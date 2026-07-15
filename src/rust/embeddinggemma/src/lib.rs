//! CPU-only, pure-Rust inference for the 300M EmbeddingGemma GGUF architecture.
//!
//! This crate intentionally implements the model directly over Rbebelm's pure-Rust GGUF,
//! quantization, matmul, normalization, RoPE, and softmax substrate. It does not link to
//! llama.cpp, PyTorch, ONNX Runtime, or the SentencePiece C++ library.

pub mod model;
pub mod tokenizer;

pub use model::{
    EmbeddingGemma, EmbeddingOutput, ARCHITECTURE, BATCH_TOKEN_BUDGET, CONTEXT_LENGTH,
    EMBEDDING_DIMENSIONS,
};
pub use tokenizer::Tokenizer;
