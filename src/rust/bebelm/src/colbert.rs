//! Native CPU execution profile for LiquidAI's LFM2.5-ColBERT-350M GGUFs.
//!
//! This is intentionally separate from the generative `lfm2moe` model: it is a non-causal
//! `lfm2` encoder with centered short convolutions, a dense 128-dimensional token projection,
//! and ColBERT MaxSim scoring. A pooled causal state is not a substitute for this profile.

use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::path::Path;

use crate::gguf::{GgufFile, TensorInfo};
use crate::kernels::activation::swiglu;
use crate::kernels::attention::attention_full;
use crate::kernels::conv::conv_centered;
use crate::kernels::dequant;
use crate::kernels::elementwise::add_assign;
use crate::kernels::matmul::{dot, matmul};
use crate::kernels::rmsnorm::rmsnorm;
use crate::kernels::rope::rope_neox;
use crate::tensor::GgmlType;
use crate::tokenizer::Tokenizer;

/// GGUF architecture name for this encoder family.
pub const ARCH: &str = "lfm2";
pub const PROFILE_NAME: &str = "lfm2.5-colbert-350m-cpu";
pub const HIDDEN: usize = 1024;
pub const OUTPUT_DIM: usize = 128;
pub const N_LAYERS: usize = 16;
pub const VOCAB: usize = 64_402;
pub const N_HEADS: usize = 16;
pub const N_KV_HEADS: usize = 8;
pub const HEAD_DIM: usize = HIDDEN / N_HEADS;
pub const KV_DIM: usize = N_KV_HEADS * HEAD_DIM;
pub const FF: usize = 4608;
pub const CONV_L_CACHE: usize = 3;
pub const ROPE_THETA: f32 = 1_000_000.0;
pub const RMS_EPS: f32 = 1e-5;
pub const QUERY_LENGTH: usize = 32;
pub const DOCUMENT_LENGTH: usize = 512;
pub const PAD_TOKEN_ID: u32 = 7;

/// The six grouped-query attention layers in the released 350M model; the others are
/// non-causal, centered short-convolution layers.
pub const ATTENTION_LAYERS: [usize; 6] = [2, 5, 8, 10, 12, 14];

/// A variable-length sequence of unit-normalized ColBERT vectors, stored token-major.
#[derive(Clone, Debug)]
pub struct TokenEmbeddings {
    /// Model-input ids corresponding to the retained vectors.
    pub token_ids: Vec<u32>,
    /// Token-major, L2-normalized `n_tokens × dimensions` vectors.
    pub values: Vec<f32>,
    /// Vector width; fixed at [`OUTPUT_DIM`] for this profile.
    pub dimensions: usize,
}

impl TokenEmbeddings {
    pub fn len(&self) -> usize {
        self.token_ids.len()
    }

    pub fn is_empty(&self) -> bool {
        self.token_ids.is_empty()
    }
}

/// A loaded, validated LFM2.5-ColBERT encoder. The GGUF is mmapped once; each call is
/// stateless and returns a fresh query or document token-vector matrix.
pub struct ColbertModel {
    gguf: GgufFile,
    by_name: HashMap<String, usize>,
    f32_cache: HashMap<String, Vec<f32>>,
    tokenizer: Tokenizer,
    pad_id: u32,
    document_skip_ids: HashSet<u32>,
}

impl ColbertModel {
    /// Open the official LFM2.5-ColBERT GGUF profile and validate its full tensor contract.
    pub fn load<P: AsRef<Path>>(path: P) -> Result<Self, Box<dyn Error>> {
        let gguf = GgufFile::open(path)?;
        validate(&gguf)?;
        let by_name = gguf
            .tensors
            .iter()
            .enumerate()
            .map(|(index, tensor)| (tensor.name.clone(), index))
            .collect();
        let tokenizer = Tokenizer::from_gguf_relaxed(&gguf)?;
        let pad_id = gguf
            .get_u32("tokenizer.ggml.padding_token_id")
            .ok_or("missing tokenizer.ggml.padding_token_id")?;
        let document_skip_ids = skiplist_ids(&tokenizer);
        let mut model = Self {
            gguf,
            by_name,
            f32_cache: HashMap::new(),
            tokenizer,
            pad_id,
            document_skip_ids,
        };
        model.check_tensors()?;
        model.precompute_f32();
        Ok(model)
    }

    pub const fn profile_name(&self) -> &'static str {
        PROFILE_NAME
    }

    pub const fn hidden_size(&self) -> usize {
        HIDDEN
    }

    pub const fn dimensions(&self) -> usize {
        OUTPUT_DIM
    }

    pub const fn query_length(&self) -> usize {
        QUERY_LENGTH
    }

    pub const fn document_length(&self) -> usize {
        DOCUMENT_LENGTH
    }

    pub fn tokenizer(&self) -> &Tokenizer {
        &self.tokenizer
    }

    /// Encode a query as exactly 32 unit token vectors. The trailing PAD positions are model
    /// query-expansion slots, as prescribed by the published SentenceTransformers config.
    pub fn encode_query(&self, text: &str) -> TokenEmbeddings {
        let mut ids = self.tokenizer.encode(&format!("[Q] {text}"), true);
        ids.truncate(QUERY_LENGTH);
        ids.resize(QUERY_LENGTH, self.pad_id);
        self.encode_ids(ids)
    }

    /// Encode a document as up to 512 unit token vectors, removing only the published
    /// punctuation skip-list from the returned (already contextualized) vectors.
    pub fn encode_document(&self, text: &str) -> TokenEmbeddings {
        let mut ids = self.tokenizer.encode(&format!("[D] {text}"), true);
        ids.truncate(DOCUMENT_LENGTH);
        let mut encoded = self.encode_ids(ids);
        if self.document_skip_ids.is_empty() {
            return encoded;
        }

        let mut token_ids = Vec::with_capacity(encoded.len());
        let mut values = Vec::with_capacity(encoded.values.len());
        for (index, id) in encoded.token_ids.iter().copied().enumerate() {
            if !self.document_skip_ids.contains(&id) {
                token_ids.push(id);
                values.extend_from_slice(
                    &encoded.values[index * OUTPUT_DIM..(index + 1) * OUTPUT_DIM],
                );
            }
        }
        encoded.token_ids = token_ids;
        encoded.values = values;
        encoded
    }

    fn encode_ids(&self, token_ids: Vec<u32>) -> TokenEmbeddings {
        assert!(
            !token_ids.is_empty(),
            "ColBERT input must contain at least one token"
        );
        let n_tokens = token_ids.len();
        let mut hidden = vec![0.0f32; n_tokens * HIDDEN];
        for (row, &token) in token_ids.iter().enumerate() {
            self.embed_token(token, &mut hidden[row * HIDDEN..(row + 1) * HIDDEN]);
        }

        for layer in 0..N_LAYERS {
            let normed = self.norm_batch(&hidden, &name(layer, "attn_norm.weight"));
            let operator = if is_attention(layer) {
                self.attention(layer, &normed, n_tokens)
            } else {
                self.shortconv(layer, &normed, n_tokens)
            };
            add_assign(&mut hidden, &operator);

            let normed = self.norm_batch(&hidden, &name(layer, "ffn_norm.weight"));
            let ffn = self.dense_ffn(layer, &normed, n_tokens);
            add_assign(&mut hidden, &ffn);
        }

        let final_hidden = self.norm_batch(&hidden, "token_embd_norm.weight");
        let mut values = vec![0.0f32; n_tokens * OUTPUT_DIM];
        self.matmul(
            "dense_2.weight",
            &final_hidden,
            HIDDEN,
            OUTPUT_DIM,
            n_tokens,
            &mut values,
        );
        for row in values.chunks_exact_mut(OUTPUT_DIM) {
            l2_normalize(row);
        }
        TokenEmbeddings {
            token_ids,
            values,
            dimensions: OUTPUT_DIM,
        }
    }

    fn attention(&self, layer: usize, x: &[f32], n_tokens: usize) -> Vec<f32> {
        let mut q = vec![0.0f32; n_tokens * HIDDEN];
        let mut k = vec![0.0f32; n_tokens * KV_DIM];
        let mut v = vec![0.0f32; n_tokens * KV_DIM];
        self.matmul(
            &name(layer, "attn_q.weight"),
            x,
            HIDDEN,
            HIDDEN,
            n_tokens,
            &mut q,
        );
        self.matmul(
            &name(layer, "attn_k.weight"),
            x,
            HIDDEN,
            KV_DIM,
            n_tokens,
            &mut k,
        );
        self.matmul(
            &name(layer, "attn_v.weight"),
            x,
            HIDDEN,
            KV_DIM,
            n_tokens,
            &mut v,
        );

        let q_gain = self.f32(&name(layer, "attn_q_norm.weight"));
        let k_gain = self.f32(&name(layer, "attn_k_norm.weight"));
        for token in 0..n_tokens {
            norm_rope_heads(
                &mut q[token * HIDDEN..(token + 1) * HIDDEN],
                N_HEADS,
                q_gain,
                token,
            );
            norm_rope_heads(
                &mut k[token * KV_DIM..(token + 1) * KV_DIM],
                N_KV_HEADS,
                k_gain,
                token,
            );
        }

        let mut attended = vec![0.0f32; n_tokens * HIDDEN];
        attention_full(
            &q,
            &k,
            &v,
            n_tokens,
            N_HEADS,
            N_KV_HEADS,
            HEAD_DIM,
            &mut attended,
        );
        let mut out = vec![0.0f32; n_tokens * HIDDEN];
        self.matmul(
            &name(layer, "attn_output.weight"),
            &attended,
            HIDDEN,
            HIDDEN,
            n_tokens,
            &mut out,
        );
        out
    }

    fn shortconv(&self, layer: usize, x: &[f32], n_tokens: usize) -> Vec<f32> {
        let mut bcx = vec![0.0f32; n_tokens * 3 * HIDDEN];
        self.matmul(
            &name(layer, "shortconv.in_proj.weight"),
            x,
            HIDDEN,
            3 * HIDDEN,
            n_tokens,
            &mut bcx,
        );
        let mut bx = vec![0.0f32; n_tokens * HIDDEN];
        for token in 0..n_tokens {
            let base = token * 3 * HIDDEN;
            for channel in 0..HIDDEN {
                bx[token * HIDDEN + channel] =
                    bcx[base + channel] * bcx[base + 2 * HIDDEN + channel];
            }
        }
        let mut convolved = vec![0.0f32; n_tokens * HIDDEN];
        conv_centered(
            &bx,
            self.f32(&name(layer, "shortconv.conv.weight")),
            HIDDEN,
            CONV_L_CACHE,
            n_tokens,
            &mut convolved,
        );
        let mut gated = vec![0.0f32; n_tokens * HIDDEN];
        for token in 0..n_tokens {
            let base = token * 3 * HIDDEN;
            for channel in 0..HIDDEN {
                gated[token * HIDDEN + channel] =
                    bcx[base + HIDDEN + channel] * convolved[token * HIDDEN + channel];
            }
        }
        let mut out = vec![0.0f32; n_tokens * HIDDEN];
        self.matmul(
            &name(layer, "shortconv.out_proj.weight"),
            &gated,
            HIDDEN,
            HIDDEN,
            n_tokens,
            &mut out,
        );
        out
    }

    fn dense_ffn(&self, layer: usize, x: &[f32], n_tokens: usize) -> Vec<f32> {
        let mut gate = vec![0.0f32; n_tokens * FF];
        let mut up = vec![0.0f32; n_tokens * FF];
        self.matmul(
            &name(layer, "ffn_gate.weight"),
            x,
            HIDDEN,
            FF,
            n_tokens,
            &mut gate,
        );
        self.matmul(
            &name(layer, "ffn_up.weight"),
            x,
            HIDDEN,
            FF,
            n_tokens,
            &mut up,
        );
        let mut activated = vec![0.0f32; n_tokens * FF];
        for ((gate_row, up_row), out_row) in gate
            .chunks_exact(FF)
            .zip(up.chunks_exact(FF))
            .zip(activated.chunks_exact_mut(FF))
        {
            swiglu(gate_row, up_row, out_row);
        }
        let mut out = vec![0.0f32; n_tokens * HIDDEN];
        self.matmul(
            &name(layer, "ffn_down.weight"),
            &activated,
            FF,
            HIDDEN,
            n_tokens,
            &mut out,
        );
        out
    }

    fn norm_batch(&self, values: &[f32], gain_name: &str) -> Vec<f32> {
        let mut out = vec![0.0f32; values.len()];
        let gain = self.f32(gain_name);
        for (input, output) in values
            .chunks_exact(HIDDEN)
            .zip(out.chunks_exact_mut(HIDDEN))
        {
            rmsnorm(input, gain, RMS_EPS, output);
        }
        out
    }

    fn matmul(
        &self,
        tensor_name: &str,
        x: &[f32],
        n_in: usize,
        n_out: usize,
        n_tokens: usize,
        out: &mut [f32],
    ) {
        let tensor = self.tensor(tensor_name).expect("validated ColBERT tensor");
        matmul(
            tensor.ggml_type,
            self.data(tensor),
            n_in,
            n_out,
            x,
            n_tokens,
            out,
        );
    }

    fn embed_token(&self, token: u32, out: &mut [f32]) {
        let tensor = self
            .tensor("token_embd.weight")
            .expect("validated token embedding");
        assert!(
            (token as usize) < VOCAB,
            "token id outside ColBERT vocabulary"
        );
        let (block_elements, block_bytes) =
            tensor.ggml_type.block().expect("supported embedding dtype");
        let row_bytes = (HIDDEN / block_elements as usize) * block_bytes as usize;
        let offset = token as usize * row_bytes;
        dequant::dequantize_into(
            tensor.ggml_type,
            &self.data(tensor)[offset..offset + row_bytes],
            out,
        );
    }

    fn precompute_f32(&mut self) {
        let mut cache = HashMap::new();
        for tensor in &self.gguf.tensors {
            if tensor.ggml_type == GgmlType::F32 {
                cache.insert(
                    tensor.name.clone(),
                    dequant::dequantize(
                        tensor.ggml_type,
                        self.gguf.tensor_data(tensor),
                        tensor.n_elements() as usize,
                    ),
                );
            }
        }
        self.f32_cache = cache;
    }

    fn f32(&self, name: &str) -> &[f32] {
        self.f32_cache
            .get(name)
            .unwrap_or_else(|| panic!("ColBERT F32 tensor not precomputed: {name}"))
            .as_slice()
    }

    fn tensor(&self, name: &str) -> Option<&TensorInfo> {
        self.by_name
            .get(name)
            .map(|&index| &self.gguf.tensors[index])
    }

    fn data(&self, tensor: &TensorInfo) -> &[u8] {
        self.gguf.tensor_data(tensor)
    }

    fn check_tensors(&self) -> Result<(), Box<dyn Error>> {
        for (name, shape) in expected_tensors() {
            let tensor = self
                .tensor(&name)
                .ok_or_else(|| format!("missing ColBERT tensor {name}"))?;
            if tensor.dims != shape {
                return Err(format!(
                    "ColBERT tensor {name}: shape {:?} != expected {shape:?}",
                    tensor.dims
                )
                .into());
            }
            if !dequant::supports(tensor.ggml_type) {
                return Err(format!(
                    "ColBERT tensor {name}: unsupported CPU dtype {}",
                    tensor.ggml_type
                )
                .into());
            }
        }
        Ok(())
    }
}

/// ColBERT's late-interaction score: each query vector selects its best matching document
/// vector, and those maxima are summed. Both inputs must have unit-normalized, equal-width rows.
pub fn maxsim(query: &TokenEmbeddings, document: &TokenEmbeddings) -> Result<f32, Box<dyn Error>> {
    if query.dimensions != document.dimensions {
        return Err(format!(
            "MaxSim dimension mismatch: {} vs {}",
            query.dimensions, document.dimensions
        )
        .into());
    }
    if query.is_empty() || document.is_empty() {
        return Err("MaxSim requires non-empty query and document token vectors".into());
    }
    if query.values.len() != query.len() * query.dimensions
        || document.values.len() != document.len() * document.dimensions
    {
        return Err("malformed token-vector matrix".into());
    }
    let mut score = 0.0;
    for query_row in query.values.chunks_exact(query.dimensions) {
        let best = document
            .values
            .chunks_exact(document.dimensions)
            .map(|document_row| dot(query_row, document_row))
            .fold(f32::NEG_INFINITY, f32::max);
        score += best;
    }
    Ok(score)
}

fn is_attention(layer: usize) -> bool {
    ATTENTION_LAYERS.contains(&layer)
}

fn name(layer: usize, suffix: &str) -> String {
    format!("blk.{layer}.{suffix}")
}

fn norm_rope_heads(values: &mut [f32], n_heads: usize, gain: &[f32], position: usize) {
    let mut normalized = vec![0.0f32; HEAD_DIM];
    for head in 0..n_heads {
        let row = &mut values[head * HEAD_DIM..(head + 1) * HEAD_DIM];
        rmsnorm(row, gain, RMS_EPS, &mut normalized);
        row.copy_from_slice(&normalized);
        rope_neox(row, position, ROPE_THETA);
    }
}

fn l2_normalize(values: &mut [f32]) {
    let norm = values.iter().map(|value| value * value).sum::<f32>().sqrt();
    if norm > 0.0 {
        for value in values {
            *value /= norm;
        }
    }
}

fn skiplist_ids(tokenizer: &Tokenizer) -> HashSet<u32> {
    const WORDS: &[&str] = &[
        "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", ":", ";", "<",
        "=", ">", "?", "@", "[", "\\", "]", "^", "_", "`", "{", "|", "}", "~",
    ];
    WORDS
        .iter()
        .flat_map(|word| tokenizer.encode(word, false))
        .collect()
}

fn validate(g: &GgufFile) -> Result<(), Box<dyn Error>> {
    let architecture = g.architecture().ok_or("missing general.architecture")?;
    if architecture != ARCH {
        return Err(format!("architecture: expected {ARCH:?}, got {architecture:?}").into());
    }
    expect_u32(g, "lfm2.block_count", N_LAYERS as u32)?;
    expect_u32(g, "lfm2.context_length", 128_000)?;
    expect_u32(g, "lfm2.embedding_length", HIDDEN as u32)?;
    expect_u32(g, "lfm2.embedding_length_out", OUTPUT_DIM as u32)?;
    expect_u32(g, "lfm2.feed_forward_length", FF as u32)?;
    expect_u32(g, "lfm2.attention.head_count", N_HEADS as u32)?;
    expect_u32(g, "lfm2.vocab_size", VOCAB as u32)?;
    expect_u32(g, "lfm2.shortconv.l_cache", CONV_L_CACHE as u32)?;
    expect_f32(g, "lfm2.rope.freq_base", ROPE_THETA, 1.0)?;
    expect_f32(g, "lfm2.attention.layer_norm_rms_epsilon", RMS_EPS, 1e-9)?;
    if g.get_bool("lfm2.attention.causal") != Some(false) {
        return Err("lfm2.attention.causal: expected false for ColBERT encoder".into());
    }
    expect_u32(g, "tokenizer.ggml.bos_token_id", 1)?;
    expect_u32(g, "tokenizer.ggml.padding_token_id", PAD_TOKEN_ID)?;
    let kv_heads = g
        .get_u32_array("lfm2.attention.head_count_kv")
        .ok_or("missing lfm2.attention.head_count_kv")?;
    if kv_heads.len() != N_LAYERS {
        return Err(format!(
            "lfm2.attention.head_count_kv has {} entries, expected {N_LAYERS}",
            kv_heads.len()
        )
        .into());
    }
    for (layer, &heads) in kv_heads.iter().enumerate() {
        let expected = if is_attention(layer) {
            N_KV_HEADS as u32
        } else {
            0
        };
        if heads != expected {
            return Err(format!("layer {layer}: kv heads={heads}, expected {expected}").into());
        }
    }
    Ok(())
}

fn expect_u32(g: &GgufFile, key: &str, expected: u32) -> Result<(), Box<dyn Error>> {
    match g.get_u32(key) {
        Some(value) if value == expected => Ok(()),
        Some(value) => Err(format!("{key}: expected {expected}, got {value}").into()),
        None => Err(format!("missing metadata {key}").into()),
    }
}

fn expect_f32(
    g: &GgufFile,
    key: &str,
    expected: f32,
    tolerance: f32,
) -> Result<(), Box<dyn Error>> {
    match g.get_f32(key) {
        Some(value) if (value - expected).abs() <= tolerance => Ok(()),
        Some(value) => Err(format!("{key}: expected {expected}, got {value}").into()),
        None => Err(format!("missing metadata {key}").into()),
    }
}

/// Full tensor contract for the published 350M GGUF profile.
pub fn expected_tensors() -> Vec<(String, Vec<u64>)> {
    let hidden = HIDDEN as u64;
    let mut tensors = vec![
        ("dense_2.weight".into(), vec![hidden, OUTPUT_DIM as u64]),
        ("token_embd.weight".into(), vec![hidden, VOCAB as u64]),
        ("token_embd_norm.weight".into(), vec![hidden]),
    ];
    for layer in 0..N_LAYERS {
        let prefix = format!("blk.{layer}");
        tensors.push((format!("{prefix}.attn_norm.weight"), vec![hidden]));
        tensors.push((format!("{prefix}.ffn_norm.weight"), vec![hidden]));
        if is_attention(layer) {
            tensors.push((format!("{prefix}.attn_q.weight"), vec![hidden, hidden]));
            tensors.push((
                format!("{prefix}.attn_k.weight"),
                vec![hidden, KV_DIM as u64],
            ));
            tensors.push((
                format!("{prefix}.attn_v.weight"),
                vec![hidden, KV_DIM as u64],
            ));
            tensors.push((format!("{prefix}.attn_output.weight"), vec![hidden, hidden]));
            tensors.push((
                format!("{prefix}.attn_q_norm.weight"),
                vec![HEAD_DIM as u64],
            ));
            tensors.push((
                format!("{prefix}.attn_k_norm.weight"),
                vec![HEAD_DIM as u64],
            ));
        } else {
            tensors.push((
                format!("{prefix}.shortconv.in_proj.weight"),
                vec![hidden, 3 * hidden],
            ));
            tensors.push((
                format!("{prefix}.shortconv.conv.weight"),
                vec![CONV_L_CACHE as u64, hidden],
            ));
            tensors.push((
                format!("{prefix}.shortconv.out_proj.weight"),
                vec![hidden, hidden],
            ));
        }
        tensors.push((format!("{prefix}.ffn_gate.weight"), vec![hidden, FF as u64]));
        tensors.push((format!("{prefix}.ffn_up.weight"), vec![hidden, FF as u64]));
        tensors.push((format!("{prefix}.ffn_down.weight"), vec![FF as u64, hidden]));
    }
    tensors
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tensor_contract_matches_published_file() {
        assert_eq!(expected_tensors().len(), 149);
    }

    #[test]
    fn maxsim_uses_one_best_document_vector_per_query_vector() {
        let query = TokenEmbeddings {
            token_ids: vec![1, 2],
            dimensions: 2,
            values: vec![1.0, 0.0, 0.0, 1.0],
        };
        let document = TokenEmbeddings {
            token_ids: vec![3, 4],
            dimensions: 2,
            values: vec![0.8, 0.2, 0.1, 0.9],
        };
        assert!((maxsim(&query, &document).unwrap() - 1.7).abs() < 1e-6);
    }

    #[test]
    #[ignore = "loads a local ColBERT GGUF; set COLBERT_WEIGHTS_FILE and run ignored tests"]
    fn official_q4_k_m_profile_loads_and_emits_finite_vectors() {
        let path = std::env::var("COLBERT_WEIGHTS_FILE").expect("COLBERT_WEIGHTS_FILE");
        let model = ColbertModel::load(path).expect("load official ColBERT GGUF");
        let query = model.encode_query("What is panda?");
        let document = model.encode_document("The giant panda is a bear species endemic to China.");
        assert_eq!(query.len(), QUERY_LENGTH);
        assert_eq!(query.token_ids[QUERY_LENGTH - 1], PAD_TOKEN_ID);
        assert_eq!(query.dimensions, OUTPUT_DIM);
        assert!(!document.is_empty());
        assert!(query
            .values
            .iter()
            .chain(&document.values)
            .all(|value| value.is_finite()));
        assert!(maxsim(&query, &document).unwrap().is_finite());

        // LiquidAI's published Q4_K_M llama.cpp example reports 29.04 for this pair.
        // Quantized matmul implementations differ slightly, so use a deliberately narrow
        // tolerance while protecting prefixes, PAD=7 expansion, non-causal attention,
        // projection, normalization, and MaxSim semantics together.
        let score = maxsim(&query, &model.encode_document("hi")).unwrap();
        assert!((score - 29.04).abs() < 0.30, "{score} != 29.04");
    }
}
