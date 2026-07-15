#define _GNU_SOURCE
#include <R.h>
#include <Rinternals.h>

#include "rbebelm_backend.h"
#ifdef __EMSCRIPTEN__
#include "rust/api.h"
#endif

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#if defined(_WIN32)
#include <windows.h>
#define RBEBELM_DYLIB_EXT ".dll"
#else
#include <dlfcn.h>
#include <libgen.h>
#include <unistd.h>
#if defined(__linux__) && defined(__aarch64__)
#include <sys/auxv.h>
#include <asm/hwcap.h>
#endif
#if defined(__APPLE__) && defined(__aarch64__)
#include <sys/types.h>
#include <sys/sysctl.h>
#endif
#define RBEBELM_DYLIB_EXT ".so"
#if defined(__APPLE__)
#undef RBEBELM_DYLIB_EXT
#define RBEBELM_DYLIB_EXT ".dylib"
#endif
#endif

#define RBEBELM_ARRAY_LEN(x) (sizeof(x) / sizeof((x)[0]))

static const char *const RBEBELM_BACKENDS[] = {
    "scalar",
    "neon",
    "dotprod",
    "avx2",
    "avx512",
    "wasm_simd128",
};

static const char *const RBEBELM_PRIORITY[] = {
    "wasm_simd128",
    "avx512",
    "avx2",
    "dotprod",
    "neon",
    "scalar",
};

typedef SEXP (*fn_001)(void);
static fn_001 p_001 = NULL;
typedef SEXP (*fn_002)(void);
static fn_002 p_002 = NULL;
typedef SEXP (*fn_003)(void);
static fn_003 p_003 = NULL;
typedef SEXP (*fn_004)(SEXP);
static fn_004 p_004 = NULL;
typedef SEXP (*fn_005)(SEXP, SEXP, SEXP);
static fn_005 p_005 = NULL;
typedef SEXP (*fn_006)(SEXP, SEXP);
static fn_006 p_006 = NULL;
typedef SEXP (*fn_007)(SEXP, SEXP);
static fn_007 p_007 = NULL;
typedef SEXP (*fn_008)(SEXP, SEXP, SEXP, SEXP);
static fn_008 p_008 = NULL;
typedef SEXP (*fn_009)(SEXP, SEXP);
static fn_009 p_009 = NULL;
typedef SEXP (*fn_010)(SEXP, SEXP);
static fn_010 p_010 = NULL;
typedef SEXP (*fn_011)(SEXP, SEXP);
static fn_011 p_011 = NULL;
typedef SEXP (*fn_012)(SEXP, SEXP, SEXP);
static fn_012 p_012 = NULL;
typedef SEXP (*fn_013)(SEXP);
static fn_013 p_013 = NULL;
typedef SEXP (*fn_014)(SEXP, SEXP, SEXP);
static fn_014 p_014 = NULL;
typedef SEXP (*fn_015)(SEXP);
static fn_015 p_015 = NULL;
typedef SEXP (*fn_016)(SEXP);
static fn_016 p_016 = NULL;
typedef SEXP (*fn_017)(SEXP);
static fn_017 p_017 = NULL;
typedef SEXP (*fn_018)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_018 p_018 = NULL;
typedef SEXP (*fn_019)(SEXP, SEXP, SEXP);
static fn_019 p_019 = NULL;
typedef SEXP (*fn_020)(SEXP);
static fn_020 p_020 = NULL;
typedef SEXP (*fn_021)(SEXP);
static fn_021 p_021 = NULL;
typedef SEXP (*fn_022)(SEXP);
static fn_022 p_022 = NULL;
typedef SEXP (*fn_023)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_023 p_023 = NULL;
typedef SEXP (*fn_024)(SEXP, SEXP);
static fn_024 p_024 = NULL;
typedef SEXP (*fn_025)(SEXP);
static fn_025 p_025 = NULL;
typedef SEXP (*fn_026)(SEXP);
static fn_026 p_026 = NULL;
typedef SEXP (*fn_027)(SEXP, SEXP);
static fn_027 p_027 = NULL;
typedef SEXP (*fn_028)(SEXP);
static fn_028 p_028 = NULL;
typedef SEXP (*fn_029)(SEXP, SEXP);
static fn_029 p_029 = NULL;
typedef SEXP (*fn_030)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_030 p_030 = NULL;
typedef SEXP (*fn_031)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_031 p_031 = NULL;
typedef SEXP (*fn_032)(SEXP, SEXP);
static fn_032 p_032 = NULL;
typedef SEXP (*fn_033)(SEXP, SEXP, SEXP);
static fn_033 p_033 = NULL;
typedef SEXP (*fn_034)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_034 p_034 = NULL;
typedef SEXP (*fn_035)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_035 p_035 = NULL;
typedef SEXP (*fn_036)(SEXP);
static fn_036 p_036 = NULL;
typedef SEXP (*fn_037)(SEXP, SEXP);
static fn_037 p_037 = NULL;
typedef SEXP (*fn_038)(SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_038 p_038 = NULL;
typedef SEXP (*fn_039)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_039 p_039 = NULL;
typedef SEXP (*fn_040)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_040 p_040 = NULL;
typedef SEXP (*fn_041)(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
static fn_041 p_041 = NULL;
typedef SEXP (*fn_042)(SEXP);
static fn_042 p_042 = NULL;
typedef SEXP (*fn_043)(SEXP, SEXP);
static fn_043 p_043 = NULL;
typedef SEXP (*fn_044)(SEXP, SEXP, SEXP);
static fn_044 p_044 = NULL;

#ifdef __EMSCRIPTEN__
static void bind_static_backend_symbols(void) {
    p_001 = (fn_001)savvy_bebel_event_types__ffi;
    p_002 = (fn_002)savvy_bebel_token_ids__ffi;
    p_003 = (fn_003)savvy_rbebelm_backend_features__ffi;
    p_004 = (fn_004)savvy_rbebelm_parse_tool_calls__ffi;
    p_005 = (fn_005)savvy_rbebelm_render_system_turn__ffi;
    p_006 = (fn_006)savvy_BebelAgent_append__ffi;
    p_007 = (fn_007)savvy_BebelAgent_append_system__ffi;
    p_008 = (fn_008)savvy_BebelAgent_append_system_with_tools__ffi;
    p_009 = (fn_009)savvy_BebelAgent_append_tokens__ffi;
    p_010 = (fn_010)savvy_BebelAgent_append_tool_result__ffi;
    p_011 = (fn_011)savvy_BebelAgent_append_user__ffi;
    p_012 = (fn_012)savvy_BebelAgent_assistant_turn__ffi;
    p_013 = (fn_013)savvy_BebelAgent_assistant_turn_async__ffi;
    p_014 = (fn_014)savvy_BebelAgent_assistant_turn_tool_stop__ffi;
    p_015 = (fn_015)savvy_BebelAgent_assistant_turn_tool_stop_async__ffi;
    p_016 = (fn_016)savvy_BebelAgent_clear__ffi;
    p_017 = (fn_017)savvy_BebelAgent_clone__ffi;
    p_018 = (fn_018)savvy_BebelAgent_configure__ffi;
    p_019 = (fn_019)savvy_BebelAgent_generate__ffi;
    p_020 = (fn_020)savvy_BebelAgent_generate_async__ffi;
    p_021 = (fn_021)savvy_BebelAgent_history__ffi;
    p_022 = (fn_022)savvy_BebelAgent_info__ffi;
    p_023 = (fn_023)savvy_BebelAgent_new__ffi;
    p_024 = (fn_024)savvy_BebelAgent_prefill__ffi;
    p_025 = (fn_025)savvy_BebelAgent_transcript__ffi;
    p_026 = (fn_026)savvy_BebelAsyncJob_cancel__ffi;
    p_027 = (fn_027)savvy_BebelAsyncJob_events__ffi;
    p_028 = (fn_028)savvy_BebelAsyncJob_ready__ffi;
    p_029 = (fn_029)savvy_BebelAsyncJob_result__ffi;
    p_030 = (fn_030)savvy_BebelModel_chat__ffi;
    p_031 = (fn_031)savvy_BebelModel_chat_async__ffi;
    p_032 = (fn_032)savvy_BebelModel_decode__ffi;
    p_033 = (fn_033)savvy_BebelModel_encode__ffi;
    p_034 = (fn_034)savvy_BebelModel_generate__ffi;
    p_035 = (fn_035)savvy_BebelModel_generate_async__ffi;
    p_036 = (fn_036)savvy_BebelModel_info__ffi;
    p_037 = (fn_037)savvy_BebelModel_load__ffi;
    p_038 = (fn_038)savvy_BebelModel_pooled_states__ffi;
    p_039 = (fn_039)savvy_BebelModel_pooled_states_batch__ffi;
    p_040 = (fn_040)savvy_BebelModel_token_states__ffi;
    p_041 = (fn_041)savvy_EmbeddingGemmaModel_embed_batch__ffi;
    p_042 = (fn_042)savvy_EmbeddingGemmaModel_info__ffi;
    p_043 = (fn_043)savvy_EmbeddingGemmaModel_load__ffi;
    p_044 = (fn_044)savvy_EmbeddingGemmaModel_tokenize__ffi;
}
#endif

static int backend_loaded = 0;
static char requested_backend[32] = "";
static char selected_backend[32] = "";
static char installed_backends[128] = "";
static char supported_backends[128] = "";

static void append_csv(char *out, size_t out_size, const char *name) {
    size_t n = strlen(out);
    if (n > 0 && n + 1 < out_size) {
        out[n++] = ',';
        out[n] = '\0';
    }
    if (n < out_size) {
        strncat(out, name, out_size - n - 1);
    }
}

static int csv_has(const char *csv, const char *name) {
    size_t name_len = strlen(name);
    const char *p = csv == NULL ? "" : csv;
    while (*p != '\0') {
        while (*p == ',' || *p == ' ' || *p == '\t') p++;
        const char *start = p;
        while (*p != '\0' && *p != ',') p++;
        const char *end = p;
        while (end > start && (end[-1] == ' ' || end[-1] == '\t')) end--;
        if ((size_t)(end - start) == name_len && strncmp(start, name, name_len) == 0) {
            return 1;
        }
    }
    return 0;
}

static int known_backend(const char *backend) {
    if (backend == NULL) return 0;
    for (size_t i = 0; i < RBEBELM_ARRAY_LEN(RBEBELM_BACKENDS); i++) {
        if (strcmp(backend, RBEBELM_BACKENDS[i]) == 0) return 1;
    }
    return 0;
}

/* Runtime CPU checks copied in spirit from Rsassy: check the CPU and OS register
 * state before loading a backend compiled for a higher x86-64 level. */
#if defined(__x86_64__) || defined(_M_X64)
typedef struct CpuRegs { unsigned int eax, ebx, ecx, edx; } CpuRegs;

enum { LEAF_1 = 1u, LEAF_7 = 7u, EXT_LEAF_1 = 0x80000001u };
enum {
    ECX_SSE3 = 0, ECX_SSSE3 = 9, ECX_FMA = 12, ECX_SSE41 = 19,
    ECX_SSE42 = 20, ECX_MOVBE = 22, ECX_POPCNT = 23, ECX_XSAVE = 26,
    ECX_OSXSAVE = 27, ECX_AVX = 28, ECX_F16C = 29, EXT_ECX_LZCNT = 5
};
enum {
    EBX_BMI1 = 3, EBX_AVX2 = 5, EBX_BMI2 = 8, EBX_AVX512F = 16,
    EBX_AVX512DQ = 17, EBX_AVX512CD = 28, EBX_AVX512BW = 30, EBX_AVX512VL = 31
};

static CpuRegs cpuid_leaf(unsigned int leaf, unsigned int subleaf) {
    CpuRegs out;
#if defined(_MSC_VER)
    int regs[4];
    __cpuidex(regs, (int)leaf, (int)subleaf);
    out.eax = (unsigned int)regs[0]; out.ebx = (unsigned int)regs[1];
    out.ecx = (unsigned int)regs[2]; out.edx = (unsigned int)regs[3];
#else
    __asm__ volatile("cpuid" : "=a"(out.eax), "=b"(out.ebx), "=c"(out.ecx), "=d"(out.edx) : "a"(leaf), "c"(subleaf));
#endif
    return out;
}

static uint64_t xgetbv0(void) {
#if defined(_MSC_VER)
    return (uint64_t)_xgetbv(0);
#else
    unsigned int eax, edx;
    __asm__ volatile("xgetbv" : "=a"(eax), "=d"(edx) : "c"(0));
    return ((uint64_t)edx << 32) | eax;
#endif
}

static int bit(unsigned int value, unsigned int b) { return (value & (1u << b)) != 0; }
static int has_leaf(unsigned int leaf) { return cpuid_leaf(0, 0).eax >= leaf; }
static int has_ext_leaf(unsigned int leaf) { return cpuid_leaf(0x80000000u, 0).eax >= leaf; }
static int os_saves_ymm(const CpuRegs *leaf1) {
    if (!bit(leaf1->ecx, ECX_XSAVE) || !bit(leaf1->ecx, ECX_OSXSAVE)) return 0;
    return (xgetbv0() & 0x6u) == 0x6u;
}
static int os_saves_zmm(const CpuRegs *leaf1) {
    if (!os_saves_ymm(leaf1)) return 0;
    return (xgetbv0() & 0xE6u) == 0xE6u;
}

static int cpu_x86_64_v3(void) {
    if (!has_leaf(LEAF_7) || !has_ext_leaf(EXT_LEAF_1)) return 0;
    CpuRegs l1 = cpuid_leaf(LEAF_1, 0);
    if (!os_saves_ymm(&l1)) return 0;
    CpuRegs l7 = cpuid_leaf(LEAF_7, 0);
    CpuRegs e1 = cpuid_leaf(EXT_LEAF_1, 0);
    return bit(l1.ecx, ECX_SSE3) && bit(l1.ecx, ECX_SSSE3) && bit(l1.ecx, ECX_FMA) &&
           bit(l1.ecx, ECX_SSE41) && bit(l1.ecx, ECX_SSE42) && bit(l1.ecx, ECX_MOVBE) &&
           bit(l1.ecx, ECX_POPCNT) && bit(l1.ecx, ECX_AVX) && bit(l1.ecx, ECX_F16C) &&
           bit(l7.ebx, EBX_BMI1) && bit(l7.ebx, EBX_AVX2) && bit(l7.ebx, EBX_BMI2) &&
           bit(e1.ecx, EXT_ECX_LZCNT);
}

static int cpu_x86_64_v4(void) {
    if (!cpu_x86_64_v3() || !has_leaf(LEAF_7)) return 0;
    CpuRegs l1 = cpuid_leaf(LEAF_1, 0);
    if (!os_saves_zmm(&l1)) return 0;
    CpuRegs l7 = cpuid_leaf(LEAF_7, 0);
    return bit(l7.ebx, EBX_AVX512F) && bit(l7.ebx, EBX_AVX512DQ) &&
           bit(l7.ebx, EBX_AVX512CD) && bit(l7.ebx, EBX_AVX512BW) && bit(l7.ebx, EBX_AVX512VL);
}
#else
static int cpu_x86_64_v3(void) { return 0; }
static int cpu_x86_64_v4(void) { return 0; }
#endif

static int cpu_neon(void) {
#if defined(__aarch64__) || defined(_M_ARM64)
    return 1;
#else
    return 0;
#endif
}

static int cpu_dotprod(void) {
#if defined(__aarch64__) && defined(__ARM_FEATURE_DOTPROD)
    return 1;
#elif defined(__linux__) && defined(__aarch64__) && defined(HWCAP_ASIMDDP)
    return (getauxval(AT_HWCAP) & HWCAP_ASIMDDP) != 0;
#elif defined(__APPLE__) && defined(__aarch64__)
    int value = 0;
    size_t len = sizeof(value);
    if (sysctlbyname("hw.optional.arm.FEAT_DotProd", &value, &len, NULL, 0) == 0) return value != 0;
    return 0;
#elif defined(_WIN32) && defined(_M_ARM64) && defined(PF_ARM_V82_DP_INSTRUCTIONS_AVAILABLE)
    return IsProcessorFeaturePresent(PF_ARM_V82_DP_INSTRUCTIONS_AVAILABLE) != 0;
#else
    return 0;
#endif
}

static int cpu_wasm_simd128(void) {
#ifdef __EMSCRIPTEN__
    return 1;
#else
    return 0;
#endif
}

static int backend_supported(const char *backend) {
    if (strcmp(backend, "scalar") == 0) return 1;
    if (strcmp(backend, "avx2") == 0) return cpu_x86_64_v3();
    if (strcmp(backend, "avx512") == 0) return cpu_x86_64_v4();
    if (strcmp(backend, "dotprod") == 0) return cpu_dotprod();
    if (strcmp(backend, "neon") == 0) return cpu_neon();
    if (strcmp(backend, "wasm_simd128") == 0) return cpu_wasm_simd128();
    return 0;
}

static int backend_in_this_build(const char *backend) {
#ifdef __EMSCRIPTEN__
    return strcmp(backend, "wasm_simd128") == 0;
#else
    return strcmp(backend, "wasm_simd128") != 0;
#endif
}

const char *Rbebelm_dispatch_mode(void) {
#ifdef __EMSCRIPTEN__
    return "static";
#else
    return "dynamic";
#endif
}

static void dylib_dir(char *out, size_t out_size) {
#if defined(_WIN32)
    HMODULE hm = NULL;
    if (!GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                            (LPCSTR)&dylib_dir, &hm)) {
        Rf_error("cannot locate Rbebelm shared library");
    }
    DWORD n = GetModuleFileNameA(hm, out, (DWORD)out_size);
    if (n == 0 || n >= out_size) Rf_error("Rbebelm shared library path is too long");
    for (char *p = out + strlen(out); p > out; --p) {
        if (p[-1] == '\\' || p[-1] == '/') { p[-1] = '\0'; return; }
    }
#else
    Dl_info info;
    if (dladdr((void *)&dylib_dir, &info) == 0 || info.dli_fname == NULL) {
        Rf_error("cannot locate Rbebelm shared library");
    }
    snprintf(out, out_size, "%s", info.dli_fname);
    char *slash = strrchr(out, '/');
    if (slash == NULL) Rf_error("cannot derive Rbebelm shared library directory");
    *slash = '\0';
#endif
}

static int path_exists_any(const char *path) {
#if defined(_WIN32)
    return GetFileAttributesA(path) != INVALID_FILE_ATTRIBUTES;
#else
    return access(path, F_OK) == 0;
#endif
}

static void backend_dir(char *out, size_t out_size) {
    char libdir[4096];
    dylib_dir(libdir, sizeof(libdir));

    char tmp[4096];
    const char *backend_leaf = "/rbebelm-backends";
    if (strlen(libdir) + strlen(backend_leaf) >= sizeof(tmp)) {
        Rf_error("Rbebelm backend path is too long");
    }
    strcpy(tmp, libdir);
    strcat(tmp, backend_leaf);
    if (path_exists_any(tmp)) { snprintf(out, out_size, "%s", tmp); return; }

    char *base = strrchr(libdir, '/');
#if defined(_WIN32)
    char *base2 = strrchr(libdir, '\\');
    if (base2 != NULL && (base == NULL || base2 > base)) base = base2;
#endif
    const char *leaf = base == NULL ? libdir : base + 1;
    if (strcmp(leaf, "libs") == 0) {
        size_t prefix_len = (size_t)(base - libdir + 1);
        snprintf(out, out_size, "%.*sbackends", (int)prefix_len, libdir);
        return;
    }
    if (base != NULL) {
        char parent[4096];
        snprintf(parent, sizeof(parent), "%s", libdir);
        parent[base - libdir] = '\0';
        char *pbase = strrchr(parent, '/');
#if defined(_WIN32)
        char *pbase2 = strrchr(parent, '\\');
        if (pbase2 != NULL && (pbase == NULL || pbase2 > pbase)) pbase = pbase2;
#endif
        const char *pleaf = pbase == NULL ? parent : pbase + 1;
        if (strcmp(pleaf, "libs") == 0) {
            size_t prefix_len = (size_t)(pbase - parent + 1);
            snprintf(out, out_size, "%.*sbackends/%s", (int)prefix_len, parent, leaf);
            return;
        }
    }
    if (strlen(libdir) + strlen(backend_leaf) >= out_size) {
        Rf_error("Rbebelm backend path is too long");
    }
    strcpy(out, libdir);
    strcat(out, backend_leaf);
}

static void backend_path(const char *backend, char *out, size_t out_size) {
    char dir[4096];
    backend_dir(dir, sizeof(dir));
    const char *prefix = "/rbebelm_backend_";
    size_t need = strlen(dir) + strlen(prefix) + strlen(backend) + strlen(RBEBELM_DYLIB_EXT) + 1;
    if (need > out_size) {
        Rf_error("Rbebelm backend library path is too long");
    }
    strcpy(out, dir);
    strcat(out, prefix);
    strcat(out, backend);
    strcat(out, RBEBELM_DYLIB_EXT);
}

static int file_exists(const char *path) {
#if defined(_WIN32)
    DWORD attr = GetFileAttributesA(path);
    return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
#else
    return access(path, R_OK) == 0;
#endif
}

static void refresh_backend_lists(void) {
    installed_backends[0] = '\0';
    supported_backends[0] = '\0';
#ifdef __EMSCRIPTEN__
    append_csv(installed_backends, sizeof(installed_backends), "wasm_simd128");
    append_csv(supported_backends, sizeof(supported_backends), "wasm_simd128");
    return;
#endif
    for (size_t i = 0; i < RBEBELM_ARRAY_LEN(RBEBELM_BACKENDS); i++) {
        const char *b = RBEBELM_BACKENDS[i];
        if (!backend_in_this_build(b)) continue;
        char path[4096];
        backend_path(b, path, sizeof(path));
        if (file_exists(path)) {
            append_csv(installed_backends, sizeof(installed_backends), b);
            if (backend_supported(b)) append_csv(supported_backends, sizeof(supported_backends), b);
        }
    }
}

static void set_err(char *err, size_t err_size, const char *prefix, const char *detail) {
    if (err_size == 0) return;
    err[0] = '\0';
    if (prefix == NULL) prefix = "";
    if (detail == NULL) detail = "";
    size_t need = strlen(prefix) + strlen(detail) + 1;
    if (need > err_size) {
        const char *fallback = "backend error message is too long";
        strncpy(err, fallback, err_size - 1);
        err[err_size - 1] = '\0';
        return;
    }
    strcpy(err, prefix);
    strcat(err, detail);
}

static void *load_symbol(void *handle, const char *name) {
#if defined(_WIN32)
    void *sym = (void *)GetProcAddress((HMODULE)handle, name);
#else
    void *sym = dlsym(handle, name);
#endif
    if (sym == NULL) Rf_error("failed to load Rbebelm backend symbol '%s'", name);
    return sym;
}

static int try_load_backend(const char *backend, char *err, size_t err_size) {
    char path[4096];
    backend_path(backend, path, sizeof(path));
    if (!file_exists(path)) {
        set_err(err, err_size, "backend library is not installed: ", path);
        return 0;
    }
#if defined(_WIN32)
    HMODULE handle = LoadLibraryA(path);
    if (handle == NULL) {
        set_err(err, err_size, "LoadLibrary failed for ", path);
        return 0;
    }
#else
    void *handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
    if (handle == NULL) {
        set_err(err, err_size, "", dlerror());
        return 0;
    }
#endif
    p_001 = (fn_001)load_symbol(handle, "savvy_bebel_event_types__ffi");
    p_002 = (fn_002)load_symbol(handle, "savvy_bebel_token_ids__ffi");
    p_003 = (fn_003)load_symbol(handle, "savvy_rbebelm_backend_features__ffi");
    p_004 = (fn_004)load_symbol(handle, "savvy_rbebelm_parse_tool_calls__ffi");
    p_005 = (fn_005)load_symbol(handle, "savvy_rbebelm_render_system_turn__ffi");
    p_006 = (fn_006)load_symbol(handle, "savvy_BebelAgent_append__ffi");
    p_007 = (fn_007)load_symbol(handle, "savvy_BebelAgent_append_system__ffi");
    p_008 = (fn_008)load_symbol(handle, "savvy_BebelAgent_append_system_with_tools__ffi");
    p_009 = (fn_009)load_symbol(handle, "savvy_BebelAgent_append_tokens__ffi");
    p_010 = (fn_010)load_symbol(handle, "savvy_BebelAgent_append_tool_result__ffi");
    p_011 = (fn_011)load_symbol(handle, "savvy_BebelAgent_append_user__ffi");
    p_012 = (fn_012)load_symbol(handle, "savvy_BebelAgent_assistant_turn__ffi");
    p_013 = (fn_013)load_symbol(handle, "savvy_BebelAgent_assistant_turn_async__ffi");
    p_014 = (fn_014)load_symbol(handle, "savvy_BebelAgent_assistant_turn_tool_stop__ffi");
    p_015 = (fn_015)load_symbol(handle, "savvy_BebelAgent_assistant_turn_tool_stop_async__ffi");
    p_016 = (fn_016)load_symbol(handle, "savvy_BebelAgent_clear__ffi");
    p_017 = (fn_017)load_symbol(handle, "savvy_BebelAgent_clone__ffi");
    p_018 = (fn_018)load_symbol(handle, "savvy_BebelAgent_configure__ffi");
    p_019 = (fn_019)load_symbol(handle, "savvy_BebelAgent_generate__ffi");
    p_020 = (fn_020)load_symbol(handle, "savvy_BebelAgent_generate_async__ffi");
    p_021 = (fn_021)load_symbol(handle, "savvy_BebelAgent_history__ffi");
    p_022 = (fn_022)load_symbol(handle, "savvy_BebelAgent_info__ffi");
    p_023 = (fn_023)load_symbol(handle, "savvy_BebelAgent_new__ffi");
    p_024 = (fn_024)load_symbol(handle, "savvy_BebelAgent_prefill__ffi");
    p_025 = (fn_025)load_symbol(handle, "savvy_BebelAgent_transcript__ffi");
    p_026 = (fn_026)load_symbol(handle, "savvy_BebelAsyncJob_cancel__ffi");
    p_027 = (fn_027)load_symbol(handle, "savvy_BebelAsyncJob_events__ffi");
    p_028 = (fn_028)load_symbol(handle, "savvy_BebelAsyncJob_ready__ffi");
    p_029 = (fn_029)load_symbol(handle, "savvy_BebelAsyncJob_result__ffi");
    p_030 = (fn_030)load_symbol(handle, "savvy_BebelModel_chat__ffi");
    p_031 = (fn_031)load_symbol(handle, "savvy_BebelModel_chat_async__ffi");
    p_032 = (fn_032)load_symbol(handle, "savvy_BebelModel_decode__ffi");
    p_033 = (fn_033)load_symbol(handle, "savvy_BebelModel_encode__ffi");
    p_034 = (fn_034)load_symbol(handle, "savvy_BebelModel_generate__ffi");
    p_035 = (fn_035)load_symbol(handle, "savvy_BebelModel_generate_async__ffi");
    p_036 = (fn_036)load_symbol(handle, "savvy_BebelModel_info__ffi");
    p_037 = (fn_037)load_symbol(handle, "savvy_BebelModel_load__ffi");
    p_038 = (fn_038)load_symbol(handle, "savvy_BebelModel_pooled_states__ffi");
    p_039 = (fn_039)load_symbol(handle, "savvy_BebelModel_pooled_states_batch__ffi");
    p_040 = (fn_040)load_symbol(handle, "savvy_BebelModel_token_states__ffi");
    p_041 = (fn_041)load_symbol(handle, "savvy_EmbeddingGemmaModel_embed_batch__ffi");
    p_042 = (fn_042)load_symbol(handle, "savvy_EmbeddingGemmaModel_info__ffi");
    p_043 = (fn_043)load_symbol(handle, "savvy_EmbeddingGemmaModel_load__ffi");
    p_044 = (fn_044)load_symbol(handle, "savvy_EmbeddingGemmaModel_tokenize__ffi");
    snprintf(selected_backend, sizeof(selected_backend), "%s", backend);
    backend_loaded = 1;
    return 1;
}

static const char *select_backend(void) {
    for (size_t i = 0; i < RBEBELM_ARRAY_LEN(RBEBELM_PRIORITY); i++) {
        const char *b = RBEBELM_PRIORITY[i];
        if (csv_has(installed_backends, b) && backend_supported(b)) return b;
    }
    return "";
}

void Rbebelm_request_backend(const char *backend) {
    if (backend_loaded) Rf_error("Rbebelm backend is already initialized; call rbebelm_set_backend() before loading a model or querying backend features");
    if (backend == NULL || strcmp(backend, "auto") == 0) {
        requested_backend[0] = '\0';
        return;
    }
    if (!known_backend(backend)) Rf_error("unknown Rbebelm backend '%s'", backend);
    if (!backend_in_this_build(backend)) Rf_error("requested Rbebelm backend '%s' is not installed in this build", backend);
    if (!backend_supported(backend)) Rf_error("requested Rbebelm backend '%s' is not supported on this CPU/runtime", backend);
    snprintf(requested_backend, sizeof(requested_backend), "%s", backend);
}

void Rbebelm_init_backend(void) {
    if (backend_loaded) return;
#ifdef __EMSCRIPTEN__
    refresh_backend_lists();
    if (requested_backend[0] != '\0' && strcmp(requested_backend, "wasm_simd128") != 0) {
        Rf_error("only the wasm_simd128 backend is available in webR/Emscripten builds");
    }
    bind_static_backend_symbols();
    snprintf(selected_backend, sizeof(selected_backend), "%s", "wasm_simd128");
    backend_loaded = 1;
    return;
#endif
    const char *env_backend = getenv("RBEBELM_BACKEND");
    if (requested_backend[0] == '\0' && env_backend != NULL && env_backend[0] != '\0') {
        Rbebelm_request_backend(env_backend);
    }
    refresh_backend_lists();
    const char *selected = requested_backend[0] == '\0' ? select_backend() : requested_backend;
    if (selected == NULL || selected[0] == '\0') {
        Rf_error("failed to select an Rbebelm backend; installed_backends='%s', supported_backends='%s'", installed_backends, supported_backends);
    }
    char err[4096] = "";
    if (!try_load_backend(selected, err, sizeof(err))) {
        Rf_error("failed to load selected Rbebelm backend '%s': %s", selected, err);
    }
}

int Rbebelm_backend_is_loaded(void) { return backend_loaded; }
const char *Rbebelm_requested_backend_name(void) { return requested_backend[0] == '\0' ? "auto" : requested_backend; }
const char *Rbebelm_selected_backend_name(void) { return selected_backend[0] == '\0' ? "unknown" : selected_backend; }
const char *Rbebelm_installed_backend_names(void) { refresh_backend_lists(); return installed_backends[0] == '\0' ? "none" : installed_backends; }
const char *Rbebelm_supported_backend_names(void) { refresh_backend_lists(); return supported_backends[0] == '\0' ? "none" : supported_backends; }

SEXP Rbebelm_bebel_event_types_ffi(void) { Rbebelm_init_backend(); return p_001(); }
SEXP Rbebelm_bebel_token_ids_ffi(void) { Rbebelm_init_backend(); return p_002(); }
SEXP Rbebelm_backend_features_ffi(void) { Rbebelm_init_backend(); return p_003(); }
SEXP Rbebelm_parse_tool_calls_ffi(SEXP c_arg__text) { Rbebelm_init_backend(); return p_004(c_arg__text); }
SEXP Rbebelm_render_system_turn_ffi(SEXP c_arg__message, SEXP c_arg__tool_names, SEXP c_arg__tool_schemas) { Rbebelm_init_backend(); return p_005(c_arg__message, c_arg__tool_names, c_arg__tool_schemas); }
SEXP Rbebelm_BebelAgent_append_ffi(SEXP self__, SEXP c_arg__text) { Rbebelm_init_backend(); return p_006(self__, c_arg__text); }
SEXP Rbebelm_BebelAgent_append_system_ffi(SEXP self__, SEXP c_arg__message) { Rbebelm_init_backend(); return p_007(self__, c_arg__message); }
SEXP Rbebelm_BebelAgent_append_system_with_tools_ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__tool_names, SEXP c_arg__tool_schemas) { Rbebelm_init_backend(); return p_008(self__, c_arg__message, c_arg__tool_names, c_arg__tool_schemas); }
SEXP Rbebelm_BebelAgent_append_tokens_ffi(SEXP self__, SEXP c_arg__ids) { Rbebelm_init_backend(); return p_009(self__, c_arg__ids); }
SEXP Rbebelm_BebelAgent_append_tool_result_ffi(SEXP self__, SEXP c_arg__content) { Rbebelm_init_backend(); return p_010(self__, c_arg__content); }
SEXP Rbebelm_BebelAgent_append_user_ffi(SEXP self__, SEXP c_arg__message) { Rbebelm_init_backend(); return p_011(self__, c_arg__message); }
SEXP Rbebelm_BebelAgent_assistant_turn_ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event) { Rbebelm_init_backend(); return p_012(self__, c_arg__check_interrupt, c_arg__on_event); }
SEXP Rbebelm_BebelAgent_assistant_turn_async_ffi(SEXP self__) { Rbebelm_init_backend(); return p_013(self__); }
SEXP Rbebelm_BebelAgent_assistant_turn_tool_stop_ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event) { Rbebelm_init_backend(); return p_014(self__, c_arg__check_interrupt, c_arg__on_event); }
SEXP Rbebelm_BebelAgent_assistant_turn_tool_stop_async_ffi(SEXP self__) { Rbebelm_init_backend(); return p_015(self__); }
SEXP Rbebelm_BebelAgent_clear_ffi(SEXP self__) { Rbebelm_init_backend(); return p_016(self__); }
SEXP Rbebelm_BebelAgent_clone_ffi(SEXP self__) { Rbebelm_init_backend(); return p_017(self__); }
SEXP Rbebelm_BebelAgent_configure_ffi(SEXP self__, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) { Rbebelm_init_backend(); return p_018(self__, c_arg__greedy, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty); }
SEXP Rbebelm_BebelAgent_generate_ffi(SEXP self__, SEXP c_arg__check_interrupt, SEXP c_arg__on_event) { Rbebelm_init_backend(); return p_019(self__, c_arg__check_interrupt, c_arg__on_event); }
SEXP Rbebelm_BebelAgent_generate_async_ffi(SEXP self__) { Rbebelm_init_backend(); return p_020(self__); }
SEXP Rbebelm_BebelAgent_history_ffi(SEXP self__) { Rbebelm_init_backend(); return p_021(self__); }
SEXP Rbebelm_BebelAgent_info_ffi(SEXP self__) { Rbebelm_init_backend(); return p_022(self__); }
SEXP Rbebelm_BebelAgent_new_ffi(SEXP c_arg__model, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) { Rbebelm_init_backend(); return p_023(c_arg__model, c_arg__greedy, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty); }
SEXP Rbebelm_BebelAgent_prefill_ffi(SEXP self__, SEXP c_arg__check_interrupt) { Rbebelm_init_backend(); return p_024(self__, c_arg__check_interrupt); }
SEXP Rbebelm_BebelAgent_transcript_ffi(SEXP self__) { Rbebelm_init_backend(); return p_025(self__); }
SEXP Rbebelm_BebelAsyncJob_cancel_ffi(SEXP self__) { Rbebelm_init_backend(); return p_026(self__); }
SEXP Rbebelm_BebelAsyncJob_events_ffi(SEXP self__, SEXP c_arg__max) { Rbebelm_init_backend(); return p_027(self__, c_arg__max); }
SEXP Rbebelm_BebelAsyncJob_ready_ffi(SEXP self__) { Rbebelm_init_backend(); return p_028(self__); }
SEXP Rbebelm_BebelAsyncJob_result_ffi(SEXP self__, SEXP c_arg__wait) { Rbebelm_init_backend(); return p_029(self__, c_arg__wait); }
SEXP Rbebelm_BebelModel_chat_ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) { Rbebelm_init_backend(); return p_030(self__, c_arg__message, c_arg__greedy, c_arg__check_interrupt, c_arg__on_event, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty); }
SEXP Rbebelm_BebelModel_chat_async_ffi(SEXP self__, SEXP c_arg__message, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) { Rbebelm_init_backend(); return p_031(self__, c_arg__message, c_arg__greedy, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty); }
SEXP Rbebelm_BebelModel_decode_ffi(SEXP self__, SEXP c_arg__ids) { Rbebelm_init_backend(); return p_032(self__, c_arg__ids); }
SEXP Rbebelm_BebelModel_encode_ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos) { Rbebelm_init_backend(); return p_033(self__, c_arg__text, c_arg__add_bos); }
SEXP Rbebelm_BebelModel_generate_ffi(SEXP self__, SEXP c_arg__prompt, SEXP c_arg__greedy, SEXP c_arg__check_interrupt, SEXP c_arg__on_event, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) { Rbebelm_init_backend(); return p_034(self__, c_arg__prompt, c_arg__greedy, c_arg__check_interrupt, c_arg__on_event, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty); }
SEXP Rbebelm_BebelModel_generate_async_ffi(SEXP self__, SEXP c_arg__prompt, SEXP c_arg__greedy, SEXP c_arg__max_gen, SEXP c_arg__max_context, SEXP c_arg__max_think, SEXP c_arg__temperature, SEXP c_arg__top_k, SEXP c_arg__repeat_penalty) { Rbebelm_init_backend(); return p_035(self__, c_arg__prompt, c_arg__greedy, c_arg__max_gen, c_arg__max_context, c_arg__max_think, c_arg__temperature, c_arg__top_k, c_arg__repeat_penalty); }
SEXP Rbebelm_BebelModel_info_ffi(SEXP self__) { Rbebelm_init_backend(); return p_036(self__); }
SEXP Rbebelm_BebelModel_load_ffi(SEXP c_arg__path, SEXP c_arg__num_threads) { Rbebelm_init_backend(); return p_037(c_arg__path, c_arg__num_threads); }
SEXP Rbebelm_BebelModel_pooled_states_ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos, SEXP c_arg__normalize, SEXP c_arg__pooling) { Rbebelm_init_backend(); return p_038(self__, c_arg__text, c_arg__add_bos, c_arg__normalize, c_arg__pooling); }
SEXP Rbebelm_BebelModel_pooled_states_batch_ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos, SEXP c_arg__normalize, SEXP c_arg__pooling, SEXP c_arg__check_interrupt, SEXP c_arg__token_batch_size, SEXP c_arg__sequence_batch_size) { Rbebelm_init_backend(); return p_039(self__, c_arg__text, c_arg__add_bos, c_arg__normalize, c_arg__pooling, c_arg__check_interrupt, c_arg__token_batch_size, c_arg__sequence_batch_size); }
SEXP Rbebelm_BebelModel_token_states_ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__add_bos, SEXP c_arg__normalize, SEXP c_arg__check_interrupt, SEXP c_arg__token_batch_size) { Rbebelm_init_backend(); return p_040(self__, c_arg__text, c_arg__add_bos, c_arg__normalize, c_arg__check_interrupt, c_arg__token_batch_size); }
SEXP Rbebelm_EmbeddingGemmaModel_embed_batch_ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__dimensions, SEXP c_arg__normalize, SEXP c_arg__truncate, SEXP c_arg__check_interrupt) { Rbebelm_init_backend(); return p_041(self__, c_arg__text, c_arg__dimensions, c_arg__normalize, c_arg__truncate, c_arg__check_interrupt); }
SEXP Rbebelm_EmbeddingGemmaModel_info_ffi(SEXP self__) { Rbebelm_init_backend(); return p_042(self__); }
SEXP Rbebelm_EmbeddingGemmaModel_load_ffi(SEXP c_arg__path, SEXP c_arg__num_threads) { Rbebelm_init_backend(); return p_043(c_arg__path, c_arg__num_threads); }
SEXP Rbebelm_EmbeddingGemmaModel_tokenize_ffi(SEXP self__, SEXP c_arg__text, SEXP c_arg__truncate) { Rbebelm_init_backend(); return p_044(self__, c_arg__text, c_arg__truncate); }

SEXP Rbebelm_set_backend_impl(SEXP backend_s) {
    if (TYPEOF(backend_s) != STRSXP || XLENGTH(backend_s) != 1 || STRING_ELT(backend_s, 0) == NA_STRING) {
        Rf_error("backend must be a single non-NA string");
    }
    Rbebelm_request_backend(CHAR(STRING_ELT(backend_s, 0)));
    return Rf_mkString(Rbebelm_requested_backend_name());
}

static SEXP scalar_string(const char *x) { return Rf_ScalarString(Rf_mkChar(x)); }
static SEXP scalar_logical(int x) { return Rf_ScalarLogical(x ? 1 : 0); }

SEXP Rbebelm_backend_info_impl(void) {
    refresh_backend_lists();
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 6));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 6));
    SET_STRING_ELT(names, 0, Rf_mkChar("dispatch_mode"));
    SET_STRING_ELT(names, 1, Rf_mkChar("requested_backend"));
    SET_STRING_ELT(names, 2, Rf_mkChar("selected_backend"));
    SET_STRING_ELT(names, 3, Rf_mkChar("installed_backends"));
    SET_STRING_ELT(names, 4, Rf_mkChar("supported_backends"));
    SET_STRING_ELT(names, 5, Rf_mkChar("backend_loaded"));
    SET_VECTOR_ELT(out, 0, scalar_string(Rbebelm_dispatch_mode()));
    SET_VECTOR_ELT(out, 1, scalar_string(Rbebelm_requested_backend_name()));
    SET_VECTOR_ELT(out, 2, scalar_string(Rbebelm_selected_backend_name()));
    SET_VECTOR_ELT(out, 3, scalar_string(Rbebelm_installed_backend_names()));
    SET_VECTOR_ELT(out, 4, scalar_string(Rbebelm_supported_backend_names()));
    SET_VECTOR_ELT(out, 5, scalar_logical(backend_loaded));
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}

SEXP Rbebelm_cpuid_info_impl(void) {
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 5));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 5));
    SET_STRING_ELT(names, 0, Rf_mkChar("cpu_x86_64_v3"));
    SET_STRING_ELT(names, 1, Rf_mkChar("cpu_x86_64_v4"));
    SET_STRING_ELT(names, 2, Rf_mkChar("cpu_neon"));
    SET_STRING_ELT(names, 3, Rf_mkChar("cpu_dotprod"));
    SET_STRING_ELT(names, 4, Rf_mkChar("cpu_wasm_simd128"));
    SET_VECTOR_ELT(out, 0, scalar_logical(cpu_x86_64_v3()));
    SET_VECTOR_ELT(out, 1, scalar_logical(cpu_x86_64_v4()));
    SET_VECTOR_ELT(out, 2, scalar_logical(cpu_neon()));
    SET_VECTOR_ELT(out, 3, scalar_logical(cpu_dotprod()));
    SET_VECTOR_ELT(out, 4, scalar_logical(cpu_wasm_simd128()));
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}
