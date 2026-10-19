import Fvtrace
import Tests.Harness

namespace Tests.Engine
open Tests Fvtrace

def fixture : IO Trace := do
  match decodeTrace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json") with
  | .ok t => pure t
  | .error ds => throw (IO.userError s!"fixture does not decode: {repr ds}")

def mapFact (t : Trace) (id : String) (f : Fact → Fact) : Trace :=
  { t with facts := t.facts.map fun x => if x.id == id then f x else x }

def claimNamed (t : Trace) (id : String) : Claim := (t.claim? id).get!

def finalOf (s : Scenario) (id : String) : State := s.final (claimNamed s.trace id)

def tests : TestM Unit := do
  let t ← fixture
  let s : Scenario := { trace := t, current := fun _ => true }
  checkEq "engine: C1 rests on an assumed entailment" (finalOf s "C1") .conditional
  checkEq "engine: C2 has gaps" (finalOf s "C2") .«open»
  checkEq "engine: prospective C3 is open" (finalOf s "C3") .«open»
  checkEq "engine: breakdown partitions needs"
    (let c := claimNamed t "C2"; (s.verifiedNeeds c, s.premises c, s.gaps c, s.blockers c))
    (["O1"], ["O3"], ["O2", "EN2"], [])
  let stale : Scenario := { s with current := fun _ => false }
  checkEq "engine: a stale receipt no longer counts as verified" (stale.eff "O1") .stale
  checkEq "engine: stale O1 drops C1 to open" (finalOf stale "C1") .«open»
  let w := s.withOverrides [("O2", .checked), ("EN2", .proved)]
  checkEq "engine: what-if raises C2 to conditional" (finalOf w "C2") .conditional
  check "engine: what-if marks C2 hypothetical" (w.hypothetical (claimNamed t "C2"))
  check "engine: what-if leaves C1 recorded" (!w.hypothetical (claimNamed t "C1"))
  checkEq "engine: conditional sentence keeps texts verbatim" (w.sentence (claimNamed t "C2"))
    "Assuming “The model assumptions hold.”: Treatment raises the marker."
  let rna := { t with claims := t.claims.map fun c =>
    if c.id == "C1" then { c with text := "RNA is quantified." } else c }
  checkEq "engine: verbatim capitals (R1-P7)"
    (({ s with trace := rna } : Scenario).sentence (claimNamed rna "C1"))
    "Assuming “O1 entails C1.”: RNA is quantified."
  -- Exclusions: X1 (assumed) relates O4 + O5 on S.
  let c9 : Claim := { id := "C9", question := "Q1", subject := "S", level := .descriptive,
                      text := "Both hold.", needs := ["O4", "O5"], entailment := "EN9" }
  let en9 : Fact := { id := "EN9", subject := "S", kind := .entailment,
                      text := "O4 and O5 entail C9.", status := .assumed, route := .humanRuling }
  let both := { t with claims := t.claims ++ [c9], facts := t.facts ++ [en9] }
  let sb : Scenario := { s with trace := both }
  checkEq "engine: needing both sides of an exclusion is cannot (R2-E1)" (finalOf sb "C9")
    .cannot
  checkEq "engine: the incompatible witness names X1"
    (sb.incompatible (claimNamed both "C9")) ["X1"]
  let clash := s.withOverrides [("O4", .assumed), ("O5", .assumed)]
  checkEq "engine: a conflicting what-if invalidates subject S" (clash.valid "S") false
  checkEq "engine: every claim on S reads cannot" (finalOf clash "C1") .cannot
  checkEq "engine: the other subject is untouched (R1-P6)" (finalOf clash "C3") (finalOf s "C3")
  check "engine: conflict qualifier" ((clash.qualifiers (claimNamed t "C1") .reviewed).contains
    "conflicting what-if")
  let verifiedX := { t with exclusions := t.exclusions.map fun x =>
    { x with status := .proved, route := .lean } }
  let sx : Scenario := { s with trace := verifiedX, overrides := [("O4", .checked)] }
  checkEq "engine: a verified exclusion derives the other side violated" (sx.eff "O5") .violated
  checkEq "engine: the derivation keeps its witness" (sx.derivations "O5") [("X1", "O4")]
  -- Experiments: E1 checks O2; E2 (requires E1) asserts O4; E3 creates N + checks M1.
  checkEq "engine: closure adds requires" (s.closure ["E2"]) ["E1", "E2"]
  let e4 : Experiment := { id := "E4", subject := "N", kind := .dry, effort := .days,
                           title := "Rule on M1", method := "m", resources := "r",
                           success := [("EN3", .assumed)], caveat := "c" }
  let follow := { t with experiments := t.experiments ++ [e4] }
  let sf : Scenario := { s with trace := follow }
  checkEq "engine: closure adds the creator of a prospective subject (R1-P1)" (sf.closure ["E4"])
    ["E3", "E4"]
  match sf.plan (claimNamed follow "C3") with
  | .planned _ exps st .. =>
    checkEq "engine: the C3 plan includes its creator" exps ["E3", "E4"]
    checkEq "engine: the C3 plan reaches conditional" st .conditional
  | other => check "engine: the C3 plan includes its creator" false s!"{repr other}"
  let e5 : Experiment := { id := "E5", subject := "S", kind := .wet, effort := .weeks,
                           title := "Assess", method := "m", resources := "r",
                           success := [("O2", .assumed)], caveat := "c" }
  let support := { t with experiments := t.experiments ++ [e5] }
  let ss : Scenario := { s with trace := support }
  checkEq "engine: assumed + checked outcomes merge to checked (R1-P4)" (ss.merged ["E1", "E5"])
    [("O2", .checked)]
  let weaken := s.withOverrides [("O1", .proved)]
  checkEq "engine: a weaker success never lowers a fact (R2-P2b)"
    ((weaken.applySuccess ["E5"]).eff "O1") .proved
  match (s.withOverrides [("EN2", .proved)]).plan (claimNamed t "C2") with
  | .planned cov exps st .. =>
    checkEq "engine: C2 plan = E1" exps ["E1"]
    checkEq "engine: C2 plan reaches conditional" st .conditional
    checkEq "engine: alternatives list E1 for O2" (cov.alternatives.map (·.experiment)) ["E1"]
  | other => check "engine: C2 plan = E1" false s!"{repr other}"
  match s.plan (claimNamed t "C1") with
  | .noImprovement cov =>
    checkEq "engine: noImprovement still lists coverage (R2-E2)" cov.uncovered ["EN1"]
  | other => check "engine: noImprovement still lists coverage (R2-E2)" false s!"{repr other}"
  match clash.plan (claimNamed t "C2") with
  | .inconsistent _ => check "engine: an invalid what-if yields inconsistent (R1-P3)" true
  | other => check "engine: an invalid what-if yields inconsistent (R1-P3)" false s!"{repr other}"
  checkEq "engine: work ranks closable facts (ties by id)" ((s.work).map (·.fact))
    ["EN2", "EN3", "M1", "O2"]
  checkEq "engine: a violated fact lists apart" ((s.withOverrides [("O2", .violated)]).blockerFacts)
    [("O2", ["C2"])]
  checkEq "engine: what-if parse normalizes" (Overrides.parse t "O3=assumed,O2=checked").toOption
    (some [("O2", .checked), ("O3", .assumed)])
  check "engine: what-if above the route is rejected"
    ((Overrides.parse t "O3=proved").toOption.isNone)
  check "engine: what-if on an unknown fact is rejected"
    ((Overrides.parse t "Z9=assumed").toOption.isNone)
  check "engine: duplicate what-if is rejected"
    ((Overrides.parse t "O2=checked,O2=assumed").toOption.isNone)

end Tests.Engine
