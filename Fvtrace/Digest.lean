/-!
# SHA-256 digests

HACL*'s formally verified SHA-256 (F* → C, vendored in `c/hacl` by `tools/vendor-hacl.sh`) behind
a three-call FFI (`c/fvtrace_digest.c`). Digests feed receipts + review records as opaque values:
no proof in `Fvtrace.Proofs` depends on how they are computed.
-/

namespace Fvtrace.Digest

private opaque Sha256Pointed : NonemptyType

/-- A streaming SHA-256 state (a HACL* object, freed by Lean's reference counting). -/
def Sha256 : Type := Sha256Pointed.type

instance : Nonempty Sha256 := Sha256Pointed.property

@[extern "fvtrace_sha256_new"]
opaque Sha256.new : IO Sha256

@[extern "fvtrace_sha256_update"]
opaque Sha256.update (s : @& Sha256) (bytes : @& ByteArray) : IO Unit

/-- The digest so far; the state stays usable. -/
@[extern "fvtrace_sha256_finish"]
opaque Sha256.finish (s : @& Sha256) : IO ByteArray

def hexDigit (n : Nat) : Char := "0123456789abcdef".toList[n % 16]!

/-- Lowercase hex, two characters per byte. -/
def hex (bytes : ByteArray) : String :=
  bytes.foldl (init := "") fun acc b => (acc.push (hexDigit (b.toNat / 16))).push (hexDigit b.toNat)

def ofBytes (bytes : ByteArray) : IO String := do
  let s ← Sha256.new
  s.update bytes
  return hex (← s.finish)

def ofString (s : String) : IO String := ofBytes s.toUTF8

/-- A file's digest, read in 1 MiB chunks (constant memory for any file size). -/
def ofFile (path : System.FilePath) : IO String := do
  let s ← Sha256.new
  let h ← IO.FS.Handle.mk path .read
  repeat
    let chunk ← h.read 1048576
    if chunk.isEmpty then break
    s.update chunk
  return hex (← s.finish)

end Fvtrace.Digest
