use std::sync::Arc;

use bebelm::cache::Cache;
use bebelm::config::HIDDEN;
use bebelm::model::Model;
use savvy::{savvy, FunctionSexp, IntegerSexp, OwnedListSexp, OwnedRealSexp};

use crate::chatml::{user_turn, ASSISTANT_OPEN};
use crate::generation::{run_generation, turn_to_list};
use crate::options::GenerationOptions;
use crate::util::{err, ids_from_integer, ids_to_sexp, init_rayon, str_scalar};

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
        let ids = self.inner.tokenizer().encode(text, add_bos);
        if ids.is_empty() {
            return Err(err("text produced no tokens"));
        }
        let mut cache = Cache::new();
        let mut pooled = vec![0.0f32; HIDDEN];
        match pooling {
            "mean" => {
                for token in ids.iter().copied() {
                    let h = self.inner.hidden_step(token, &mut cache);
                    for (acc, v) in pooled.iter_mut().zip(h.iter()) {
                        *acc += *v;
                    }
                }
                let denom = ids.len() as f32;
                for v in pooled.iter_mut() {
                    *v /= denom;
                }
            }
            "last" => {
                for token in ids.iter().copied() {
                    pooled = self.inner.hidden_step(token, &mut cache);
                }
            }
            other => {
                return Err(err(format!("unsupported pooling mode {other:?}; use \"mean\" or \"last\"")));
            }
        }
        if normalize {
            let norm = pooled.iter().map(|v| (*v as f64) * (*v as f64)).sum::<f64>().sqrt();
            if norm > 0.0 && norm.is_finite() {
                for v in pooled.iter_mut() {
                    *v = (*v as f64 / norm) as f32;
                }
            }
        }
        let mut out = OwnedRealSexp::new(HIDDEN)?;
        for (i, value) in pooled.iter().enumerate() {
            out.set_elt(i, *value as f64)?;
        }
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
