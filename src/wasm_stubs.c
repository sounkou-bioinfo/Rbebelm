#include <stddef.h>
#include <stdint.h>
#include <Rinternals.h>
#include "rust/api.h"

/* webR/wasm compatibility shim.
 * savvy itself supports webR, but upstream BebeLM currently depends on
 * mmap/GGUF loading and a multi-GB model artifact that is not browser-viable.
 * These functions implement the same savvy FFI ABI and fail explicitly for
 * model/agent operations while keeping metadata APIs loadable in webR.
 */

static SEXP rbebelm_wasm_savvy_error(void) {
    SEXP msg = Rf_mkChar("BebeLM GGUF inference is not supported in webR/Emscripten builds; use desktop R for model loading/generation");
    return (SEXP)(((uintptr_t)msg) | (uintptr_t)1);
}

static SEXP wasm_string_vector(const char *const *values, int n) {
    SEXP out = PROTECT(Rf_allocVector(STRSXP, n));
    for (int i = 0; i < n; i++) SET_STRING_ELT(out, i, Rf_mkChar(values[i]));
    UNPROTECT(1);
    return out;
}

static SEXP wasm_event_types(void) {
    static const char *const values[] = {"start","thinking_start","thinking_delta","thinking_end","text_start","text_delta","text_end","tool_list_start","tool_list_delta","tool_list_end","tool_call_start","tool_call_delta","tool_call_end","done"};
    return wasm_string_vector(values, (int)(sizeof(values) / sizeof(values[0])));
}

static SEXP wasm_token_ids(void) {
    static const char *const names_c[] = {"TOKEN_PAD","TOKEN_BOS","TOKEN_ENDOFTEXT","TOKEN_FIM_PRE","TOKEN_FIM_MID","TOKEN_FIM_SUF","TOKEN_IM_START","TOKEN_IM_END","TOKEN_EOS","TOKEN_THINK","TOKEN_THINK_END","TOKEN_TOOL_LIST_START","TOKEN_TOOL_LIST_END","TOKEN_TOOL_CALL_START","TOKEN_TOOL_CALL_END"};
    static const int values[] = {124893,124894,124895,124896,124897,124898,124899,124900,124900,124901,124902,124903,124904,124905,124906};
    int n = (int)(sizeof(values) / sizeof(values[0]));
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, n));
    for (int i = 0; i < n; i++) { INTEGER(out)[i] = values[i]; SET_STRING_ELT(names, i, Rf_mkChar(names_c[i])); }
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}

static SEXP wasm_backend_features(void) {
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 10));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 10));
    const char *nms[] = {"backend","target_arch","target_os","rust_package","rust_package_version","native_simd_feature","compiled_avx2","compiled_avx512f","compiled_neon","compiled_wasm_simd128"};
    for (int i = 0; i < 10; i++) SET_STRING_ELT(names, i, Rf_mkChar(nms[i]));
    SET_VECTOR_ELT(out, 0, Rf_mkString("wasm_simd128"));
    SET_VECTOR_ELT(out, 1, Rf_mkString("wasm32"));
    SET_VECTOR_ELT(out, 2, Rf_mkString("emscripten"));
    SET_VECTOR_ELT(out, 3, Rf_mkString("rbebelm_backend"));
    SET_VECTOR_ELT(out, 4, Rf_mkString("0.0.0"));
    SET_VECTOR_ELT(out, 5, Rf_ScalarLogical(0));
    SET_VECTOR_ELT(out, 6, Rf_ScalarLogical(0));
    SET_VECTOR_ELT(out, 7, Rf_ScalarLogical(0));
    SET_VECTOR_ELT(out, 8, Rf_ScalarLogical(0));
    SET_VECTOR_ELT(out, 9, Rf_ScalarLogical(1));
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}

SEXP savvy_bebel_event_types__ffi(void) {
    return wasm_event_types();
}

SEXP savvy_bebel_token_ids__ffi(void) {
    return wasm_token_ids();
}

SEXP savvy_rbebelm_backend_features__ffi(void) {
    return wasm_backend_features();
}

SEXP savvy_BebelAgent_append__ffi(SEXP self__, SEXP c_arg__text) {
    (void)self__;
    (void)c_arg__text;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_append_tokens__ffi(SEXP self__, SEXP c_arg__ids) {
    (void)self__;
    (void)c_arg__ids;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_append_tool_result__ffi(SEXP self__, SEXP c_arg__content) {
    (void)self__;
    (void)c_arg__content;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_append_user__ffi(SEXP self__, SEXP c_arg__message) {
    (void)self__;
    (void)c_arg__message;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_assistant_turn__ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event) {
    (void)self__;
    (void)c_arg__check_interrupt;
    (void)c_arg__on_event;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_clear__ffi(SEXP self__) {
    (void)self__;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_configure__ffi(SEXP self__, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) {
    (void)self__;
    (void)c_arg__greedy;
    (void)c_arg__max_gen;
    (void)c_arg__max_context;
    (void)c_arg__max_think;
    (void)c_arg__temperature;
    (void)c_arg__top_k;
    (void)c_arg__repeat_penalty;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_generate__ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event) {
    (void)self__;
    (void)c_arg__check_interrupt;
    (void)c_arg__on_event;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_history__ffi(SEXP self__) {
    (void)self__;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_info__ffi(SEXP self__) {
    (void)self__;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_new__ffi(SEXP c_arg__model, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) {
    (void)c_arg__model;
    (void)c_arg__greedy;
    (void)c_arg__max_gen;
    (void)c_arg__max_context;
    (void)c_arg__max_think;
    (void)c_arg__temperature;
    (void)c_arg__top_k;
    (void)c_arg__repeat_penalty;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelAgent_transcript__ffi(SEXP self__) {
    (void)self__;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelModel_chat__ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) {
    (void)self__;
    (void)c_arg__message;
    (void)c_arg__greedy;
    (void)c_arg__check_interrupt;
    (void)c_arg__on_event;
    (void)c_arg__max_gen;
    (void)c_arg__max_context;
    (void)c_arg__max_think;
    (void)c_arg__temperature;
    (void)c_arg__top_k;
    (void)c_arg__repeat_penalty;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelModel_decode__ffi(SEXP self__, SEXP c_arg__ids) {
    (void)self__;
    (void)c_arg__ids;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelModel_encode__ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos) {
    (void)self__;
    (void)c_arg__text;
    (void)c_arg__add_bos;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelModel_generate__ffi(SEXP self__, SEXP c_arg__prompt, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) {
    (void)self__;
    (void)c_arg__prompt;
    (void)c_arg__greedy;
    (void)c_arg__check_interrupt;
    (void)c_arg__on_event;
    (void)c_arg__max_gen;
    (void)c_arg__max_context;
    (void)c_arg__max_think;
    (void)c_arg__temperature;
    (void)c_arg__top_k;
    (void)c_arg__repeat_penalty;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelModel_info__ffi(SEXP self__) {
    (void)self__;
    return rbebelm_wasm_savvy_error();
}

SEXP savvy_BebelModel_load__ffi(SEXP c_arg__path, SEXP c_arg__num_threads) {
    (void)c_arg__path;
    (void)c_arg__num_threads;
    return rbebelm_wasm_savvy_error();
}
