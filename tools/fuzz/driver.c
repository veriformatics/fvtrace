/* libFuzzer entry for one fuzz target (tools/fuzz.sh builds one binary per target, sanitized).
   -DFVTRACE_FUZZ_TARGET=<name> calls FvtraceFuzz's export fvtrace_fuzz_<name> (FvtraceFuzz.lean):
   0 = the input met its contract, any other code = a broken property ⇒ abort. -DFVTRACE_FUZZ_PAGE
   drives c/page_engine.c's own entries instead (the exported page's bridge), split as the replay
   splits: the bytes before the first NUL = a snapshot, the rest = one request. */
#include <lean/lean.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void lean_initialize_runtime_module(void);
void lean_io_mark_end_initialization(void);

#define CAT2(a, b) a##b
#define CAT(a, b) CAT2(a, b)
#define STR2(a) #a
#define STR(a) STR2(a)

#ifdef FVTRACE_FUZZ_PAGE
int fvtrace_init(void);
char *fvtrace_load(const char *snapshot, size_t snapshot_len, size_t *len);
char *fvtrace_answer(const char *request, size_t request_len, size_t *len);
#else
lean_object *initialize_fvtrace_FvtraceFuzz(uint8_t builtin);
#define TARGET CAT(fvtrace_fuzz_, FVTRACE_FUZZ_TARGET)
lean_object *TARGET(lean_object *input);
#endif

int LLVMFuzzerInitialize(int *argc, char ***argv) {
  (void)argc;
  (void)argv;
  /* Lean's panic prints + returns a default unless this is set; a campaign must stop on it. */
  setenv("LEAN_ABORT_ON_PANIC", "1", 1);
#ifdef FVTRACE_FUZZ_PAGE
  if (fvtrace_init() != 0) abort();
#else
  lean_initialize_runtime_module();
  lean_object *r = initialize_fvtrace_FvtraceFuzz(1);
  if (lean_io_result_is_error(r)) {
    lean_io_result_show_error(r);
    abort();
  }
  lean_dec_ref(r);
  lean_io_mark_end_initialization();
#endif
  return 0;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
#ifdef FVTRACE_FUZZ_PAGE
  const uint8_t *nul = size ? memchr(data, 0, size) : NULL;
  size_t snapshot_len = nul ? (size_t)(nul - data) : size;
  size_t len = 0;
  char *problem = fvtrace_load((const char *)data, snapshot_len, &len);
  if (problem == NULL) abort();
  int loaded = len == 0;
  free(problem);
  if (loaded) {
    const char *request = nul ? (const char *)nul + 1 : "";
    size_t request_len = nul ? size - snapshot_len - 1 : 0;
    char *answer = fvtrace_answer(request, request_len, &len);
    if (answer == NULL || len == 0) {
      fputs("fvtrace-fuzz page: no answer\n", stderr);
      abort();
    }
    free(answer);
  }
#else
  lean_object *input = lean_alloc_sarray(1, size, size);
  if (size) memcpy(lean_sarray_cptr(input), data, size);
  lean_object *r = TARGET(input);
  if (lean_io_result_is_error(r)) {
    lean_io_result_show_error(r);
    abort();
  }
  unsigned code = (unsigned)lean_unbox(lean_io_result_get_value(r));
  lean_dec_ref(r);
  if (code != 0) {
    fprintf(stderr, "fvtrace-fuzz %s: property %u\n", STR(FVTRACE_FUZZ_TARGET), code);
    abort();
  }
#endif
  return 0;
}
