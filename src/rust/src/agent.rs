use std::sync::Arc;

use bebelm::cache::Cache;
use bebelm::model::Model;
use bebelm::sampler::Sampler;
use bebelm::tokenizer::{Tokenizer, TOKEN_IM_END};
use savvy::{savvy, FunctionSexp, IntegerSexp, OwnedListSexp};

use crate::chatml::{system_turn, tool_turn, user_turn, ASSISTANT_OPEN};
use crate::generation::{run_state, turn_to_list};
use crate::model::BebelModel;
use crate::options::{maybe_update_sampler, GenerationOptions};
use crate::util::{checked_positive_usize, checked_usize, err, ids_from_integer, ids_to_sexp, int_scalar, real_scalar, str_scalar};

/// Persistent BebeLM conversation agent with transcript and decode caches.
/// @export
#[savvy]
pub struct BebelAgent {
    model: Arc<Model>,
    model_path: String,
    tok: Tokenizer,
    cache: Cache,
    sampler: Sampler,
    history: Vec<u32>,
    max_gen: usize,
    max_context: usize,
    max_think: usize,
}

#[savvy]
impl BebelAgent {
    /// Create an independent agent backed by a loaded model.
    /// @export
    fn new(
        model: &BebelModel,
        greedy: bool,
        max_gen: Option<f64>,
        max_context: Option<f64>,
        max_think: Option<f64>,
        temperature: Option<f64>,
        top_k: Option<f64>,
        repeat_penalty: Option<f64>,
    ) -> savvy::Result<Self> {
        let opts = GenerationOptions::new(greedy, true, None, max_gen, max_context, max_think, temperature, top_k, repeat_penalty)?;
        let tok = Tokenizer::from_gguf(model.inner.gguf()).map_err(|e| err(format!("cannot create BebeLM tokenizer: {e}")))?;
        Ok(Self {
            model: Arc::clone(&model.inner),
            model_path: model.path.clone(),
            tok,
            cache: Cache::new(),
            sampler: opts.sampler,
            history: Vec::new(),
            max_gen: opts.max_gen,
            max_context: opts.max_context,
            max_think: opts.max_think,
        })
    }

    /// Return agent state and generation configuration.
    /// @export
    fn info(&self) -> savvy::Result<savvy::Sexp> {
        let mut out = OwnedListSexp::new(10, true)?;
        out.set_name_and_value(0, "model_path", str_scalar(&self.model_path)?)?;
        out.set_name_and_value(1, "backend", str_scalar(crate::backend::backend_name())?)?;
        out.set_name_and_value(2, "history_tokens", int_scalar(self.history.len() as i32)?)?;
        out.set_name_and_value(3, "processed_tokens", int_scalar(self.cache.pos as i32)?)?;
        out.set_name_and_value(4, "kv_tokens", int_scalar(self.cache.kv_len() as i32)?)?;
        out.set_name_and_value(5, "max_gen", int_scalar(self.max_gen as i32)?)?;
        out.set_name_and_value(6, "max_context", int_scalar(self.max_context as i32)?)?;
        out.set_name_and_value(7, "max_think", real_scalar(self.max_think as f64)?)?;
        out.set_name_and_value(8, "temperature", real_scalar(self.sampler.temperature as f64)?)?;
        out.set_name_and_value(9, "top_k", int_scalar(self.sampler.top_k as i32)?)?;
        out.into()
    }

    /// Update generation configuration in place.
    /// @export
    fn configure(
        &mut self,
        greedy: Option<bool>,
        max_gen: Option<f64>,
        max_context: Option<f64>,
        max_think: Option<f64>,
        temperature: Option<f64>,
        top_k: Option<f64>,
        repeat_penalty: Option<f64>,
    ) -> savvy::Result<savvy::Sexp> {
        maybe_update_sampler(&mut self.sampler, greedy, temperature, top_k, repeat_penalty)?;
        if let Some(n) = checked_usize(max_gen, "max_gen")? {
            self.max_gen = n;
        }
        if let Some(n) = checked_positive_usize(max_context, "max_context")? {
            self.max_context = n;
        }
        if let Some(n) = checked_usize(max_think, "max_think")? {
            self.max_think = n;
        }
        self.info()
    }

    /// Append raw text to the transcript. BOS is added automatically for the first append.
    /// @export
    fn append(&mut self, text: &str) -> savvy::Result<savvy::Sexp> {
        let add_bos = self.history.is_empty();
        let ids = self.tok.encode(text, add_bos);
        self.history.extend(ids);
        self.info()
    }

    /// Append a ChatML system turn to the transcript.
    /// @export
    fn append_system(&mut self, message: &str) -> savvy::Result<savvy::Sexp> {
        self.append(&system_turn(message))
    }

    /// Append a ChatML user turn to the transcript.
    /// @export
    fn append_user(&mut self, message: &str) -> savvy::Result<savvy::Sexp> {
        self.append(&user_turn(message))
    }

    /// Append a ChatML tool result turn to the transcript.
    /// @export
    fn append_tool_result(&mut self, content: &str) -> savvy::Result<savvy::Sexp> {
        self.append(&tool_turn(content))
    }

    /// Append already-tokenized ids to the transcript.
    /// @export
    fn append_tokens(&mut self, ids: IntegerSexp) -> savvy::Result<savvy::Sexp> {
        let ids = ids_from_integer(ids)?;
        self.history.extend(ids);
        self.info()
    }

    /// Generate a raw continuation from the current transcript.
    /// @export
    fn generate(&mut self, check_interrupt: bool, on_event: Option<FunctionSexp>) -> savvy::Result<savvy::Sexp> {
        let turn = run_state(
            self.model.as_ref(),
            &self.tok,
            &mut self.cache,
            &mut self.history,
            &mut self.sampler,
            check_interrupt,
            &on_event,
            self.max_gen,
            self.max_context,
            self.max_think,
        )?;
        turn_to_list(turn)
    }

    /// Open an assistant ChatML turn, generate it, then close the assistant turn.
    /// @export
    fn assistant_turn(&mut self, check_interrupt: bool, on_event: Option<FunctionSexp>) -> savvy::Result<savvy::Sexp> {
        self.append(ASSISTANT_OPEN)?;
        let turn = run_state(
            self.model.as_ref(),
            &self.tok,
            &mut self.cache,
            &mut self.history,
            &mut self.sampler,
            check_interrupt,
            &on_event,
            self.max_gen,
            self.max_context,
            self.max_think,
        )?;
        self.history.push(TOKEN_IM_END);
        let newline = self.tok.encode("\n", false);
        self.history.extend(newline);
        turn_to_list(turn)
    }

    /// Clear transcript and caches, keeping weights and generation configuration.
    /// @export
    fn clear(&mut self) -> savvy::Result<savvy::Sexp> {
        self.history.clear();
        self.cache = Cache::new();
        self.info()
    }

    /// Return the full token transcript.
    /// @export
    fn history(&self) -> savvy::Result<savvy::Sexp> {
        ids_to_sexp(&self.history)?.into()
    }

    /// Decode the current token transcript.
    /// @export
    fn transcript(&self) -> savvy::Result<savvy::Sexp> {
        str_scalar(&self.tok.decode(&self.history))?.into()
    }
}
