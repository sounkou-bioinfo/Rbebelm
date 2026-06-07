use savvy::{savvy, OwnedIntegerSexp, OwnedListSexp, OwnedLogicalSexp, OwnedRealSexp, Sexp};
use serde_json::{Map, Number, Value};

use crate::util::{err, str_scalar};

fn number_to_sexp(value: &Number) -> savvy::Result<Sexp> {
    if let Some(i) = value.as_i64() {
        if i >= i32::MIN as i64 && i <= i32::MAX as i64 {
            let mut out = OwnedIntegerSexp::new(1)?;
            out.set_elt(0, i as i32)?;
            return out.into();
        }
    }
    let mut out = OwnedRealSexp::new(1)?;
    out.set_elt(0, value.as_f64().unwrap_or(f64::NAN))?;
    out.into()
}

fn json_to_sexp(value: &Value) -> savvy::Result<Sexp> {
    match value {
        Value::Null => Ok(savvy::sexp::null::NullSexp.into()),
        Value::Bool(x) => {
            let mut out = OwnedLogicalSexp::new(1)?;
            out.set_elt(0, *x)?;
            out.into()
        }
        Value::Number(x) => number_to_sexp(x),
        Value::String(x) => str_scalar(x)?.into(),
        Value::Array(xs) => {
            let mut out = OwnedListSexp::new(xs.len(), false)?;
            for (i, x) in xs.iter().enumerate() {
                out.set_value(i, json_to_sexp(x)?)?;
            }
            out.into()
        }
        Value::Object(xs) => object_to_sexp(xs),
    }
}

fn object_to_sexp(xs: &Map<String, Value>) -> savvy::Result<Sexp> {
    let mut out = OwnedListSexp::new(xs.len(), true)?;
    for (i, (name, value)) in xs.iter().enumerate() {
        out.set_name_and_value(i, name, json_to_sexp(value)?)?;
    }
    out.into()
}

/// Parse JSON into base R vectors/lists.
/// @keywords internal
#[savvy]
fn rbebelm_json_parse(text: &str) -> savvy::Result<Sexp> {
    let value: Value = serde_json::from_str(text).map_err(|e| err(format!("invalid JSON: {e}")))?;
    json_to_sexp(&value)
}

/// Format a tool-result object as JSON.
/// @keywords internal
#[savvy]
fn rbebelm_json_tool_result(tool: &str, ok: bool, result: Option<&str>, error: Option<&str>) -> savvy::Result<Sexp> {
    let payload = serde_json::json!({
        "tool": tool,
        "ok": ok,
        "result": result,
        "error": error,
    });
    str_scalar(&payload.to_string())?.into()
}
