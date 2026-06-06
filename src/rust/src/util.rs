use std::sync::Once;

use savvy::ffi::SEXP;
use savvy::{unwind_protect, IntegerSexp, OwnedIntegerSexp, OwnedLogicalSexp, OwnedRealSexp, OwnedStringSexp};

unsafe extern "C" {
    static mut R_NilValue: SEXP;
    fn R_CheckUserInterrupt();
}

static RAYON_INIT: Once = Once::new();

pub fn err(message: impl Into<String>) -> savvy::Error {
    savvy::Error::new(&message.into())
}

pub fn str_scalar(value: &str) -> savvy::Result<OwnedStringSexp> {
    let mut out = OwnedStringSexp::new(1)?;
    out.set_elt(0, value)?;
    Ok(out)
}

pub fn int_scalar(value: i32) -> savvy::Result<OwnedIntegerSexp> {
    let mut out = OwnedIntegerSexp::new(1)?;
    out.set_elt(0, value)?;
    Ok(out)
}

pub fn real_scalar(value: f64) -> savvy::Result<OwnedRealSexp> {
    let mut out = OwnedRealSexp::new(1)?;
    out.set_elt(0, value)?;
    Ok(out)
}

pub fn bool_scalar(value: bool) -> savvy::Result<OwnedLogicalSexp> {
    let mut out = OwnedLogicalSexp::new(1)?;
    out.set_elt(0, value)?;
    Ok(out)
}

pub fn checked_usize(value: Option<f64>, name: &str) -> savvy::Result<Option<usize>> {
    match value {
        None => Ok(None),
        Some(v) if v.is_finite() && v >= 0.0 && v.fract() == 0.0 && v <= usize::MAX as f64 => Ok(Some(v as usize)),
        Some(_) => Err(err(format!("{name} must be a non-negative whole number"))),
    }
}

pub fn checked_positive_usize(value: Option<f64>, name: &str) -> savvy::Result<Option<usize>> {
    match checked_usize(value, name)? {
        Some(0) => Err(err(format!("{name} must be >= 1"))),
        other => Ok(other),
    }
}

pub fn init_rayon(num_threads: Option<f64>) -> savvy::Result<()> {
    let threads = checked_positive_usize(num_threads, "num_threads")?;
    if let Some(n) = threads {
        let mut result: Result<(), String> = Ok(());
        RAYON_INIT.call_once(|| {
            result = rayon::ThreadPoolBuilder::new()
                .num_threads(n)
                .build_global()
                .map_err(|e| format!("cannot initialize rayon thread pool: {e}"));
        });
        result.map_err(err)?;
    }
    Ok(())
}

pub fn ids_to_sexp(ids: &[u32]) -> savvy::Result<OwnedIntegerSexp> {
    let mut out = OwnedIntegerSexp::new(ids.len())?;
    for (i, &id) in ids.iter().enumerate() {
        let value = i32::try_from(id).map_err(|_| err("token id does not fit in R integer"))?;
        out.set_elt(i, value)?;
    }
    Ok(out)
}

pub fn ids_from_integer(ids: IntegerSexp) -> savvy::Result<Vec<u32>> {
    ids.as_slice()
        .iter()
        .map(|&id| {
            if id < 0 {
                Err(err("token ids must be non-negative integers"))
            } else {
                Ok(id as u32)
            }
        })
        .collect()
}

pub fn check_user_interrupt() -> savvy::Result<()> {
    unsafe {
        unwind_protect(|| {
            R_CheckUserInterrupt();
            R_NilValue as SEXP
        })?;
    }
    Ok(())
}
