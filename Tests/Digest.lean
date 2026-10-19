import Fvtrace.Digest
import Tests.Harness

namespace Tests.Digest
open Tests Fvtrace

/-- FIPS 180-4 / NIST CSRC SHA-256 example vectors. -/
def vectors : List (String × String) :=
  [("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
   ("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
   ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
   ("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn" ++
      "hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
    "cf5b16a778af8380036ce59e7b0492370b249b11e8f07a51afac45037afee9d1")]

def tests : TestM Unit := do
  for (msg, want) in vectors do
    checkEq s!"digest: NIST vector of length {msg.length}" (← Digest.ofString msg) want
  let million := ByteArray.mk (Array.replicate 1000000 97)
  checkEq "digest: one million a" (← Digest.ofBytes million)
    "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"
  let s ← Digest.Sha256.new
  for piece in ["ab", "", "c"] do s.update piece.toUTF8
  checkEq "digest: streaming equals one shot" (Digest.hex (← s.finish))
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  IO.FS.withTempDir fun dir => do
    let sample := ByteArray.mk ((Array.range 300000).map fun i => (i % 251).toUInt8)
    IO.FS.writeBinFile (dir / "sample.bin") sample
    checkEq "digest: file equals bytes" (← Digest.ofFile (dir / "sample.bin"))
      (← Digest.ofBytes sample)
    IO.FS.writeBinFile (dir / "empty.bin") ByteArray.empty
    checkEq "digest: empty file" (← Digest.ofFile (dir / "empty.bin"))
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

end Tests.Digest
