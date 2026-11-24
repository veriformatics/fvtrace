import Fvtrace
import Tests.Harness

namespace Tests.Check
open Tests Fvtrace

def found (t : Trace) : List (String × String) :=
  (Check.violations t).map fun v => (v.rule.code, v.path)

def mapClaim (t : Trace) (id : String) (f : Claim → Claim) : Trace :=
  { t with claims := t.claims.map fun c => if c.id == id then f c else c }

def mapExperiment (t : Trace) (id : String) (f : Experiment → Experiment) : Trace :=
  { t with experiments := t.experiments.map fun e => if e.id == id then f e else e }

/-- `t` breaks exactly the listed (rule, path) instances. -/
def expect (name : String) (t : Trace) (want : List (String × String)) : TestM Unit :=
  checkEq name (found t) want

/-- Reused facts (user ruling; kernel.md WF-route): a reuse (`instantiation`) of a fact that must
be verified must be verified too, through reuses of reuses, naming the direct source; a reuse of a
background condition, or a cycle of reuses reaching no must-verify kind, may be assumed. -/
def reuseTests : TestM Unit := do
  let t ← fixture
  let k := t.facts.length
  let reuse := fun (fid sub src : String) (st : Status) =>
    ({ id := fid, subject := sub, kind := .instantiation, text := s!"{fid} holds here too.",
       status := st, route := .humanRuling, instantiates := some src } : Fact)
  let withFacts := fun (fs : List Fact) => { t with
    subjects := t.subjects ++ [{ id := "T", title := "Other data", kind := .existing }],
    facts := t.facts ++ fs }
  let messages := fun (x : Trace) => (Check.violations x).map (·.message)
  let direct := withFacts [reuse "I2" "T" "O2" .assumed]
  expect "check: a reused result recorded assumed" direct [("WF-route", s!"/facts/{k}/status")]
  checkEq "check: the refusal names the reuse + its source" (messages direct)
    ["I2 reuses O2, which must be verified, so I2 cannot be assumed."]
  let chain := withFacts [reuse "I2" "T" "O2" .«open», reuse "I2b" "S" "I2" .assumed]
  checkEq "check: a reuse of a reuse of a result names its direct source" (messages chain)
    ["I2b reuses I2, which must be verified, so I2b cannot be assumed."]
  expect "check: a reused background condition may be assumed"
    (withFacts [reuse "I3" "T" "O3" .assumed]) []
  expect "check: a cycle of reuses reaches no must-verify kind"
    (withFacts [reuse "Ca" "T" "Cb" .assumed, reuse "Cb" "S" "Ca" .assumed]) []
  -- A second fact under a taken id is judged by the first (WF-ids reports the duplicate).
  let dup := { t with facts := t.facts ++ [{ (t.fact? "O3").get! with
    id := "O2", status := .assumed, route := .humanRuling }] }
  checkEq "check: a duplicate id's record names the first fact, not an empty source"
    ((Check.violations dup).filterMap fun v => if v.path == s!"/facts/{k}/status" then
      some v.message else none)
    ["O2 cannot be assumed: the fact listed first with this id must be verified"]
  -- Fuel = the fact count, at its bound: every fact but the source is one chain, so the far end's
  -- walk takes exactly that many steps (one fewer would read the far end as no must-verify fact).
  let m := 6
  let chained := { withFacts [] with
    facts := [(t.fact? "O2").get!] ++ (List.range m).map fun i =>
      reuse s!"L{i}" (if i % 2 == 0 then "T" else "S") (if i == 0 then "O2" else s!"L{i - 1}")
        (if i + 1 == m then .assumed else .«open»),
    subjects := (withFacts []).subjects.filter (·.id != "N"),
    claims := [], experiments := [], exclusions := [], waivers := [] }
  checkEq "check: the far end of a chain of every fact but its source must be verified"
    (messages chained)
    [s!"L{m - 1} reuses L{m - 2}, which must be verified, so L{m - 1} cannot be assumed."]
  let e := { t.experiments.head! with
    id := "E4", subject := "T", success := [("I2", .assumed)], failure := [], requires := [] }
  let outcome := { withFacts [reuse "I2" "T" "O2" .«open»] with
    experiments := t.experiments ++ [e] }
  expect "check: an outcome cannot assume a reused result" outcome
    [("WF-route", s!"/experiments/{t.experiments.length}")]
  checkEq "check: the outcome refusal names the source" (messages outcome)
    ["outcome \"I2\": an outcome cannot assume I2: it reuses O2, which must be verified; \
      leave I2 out"]

def tests : TestM Unit := do
  let t ← fixture
  expect "check: the synthetic fixture is well-formed" t []
  match decodeTrace (← IO.FS.readBinFile "skill/fvtrace/assets/example.trace.json") with
  | .ok ex => expect "check: the skill's example trace is well-formed" ex []
  | .error ds => check "check: the skill's example trace decodes" false s!"{repr ds}"
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
  expect "check: entailment of wrong kind"
    (mapClaim t "C1" fun c => { c with entailment := some "O2" })
    [("WF-entail", "/claims/0/entailment")]
  expect "check: shared entailment"
    (mapClaim t "C2" fun c => { c with entailment := some "EN1" })
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
  expect "check: a result is never recorded assumed (must-verify kind)"
    (mapFact t "O2" fun f => { f with status := .assumed })
    [("WF-route", "/facts/1/status")]
  for k in [Kind.entailment, .estimand, .numerical, .implementation, .dataflow] do
    expect s!"check: kind {k.name} is never recorded assumed"
      (mapFact t "O5" fun f => { f with kind := k, status := .assumed })
      [("WF-route", "/facts/4/status")]
  let assumedOutcome := mapExperiment t "E1" fun e => { e with success := [("O2", .assumed)] }
  expect "check: an outcome never assumes a must-verify fact" assumedOutcome
    [("WF-route", "/experiments/0")]
  checkEq "check: the outcome message names a repair a success can take"
    ((Check.violations assumedOutcome).map (·.message))
    ["outcome \"O2\": an outcome cannot assume O2: facts of kind result must be verified; \
      leave O2 out"]
  let assumedFailure := mapExperiment t "E1" fun e => { e with failure := [("O2", .assumed)] }
  let routeMessages := ((Check.violations assumedFailure).filter (·.rule == .route)).map
    (·.message)
  check "check: a failure's route diagnostic gives a repair both outcome sides allow"
    (routeMessages.length == 1 && routeMessages.all fun m =>
      (m.splitOn "a success").length == 1 && (m.splitOn "set a verified").length == 1 &&
        (m.splitOn "leave O2 out").length == 2) s!"{repr routeMessages}"
  expect "check: background conditions may be assumed"
    (mapFact (mapFact t "O4" fun f => { f with kind := .interpretation, status := .assumed })
      "O5" fun f => { f with kind := .specReview })
    []
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
  expect "check: prospective fact must record open (an assumed result breaks WF-route too)"
    (mapFact t "M1" fun f => { f with status := .assumed })
    [("WF-route", "/facts/7/status"), ("WF-prospective", "/facts/7/status")]
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
  checkEq "render: control characters escaped" (Render.safe "a\x1b[2Jb\x9bc\x7f\nd")
    "a\\u{1b}[2Jb\\u{9b}c\\u{7f}\\u{0a}d"
  checkEq "render: escape range boundaries" (Render.safe "\x1f \x7e\x7f\x9f\xa0\x10\x90")
    "\\u{1f} ~\\u{7f}\\u{9f}\xa0\\u{10}\\u{90}"
  checkEq "render: bidirectional formatting escaped"
    (Render.safe "a\u202ab\u202ec\u2066d\u2069e\u061cf\u200eg\u200f")
    "a\\u{202a}b\\u{202e}c\\u{2066}d\\u{2069}e\\u{61c}f\\u{200e}g\\u{200f}"
  let kept := "\u2029\u202f\u2065\u206a\u200d\u061b\u200b"
  checkEq "render: bidirectional range boundaries kept" (Render.safe kept) kept

/-- L-* over its whole domain (`kernel.md` § Lints, the contract's table restated here): every claim
level × every subset of the five kinds the rules ask for → exactly the rules whose levels hold the
level and whose kind the claim does not need. -/
def lintTableTests : TestM Unit := do
  let t ← fixture
  let rules : List (String × List Level × Kind) :=
    [("L-result", [.descriptive, .inferential, .causal], .result),
     ("L-statistical", [.inferential, .causal], .statistical),
     ("L-interpretation", [.causal], .interpretation),
     ("L-release", [.release], .release),
     ("L-estimand", [.estimand], .estimand)]
  let subject := ((t.claims.find? (·.id == "C2")).map (·.subject)).getD ""
  let extra : List Fact := rules.zipIdx.map fun ((_, _, kind), i) =>
    { id := s!"K{i}", subject, kind, text := "A fact of one kind.", status := .«open»,
      route := .lean }
  let base := { t with facts := t.facts ++ extra, waivers := [] }
  let mut wrong : List String := []
  let mut cases := 0
  for level in Level.all do
    for mask in [0:32] do
      let present := extra.zipIdx.filter fun (_, i) => (mask >>> i) % 2 == 1
      let traced := mapClaim base "C2" fun c => { c with level, needs := present.map (·.1.id) }
      let got := ((Lint.warnings traced).filter (·.claim == "C2")).map (·.rule)
      let want := (rules.filter fun (_, levels, kind) =>
        levels.contains level && !present.any (·.1.kind == kind)).map (·.1)
      unless got.mergeSort (· ≤ ·) == want.mergeSort (· ≤ ·) do
        wrong := s!"{repr level} mask {mask}: {got}" :: wrong
      cases := cases + 1
  check s!"lint property: every level × kind subset fires exactly the contract's rules \
    ({cases} cases)" wrong.isEmpty (", ".intercalate (wrong.take 3))

end Tests.Check
