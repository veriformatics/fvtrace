import Fvtrace.Present

/-!
# Answers (`.agent/contracts/kernel.md` P-shared)

Every engine answer the envelope + the CLI text read about one scenario, as one record of plain
functions. `reference` = the `Scenario` functions the guarantees (G1–G13) are about; `fast` = the
same answers from indexes + memos (`Fvtrace.Answers.Fast`). `Fvtrace.Proofs.Answers` proves the two
records equal for every scenario (`Spec.AnswersAgree`), so the envelope reads the same either way.
-/

namespace Fvtrace

/-- A claim's envelope member, its needs' statuses read once (`kernel.md` V-env): its states, need
lists, excluded pairs' count, whether the what-if moves it, its plan summary. -/
structure ClaimView where
  final : State
  intrinsic : State
  verified : List String
  premises : List String
  gaps : List String
  blockers : List String
  incompatibleCount : Nat
  /-- The what-if changes a need's status or the subject's consistency. -/
  changed : Bool
  /-- The claim's subject is consistent. -/
  valid : Bool
  hypothetical : Bool
  plan : PlanSummary
  deriving DecidableEq, Repr

structure Answers where
  /-- The trace's lookups. -/
  lookups : Lookups
  /-- The what-if's status for a fact id (its first entry). -/
  override? : String → Option Status
  eff : String → EStatus
  derivations : String → List (String × String)
  active : Exclusion → Bool
  valid : String → Bool
  conflicts : String → List String
  closable : Fact → Bool
  final : Claim → State
  intrinsic : Claim → State
  sentence : Claim → String
  qualifiers : Claim → Receipt.ReviewState → List String
  verifiedNeeds : Claim → List String
  premises : Claim → List String
  gaps : Claim → List String
  blockers : Claim → List String
  incompatible : Claim → List String
  hypothetical : Claim → Bool
  prospective : String → Bool
  creates : Experiment → Bool
  factText : String → String
  /-- The fact id names a `result` fact. -/
  isResult : String → Bool
  /-- The claims on a subject, in trace order. -/
  claimsOn : String → List Claim
  plan : Claim → PlanResult
  work : Unit → List Scenario.Work
  blockerFacts : Unit → List (String × List String)
  closure : List String → List String
  merged : List String → List (String × Status)
  raised : List String → Overrides
  /-- The moves of applying the successes of `ids` (closed). -/
  successMoves : List String → List Scenario.Move
  failureMoves : Experiment → List Scenario.Move
  /-- The experiments, most useful first (`Evaluate.experimentBefore`). -/
  experimentOrder : Unit → List Experiment
  /-- The complete what-if after `extra` (`Scenario.withOverrides`). -/
  withOverrides : Overrides → Overrides
  /-- Each experiment's row, in `experimentOrder` (`kernel.md` P-rows). -/
  experimentRows : Unit → List ExperimentRow
  /-- A claim's plan result kind + state (`kernel.md` V-env). -/
  planSummary : Claim → PlanSummary
  /-- The experiments, in `experimentOrder`, whose success closure raises a fact (V-details). -/
  raisers : String → List String
  /-- A claim's envelope member. -/
  claimView : Claim → ClaimView

namespace Answers

/-- An experiment's row from the answers it reads: its closure's success moves, its failure's,
whether the what-if already holds its success, whether that touches a `result` fact. -/
def rowOf (closure : List String → List String) (merged : List String → List (String × Status))
    (successMoves : List String → List Scenario.Move)
    (failureMoves : Experiment → List Scenario.Move) (override? : String → Option Status)
    (isResult : String → Bool) (e : Experiment) : ExperimentRow :=
  let cl := closure [e.id]
  let wins := successMoves cl
  let losses := if e.failure.isEmpty then [] else failureMoves e
  let m := merged cl
  { experiment := e, lights := Scenario.lights wins, clears := Scenario.clears wins,
    lowers := Scenario.lowers wins, breaks := Scenario.breaks losses,
    applied := m.all fun x => override? x.1 == some x.2,
    contingent := m.any fun x => isResult x.1 }

/-- The experiments of `order` whose success closure raises `f`, by id. -/
def raisersOf (order : List Experiment) (closure : List String → List String)
    (raised : List String → Overrides) (f : String) : List String :=
  (order.filter fun e => (raised (closure [e.id])).any (·.1 == f)).map (·.id)

/-- `Evaluate.experimentBefore` on rows: more lights, then more clears, then less effort, then the
smaller id. -/
def rowBefore (a b : ExperimentRow) : Bool :=
  let ea := Effort.all.idxOf a.experiment.effort
  let eb := Effort.all.idxOf b.experiment.effort
  a.lights > b.lights || (a.lights == b.lights && (a.clears > b.clears || (a.clears == b.clears &&
    (ea < eb || (ea == eb && a.experiment.id < b.experiment.id)))))

/-- The `Scenario` functions themselves. -/
def reference (s : Scenario) : Answers where
  lookups := Lookups.reference s.trace
  override? id := s.overrides.lookup id
  eff := s.eff
  derivations := s.derivations
  active := s.active
  valid := s.valid
  conflicts := s.conflicts
  closable := s.closable
  final := s.final
  intrinsic := s.intrinsic
  sentence := s.sentence
  qualifiers := s.qualifiers
  verifiedNeeds := s.verifiedNeeds
  premises := s.premises
  gaps := s.gaps
  blockers := s.blockers
  incompatible := s.incompatible
  hypothetical := s.hypothetical
  prospective := s.prospective
  creates := s.creates
  factText := s.factText
  isResult k := s.resultFacts.contains k
  claimsOn sub := s.trace.claims.filter (·.subject == sub)
  plan := s.plan
  work _ := s.work
  blockerFacts _ := s.blockerFacts
  closure := s.closure
  merged := s.merged
  raised := s.raised
  successMoves ids := s.moves (s.applySuccess ids)
  failureMoves e := s.moves (s.applyFailure e)
  experimentOrder _ := s.trace.experiments.mergeSort (Evaluate.experimentBefore s)
  withOverrides extra := (s.withOverrides extra).overrides
  experimentRows _ := (s.trace.experiments.mergeSort (Evaluate.experimentBefore s)).map
    (rowOf s.closure s.merged (fun ids => s.moves (s.applySuccess ids))
      (fun e => s.moves (s.applyFailure e)) (s.overrides.lookup ·) (s.resultFacts.contains ·))
  planSummary c := (s.plan c).summary
  raisers := raisersOf (s.trace.experiments.mergeSort (Evaluate.experimentBefore s)) s.closure
    s.raised
  claimView c :=
    { final := s.final c, intrinsic := s.intrinsic c, verified := s.verifiedNeeds c
      premises := s.premises c, gaps := s.gaps c, blockers := s.blockers c
      incompatibleCount := (s.incompatible c).length, changed := s.changedByWhatif c
      valid := s.valid c.subject, hypothetical := s.hypothetical c, plan := (s.plan c).summary }

end Answers

end Fvtrace
