use std::sync::Arc;

use embeddinggemma::{
    EmbeddingGemma, ARCHITECTURE, BATCH_TOKEN_BUDGET, CONTEXT_LENGTH, EMBEDDING_DIMENSIONS,
};
use savvy::{
    savvy, OwnedIntegerSexp, OwnedListSexp, OwnedLogicalSexp, OwnedRealSexp, OwnedStringSexp,
    StringSexp,
};

use crate::util::{
    check_user_interrupt, checked_positive_usize, err, ids_to_sexp, init_rayon, int_scalar,
    str_scalar,
};

/// Loaded EmbeddingGemma GGUF model.
/// @export
#[savvy]
#[derive(Clone)]
pub struct EmbeddingGemmaModel {
    inner: Arc<EmbeddingGemma>,
    path: String,
}

#[savvy]
impl EmbeddingGemmaModel {
    /// Load an EmbeddingGemma GGUF model from disk.
    /// @export
    fn load(path: &str, num_threads: Option<f64>) -> savvy::Result<Self> {
        init_rayon(num_threads)?;
        let model = EmbeddingGemma::load(path)
            .map_err(|error| err(format!("cannot load EmbeddingGemma model: {error}")))?;
        Ok(Self {
            inner: Arc::new(model),
            path: path.to_string(),
        })
    }

    /// Return model information.
    /// @export
    fn info(&self) -> savvy::Result<savvy::Sexp> {
        let mut dimensions = OwnedIntegerSexp::new(EMBEDDING_DIMENSIONS.len())?;
        for (index, &dimension) in EMBEDDING_DIMENSIONS.iter().enumerate() {
            dimensions.set_elt(index, dimension as i32)?;
        }
        let mut out = OwnedListSexp::new(7, true)?;
        out.set_name_and_value(0, "path", str_scalar(&self.path)?)?;
        out.set_name_and_value(1, "architecture", str_scalar(ARCHITECTURE)?)?;
        out.set_name_and_value(2, "context_length", int_scalar(CONTEXT_LENGTH as i32)?)?;
        out.set_name_and_value(3, "dimensions", dimensions)?;
        out.set_name_and_value(4, "pooling", str_scalar("mean")?)?;
        out.set_name_and_value(5, "attention", str_scalar("bidirectional")?)?;
        out.set_name_and_value(6, "backend", str_scalar(crate::backend::backend_name())?)?;
        out.into()
    }

    /// Tokenize one already task-formatted input.
    /// @export
    fn tokenize(&self, text: &str, truncate: bool) -> savvy::Result<savvy::Sexp> {
        let (ids, truncated) = self
            .inner
            .tokenize(text, truncate)
            .map_err(|error| err(error.to_string()))?;
        let mut pieces = OwnedStringSexp::new(ids.len())?;
        for (index, &id) in ids.iter().enumerate() {
            let piece = self.inner.tokenizer().token_piece(id).unwrap_or_default();
            pieces.set_elt(index, &piece)?;
        }
        let mut out = OwnedListSexp::new(3, true)?;
        out.set_name_and_value(0, "ids", ids_to_sexp(&ids)?)?;
        out.set_name_and_value(1, "tokens", pieces)?;
        out.set_name_and_value(2, "truncated", crate::util::bool_scalar(truncated)?)?;
        out.into()
    }

    /// Embed already task-formatted inputs.
    /// @export
    fn embed_batch(
        &self,
        text: StringSexp,
        dimensions: f64,
        normalize: bool,
        truncate: bool,
        check_interrupt: bool,
    ) -> savvy::Result<savvy::Sexp> {
        let dimensions = checked_positive_usize(Some(dimensions), "dimensions")?.expect("provided");
        if !EMBEDDING_DIMENSIONS.contains(&dimensions) {
            return Err(err("dimensions must be 768, 512, 256, or 128"));
        }
        let texts = text.to_vec();
        let n = texts.len();
        let mut matrix = OwnedRealSexp::new(n * dimensions)?;
        let mut token_count = OwnedIntegerSexp::new(n)?;
        let mut truncated_out = OwnedLogicalSexp::new(n)?;

        // Tokenize first so independent short inputs can share matrix reads in bounded packed
        // encoder passes. Attention boundaries are retained by the Rust model.
        let mut tokenized = Vec::with_capacity(n);
        for (row, one) in texts.iter().enumerate() {
            if check_interrupt {
                check_user_interrupt()?;
            }
            tokenized.push(
                self.inner
                    .tokenize(one, truncate)
                    .map_err(|error| err(format!("input {}: {error}", row + 1)))?,
            );
        }

        let mut embedded = Vec::with_capacity(n);
        let mut start = 0;
        while start < n {
            if check_interrupt {
                check_user_interrupt()?;
            }
            let mut end = start;
            let mut tokens = 0;
            while end < n {
                let next = tokenized[end].0.len();
                if end > start && tokens + next > BATCH_TOKEN_BUDGET {
                    break;
                }
                tokens += next;
                end += 1;
            }
            embedded.extend(
                self.inner
                    .embed_tokenized_batch(&tokenized[start..end], dimensions, normalize)
                    .map_err(|error| err(format!("inputs {}-{}: {error}", start + 1, end)))?,
            );
            start = end;
        }

        for (row, one) in embedded.iter().enumerate() {
            token_count.set_elt(
                row,
                i32::try_from(one.token_ids.len())
                    .map_err(|_| err("token count does not fit in R integer"))?,
            )?;
            truncated_out.set_elt(row, one.truncated)?;
            for (column, &value) in one.values.iter().enumerate() {
                matrix.as_mut_slice()[row + column * n] = value as f64;
            }
        }
        matrix.set_dim(&[n, dimensions])?;

        let mut out = OwnedListSexp::new(3, true)?;
        out.set_name_and_value(0, "embeddings", matrix)?;
        out.set_name_and_value(1, "token_count", token_count)?;
        out.set_name_and_value(2, "truncated", truncated_out)?;
        out.into()
    }
}
