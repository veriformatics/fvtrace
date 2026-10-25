import Fvtrace.Proofs.Plan

open Fvtrace Fvtrace.Proofs.Plan

/-! A plan search over one relevant experiment (`kernel.md` P-plan-local): its candidate is that
experiment's closure, kept when the subject stays valid and the claim's rank rises; cost + id
comparisons against the empty plan drop out. -/

namespace Fvtrace.Proofs.Singleton

theorem closure_nil (s : Scenario) : s.closure [] = [] := by
  have hf : ∀ n, s.closureFuel n [] = [] := by
    intro n
    cases n <;> simp [Scenario.closureFuel, Scenario.closureStep]
  simp [Scenario.closure, hf]

theorem idsLt_nil (ids : List String) : idsLt ids [] = false := by
  cases ids <;> rfl

theorem better_empty (s : Scenario) (c : Claim) (ids : List String) :
    s.planBetter c ids [] =
      decide (((s.applySuccess ids).final c).rank > (s.final c).rank) := by
  simp [Scenario.planBetter, applySuccess_nil, costOf, lexLt, idsLt_nil]

theorem search_singleton (s : Scenario) (c : Claim) (r : String) :
    s.search c [] [r] [] =
      if (s.applySuccess (s.closure [r])).valid c.subject &&
          ((s.applySuccess (s.closure [r])).final c).rank > (s.final c).rank
      then s.closure [r] else [] := by
  rw [search_eq]
  simp only [leaves, sublists, List.map_cons, List.map_nil, List.nil_append]
  by_cases hb : s.valid c.subject = true <;>
    by_cases hv : (s.applySuccess (s.closure [r])).valid c.subject = true <;>
      simp [closure_nil, applySuccess_nil, hb, hv, step, better_empty]

end Fvtrace.Proofs.Singleton

