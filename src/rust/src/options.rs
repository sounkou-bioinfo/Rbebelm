use bebelm::sampler::Sampler;
use savvy::FunctionSexp;

use crate::util::{checked_positive_usize, checked_usize, err};

pub struct GenerationOptions {
    pub sampler: Sampler,
    pub check_interrupt: bool,
    pub on_event: Option<FunctionSexp>,
    pub max_gen: usize,
    pub max_context: usize,
    pub max_think: usize,
}

impl GenerationOptions {
    pub fn new(
        greedy: bool,
        check_interrupt: bool,
        on_event: Option<FunctionSexp>,
        max_gen: Option<f64>,
        max_context: Option<f64>,
        max_think: Option<f64>,
        temperature: Option<f64>,
        top_k: Option<f64>,
        repeat_penalty: Option<f64>,
    ) -> savvy::Result<Self> {
        Ok(Self {
            sampler: make_sampler(greedy, temperature, top_k, repeat_penalty)?,
            check_interrupt,
            on_event,
            max_gen: checked_usize(max_gen, "max_gen")?.unwrap_or(2048),
            max_context: checked_positive_usize(max_context, "max_context")?.unwrap_or(32_768),
            max_think: checked_usize(max_think, "max_think")?.unwrap_or(usize::MAX),
        })
    }
}

pub fn make_sampler(
    greedy: bool,
    temperature: Option<f64>,
    top_k: Option<f64>,
    repeat_penalty: Option<f64>,
) -> savvy::Result<Sampler> {
    let mut sampler = if greedy { Sampler::greedy() } else { Sampler::recommended() };
    apply_sampler_overrides(&mut sampler, temperature, top_k, repeat_penalty)?;
    Ok(sampler)
}

pub fn apply_sampler_overrides(
    sampler: &mut Sampler,
    temperature: Option<f64>,
    top_k: Option<f64>,
    repeat_penalty: Option<f64>,
) -> savvy::Result<()> {
    if let Some(t) = temperature {
        if !t.is_finite() || t < 0.0 {
            return Err(err("temperature must be finite and non-negative"));
        }
        sampler.temperature = t as f32;
    }
    if let Some(k) = checked_usize(top_k, "top_k")? {
        sampler.top_k = k;
    }
    if let Some(p) = repeat_penalty {
        if !p.is_finite() || p <= 0.0 {
            return Err(err("repeat_penalty must be finite and positive"));
        }
        sampler.repeat_penalty = p as f32;
    }
    Ok(())
}

pub fn maybe_update_sampler(
    sampler: &mut Sampler,
    greedy: Option<bool>,
    temperature: Option<f64>,
    top_k: Option<f64>,
    repeat_penalty: Option<f64>,
) -> savvy::Result<()> {
    if let Some(greedy) = greedy {
        *sampler = if greedy { Sampler::greedy() } else { Sampler::recommended() };
    }
    apply_sampler_overrides(sampler, temperature, top_k, repeat_penalty)
}
