use bebelm::agent::StopReason;
use bebelm::tokenizer::{
    TOKEN_THINK, TOKEN_THINK_END, TOKEN_TOOL_CALL_END, TOKEN_TOOL_CALL_START, TOKEN_TOOL_LIST_END,
    TOKEN_TOOL_LIST_START,
};
use savvy::{savvy, FunctionArgs, FunctionSexp, OwnedListSexp, OwnedStringSexp};

use crate::util::{err, int_scalar, str_scalar};

#[derive(Clone, Copy, PartialEq, Eq)]
enum ActiveBlock {
    None,
    Text,
    Thinking,
    ToolList,
    ToolCall,
}

impl ActiveBlock {
    fn start_event(self) -> Option<&'static str> {
        match self {
            ActiveBlock::None => None,
            ActiveBlock::Text => Some("text_start"),
            ActiveBlock::Thinking => Some("thinking_start"),
            ActiveBlock::ToolList => Some("tool_list_start"),
            ActiveBlock::ToolCall => Some("tool_call_start"),
        }
    }

    fn delta_event(self) -> Option<&'static str> {
        match self {
            ActiveBlock::None => None,
            ActiveBlock::Text => Some("text_delta"),
            ActiveBlock::Thinking => Some("thinking_delta"),
            ActiveBlock::ToolList => Some("tool_list_delta"),
            ActiveBlock::ToolCall => Some("tool_call_delta"),
        }
    }

    fn end_event(self) -> Option<&'static str> {
        match self {
            ActiveBlock::None => None,
            ActiveBlock::Text => Some("text_end"),
            ActiveBlock::Thinking => Some("thinking_end"),
            ActiveBlock::ToolList => Some("tool_list_end"),
            ActiveBlock::ToolCall => Some("tool_call_end"),
        }
    }
}

pub fn event_types() -> &'static [&'static str] {
    &[
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
    ]
}

/// Return BebeLM stream event types.
/// @export
#[savvy]
pub fn bebel_event_types() -> savvy::Result<savvy::Sexp> {
    let types = event_types();
    let mut out = OwnedStringSexp::new(types.len())?;
    for (i, event_type) in types.iter().enumerate() {
        out.set_elt(i, event_type)?;
    }
    out.into()
}

fn call_event(callback: &Option<FunctionSexp>, event: OwnedListSexp) -> savvy::Result<()> {
    let Some(callback) = callback else {
        return Ok(());
    };
    let mut args = FunctionArgs::new();
    args.add("event", event)?;
    let _ = callback.call(args)?;
    Ok(())
}

fn simple_event(event_type: &str) -> savvy::Result<OwnedListSexp> {
    let mut event = OwnedListSexp::new(1, true)?;
    event.set_name_and_value(0, "type", str_scalar(event_type)?)?;
    Ok(event)
}

fn control_event(event_type: &str, index: usize, id: u32, marker: &str) -> savvy::Result<OwnedListSexp> {
    let mut event = OwnedListSexp::new(4, true)?;
    event.set_name_and_value(0, "type", str_scalar(event_type)?)?;
    event.set_name_and_value(1, "index", int_scalar(index as i32)?)?;
    event.set_name_and_value(2, "id", int_scalar(i32::try_from(id).map_err(|_| err("token id does not fit in R integer"))?)?)?;
    event.set_name_and_value(3, "marker", str_scalar(marker)?)?;
    Ok(event)
}

fn delta_event(event_type: &str, index: usize, id: u32, delta: &str) -> savvy::Result<OwnedListSexp> {
    let mut event = OwnedListSexp::new(4, true)?;
    event.set_name_and_value(0, "type", str_scalar(event_type)?)?;
    event.set_name_and_value(1, "index", int_scalar(index as i32)?)?;
    event.set_name_and_value(2, "id", int_scalar(i32::try_from(id).map_err(|_| err("token id does not fit in R integer"))?)?)?;
    event.set_name_and_value(3, "delta", str_scalar(delta)?)?;
    Ok(event)
}

fn end_event(event_type: &str, content: &str) -> savvy::Result<OwnedListSexp> {
    let mut event = OwnedListSexp::new(2, true)?;
    event.set_name_and_value(0, "type", str_scalar(event_type)?)?;
    event.set_name_and_value(1, "content", str_scalar(content)?)?;
    Ok(event)
}

fn control_end_event(event_type: &str, index: usize, id: u32, marker: &str, content: &str) -> savvy::Result<OwnedListSexp> {
    let mut event = OwnedListSexp::new(5, true)?;
    event.set_name_and_value(0, "type", str_scalar(event_type)?)?;
    event.set_name_and_value(1, "index", int_scalar(index as i32)?)?;
    event.set_name_and_value(2, "id", int_scalar(i32::try_from(id).map_err(|_| err("token id does not fit in R integer"))?)?)?;
    event.set_name_and_value(3, "marker", str_scalar(marker)?)?;
    event.set_name_and_value(4, "content", str_scalar(content)?)?;
    Ok(event)
}

fn done_event(stop: StopReason, text: &str, generated_tokens: usize) -> savvy::Result<OwnedListSexp> {
    let stop = match stop {
        StopReason::Eos => "eos",
        StopReason::MaxNew => "max_new",
    };
    let mut event = OwnedListSexp::new(4, true)?;
    event.set_name_and_value(0, "type", str_scalar("done")?)?;
    event.set_name_and_value(1, "stop", str_scalar(stop)?)?;
    event.set_name_and_value(2, "text", str_scalar(text)?)?;
    event.set_name_and_value(3, "generated_tokens", int_scalar(generated_tokens as i32)?)?;
    Ok(event)
}

pub struct StreamState<'a> {
    callback: &'a Option<FunctionSexp>,
    active: ActiveBlock,
    content: String,
}

impl<'a> StreamState<'a> {
    pub fn new(callback: &'a Option<FunctionSexp>) -> Self {
        Self {
            callback,
            active: ActiveBlock::None,
            content: String::new(),
        }
    }

    pub fn start(&mut self) -> savvy::Result<()> {
        call_event(self.callback, simple_event("start")?)
    }

    pub fn token(&mut self, index: usize, id: u32, piece: &str) -> savvy::Result<()> {
        match id {
            TOKEN_THINK => self.start_control_block(ActiveBlock::Thinking, index, id, piece),
            TOKEN_THINK_END => self.end_control_block(ActiveBlock::Thinking, index, id, piece),
            TOKEN_TOOL_LIST_START => self.start_control_block(ActiveBlock::ToolList, index, id, piece),
            TOKEN_TOOL_LIST_END => self.end_control_block(ActiveBlock::ToolList, index, id, piece),
            TOKEN_TOOL_CALL_START => self.start_control_block(ActiveBlock::ToolCall, index, id, piece),
            TOKEN_TOOL_CALL_END => self.end_control_block(ActiveBlock::ToolCall, index, id, piece),
            _ => self.delta(index, id, piece),
        }
    }

    pub fn finish(&mut self, stop: StopReason, text: &str, generated_tokens: usize) -> savvy::Result<()> {
        self.close_active()?;
        call_event(self.callback, done_event(stop, text, generated_tokens)?)
    }

    fn start_control_block(&mut self, block: ActiveBlock, index: usize, id: u32, marker: &str) -> savvy::Result<()> {
        self.close_active()?;
        self.active = block;
        self.content.clear();
        call_event(
            self.callback,
            control_event(block.start_event().expect("control block start event"), index, id, marker)?,
        )
    }

    fn end_control_block(&mut self, block: ActiveBlock, index: usize, id: u32, marker: &str) -> savvy::Result<()> {
        if self.active != block {
            self.close_active()?;
            self.active = block;
        }
        let event_type = block.end_event().expect("control block end event");
        let event = control_end_event(event_type, index, id, marker, &self.content)?;
        self.active = ActiveBlock::None;
        self.content.clear();
        call_event(self.callback, event)
    }

    fn delta(&mut self, index: usize, id: u32, piece: &str) -> savvy::Result<()> {
        if self.active == ActiveBlock::None {
            self.active = ActiveBlock::Text;
            self.content.clear();
            call_event(self.callback, simple_event("text_start")?)?;
        }
        self.content.push_str(piece);
        call_event(
            self.callback,
            delta_event(self.active.delta_event().expect("delta event"), index, id, piece)?,
        )
    }

    fn close_active(&mut self) -> savvy::Result<()> {
        if self.active == ActiveBlock::None {
            return Ok(());
        }
        let event_type = self.active.end_event().expect("end event");
        let event = end_event(event_type, &self.content)?;
        self.active = ActiveBlock::None;
        self.content.clear();
        call_event(self.callback, event)
    }
}
