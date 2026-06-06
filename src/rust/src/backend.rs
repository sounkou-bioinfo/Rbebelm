use savvy::{savvy, OwnedListSexp};

use crate::util::{bool_scalar, str_scalar};

pub fn backend_name() -> &'static str {
    if cfg!(target_feature = "avx512f") {
        "avx512"
    } else if cfg!(target_feature = "avx2") {
        "avx2"
    } else if cfg!(target_feature = "neon") {
        "neon"
    } else if cfg!(target_feature = "simd128") {
        "wasm_simd128"
    } else {
        "scalar"
    }
}

/// Return feature information reported by the loaded Rust backend.
/// @export
#[savvy]
pub fn rbebelm_backend_features() -> savvy::Result<savvy::Sexp> {
    let mut out = OwnedListSexp::new(10, true)?;
    out.set_name_and_value(0, "backend", str_scalar(backend_name())?)?;
    out.set_name_and_value(1, "target_arch", str_scalar(std::env::consts::ARCH)?)?;
    out.set_name_and_value(2, "target_os", str_scalar(std::env::consts::OS)?)?;
    out.set_name_and_value(3, "rust_package", str_scalar(env!("CARGO_PKG_NAME"))?)?;
    out.set_name_and_value(4, "rust_package_version", str_scalar(env!("CARGO_PKG_VERSION"))?)?;
    out.set_name_and_value(5, "native_simd_feature", bool_scalar(cfg!(feature = "native-simd"))?)?;
    out.set_name_and_value(6, "compiled_avx2", bool_scalar(cfg!(target_feature = "avx2"))?)?;
    out.set_name_and_value(7, "compiled_avx512f", bool_scalar(cfg!(target_feature = "avx512f"))?)?;
    out.set_name_and_value(8, "compiled_neon", bool_scalar(cfg!(target_feature = "neon"))?)?;
    out.set_name_and_value(9, "compiled_wasm_simd128", bool_scalar(cfg!(target_feature = "simd128"))?)?;
    out.into()
}
