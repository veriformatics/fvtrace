/* The exported page's engine entry, compiled to WebAssembly alone (fvtrace-wasm, kernel.md
   E-build) with the Lean C of Fvtrace.Snapshot's import closure. Strings cross as (pointer, byte
   length): a NUL inside a what-if must reach Lean as it does from the command line. */
#include <lean/lean.h>
#include <stdlib.h>
#include <string.h>

void lean_initialize_runtime_module(void);
void lean_io_mark_end_initialization(void);
lean_object *initialize_fvtrace_Fvtrace_Snapshot(uint8_t builtin);
lean_object *fvtrace_snapshot_evaluate(lean_object *snapshot, lean_object *spec);

/* 0 = ready; otherwise the initializer's error went to standard error. */
int fvtrace_init(void) {
  lean_initialize_runtime_module();
  lean_object *r = initialize_fvtrace_Fvtrace_Snapshot(1);
  int failed = lean_io_result_is_error(r);
  if (failed) lean_io_result_show_error(r);
  lean_dec_ref(r);
  lean_io_mark_end_initialization();
  return failed;
}

void *fvtrace_alloc(size_t n) { return malloc(n); }

void fvtrace_free(void *p) { free(p); }

/* The result's bytes (the caller frees them) and its length at *len; NULL when out of memory. */
char *fvtrace_evaluate(const char *snapshot, size_t snapshot_len, const char *spec,
                       size_t spec_len, size_t *len) {
  lean_object *out = fvtrace_snapshot_evaluate(lean_mk_string_from_bytes(snapshot, snapshot_len),
                                               lean_mk_string_from_bytes(spec, spec_len));
  size_t n = lean_string_size(out) - 1;
  char *buf = malloc(n + 1);
  if (buf != NULL) {
    memcpy(buf, lean_string_cstr(out), n);
    *len = n;
  }
  lean_dec_ref(out);
  return buf;
}

/* The runtime's io.cpp words operating-system errors through libuv; the page performs no I/O. */
const char *uv_strerror(int err) {
  (void)err;
  return "operating-system error";
}
