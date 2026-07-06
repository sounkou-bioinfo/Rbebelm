#ifndef RBEBELM_BACKEND_H
#define RBEBELM_BACKEND_H

#include <Rinternals.h>

void Rbebelm_init_backend(void);
int Rbebelm_backend_is_loaded(void);
void Rbebelm_request_backend(const char *backend);
const char *Rbebelm_requested_backend_name(void);
const char *Rbebelm_selected_backend_name(void);
const char *Rbebelm_installed_backend_names(void);
const char *Rbebelm_supported_backend_names(void);
const char *Rbebelm_dispatch_mode(void);

SEXP Rbebelm_set_backend_impl(SEXP backend_s);
SEXP Rbebelm_backend_info_impl(void);
SEXP Rbebelm_cpuid_info_impl(void);

SEXP Rbebelm_bebel_event_types_ffi(void);
SEXP Rbebelm_bebel_token_ids_ffi(void);
SEXP Rbebelm_backend_features_ffi(void);
SEXP Rbebelm_parse_tool_calls_ffi(SEXP c_arg__text);
SEXP Rbebelm_render_system_turn_ffi(SEXP c_arg__message, SEXP c_arg__tool_names, SEXP c_arg__tool_schemas);
SEXP Rbebelm_BebelAgent_append_ffi(SEXP self__, SEXP c_arg__text);
SEXP Rbebelm_BebelAgent_append_system_ffi(SEXP self__, SEXP c_arg__message);
SEXP Rbebelm_BebelAgent_append_system_with_tools_ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__tool_names, SEXP c_arg__tool_schemas);
SEXP Rbebelm_BebelAgent_append_tokens_ffi(SEXP self__, SEXP c_arg__ids);
SEXP Rbebelm_BebelAgent_append_tool_result_ffi(SEXP self__, SEXP c_arg__content);
SEXP Rbebelm_BebelAgent_append_user_ffi(SEXP self__, SEXP c_arg__message);
SEXP Rbebelm_BebelAgent_assistant_turn_ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event);
SEXP Rbebelm_BebelAgent_assistant_turn_async_ffi(SEXP self__);
SEXP Rbebelm_BebelAgent_assistant_turn_tool_stop_ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event);
SEXP Rbebelm_BebelAgent_assistant_turn_tool_stop_async_ffi(SEXP self__);
SEXP Rbebelm_BebelAgent_clear_ffi(SEXP self__);
SEXP Rbebelm_BebelAgent_clone_ffi(SEXP self__);
SEXP Rbebelm_BebelAgent_configure_ffi(SEXP self__, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP Rbebelm_BebelAgent_generate_ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event);
SEXP Rbebelm_BebelAgent_generate_async_ffi(SEXP self__);
SEXP Rbebelm_BebelAgent_history_ffi(SEXP self__);
SEXP Rbebelm_BebelAgent_info_ffi(SEXP self__);
SEXP Rbebelm_BebelAgent_new_ffi(SEXP c_arg__model, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP Rbebelm_BebelAgent_prefill_ffi(SEXP self__, SEXP c_arg__check_interrupt);
SEXP Rbebelm_BebelAgent_transcript_ffi(SEXP self__);
SEXP Rbebelm_BebelAsyncJob_events_ffi(SEXP self__, SEXP c_arg__max);
SEXP Rbebelm_BebelAsyncJob_ready_ffi(SEXP self__);
SEXP Rbebelm_BebelAsyncJob_result_ffi(SEXP self__, SEXP c_arg__wait);
SEXP Rbebelm_BebelModel_chat_ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP Rbebelm_BebelModel_chat_async_ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP Rbebelm_BebelModel_decode_ffi(SEXP self__, SEXP c_arg__ids);
SEXP Rbebelm_BebelModel_embed_ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos, SEXP c_arg__normalize, SEXP c_arg__pooling);
SEXP Rbebelm_BebelModel_encode_ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos);
SEXP Rbebelm_BebelModel_generate_ffi(SEXP self__, SEXP c_arg__prompt, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP Rbebelm_BebelModel_generate_async_ffi(SEXP self__, SEXP c_arg__prompt, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP Rbebelm_BebelModel_info_ffi(SEXP self__);
SEXP Rbebelm_BebelModel_load_ffi(SEXP c_arg__path, SEXP c_arg__num_threads);

#endif
