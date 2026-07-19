use std::sync::Arc;

use bebelm::model::Model;
use savvy::{savvy, FunctionSexp, IntegerSexp, OwnedListSexp};

use crate::chatml::{user_turn, ASSISTANT_OPEN};
use crate::generation::{run_generation, turn_to_list};
use crate::options::GenerationOptions;
use crate::util::{err, ids_from_integer, ids_to_sexp, init_rayon, str_scalar};

/// Loaded BebeLM GGUF generation model.
/// @export
#[savvy]
#[derive(Clone)]
pub struct BebelModel {
    pub(crate) inner: Arc<Model>,
    pub(crate) path: String,
}

#[savvy]
impl BebelModel {
    /// Load a supported BebeLM generation GGUF from disk.
    /// @export
    fn load(path: &str, num_threads: Option<f64>) -> savvy::Result<Self> {
        init_rayon(num_threads)?;
        let model = Model::load(path).map_err(|error| err(format!("cannot load BebeLM model: {error}")))?;
        Ok(Self { inner: Arc::new(model), path: path.to_string() })
    }

    /// Return model and backend information.
    /// @export
    fn info(&self) -> savvy::Result<savvy::Sexp> {
        let mut out = OwnedListSexp::new(5, true)?;
        out.set_name_and_value(0, "path", str_scalar(&self.path)?)?;
        out.set_name_and_value(1, "architecture", str_scalar(&self.inner.architecture().to_string())?)?;
        out.set_name_and_value(2, "profile", str_scalar(self.inner.profile_name())?)?;
        out.set_name_and_value(3, "backend", str_scalar(crate::backend::backend_name())?)?;
        out.set_name_and_value(4, "package", str_scalar("Rbebelm")?)?;
        out.into()
    }

    /// Tokenize text with the generation model tokenizer.
    /// @export
    fn encode(&self, text: &str, add_bos: bool) -> savvy::Result<savvy::Sexp> {
        ids_to_sexp(&self.inner.tokenizer().encode(text, add_bos))?.into()
    }

    /// Decode token ids with the generation model tokenizer.
    /// @export
    fn decode(&self, ids: IntegerSexp) -> savvy::Result<savvy::Sexp> {
        let ids = ids_from_integer(ids)?;
        str_scalar(&self.inner.tokenizer().decode(&ids))?.into()
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
        let mut options = GenerationOptions::new(
            greedy,
            check_interrupt,
            on_event,
            max_gen,
            max_context,
            max_think,
            temperature,
            top_k,
            repeat_penalty,
        )?;
        let history = self.inner.tokenizer().encode(prompt, true);
        turn_to_list(run_generation(self.inner.as_ref(), history, &mut options)?)
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
        let mut options = GenerationOptions::new(
            greedy,
            check_interrupt,
            on_event,
            max_gen,
            max_context,
            max_think,
            temperature,
            top_k,
            repeat_penalty,
        )?;
        let mut history = self.inner.tokenizer().encode(&user_turn(message), true);
        history.extend(self.inner.tokenizer().encode(ASSISTANT_OPEN, false));
        turn_to_list(run_generation(self.inner.as_ref(), history, &mut options)?)
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
