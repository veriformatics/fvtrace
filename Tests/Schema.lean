import Fvtrace.Decode
import Tests.Harness

namespace Tests.Schema
open Tests Fvtrace

/-- The decoder's verdict on the shared corpus `tests/schema/cases/` (the Node test holds the JSON
Schema to the same verdicts): `valid-*` decode; `invalid-*` + `decoder-only-*` fail. -/
def tests : TestM Unit := do
  let dir : System.FilePath := "tests/schema/cases"
  let entries ← dir.readDir
  let files := (entries.map (·.fileName)).qsort (· < ·)
  check "schema corpus: non-empty" (files.size ≥ 30) s!"{files.size} files"
  for name in files do
    let bytes ← IO.FS.readBinFile (dir / name)
    let accepted := (decodeTrace bytes).toOption.isSome
    let want := name.startsWith "valid-"
    let verb := if want then "accepts" else "rejects"
    check s!"schema corpus: decoder {verb} {name}" (accepted == want)

end Tests.Schema
