#!/usr/bin/env sh
# Compile every AArch64 runtime-dispatch variant. `cargo check` is insufficient:
# it does not assemble inline `sdot`, which is the failure R-universe reported.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
manifest="$root/src/rust/Cargo.toml"
target="aarch64-unknown-linux-gnu"
linker=${CARGO_AARCH64_LINKER:-aarch64-linux-gnu-gcc}
target_dir=$(mktemp -d "${TMPDIR:-/tmp}/rbebelm-aarch64.XXXXXX")

cleanup() {
  rm -rf "$target_dir"
}
trap cleanup EXIT HUP INT TERM

if ! command -v "$linker" >/dev/null 2>&1; then
  printf '%s\n' "missing AArch64 linker: $linker" >&2
  exit 1
fi

build_backend() {
  backend=$1
  features=$2
  rustflags=$3
  printf '%s\n' "=== Building AArch64 Rbebelm backend: $backend ==="
  env \
    CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER="$linker" \
    CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_RUSTFLAGS="$rustflags" \
    CARGO_TARGET_DIR="$target_dir/$backend" \
    cargo build \
      --manifest-path="$manifest" \
      --target="$target" \
      --no-default-features \
      --features="$features" \
      --lib \
      --release
}

# The scalar and NEON artifacts must not assemble dot-product instructions.
build_backend scalar portable "-C target-feature=-dotprod"
build_backend neon native-simd "-C target-feature=-dotprod"
# Only the dispatcher-selected dotprod artifact may contain `sdot`.
build_backend dotprod native-simd "-C target-feature=+dotprod"
