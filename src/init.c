
// clang-format sorts includes unless SortIncludes: Never. However, the ordering
// does matter here. So, we need to disable clang-format for safety.

// clang-format off
#include <stdint.h>
#include <Rinternals.h>
#include <R_ext/Parse.h>
// clang-format on

#include "rbebelm_backend.h"

static uintptr_t TAGGED_POINTER_MASK = (uintptr_t)1;

SEXP handle_result(SEXP res_) {
    uintptr_t res = (uintptr_t)res_;

    // An error is indicated by tag.
    if ((res & TAGGED_POINTER_MASK) == 1) {
        // Remove tag
        SEXP res_aligned = (SEXP)(res & ~TAGGED_POINTER_MASK);

        // Currently, there are two types of error cases:
        //
        //   1. Error from Rust code
        //   2. Error from R's C API, which is caught by R_UnwindProtect()
        //
        if (TYPEOF(res_aligned) == CHARSXP) {
            // In case 1, the result is an error message that can be passed to
            // Rf_errorcall() directly.
            Rf_errorcall(R_NilValue, "%s", CHAR(res_aligned));
        } else {
            // In case 2, the result is the token to restart the
            // cleanup process on R's side.
            R_ContinueUnwind(res_aligned);
        }
    }

    return (SEXP)res;
}

SEXP savvy_bebel_event_types__impl(void) {
    SEXP res = Rbebelm_bebel_event_types_ffi();
    return handle_result(res);
}

SEXP savvy_bebel_token_ids__impl(void) {
    SEXP res = Rbebelm_bebel_token_ids_ffi();
    return handle_result(res);
}

SEXP savvy_rbebelm_backend_features__impl(void) {
    SEXP res = Rbebelm_backend_features_ffi();
    return handle_result(res);
}

SEXP savvy_rbebelm_json_parse__impl(SEXP c_arg__text) {
    SEXP res = Rbebelm_json_parse_ffi(c_arg__text);
    return handle_result(res);
}

SEXP savvy_rbebelm_json_tool_result__impl(SEXP c_arg__tool, SEXP c_arg__ok, SEXP c_arg__result, SEXP c_arg__error) {
    SEXP res = Rbebelm_json_tool_result_ffi(c_arg__tool, c_arg__ok, c_arg__result, c_arg__error);
    return handle_result(res);
}

SEXP savvy_BebelAgent_append__impl(SEXP self__, SEXP c_arg__text) {
    SEXP res = Rbebelm_BebelAgent_append_ffi(self__, c_arg__text);
    return handle_result(res);
}

SEXP savvy_BebelAgent_append_tokens__impl(SEXP self__, SEXP c_arg__ids) {
    SEXP res = Rbebelm_BebelAgent_append_tokens_ffi(self__, c_arg__ids);
    return handle_result(res);
}

SEXP savvy_BebelAgent_append_tool_result__impl(SEXP self__, SEXP c_arg__content) {
    SEXP res = Rbebelm_BebelAgent_append_tool_result_ffi(self__, c_arg__content);
    return handle_result(res);
}

SEXP savvy_BebelAgent_append_user__impl(SEXP self__, SEXP c_arg__message) {
    SEXP res = Rbebelm_BebelAgent_append_user_ffi(self__, c_arg__message);
    return handle_result(res);
}

SEXP savvy_BebelAgent_assistant_turn__impl(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event) {
    SEXP res = Rbebelm_BebelAgent_assistant_turn_ffi(self__, c_arg__check_interrupt, c_arg__on_event);
    return handle_result(res);
}

SEXP savvy_BebelAgent_clear__impl(SEXP self__) {
    SEXP res = Rbebelm_BebelAgent_clear_ffi(self__);
    return handle_result(res);
}

SEXP savvy_BebelAgent_configure__impl(SEXP self__, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) {
    SEXP res = Rbebelm_BebelAgent_configure_ffi(self__, c_arg__greedy, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty);
    return handle_result(res);
}

SEXP savvy_BebelAgent_generate__impl(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event) {
    SEXP res = Rbebelm_BebelAgent_generate_ffi(self__, c_arg__check_interrupt, c_arg__on_event);
    return handle_result(res);
}

SEXP savvy_BebelAgent_history__impl(SEXP self__) {
    SEXP res = Rbebelm_BebelAgent_history_ffi(self__);
    return handle_result(res);
}

SEXP savvy_BebelAgent_info__impl(SEXP self__) {
    SEXP res = Rbebelm_BebelAgent_info_ffi(self__);
    return handle_result(res);
}

SEXP savvy_BebelAgent_new__impl(SEXP c_arg__model, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) {
    SEXP res = Rbebelm_BebelAgent_new_ffi(c_arg__model, c_arg__greedy, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty);
    return handle_result(res);
}

SEXP savvy_BebelAgent_transcript__impl(SEXP self__) {
    SEXP res = Rbebelm_BebelAgent_transcript_ffi(self__);
    return handle_result(res);
}

SEXP savvy_BebelModel_chat__impl(SEXP self__, SEXP c_arg__message, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) {
    SEXP res = Rbebelm_BebelModel_chat_ffi(self__, c_arg__message, c_arg__greedy, c_arg__check_interrupt, c_arg__on_event, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty);
    return handle_result(res);
}

SEXP savvy_BebelModel_decode__impl(SEXP self__, SEXP c_arg__ids) {
    SEXP res = Rbebelm_BebelModel_decode_ffi(self__, c_arg__ids);
    return handle_result(res);
}

SEXP savvy_BebelModel_encode__impl(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos) {
    SEXP res = Rbebelm_BebelModel_encode_ffi(self__, c_arg__text, c_arg__add_bos);
    return handle_result(res);
}

SEXP savvy_BebelModel_generate__impl(SEXP self__, SEXP c_arg__prompt, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) {
    SEXP res = Rbebelm_BebelModel_generate_ffi(self__, c_arg__prompt, c_arg__greedy, c_arg__check_interrupt, c_arg__on_event, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty);
    return handle_result(res);
}

SEXP savvy_BebelModel_info__impl(SEXP self__) {
    SEXP res = Rbebelm_BebelModel_info_ffi(self__);
    return handle_result(res);
}

SEXP savvy_BebelModel_load__impl(SEXP c_arg__path, SEXP c_arg__num_threads) {
    SEXP res = Rbebelm_BebelModel_load_ffi(c_arg__path, c_arg__num_threads);
    return handle_result(res);
}


static const R_CallMethodDef CallEntries[] = {
    {"savvy_bebel_event_types__impl", (DL_FUNC) &savvy_bebel_event_types__impl, 0},
    {"savvy_bebel_token_ids__impl", (DL_FUNC) &savvy_bebel_token_ids__impl, 0},
    {"savvy_rbebelm_backend_features__impl", (DL_FUNC) &savvy_rbebelm_backend_features__impl, 0},
    {"savvy_rbebelm_json_parse__impl", (DL_FUNC) &savvy_rbebelm_json_parse__impl, 1},
    {"savvy_rbebelm_json_tool_result__impl", (DL_FUNC) &savvy_rbebelm_json_tool_result__impl, 4},
    {"savvy_BebelAgent_append__impl", (DL_FUNC) &savvy_BebelAgent_append__impl, 2},
    {"savvy_BebelAgent_append_tokens__impl", (DL_FUNC) &savvy_BebelAgent_append_tokens__impl, 2},
    {"savvy_BebelAgent_append_tool_result__impl", (DL_FUNC) &savvy_BebelAgent_append_tool_result__impl, 2},
    {"savvy_BebelAgent_append_user__impl", (DL_FUNC) &savvy_BebelAgent_append_user__impl, 2},
    {"savvy_BebelAgent_assistant_turn__impl", (DL_FUNC) &savvy_BebelAgent_assistant_turn__impl, 3},
    {"savvy_BebelAgent_clear__impl", (DL_FUNC) &savvy_BebelAgent_clear__impl, 1},
    {"savvy_BebelAgent_configure__impl", (DL_FUNC) &savvy_BebelAgent_configure__impl, 8},
    {"savvy_BebelAgent_generate__impl", (DL_FUNC) &savvy_BebelAgent_generate__impl, 3},
    {"savvy_BebelAgent_history__impl", (DL_FUNC) &savvy_BebelAgent_history__impl, 1},
    {"savvy_BebelAgent_info__impl", (DL_FUNC) &savvy_BebelAgent_info__impl, 1},
    {"savvy_BebelAgent_new__impl", (DL_FUNC) &savvy_BebelAgent_new__impl, 8},
    {"savvy_BebelAgent_transcript__impl", (DL_FUNC) &savvy_BebelAgent_transcript__impl, 1},
    {"savvy_BebelModel_chat__impl", (DL_FUNC) &savvy_BebelModel_chat__impl, 11},
    {"savvy_BebelModel_decode__impl", (DL_FUNC) &savvy_BebelModel_decode__impl, 2},
    {"savvy_BebelModel_encode__impl", (DL_FUNC) &savvy_BebelModel_encode__impl, 3},
    {"savvy_BebelModel_generate__impl", (DL_FUNC) &savvy_BebelModel_generate__impl, 11},
    {"savvy_BebelModel_info__impl", (DL_FUNC) &savvy_BebelModel_info__impl, 1},
    {"savvy_BebelModel_load__impl", (DL_FUNC) &savvy_BebelModel_load__impl, 2},
    {"Rbebelm_set_backend_impl", (DL_FUNC) &Rbebelm_set_backend_impl, 1},
    {"Rbebelm_backend_info_impl", (DL_FUNC) &Rbebelm_backend_info_impl, 0},
    {"Rbebelm_cpuid_info_impl", (DL_FUNC) &Rbebelm_cpuid_info_impl, 0},
    {NULL, NULL, 0}
};

void R_init_Rbebelm(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);

    // Functions for initialization, if any.

}
