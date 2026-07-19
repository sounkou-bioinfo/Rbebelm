//! Registry for the deliberately small set of model architectures this fork supports.
//!
//! A GGUF container is not a model-runtime contract: tensor names, cache layout, tokenizer
//! conventions, operator graph, and quantization kernels are architecture-specific.  Keep
//! dispatch here explicit so adding a model means adding a complete, validated profile rather
//! than accepting an arbitrary GGUF and failing later in the forward pass.

use std::error::Error;
use std::fmt;

use crate::config;
use crate::gguf::GgufFile;

/// A model architecture with a complete CPU execution profile in this fork.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Architecture {
    /// Liquid AI LFM2.5-8B-A1B's hybrid short-convolution / attention MoE graph.
    Lfm2Moe,
}

impl Architecture {
    /// All architectures handled by the BebeLM generation loader.
    pub const SUPPORTED: [Self; 1] = [Self::Lfm2Moe];

    /// The `general.architecture` value expected in the GGUF metadata.
    pub const fn gguf_name(self) -> &'static str {
        match self {
            Self::Lfm2Moe => config::ARCH,
        }
    }

    /// Stable, human-readable identifier for diagnostics and host integrations.
    pub const fn profile_name(self) -> &'static str {
        match self {
            Self::Lfm2Moe => "lfm2.5-8b-a1b-cpu",
        }
    }
}

impl fmt::Display for Architecture {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.gguf_name())
    }
}

/// Select and validate the complete execution profile for `gguf`.
///
/// This is deliberately a closed registry. An unknown `general.architecture` is rejected
/// before tensor lookup or kernel execution, with the generation profiles this loader can
/// actually run. Other native profiles (such as ColBERT) use their own validated entry point.
pub fn select(gguf: &GgufFile) -> Result<Architecture, Box<dyn Error>> {
    let got = gguf.architecture().ok_or("missing general.architecture")?;
    let architecture = match got {
        config::ARCH => Architecture::Lfm2Moe,
        other => {
            let supported = Architecture::SUPPORTED
                .iter()
                .map(|profile| format!("{:?}", profile.gguf_name()))
                .collect::<Vec<_>>()
                .join(", ");
            return Err(format!(
                "unsupported GGUF architecture {other:?}; this build has complete CPU profiles for {supported}"
            )
            .into());
        }
    };

    match architecture {
        Architecture::Lfm2Moe => config::validate_lfm2moe(gguf)?,
    }
    Ok(architecture)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn profile_names_are_unique() {
        let mut names: Vec<_> = Architecture::SUPPORTED
            .iter()
            .map(|a| a.profile_name())
            .collect();
        names.sort_unstable();
        names.dedup();
        assert_eq!(names.len(), Architecture::SUPPORTED.len());
    }
}
