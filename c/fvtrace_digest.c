// Lean FFI shim over HACL*'s verified SHA-256 (c/hacl). The shim only moves bytes between Lean
// objects and HACL*; file I/O stays in Lean, so paths follow Lean's portable file API.
#include <lean/lean.h>
#include <string.h>

#include "Hacl_Hash_SHA2.h"

static lean_external_class *sha256_class = NULL;

static void sha256_finalize(void *state) {
  Hacl_Hash_SHA2_free_256((Hacl_Hash_SHA2_state_t_256 *)state);
}

static void sha256_foreach(void *state, b_lean_obj_arg f) {
  (void)state;
  (void)f;
}

static lean_external_class *sha256_get_class(void) {
  if (sha256_class == NULL) {
    sha256_class = lean_register_external_class(sha256_finalize, sha256_foreach);
  }
  return sha256_class;
}

// Fvtrace.Digest.Sha256.new : IO Sha256
LEAN_EXPORT lean_obj_res fvtrace_sha256_new(lean_obj_arg world) {
  (void)world;
  Hacl_Hash_SHA2_state_t_256 *state = Hacl_Hash_SHA2_malloc_256();
  if (state == NULL) {
    return lean_io_result_mk_error(lean_mk_io_user_error(lean_mk_string("sha256: out of memory")));
  }
  return lean_io_result_mk_ok(lean_alloc_external(sha256_get_class(), state));
}

// Fvtrace.Digest.Sha256.update : @& Sha256 → @& ByteArray → IO Unit
LEAN_EXPORT lean_obj_res fvtrace_sha256_update(b_lean_obj_arg st, b_lean_obj_arg bytes,
                                               lean_obj_arg world) {
  (void)world;
  Hacl_Hash_SHA2_state_t_256 *state = (Hacl_Hash_SHA2_state_t_256 *)lean_get_external_data(st);
  size_t size = lean_sarray_size(bytes);
  uint8_t *data = lean_sarray_cptr(bytes);
  // HACL*'s update takes a 32-bit length; feed larger arrays in slices.
  while (size > 0) {
    uint32_t chunk = size > 0x40000000u ? 0x40000000u : (uint32_t)size;
    if (Hacl_Hash_SHA2_update_256(state, data, chunk) != Hacl_Streaming_Types_Success) {
      return lean_io_result_mk_error(
          lean_mk_io_user_error(lean_mk_string("sha256: input exceeds the SHA-256 length limit")));
    }
    data += chunk;
    size -= chunk;
  }
  return lean_io_result_mk_ok(lean_box(0));
}

// Fvtrace.Digest.Sha256.finish : @& Sha256 → IO ByteArray
LEAN_EXPORT lean_obj_res fvtrace_sha256_finish(b_lean_obj_arg st, lean_obj_arg world) {
  (void)world;
  Hacl_Hash_SHA2_state_t_256 *state = (Hacl_Hash_SHA2_state_t_256 *)lean_get_external_data(st);
  lean_object *out = lean_alloc_sarray(1, 32, 32);
  Hacl_Hash_SHA2_digest_256(state, lean_sarray_cptr(out));
  return lean_io_result_mk_ok(out);
}
