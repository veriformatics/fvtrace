import Fvtrace.Present

/-!
# Answers (`.agent/contracts/kernel.md` P-shared)

Every engine answer the envelope + the CLI text read about one scenario, as one record of plain
functions. `reference` = the `Scenario` functions the guarantees (G1–G13) are about; `fast` = the
same answers from indexes + memos (`Fvtrace.Answers.Fast`). `Fvtrace.Proofs.Answers` proves the two
records equal for every scenario (`Spec.AnswersAgree`), so the envelope reads the same either way.
-/

namespace Fvtrace

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

namespace Answers

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

end Answers

end Fvtrace
