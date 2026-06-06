use savvy::{savvy, FunctionSexp, IntegerSexp, OwnedIntegerSexp, OwnedListSexp, OwnedStringSexp};

use crate::util::{err, int_scalar, str_scalar};

const EVENT_TYPES: &[&str] = &[
    "start",
    "thinking_start",
    "thinking_delta",
    "thinking_end",
    "text_start",
    "text_delta",
    "text_end",
    "tool_list_start",
    "tool_list_delta",
    "tool_list_end",
    "tool_call_start",
    "tool_call_delta",
    "tool_call_end",
    "done",
];

const TOKEN_IDS: &[(&str, i32)] = &[
    ("TOKEN_PAD", 124_893),
    ("TOKEN_BOS", 124_894),
    ("TOKEN_ENDOFTEXT", 124_895),
    ("TOKEN_FIM_PRE", 124_896),
    ("TOKEN_FIM_MID", 124_897),
    ("TOKEN_FIM_SUF", 124_898),
    ("TOKEN_IM_START", 124_899),
    ("TOKEN_IM_END", 124_900),
    ("TOKEN_EOS", 124_900),
    ("TOKEN_THINK", 124_901),
    ("TOKEN_THINK_END", 124_902),
    ("TOKEN_TOOL_LIST_START", 124_903),
    ("TOKEN_TOOL_LIST_END", 124_904),
    ("TOKEN_TOOL_CALL_START", 124_905),
    ("TOKEN_TOOL_CALL_END", 124_906),
];

fn unsupported() -> savvy::Error {
    err("BebeLM GGUF inference is not supported in webR/Emscripten builds; use desktop R for model loading/generation")
}

/// Return BebeLM stream event types.
/// @export
#[cfg_attr(target_os = "emscripten", savvy)]
pub fn bebel_event_types() -> savvy::Result<savvy::Sexp> {
    let mut out = OwnedStringSexp::new(EVENT_TYPES.len())?;
    for (i, event_type) in EVENT_TYPES.iter().enumerate() {
        out.set_elt(i, event_type)?;
    }
    out.into()
}

/// Return BebeLM tokenizer special token ids.
/// @export
#[cfg_attr(target_os = "emscripten", savvy)]
pub fn bebel_token_ids() -> savvy::Result<savvy::Sexp> {
    let mut out = OwnedIntegerSexp::new(TOKEN_IDS.len())?;
    for (i, &(_, id)) in TOKEN_IDS.iter().enumerate() {
        out.set_elt(i, id)?;
    }
    let names: Vec<&str> = TOKEN_IDS.iter().map(|&(name, _)| name).collect();
    out.set_names(names)?;
    out.into()
}

/// Loaded BebeLM GGUF model.
/// @export
#[cfg_attr(target_os = "emscripten", savvy)]
pub struct BebelModel {
    path: String,
}

#[cfg_attr(target_os = "emscripten", savvy)]
impl BebelModel {
    /// Load a GGUF model from disk.
    /// @export
    fn load(path: &str, _num_threads: Option<f64>) -> savvy::Result<Self> {
        let _ = path;
        Err(unsupported())
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
    fn encode(&self, _text: &str, _add_bos: bool) -> savvy::Result<savvy::Sexp> {
        Err(unsupported())
    }

    /// Decode token ids with the model tokenizer.
    /// @export
    fn decode(&self, _ids: IntegerSexp) -> savvy::Result<savvy::Sexp> {
        Err(unsupported())
    }

    /// Generate a raw continuation from a prompt.
    /// @export
    fn generate(
        &self,
        _prompt: &str,
        _greedy: bool,
        _check_interrupt: bool,
        _on_event: Option<FunctionSexp>,
        _max_gen: Option<f64>,
        _max_context: Option<f64>,
        _max_think: Option<f64>,
        _temperature: Option<f64>,
        _top_k: Option<f64>,
        _repeat_penalty: Option<f64>,
    ) -> savvy::Result<savvy::Sexp> {
        Err(unsupported())
    }

    /// Generate an assistant reply after one ChatML user turn.
    /// @export
    fn chat(
        &self,
        _message: &str,
        _greedy: bool,
        _check_interrupt: bool,
        _on_event: Option<FunctionSexp>,
        _max_gen: Option<f64>,
        _max_context: Option<f64>,
        _max_think: Option<f64>,
        _temperature: Option<f64>,
        _top_k: Option<f64>,
        _repeat_penalty: Option<f64>,
    ) -> savvy::Result<savvy::Sexp> {
        Err(unsupported())
    }
}

/// Persistent BebeLM conversation agent with transcript and decode caches.
/// @export
#[cfg_attr(target_os = "emscripten", savvy)]
pub struct BebelAgent {}

#[cfg_attr(target_os = "emscripten", savvy)]
impl BebelAgent {
    /// Create an independent agent backed by a loaded model.
    /// @export
    fn new(
        _model: &BebelModel,
        _greedy: bool,
        _max_gen: Option<f64>,
        _max_context: Option<f64>,
        _max_think: Option<f64>,
        _temperature: Option<f64>,
        _top_k: Option<f64>,
        _repeat_penalty: Option<f64>,
    ) -> savvy::Result<Self> {
        Err(unsupported())
    }

    /// Return agent state and generation configuration.
    /// @export
    fn info(&self) -> savvy::Result<savvy::Sexp> {
        let mut out = OwnedListSexp::new(5, true)?;
        out.set_name_and_value(0, "backend", str_scalar(crate::backend::backend_name())?)?;
        out.set_name_and_value(1, "history_tokens", int_scalar(0)?)?;
        out.set_name_and_value(2, "processed_tokens", int_scalar(0)?)?;
        out.set_name_and_value(3, "kv_tokens", int_scalar(0)?)?;
        out.set_name_and_value(4, "model_path", str_scalar("")?)?;
        out.into()
    }

    /// Update generation configuration in place.
    /// @export
    fn configure(
        &mut self,
        _greedy: Option<bool>,
        _max_gen: Option<f64>,
        _max_context: Option<f64>,
        _max_think: Option<f64>,
        _temperature: Option<f64>,
        _top_k: Option<f64>,
        _repeat_penalty: Option<f64>,
    ) -> savvy::Result<savvy::Sexp> {
        Err(unsupported())
    }

    /// Append raw text to the transcript. BOS is added automatically for the first append.
    /// @export
    fn append(&mut self, _text: &str) -> savvy::Result<savvy::Sexp> { Err(unsupported()) }

    /// Append a ChatML user turn to the transcript.
    /// @export
    fn append_user(&mut self, _message: &str) -> savvy::Result<savvy::Sexp> { Err(unsupported()) }

    /// Append a ChatML tool result turn to the transcript.
    /// @export
    fn append_tool_result(&mut self, _content: &str) -> savvy::Result<savvy::Sexp> { Err(unsupported()) }

    /// Append already-tokenized ids to the transcript.
    /// @export
    fn append_tokens(&mut self, _ids: IntegerSexp) -> savvy::Result<savvy::Sexp> { Err(unsupported()) }

    /// Generate a raw continuation from the current transcript.
    /// @export
    fn generate(&mut self, _check_interrupt: bool, _on_event: Option<FunctionSexp>) -> savvy::Result<savvy::Sexp> { Err(unsupported()) }

    /// Open an assistant ChatML turn, generate it, then close the assistant turn.
    /// @export
    fn assistant_turn(&mut self, _check_interrupt: bool, _on_event: Option<FunctionSexp>) -> savvy::Result<savvy::Sexp> { Err(unsupported()) }

    /// Clear transcript and caches, keeping weights and generation configuration.
    /// @export
    fn clear(&mut self) -> savvy::Result<savvy::Sexp> { self.info() }

    /// Return the full token transcript.
    /// @export
    fn history(&self) -> savvy::Result<savvy::Sexp> { OwnedIntegerSexp::new(0)?.into() }

    /// Decode the current token transcript.
    /// @export
    fn transcript(&self) -> savvy::Result<savvy::Sexp> { str_scalar("")?.into() }
}
