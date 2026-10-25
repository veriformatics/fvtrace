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
lean_object *fvtrace_snapshot_load(lean_object *snapshot);
lean_object *fvtrace_snapshot_answer(lean_object *engine, lean_object *request);

/* The loaded engine (kernel.md E-state), replaced by each answer's next state. */
static lean_object *engine = NULL;

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

/* A fresh copy of a Lean string's bytes + its length at *len; NULL when out of memory. */
static char *copy_out(lean_object *text, size_t *len) {
  size_t n = lean_string_size(text) - 1;
  char *buf = malloc(n + 1);
  if (buf != NULL) {
    memcpy(buf, lean_string_cstr(text), n);
    *len = n;
  }
  return buf;
}

/* "" (length 0) when the snapshot loaded, else the problem's text; NULL when out of memory. */
char *fvtrace_load(const char *snapshot, size_t snapshot_len, size_t *len) {
  lean_object *r = fvtrace_snapshot_load(lean_mk_string_from_bytes(snapshot, snapshot_len));
  char *buf;
  if (lean_obj_tag(r) == 1) { /* Except.ok */
    lean_object *e = lean_ctor_get(r, 0);
    lean_inc(e);
    if (engine != NULL) lean_dec(engine);
    engine = e;
    buf = malloc(1);
    if (buf != NULL) {
      buf[0] = 0;
      *len = 0;
    }
  } else {
    buf = copy_out(lean_ctor_get(r, 0), len);
  }
  lean_dec(r);
  return buf;
}

/* One request's answer; NULL when out of memory or before a successful load. */
char *fvtrace_answer(const char *request, size_t request_len, size_t *len) {
  if (engine == NULL) return NULL;
  lean_inc(engine);
  lean_object *r =
      fvtrace_snapshot_answer(engine, lean_mk_string_from_bytes(request, request_len));
  lean_object *next = lean_ctor_get(r, 0);
  lean_inc(next);
  lean_dec(engine);
  engine = next;
  char *buf = copy_out(lean_ctor_get(r, 1), len);
  lean_dec(r);
  return buf;
}

/* The runtime's io.cpp words operating-system errors through libuv; the page performs no I/O. */
const char *uv_strerror(int err) {
  (void)err;
  return "operating-system error";
}
