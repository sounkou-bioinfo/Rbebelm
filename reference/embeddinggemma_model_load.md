# Load an EmbeddingGemma GGUF model

Loads the dedicated, retrieval-trained `gemma-embedding` architecture
through the package's pure-Rust CPU backend. The implementation does not
link to 'llama.cpp', 'PyTorch', the 'ONNX Runtime', or the
'SentencePiece' C++ library. Model weights remain subject to the Gemma
Terms of Use.

## Usage

``` r
embeddinggemma_model_load(path, num_threads = NULL)
```

## Arguments

- path:

  Path to an EmbeddingGemma GGUF file. The supported reference artifact
  is `embeddinggemma-300M-Q8_0.gguf` from
  `ggml-org/embeddinggemma-300M-GGUF`.

- num_threads:

  Optional Rayon global thread-pool size. This can only be set once per
  R process.

## Value

An `EmbeddingGemmaModel` object.
