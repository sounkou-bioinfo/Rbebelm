# Unregister an extension from a running loop

Removes an extension by manifest name, rebuilds contributed catalogs,
and emits extension/catalog events for frontends.

## Usage

``` r
bebel_loop_unregister_extension(loop, name, missing_ok = FALSE)
```

## Arguments

- loop:

  A `bebelAgentLoop`.

- name:

  Extension manifest name.

- missing_ok:

  If `TRUE`, missing extensions are ignored.
