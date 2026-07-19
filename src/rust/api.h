SEXP savvy_bebel_event_types__ffi(void);
SEXP savvy_bebel_token_ids__ffi(void);
SEXP savvy_rbebelm_backend_features__ffi(void);
SEXP savvy_rbebelm_parse_tool_calls__ffi(SEXP c_arg__text);
SEXP savvy_rbebelm_render_system_turn__ffi(SEXP c_arg__message, SEXP c_arg__tool_names, SEXP c_arg__tool_schemas);

// methods and associated functions for BebelAgent
SEXP savvy_BebelAgent_append__ffi(SEXP self__, SEXP c_arg__text);
SEXP savvy_BebelAgent_append_system__ffi(SEXP self__, SEXP c_arg__message);
SEXP savvy_BebelAgent_append_system_with_tools__ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__tool_names, SEXP c_arg__tool_schemas);
SEXP savvy_BebelAgent_append_tokens__ffi(SEXP self__, SEXP c_arg__ids);
SEXP savvy_BebelAgent_append_tool_result__ffi(SEXP self__, SEXP c_arg__content);
SEXP savvy_BebelAgent_append_user__ffi(SEXP self__, SEXP c_arg__message);
SEXP savvy_BebelAgent_assistant_turn__ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event);
SEXP savvy_BebelAgent_assistant_turn_async__ffi(SEXP self__);
SEXP savvy_BebelAgent_assistant_turn_tool_stop__ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event);
SEXP savvy_BebelAgent_assistant_turn_tool_stop_async__ffi(SEXP self__);
SEXP savvy_BebelAgent_clear__ffi(SEXP self__);
SEXP savvy_BebelAgent_clone__ffi(SEXP self__);
SEXP savvy_BebelAgent_configure__ffi(SEXP self__, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP savvy_BebelAgent_generate__ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event);
SEXP savvy_BebelAgent_generate_async__ffi(SEXP self__);
SEXP savvy_BebelAgent_history__ffi(SEXP self__);
SEXP savvy_BebelAgent_info__ffi(SEXP self__);
SEXP savvy_BebelAgent_new__ffi(SEXP c_arg__model, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP savvy_BebelAgent_prefill__ffi(SEXP self__, SEXP c_arg__check_interrupt);
SEXP savvy_BebelAgent_transcript__ffi(SEXP self__);

// methods and associated functions for BebelAsyncJob
SEXP savvy_BebelAsyncJob_cancel__ffi(SEXP self__);
SEXP savvy_BebelAsyncJob_events__ffi(SEXP self__, SEXP c_arg__max);
SEXP savvy_BebelAsyncJob_ready__ffi(SEXP self__);
SEXP savvy_BebelAsyncJob_result__ffi(SEXP self__, SEXP c_arg__wait);

// methods and associated functions for BebelModel
SEXP savvy_BebelModel_chat__ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP savvy_BebelModel_chat_async__ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP savvy_BebelModel_decode__ffi(SEXP self__, SEXP c_arg__ids);
SEXP savvy_BebelModel_encode__ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos);
SEXP savvy_BebelModel_generate__ffi(SEXP self__, SEXP c_arg__prompt, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP savvy_BebelModel_generate_async__ffi(SEXP self__, SEXP c_arg__prompt, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty);
SEXP savvy_BebelModel_info__ffi(SEXP self__);
SEXP savvy_BebelModel_load__ffi(SEXP c_arg__path, SEXP c_arg__num_threads);

// methods and associated functions for ColbertEmbeddings
SEXP savvy_ColbertEmbeddings_ids__ffi(SEXP self__);
SEXP savvy_ColbertEmbeddings_info__ffi(SEXP self__);
SEXP savvy_ColbertEmbeddings_maxsim__ffi(SEXP self__, SEXP c_arg__document);
SEXP savvy_ColbertEmbeddings_vectors__ffi(SEXP self__);

// methods and associated functions for ColbertModel
SEXP savvy_ColbertModel_encode_document__ffi(SEXP self__, SEXP c_arg__text);
SEXP savvy_ColbertModel_encode_query__ffi(SEXP self__, SEXP c_arg__text);
SEXP savvy_ColbertModel_info__ffi(SEXP self__);
SEXP savvy_ColbertModel_load__ffi(SEXP c_arg__path, SEXP c_arg__num_threads);

// methods and associated functions for EmbeddingGemmaModel
SEXP savvy_EmbeddingGemmaModel_embed_batch__ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__dimensions, SEXP c_arg__normalize, SEXP c_arg__truncate, SEXP c_arg__check_interrupt);
SEXP savvy_EmbeddingGemmaModel_info__ffi(SEXP self__);
SEXP savvy_EmbeddingGemmaModel_load__ffi(SEXP c_arg__path, SEXP c_arg__num_threads);
SEXP savvy_EmbeddingGemmaModel_tokenize__ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__truncate);
