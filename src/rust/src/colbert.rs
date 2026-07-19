use std::sync::Arc;

use bebelm::colbert::{maxsim, ColbertModel as CoreColbertModel, TokenEmbeddings};
use savvy::{savvy, OwnedListSexp, OwnedRealSexp};

use crate::util::{err, ids_to_sexp, init_rayon, int_scalar, real_scalar, str_scalar};

/// Loaded LFM2.5-ColBERT GGUF model.
/// @export
#[savvy]
#[derive(Clone)]
pub struct ColbertModel {
    inner: Arc<CoreColbertModel>,
    path: String,
}

/// One query or document's L2-normalized ColBERT token vectors.
/// @export
#[savvy]
#[derive(Clone)]
pub struct ColbertEmbeddings {
    inner: Arc<TokenEmbeddings>,
    kind: &'static str,
}

#[savvy]
impl ColbertModel {
    /// Load the native LFM2.5-ColBERT-350M GGUF profile.
    /// @export
    fn load(path: &str, num_threads: Option<f64>) -> savvy::Result<Self> {
        init_rayon(num_threads)?;
        let model = CoreColbertModel::load(path)
            .map_err(|error| err(format!("cannot load ColBERT model: {error}")))?;
        Ok(Self {
            inner: Arc::new(model),
            path: path.to_string(),
        })
    }

    /// Return model and late-interaction profile information.
    /// @export
    fn info(&self) -> savvy::Result<savvy::Sexp> {
        let mut out = OwnedListSexp::new(8, true)?;
        out.set_name_and_value(0, "path", str_scalar(&self.path)?)?;
        out.set_name_and_value(1, "architecture", str_scalar("lfm2")?)?;
        out.set_name_and_value(2, "profile", str_scalar(self.inner.profile_name())?)?;
        out.set_name_and_value(3, "dimensions", int_scalar(self.inner.dimensions() as i32)?)?;
        out.set_name_and_value(
            4,
            "query_length",
            int_scalar(self.inner.query_length() as i32)?,
        )?;
        out.set_name_and_value(
            5,
            "document_length",
            int_scalar(self.inner.document_length() as i32)?,
        )?;
        out.set_name_and_value(6, "similarity", str_scalar("MaxSim")?)?;
        out.set_name_and_value(7, "backend", str_scalar(crate::backend::backend_name())?)?;
        out.into()
    }

    /// Encode a retrieval query into its 32 ColBERT vectors.
    /// @export
    fn encode_query(&self, text: &str) -> savvy::Result<ColbertEmbeddings> {
        if text.is_empty() {
            return Err(err("query must be a non-empty string"));
        }
        Ok(ColbertEmbeddings {
            inner: Arc::new(self.inner.encode_query(text)),
            kind: "query",
        })
    }

    /// Encode a retrieval document into its retained ColBERT vectors.
    /// @export
    fn encode_document(&self, text: &str) -> savvy::Result<ColbertEmbeddings> {
        if text.is_empty() {
            return Err(err("document must be a non-empty string"));
        }
        Ok(ColbertEmbeddings {
            inner: Arc::new(self.inner.encode_document(text)),
            kind: "document",
        })
    }
}

#[savvy]
impl ColbertEmbeddings {
    /// Return vector shape and role.
    /// @export
    fn info(&self) -> savvy::Result<savvy::Sexp> {
        let mut out = OwnedListSexp::new(3, true)?;
        out.set_name_and_value(0, "kind", str_scalar(self.kind)?)?;
        out.set_name_and_value(1, "tokens", int_scalar(self.inner.len() as i32)?)?;
        out.set_name_and_value(2, "dimensions", int_scalar(self.inner.dimensions as i32)?)?;
        out.into()
    }

    /// Return the model-input ids aligned with the token-vector rows.
    /// @export
    fn ids(&self) -> savvy::Result<savvy::Sexp> {
        ids_to_sexp(&self.inner.token_ids)?.into()
    }

    /// Return token-major vectors as an `n_tokens × dimensions` R numeric matrix.
    /// @export
    fn vectors(&self) -> savvy::Result<savvy::Sexp> {
        let n = self.inner.len();
        let d = self.inner.dimensions;
        let mut matrix = OwnedRealSexp::new(n * d)?;
        for row in 0..n {
            for column in 0..d {
                matrix.as_mut_slice()[row + column * n] =
                    self.inner.values[row * d + column] as f64;
            }
        }
        matrix.set_dim(&[n, d])?;
        matrix.into()
    }

    /// Score `document` against this query with ColBERT MaxSim.
    /// @export
    fn maxsim(&self, document: &ColbertEmbeddings) -> savvy::Result<savvy::Sexp> {
        if self.kind != "query" {
            return Err(err("MaxSim receiver must be query embeddings"));
        }
        if document.kind != "document" {
            return Err(err("MaxSim argument must be document embeddings"));
        }
        let score = maxsim(self.inner.as_ref(), document.inner.as_ref())
            .map_err(|error| err(error.to_string()))?;
        real_scalar(score as f64)?.into()
    }
}
