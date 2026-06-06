use std::time::Instant;

use bebelm::agent::{GenStats, StopReason, Turn};
use bebelm::cache::Cache;
use bebelm::model::Model;
use bebelm::sampler::Sampler;
use bebelm::tokenizer::{
    Tokenizer, TOKEN_BOS, TOKEN_ENDOFTEXT, TOKEN_IM_START, TOKEN_PAD, TOKEN_THINK, TOKEN_THINK_END,
};
use savvy::{FunctionSexp, OwnedListSexp};

use crate::events::StreamState;
use crate::options::GenerationOptions;
use crate::util::{check_user_interrupt, err, ids_to_sexp, int_scalar, real_scalar, str_scalar};

const STOP_TOKENS: [u32; 4] = [TOKEN_ENDOFTEXT, TOKEN_BOS, TOKEN_PAD, TOKEN_IM_START];

pub fn trim_context(cache: &mut Cache, max_context: usize) {
    let len = cache.kv_len();
    if len > max_context {
        cache.evict_front(len - max_context);
    }
}

pub fn run_one_shot(model: &Model, tok: Tokenizer, history: Vec<u32>, opts: &mut GenerationOptions) -> savvy::Result<Turn> {
    let mut cache = Cache::new();
    let mut history = history;
    run_state(
        model,
        &tok,
        &mut cache,
        &mut history,
        &mut opts.sampler,
        opts.check_interrupt,
        &opts.on_event,
        opts.max_gen,
        opts.max_context,
        opts.max_think,
    )
}

#[allow(clippy::too_many_arguments)]
pub fn run_state(
    model: &Model,
    tok: &Tokenizer,
    cache: &mut Cache,
    history: &mut Vec<u32>,
    sampler: &mut Sampler,
    check_interrupt: bool,
    on_event: &Option<FunctionSexp>,
    max_gen: usize,
    max_context: usize,
    max_think: usize,
) -> savvy::Result<Turn> {
    if history.is_empty() {
        return Err(err("prompt must produce at least one token"));
    }
    if cache.pos > history.len() {
        return Err(err("agent cache is ahead of token history"));
    }

    let t_prefill = Instant::now();
    let pending = history.len() - cache.pos;
    if pending == 0 {
        return Err(err("no pending tokens to generate from; append text or tokens first"));
    }
    let (&last, rest) = history[cache.pos..]
        .split_last()
        .expect("non-empty pending history checked above");
    for (i, &token) in rest.iter().enumerate() {
        if check_interrupt && i % 16 == 0 {
            check_user_interrupt()?;
        }
        let _ = model.forward_step(token, cache);
        trim_context(cache, max_context);
    }
    if check_interrupt {
        check_user_interrupt()?;
    }
    let mut logits = model.forward_step(last, cache);
    trim_context(cache, max_context);
    let prefill = t_prefill.elapsed();

    let t_decode = Instant::now();
    let mut stream = StreamState::new(on_event);
    stream.start()?;
    let mut ids = Vec::new();
    let mut thinking = false;
    let mut think_count = 0usize;
    let mut think_capped = max_think == 0;
    let mut require_answer = false;

    let stop = loop {
        if check_interrupt {
            check_user_interrupt()?;
        }
        if think_capped {
            logits[TOKEN_THINK as usize] = f32::NEG_INFINITY;
        }
        if require_answer {
            logits[tok.eos as usize] = f32::NEG_INFINITY;
            for &t in &STOP_TOKENS {
                logits[t as usize] = f32::NEG_INFINITY;
            }
            require_answer = false;
        }

        let next = if thinking && think_count >= max_think {
            think_capped = true;
            TOKEN_THINK_END
        } else {
            sampler.sample(&mut logits, history)
        };
        if next == tok.eos || STOP_TOKENS.contains(&next) {
            break StopReason::Eos;
        }
        match next {
            TOKEN_THINK => {
                thinking = true;
                think_count = 0;
            }
            TOKEN_THINK_END => {
                thinking = false;
                require_answer = true;
            }
            _ if thinking => think_count += 1,
            _ => {}
        }

        let index = ids.len() + 1;
        let piece = tok.decode(&[next]);
        stream.token(index, next, &piece)?;
        ids.push(next);
        history.push(next);
        if ids.len() >= max_gen {
            break StopReason::MaxNew;
        }
        logits = model.forward_step(next, cache);
        trim_context(cache, max_context);
    };

    let decode = t_decode.elapsed();
    let generated_tokens = ids.len();
    let text = tok.decode(&ids);
    stream.finish(stop, &text, generated_tokens)?;
    Ok(Turn {
        ids,
        text,
        stats: GenStats {
            prompt_tokens: pending,
            generated_tokens,
            prefill,
            decode,
        },
        stop,
    })
}

pub fn turn_to_list(turn: Turn) -> savvy::Result<savvy::Sexp> {
    let stop = match turn.stop {
        StopReason::Eos => "eos",
        StopReason::MaxNew => "max_new",
    };
    let mut out = OwnedListSexp::new(9, true)?;
    out.set_name_and_value(0, "text", str_scalar(&turn.text)?)?;
    out.set_name_and_value(1, "ids", ids_to_sexp(&turn.ids)?)?;
    out.set_name_and_value(2, "stop", str_scalar(stop)?)?;
    out.set_name_and_value(3, "prompt_tokens", int_scalar(turn.stats.prompt_tokens as i32)?)?;
    out.set_name_and_value(4, "generated_tokens", int_scalar(turn.stats.generated_tokens as i32)?)?;
    out.set_name_and_value(5, "prefill_seconds", real_scalar(turn.stats.prefill.as_secs_f64())?)?;
    out.set_name_and_value(6, "decode_seconds", real_scalar(turn.stats.decode.as_secs_f64())?)?;
    out.set_name_and_value(7, "prefill_tps", real_scalar(turn.stats.prefill_tps())?)?;
    out.set_name_and_value(8, "decode_tps", real_scalar(turn.stats.decode_tps())?)?;
    out.into()
}
