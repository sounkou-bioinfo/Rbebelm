use std::sync::{Arc, Mutex};

use bebelm::cache::Cache;
use bebelm::config::HIDDEN;
use bebelm::model::Model;
use savvy::{savvy, FunctionSexp, IntegerSexp, OwnedListSexp, OwnedRealSexp, StringSexp};

use crate::chatml::{user_turn, ASSISTANT_OPEN};
use crate::generation::{run_generation, turn_to_list};
use crate::options::GenerationOptions;
use crate::util::{check_user_interrupt, checked_positive_usize, err, ids_from_integer, ids_to_sexp, init_rayon, str_scalar};

const DEFAULT_EMBED_TOKEN_BATCH: usize = 512;

/// Loaded BebeLM GGUF model.
/// @export
#[savvy]
#[derive(Clone)]
pub struct BebelModel {
    pub(crate) inner: Arc<Model>,
    pub(crate) exec_lock: Arc<Mutex<()>>,
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
            exec_lock: Arc::new(Mutex::new(())),
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
        let _guard = self.exec_lock.lock().map_err(|_| err("model execution lock poisoned"))?;
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
    ) -> savvy::Result<savvy::Sexp> {
        let texts = text.to_vec();
        let token_batch_size = checked_positive_usize(token_batch_size, "token_batch_size")?.unwrap_or(DEFAULT_EMBED_TOKEN_BATCH);
        let n = texts.len();
        let _guard = self.exec_lock.lock().map_err(|_| err("model execution lock poisoned"))?;
        let mut out = OwnedRealSexp::new(n * HIDDEN)?;
        {
            let values = out.as_mut_slice();
            for (row, one) in texts.iter().enumerate() {
                if check_interrupt {
                    check_user_interrupt()?;
                }
                let pooled = pooled_embedding(self.inner.as_ref(), one, add_bos, normalize, pooling, token_batch_size, check_interrupt)?;
                for col in 0..HIDDEN {
                    values[row + col * n] = pooled[col] as f64;
                }
            }
        }
        out.set_dim(&[n, HIDDEN])?;
        out.into()
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
        let _guard = self.exec_lock.lock().map_err(|_| err("model execution lock poisoned"))?;
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
            Arc::clone(&self.exec_lock),
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
        let _guard = self.exec_lock.lock().map_err(|_| err("model execution lock poisoned"))?;
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
            Arc::clone(&self.exec_lock),
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

fn normalize_embedding(values: &mut [f32]) {
    let norm = values.iter().map(|v| (*v as f64) * (*v as f64)).sum::<f64>().sqrt();
    if norm > 0.0 && norm.is_finite() {
        for v in values.iter_mut() {
            *v = (*v as f64 / norm) as f32;
        }
    }
}
