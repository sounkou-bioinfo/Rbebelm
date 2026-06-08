use bebelm::tool::{parse_tool_calls, Schema, Tool, Type};
use savvy::{savvy, LogicalSexp, OwnedListSexp, StringSexp};

use crate::util::{err, str_scalar};

fn tool_type(value: &str) -> Type {
    match value {
        "integer" => Type::Int,
        "number" => Type::Num,
        "boolean" => Type::Bool,
        _ => Type::Str,
    }
}

fn parse_tool_call_to_list(call: &bebelm::tool::ToolCall) -> savvy::Result<savvy::Sexp> {
    let mut args = OwnedListSexp::new(call.args.len(), true)?;
    for (i, (name, value)) in call.args.iter().enumerate() {
        args.set_name_and_value(i, name, str_scalar(value)?)?;
    }

    let args_sexp: savvy::Sexp = args.into();
    let mut out = OwnedListSexp::new(3, true)?;
    out.set_name_and_value(0, "name", str_scalar(&call.name)?)?;
    out.set_name_and_value(1, "arguments", args_sexp)?;
    out.set_name_and_value(2, "raw", str_scalar(&call.raw)?)?;
    out.into()
}

pub fn render_system_turn(message: &str, tool_names: &[&str], tool_schemas: &[&str]) -> savvy::Result<String> {
    if tool_names.len() != tool_schemas.len() {
        return Err(err("tool_names and tool_schemas must have the same length"));
    }

    // Mirrors upstream bebelm::agent::Agent::append_system(). We construct Tool::raw values so
    // the schema strings flow through the upstream tool abstraction rather than a separate R-side
    // prompt template.
    let tools: Vec<Tool> = tool_names
        .iter()
        .zip(tool_schemas.iter())
        .map(|(name, schema)| Tool::raw((*name).to_string(), (*schema).to_string(), |_| String::new()))
        .collect();

    let mut block = String::from("<|im_start|>system\n");
    if !tools.is_empty() {
        block.push_str("List of tools: [");
        for (i, tool) in tools.iter().enumerate() {
            if i > 0 {
                block.push_str(", ");
            }
            block.push_str(tool.schema());
        }
        block.push_str("]\n\n");
    }
    block.push_str(message);
    block.push_str("<|im_end|>\n");
    Ok(block)
}

/// Render an upstream BebeLM tool schema from parameter vectors.
/// @keywords internal
#[savvy]
fn rbebelm_tool_schema_json(
    name: &str,
    description: &str,
    param_names: StringSexp,
    param_types: StringSexp,
    param_descriptions: StringSexp,
    param_required: LogicalSexp,
) -> savvy::Result<savvy::Sexp> {
    let names = param_names.to_vec();
    let types = param_types.to_vec();
    let descriptions = param_descriptions.to_vec();
    let required = param_required.to_vec();
    let n = names.len();
    if types.len() != n || descriptions.len() != n || required.len() != n {
        return Err(err("parameter vectors must have the same length"));
    }

    let mut schema = Schema::new();
    for i in 0..n {
        schema = if required[i] {
            schema.req(names[i], tool_type(types[i]), descriptions[i])
        } else {
            schema.opt(names[i], tool_type(types[i]), descriptions[i])
        };
    }
    let tool = Tool::new(name, description, schema, |_| String::new());
    str_scalar(tool.schema())?.into()
}

/// Parse upstream BebeLM Pythonic tool calls.
/// @keywords internal
#[savvy]
fn rbebelm_parse_tool_calls(text: &str) -> savvy::Result<savvy::Sexp> {
    let calls = parse_tool_calls(text);
    let mut out = OwnedListSexp::new(calls.len(), false)?;
    for (i, call) in calls.iter().enumerate() {
        out.set_value(i, parse_tool_call_to_list(call)?)?;
    }
    out.into()
}

/// Render an upstream BebeLM ChatML system turn, optionally with tool schemas.
/// @keywords internal
#[savvy]
fn rbebelm_render_system_turn(message: &str, tool_names: StringSexp, tool_schemas: StringSexp) -> savvy::Result<savvy::Sexp> {
    let names = tool_names.to_vec();
    let schemas = tool_schemas.to_vec();
    str_scalar(&render_system_turn(message, &names, &schemas)?)?.into()
}
