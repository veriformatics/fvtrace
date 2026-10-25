import Fvtrace.Proofs.Walk

/-! `Answers.fast s = Answers.reference s` (`kernel.md` P-claims `AnswersAgree`), field by field
(`Fvtrace.Proofs.Answers`: indexes, cores, deltas, plans; `Fvtrace.Proofs.Walk`: the forest walk's
rows + plan summaries). -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false
set_option linter.unusedSectionVars false

namespace Fvtrace.Proofs.Answers
open Fvtrace Fvtrace.Answers Fvtrace.Proofs.Index Fvtrace.Proofs.Lookups
  Fvtrace.Proofs.Positions Fvtrace.Proofs.Walk

attribute [local instance] lexOrd

/-- The walk's rows, sorted once = the trace's reference rows, sorted once. -/
theorem sorted_walk (s : Scenario) (fb : Experiment → ExperimentRow)
    (fm : Experiment → List Scenario.Move) (hfb : fb = rowRefOf s)
    (hfm : ∀ e, fm e = s.moves (s.applyFailure e)) :
    (walk (cxOf s) s (coreOf s) (memoOf s) (Forest.build (cxOf s)) fb fm).1.toList.mergeSort
        rowBefore = (s.trace.experiments.map (rowRefOf s)).mergeSort rowBefore := by
  rw [(walk_eq s fb fm hfb hfm).1]

/-- The walk's rows, sorted once = the reference rows. -/
theorem rows_of_walk (s : Scenario) (fb : Experiment → ExperimentRow)
    (fm : Experiment → List Scenario.Move) (hfb : fb = rowRefOf s)
    (hfm : ∀ e, fm e = s.moves (s.applyFailure e)) :
    (walk (cxOf s) s (coreOf s) (memoOf s) (Forest.build (cxOf s)) fb fm).1.toList.mergeSort
        rowBefore =
      (s.trace.experiments.mergeSort (Evaluate.experimentBefore s)).map (rowRefOf s) := by
  rw [(walk_eq s fb fm hfb hfm).1]
  exact rows_eq s

/-- A claim's summary: the walk's where it answers it, else its plan's. -/
theorem summary_of_walk (s : Scenario) (fb : Experiment → ExperimentRow)
    (fm : Experiment → List Scenario.Move) (hfb : fb = rowRefOf s)
    (hfm : ∀ e, fm e = s.moves (s.applyFailure e)) (c : Claim) :
    (match (cxOf s).positionOf c with
      | some q => match (walk (cxOf s) s (coreOf s) (memoOf s) (Forest.build (cxOf s)) fb fm).2[q]?
          with
        | some (some sm) => sm
        | _ =>
          (planOf (cxOf s) ((cxOf s).closureWith (Forest.build (cxOf s))) s (coreOf s) c).summary
      | none =>
        (planOf (cxOf s) ((cxOf s).closureWith (Forest.build (cxOf s))) s (coreOf s) c).summary) =
      (s.plan c).summary := by
  have hgen :
      (planOf (cxOf s) ((cxOf s).closureWith (Forest.build (cxOf s))) s (coreOf s) c).summary =
      (s.plan c).summary := congrArg PlanResult.summary (plan_eq s _ (funext (closure_eq s)) c)
  split
  · rename_i q hq
    split
    · rename_i sm hsm
      obtain ⟨hql, hsum⟩ := (walk_eq s fb fm hfb hfm).2 q sm hsm
      obtain ⟨_, hc⟩ := positionOf_some s hq
      rw [hsum, hc]
    · exact hgen
  · exact hgen

theorem filter_pairs {β : Type} (l : List String) (f : String → β) (p : String × β → Bool) :
    ((l.map fun n => (n, f n)).filter p).map (·.1) = l.filter fun n => p (n, f n) := by
  induction l with
  | nil => rfl
  | cons a l ih =>
    simp only [List.map_cons, List.filter_cons]
    split <;> simp [ih]

theorem countP_pairs {β : Type} (l : List String) (f : String → β) (p : String × β → Bool) :
    (l.map fun n => (n, f n)).countP p = l.countP fun n => p (n, f n) := by
  rw [List.countP_map]; rfl

theorem any_pairs {β : Type} (l : List String) (f : String → β) (p : String × β → Bool) :
    (l.map fun n => (n, f n)).any p = l.any fun n => p (n, f n) := by
  rw [List.any_map]; rfl

/-- A claim's envelope member, each need's status read once = the reference's. -/
theorem view_eq (s : Scenario) (plan : PlanSummary) (c : Claim) (hp : plan = (s.plan c).summary) :
    viewWith (cxOf s) s (coreOf s) (baseOf s) s.prospective plan c =
      (Answers.reference s).claimView c := by
  have hbe : (baseOf s).eff = s.baseline.eff := base_eff s
  have hbv : Core.valid (baseOf s) = s.baseline.valid := base_valid s
  unfold viewWith
  simp only [Answers.reference]
  rw [eff_eq, mustVerify_eq, incompatible_eq, valid_eq, hbe, hbv, hp]
  have hint : (Counts.of s.eff s.restsOn c.needsAll).state (!(s.incompatible c).isEmpty) =
      s.intrinsic c := by
    rw [counts_state]; rfl
  have hcounts : needCounts (c.needsAll.map fun n => (n, s.eff n, s.mustVerify n)) =
      Counts.of s.eff s.restsOn c.needsAll := by
    unfold needCounts Counts.of
    rw [countP_pairs, countP_pairs, countP_pairs]
    rfl
  rw [hcounts, hint]
  have hchanged : (!s.overrides.isEmpty &&
      (((c.needsAll.map fun n => (n, s.eff n, s.mustVerify n)).any
        fun x => x.2.1 != s.baseline.eff x.1) ||
        s.valid c.subject != s.baseline.valid c.subject)) = s.changedByWhatif c := by
    unfold Scenario.changedByWhatif
    rw [any_pairs]
    cases ho : s.overrides.isEmpty
    · rfl
    · rw [baseline_self s ho]; simp
  rw [hchanged]
  congr 1 <;> first | exact filter_pairs _ _ _ | (unfold Scenario.final; rfl) | rfl

theorem answers_agree (s : Scenario) : Answers.fast s = Answers.reference s := by
  unfold Answers.fast Answers.reference
  dsimp only
  have hbe : (baseOf s).eff = s.baseline.eff := base_eff s
  have hbv : Core.valid (baseOf s) = s.baseline.valid := base_valid s
  have hrow : rowOf (fun ids => (cxOf s).closureWith (Forest.build (cxOf s)) ids) (cxOf s).merged
      (fun ids => movesUnder (cxOf s) s (coreOf s)
        (Thunk.mk fun _ => (cxOf s).claims.map (ClaimMemo.of (cxOf s) s (coreOf s)))
        (raisedBy (cxOf s) (coreOf s) ids))
      (fun e => movesUnder (cxOf s) s (coreOf s)
        (Thunk.mk fun _ => (cxOf s).claims.map (ClaimMemo.of (cxOf s) s (coreOf s)))
        (e.failure.map fun (k, _) => (k, .violated)))
      (coreOf s).override? (cxOf s).isResult = rowRefOf s := by
    congr 1
    · exact funext (closure_eq s)
    · exact merged_eq s
    · funext ids; rw [moves_eq, raised_eq]; rfl
    · funext e; rw [moves_eq]; rfl
    · funext id; exact override_eq s id
    · funext k; rw [isResult_eq]; rfl
  have hfail : ∀ e, movesUnder (cxOf s) s (coreOf s)
      (Thunk.mk fun _ => (cxOf s).claims.map (ClaimMemo.of (cxOf s) s (coreOf s)))
      (e.failure.map fun (k, _) => (k, .violated)) = s.moves (s.applyFailure e) := by
    intro e; rw [moves_eq]; rfl
  congr 1
  case e_lookups => exact ctx_L s.trace
  case e_override? => funext id; exact override_eq s id
  case e_eff => exact eff_eq s
  case e_derivations =>
    funext id
    show derive (cxOf s) s (coreOf s).eff1 id = s.derivations id
    rw [eff1_eq]; exact derive_eq s id
  case e_active => exact active_eq s
  case e_valid => exact valid_eq s
  case e_conflicts => exact conflicts_eq s
  case e_closable => funext f; exact closable_eq s f
  case e_final => exact final_eq s
  case e_intrinsic => exact intrinsic_eq s
  case e_sentence =>
    funext c
    unfold Scenario.sentence Scenario.sentenceParts
    rw [final_eq, eff_eq, premisesUnder_eq s s rfl, ctx_L]
    rfl
  case e_qualifiers =>
    funext c review
    unfold Scenario.qualifiers Scenario.changedByWhatif Scenario.prospective Scenario.creatorTitle
    rw [ctx_L, eff_eq, valid_eq, hbe, hbv]
    rfl
  case e_verifiedNeeds => funext c; unfold Scenario.verifiedNeeds; rw [eff_eq]
  case e_premises => funext c; rw [eff_eq]; exact premisesUnder_eq s s rfl c
  case e_gaps => funext c; rw [eff_eq]; exact gapsUnder_eq s s rfl c
  case e_blockers => funext c; unfold Scenario.blockers; rw [eff_eq]
  case e_incompatible => exact incompatible_eq s
  case e_hypothetical =>
    funext c
    unfold Scenario.hypothetical Scenario.changedByWhatif Scenario.prospective
    rw [ctx_L, eff_eq, valid_eq, hbe, hbv]
    rfl
  case e_prospective => funext sub; rw [ctx_L]; rfl
  case e_creates => funext e; rw [ctx_L]; rfl
  case e_factText => funext id; rw [ctx_L]; rfl
  case e_isResult => funext k; rw [isResult_eq]; rfl
  case e_claimsOn =>
    funext sub
    rw [claimSubject_group, ctx_claims, read_positions,
      zipIdx_filter_fst s.trace.claims (·.subject == sub)]
  case e_plan => funext c; exact plan_eq s _ (funext (closure_eq s)) c
  case e_work =>
    funext _
    simp only [closable_eq, gates_eq, unlocks_eq]
    exact work_eq s
  case e_blockerFacts =>
    funext _
    simp only [gates_eq, eff_eq]
    rfl
  case e_closure => funext ids; exact closure_eq s ids
  case e_merged => exact merged_eq s
  case e_raised => funext ids; exact raised_eq s ids
  case e_successMoves =>
    funext ids
    rw [moves_eq, raised_eq]
    rfl
  case e_failureMoves =>
    funext e
    rw [moves_eq]
    rfl
  case e_experimentOrder =>
    funext _
    exact (congrArg (List.map (·.experiment)) (sorted_walk s _ _ hrow hfail)).trans
      (experimentOrder_eq s)
  case e_withOverrides => funext extra; exact withOverrides_eq s extra
  case e_experimentRows =>
    funext _
    exact rows_of_walk s _ _ hrow hfail
  case e_planSummary =>
    funext c
    exact summary_of_walk s _ _ hrow hfail c
  case e_raisers =>
    funext f
    exact (congrArg (fun o => raisersWith (cxOf s) (coreOf s) (Forest.build (cxOf s))
        ((cxOf s).closureWith (Forest.build (cxOf s))) o f)
      ((congrArg (List.map (·.experiment)) (sorted_walk s _ _ hrow hfail)).trans
        (experimentOrder_eq s))).trans (raisersWith_eq s _ f)

  case e_claimView =>
    funext c
    have hpro : (fun sub => (((cxOf s).L.subject? sub).map (·.kind == .prospective)).getD false) =
        s.prospective := by funext sub; rw [ctx_L]; rfl
    rw [hpro]
    exact view_eq s _ c (summary_of_walk s _ _ hrow hfail c)

theorem answersAgree : Spec.AnswersAgree := answers_agree

end Fvtrace.Proofs.Answers
