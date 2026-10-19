import Fvtrace
import Tests.Harness

namespace Tests.Check
open Tests Fvtrace

def fixture : IO Trace := do
  match decodeTrace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json") with
  | .ok t => pure t
  | .error ds => throw (IO.userError s!"fixture does not decode: {repr ds}")

def found (t : Trace) : List (String × String) :=
  (Check.violations t).map fun v => (v.rule.code, v.path)

def mapClaim (t : Trace) (id : String) (f : Claim → Claim) : Trace :=
  { t with claims := t.claims.map fun c => if c.id == id then f c else c }

def mapFact (t : Trace) (id : String) (f : Fact → Fact) : Trace :=
  { t with facts := t.facts.map fun x => if x.id == id then f x else x }

def mapExperiment (t : Trace) (id : String) (f : Experiment → Experiment) : Trace :=
  { t with experiments := t.experiments.map fun e => if e.id == id then f e else e }

/-- `t` breaks exactly the listed (rule, path) instances. -/
def expect (name : String) (t : Trace) (want : List (String × String)) : TestM Unit :=
  checkEq name (found t) want

def tests : TestM Unit := do
  let t ← fixture
  expect "check: the synthetic fixture is well-formed" t []
  let roundTrip := fun (x : Trace) => (decodeTrace (Encode.trace x).pretty.toUTF8).toOption
  checkEq "encode: the synthetic fixture round-trips" (roundTrip t) (some t)
  let latent := mapClaim t "C2" fun c => { c with latent := true }
  checkEq "encode: a latent claim round-trips" (roundTrip latent) (some latent)
  checkEq "lint: the synthetic fixture has no warning" (Lint.warnings t).length 0
  expect "check: duplicate id" { t with questions := t.questions ++ [⟨"O1", "Dup", "Dup?"⟩] }
    [("WF-ids", "")]
  expect "check: dangling need" (mapClaim t "C1" fun c => { c with needs := ["O9"] })
    [("WF-refs", "/claims/0/needs")]
  expect "check: dangling question" (mapClaim t "C1" fun c => { c with question := "Q9" })
    [("WF-refs", "/claims/0/question")]
  expect "check: need on another subject" (mapClaim t "C1" fun c => { c with needs := ["M1"] })
    [("WF-subject", "/claims/0")]
  expect "check: entailment of wrong kind" (mapClaim t "C1" fun c => { c with entailment := "O3" })
    [("WF-entail", "/claims/0/entailment")]
  expect "check: shared entailment"
    (mapClaim t "C2" fun c => { c with entailment := "EN1" })
    [("WF-entail", "/claims/0/entailment"), ("WF-entail", "/claims/1/entailment")]
  expect "check: entailment fact used as a need"
    (mapClaim t "C2" fun c => { c with needs := c.needs ++ ["EN1"] })
    [("WF-entail", "/claims/1/needs")]
  expect "check: empty needs" (mapClaim t "C1" fun c => { c with needs := [] })
    [("WF-needs", "/claims/0/needs")]
  expect "check: repeated need" (mapClaim t "C1" fun c => { c with needs := ["O1", "O1"] })
    [("WF-needs", "/claims/0/needs")]
  expect "check: human ruling cannot prove"
    (mapFact t "O3" fun f =>
      { f with status := .proved, evidence := (t.fact? "O1").bind (·.evidence) })
    [("WF-route", "/facts/2/status")]
  expect "check: outcome above its route"
    (mapExperiment t "E2" fun e => { e with success := [("O4", .checked)] })
    [("WF-route", "/experiments/1")]
  expect "check: success must assert"
    (mapExperiment t "E1" fun e => { e with success := [("O2", .tested)] })
    [("WF-outcome", "/experiments/0/success")]
  expect "check: failure must violate"
    (mapExperiment t "E1" fun e => { e with failure := [("O2", .«open»)] })
    [("WF-outcome", "/experiments/0/failure")]
  expect "check: requires must name an earlier experiment"
    (mapExperiment t "E1" fun e => { e with requires := ["E2"] })
    [("WF-outcome", "/experiments/0/requires")]
  expect "check: verified needs a receipt"
    (mapFact t "O1" fun f => { f with evidence := none })
    [("WF-receipt", "/facts/0/evidence")]
  expect "check: receipt needs a statement digest"
    (mapFact t "O1" fun f =>
      { f with evidence := f.evidence.map fun ev => { ev with statementDigest := none } })
    [("WF-receipt", "/facts/0/evidence")]
  expect "check: path may not climb out of the project"
    (mapFact t "O1" fun f => { f with evidence := f.evidence.map fun ev =>
      { ev with artifacts := ev.artifacts.map fun a => { a with path := "../secret.txt" } } })
    [("WF-path", "")]
  expect "check: absolute path rejected"
    (mapFact t "O1" fun f => { f with evidence := f.evidence.map fun ev =>
      { ev with artifacts := ev.artifacts.map fun a => { a with path := "/etc/passwd" } } })
    [("WF-path", "")]
  expect "check: backslash in a path rejected"
    (mapFact t "O1" fun f => { f with evidence := f.evidence.map fun ev =>
      { ev with artifacts := ev.artifacts.map fun a => { a with path := "proofs\\A.lean" } } })
    [("WF-path", "")]
  expect "check: NUL in a path rejected"
    (mapFact t "O1" fun f => { f with evidence := f.evidence.map fun ev =>
      { ev with artifacts := ev.artifacts.map fun a => { a with path := "proofs/A\x00.lean" } } })
    [("WF-path", "")]
  expect "check: prospective fact must record open"
    (mapFact t "M1" fun f => { f with status := .assumed })
    [("WF-prospective", "/facts/7/status")]
  expect "check: creator must be on its subject"
    (mapExperiment t "E3" fun e => { e with subject := "S", success := [("O2", .checked)] })
    [("WF-prospective", "/subjects/1/createdBy")]
  expect "check: variant must mirror an existing claim"
    (mapClaim t "C3" fun c => { c with variantOf := some "C3" })
    [("WF-variant", "/claims/2/variantOf")]
  expect "check: exclusion of one fact"
    { t with exclusions := t.exclusions.map fun x => { x with between := ("O4", "O4") } }
    [("WF-exclusion", "/exclusions/0/between")]
  expect "check: repeated exclusion pair"
    { t with exclusions := t.exclusions ++ t.exclusions.map fun x =>
        { x with id := "X2", between := (x.between.2, x.between.1) } }
    [("WF-exclusion", "/exclusions/1")]
  expect "check: contradictory recorded statuses"
    (mapFact (mapFact t "O4" fun f => { f with status := .assumed }) "O5"
      fun f => { f with status := .assumed })
    [("WF-consistent", "/exclusions/0")]
  expect "check: waiver names a lint rule"
    { t with waivers := [⟨"L-nope", "C1", "why"⟩] } [("WF-waiver", "/waivers/0/rule")]
  expect "check: instantiation names its source"
    (mapFact t "O4" fun f => { f with kind := .instantiation })
    [("WF-kind", "/facts/3")]
  let noResult := mapClaim t "C2" fun c => { c with needs := ["O1", "O3"] }
  checkEq "lint: inferential claim without a result fact"
    ((Lint.warnings noResult).map fun w => (w.rule, w.path, w.waived))
    [("L-result", "/claims/1", none)]
  let waived := { noResult with waivers := [⟨"L-result", "C2", "Counted elsewhere."⟩] }
  checkEq "lint: a waiver keeps the warning, with its reason"
    ((Lint.warnings waived).map fun w => (w.rule, w.waived))
    [("L-result", some "Counted elsewhere.")]
  let causal := mapClaim t "C2" fun c => { c with level := .causal }
  checkEq "lint: causal claim without an interpretation fact"
    ((Lint.warnings causal).map (·.rule)) ["L-interpretation"]
  checkEq "lint: release claim without a release fact"
    ((Lint.warnings (mapClaim t "C1" fun c => { c with level := .release })).map (·.rule))
    ["L-release"]
  let (rc, out, _) ← capture (Fvtrace.Cli.run ["check", "tests/fixtures/synthetic.trace.json"])
  checkEq "cli: check valid rc" rc 0
  checkEq "cli: check valid output" out
    ("tests/fixtures/synthetic.trace.json: valid\n" ++
      "  receipts: not checked (give --project DIR)\n  review: draft\n")
  let (rc, out, _) ←
    capture (Fvtrace.Cli.run ["check", "--json", "tests/schema/cases/invalid-status.json"])
  checkEq "cli: check invalid rc" rc 1
  check "cli: check --json is JSON" ((Json.parse out.toUTF8).toOption.isSome)
  let (rc, _, err) ← capture (Fvtrace.Cli.run ["check", "tests/fixtures/absent.json"])
  checkEq "cli: check unreadable rc" rc 2
  check "cli: unreadable file named"
    (err.startsWith "fvtrace: cannot read tests/fixtures/absent.json")
  checkEq "render: control characters escaped" (Render.safe "a\x1b[2Jb\x9bc\x7f\nd")
    "a\\u{1b}[2Jb\\u{9b}c\\u{7f}\\u{0a}d"
  checkEq "render: escape range boundaries" (Render.safe "\x1f \x7e\x7f\x9f\xa0\x10\x90")
    "\\u{1f} ~\\u{7f}\\u{9f}\xa0\\u{10}\\u{90}"

end Tests.Check
