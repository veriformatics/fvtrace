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
  checkEq "engine: C1 rests on a background condition" (finalOf s "C1") .conditional
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
    "Assuming “The model assumptions hold.”: RNA is quantified."
  -- Exclusions: X1 (assumed) relates O4 + O5 on S.
  let c9 : Claim := { id := "C9", question := "Q1", subject := "S", level := .descriptive,
                      text := "Both hold.", needs := ["O4", "O5"], entailment := some "EN9" }
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
                           success := [("EN3", .proved)], caveat := "c" }
  let follow := { t with experiments := t.experiments ++ [e4] }
  let sf : Scenario := { s with trace := follow }
  checkEq "engine: closure adds the creator of a prospective subject (R1-P1)" (sf.closure ["E4"])
    ["E3", "E4"]
  match sf.plan (claimNamed follow "C3") with
  | .planned _ exps st .. =>
    checkEq "engine: the C3 plan includes its creator" exps ["E3", "E4"]
    checkEq "engine: the C3 plan reaches can" st .can
  | other => check "engine: the C3 plan includes its creator" false s!"{repr other}"
  -- A creator's closure step re-adds the creator: without dropping duplicates the list doubles
  -- every step (fuel = experiments + 1 ⇒ 2^28 entries here).
  let many := { follow with experiments := follow.experiments ++ (List.range 24).map fun i =>
    { e4 with id := s!"X{i}", subject := "S" } }
  checkEq "engine: closure stays small with many experiments (no doubling per step)"
    (({ s with trace := many } : Scenario).closure ["E3"]) ["E3"]
  checkEq "evaluate: only the creator of a prospective subject creates new data"
    (((sf.trace.experiments.filter sf.creates).map (·.id)), sf.prospective "N") (["E3"], true)
  let onNew := sf.withOverrides [("M1", .checked)]
  check "evaluate: a what-if that changes a new-data claim says so"
    ((onNew.qualifiers (claimNamed follow "C3") .draft).contains "what-if")
  check "evaluate: without a what-if, a new-data claim carries no what-if qualifier"
    (!(sf.qualifiers (claimNamed follow "C3") .draft).contains "what-if")
  let e5 : Experiment := { id := "E5", subject := "S", kind := .wet, effort := .weeks,
                           title := "Assess", method := "m", resources := "r",
                           success := [("O4", .assumed)], caveat := "c" }
  let e6 : Experiment := { e5 with id := "E6", kind := .dry, success := [("O4", .checked)] }
  let checkable := mapFact t "O4" fun f => { f with route := .runtimeChecker }
  let support := { checkable with experiments := checkable.experiments ++ [e5, e6] }
  let ss : Scenario := { s with trace := support }
  checkEq "engine: assumed + checked outcomes merge to checked (R1-P4)" (ss.merged ["E6", "E5"])
    [("O4", .checked)]
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
    checkEq "engine: noImprovement still lists coverage (R2-E2)" cov.uncovered ["O3"]
  | other => check "engine: noImprovement still lists coverage (R2-E2)" false s!"{repr other}"
  match clash.plan (claimNamed t "C2") with
  | .inconsistent _ => check "engine: an invalid what-if yields inconsistent (R1-P3)" true
  | other => check "engine: an invalid what-if yields inconsistent (R1-P3)" false s!"{repr other}"
  checkEq "engine: work ranks closable facts (ties by id)" ((s.work).map (·.fact))
    ["EN2", "EN3", "M1", "O2"]
  checkEq "engine: a violated fact lists apart" ((s.withOverrides [("O2", .violated)]).blockerFacts)
    [("O2", ["C2"])]
  let acts := fun (sc : Scenario) => (Evaluate.actions sc).map fun (id, _, _, o) => (id, o)
  checkEq "evaluate: recorded actions = suppose closable facts, outcomes, plans"
    ((acts s).map (·.1)) ["suppose:O2", "suppose:O4", "suppose:O5", "suppose:EN2", "suppose:M1",
      "suppose:EN3", "success:E1", "success:E2", "success:E3", "failure:E1"]
  checkEq "evaluate: a suppose action is the whole what-if it leads to"
    ((acts (s.withOverrides [("O2", .checked)])).lookup "suppose:EN2")
    (some [("EN2", .proved), ("O2", .checked)])
  checkEq "evaluate: a supposed fact at its ceiling has no suppose action"
    ((acts (s.withOverrides [("O2", .checked)])).lookup "suppose:O2") none
  checkEq "evaluate: a plan action from a what-if keeps it"
    ((acts (s.withOverrides [("EN2", .proved)])).lookup "plan:C2")
    (some [("O2", .checked), ("EN2", .proved)])
  checkEq "engine: what-if parse normalizes" (Overrides.parse t "O3=assumed,O2=checked").toOption
    (some [("O2", .checked), ("O3", .assumed)])
  check "engine: what-if above the route is rejected"
    ((Overrides.parse t "O3=proved").toOption.isNone)
  check "engine: what-if on an unknown fact is rejected"
    ((Overrides.parse t "Z9=assumed").toOption.isNone)
  check "engine: duplicate what-if is rejected"
    ((Overrides.parse t "O2=checked,O2=assumed").toOption.isNone)
  -- The GUI shows a refusal as `<message>. This page shows …` and the CLI as `fvtrace: <message>`:
  -- each message opens with the token it rejects, so it reads right on both.
  let refusal := fun (spec : String) =>
    match Overrides.parse t spec with | .error m => m | .ok _ => ""
  checkEq "engine: an unknown fact opens its refusal" (refusal "Z9=assumed")
    "\"Z9\" is not a fact on record"
  checkEq "engine: an unknown status opens its refusal" (refusal "O2=bogus")
    "\"bogus\" is not a status"
  checkEq "engine: a malformed entry opens its refusal" (refusal "O2")
    "\"O2\" is not of the form FACT=STATUS"

/-- Contract regression witnesses + acceptance cases (kernel.md) beyond `tests`. -/
def witnessTests : TestM Unit := do
  let t ← fixture
  let s : Scenario := { trace := t, current := fun _ => true }
  let e1 := (t.experiment? "E1").get!
  let e3 := (t.experiment? "E3").get!
  let entail := fun (id claim : String) (st : Status) (r : Route) =>
    ({ id, subject := "S", kind := .entailment, text := s!"Its needs entail {claim}.",
       status := st, route := r } : Fact)
  -- R2-P2b: weaker successes on the verified sources of two exclusions never weaken them.
  let xa : Exclusion := { id := "XA", subject := "S", between := ("O2", "O4"),
                          text := "O2 rules out O4.", status := .proved, route := .lean }
  let xb : Exclusion := { id := "XB", subject := "S", between := ("O1", "O5"),
                          text := "O1 rules out O5.", status := .proved, route := .lean }
  let weak := fun (id k : String) => ({ e1 with id, success := [(k, .assumed)], failure := [] } :
    Experiment)
  let c10 : Claim := { id := "C10", question := "Q1", subject := "S", level := .descriptive,
                       text := "Both samplings hold.", needs := ["O4", "O5"],
                       entailment := some "EN10" }
  -- Sources + targets are background conditions: an assumed success on a must-verify fact is
  -- invalid input.
  let base := mapFact (mapFact t "O2" fun f => { f with status := .checked, kind := .provenance })
    "O1" fun f => { f with kind := .provenance }
  let joinT := { base with
    facts := base.facts ++ [entail "EN10" "C10" .assumed .humanRuling]
    claims := base.claims ++ [c10], exclusions := [xa, xb]
    experiments := base.experiments ++ [weak "EA" "O2", weak "EB" "O1"] }
  let sj : Scenario := { s with trace := joinT }
  checkEq "engine: verified sources derive both sides violated" (sj.eff "O4", sj.eff "O5")
    (.violated, .violated)
  checkEq "engine: C10 reads cannot" (finalOf sj "C10") .cannot
  let after := sj.applySuccess (sj.closure ["EA", "EB"])
  checkEq "engine: weaker successes keep both sources verified (R2-P2b)"
    (after.eff1 "O2", after.eff1 "O1") (.checked, .proved)
  checkEq "engine: C10 stays cannot after both weaker successes (R2-P2b)" (finalOf after "C10")
    .cannot
  checkEq "engine: weaker successes raise nothing" (sj.raised (sj.closure ["EA", "EB"])) []
  -- R2-C1: a follow-up plans with its subject's creator + the creator's own prerequisites.
  let e0 : Experiment := { id := "E0", subject := "N", kind := .dry, effort := .hours,
                           title := "Prove the cohort's arithmetic", method := "m",
                           resources := "r",
                           success := [("EN3", .proved)], caveat := "c" }
  let e4 : Experiment := { e0 with id := "E4", effort := .days, title := "Rule on M1" }
  let creator := { e3 with requires := ["E0"] }
  let onS := t.experiments.filter (·.subject == "S")
  let chain := { t with experiments := onS ++ [e0, creator, e4] }
  let sc : Scenario := { s with trace := chain }
  checkEq "engine: the closure holds the creator's own prerequisites (R2-C1)"
    (sc.closure ["E4"]) ["E0", "E3", "E4"]
  let n := "engine: the C3 plan runs the creator's prerequisite too (R2-C1)"
  match sc.plan (claimNamed chain "C3") with
  | .planned _ exps st .. =>
    checkEq n exps ["E0", "E3"]
    checkEq "engine: that plan reaches can" st .can
  | other => check n false s!"{repr other}"
  -- Acceptance (new data): a success on the new subject moves only its claims.
  let lit := sc.applySuccess (sc.closure ["E4"])
  checkEq "engine: a new-data success moves only claims on its subject"
    ((sc.moves lit).map (·.claim)) ["C3"]
  checkEq "engine: existing claims keep their gaps"
    (lit.gaps (claimNamed chain "C1"), lit.gaps (claimNamed chain "C2"))
    (sc.gaps (claimNamed chain "C1"), sc.gaps (claimNamed chain "C2"))
  -- Acceptance (results): with no experiment for result O2, no plan raises C2.
  let noResult := { t with experiments := t.experiments.filter (·.subject != "S") }
  let sr : Scenario := { s with trace := noResult, overrides := [("EN2", .proved)] }
  let n := "engine: no experiment raises result O2, so no plan raises C2"
  match sr.plan (claimNamed noResult "C2") with
  | .noImprovement cov => check n (cov.uncovered.contains "O2") s!"{repr cov.uncovered}"
  | other => check n false s!"{repr other}"
  -- R2-E2: noImprovement still lists the experiments for each need.
  let n := "engine: noImprovement lists E1 for O2 (R2-E2)"
  match s.plan (claimNamed t "C2") with
  | .noImprovement cov =>
    check n (cov.alternatives.any fun a => a.need == "O2" && a.experiment == "E1")
    check "engine: noImprovement lists EN2 as uncovered (R2-E2)" (cov.uncovered.contains "EN2")
  | other => check n false s!"{repr other}"
  -- Acceptance (plan rule): the highest state first, then the lowest cost.
  let c11 : Claim := { id := "C11", question := "Q1", subject := "S", level := .estimand,
                       text := "The table is right.", needs := ["O2"], entailment := some "EN11" }
  let quick : Experiment := { weak "E6" "O2" with effort := .hours }
  let rule := { t with
    claims := t.claims ++ [c11], facts := t.facts ++ [entail "EN11" "C11" .proved .lean]
    experiments := t.experiments ++ [quick] }
  let su : Scenario := { s with trace := rule }
  let n := "engine: a higher state beats a lower cost"
  match su.plan (claimNamed rule "C11") with
  | .planned cov exps st .. =>
    checkEq n (exps, st) (["E1"], .can)
    checkEq "engine: the plan lists both experiments for O2"
      ((cov.alternatives.filter (·.need == "O2")).map (·.experiment)) ["E1", "E6"]
  | other => check n false s!"{repr other}"
  let sure := { quick with id := "E7", success := [("O2", .checked)] }
  let rule2 := { rule with experiments := rule.experiments ++ [sure] }
  let n := "engine: at the same state the cheaper plan wins"
  match ({ s with trace := rule2 } : Scenario).plan (claimNamed rule2 "C11") with
  | .planned _ exps st .. => checkEq n (exps, st) (["E7"], .can)
  | other => check n false s!"{repr other}"
  -- Plan rule, last tie-break: equal state + equal cost → the smaller id list, whichever of the
  -- two tied candidates the search meets first.
  let f1 : Fact := { id := "F1", subject := "S", kind := .numerical, text := "F1 holds.",
                     status := .«open», route := .runtimeChecker }
  let c13 : Claim := { id := "C13", question := "Q1", subject := "S", level := .estimand,
                       text := "F1 and F2 hold.", needs := ["F1", "F2"], entailment := some "EN13" }
  let p : Experiment := { quick with id := "P", success := [("F1", .checked)] }
  let onF2 := fun (id : String) => ({ p with id, success := [("F2", .checked)] } : Experiment)
  let tie := fun (exps : List Experiment) => ({ t with
    facts := t.facts ++ [f1, { f1 with id := "F2", text := "F2 holds." },
      entail "EN13" "C13" .proved .lean]
    claims := t.claims ++ [c13], experiments := t.experiments ++ exps } : Trace)
  let planOf := fun (tr : Trace) =>
    match ({ s with trace := tr } : Scenario).plan (claimNamed tr "C13") with
    | .planned _ exps .. => exps
    | _ => []
  checkEq "engine: a tie goes to the smaller ids (the larger met first)"
    (planOf (tie [p, onF2 "Q1", onF2 "Q2"])) ["P", "Q1"]
  checkEq "engine: a tie goes to the smaller ids (the smaller met first)"
    (planOf (tie [p, onF2 "QB", onF2 "QA"])) ["P", "QA"]
  -- Coverage: an experiment that only repeats a need's current status is no alternative for it.
  let both : Experiment :=
    { quick with id := "XO", success := [("O2", .checked), ("O3", .assumed)] }
  let covT := { t with experiments := t.experiments ++ [both] }
  let cov := ({ s with trace := covT } : Scenario).coverage (claimNamed covT "C2")
  checkEq "engine: an outcome at the need's current status is no alternative"
    ((cov.alternatives.filter (·.experiment == "XO")).map (·.need), cov.uncovered.contains "O3")
    (["O2"], true)
  -- Above 20 relevant experiments no optimum is claimed (and no search runs).
  let many := (List.range 21).map fun i => (s!"G{i}", s!"Y{i}")
  let gs := many.map fun (g, _) => ({ f1 with id := g, text := s!"{g} holds." } : Fact)
  let c21 : Claim := { c13 with id := "C21", needs := many.map (·.1), entailment := some "EN21" }
  let big := { t with
    facts := t.facts ++ gs ++ [entail "EN21" "C21" .proved .lean], claims := t.claims ++ [c21]
    experiments := t.experiments ++ many.map fun (g, y) =>
      { p with id := y, success := [(g, .checked)] } }
  let n := "engine: 21 relevant experiments → tooLarge"
  match ({ s with trace := big } : Scenario).plan (claimNamed big "C21") with
  | .tooLarge _ => check n true
  | other => check n false s!"{repr other}"
  -- Preview counts: a success that derives a violation lowers a claim; each move counts once.
  let c12 : Claim := { id := "C12", question := "Q1", subject := "S", level := .estimand,
                       text := "The animal was sampled once.", needs := ["O4"],
                       entailment := some "EN12" }
  let lowerT := { t with
    claims := t.claims ++ [c12], exclusions := [xa]
    facts := t.facts ++ [entail "EN12" "C12" .assumed .humanRuling] }
  let sl : Scenario := { s with trace := lowerT }
  let wins := sl.moves (sl.applySuccess (sl.closure ["E1"]))
  checkEq "engine: a success that derives a violation lowers a claim"
    (wins.map fun m => (m.claim, m.before, m.after)) [("C12", .«open», .cannot)]
  checkEq "engine: lights, clears + lowers count each move once"
    (Scenario.lights wins, Scenario.clears wins, Scenario.lowers wins) (0, 0, 1)
  checkEq "engine: raises = the facts a success lifts" (sl.raised (sl.closure ["E1"]))
    [("O2", .checked)]
  -- Ranking: unlocks = the claims verifying a fact alone moves from open or cannot to can or
  -- conditional; a claim that is already conditional is not unlocked.
  let sE := s.withOverrides [("EN2", .proved)]
  checkEq "engine: verifying O2 alone unlocks C2" (sE.unlocks (t.fact? "O2").get!) ["C2"]
  let a : Fact := { id := "A", subject := "S", kind := .statistical, text := "A holds.",
                    status := .assumed, route := .lean }
  let ck : Claim := { id := "CK", question := "Q1", subject := "S", level := .estimand,
                      text := "A is so.", needs := ["O1", "A"], entailment := some "EK" }
  let kT := { t with
    facts := t.facts ++ [a, entail "EK" "CK" .proved .lean], claims := t.claims ++ [ck] }
  let sk : Scenario := { s with trace := kT }
  checkEq "engine: CK is conditional on A" (finalOf sk "CK") .conditional
  checkEq "engine: verifying A makes CK can, yet a conditional claim is not unlocked"
    (sk.unlocks a) []
  -- Envelope: an instantiation fact keeps its source.
  let inst : Fact := { id := "I1", subject := "N", kind := .instantiation,
                       text := "O1 holds for the new cohort.", status := .«open»,
                       route := .humanRuling, instantiates := some "O1" }
  check "evaluate: the envelope keeps a fact's instantiation source"
    (((Evaluate.factJson s [] inst).canonical.splitOn "\"instantiates\":\"O1\"").length == 2)

/-- Must-verify kinds + verdict words (contract § Model `allows` + `ceiling f`, S-state gate). -/
def kindTests : TestM Unit := do
  let t ← fixture
  let s : Scenario := { trace := t, current := fun _ => true }
  checkEq "evaluate: verdict words"
    ([State.can, .conditional, .«open», .cannot].map State.verdict)
    ["Fully supported", "Conditional", "Pending verification", "Claim not possible"]
  -- R3-K1: a scenario that assumes a must-verify need (built directly, past the input checks)
  -- never reads conditional; the need lists under gaps, not premises.
  let g := s.withOverrides [("EN2", .assumed), ("O2", .checked)]
  let c2 := claimNamed t "C2"
  checkEq "engine: an assumed reasoning fact keeps C2 open (R3-K1)" (finalOf g "C2") .«open»
  checkEq "engine: the assumed reasoning fact is a gap, the background condition a premise"
    (g.gaps c2, g.premises c2) (["EN2"], ["O3"])
  -- R3-K2: a result on an empirical route tops out at tested: never closable, never supposed.
  let emp := mapFact t "O2" fun f => { f with route := .empirical }
  let se : Scenario := { s with trace := emp }
  check "engine: a result on an empirical route is not closable (R3-K2)"
    (!se.closable (emp.fact? "O2").get!)
  check "evaluate: no suppose action for it"
    (!((Evaluate.actions se).any fun (id, _) => id == "suppose:O2"))
  check "engine: no work row for it" (!(se.work.any (·.fact == "O2")))
  let lean := mapFact t "O3" fun f => { f with route := .lean }
  check "engine: a background condition on a lean route stays closable"
    (({ s with trace := lean } : Scenario).closable (lean.fact? "O3").get!)
  check "engine: the what-if refuses an assumed result"
    ((Overrides.parse t "O2=assumed").toOption.isNone)
  checkEq "engine: the refusal says the fact must be verified"
    (match Overrides.parse t "O2=assumed" with | .error m => m | .ok _ => "")
    "O2 cannot be assumed: facts of its kind must be verified"
  checkEq "engine: the what-if may assume a background condition"
    (Overrides.parse t "O3=assumed").toOption (some [("O3", .assumed)])

/-- Plan search at the ruled limit: 20 relevant experiments on one claim (2^20 candidates for an
exhaustive search; the branch and bound skips subtrees it proves to hold no better plan). -/
def scaleTests : TestM Unit := do
  let efforts := [Effort.hours, .days, .weeks, .months]
  let fact := fun (id : String) (k : Kind) =>
    ({ id, subject := "S", kind := k, text := s!"{id} holds.", status := .«open»,
       route := .lean } : Fact)
  let exp := fun (i : Nat) (success : List (String × Status)) =>
    ({ id := s!"E{i + 10}", subject := "S", kind := .dry, effort := efforts[i % 4]!,
       title := s!"Experiment {i}", method := "Run it.", resources := "None.", success,
       caveat := "None." } : Experiment)
  let wide := fun (facts : List Fact) (c : Claim) (exps : List Experiment)
      (exclusions : List Exclusion) =>
    ({ analysis := { id := "A", title := "Wide", summary := "Twenty experiments, one claim." },
       subjects := [{ id := "S", title := "Wide", kind := .existing }],
       questions := [{ id := "Q", title := "Q", text := "Does it hold?" }],
       facts, claims := [c], experiments := exps, exclusions } : Trace)
  let claimOn := fun (needs : List String) =>
    ({ id := "C", question := "Q", subject := "S", level := .estimand, text := "They hold.",
       needs, entailment := some "EN" } : Claim)
  let planOf := fun (t : Trace) =>
    ({ trace := t, current := fun _ => true } : Scenario).plan ((t.claim? "C").get!)
  let range := List.range 20
  -- Every experiment also proves the reasoning fact EN, so each one is a true alternative for it.
  let proving := fun (i : Nat) (needs : List String) => exp i (((needs ++ ["EN"]).map (·, .proved)))
  let one := range.map (s!"F{·}")
  let n := "plan: 20 experiments, one need each → all twenty"
  match planOf (wide ((one ++ ["EN"]).map (fact · .numerical) |>.map fun f =>
      if f.id == "EN" then { f with kind := .entailment } else f)
      (claimOn one) (range.map fun i => proving i [s!"F{i}"]) []) with
  | .planned _ exps st .. => checkEq n (exps.length, st) (20, .can)
  | other => check n false s!"{repr other}"
  let n := "plan: 20 experiments, one shared need → the cheapest, smallest id"
  match planOf (wide [fact "F" .numerical, fact "EN" .entailment] (claimOn ["F"])
      (range.map fun i => proving i ["F"]) []) with
  | .planned _ exps st .. => checkEq n (exps, st) (["E10"], .can)
  | other => check n false s!"{repr other}"
  let pairs := (List.range 10).map (s!"F{·}")
  let n := "plan: 20 experiments, two per need → the cheaper of each pair"
  match planOf (wide ((pairs.map (fact · .numerical)) ++ [fact "EN" .entailment]) (claimOn pairs)
      (range.map fun i => proving i [s!"F{i / 2}"]) []) with
  | .planned _ exps st .. =>
    checkEq n (exps, st) ((List.range 10).map (s!"E{2 * · + 10}"), .can)
  | other => check n false s!"{repr other}"
  -- Every non-empty set asserts F against the assumed premise G: each one conflicts.
  let x : Exclusion := { id := "X", subject := "S", between := ("F", "G"),
                         text := "F rules out G.", status := .assumed, route := .humanRuling }
  let restating : Claim := { id := "C", question := "Q", subject := "S", level := .descriptive,
                             text := "F holds.", needs := ["F"], restates := true }
  let g : Fact := { fact "G" .statistical with status := .assumed, route := .humanRuling }
  let n := "plan: 20 experiments that each conflict → no improvement"
  match planOf (wide [fact "F" .result, g] restating (range.map fun i => exp i [("F", .proved)])
      [x]) with
  | .noImprovement _ => check n true
  | other => check n false s!"{repr other}"

/-- Contract acceptance rows (03fe522) the unit tests had not reached: valid actions, mixed work
rows, the self-trace's stated verdicts. -/
def acceptanceTests : TestM Unit := do
  let t ← fixture
  let s : Scenario := { trace := t, current := fun _ => true }
  -- Actions: every emitted action's overrides form a valid what-if, from the recorded view and
  -- from a what-if (E1's success touches the result O2; E2's the background condition O4).
  for sc in [s, s.withOverrides [("EN2", .proved)]] do
    check "evaluate: every action is a valid what-if"
      ((Evaluate.actions sc).all fun (_, _, _, o) => Overrides.valid t o)
  -- Work rows: a fact that makes one claim available alone + is needed by another with more.
  let en : Fact := { id := "ENY", subject := "S", kind := .entailment, text := "O2 gives CY.",
                     status := .proved, route := .lean }
  let cy : Claim := { id := "CY", question := "Q1", subject := "S", level := .descriptive,
                      text := "The marker rises.", needs := ["O2"], entailment := some "ENY" }
  let mixed := { t with facts := t.facts ++ [en], claims := t.claims ++ [cy] }
  let sm : Scenario := { s with trace := mixed }
  match sm.work.find? (·.fact == "O2") with
  | some w =>
    checkEq "cli: a mixed work row makes one claim available + names what the other needs"
      (w.unlocks, Cli.neededBy sm w) (["CY"], ["Needed by C2, together with EN2."])
  | none => check "cli: a mixed work row makes one claim available" false
  -- Work rows: a claim that cannot stand still names the facts it needs with the row's fact.
  let blocked := s.withOverrides [("O1", .violated)]
  match blocked.work.find? (·.fact == "O2") with
  | some w =>
    checkEq "cli: a work row names what a blocked claim needs too"
      (Cli.neededBy blocked w)
      ["Needed by C2, together with EN2, but C2 is not possible as worded."]
  | none => check "cli: a work row names what a blocked claim needs too" false
  -- Self-trace (user rulings): its stated verdicts, receipts taken as current.
  match decodeTrace (← IO.FS.readBinFile "examples/fvtrace/trace.json") with
  | .ok self =>
    let ss : Scenario := { trace := self, current := fun _ => true }
    checkEq "examples: the self-trace's verdicts (C1, C3–C6, C8 can; C2 + C7 open)"
      (self.claims.map fun c => (c.id, ss.final c))
      [("C1", .can), ("C2", .«open»), ("C3", .can), ("C4", .can), ("C5", .can), ("C6", .can),
       ("C8", .can), ("C7", .«open»)]
    check "examples: no self-trace claim needs I1 (a universal premise)"
      (self.claims.all fun c => !c.needs.contains "I1")
  | .error _ => check "examples: the self-trace decodes" false

end Tests.Engine
