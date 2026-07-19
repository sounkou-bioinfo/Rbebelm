//! bebelm — curated CPU-only, pure-Rust inference profiles for GGUF models.
//!
//! Library surface: the GGUF loader, dtype/block sizing, and the compute kernels. The
//! `bebelm` binary (`src/main.rs`) is a thin CLI over this crate.

pub mod agent;
pub mod architecture;
pub mod cache;
pub mod colbert;
pub mod config;
pub mod gguf;
pub mod kernels;
pub mod model;
pub mod sampler;
pub mod tensor;
pub mod tokenizer;
pub mod tool;
