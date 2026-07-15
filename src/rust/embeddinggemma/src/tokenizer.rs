//! SentencePiece-style tokenizer reconstructed from `tokenizer.ggml.*` GGUF metadata.
//!
//! EmbeddingGemma's GGUF declares the `llama` tokenizer model. Its tokenization algorithm is
//! the score-prioritized SentencePiece merge procedure used by llama.cpp: split into UTF-8 code
//! points, replace ASCII spaces with U+2581, repeatedly merge the highest-scoring adjacent token,
//! and fall back to byte tokens. No C/C++ SentencePiece runtime is required.

use std::cmp::Ordering;
use std::collections::{BinaryHeap, HashMap};
use std::error::Error;

use bebelm::gguf::GgufFile;

const TOKEN_TYPE_BYTE: u32 = 6;
const ESCAPED_SPACE: &str = "▁";

pub struct Tokenizer {
    tokens: Vec<String>,
    token_to_id: HashMap<String, u32>,
    scores: Vec<f32>,
    byte_to_id: [u32; 256],
    bos: u32,
    eos: u32,
    add_bos: bool,
    add_eos: bool,
}

#[derive(Clone, Copy, Debug)]
struct Symbol {
    start: usize,
    len: usize,
    prev: Option<usize>,
    next: Option<usize>,
}

#[derive(Clone, Copy, Debug)]
struct Bigram {
    left: usize,
    right: usize,
    score: f32,
    size: usize,
}

impl PartialEq for Bigram {
    fn eq(&self, other: &Self) -> bool {
        self.score.to_bits() == other.score.to_bits() && self.left == other.left
    }
}

impl Eq for Bigram {}

impl PartialOrd for Bigram {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Bigram {
    fn cmp(&self, other: &Self) -> Ordering {
        self.score
            .total_cmp(&other.score)
            // For equal scores SentencePiece resolves the leftmost merge first.
            .then_with(|| other.left.cmp(&self.left))
    }
}

impl Tokenizer {
    pub fn from_gguf(gguf: &GgufFile) -> Result<Self, Box<dyn Error>> {
        let model = gguf.get_str("tokenizer.ggml.model").unwrap_or("");
        if model != "llama" {
            return Err(format!(
                "unsupported EmbeddingGemma tokenizer model {model:?}; expected \"llama\""
            )
            .into());
        }
        let tokens = gguf
            .get_str_array("tokenizer.ggml.tokens")
            .ok_or("missing tokenizer.ggml.tokens")?;
        let scores = gguf
            .get_f32_array("tokenizer.ggml.scores")
            .ok_or("missing tokenizer.ggml.scores")?;
        let types = gguf
            .get_u32_array("tokenizer.ggml.token_type")
            .ok_or("missing tokenizer.ggml.token_type")?;
        if tokens.len() != scores.len() || tokens.len() != types.len() {
            return Err(format!(
                "tokenizer metadata length mismatch: {} tokens, {} scores, {} token types",
                tokens.len(),
                scores.len(),
                types.len()
            )
            .into());
        }
        if tokens.len() > u32::MAX as usize {
            return Err("tokenizer vocabulary does not fit in u32 ids".into());
        }

        let unknown = gguf.get_u32("tokenizer.ggml.unknown_token_id").unwrap_or(3);
        let bos = gguf.get_u32("tokenizer.ggml.bos_token_id").unwrap_or(2);
        let eos = gguf.get_u32("tokenizer.ggml.eos_token_id").unwrap_or(1);
        for (name, id) in [("unknown", unknown), ("BOS", bos), ("EOS", eos)] {
            if id as usize >= tokens.len() {
                return Err(format!(
                    "tokenizer {name} token id {id} is outside vocabulary size {}",
                    tokens.len()
                )
                .into());
            }
        }

        let mut byte_to_id = [unknown; 256];
        for (id, (token, &kind)) in tokens.iter().zip(&types).enumerate() {
            if kind == TOKEN_TYPE_BYTE {
                if let Some(byte) = parse_byte_token(token) {
                    byte_to_id[byte as usize] = id as u32;
                }
            }
        }

        let token_to_id = tokens
            .iter()
            .enumerate()
            .map(|(id, token)| (token.clone(), id as u32))
            .collect();
        Ok(Self {
            tokens,
            token_to_id,
            scores,
            byte_to_id,
            bos,
            eos,
            add_bos: gguf
                .get_bool("tokenizer.ggml.add_bos_token")
                .unwrap_or(true),
            add_eos: gguf
                .get_bool("tokenizer.ggml.add_eos_token")
                .unwrap_or(true),
        })
    }

    /// Encode one input using EmbeddingGemma's model-declared BOS/EOS policy.
    pub fn encode(&self, text: &str) -> Vec<u32> {
        let mut out = Vec::new();
        if self.add_bos {
            out.push(self.bos);
        }
        if !text.is_empty() {
            let escaped = text.replace(' ', ESCAPED_SPACE);
            self.encode_escaped(&escaped, &mut out);
        }
        if self.add_eos {
            out.push(self.eos);
        }
        out
    }

    /// Return a legible token piece. U+2581 is rendered as a regular space.
    pub fn token_piece(&self, id: u32) -> Option<String> {
        self.tokens
            .get(id as usize)
            .map(|piece| piece.replace(ESCAPED_SPACE, " "))
    }

    pub fn bos_id(&self) -> u32 {
        self.bos
    }

    pub fn eos_id(&self) -> u32 {
        self.eos
    }

    pub fn adds_eos(&self) -> bool {
        self.add_eos
    }

    pub fn vocab_size(&self) -> usize {
        self.tokens.len()
    }

    fn encode_escaped(&self, text: &str, out: &mut Vec<u32>) {
        let mut starts: Vec<usize> = text.char_indices().map(|(i, _)| i).collect();
        starts.push(text.len());
        if starts.len() <= 1 {
            return;
        }
        let n = starts.len() - 1;
        let mut symbols: Vec<Symbol> = (0..n)
            .map(|i| Symbol {
                start: starts[i],
                len: starts[i + 1] - starts[i],
                prev: i.checked_sub(1),
                next: (i + 1 < n).then_some(i + 1),
            })
            .collect();
        let mut heap = BinaryHeap::new();
        for right in 1..n {
            self.try_add_bigram(text, &symbols, right - 1, right, &mut heap);
        }

        while let Some(bigram) = heap.pop() {
            let left = symbols[bigram.left];
            let right = symbols[bigram.right];
            if left.len == 0
                || right.len == 0
                || left.next != Some(bigram.right)
                || left.len + right.len != bigram.size
            {
                continue;
            }

            symbols[bigram.left].len += right.len;
            symbols[bigram.right].len = 0;
            symbols[bigram.left].next = right.next;
            if let Some(next) = right.next {
                symbols[next].prev = Some(bigram.left);
            }
            if let Some(prev) = symbols[bigram.left].prev {
                self.try_add_bigram(text, &symbols, prev, bigram.left, &mut heap);
            }
            if let Some(next) = symbols[bigram.left].next {
                self.try_add_bigram(text, &symbols, bigram.left, next, &mut heap);
            }
        }

        let mut current = Some(0usize);
        while let Some(i) = current {
            let symbol = symbols[i];
            let piece = &text[symbol.start..symbol.start + symbol.len];
            if let Some(&id) = self.token_to_id.get(piece) {
                out.push(id);
            } else {
                for &byte in piece.as_bytes() {
                    out.push(self.byte_to_id[byte as usize]);
                }
            }
            current = symbol.next;
        }
    }

    fn try_add_bigram(
        &self,
        text: &str,
        symbols: &[Symbol],
        left: usize,
        right: usize,
        heap: &mut BinaryHeap<Bigram>,
    ) {
        if symbols[left].len == 0 || symbols[right].len == 0 || symbols[left].next != Some(right) {
            return;
        }
        let size = symbols[left].len + symbols[right].len;
        let start = symbols[left].start;
        let piece = &text[start..start + size];
        if let Some(&id) = self.token_to_id.get(piece) {
            heap.push(Bigram {
                left,
                right,
                score: self.scores[id as usize],
                size,
            });
        }
    }
}

fn parse_byte_token(token: &str) -> Option<u8> {
    let hex = token.strip_prefix("<0x")?.strip_suffix('>')?;
    (hex.len() == 2)
        .then(|| u8::from_str_radix(hex, 16).ok())
        .flatten()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tokenizer() -> Tokenizer {
        let tokens = vec![
            "<pad>", "<eos>", "<bos>", "<unk>", "a", "b", "c", "ab", "bc", "abc", "▁", "▁a",
        ]
        .into_iter()
        .map(str::to_string)
        .collect::<Vec<_>>();
        let scores = vec![
            -1000.0, -1000.0, -1000.0, -1000.0, -5.0, -5.0, -5.0, -2.0, -3.0, -1.0, -2.0, -1.0,
        ];
        let token_to_id = tokens
            .iter()
            .enumerate()
            .map(|(i, s)| (s.clone(), i as u32))
            .collect();
        Tokenizer {
            tokens,
            token_to_id,
            scores,
            byte_to_id: [3; 256],
            bos: 2,
            eos: 1,
            add_bos: true,
            add_eos: true,
        }
    }

    #[test]
    fn highest_scoring_merges_win() {
        assert_eq!(tokenizer().encode("abc"), vec![2, 9, 1]);
    }

    #[test]
    fn spaces_are_sentencepiece_markers() {
        assert_eq!(tokenizer().encode(" a"), vec![2, 11, 1]);
    }

    #[test]
    fn empty_input_still_gets_model_specials() {
        assert_eq!(tokenizer().encode(""), vec![2, 1]);
    }

    #[test]
    fn byte_token_parser_is_strict() {
        assert_eq!(parse_byte_token("<0xAF>"), Some(0xaf));
        assert_eq!(parse_byte_token("<0x0>"), None);
        assert_eq!(parse_byte_token("AF"), None);
    }
}
