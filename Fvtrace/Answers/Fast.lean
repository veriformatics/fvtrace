import Fvtrace.Answers.Forest

/-!
# Fast answers (`.agent/contracts/kernel.md` P-delta)

`Answers.fast s` = the answers of `Answers.reference s`, read from sorted indexes (`Fvtrace.Index`)
+ memos instead of list scans. `Fvtrace.Proofs.Answers` proves the two records equal for every
scenario (`Spec.AnswersAgree`).
-/

namespace Fvtrace.Answers

/-- `Counts.of` over need triples (id, status, must verify). -/
def needCounts (ne : List (String × EStatus × Bool)) : Counts :=
  { violated := ne.countP (·.2.1 == .violated)
    unverified := ne.countP fun x => !x.2.1.verified
    unrested := ne.countP fun x => !(x.2.1.asserted && (!x.2.2 || x.2.1.verified)) }

/-- A claim's envelope member: each need's status + kind read once, its excluded pairs once; a
what-if-free scenario changes nothing (`kernel.md` V-env). -/
def viewWith (cx : Ctx) (s : Scenario) (core base : Core) (prospective : String → Bool)
    (plan : PlanSummary) (c : Claim) : ClaimView :=
  let ne := c.needsAll.map fun n => (n, core.eff n, cx.mustVerify n)
  let inc := Core.incompatible cx s c
  let intrinsic := (needCounts ne).state !inc.isEmpty
  let valid := core.valid c.subject
  let changed := !s.overrides.isEmpty && ((ne.any fun x => x.2.1 != base.eff x.1) ||
    valid != base.valid c.subject)
  { final := if valid then intrinsic else .cannot, intrinsic
    verified := (ne.filter (·.2.1.verified)).map (·.1)
    premises := (ne.filter fun x => x.2.1 == .assumed && !x.2.2).map (·.1)
    gaps := (ne.filter fun x => x.2.1.strength == 1 || (x.2.1 == .assumed && x.2.2)).map (·.1)
    blockers := (ne.filter (·.2.1 == .violated)).map (·.1)
    incompatibleCount := inc.length, changed, valid
    hypothetical := prospective c.subject || changed, plan }

/-- The same answers from indexes + memos. -/
def fast (s : Scenario) : Answers :=
  let t := s.trace
  let cx := Ctx.build t
  let core := Core.build cx s
  let base := if s.overrides.isEmpty then core else Core.build cx { s with overrides := [] }
  let memo := Thunk.mk fun _ => cx.claims.map (ClaimMemo.of cx s core)
  let forest := Thunk.mk fun _ => Forest.build cx
  let closure := fun ids => cx.closureWith forest.get ids
  let gates := fun (f : Fact) => (cx.gatePositions f.id).filterMap fun p =>
    (cx.claims[p]?).map (·.id)
  let closable := fun (f : Fact) =>
    let e := core.eff f.id
    e != .violated && e.strength < (EStatus.ofStatus f.ceiling).strength
  let premises := fun (c : Claim) => premisesUnder cx core.eff c.needsAll
  let factText := fun id => ((cx.L.fact? id).map (·.text)).getD id
  let final := Core.final cx s core
  let prospective := fun sub => ((cx.L.subject? sub).map (·.kind == .prospective)).getD false
  let changedByWhatif := fun (c : Claim) =>
    c.needsAll.any (fun n => core.eff n != base.eff n) ||
      core.valid c.subject != base.valid c.subject
  let successMoves := fun ids => movesUnder cx s core memo (raisedBy cx core ids)
  let failureMoves := fun (e : Experiment) =>
    movesUnder cx s core memo (e.failure.map fun (k, _) => (k, .violated))
  -- Each experiment's row once (the forest walk, or its closure on demand), sorted once: the order,
  -- the envelope + the raisers read the same rows; the walk answers the plans of the claims whose
  -- one relevant experiment lies on the forest.
  let batch := Thunk.mk fun _ => walk cx s core memo.get forest.get
    (rowOf closure cx.merged successMoves failureMoves core.override? cx.isResult) failureMoves
  let rows := Thunk.mk fun _ => batch.get.1.toList.mergeSort rowBefore
  let planSummary := fun c => match cx.positionOf c with
    | some q => match batch.get.2[q]? with
      | some (some sm) => sm
      | _ => (planOf cx closure s core c).summary
    | none => (planOf cx closure s core c).summary
  { lookups := cx.L
    override? := core.override?
    eff := core.eff
    derivations := core.derivations
    active := core.active
    valid := core.valid
    conflicts := core.conflicts
    closable
    final
    intrinsic := Core.intrinsic cx s core
    sentence := fun c => String.join (Scenario.sentenceWith (final c) (premises c) factText c)
    qualifiers := fun c review =>
      Scenario.qualifiersWith (changedByWhatif c) review
        (if prospective c.subject then
          Scenario.creatorTitleWith cx.L.subject? cx.L.experiment? c.subject
        else none)
        (core.valid c.subject)
    verifiedNeeds := fun c => c.needsAll.filter fun n => (core.eff n).verified
    premises
    gaps := fun c => gapsUnder cx core.eff c.needsAll
    blockers := fun c => c.needsAll.filter fun n => core.eff n == .violated
    incompatible := Core.incompatible cx s
    hypothetical := fun c => prospective c.subject || changedByWhatif c
    prospective
    creates := fun e => (cx.L.subject? e.subject).any (·.createdBy == some e.id)
    factText
    isResult := cx.isResult
    claimsOn := fun sub => (cx.claimSubject.group (cmp := compare) sub).filterMap (cx.claims[·]?)
    plan := planOf cx closure s core
    work := fun _ =>
      let rows := t.facts.filterMap fun f =>
        let g := gates f
        if closable f && !g.isEmpty then
          some (({ fact := f.id, unlocks := unlocksOf cx s core memo f, gates := g } :
            Scenario.Work))
        else none
      ((rows.map fun w => (w.unlocks.length, w.gates.length, w)).mergeSort
        fun a b => !workKeyBefore b a).map (·.2.2)
    blockerFacts := fun _ => (t.facts.filter fun f => core.eff f.id == .violated).map fun f =>
      (f.id, gates f)
    closure
    merged := cx.merged
    raised := raisedBy cx core
    successMoves
    failureMoves
    experimentOrder := fun _ => rows.get.map (·.experiment)
    withOverrides := fun extra =>
      let ex := Index.ofKeys compare (extra.map (·.1))
      extra ++ s.overrides.filter fun (k, _) => (ex.first? (cmp := compare) k).isNone
    experimentRows := fun _ => rows.get
    planSummary
    raisers := fun f => raisersWith cx core forest.get closure (rows.get.map (·.experiment)) f
    claimView := fun c => viewWith cx s core base prospective (planSummary c) c }

end Fvtrace.Answers
