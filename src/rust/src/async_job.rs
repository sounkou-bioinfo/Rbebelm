use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};

use bebelm::agent::Turn;
use bebelm::model::Model;
use savvy::{savvy, NullSexp};

use crate::agent::BebelAgent;
use crate::chatml::{user_turn, ASSISTANT_OPEN};
use crate::events::{drain_event_queue, new_event_queue, EventQueue};
use crate::generation::{run_generation_with_events, turn_to_list};
use crate::options::GenerationOptions;
use crate::util::{bool_scalar, err};

type AsyncResult = Result<Turn, String>;

/// Background BebeLM generation job.
/// @export
#[savvy]
pub struct BebelAsyncJob {
    handle: Option<JoinHandle<AsyncResult>>,
    result: Option<AsyncResult>,
    events: EventQueue,
    consumed: bool,
}

#[savvy]
impl BebelAsyncJob {
    /// Test whether the background job has finished.
    /// @export
    fn ready(&self) -> savvy::Result<savvy::Sexp> {
        bool_scalar(self.is_ready())?.into()
    }

    /// Drain queued generation events.
    /// @export
    fn events(&self, max: Option<f64>) -> savvy::Result<savvy::Sexp> {
        drain_event_queue(&self.events, max)
    }

    /// Collect the result. Returns NULL when wait = FALSE and the job is still running.
    /// @export
    fn result(&mut self, wait: bool) -> savvy::Result<savvy::Sexp> {
        if self.consumed {
            return Err(err("async job result has already been collected"));
        }

        if self.result.is_none() {
            let ready = self.handle.as_ref().map(|handle| handle.is_finished()).unwrap_or(false);
            if !wait && !ready {
                return Ok(NullSexp.into());
            }
            let handle = self.handle.take().ok_or_else(|| err("async job has no running task"))?;
            self.result = Some(handle.join().map_err(|_| err("async job panicked"))?);
        }

        self.consumed = true;
        match self.result.take().expect("result populated above") {
            Ok(turn) => turn_to_list(turn),
            Err(message) => Err(err(message)),
        }
    }
}

impl BebelAsyncJob {
    fn spawn(f: impl FnOnce(EventQueue) -> savvy::Result<Turn> + Send + 'static) -> Self {
        let events = new_event_queue();
        let worker_events = Arc::clone(&events);
        Self {
            handle: Some(thread::spawn(move || f(worker_events).map_err(|e| e.to_string()))),
            result: None,
            events,
            consumed: false,
        }
    }

    fn is_ready(&self) -> bool {
        self.result.is_some()
            || self.consumed
            || self.handle.as_ref().map(|handle| handle.is_finished()).unwrap_or(false)
    }
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn spawn_model_generate(
    model: Arc<Model>,
    exec_lock: Arc<Mutex<()>>,
    prompt: String,
    greedy: bool,
    max_gen: Option<f64>,
    max_context: Option<f64>,
    max_think: Option<f64>,
    temperature: Option<f64>,
    top_k: Option<f64>,
    repeat_penalty: Option<f64>,
) -> savvy::Result<BebelAsyncJob> {
    Ok(BebelAsyncJob::spawn(move |events| {
        let mut opts = GenerationOptions::new(
            greedy,
            false,
            None,
            max_gen,
            max_context,
            max_think,
            temperature,
            top_k,
            repeat_penalty,
        )?;
        let history = model.tokenizer().encode(&prompt, true);
        let _guard = exec_lock.lock().map_err(|_| err("model execution lock poisoned"))?;
        run_generation_with_events(model.as_ref(), history, &mut opts, Some(&events))
    }))
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn spawn_model_chat(
    model: Arc<Model>,
    exec_lock: Arc<Mutex<()>>,
    message: String,
    greedy: bool,
    max_gen: Option<f64>,
    max_context: Option<f64>,
    max_think: Option<f64>,
    temperature: Option<f64>,
    top_k: Option<f64>,
    repeat_penalty: Option<f64>,
) -> savvy::Result<BebelAsyncJob> {
    Ok(BebelAsyncJob::spawn(move |events| {
        let mut opts = GenerationOptions::new(
            greedy,
            false,
            None,
            max_gen,
            max_context,
            max_think,
            temperature,
            top_k,
            repeat_penalty,
        )?;
        let mut history = model.tokenizer().encode(&user_turn(&message), true);
        history.extend(model.tokenizer().encode(ASSISTANT_OPEN, false));
        let _guard = exec_lock.lock().map_err(|_| err("model execution lock poisoned"))?;
        run_generation_with_events(model.as_ref(), history, &mut opts, Some(&events))
    }))
}

pub(crate) fn spawn_agent_generate(mut agent: BebelAgent) -> BebelAsyncJob {
    BebelAsyncJob::spawn(move |events| agent.generate_turn_with_events(false, None, Some(&events)))
}

pub(crate) fn spawn_agent_assistant_turn(mut agent: BebelAgent, stop_on_tool_call: bool) -> BebelAsyncJob {
    BebelAsyncJob::spawn(move |events| {
        agent.assistant_turn_impl_with_events(false, None, stop_on_tool_call, Some(&events))
    })
}
