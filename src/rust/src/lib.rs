mod backend;
mod util;

#[cfg(not(target_os = "emscripten"))]
mod agent;
#[cfg(not(target_os = "emscripten"))]
mod chatml;
#[cfg(not(target_os = "emscripten"))]
mod events;
#[cfg(not(target_os = "emscripten"))]
mod generation;
#[cfg(not(target_os = "emscripten"))]
mod model;
#[cfg(not(target_os = "emscripten"))]
mod options;
#[cfg(not(target_os = "emscripten"))]
mod tokens;

#[cfg(target_os = "emscripten")]
mod wasm;
