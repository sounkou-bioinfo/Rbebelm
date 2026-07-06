use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use bebelm::agent::StopReason;
use bebelm::tokenizer::{
    TOKEN_THINK, TOKEN_THINK_END, TOKEN_TOOL_CALL_END, TOKEN_TOOL_CALL_START, TOKEN_TOOL_LIST_END,
    TOKEN_TOOL_LIST_START,
};
use savvy::{savvy, FunctionArgs, FunctionSexp, OwnedListSexp, OwnedStringSexp};

use crate::util::{checked_usize, err, int_scalar, str_scalar};

pub type EventQueue = Arc<Mutex<VecDeque<BebelStreamEvent>>>;

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

#[derive(Clone, Debug)]
pub struct BebelStreamEvent {
    event_type: &'static str,
    index: Option<usize>,
    id: Option<u32>,
    marker: Option<String>,
    delta: Option<String>,
    content: Option<String>,
    stop: Option<&'static str>,
    text: Option<String>,
    generated_tokens: Option<usize>,
}

impl BebelStreamEvent {
    fn new(event_type: &'static str) -> Self {
        Self {
            event_type,
            index: None,
            id: None,
            marker: None,
            delta: None,
            content: None,
            stop: None,
            text: None,
            generated_tokens: None,
        }
    }

    fn to_list(&self) -> savvy::Result<OwnedListSexp> {
        let field_count = 1
            + usize::from(self.index.is_some())
            + usize::from(self.id.is_some())
            + usize::from(self.marker.is_some())
            + usize::from(self.delta.is_some())
            + usize::from(self.content.is_some())
            + usize::from(self.stop.is_some())
            + usize::from(self.text.is_some())
            + usize::from(self.generated_tokens.is_some());
        let mut out = OwnedListSexp::new(field_count, true)?;
        let mut i = 0;
        out.set_name_and_value(i, "type", str_scalar(self.event_type)?)?;
        i += 1;
        if let Some(index) = self.index {
            out.set_name_and_value(
                i,
                "index",
                int_scalar(i32::try_from(index).map_err(|_| err("event index does not fit in R integer"))?)?,
            )?;
            i += 1;
        }
        if let Some(id) = self.id {
            out.set_name_and_value(
                i,
                "id",
                int_scalar(i32::try_from(id).map_err(|_| err("token id does not fit in R integer"))?)?,
            )?;
            i += 1;
        }
        if let Some(marker) = self.marker.as_deref() {
            out.set_name_and_value(i, "marker", str_scalar(marker)?)?;
            i += 1;
        }
        if let Some(delta) = self.delta.as_deref() {
            out.set_name_and_value(i, "delta", str_scalar(delta)?)?;
            i += 1;
        }
        if let Some(content) = self.content.as_deref() {
            out.set_name_and_value(i, "content", str_scalar(content)?)?;
            i += 1;
        }
        if let Some(stop) = self.stop {
            out.set_name_and_value(i, "stop", str_scalar(stop)?)?;
            i += 1;
        }
        if let Some(text) = self.text.as_deref() {
            out.set_name_and_value(i, "text", str_scalar(text)?)?;
            i += 1;
        }
        if let Some(generated_tokens) = self.generated_tokens {
            out.set_name_and_value(
                i,
                "generated_tokens",
                int_scalar(
                    i32::try_from(generated_tokens)
                        .map_err(|_| err("generated token count does not fit in R integer"))?,
                )?,
            )?;
        }
        Ok(out)
    }
}

pub fn new_event_queue() -> EventQueue {
    Arc::new(Mutex::new(VecDeque::new()))
}

pub fn drain_event_queue(queue: &EventQueue, max: Option<f64>) -> savvy::Result<savvy::Sexp> {
    let max = checked_usize(max, "max")?.unwrap_or(usize::MAX);
    let mut queue = queue.lock().map_err(|_| err("async event queue lock poisoned"))?;
    let n = std::cmp::min(max, queue.len());
    let mut out = OwnedListSexp::new(n, false)?;
    for i in 0..n {
        let event = queue.pop_front().expect("event count fixed before drain");
        out.set_value(i, event.to_list()?)?;
    }
    out.into()
}

fn emit_event(
    callback: &Option<FunctionSexp>,
    queue: Option<&EventQueue>,
    event: BebelStreamEvent,
) -> savvy::Result<()> {
    if let Some(queue) = queue {
        queue
            .lock()
            .map_err(|_| err("async event queue lock poisoned"))?
            .push_back(event.clone());
    }
    if let Some(callback) = callback {
        let mut args = FunctionArgs::new();
        args.add("event", event.to_list()?)?;
        let _ = callback.call(args)?;
    }
    Ok(())
}

fn simple_event(event_type: &'static str) -> BebelStreamEvent {
    BebelStreamEvent::new(event_type)
}

fn control_event(event_type: &'static str, index: usize, id: u32, marker: &str) -> BebelStreamEvent {
    let mut event = BebelStreamEvent::new(event_type);
    event.index = Some(index);
    event.id = Some(id);
    event.marker = Some(marker.to_string());
    event
}

fn delta_event(event_type: &'static str, index: usize, id: u32, delta: &str) -> BebelStreamEvent {
    let mut event = BebelStreamEvent::new(event_type);
    event.index = Some(index);
    event.id = Some(id);
    event.delta = Some(delta.to_string());
    event
}

fn end_event(event_type: &'static str, content: &str) -> BebelStreamEvent {
    let mut event = BebelStreamEvent::new(event_type);
    event.content = Some(content.to_string());
    event
}

fn control_end_event(
    event_type: &'static str,
    index: usize,
    id: u32,
    marker: &str,
    content: &str,
) -> BebelStreamEvent {
    let mut event = BebelStreamEvent::new(event_type);
    event.index = Some(index);
    event.id = Some(id);
    event.marker = Some(marker.to_string());
    event.content = Some(content.to_string());
    event
}

fn done_event(stop: StopReason, text: &str, generated_tokens: usize) -> BebelStreamEvent {
    let stop = match stop {
        StopReason::Eos => "eos",
        StopReason::MaxNew => "max_new",
        StopReason::ToolCall => "tool_call",
    };
    let mut event = BebelStreamEvent::new("done");
    event.stop = Some(stop);
    event.text = Some(text.to_string());
    event.generated_tokens = Some(generated_tokens);
    event
}

pub struct StreamState<'a> {
    callback: &'a Option<FunctionSexp>,
    queue: Option<&'a EventQueue>,
    active: ActiveBlock,
    content: String,
}

impl<'a> StreamState<'a> {
    pub fn new(callback: &'a Option<FunctionSexp>, queue: Option<&'a EventQueue>) -> Self {
        Self {
            callback,
            queue,
            active: ActiveBlock::None,
            content: String::new(),
        }
    }

    pub fn start(&mut self) -> savvy::Result<()> {
        if !self.has_sink() {
            return Ok(());
        }
        emit_event(self.callback, self.queue, simple_event("start"))
    }

    pub fn token(&mut self, index: usize, id: u32, piece: &str) -> savvy::Result<()> {
        if !self.has_sink() {
            return Ok(());
        }
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
        if !self.has_sink() {
            return Ok(());
        }
        self.close_active()?;
        emit_event(self.callback, self.queue, done_event(stop, text, generated_tokens))
    }

    fn has_sink(&self) -> bool {
        self.callback.is_some() || self.queue.is_some()
    }

    fn start_control_block(&mut self, block: ActiveBlock, index: usize, id: u32, marker: &str) -> savvy::Result<()> {
        self.close_active()?;
        self.active = block;
        self.content.clear();
        emit_event(
            self.callback,
            self.queue,
            control_event(block.start_event().expect("control block start event"), index, id, marker),
        )
    }

    fn end_control_block(&mut self, block: ActiveBlock, index: usize, id: u32, marker: &str) -> savvy::Result<()> {
        if self.active != block {
            self.close_active()?;
            self.active = block;
        }
        let event_type = block.end_event().expect("control block end event");
        let event = control_end_event(event_type, index, id, marker, &self.content);
        self.active = ActiveBlock::None;
        self.content.clear();
        emit_event(self.callback, self.queue, event)
    }

    fn delta(&mut self, index: usize, id: u32, piece: &str) -> savvy::Result<()> {
        if self.active == ActiveBlock::None {
            self.active = ActiveBlock::Text;
            self.content.clear();
            emit_event(self.callback, self.queue, simple_event("text_start"))?;
        }
        self.content.push_str(piece);
        emit_event(
            self.callback,
            self.queue,
            delta_event(self.active.delta_event().expect("delta event"), index, id, piece),
        )
    }

    fn close_active(&mut self) -> savvy::Result<()> {
        if self.active == ActiveBlock::None {
            return Ok(());
        }
        let event_type = self.active.end_event().expect("end event");
        let event = end_event(event_type, &self.content);
        self.active = ActiveBlock::None;
        self.content.clear();
        emit_event(self.callback, self.queue, event)
    }
}
