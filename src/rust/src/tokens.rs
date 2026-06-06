use bebelm::tokenizer::{
    TOKEN_BOS, TOKEN_ENDOFTEXT, TOKEN_EOS, TOKEN_FIM_MID, TOKEN_FIM_PRE, TOKEN_FIM_SUF,
    TOKEN_IM_END, TOKEN_IM_START, TOKEN_PAD, TOKEN_THINK, TOKEN_THINK_END, TOKEN_TOOL_CALL_END,
    TOKEN_TOOL_CALL_START, TOKEN_TOOL_LIST_END, TOKEN_TOOL_LIST_START,
};
use savvy::{savvy, OwnedIntegerSexp};

/// Return BebeLM tokenizer special token ids.
/// @export
#[savvy]
pub fn bebel_token_ids() -> savvy::Result<savvy::Sexp> {
    let tokens: &[(&str, u32)] = &[
        ("TOKEN_PAD", TOKEN_PAD),
        ("TOKEN_BOS", TOKEN_BOS),
        ("TOKEN_ENDOFTEXT", TOKEN_ENDOFTEXT),
        ("TOKEN_FIM_PRE", TOKEN_FIM_PRE),
        ("TOKEN_FIM_MID", TOKEN_FIM_MID),
        ("TOKEN_FIM_SUF", TOKEN_FIM_SUF),
        ("TOKEN_IM_START", TOKEN_IM_START),
        ("TOKEN_IM_END", TOKEN_IM_END),
        ("TOKEN_EOS", TOKEN_EOS),
        ("TOKEN_THINK", TOKEN_THINK),
        ("TOKEN_THINK_END", TOKEN_THINK_END),
        ("TOKEN_TOOL_LIST_START", TOKEN_TOOL_LIST_START),
        ("TOKEN_TOOL_LIST_END", TOKEN_TOOL_LIST_END),
        ("TOKEN_TOOL_CALL_START", TOKEN_TOOL_CALL_START),
        ("TOKEN_TOOL_CALL_END", TOKEN_TOOL_CALL_END),
    ];
    let mut out = OwnedIntegerSexp::new(tokens.len())?;
    for (i, &(_, id)) in tokens.iter().enumerate() {
        out.set_elt(i, id as i32)?;
    }
    let names: Vec<&str> = tokens.iter().map(|&(name, _)| name).collect();
    out.set_names(names)?;
    out.into()
}
