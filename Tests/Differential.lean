import Tests.Harness
import Fvtrace.Check
import Fvtrace.Evaluate

/-! P-shared/P-claims: generated inputs → reference records; fast bodies stay outside the oracle. -/

namespace Tests.Differential
open Fvtrace

private abbrev Gen := StateM UInt64

private def draw (bound : Nat) : Gen Nat := do
  let x := (← get) * 6364136223846793005 + 1442695040888963407
  set x
  return (x >>> 32).toNat % max 1 bound

private def pick {α : Type} [Inhabited α] (xs : List α) : Gen α := do
  return (xs[(← draw xs.length)]?).getD default

private def shuffled {α : Type} (xs : List α) : Gen (List α) := do
  let keyed ← xs.mapM fun x => do return (← draw 1000003, x)
  return (keyed.mergeSort fun a b => a.1 ≤ b.1).map (·.2)

private def receipt : Evidence :=
  { summary := "Receipt", artifacts := [{ path := "proof/result", sha256 := some digest }],
    verifier := some "Verifier", statement := some "Statement", statementDigest := some digest }
where digest := String.ofList (List.replicate 64 'a')

private def fact (id subject : String) (kind : Kind) (route : Route) (status : Status) : Fact :=
  { id, subject, kind, route, status, text := s!"{id}: RNA α\nremains verbatim.",
    evidence := if status.verified then some receipt else none,
    trusts := ["Compiler", "Records"], why := some "The conclusion depends on this fact." }

private def experiment (id subject : String) (success : Overrides) : Gen Experiment := do
  return {
    id, subject, kind := ← pick ExpKind.all, effort := ← pick Effort.all,
    title := s!"Run {id}", method := "Check the object", resources := "Time", success,
    caveat := "An inconclusive outcome asserts nothing." }

private def sample {α : Type} (salt : UInt64) (g : Gen α) : α := (g.run' salt).run

private def seed : UInt64 := 0x46565452414345

/-- Every allowed kind×route×status occurs; random order, prerequisites + optional fields vary. -/
private def generatedTrace (n : Nat) : Gen Trace := do
  let route := Route.all[n / Status.all.length]!
  let status := Status.all[n % Status.all.length]!
  let mut fs := Kind.all.zipIdx.map fun (kind, i) =>
    let f := fact s!"F{i}" "S0" kind route status
    { f with
      status := if f.allows status then status else .«open»,
      instantiates := if kind == .instantiation then some "B" else none }
  fs := fs ++ [fact "R" "S0" .result .runtimeChecker .checked,
    fact "Reason" "S0" .entailment .lean .proved,
    fact "B" "S1" .result .runtimeChecker (if n % 2 == 0 then .checked else .«open»),
    fact "Xsource" "S0" .statistical .lean .proved]
  let mut xs := []
  for (st, i) in Status.all.zipIdx do
    let id := s!"Xside{i}"
    fs := fs ++ [fact id "S0" .statistical .runtimeChecker .«open»]
    let r ← pick (Route.all.filter (·.allows st))
    let pair := if (← draw 2) == 0 then ("Xsource", id) else (id, "Xsource")
    xs := xs ++ [{
      id := s!"X{i}", subject := "S0", between := pair,
      text := s!"Pair {i} excludes", status := st, route := r,
      evidence := if st.verified then some receipt else none : Exclusion }]
  let needs ← shuffled ((List.range 11).map fun i => s!"F{i + 1}")
  let mut cs : List Claim := [
    { id := "C0", question := "Q0", subject := "S0", level := ← pick Level.all,
      text := "RNA is quantified. α ≤ β.", headline := some "RNA is quantified.",
      needs, entailment := some "F0", latent := (← draw 2) == 0 },
    { id := "C1", question := "Q1", subject := "S0", level := .descriptive,
      text := "The recorded result.", needs := ["R"], restates := true },
    { id := "C2", question := "Q2", subject := "S0", level := .causal,
      text := "An excluded possibility.", needs := if n % 2 == 0 then ["Xside0"]
        else ["Xside0", "Xsource"], entailment := some "Reason", latent := true },
    { id := "C3", question := "Q0", subject := "S1", level := .descriptive,
      text := "The other subject's result.", needs := ["B"], restates := true }]
  let allowed := fs.filter fun f => f.subject == "S0" && f.ceiling.asserted
  let support ← shuffled (allowed.map fun f => (f.id, f.ceiling))
  let repeats ← shuffled [("Xsource", Status.assumed), ("Xsource", .proved),
    ("Xside1", .assumed), ("Xside1", .checked), ("Xsource", .assumed)]
  let e0 ← experiment "E0" "S0" (repeats ++ support.take (1 + (← draw 5)))
  let e1 ← experiment "E1" "S0" [("Reason", .proved), ("Xside0", .checked)]
  let e2 ← experiment "E2" "S0" support
  let e3 ← experiment "E3" "S0" [("Xside2", .checked)]
  let eb ← experiment "EB" "S1" [("B", .checked)]
  let mut es := [{ e0 with failure := [("R", .violated), ("R", .violated)] },
    { e1 with requires := ["E0"], failure := [("Xsource", .violated)] },
    { e2 with requires := ["E0"], failure := [("F1", .violated)] },
    { e3 with requires := ["E1", "E2", "E0", "E0"] },
    { eb with failure := [("B", .violated)] }]
  let mut subs : List Subject := [
    { id := "S0", title := "Existing one", kind := .existing },
    { id := "S1", title := "Existing two", kind := .existing }]
  for p in [0, 1] do
    let sub := s!"P{p}"
    let r := sub ++ "Result"
    let ent := sub ++ "Reason"
    let inst := sub ++ "Reuse"
    let pre := sub ++ "pre"
    let creator := sub ++ "make"
    let follow := sub ++ "follow"
    subs := subs ++ [{
      id := sub, title := s!"Future {p}", kind := .prospective,
      createdBy := some creator }]
    fs := fs ++ [fact r sub .result .runtimeChecker .«open»,
      fact ent sub .entailment .lean .«open»,
      { fact inst sub .instantiation .empirical .«open» with instantiates := some "R" }]
    cs := cs ++ [{
      id := sub ++ "Claim", subject := sub, question := s!"Q{p}",
      level := .inferential, text := s!"Future claim {p}.", needs := [r, inst],
      entailment := some ent, variantOf := some (if p == 0 then "C0" else "C1"),
      latent := p == 1 }]
    let a ← experiment pre sub [(inst, .assumed)]
    let b ← experiment creator sub [(r, .checked), (r, .checked)]
    let c ← experiment follow sub [(ent, .proved), (r, .checked)]
    -- pre → createdBy make → requires pre: valid WF order, cyclic closure graph.
    es := es ++ [a, { b with requires := [pre], failure := [(r, .violated)] },
      { c with requires := [pre, creator], failure := [(inst, .violated)] }]
  let ws := Check.lintRules.zipIdx.map fun (rule, i) =>
    { rule, claim := cs[i % cs.length]!.id, reason := s!"Waiver {i}." : Waiver }
  return {
    analysis := { id := s!"A{n}", title := "Differential", summary := "Generated trace" },
    subjects := ← shuffled subs, questions := ← shuffled ((List.range 3).map fun i =>
      { id := s!"Q{i}", title := s!"Question {i}", text := "What follows?" }),
    facts := ← shuffled fs, claims := ← shuffled cs, experiments := es,
    exclusions := ← shuffled xs, waivers := ← shuffled ws,
    review := if n % 3 == 0 then none else some
      { reviewer := "Reviewer α", date := "2026-01-01", digest := "digest",
        note := some "Reviewed" } }

private def boundaryTrace (experiments : Nat) : Trace :=
  { analysis := { id := "Boundary", title := "Boundary", summary := "Plan limit" },
    subjects := [{ id := "S", title := "Subject", kind := .existing }],
    questions := [{ id := "Q", title := "Question", text := "What follows?" }],
    facts := [fact "R" "S" .result .runtimeChecker .«open»],
    claims := [{
      id := "C", question := "Q", subject := "S", level := .descriptive,
      text := "Result.", needs := ["R"], restates := true }],
    experiments := (List.range experiments).map fun i =>
      { id := s!"E{i}", subject := "S", kind := .dry, effort := .hours,
        title := s!"Experiment {i}", method := "Check", resources := "Time",
        success := [("R", .checked)], failure := [("R", .violated)], caveat := "None" } }

private def emptyTrace : Trace :=
  { boundaryTrace 0 with facts := [], claims := [], questions := [] }

private def malformed (t : Trace) (n : Nat) : Trace := Id.run do
  let f := t.facts.head!
  let c := t.claims.head!
  let e := t.experiments.head!
  let x := t.exclusions.head!
  let sub := t.subjects.head!
  let q := t.questions.head!
  match n % 6 with
  | 0 => return { t with
      subjects := sub :: t.subjects ++ [{ sub with title := "Later subject" }],
      questions := { q with id := f.id } :: t.questions ++ [q],
      facts := f :: t.facts ++ [{ f with text := "Later fact", kind := .result }],
      claims := c :: t.claims ++ [{ c with text := "Later claim", needs := [] }],
      experiments := e :: t.experiments ++ [{ e with subject := "Missing" }],
      exclusions := x :: t.exclusions ++ [{ x with text := "Later exclusion" }] }
  | 1 => return { t with
      subjects := [{ sub with createdBy := some "Missing" }],
      facts := [{ f with subject := "Missing", instantiates := some "Absent" }],
      claims := [{ c with
        subject := "Missing", question := "Absent", needs := ["Missing"],
        entailment := some "Absent", variantOf := some "Missing" }],
      experiments := [{ e with
        subject := "Missing", requires := ["Absent"],
        success := [("Missing", .assumed)], failure := [("Absent", .checked)] }],
      exclusions := [{ x with subject := "Missing", between := ("Absent", "Missing") }],
      waivers := [{ rule := "L-result", claim := "Missing", reason := "Dangling" }] }
  | 2 => return { t with claims := [
      { c with restates := true, needs := [f.id, f.id], entailment := some f.id },
      { c with id := "Other", restates := true, needs := [f.id, f.id] },
      { c with id := "Third", restates := true, needs := [] },
      { c with id := "Fourth", restates := true, needs := [f.id] }] ++ t.claims }
  | 3 => return { t with exclusions := [x, { x with id := "Reversed", between := x.between.swap },
      { x with id := "OtherSubject", subject := "Missing" },
      { x with id := "Self", between := (x.between.1, x.between.1) }, x] ++ t.exclusions }
  | 4 => return { t with waivers := [
      { rule := "L-result", claim := c.id, reason := "First" },
      { rule := "L-result", claim := c.id, reason := "Second" },
      { rule := "a|b", claim := "c", reason := "Tuple one" },
      { rule := "a", claim := "b|c", reason := "Tuple two" },
      { rule := "", claim := "\x00α", reason := "Empty key" }] ++ t.waivers }
  | _ => return { t with
      claims := [
      { c with restates := true, needs := [], entailment := none },
      { c with id := "", restates := true, needs := [f.id, "Missing"], entailment := none },
      { c with id := "\x00α", restates := true, needs := ["Missing", f.id], entailment := none },
      { c with restates := true, needs := [f.id], entailment := some "Shared" },
      { c with id := "Other", restates := false, entailment := some "Shared" }] ++ t.claims,
      facts := [{ f with id := "" }, { f with id := "\x00α" }, f] ++ t.facts }

private def idArgs (t : Trace) : List String :=
  (t.allIds ++ t.claims.flatMap (·.needsAll) ++ t.claims.filterMap (·.variantOf) ++
    t.facts.filterMap (·.instantiates) ++ t.experiments.flatMap (·.requires) ++
    t.subjects.filterMap (·.createdBy) ++ ["", "Missing", "Absent", "a|b", "\x00α"]).eraseDups

private def listArgs (ids : List String) : Gen (List (List String)) := do
  let mut out := [[], ids, ids.reverse, ["Missing"], [ids.headD "", "Missing", ids.headD ""]]
  for _ in [:4] do
    let mut xs := []
    for _ in [:(← draw 7)] do xs := xs ++ [← pick (ids ++ ["", "Missing"])]
    out := out ++ [xs]
  return out

private def arbitraryOverrides (ids : List String) : Gen Overrides := do
  let mut out := []
  for st in Status.all do out := out ++ [(← pick (ids ++ ["Missing", "Absent"]), st)]
  let repeated ← pick ids
  return (← shuffled out) ++ [(repeated, .assumed), ("Missing", .proved),
    (repeated, .violated), ("Absent", .checked), ("Missing", .«open»)]

private def current (salt : UInt64) (id : String) : Bool :=
  let h := id.toList.foldl (fun h c => h * 1099511628211 + UInt64.ofNat c.toNat) salt
  (h >>> 16).toNat % 3 != 0

private structure Context where
  trial : Nat
  salt : UInt64
  trace : Trace

private abbrev DiffM := StateT Nat TestM

private def same {α β : Type} [BEq α] [Repr α] [Repr β] (ctx : Context) (field : String) (arg : β)
    (got want : α) : DiffM Unit := do
  modify (· + 1)
  unless got == want do
    let t := ctx.trace
    check s!"differential {field}" false
      s!"seed={seed} trial={ctx.trial} salt={ctx.salt} size={t.allIds.length} \
        (subjects={t.subjects.length}, facts={t.facts.length}, claims={t.claims.length}, \
        experiments={t.experiments.length}, exclusions={t.exclusions.length}) \
        field={field} arg={repr arg} got={repr got} want={repr want}"

private def exclusionArgs (t : Trace) : List Exclusion :=
  t.exclusions ++ t.exclusions.map (fun x => { x with
    between := ("Missing", x.between.1),
    status := if x.status == .proved then .assumed else .proved, subject := "Missing" }) ++
  t.exclusions.map (fun x => { x with id := "Outside", between := x.between.swap })

private def compareLookups (ctx : Context) (got want : Lookups) : DiffM Unit := do
  let t := ctx.trace
  let ids := idArgs t
  for id in ids do
    same ctx "Lookups.fact?" id (got.fact? id) (want.fact? id)
    same ctx "Lookups.subject?" id (got.subject? id) (want.subject? id)
    same ctx "Lookups.claim?" id (got.claim? id) (want.claim? id)
    same ctx "Lookups.experiment?" id (got.experiment? id) (want.experiment? id)
    same ctx "Lookups.hasQuestion" id (got.hasQuestion id) (want.hasQuestion id)
    same ctx "Lookups.hasSubject" id (got.hasSubject id) (want.hasSubject id)
    same ctx "Lookups.hasFact" id (got.hasFact id) (want.hasFact id)
    same ctx "Lookups.hasClaim" id (got.hasClaim id) (want.hasClaim id)
    same ctx "Lookups.hasExperiment" id (got.hasExperiment id) (want.hasExperiment id)
    same ctx "Lookups.entailmentClaim?" id (got.entailmentClaim? id) (want.entailmentClaim? id)
    same ctx "Lookups.restatingClaim?" id (got.restatingClaim? id) (want.restatingClaim? id)
    for c in t.claimIds ++ ["Missing", ""] do
      same ctx "Lookups.soleEntailment" (id, c)
        (got.soleEntailment id c) (want.soleEntailment id c)
  same ctx "Lookups.idsNodup" () (got.idsNodup ()) (want.idsNodup ())
  same ctx "Lookups.duplicateIds" () (got.duplicateIds ()) (want.duplicateIds ())
  same ctx "Lookups.waiversNodup" () (got.waiversNodup ()) (want.waiversNodup ())
  let lists := sample ctx.salt (listArgs (t.factIds.take 5)) ++ t.claims.map (·.needs)
  for xs in lists do
    same ctx "Lookups.nodup" xs (got.nodup xs) (want.nodup xs)
    for c in t.claimIds ++ ["Missing", ""] do
      same ctx "Lookups.soleRestater" (xs, c) (got.soleRestater xs c) (want.soleRestater xs c)
  for i in List.range (t.experiments.length + 2) ++ [4294967296] do
    for e in t.experiments do
      for sub in [e.subject, "Missing"] do
        same ctx "Lookups.earlierExperiment" (i, e.id, sub)
          (got.earlierExperiment i e.id sub) (want.earlierExperiment i e.id sub)
    for sub in t.subjectIds ++ ["Missing"] do
      same ctx "Lookups.earlierExperiment" (i, "Missing", sub)
        (got.earlierExperiment i "Missing" sub) (want.earlierExperiment i "Missing" sub)
  for i in List.range (t.exclusions.length + 2) ++ [4294967296] do
    for x in exclusionArgs t do
      same ctx "Lookups.earlierPair" (i, x) (got.earlierPair i x) (want.earlierPair i x)
  for rule in (Check.lintRules ++ t.waivers.map (·.rule) ++ ["", "Missing"]).eraseDups do
    for c in (t.claimIds ++ t.waivers.map (·.claim) ++ ["", "Missing"]).eraseDups do
      same ctx "Lookups.waiver?" (rule, c) (got.waiver? rule c) (want.waiver? rule c)

private def claimArgs (t : Trace) : List Claim :=
  t.claims ++ t.claims.map (fun c => { c with
    needs := c.needs.reverse ++ ["Missing", "Missing"],
    entailment := none, subject := "Missing", text := c.text ++ " Outside.",
    restates := !c.restates }) ++
  (t.claims.take 1).map (fun c => { c with id := "Outside", needs := [], entailment := none })

private def factArgs (t : Trace) : List Fact :=
  t.facts ++ t.facts.map (fun f => { f with
    route := .humanRuling,
    kind := if f.kind.mustVerify then .statistical else .result, status := .violated,
    subject := "Missing", text := "Outside fact" }) ++
  (t.facts.take 1).map (fun f => { f with id := "Missing", route := .lean, kind := .result })

private def experimentArgs (t : Trace) : List Experiment :=
  t.experiments ++ t.experiments.map (fun e => { e with
    subject := "Missing",
    failure := [("Missing", .checked), ("R", .proved), ("R", .assumed)],
    success := [], requires := ["Absent"] }) ++
  (t.experiments.take 1).map (fun e => { e with id := "Outside", failure := [] })

private def compareAnswers (ctx : Context) (s : Scenario) (got want : Answers) : DiffM Unit := do
  let t := s.trace
  compareLookups ctx got.lookups want.lookups
  for id in idArgs t do
    same ctx "Answers.override?" id (got.override? id) (want.override? id)
    same ctx "Answers.eff" id (got.eff id) (want.eff id)
    same ctx "Answers.derivations" id (got.derivations id) (want.derivations id)
    same ctx "Answers.valid" id (got.valid id) (want.valid id)
    same ctx "Answers.conflicts" id (got.conflicts id) (want.conflicts id)
    same ctx "Answers.prospective" id (got.prospective id) (want.prospective id)
    same ctx "Answers.factText" id (got.factText id) (want.factText id)
    same ctx "Answers.isResult" id (got.isResult id) (want.isResult id)
    same ctx "Answers.claimsOn" id (got.claimsOn id) (want.claimsOn id)
    same ctx "Answers.raisers" id (got.raisers id) (want.raisers id)
  for f in factArgs t do
    same ctx "Answers.closable" f (got.closable f) (want.closable f)
  for x in exclusionArgs t do
    same ctx "Answers.active" x (got.active x) (want.active x)
  for c in claimArgs t do
    same ctx "Answers.final" c (got.final c) (want.final c)
    same ctx "Answers.intrinsic" c (got.intrinsic c) (want.intrinsic c)
    same ctx "Answers.sentence" c (got.sentence c) (want.sentence c)
    same ctx "Answers.verifiedNeeds" c (got.verifiedNeeds c) (want.verifiedNeeds c)
    same ctx "Answers.premises" c (got.premises c) (want.premises c)
    same ctx "Answers.gaps" c (got.gaps c) (want.gaps c)
    same ctx "Answers.blockers" c (got.blockers c) (want.blockers c)
    same ctx "Answers.incompatible" c (got.incompatible c) (want.incompatible c)
    same ctx "Answers.hypothetical" c (got.hypothetical c) (want.hypothetical c)
    same ctx "Answers.plan" c (got.plan c) (want.plan c)
    same ctx "Answers.planSummary" c (got.planSummary c) (want.planSummary c)
    for review in [Receipt.ReviewState.draft, .stale, .reviewed] do
      same ctx "Answers.qualifiers" (c, review) (got.qualifiers c review) (want.qualifiers c review)
  for e in experimentArgs t do
    same ctx "Answers.creates" e (got.creates e) (want.creates e)
    same ctx "Answers.failureMoves" e (got.failureMoves e) (want.failureMoves e)
  same ctx "Answers.work" () (got.work ()) (want.work ())
  same ctx "Answers.blockerFacts" () (got.blockerFacts ()) (want.blockerFacts ())
  same ctx "Answers.experimentOrder" () (got.experimentOrder ()) (want.experimentOrder ())
  same ctx "Answers.experimentRows" () (got.experimentRows ()) (want.experimentRows ())
  for ids in sample ctx.salt (listArgs (t.experimentIds ++ t.factIds.take 2)) do
    same ctx "Answers.closure" ids (got.closure ids) (want.closure ids)
    same ctx "Answers.merged" ids (got.merged ids) (want.merged ids)
    same ctx "Answers.raised" ids (got.raised ids) (want.raised ids)
    same ctx "Answers.successMoves" ids (got.successMoves ids) (want.successMoves ids)
  let extras := [[], s.overrides, s.overrides.reverse,
    sample (ctx.salt + 1) (arbitraryOverrides t.factIds)]
  for extra in extras do
    same ctx "Answers.withOverrides" extra (got.withOverrides extra) (want.withOverrides extra)
  let bindings := (t.factIds ++ t.exclusionIds).map fun id =>
    { id, current := s.current id,
      reasons := if s.current id then [] else ["statement-changed", "missing proof/result"] :
      Receipt.Binding }
  let review := ([Receipt.ReviewState.draft, .stale, .reviewed][ctx.trial % 3]?).getD .draft
  same ctx "envelopeWith" (s.overrides, review)
    (Evaluate.envelopeWith s got bindings "digest" review).canonical
    (Evaluate.envelopeWith s want bindings "digest" review).canonical

private def runCases : DiffM Unit := do
  let generated :=
    sample seed ((List.range (Route.all.length * Status.all.length)).mapM generatedTrace)
  let candidates := generated ++ [emptyTrace] ++ [0, 1, 20, 21].map boundaryTrace
  let mut kept := 0
  let mut scenarios := 0
  for (t, i) in candidates.zipIdx do
    let salt := seed + UInt64.ofNat i
    let ctx : Context := { trial := i, salt, trace := t }
    compareLookups ctx (Lookups.fast t) (Lookups.reference t)
    let errors := Check.violations t
    check s!"differential WF generator {i}" errors.isEmpty s!"seed={seed}: {repr errors}"
    if errors.isEmpty then
      kept := kept + 1
      let arbitrary := sample salt (arbitraryOverrides t.factIds)
      let overrides := [[], arbitrary, t.facts.map (fun f => (f.id, f.ceiling)),
        t.facts.map (fun f => (f.id, Status.assumed)) ++ arbitrary]
      for (o, j) in overrides.zipIdx do
        let scenarioSalt := salt + UInt64.ofNat j
        let s : Scenario := { trace := t, current := current scenarioSalt, overrides := o }
        compareAnswers { ctx with trial := i * 4 + j, salt := scenarioSalt }
          s (Answers.fast s) (Answers.reference s)
        scenarios := scenarios + 1
  let bad :=
    (generated.zipIdx.map fun (t, i) => malformed t i) ++ [{ emptyTrace with subjects := [] }]
  for (t, i) in bad.zipIdx do
    let ctx : Context :=
      { trial := candidates.length + i, salt := seed + UInt64.ofNat i, trace := t }
    check s!"differential malformed generator {i}" (!(Check.violations t).isEmpty)
    compareLookups ctx (Lookups.fast t) (Lookups.reference t)
  for kind in Kind.all do
    for route in Route.all do
      for status in Status.all do
        if (fact "Probe" "S0" kind route status).allows status then
          check s!"differential matrix {kind.name}/{route.name}/{status.name}"
            (generated.any fun t => t.facts.any fun f =>
              f.kind == kind && f.route == route && f.status == status)
  check "differential every WF candidate kept" (kept == candidates.length)
  IO.println s!"differential seed={seed} traces={candidates.length + bad.length} \
    kept={kept} malformed={bad.length} scenarios={scenarios} comparisons={← get}"

def tests : TestM Unit := do
  let (_, comparisons) ← runCases.run 0
  check "differential comparisons executed" (comparisons > 0)

end Tests.Differential
