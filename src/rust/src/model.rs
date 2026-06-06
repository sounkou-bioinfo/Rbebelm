use std::sync::Arc;

use bebelm::model::Model;
use bebelm::tokenizer::Tokenizer;
use savvy::{savvy, FunctionSexp, IntegerSexp, OwnedListSexp};

use crate::chatml::{user_turn, ASSISTANT_OPEN};
use crate::generation::{run_one_shot, turn_to_list};
use crate::options::GenerationOptions;
use crate::util::{err, ids_from_integer, ids_to_sexp, init_rayon, str_scalar};

/// Loaded BebeLM GGUF model.
/// @export
#[savvy]
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
        let tok = Tokenizer::from_gguf(self.inner.gguf()).map_err(|e| err(format!("cannot create BebeLM tokenizer: {e}")))?;
        ids_to_sexp(&tok.encode(text, add_bos))?.into()
    }

    /// Decode token ids with the model tokenizer.
    /// @export
    fn decode(&self, ids: IntegerSexp) -> savvy::Result<savvy::Sexp> {
        let tok = Tokenizer::from_gguf(self.inner.gguf()).map_err(|e| err(format!("cannot create BebeLM tokenizer: {e}")))?;
        let ids = ids_from_integer(ids)?;
        str_scalar(&tok.decode(&ids))?.into()
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
        let tok = Tokenizer::from_gguf(self.inner.gguf()).map_err(|e| err(format!("cannot create BebeLM tokenizer: {e}")))?;
        let history = tok.encode(prompt, true);
        let turn = run_one_shot(self.inner.as_ref(), tok, history, &mut opts)?;
        turn_to_list(turn)
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
        let tok = Tokenizer::from_gguf(self.inner.gguf()).map_err(|e| err(format!("cannot create BebeLM tokenizer: {e}")))?;
        let mut history = tok.encode(&user_turn(message), true);
        history.extend(tok.encode(ASSISTANT_OPEN, false));
        let turn = run_one_shot(self.inner.as_ref(), tok, history, &mut opts)?;
        turn_to_list(turn)
    }
}
