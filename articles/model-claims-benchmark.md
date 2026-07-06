# Benchmark harness

``` r

library(Rbebelm)
weights_file <- Sys.getenv("BEBELM_WEIGHTS_FILE", "/root/bebelm/LFM2.5-8B-A1B-Q4_K_M.gguf")
stopifnot(file.exists(weights_file))
model <- bebel_model_load(weights_file, num_threads = 2)
```

This vignette is a package-level harness for deterministic regression
benchmarks. It records outputs, token counts, and throughput. Domain
benchmarks for HPO, MONDO, ORPHANET, negation, and graph grounding can
reuse the same shape with real ontology prompts and expected labels.

``` r

tasks <- data.frame(
  id = c("capital-mali", "capital-italy", "capital-japan"),
  prompt = c(
    "The capital of Mali is",
    "The capital of Italy is",
    "The capital of Japan is"
  ),
  expected = c("Bamako", "Rome", "Tokyo"),
  stringsAsFactors = FALSE
)

run_one <- function(prompt) {
  out <- bebel_generate(model, prompt, greedy = TRUE, max_gen = 8, max_think = 0, on_event = NULL)
  list(
    text = trimws(out$text),
    prompt_tokens = out$prompt_tokens,
    generated_tokens = out$generated_tokens,
    prefill_tps = out$prefill_tps,
    decode_tps = out$decode_tps
  )
}

raw <- lapply(tasks$prompt, run_one)
bench <- cbind(
  tasks,
  do.call(rbind, lapply(raw, as.data.frame))
)
bench$matched <- grepl(bench$expected, bench$text, ignore.case = TRUE)
```

    ## Warning in grepl(bench$expected, bench$text, ignore.case = TRUE): argument
    ## 'pattern' has length > 1 and only the first element will be used

``` r

bench
```

    ##              id                  prompt expected
    ## 1  capital-mali  The capital of Mali is   Bamako
    ## 2 capital-italy The capital of Italy is     Rome
    ## 3 capital-japan The capital of Japan is    Tokyo
    ##                                text prompt_tokens generated_tokens prefill_tps
    ## 1       the city of Bamako. city of             6                8    10.05144
    ## 2      Rome. city of... ... ... ...             6                8    11.18184
    ## 3 Tokyo. city. The capital of Japan             6                8    11.21717
    ##   decode_tps matched
    ## 1   11.39013    TRUE
    ## 2   11.48716   FALSE
    ## 3   11.49185   FALSE

Async jobs let several bounded runs share one loaded model in the same R
process.

``` r

jobs <- lapply(tasks$prompt, function(prompt) {
  bebel_generate_async(model, prompt, greedy = TRUE, max_gen = 8, max_think = 0)
})

async <- lapply(jobs, bebel_async_collect, wait = TRUE)
data.frame(
  id = tasks$id,
  text = vapply(async, function(x) trimws(x$text), character(1)),
  generated_tokens = vapply(async, function(x) x$generated_tokens, integer(1)),
  decode_tps = vapply(async, function(x) x$decode_tps, numeric(1)),
  stringsAsFactors = FALSE
)
```

    ##              id                              text generated_tokens decode_tps
    ## 1  capital-mali       the city of Bamako. city of                8   11.62166
    ## 2 capital-italy      Rome. city of... ... ... ...                8   11.60975
    ## 3 capital-japan Tokyo. city. The capital of Japan                8   11.63875
