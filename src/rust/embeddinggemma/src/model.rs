//! EmbeddingGemma-300M GGUF loading and bidirectional encoder inference.

use std::collections::HashMap;
use std::error::Error;
use std::path::Path;

use bebelm::gguf::{GgufFile, TensorInfo};
use bebelm::kernels::activation::geglu;
use bebelm::kernels::elementwise::add_assign;
use bebelm::kernels::matmul::{dot, matmul};
use bebelm::kernels::rmsnorm::rmsnorm;
use bebelm::kernels::rope::rope_neox;
use bebelm::kernels::softmax::softmax;
use rayon::prelude::*;

use crate::tokenizer::Tokenizer;

pub const ARCHITECTURE: &str = "gemma-embedding";
pub const CONTEXT_LENGTH: usize = 2048;
pub const HIDDEN: usize = 768;
pub const N_LAYERS: usize = 24;
pub const N_HEADS: usize = 3;
pub const N_KV_HEADS: usize = 1;
pub const HEAD_DIM: usize = 256;
pub const KV_DIM: usize = 256;
pub const FEED_FORWARD: usize = 1152;
pub const DENSE_HIDDEN: usize = 3072;
pub const VOCAB: usize = 262_144;
pub const SLIDING_WINDOW: usize = 512;
pub const RMS_EPS: f32 = 1e-6;
pub const ROPE_THETA_GLOBAL: f32 = 1_000_000.0;
pub const ROPE_THETA_LOCAL: f32 = 10_000.0;
pub const EMBEDDING_DIMENSIONS: [usize; 4] = [768, 512, 256, 128];
/// Bound packed inference scratch space while amortizing each matrix read across short texts.
pub const BATCH_TOKEN_BUDGET: usize = 512;

pub struct EmbeddingOutput {
    pub values: Vec<f32>,
    pub token_ids: Vec<u32>,
    pub truncated: bool,
}

/// Loaded EmbeddingGemma model backed by an mmapped GGUF.
pub struct EmbeddingGemma {
    gguf: GgufFile,
    by_name: HashMap<String, usize>,
    f32_cache: HashMap<String, Vec<f32>>,
    tokenizer: Tokenizer,
}

impl EmbeddingGemma {
    pub fn load<P: AsRef<Path>>(path: P) -> Result<Self, Box<dyn Error>> {
        let gguf = GgufFile::open(path)?;
        validate_metadata(&gguf)?;
        let mut by_name = HashMap::with_capacity(gguf.tensors.len());
        for (index, tensor) in gguf.tensors.iter().enumerate() {
            if by_name.insert(tensor.name.clone(), index).is_some() {
                return Err(format!("duplicate GGUF tensor name {:?}", tensor.name).into());
            }
        }
        let tokenizer = Tokenizer::from_gguf(&gguf)?;
        if tokenizer.vocab_size() != VOCAB {
            return Err(format!(
                "tokenizer vocabulary has {} entries, expected {VOCAB}",
                tokenizer.vocab_size()
            )
            .into());
        }
        let mut model = Self {
            gguf,
            by_name,
            f32_cache: HashMap::new(),
            tokenizer,
        };
        model.check_tensors()?;
        model.precompute_f32();
        Ok(model)
    }

    pub fn tokenizer(&self) -> &Tokenizer {
        &self.tokenizer
    }

    /// Tokenize one raw, already task-formatted model input, including BOS and EOS.
    pub fn tokenize(&self, text: &str, truncate: bool) -> Result<(Vec<u32>, bool), Box<dyn Error>> {
        let mut ids = self.tokenizer.encode(text);
        let was_truncated = ids.len() > CONTEXT_LENGTH;
        if was_truncated {
            if !truncate {
                return Err(format!(
                    "input has {} tokens including BOS/EOS, exceeding EmbeddingGemma's {CONTEXT_LENGTH}-token context",
                    ids.len()
                )
                .into());
            }
            ids.truncate(CONTEXT_LENGTH);
            // When EOS is enabled, reserve the final slot for the model-declared EOS token.
            if self.tokenizer.adds_eos() {
                if let Some(last) = ids.last_mut() {
                    *last = self.tokenizer.eos_id();
                }
            }
        }
        Ok((ids, was_truncated))
    }

    /// Embed one raw, already task-formatted input.
    pub fn embed(
        &self,
        text: &str,
        dimensions: usize,
        normalize: bool,
        truncate: bool,
    ) -> Result<EmbeddingOutput, Box<dyn Error>> {
        let (ids, truncated) = self.tokenize(text, truncate)?;
        let mut outputs = self.embed_tokenized_batch(&[(ids, truncated)], dimensions, normalize)?;
        Ok(outputs.pop().expect("one input produces one embedding"))
    }

    /// Embed independent, unpadded tokenized inputs as one packed encoder pass. Attention remains
    /// bounded to each sequence; only the matrix products are shared across packed token rows.
    pub fn embed_tokenized_batch(
        &self,
        inputs: &[(Vec<u32>, bool)],
        dimensions: usize,
        normalize: bool,
    ) -> Result<Vec<EmbeddingOutput>, Box<dyn Error>> {
        if !EMBEDDING_DIMENSIONS.contains(&dimensions) {
            return Err(format!(
                "unsupported embedding dimension {dimensions}; use 768, 512, 256, or 128"
            )
            .into());
        }
        if inputs.is_empty() {
            return Ok(Vec::new());
        }

        let total_tokens: usize = inputs.iter().map(|(ids, _)| ids.len()).sum();
        if inputs.len() > 1 && total_tokens > BATCH_TOKEN_BUDGET {
            return Err(format!(
                "packed batch has {total_tokens} tokens, exceeding budget {BATCH_TOKEN_BUDGET}"
            )
            .into());
        }
        let mut ids = Vec::with_capacity(total_tokens);
        let mut offsets = Vec::with_capacity(inputs.len() + 1);
        offsets.push(0);
        for (sequence, (one, _)) in inputs.iter().enumerate() {
            if one.is_empty() || one.len() > CONTEXT_LENGTH {
                return Err(format!(
                    "tokenized input {} has {} tokens; expected 1..={CONTEXT_LENGTH}",
                    sequence + 1,
                    one.len()
                )
                .into());
            }
            if let Some(&token) = one.iter().find(|&&token| token as usize >= VOCAB) {
                return Err(format!(
                    "tokenized input {} contains out-of-vocabulary token id {token}",
                    sequence + 1
                )
                .into());
            }
            ids.extend_from_slice(one);
            offsets.push(ids.len());
        }
        let states = self.forward_packed(&ids, &offsets);

        // SentenceTransformers module 1: attention-mask mean pooling. Packing has no padding,
        // and offsets retain each independent sequence's attention-mask boundary.
        let mut pooled = vec![0.0f32; inputs.len() * HIDDEN];
        for sequence in 0..inputs.len() {
            let output = &mut pooled[sequence * HIDDEN..(sequence + 1) * HIDDEN];
            for token in offsets[sequence]..offsets[sequence + 1] {
                let row = &states[token * HIDDEN..(token + 1) * HIDDEN];
                for (acc, &value) in output.iter_mut().zip(row) {
                    *acc += value;
                }
            }
            let denom = (offsets[sequence + 1] - offsets[sequence]) as f32;
            for value in output {
                *value /= denom;
            }
        }

        // SentenceTransformers modules 2 and 3 are learned bias-free Identity-activation
        // projections, 768 -> 3072 -> 768. Both run across every packed sequence at once.
        let mut dense = vec![0.0f32; inputs.len() * DENSE_HIDDEN];
        self.matmul_named(
            "dense_2.weight",
            &pooled,
            HIDDEN,
            DENSE_HIDDEN,
            inputs.len(),
            &mut dense,
        );
        let mut projected = vec![0.0f32; inputs.len() * HIDDEN];
        self.matmul_named(
            "dense_3.weight",
            &dense,
            DENSE_HIDDEN,
            HIDDEN,
            inputs.len(),
            &mut projected,
        );

        Ok(inputs
            .iter()
            .enumerate()
            .map(|(sequence, (token_ids, truncated))| {
                let start = sequence * HIDDEN;
                let mut values = projected[start..start + dimensions].to_vec();
                if normalize {
                    l2_normalize(&mut values);
                }
                EmbeddingOutput {
                    values,
                    token_ids: token_ids.clone(),
                    truncated: *truncated,
                }
            })
            .collect())
    }

    /// Return the post-output-norm token states before mean pooling and dense projections.
    pub fn token_states(
        &self,
        text: &str,
        truncate: bool,
    ) -> Result<(Vec<u32>, Vec<f32>, bool), Box<dyn Error>> {
        let (ids, truncated) = self.tokenize(text, truncate)?;
        let states = self.forward_tokens(&ids);
        Ok((ids, states, truncated))
    }

    fn forward_tokens(&self, ids: &[u32]) -> Vec<f32> {
        self.forward_packed(ids, &[0, ids.len()])
    }

    fn forward_packed(&self, ids: &[u32], offsets: &[usize]) -> Vec<f32> {
        assert!(!ids.is_empty());
        assert_eq!(offsets.first(), Some(&0));
        assert_eq!(offsets.last(), Some(&ids.len()));
        let n = ids.len();
        let mut positions = vec![0usize; n];
        let mut sequence_starts = vec![0usize; n];
        let mut sequence_ends = vec![0usize; n];
        for bounds in offsets.windows(2) {
            assert!(bounds[0] < bounds[1] && bounds[1] - bounds[0] <= CONTEXT_LENGTH);
            for token in bounds[0]..bounds[1] {
                positions[token] = token - bounds[0];
                sequence_starts[token] = bounds[0];
                sequence_ends[token] = bounds[1];
            }
        }

        let mut hidden = vec![0.0f32; n * HIDDEN];
        let embedding_scale = (HIDDEN as f32).sqrt();
        for (row, &token) in hidden.chunks_exact_mut(HIDDEN).zip(ids) {
            self.embed_token(token, row);
            for value in row {
                *value *= embedding_scale;
            }
        }

        for layer in 0..N_LAYERS {
            let normed = self.norm_batch(&hidden, &name(layer, "attn_norm.weight"));
            let mut q = vec![0.0f32; n * HIDDEN];
            let mut k = vec![0.0f32; n * KV_DIM];
            let mut v = vec![0.0f32; n * KV_DIM];
            self.matmul_named(
                &name(layer, "attn_q.weight"),
                &normed,
                HIDDEN,
                HIDDEN,
                n,
                &mut q,
            );
            self.matmul_named(
                &name(layer, "attn_k.weight"),
                &normed,
                HIDDEN,
                KV_DIM,
                n,
                &mut k,
            );
            self.matmul_named(
                &name(layer, "attn_v.weight"),
                &normed,
                HIDDEN,
                KV_DIM,
                n,
                &mut v,
            );

            let q_gain = self.f32(&name(layer, "attn_q_norm.weight"));
            let k_gain = self.f32(&name(layer, "attn_k_norm.weight"));
            let rope_theta = if is_local_attention(layer) {
                ROPE_THETA_LOCAL
            } else {
                ROPE_THETA_GLOBAL
            };
            q.par_chunks_exact_mut(HEAD_DIM)
                .enumerate()
                .for_each(|(head_row, values)| {
                    let mut normalized = [0.0f32; HEAD_DIM];
                    rmsnorm(values, q_gain, RMS_EPS, &mut normalized);
                    values.copy_from_slice(&normalized);
                    rope_neox(values, positions[head_row / N_HEADS], rope_theta);
                });
            k.par_chunks_exact_mut(HEAD_DIM)
                .enumerate()
                .for_each(|(position, values)| {
                    let mut normalized = [0.0f32; HEAD_DIM];
                    rmsnorm(values, k_gain, RMS_EPS, &mut normalized);
                    values.copy_from_slice(&normalized);
                    rope_neox(values, positions[position], rope_theta);
                });

            let local = is_local_attention(layer);
            let mut attention = vec![0.0f32; n * HIDDEN];
            attention
                .par_chunks_exact_mut(HIDDEN)
                .enumerate()
                .for_each_init(
                    || vec![0.0f32; CONTEXT_LENGTH],
                    |score_buffer, (query_position, row_out)| {
                        let sequence_start = sequence_starts[query_position];
                        let sequence_end = sequence_ends[query_position];
                        let sequence_length = sequence_end - sequence_start;
                        let (relative_start, relative_end) =
                            attention_span(positions[query_position], sequence_length, local);
                        let start = sequence_start + relative_start;
                        let end = sequence_start + relative_end;
                        let scores = &mut score_buffer[..end - start];
                        for head in 0..N_HEADS {
                            let query = &q[query_position * HIDDEN + head * HEAD_DIM
                                ..query_position * HIDDEN + (head + 1) * HEAD_DIM];
                            for (score, key_position) in scores.iter_mut().zip(start..end) {
                                let key = &k[key_position * KV_DIM..(key_position + 1) * KV_DIM];
                                *score = dot(query, key) / (HEAD_DIM as f32).sqrt();
                            }
                            softmax(scores);
                            let out = &mut row_out[head * HEAD_DIM..(head + 1) * HEAD_DIM];
                            out.fill(0.0);
                            for (&weight, key_position) in scores.iter().zip(start..end) {
                                let value = &v[key_position * KV_DIM..(key_position + 1) * KV_DIM];
                                for (dst, &src) in out.iter_mut().zip(value) {
                                    *dst += weight * src;
                                }
                            }
                        }
                    },
                );

            let mut attention_out = vec![0.0f32; n * HIDDEN];
            self.matmul_named(
                &name(layer, "attn_output.weight"),
                &attention,
                HIDDEN,
                HIDDEN,
                n,
                &mut attention_out,
            );
            let attention_out =
                self.norm_batch(&attention_out, &name(layer, "post_attention_norm.weight"));
            add_assign(&mut hidden, &attention_out);

            let ffn_input = self.norm_batch(&hidden, &name(layer, "ffn_norm.weight"));
            let mut gate = vec![0.0f32; n * FEED_FORWARD];
            let mut up = vec![0.0f32; n * FEED_FORWARD];
            self.matmul_named(
                &name(layer, "ffn_gate.weight"),
                &ffn_input,
                HIDDEN,
                FEED_FORWARD,
                n,
                &mut gate,
            );
            self.matmul_named(
                &name(layer, "ffn_up.weight"),
                &ffn_input,
                HIDDEN,
                FEED_FORWARD,
                n,
                &mut up,
            );
            let mut activated = vec![0.0f32; n * FEED_FORWARD];
            gate.par_chunks_exact(FEED_FORWARD)
                .zip(up.par_chunks_exact(FEED_FORWARD))
                .zip(activated.par_chunks_exact_mut(FEED_FORWARD))
                .for_each(|((gate_row, up_row), output_row)| geglu(gate_row, up_row, output_row));
            let mut ffn_out = vec![0.0f32; n * HIDDEN];
            self.matmul_named(
                &name(layer, "ffn_down.weight"),
                &activated,
                FEED_FORWARD,
                HIDDEN,
                n,
                &mut ffn_out,
            );
            let ffn_out = self.norm_batch(&ffn_out, &name(layer, "post_ffw_norm.weight"));
            add_assign(&mut hidden, &ffn_out);
        }

        self.norm_batch(&hidden, "output_norm.weight")
    }

    fn tensor(&self, name: &str) -> Option<&TensorInfo> {
        self.by_name
            .get(name)
            .map(|&index| &self.gguf.tensors[index])
    }

    fn data(&self, tensor: &TensorInfo) -> &[u8] {
        self.gguf.tensor_data(tensor)
    }

    fn f32(&self, name: &str) -> &[f32] {
        self.f32_cache
            .get(name)
            .unwrap_or_else(|| panic!("f32 tensor not precomputed: {name}"))
    }

    fn precompute_f32(&mut self) {
        self.f32_cache = self
            .gguf
            .tensors
            .iter()
            // Every expected rank-1 tensor is a norm gain. Cache it as f32 regardless of its
            // supported on-disk quantization so inference cannot fail after successful loading.
            .filter(|tensor| tensor.dims.len() == 1)
            .map(|tensor| {
                let values = bebelm::kernels::dequant::dequantize(
                    tensor.ggml_type,
                    self.gguf.tensor_data(tensor),
                    tensor.n_elements() as usize,
                );
                (tensor.name.clone(), values)
            })
            .collect();
    }

    fn embed_token(&self, token: u32, out: &mut [f32]) {
        let tensor = self
            .tensor("token_embd.weight")
            .expect("validated token embedding");
        let (block_elements, block_bytes) =
            tensor.ggml_type.block().expect("validated embedding dtype");
        let row_bytes = HIDDEN / block_elements as usize * block_bytes as usize;
        let offset = token as usize * row_bytes;
        bebelm::kernels::dequant::dequantize_into(
            tensor.ggml_type,
            &self.data(tensor)[offset..offset + row_bytes],
            out,
        );
    }

    fn norm_batch(&self, input: &[f32], gain_name: &str) -> Vec<f32> {
        let gain = self.f32(gain_name);
        let mut out = vec![0.0f32; input.len()];
        input
            .par_chunks_exact(HIDDEN)
            .zip(out.par_chunks_exact_mut(HIDDEN))
            .for_each(|(src, dst)| rmsnorm(src, gain, RMS_EPS, dst));
        out
    }

    fn matmul_named(
        &self,
        tensor_name: &str,
        x: &[f32],
        n_in: usize,
        n_out: usize,
        n_tokens: usize,
        out: &mut [f32],
    ) {
        let tensor = self.tensor(tensor_name).expect("validated matmul tensor");
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

    fn check_tensors(&self) -> Result<(), Box<dyn Error>> {
        for (tensor_name, expected_shape) in expected_tensors() {
            let tensor = self
                .tensor(&tensor_name)
                .ok_or_else(|| format!("missing tensor {tensor_name}"))?;
            if tensor.dims != expected_shape {
                return Err(format!(
                    "tensor {tensor_name}: shape {:?} != expected {:?}",
                    tensor.dims, expected_shape
                )
                .into());
            }
            if !bebelm::kernels::dequant::supports(tensor.ggml_type) {
                return Err(format!(
                    "tensor {tensor_name}: unsupported dtype {}",
                    tensor.ggml_type
                )
                .into());
            }
        }
        Ok(())
    }
}

fn validate_metadata(gguf: &GgufFile) -> Result<(), Box<dyn Error>> {
    expect_str(gguf, "general.architecture", ARCHITECTURE)?;
    expect_u32(gguf, "gemma-embedding.block_count", N_LAYERS as u32)?;
    expect_u32(
        gguf,
        "gemma-embedding.context_length",
        CONTEXT_LENGTH as u32,
    )?;
    expect_u32(gguf, "gemma-embedding.embedding_length", HIDDEN as u32)?;
    expect_u32(
        gguf,
        "gemma-embedding.feed_forward_length",
        FEED_FORWARD as u32,
    )?;
    expect_u32(gguf, "gemma-embedding.attention.head_count", N_HEADS as u32)?;
    expect_u32(
        gguf,
        "gemma-embedding.attention.head_count_kv",
        N_KV_HEADS as u32,
    )?;
    expect_u32(
        gguf,
        "gemma-embedding.attention.key_length",
        HEAD_DIM as u32,
    )?;
    expect_u32(
        gguf,
        "gemma-embedding.attention.value_length",
        HEAD_DIM as u32,
    )?;
    expect_u32(
        gguf,
        "gemma-embedding.attention.sliding_window",
        SLIDING_WINDOW as u32,
    )?;
    expect_u32(gguf, "gemma-embedding.dense_2_feat_in", HIDDEN as u32)?;
    expect_u32(
        gguf,
        "gemma-embedding.dense_2_feat_out",
        DENSE_HIDDEN as u32,
    )?;
    expect_u32(gguf, "gemma-embedding.dense_3_feat_in", DENSE_HIDDEN as u32)?;
    expect_u32(gguf, "gemma-embedding.dense_3_feat_out", HIDDEN as u32)?;
    expect_u32(gguf, "gemma-embedding.pooling_type", 1)?; // mean
    expect_f32(
        gguf,
        "gemma-embedding.rope.freq_base",
        ROPE_THETA_GLOBAL,
        1.0,
    )?;
    expect_f32(
        gguf,
        "gemma-embedding.rope.freq_base_swa",
        ROPE_THETA_LOCAL,
        1e-3,
    )?;
    expect_f32(
        gguf,
        "gemma-embedding.attention.layer_norm_rms_epsilon",
        RMS_EPS,
        1e-9,
    )?;
    Ok(())
}

fn expect_u32(gguf: &GgufFile, key: &str, expected: u32) -> Result<(), Box<dyn Error>> {
    let actual = gguf
        .get_u32(key)
        .ok_or_else(|| format!("missing metadata {key}"))?;
    if actual != expected {
        return Err(format!("{key}: expected {expected}, got {actual}").into());
    }
    Ok(())
}

fn expect_f32(
    gguf: &GgufFile,
    key: &str,
    expected: f32,
    tolerance: f32,
) -> Result<(), Box<dyn Error>> {
    let actual = gguf
        .get_f32(key)
        .ok_or_else(|| format!("missing metadata {key}"))?;
    if (actual - expected).abs() > tolerance {
        return Err(format!("{key}: expected {expected}, got {actual}").into());
    }
    Ok(())
}

fn expect_str(gguf: &GgufFile, key: &str, expected: &str) -> Result<(), Box<dyn Error>> {
    let actual = gguf
        .get_str(key)
        .ok_or_else(|| format!("missing metadata {key}"))?;
    if actual != expected {
        return Err(format!("{key}: expected {expected:?}, got {actual:?}").into());
    }
    Ok(())
}

fn name(layer: usize, suffix: &str) -> String {
    format!("blk.{layer}.{suffix}")
}

/// EmbeddingGemma uses five symmetric local layers followed by one global layer.
fn is_local_attention(layer: usize) -> bool {
    layer % 6 < 5
}

fn attention_span(position: usize, n_tokens: usize, local: bool) -> (usize, usize) {
    if !local {
        return (0, n_tokens);
    }
    let half_window = SLIDING_WINDOW / 2;
    (
        position.saturating_sub(half_window),
        (position + half_window + 1).min(n_tokens),
    )
}

fn l2_normalize(values: &mut [f32]) {
    let norm = values
        .iter()
        .map(|&value| (value as f64) * (value as f64))
        .sum::<f64>()
        .sqrt();
    if norm > 0.0 && norm.is_finite() {
        for value in values {
            *value = (*value as f64 / norm) as f32;
        }
    }
}

pub fn expected_tensors() -> Vec<(String, Vec<u64>)> {
    let hidden = HIDDEN as u64;
    let head = HEAD_DIM as u64;
    let ff = FEED_FORWARD as u64;
    let mut out = vec![
        ("dense_2.weight".into(), vec![hidden, DENSE_HIDDEN as u64]),
        ("dense_3.weight".into(), vec![DENSE_HIDDEN as u64, hidden]),
        ("output_norm.weight".into(), vec![hidden]),
        ("token_embd.weight".into(), vec![hidden, VOCAB as u64]),
    ];
    for layer in 0..N_LAYERS {
        let prefix = format!("blk.{layer}");
        out.extend([
            (format!("{prefix}.attn_k.weight"), vec![hidden, head]),
            (format!("{prefix}.attn_k_norm.weight"), vec![head]),
            (format!("{prefix}.attn_norm.weight"), vec![hidden]),
            (format!("{prefix}.attn_output.weight"), vec![hidden, hidden]),
            (format!("{prefix}.attn_q.weight"), vec![hidden, hidden]),
            (format!("{prefix}.attn_q_norm.weight"), vec![head]),
            (format!("{prefix}.attn_v.weight"), vec![hidden, head]),
            (format!("{prefix}.ffn_down.weight"), vec![ff, hidden]),
            (format!("{prefix}.ffn_gate.weight"), vec![hidden, ff]),
            (format!("{prefix}.ffn_norm.weight"), vec![hidden]),
            (format!("{prefix}.ffn_up.weight"), vec![hidden, ff]),
            (format!("{prefix}.post_attention_norm.weight"), vec![hidden]),
            (format!("{prefix}.post_ffw_norm.weight"), vec![hidden]),
        ]);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn architecture_dimensions_are_consistent() {
        assert_eq!(N_HEADS * HEAD_DIM, HIDDEN);
        assert_eq!(N_KV_HEADS * HEAD_DIM, KV_DIM);
        assert_eq!(expected_tensors().len(), 316);
    }

    #[test]
    fn local_attention_is_symmetric_and_periodic() {
        assert_eq!(attention_span(0, 1000, true), (0, 257));
        assert_eq!(attention_span(500, 1000, true), (244, 757));
        assert_eq!(attention_span(999, 1000, true), (743, 1000));
        assert_eq!(attention_span(500, 1000, false), (0, 1000));
        assert!(is_local_attention(0) && is_local_attention(4));
        assert!(!is_local_attention(5));
        assert!(is_local_attention(6));
    }

    #[test]
    fn matryoshka_dimensions_are_explicit() {
        assert_eq!(EMBEDDING_DIMENSIONS, [768, 512, 256, 128]);
    }

    #[test]
    #[ignore = "loads the 319 MB EmbeddingGemma GGUF"]
    fn real_model_loads_and_embeds() {
        let path = std::env::var("EMBEDDING_GEMMA_WEIGHTS_FILE")
            .unwrap_or_else(|_| "/root/bebelm/embeddinggemma-300M-Q8_0.gguf".into());
        let model = EmbeddingGemma::load(path).expect("load EmbeddingGemma");
        let out = model
            .embed(
                "task: search result | query: capital of Mali",
                768,
                true,
                true,
            )
            .expect("embed");
        assert_eq!(
            out.token_ids,
            vec![2, 8071, 236787, 3927, 1354, 1109, 7609, 236787, 5279, 529, 63037, 1]
        );
        assert_eq!(out.values.len(), 768);
        let norm = out.values.iter().map(|v| v * v).sum::<f32>().sqrt();
        assert!((norm - 1.0).abs() < 1e-5);

        let texts = [
            "task: search result | query: capital of Mali",
            "title: none | text: Rome is the capital city of Italy.",
        ];
        let tokenized: Vec<_> = texts
            .iter()
            .map(|text| model.tokenize(text, true).unwrap())
            .collect();
        let packed = model
            .embed_tokenized_batch(&tokenized, 768, true)
            .expect("packed embeddings");
        for (text, packed_output) in texts.iter().zip(&packed) {
            let independent = model.embed(text, 768, true, true).unwrap();
            let max_error = independent
                .values
                .iter()
                .zip(&packed_output.values)
                .map(|(a, b)| (a - b).abs())
                .fold(0.0f32, f32::max);
            assert!(max_error < 1e-6, "packed/independent max error {max_error}");
        }
    }
}
