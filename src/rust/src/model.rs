use std::sync::Arc;

use bebelm::cache::Cache;
use bebelm::config::HIDDEN;
use bebelm::model::Model;
use savvy::{savvy, FunctionSexp, IntegerSexp, OwnedIntegerSexp, OwnedListSexp, OwnedRealSexp, OwnedStringSexp, StringSexp};

use crate::chatml::{user_turn, ASSISTANT_OPEN};
use crate::generation::{run_generation, turn_to_list};
use crate::options::GenerationOptions;
use crate::util::{check_user_interrupt, checked_positive_usize, err, ids_from_integer, ids_to_sexp, init_rayon, str_scalar};

const DEFAULT_EMBED_TOKEN_BATCH: usize = 512;
const DEFAULT_EMBED_SEQUENCE_BATCH: usize = 64;

/// Loaded BebeLM GGUF model.
/// @export
#[savvy]
#[derive(Clone)]
pub struct BebelModel {
    pub(crate) inner: Arc<Model>,
    pub(crate) path: String,
}

#[savvy]
impl BebelModel {
    /// Load a GGUF model from disk.
    /// @export
    fn load(path: &str, num_threads: Option<f64>) -> savvy::Result<Self> {
        init_rayon(num_threads)?;
        let model = Model::load(path).map_err(|e| err(format!("cannot load BebeLM model: {e}")))?;
        Ok(Self {
            inner: Arc::new(model),
            path: path.to_string(),
        })
    }

    /// Return model and backend information.
    /// @export
    fn info(&self) -> savvy::Result<savvy::Sexp> {
        let mut out = OwnedListSexp::new(3, true)?;
        out.set_name_and_value(0, "path", str_scalar(&self.path)?)?;
        out.set_name_and_value(1, "backend", str_scalar(crate::backend::backend_name())?)?;
        out.set_name_and_value(2, "package", str_scalar("Rbebelm")?)?;
        out.into()
    }

    /// Tokenize text with the model tokenizer.
    /// @export
    fn encode(&self, text: &str, add_bos: bool) -> savvy::Result<savvy::Sexp> {
        ids_to_sexp(&self.inner.tokenizer().encode(text, add_bos))?.into()
    }

    /// Decode token ids with the model tokenizer.
    /// @export
    fn decode(&self, ids: IntegerSexp) -> savvy::Result<savvy::Sexp> {
        let ids = ids_from_integer(ids)?;
        str_scalar(&self.inner.tokenizer().decode(&ids))?.into()
    }

    /// Embed text by pooling final hidden states.
    /// @export
    fn embed(&self, text: &str, add_bos: bool, normalize: bool, pooling: &str) -> savvy::Result<savvy::Sexp> {
        let pooled = pooled_embedding(self.inner.as_ref(), text, add_bos, normalize, pooling, DEFAULT_EMBED_TOKEN_BATCH, false)?;
        let mut out = OwnedRealSexp::new(HIDDEN)?;
        for (i, value) in pooled.iter().enumerate() {
            out.set_elt(i, *value as f64)?;
        }
        out.into()
    }

    /// Embed a character vector by pooling final hidden states.
    /// @export
    fn embed_batch(
        &self,
        text: StringSexp,
        add_bos: bool,
        normalize: bool,
        pooling: &str,
        check_interrupt: bool,
        token_batch_size: Option<f64>,
        sequence_batch_size: Option<f64>,
    ) -> savvy::Result<savvy::Sexp> {
        let texts = text.to_vec();
        let token_batch_size = checked_positive_usize(token_batch_size, "token_batch_size")?.unwrap_or(DEFAULT_EMBED_TOKEN_BATCH);
        let sequence_batch_size = checked_positive_usize(sequence_batch_size, "sequence_batch_size")?.unwrap_or(DEFAULT_EMBED_SEQUENCE_BATCH);
        let n = texts.len();
        let rows = pooled_embeddings(
            self.inner.as_ref(),
            &texts,
            add_bos,
            normalize,
            pooling,
            token_batch_size,
            sequence_batch_size,
            check_interrupt,
        )?;
        let mut out = OwnedRealSexp::new(n * HIDDEN)?;
        {
            let values = out.as_mut_slice();
            for row in 0..n {
                let pooled = &rows[row * HIDDEN..(row + 1) * HIDDEN];
                for col in 0..HIDDEN {
                    values[row + col * n] = pooled[col] as f64;
                }
            }
        }
        out.set_dim(&[n, HIDDEN])?;
        out.into()
    }

    /// Embed each token with final hidden states.
    /// @export
    fn token_embeddings(
        &self,
        text: &str,
        add_bos: bool,
        normalize: bool,
        check_interrupt: bool,
        token_batch_size: Option<f64>,
    ) -> savvy::Result<savvy::Sexp> {
        let token_batch_size = checked_positive_usize(token_batch_size, "token_batch_size")?.unwrap_or(DEFAULT_EMBED_TOKEN_BATCH);
        token_embeddings_to_list(self.inner.as_ref(), text, add_bos, normalize, token_batch_size, check_interrupt)
    }

    /// Generate a raw continuation from a prompt.
    /// @export
    fn generate(
        &self,
        prompt: &str,
        greedy: bool,
        check_interrupt: bool,
        on_event: Option<FunctionSexp>,
        max_gen: Option<f64>,
        max_context: Option<f64>,
        max_think: Option<f64>,
        temperature: Option<f64>,
        top_k: Option<f64>,
        repeat_penalty: Option<f64>,
    ) -> savvy::Result<savvy::Sexp> {
        let mut opts = GenerationOptions::new(greedy, check_interrupt, on_event, max_gen, max_context, max_think, temperature, top_k, repeat_penalty)?;
        let history = self.inner.tokenizer().encode(prompt, true);
        let turn = run_generation(self.inner.as_ref(), history, &mut opts)?;
        turn_to_list(turn)
    }

    /// Start a raw continuation job on a background Rust thread.
    /// @export
    fn generate_async(
        &self,
        prompt: &str,
        greedy: bool,
        max_gen: Option<f64>,
        max_context: Option<f64>,
        max_think: Option<f64>,
        temperature: Option<f64>,
        top_k: Option<f64>,
        repeat_penalty: Option<f64>,
    ) -> savvy::Result<crate::async_job::BebelAsyncJob> {
        crate::async_job::spawn_model_generate(
            Arc::clone(&self.inner),
            prompt.to_string(),
            greedy,
            max_gen,
            max_context,
            max_think,
            temperature,
            top_k,
            repeat_penalty,
        )
    }

    /// Generate an assistant reply after one ChatML user turn.
    /// @export
    fn chat(
        &self,
        message: &str,
        greedy: bool,
        check_interrupt: bool,
        on_event: Option<FunctionSexp>,
        max_gen: Option<f64>,
        max_context: Option<f64>,
        max_think: Option<f64>,
        temperature: Option<f64>,
        top_k: Option<f64>,
        repeat_penalty: Option<f64>,
    ) -> savvy::Result<savvy::Sexp> {
        let mut opts = GenerationOptions::new(greedy, check_interrupt, on_event, max_gen, max_context, max_think, temperature, top_k, repeat_penalty)?;
        let mut history = self.inner.tokenizer().encode(&user_turn(message), true);
        history.extend(self.inner.tokenizer().encode(ASSISTANT_OPEN, false));
        let turn = run_generation(self.inner.as_ref(), history, &mut opts)?;
        turn_to_list(turn)
    }

    /// Start a single ChatML assistant reply job on a background Rust thread.
    /// @export
    fn chat_async(
        &self,
        message: &str,
        greedy: bool,
        max_gen: Option<f64>,
        max_context: Option<f64>,
        max_think: Option<f64>,
        temperature: Option<f64>,
        top_k: Option<f64>,
        repeat_penalty: Option<f64>,
    ) -> savvy::Result<crate::async_job::BebelAsyncJob> {
        crate::async_job::spawn_model_chat(
            Arc::clone(&self.inner),
            message.to_string(),
            greedy,
            max_gen,
            max_context,
            max_think,
            temperature,
            top_k,
            repeat_penalty,
        )
    }
}

fn pooled_embedding(
    model: &Model,
    text: &str,
    add_bos: bool,
    normalize: bool,
    pooling: &str,
    token_batch_size: usize,
    check_interrupt: bool,
) -> savvy::Result<Vec<f32>> {
    let ids = model.tokenizer().encode(text, add_bos);
    if ids.is_empty() {
        return Err(err("text produced no tokens"));
    }
    let mut cache = Cache::new();
    let mut pooled = vec![0.0f32; HIDDEN];
    match pooling {
        "mean" => {
            for chunk in ids.chunks(token_batch_size) {
                if check_interrupt {
                    check_user_interrupt()?;
                }
                let hidden = model.hidden_batch(chunk, &mut cache);
                for row in hidden.chunks_exact(HIDDEN) {
                    for (acc, v) in pooled.iter_mut().zip(row.iter()) {
                        *acc += *v;
                    }
                }
            }
            let denom = ids.len() as f32;
            for v in pooled.iter_mut() {
                *v /= denom;
            }
        }
        "last" => {
            for chunk in ids.chunks(token_batch_size) {
                if check_interrupt {
                    check_user_interrupt()?;
                }
                let hidden = model.hidden_batch(chunk, &mut cache);
                let last = &hidden[hidden.len() - HIDDEN..];
                pooled.copy_from_slice(last);
            }
        }
        other => {
            return Err(err(format!("unsupported pooling mode {other:?}; use \"mean\" or \"last\"")));
        }
    }
    if normalize {
        normalize_embedding(&mut pooled);
    }
    Ok(pooled)
}

fn pooled_embeddings(
    model: &Model,
    texts: &[&str],
    add_bos: bool,
    normalize: bool,
    pooling: &str,
    token_batch_size: usize,
    sequence_batch_size: usize,
    check_interrupt: bool,
) -> savvy::Result<Vec<f32>> {
    if texts.is_empty() {
        return Ok(Vec::new());
    }
    if texts.len() == 1 {
        return pooled_embedding(model, texts[0], add_bos, normalize, pooling, token_batch_size, check_interrupt);
    }
    if !matches!(pooling, "mean" | "last") {
        return Err(err(format!("unsupported pooling mode {pooling:?}; use \"mean\" or \"last\"")));
    }

    let n = texts.len();
    let mut pooled = vec![0.0f32; n * HIDDEN];

    for start in (0..n).step_by(sequence_batch_size) {
        let end = (start + sequence_batch_size).min(n);
        let ids: Vec<Vec<u32>> = texts[start..end]
            .iter()
            .enumerate()
            .map(|(i, text)| {
                let ids = model.tokenizer().encode(text, add_bos);
                if ids.is_empty() {
                    Err(err(format!("text at index {} produced no tokens", start + i + 1)))
                } else {
                    Ok(ids)
                }
            })
            .collect::<savvy::Result<Vec<_>>>()?;

        let local_n = ids.len();
        let mut caches: Vec<Cache> = (0..local_n).map(|_| Cache::new()).collect();
        let max_len = ids.iter().map(Vec::len).max().unwrap_or(0);

        for depth in 0..max_len {
            let active: Vec<usize> = ids
                .iter()
                .enumerate()
                .filter_map(|(i, one)| (depth < one.len()).then_some(i))
                .collect();
            if active.is_empty() {
                continue;
            }
            if check_interrupt {
                check_user_interrupt()?;
            }
            let tokens: Vec<u32> = active.iter().map(|&i| ids[i][depth]).collect();
            let mut active_caches: Vec<Cache> = active
                .iter()
                .map(|&i| std::mem::take(&mut caches[i]))
                .collect();
            let mut cache_refs: Vec<&mut Cache> = active_caches.iter_mut().collect();
            let hidden = model.hidden_independent_batch(&tokens, &mut cache_refs);
            drop(cache_refs);

            for (j, &local_row) in active.iter().enumerate() {
                let src = &hidden[j * HIDDEN..(j + 1) * HIDDEN];
                let row = start + local_row;
                let dst = &mut pooled[row * HIDDEN..(row + 1) * HIDDEN];
                if pooling == "mean" {
                    for (d, s) in dst.iter_mut().zip(src.iter()) {
                        *d += *s;
                    }
                } else {
                    dst.copy_from_slice(src);
                }
            }
            for (cache, &local_row) in active_caches.into_iter().zip(active.iter()) {
                caches[local_row] = cache;
            }
        }

        if pooling == "mean" {
            for (local_row, one) in ids.iter().enumerate() {
                let denom = one.len() as f32;
                let row = start + local_row;
                for v in &mut pooled[row * HIDDEN..(row + 1) * HIDDEN] {
                    *v /= denom;
                }
            }
        }
        if normalize {
            for local_row in 0..local_n {
                let row = start + local_row;
                normalize_embedding(&mut pooled[row * HIDDEN..(row + 1) * HIDDEN]);
            }
        }
    }
    Ok(pooled)
}

fn token_embeddings_to_list(
    model: &Model,
    text: &str,
    add_bos: bool,
    normalize: bool,
    token_batch_size: usize,
    check_interrupt: bool,
) -> savvy::Result<savvy::Sexp> {
    let ids = model.tokenizer().encode(text, add_bos);
    if ids.is_empty() {
        return Err(err("text produced no tokens"));
    }
    let n = ids.len();
    let mut cache = Cache::new();
    let mut embeddings = vec![0.0f32; n * HIDDEN];
    let mut row = 0usize;
    for chunk in ids.chunks(token_batch_size) {
        if check_interrupt {
            check_user_interrupt()?;
        }
        let hidden = model.hidden_batch(chunk, &mut cache);
        for chunk_row in 0..chunk.len() {
            let src = &hidden[chunk_row * HIDDEN..(chunk_row + 1) * HIDDEN];
            let dst = &mut embeddings[row * HIDDEN..(row + 1) * HIDDEN];
            dst.copy_from_slice(src);
            if normalize {
                normalize_embedding(dst);
            }
            row += 1;
        }
    }

    let mut matrix = OwnedRealSexp::new(n * HIDDEN)?;
    {
        let values = matrix.as_mut_slice();
        for r in 0..n {
            for col in 0..HIDDEN {
                values[r + col * n] = embeddings[r * HIDDEN + col] as f64;
            }
        }
    }
    matrix.set_dim(&[n, HIDDEN])?;

    let mut token_index = OwnedIntegerSexp::new(n)?;
    for i in 0..n {
        let value = i32::try_from(i).map_err(|_| err("token index does not fit in R integer"))?;
        token_index.set_elt(i, value)?;
    }

    let mut tokens = OwnedStringSexp::new(n)?;
    for (i, &id) in ids.iter().enumerate() {
        tokens.set_elt(i, &model.tokenizer().decode(&[id]))?;
    }

    let mut out = OwnedListSexp::new(6, true)?;
    out.set_name_and_value(0, "text", str_scalar(text)?)?;
    out.set_name_and_value(1, "ids", ids_to_sexp(&ids)?)?;
    out.set_name_and_value(2, "tokens", tokens)?;
    out.set_name_and_value(3, "token_index", token_index)?;
    out.set_name_and_value(4, "embeddings", matrix)?;
    out.set_name_and_value(5, "normalized", crate::util::bool_scalar(normalize)?)?;
    out.into()
}

fn normalize_embedding(values: &mut [f32]) {
    let norm = values.iter().map(|v| (*v as f64) * (*v as f64)).sum::<f64>().sqrt();
    if norm > 0.0 && norm.is_finite() {
        for v in values.iter_mut() {
            *v = (*v as f64 / norm) as f32;
        }
    }
}
