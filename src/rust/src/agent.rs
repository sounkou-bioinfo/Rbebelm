use std::sync::Arc;

use bebelm::agent::Turn;
use bebelm::cache::Cache;
use bebelm::model::Model;
use bebelm::sampler::Sampler;
use bebelm::tokenizer::TOKEN_IM_END;
use savvy::{savvy, FunctionSexp, IntegerSexp, OwnedListSexp, StringSexp};

use crate::chatml::{tool_turn, user_turn, ASSISTANT_OPEN};
use crate::events::EventQueue;
use crate::generation::{absorb_tokens, run_state, turn_to_list};
use crate::model::BebelModel;
use crate::options::{maybe_update_sampler, GenerationOptions};
use crate::tools::render_system_turn;
use crate::util::{checked_positive_usize, checked_usize, ids_from_integer, ids_to_sexp, int_scalar, real_scalar, str_scalar};

/// Persistent BebeLM conversation agent with transcript and decode caches.
/// @export
#[savvy]
#[derive(Clone)]
pub struct BebelAgent {
    model: Arc<Model>,
    model_path: String,
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
        Ok(Self {
            model: Arc::clone(&model.inner),
            model_path: model.path.clone(),
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
        self.append_text(text);
        self.info()
    }

    /// Append an upstream-rendered ChatML system turn to the transcript.
    /// @export
    fn append_system(&mut self, message: &str) -> savvy::Result<savvy::Sexp> {
        let block = render_system_turn(message, &[], &[])?;
        self.append(&block)
    }

    /// Append an upstream-rendered ChatML system turn with tool schemas to the transcript.
    /// @export
    fn append_system_with_tools(&mut self, message: &str, tool_names: StringSexp, tool_schemas: StringSexp) -> savvy::Result<savvy::Sexp> {
        let names = tool_names.to_vec();
        let schemas = tool_schemas.to_vec();
        let block = render_system_turn(message, &names, &schemas)?;
        self.append(&block)
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
        turn_to_list(self.generate_turn(check_interrupt, on_event)?)
    }

    /// Start a raw continuation job on a cloned agent snapshot.
    /// @export
    fn generate_async(&self) -> savvy::Result<crate::async_job::BebelAsyncJob> {
        Ok(crate::async_job::spawn_agent_generate(Clone::clone(self)))
    }

    /// Prefill appended-but-unprocessed prompt tokens into the decode caches.
    /// @export
    fn prefill(&mut self, check_interrupt: bool) -> savvy::Result<savvy::Sexp> {
        let start = self.cache.pos;
        let end = self.history.len().saturating_sub(1);
        if start < end {
            absorb_tokens(
                self.model.as_ref(),
                &mut self.cache,
                &self.history[start..end],
                self.max_context,
                check_interrupt,
            )?;
        }
        self.info()
    }

    /// Clone this agent, including transcript and warmed decode caches.
    /// @export
    fn clone(&self) -> savvy::Result<Self> {
        Ok(Clone::clone(self))
    }

    /// Open an assistant ChatML turn, generate it, then close the assistant turn.
    /// @export
    fn assistant_turn(&mut self, check_interrupt: bool, on_event: Option<FunctionSexp>) -> savvy::Result<savvy::Sexp> {
        turn_to_list(self.assistant_turn_impl(check_interrupt, on_event, false)?)
    }

    /// Start an assistant ChatML turn job on a cloned agent snapshot.
    /// @export
    fn assistant_turn_async(&self) -> savvy::Result<crate::async_job::BebelAsyncJob> {
        Ok(crate::async_job::spawn_agent_assistant_turn(Clone::clone(self), false))
    }

    /// Open an assistant turn and stop when the model closes a tool call.
    /// @export
    fn assistant_turn_tool_stop(&mut self, check_interrupt: bool, on_event: Option<FunctionSexp>) -> savvy::Result<savvy::Sexp> {
        turn_to_list(self.assistant_turn_impl(check_interrupt, on_event, true)?)
    }

    /// Start an assistant-turn job that stops on a tool-call delimiter.
    /// @export
    fn assistant_turn_tool_stop_async(&self) -> savvy::Result<crate::async_job::BebelAsyncJob> {
        Ok(crate::async_job::spawn_agent_assistant_turn(Clone::clone(self), true))
    }

    /// Clear transcript and caches, keeping weights and generation configuration.
    /// @export
    fn clear(&mut self) -> savvy::Result<savvy::Sexp> {
        self.history.clear();
        self.cache = Cache::new();
        self.sampler.reset();
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
        str_scalar(&self.model.tokenizer().decode(&self.history))?.into()
    }
}

impl BebelAgent {
    fn append_text(&mut self, text: &str) {
        let add_bos = self.history.is_empty();
        let ids = self.model.tokenizer().encode(text, add_bos);
        self.history.extend(ids);
    }

    pub(crate) fn generate_turn(&mut self, check_interrupt: bool, on_event: Option<FunctionSexp>) -> savvy::Result<Turn> {
        self.generate_turn_with_events(check_interrupt, on_event, None)
    }

    pub(crate) fn generate_turn_with_events(
        &mut self,
        check_interrupt: bool,
        on_event: Option<FunctionSexp>,
        event_queue: Option<&EventQueue>,
    ) -> savvy::Result<Turn> {
        run_state(
            self.model.as_ref(),
            &mut self.cache,
            &mut self.history,
            &mut self.sampler,
            check_interrupt,
            &on_event,
            event_queue,
            self.max_gen,
            self.max_context,
            self.max_think,
            false,
        )
    }

    pub(crate) fn assistant_turn_impl(&mut self, check_interrupt: bool, on_event: Option<FunctionSexp>, stop_on_tool_call: bool) -> savvy::Result<Turn> {
        self.assistant_turn_impl_with_events(check_interrupt, on_event, stop_on_tool_call, None)
    }

    pub(crate) fn assistant_turn_impl_with_events(
        &mut self,
        check_interrupt: bool,
        on_event: Option<FunctionSexp>,
        stop_on_tool_call: bool,
        event_queue: Option<&EventQueue>,
    ) -> savvy::Result<Turn> {
        self.append_text(ASSISTANT_OPEN);
        let turn = run_state(
            self.model.as_ref(),
            &mut self.cache,
            &mut self.history,
            &mut self.sampler,
            check_interrupt,
            &on_event,
            event_queue,
            self.max_gen,
            self.max_context,
            self.max_think,
            stop_on_tool_call,
        )?;
        self.history.push(TOKEN_IM_END);
        let newline = self.model.tokenizer().encode("\n", false);
        self.history.extend(newline);
        Ok(turn)
    }
}
