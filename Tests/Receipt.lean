import Fvtrace
import Tests.Harness

namespace Tests.Receipt
open Tests Fvtrace

def fixture : IO Trace := do
  match decodeTrace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json") with
  | .ok t => pure t
  | .error ds => throw (IO.userError s!"fixture does not decode: {repr ds}")

def mapFact (t : Trace) (id : String) (f : Fact → Fact) : Trace :=
  { t with facts := t.facts.map fun x => if x.id == id then f x else x }

def bindingOf (t : Trace) (root : System.FilePath) (id : String) : IO (Option Receipt.Binding) := do
  let cache ← IO.mkRef ({} : Receipt.Cache)
  return (← Receipt.bindings t root cache (rehash := true)).find? (·.id == id)

def reasonsOf (t : Trace) (root : System.FilePath) (id : String) : IO (List String) := do
  return ((← bindingOf t root id).map (·.reasons)).getD ["absent"]

def evidenceFor (path : String) : Evidence :=
  { summary := "Receipt.", artifacts := [{ path }], verifier := some "Lean 4.35.0",
    statement := some "theorem" }

def tests : TestM Unit := do
  let base ← fixture
  IO.FS.withTempDir fun root => do
    IO.FS.createDirAll (root / "proofs")
    IO.FS.writeFile (root / "proofs" / "Contrast.lean")
      "theorem contrast_correct : True := trivial\n"
    IO.FS.writeFile (root / "proofs" / "Entail.lean") "theorem entails : True := trivial\n"
    IO.FS.writeFile (root / "proofs" / "Exclude.lean") "theorem excludes : True := trivial\n"
    -- EN1 (entailment of C1) + X1 (exclusion O4/O5) become verified, with receipts to pin.
    let t := mapFact base "EN1" fun f =>
      { f with status := .proved, route := .lean,
               evidence := some (evidenceFor "proofs/Entail.lean") }
    let t := { t with exclusions := t.exclusions.map fun x =>
      { x with status := .proved, route := .lean,
               evidence := some (evidenceFor "proofs/Exclude.lean") } }
    let cache ← IO.mkRef ({} : Receipt.Cache)
    let (pinned, problems) ← Receipt.pin t root cache
    checkEq "receipt: pin reports no problem" problems []
    let contrastSha ← Digest.ofFile (root / "proofs" / "Contrast.lean")
    checkEq "receipt: pin records the artifact digest"
      (((pinned.fact? "O1").bind (·.evidence)).map (·.artifacts.map (·.sha256)))
      (some [some contrastSha])
    checkEq "receipt: a pinned trace is well-formed"
      ((Check.violations pinned).map (·.rule.code)) []
    for id in ["O1", "EN1", "X1"] do
      checkEq s!"receipt: {id} current after pin" (← reasonsOf pinned root id) []
    IO.FS.writeFile (root / "proofs" / "Contrast.lean")
      "theorem contrast_correct : False := sorry\n"
    checkEq "receipt: an edited artifact is changed" (← reasonsOf pinned root "O1")
      ["changed proofs/Contrast.lean"]
    IO.FS.removeFile (root / "proofs" / "Contrast.lean")
    checkEq "receipt: a deleted artifact is missing" (← reasonsOf pinned root "O1")
      ["missing proofs/Contrast.lean"]
    IO.FS.withTempDir fun outside => do
      IO.FS.writeFile (outside / "secret.txt") "not part of the project\n"
      let _ ← IO.Process.output { cmd := "ln", args := #["-s", (outside / "secret.txt").toString,
        (root / "proofs" / "Contrast.lean").toString] }
      checkEq "receipt: a symlink out of the project is refused" (← reasonsOf pinned root "O1")
        ["outside proofs/Contrast.lean"]
    let reworded := mapFact pinned "O1" fun f => { f with text := f.text ++ " Revised." }
    checkEq "receipt: rewording a fact stales its receipt"
      ((← reasonsOf reworded root "O1").filter (· == "statement-changed")) ["statement-changed"]
    checkEq "receipt: rewording a need stales the claim's entailment receipt"
      (← reasonsOf reworded root "EN1") ["statement-changed"]
    let claimEdit := { pinned with claims := pinned.claims.map fun c =>
      if c.id == "C1" then { c with text := "A different claim." } else c }
    checkEq "receipt: rewording the claim stales its entailment receipt"
      (← reasonsOf claimEdit root "EN1") ["statement-changed"]
    checkEq "receipt: rewording an exclusion endpoint stales the exclusion (R2-N1)"
      (← reasonsOf
        (mapFact pinned "O5" fun f => { f with text := "Every animal was sampled twice." })
        root "X1") ["statement-changed"]
  checkEq "review: a trace without a record is draft" (← Receipt.reviewState base) .draft
  let reviewed ← Receipt.review base "R. Viewer" (some "First pass.")
  checkEq "review: a fresh record is current" (← Receipt.reviewState reviewed) .reviewed
  checkEq "review: the record is excluded from its own digest"
    (← Receipt.reviewDigest reviewed) (← Receipt.reviewDigest base)
  let edited := mapFact reviewed "O3" fun f => { f with status := .open }
  checkEq "review: any later edit makes the record stale" (← Receipt.reviewState edited) .stale
  let c : Receipt.Cache := ({} : Receipt.Cache).insert "a" (5, 1700000000, 42, "d")
  checkEq "receipt: cache JSON round-trips"
    ((Receipt.Cache.ofJson (Receipt.Cache.toJson c)).toList) c.toList

end Tests.Receipt
