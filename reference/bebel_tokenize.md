# Tokenize text with a BebeLM model tokenizer

Tokenize text with a BebeLM model tokenizer

## Usage

``` r
bebel_tokenize(model, text, add_bos = TRUE)
```

## Arguments

- model:

  A `BebelModel` object.

- text:

  Text to encode.

- add_bos:

  Whether to prepend the BOS token.

## Value

Integer token ids.
