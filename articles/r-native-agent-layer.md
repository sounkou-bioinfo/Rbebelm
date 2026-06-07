# R-native agent layer

RbebelM’s low-level API exposes model loading, ChatML turns, events, and
tool orchestration. The R-native agent layer builds a small harness on
top of those pieces: one session object can be driven from a console
loop or from a JSON-RPC server.

The layer is intentionally separate from the core model bindings. The
hot path is still BebeLM/Rust inference; the R layer owns session
policy, tool metadata, console interaction, and RPC.

## Create a session

``` r

library(Rbebelm)

model <- bebel_model_load(Sys.getenv("BEBELM_WEIGHTS_FILE"), num_threads = 2)
agent <- bebel_r_agent(
  model,
  allow_eval = FALSE,
  greedy = TRUE,
  max_gen = 128,
  max_think = 16
)
agent
#> <bebelRAgent>
#>   tools: r_objects, r_help, list_files, read_file, grep_files 
#>   history tokens: 98
```

The default tools are deliberately small:

``` r

library(Rbebelm)
tools <- bebel_default_r_tools(allow_eval = FALSE)
bebel_agent_tool_catalog(tools)
#>         name                                       description
#> 1  r_objects     List objects in the configured R environment.
#> 2     r_help Read R help for a topic, optionally in a package.
#> 3 list_files                     List files under a directory.
#> 4  read_file                                 Read a text file.
#> 5 grep_files                       Search text files by regex.
```

They include R object/documentation inspection and read-only file tools.
The `r_eval` tool is only included when the agent is created with
`allow_eval = TRUE`.

## Run a turn

``` r

turn <- bebel_r_agent_turn(
  agent,
  "Reply exactly: R agent ready.",
  max_steps = 1,
  on_event = NULL
)
trimws(sub("(?s)^.*</think>\\s*", "", turn$text, perl = TRUE))
#> [1] "R agent ready."
```

For interactive use, start the console loop:

``` r

bebel_r_agent_console(agent)
```

Or use the one-call launcher, which loads the model and then enters the
console:

``` r

bebel_r_agent_start(Sys.getenv("BEBELM_WEIGHTS_FILE", "LFM2.5-8B-A1B-Q4_K_M.gguf"))
```

The package also installs a small helper script in `inst/bin`:

``` r

agent_bin <- system.file("bin/rbebelm-agent", package = "Rbebelm")
system2(agent_bin, "--help")
```

Console commands include `/tools`, `/r`, `/rplot`, `/transcript`,
`/clear`, and `/quit`. The `/r` command evaluates R directly in the same
environment used by the agent’s R tools. For example, `/r x <- mtcars`
creates an object that `r_objects()` can later see. Visible `/r` output
is capped so large objects do not flood the chat prompt; assign objects
or use summaries such as `/r str(x)` for inspection. In an `Rscript`
terminal, use `/rplot plot(mpg ~ cyl, mtcars)` to save graphics as PNG
files under `rbebelm-plots/`. The `r_eval` and `r_plot` tools are only
advertised to the model when the session is created with
`allow_eval = TRUE`. The console prints a compact token/timing stats
line after each user turn.

## JSON-RPC SDK surface

The same session object can be served over a small JSON-RPC API. This is
not an OpenAI-compatible API; it is an SDK surface for controlling the
R-native agent. `nanonext` and `jsonlite` are optional dependencies used
only by this server.

``` r

server <- bebel_r_agent_rpc_server(agent, url = "http://127.0.0.1:8080")
server$start()
# ... handle requests ...
server$close()
```

Supported methods:

- `session/info`
- `tools/list`
- `session/transcript`
- `session/clear`
- `turn`

Example request body for `POST /rpc`:

``` json
{"jsonrpc":"2.0","id":1,"method":"turn","params":{"prompt":"List objects in the R session."}}
```

The console and RPC layers share the same session, transcript, tool
catalog, and BebeLM agent state.
