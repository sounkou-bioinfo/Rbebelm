use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

use crate::util::err;

pub type CancelFlag = Arc<AtomicBool>;

pub fn new_cancel_flag() -> CancelFlag {
    Arc::new(AtomicBool::new(false))
}

pub fn cancel(flag: &CancelFlag) -> bool {
    !flag.swap(true, Ordering::Relaxed)
}

pub fn is_cancelled(flag: &CancelFlag) -> bool {
    flag.load(Ordering::Relaxed)
}

pub fn check_cancelled(flag: Option<&CancelFlag>) -> savvy::Result<()> {
    if flag.is_some_and(is_cancelled) {
        return Err(err("async job cancelled"));
    }
    Ok(())
}
