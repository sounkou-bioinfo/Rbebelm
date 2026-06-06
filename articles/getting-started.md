# Getting started

`Rbebelm` binds the Rust `bebelm` crate. Model weights are not bundled;
point the package at a local GGUF file.

``` r

library(Rbebelm)
rbebelm_backend_info()
#> $dispatch_mode
#> [1] "dynamic"
#> 
#> $requested_backend
#> [1] "auto"
#> 
#> $selected_backend
#> [1] "unknown"
#> 
#> $installed_backends
#> [1] "scalar,avx2,avx512"
#> 
#> $supported_backends
#> [1] "scalar,avx2"
#> 
#> $backend_loaded
#> [1] FALSE
```

``` r

weights <- Sys.getenv("BEBELM_WEIGHTS_FILE")
if (nzchar(weights) && file.exists(weights)) {
  model <- bebel_model_load(weights, num_threads = 2)
  bebel_chat(model, "Say hello from BebeLM.", max_gen = 32)

  agent <- bebel_agent(model, max_gen = 32)
  bebel_append_user(agent, "Remember this city: Paris.")
  bebel_assistant_turn(agent, on_event = NULL)
  bebel_append_user(agent, "Which city did I name?")
  bebel_assistant_turn(agent, on_event = NULL)
} else {
  message("Set BEBELM_WEIGHTS_FILE to run the model example.")
}
#> Set BEBELM_WEIGHTS_FILE to run the model example.
```
