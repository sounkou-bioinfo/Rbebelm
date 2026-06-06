#ifdef __EMSCRIPTEN__
/*
 * webR's side-module loader used here does not provide legacy Emscripten
 * invoke_* helper imports that Rust/Emscripten may emit around setjmp/cleanup
 * paths. These trampolines call the wasm function-table entry directly. They
 * are runtime glue, not replacements for Rbebelm or BebeLM functionality.
 */
int invoke_i(int fp) {
    int (*f)(void) = (int (*)(void))fp;
    return f();
}

int invoke_ii(int fp, int a) {
    int (*f)(int) = (int (*)(int))fp;
    return f(a);
}

int invoke_iiiiii(int fp, int a, int b, int c, int d, int e) {
    int (*f)(int, int, int, int, int) = (int (*)(int, int, int, int, int))fp;
    return f(a, b, c, d, e);
}

void invoke_vi(int fp, int a) {
    void (*f)(int) = (void (*)(int))fp;
    f(a);
}
#endif
