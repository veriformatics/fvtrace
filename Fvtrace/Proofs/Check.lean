import Fvtrace.Spec.WellFormed

/-! Proofs of `Fvtrace.Spec.CheckAcceptsExactlyWellFormed` + `CheckViolationsSound`. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false

namespace Fvtrace.Proofs.Check
open Fvtrace Fvtrace.Check Fvtrace.Spec

theorem ensure_eq_nil {ok : Bool} {p m : String} : ensure ok p m = [] ↔ ok = true := by
  unfold ensure; cases ok <;> simp

theorem forall_zipIdx {α : Type} {l : List α} {P : α → Prop} :
    (∀ q ∈ l.zipIdx, P q.1) ↔ ∀ x ∈ l, P x := by
  constructor
  · intro h x hx
    have : x ∈ l.zipIdx.map Prod.fst := by rw [List.zipIdx_map_fst]; exact hx
    obtain ⟨q, hq, rfl⟩ := List.mem_map.mp this
    exact h q hq
  · intro h q hq
    exact h q.1 (List.fst_mem_of_mem_zipIdx hq)

/-- A per-element finding list over `zipIdx` is empty iff every element passes. -/
theorem flatMap_zipIdx_eq_nil {α β : Type} {l : List α} {g : α × Nat → List β} {P : α → Prop}
    (h : ∀ x i, g (x, i) = [] ↔ P x) : l.zipIdx.flatMap g = [] ↔ ∀ x ∈ l, P x := by
  rw [List.flatMap_eq_nil_iff]
  constructor
  · intro hg x hx
    have : x ∈ l.zipIdx.map Prod.fst := by rw [List.zipIdx_map_fst]; exact hx
    obtain ⟨q, hq, rfl⟩ := List.mem_map.mp this
    exact (h q.1 q.2).mp (hg q hq)
  · intro hp q hq
    exact (h q.1 q.2).mpr (hp q.1 (List.fst_mem_of_mem_zipIdx hq))

theorem ids_iff (t : Trace) : Check.ids t = [] ↔ IdsUnique t := by
  simp [Check.ids, ensure_eq_nil, IdsUnique]

theorem needs_iff (t : Trace) : Check.needs t = [] ↔ NeedsProper t := by
  unfold Check.needs NeedsProper
  rw [flatMap_zipIdx_eq_nil (P := fun c => c.needs ≠ [] ∧ c.needs.Nodup)]
  intro c i
  simp [ensure_eq_nil]

theorem kind_iff (t : Trace) : Check.kind t = [] ↔ KindsProper t := by
  unfold Check.kind KindsProper
  rw [flatMap_zipIdx_eq_nil (P := fun f => f.kind = .instantiation ↔ f.instantiates.isSome)]
  intro f i
  simp only [ensure_eq_nil]
  cases f.instantiates <;> cases f.kind <;> simp

theorem claimRefs_iff (t : Trace) (c : Claim) (i : Nat) : claimRefs t c i = [] ↔
    (c.question ∈ t.questionIds ∧ c.subject ∈ t.subjectIds ∧ (∀ n ∈ c.needs, n ∈ t.factIds) ∧
      c.entailment ∈ t.factIds ∧ ∀ v, c.variantOf = some v → v ∈ t.claimIds) := by
  unfold claimRefs
  cases c.variantOf <;> simp [ensure_eq_nil, List.flatMap_eq_nil_iff]

theorem factRefs_iff (t : Trace) (f : Fact) (i : Nat) : factRefs t f i = [] ↔
    (f.subject ∈ t.subjectIds ∧ ∀ s, f.instantiates = some s → s ∈ t.factIds) := by
  unfold factRefs
  cases f.instantiates <;> simp [ensure_eq_nil]

theorem experimentRefs_iff (t : Trace) (e : Experiment) (i : Nat) : experimentRefs t e i = [] ↔
    (e.subject ∈ t.subjectIds ∧ (∀ p ∈ e.success ++ e.failure, p.1 ∈ t.factIds) ∧
      ∀ r ∈ e.requires, r ∈ t.experimentIds) := by
  unfold experimentRefs
  simp [ensure_eq_nil, List.flatMap_eq_nil_iff, or_imp, forall_and, and_assoc]

theorem exclusionRefs_iff (t : Trace) (x : Exclusion) (i : Nat) : exclusionRefs t x i = [] ↔
    (x.subject ∈ t.subjectIds ∧ x.between.1 ∈ t.factIds ∧ x.between.2 ∈ t.factIds) := by
  unfold exclusionRefs
  simp [ensure_eq_nil]

theorem subjectRefs_iff (t : Trace) (s : Subject) (i : Nat) : subjectRefs t s i = [] ↔
    ∀ e, s.createdBy = some e → e ∈ t.experimentIds := by
  unfold subjectRefs
  cases s.createdBy <;> simp [ensure_eq_nil]

theorem waiverRefs_iff (t : Trace) (w : Waiver) (i : Nat) : waiverRefs t w i = [] ↔
    w.claim ∈ t.claimIds := by
  unfold waiverRefs
  simp [ensure_eq_nil]

theorem refs_iff (t : Trace) : Check.refs t = [] ↔ RefsResolve t := by
  unfold Check.refs RefsResolve
  simp only [List.append_eq_nil_iff]
  rw [flatMap_zipIdx_eq_nil (fun c i => claimRefs_iff t c i),
    flatMap_zipIdx_eq_nil (fun f i => factRefs_iff t f i),
    flatMap_zipIdx_eq_nil (fun e i => experimentRefs_iff t e i),
    flatMap_zipIdx_eq_nil (fun x i => exclusionRefs_iff t x i),
    flatMap_zipIdx_eq_nil (fun s i => subjectRefs_iff t s i),
    flatMap_zipIdx_eq_nil (fun w i => waiverRefs_iff t w i)]
  simp only [and_assoc]

/-- Index-aware variant: the per-element condition may depend on the position. -/
theorem flatMap_zipIdx_eq_nil_idx {α β : Type} {l : List α} {g : α × Nat → List β}
    {P : Nat → α → Prop} (h : ∀ x i, g (x, i) = [] ↔ P i x) :
    l.zipIdx.flatMap g = [] ↔ ∀ i (hi : i < l.length), P i l[i] := by
  rw [List.flatMap_eq_nil_iff]
  constructor
  · intro hg i hi
    have hmem : (l[i], i) ∈ l.zipIdx := by
      rw [List.mem_zipIdx_iff_getElem?]; simp
    exact (h _ _).mp (hg _ hmem)
  · intro hp q hq
    rw [List.mem_zipIdx_iff_getElem?] at hq
    obtain ⟨hi, heq⟩ := List.getElem?_eq_some_iff.mp hq
    have := hp q.2 hi
    rw [heq] at this
    exact (h q.1 q.2).mpr this

theorem onSubject_iff (t : Trace) (id s : String) : onSubject t id s = true ↔ OnSubject t id s := by
  unfold onSubject OnSubject
  cases h : t.factSubject? id <;> simp

theorem subject_iff (t : Trace) : Check.subject t = [] ↔ SubjectsAgree t := by
  unfold Check.subject SubjectsAgree
  simp only [List.append_eq_nil_iff]
  rw [flatMap_zipIdx_eq_nil (P := fun c => ∀ n ∈ c.needsAll, OnSubject t n c.subject)
      (fun c i => by simp [claimSubjects, ensure_eq_nil, List.flatMap_eq_nil_iff, onSubject_iff]),
    flatMap_zipIdx_eq_nil (P := fun e => ∀ p ∈ e.success ++ e.failure, OnSubject t p.1 e.subject)
      (fun e i => by
        simp [experimentSubjects, ensure_eq_nil, List.flatMap_eq_nil_iff, onSubject_iff, or_imp,
          forall_and]),
    flatMap_zipIdx_eq_nil
      (P := fun x => OnSubject t x.between.1 x.subject ∧ OnSubject t x.between.2 x.subject)
      (fun x i => by simp [exclusionSubjects, ensure_eq_nil, onSubject_iff]),
    flatMap_zipIdx_eq_nil (P := fun f => ∀ s, f.instantiates = some s → ∀ sub,
        t.factSubject? s = some sub → sub ≠ f.subject)
      (fun f i => by
        unfold instantiationSubject
        cases hf : f.instantiates with
        | none => simp
        | some s => cases h : t.factSubject? s <;> simp [ensure_eq_nil, h])]
  simp only [and_assoc]

theorem entailmentKind_iff (t : Trace) (id : String) :
    entailmentKind t id = true ↔ ∀ f, t.fact? id = some f → f.kind = .entailment := by
  unfold entailmentKind
  cases h : t.fact? id <;> simp

theorem needNotEntailment_iff (t : Trace) (id : String) :
    needNotEntailment t id = true ↔ ∀ f, t.fact? id = some f → f.kind ≠ .entailment := by
  unfold needNotEntailment
  cases h : t.fact? id <;> simp

theorem entailUnique_iff (t : Trace) (c : Claim) :
    (t.claims.all fun d => d.entailment != c.entailment || d.id == c.id) = true ↔
      ∀ d ∈ t.claims, d.entailment = c.entailment → d.id = c.id := by
  simp only [List.all_eq_true, Bool.or_eq_true, bne_iff_ne, ne_eq, beq_iff_eq]
  constructor
  · intro h d hd he
    rcases h d hd with h' | h'
    · exact absurd he h'
    · exact h'
  · intro h d hd
    by_cases he : d.entailment = c.entailment
    · exact Or.inr (h d hd he)
    · exact Or.inl he

theorem entail_iff (t : Trace) : Check.entail t = [] ↔ EntailmentsProper t := by
  unfold Check.entail EntailmentsProper
  rw [flatMap_zipIdx_eq_nil]
  intro c i
  simp only [claimEntail, List.append_eq_nil_iff, ensure_eq_nil, List.flatMap_eq_nil_iff,
    entailmentKind_iff, needNotEntailment_iff, entailUnique_iff, Bool.not_eq_true', and_assoc]
  simp

theorem route_iff (t : Trace) : Check.route t = [] ↔ RoutesRespected t := by
  unfold Check.route RoutesRespected
  simp only [List.append_eq_nil_iff]
  rw [flatMap_zipIdx_eq_nil (P := fun f => f.allows f.status = true)
      (fun f i => by simp [ensure_eq_nil]),
    flatMap_zipIdx_eq_nil (P := fun e => ∀ p ∈ e.success ++ e.failure, ∀ f, t.fact? p.1 = some f →
        f.allows p.2 = true)
      (fun e i => by
        unfold outcomeRoutes
        simp only [List.flatMap_eq_nil_iff]
        refine forall_congr' fun p => imp_congr_right fun _ => ?_
        cases t.fact? p.1 <;> simp [ensure_eq_nil]),
    flatMap_zipIdx_eq_nil (P := fun x => x.route.allows x.status = true)
      (fun x i => by simp [ensure_eq_nil])]
  simp only [and_assoc]

theorem outcome_iff (t : Trace) : Check.outcome t = [] ↔ OutcomesProper t := by
  unfold Check.outcome OutcomesProper
  simp only [List.append_eq_nil_iff]
  rw [flatMap_zipIdx_eq_nil (P := fun e => e.success ≠ [] ∧ (∀ p ∈ e.success, p.2.asserted = true) ∧
        ∀ p ∈ e.failure, p.2 = .violated)
      (fun e i => by simp [ensure_eq_nil, List.flatMap_eq_nil_iff]),
    flatMap_zipIdx_eq_nil_idx (P := fun i e => ∀ r ∈ e.requires,
        ∃ d ∈ t.experiments.take i, d.id = r ∧ d.subject = e.subject)
      (fun e i => by
        simp [requiresEarlier, ensure_eq_nil, List.flatMap_eq_nil_iff, List.any_eq_true])]

theorem receiptOk_iff (s : Status) (e : Option Evidence) :
    receiptOk s e = true ↔ ReceiptComplete s e := by
  unfold receiptOk ReceiptComplete
  cases hv : s.verified <;> cases e <;> simp [List.all_eq_true, and_assoc]

theorem receipt_iff (t : Trace) : Check.receipt t = [] ↔ ReceiptsComplete t := by
  unfold Check.receipt ReceiptsComplete
  simp only [List.append_eq_nil_iff]
  rw [flatMap_zipIdx_eq_nil (P := fun f => ReceiptComplete f.status f.evidence)
      (fun f i => by simp [ensure_eq_nil, receiptOk_iff]),
    flatMap_zipIdx_eq_nil (P := fun x => ReceiptComplete x.status x.evidence)
      (fun x i => by simp [ensure_eq_nil, receiptOk_iff])]

theorem path_iff (t : Trace) : Check.path t = [] ↔ PathsSafe t := by
  unfold Check.path PathsSafe
  simp [List.flatMap_eq_nil_iff, ensure_eq_nil, or_imp, forall_and, forall_exists_index, and_imp]

theorem subjectKind_iff (t : Trace) (id : String) (k : SubjectKind) :
    subjectKind t id k = true ↔ ∀ s, t.subject? id = some s → s.kind = k := by
  unfold subjectKind
  cases t.subject? id <;> simp

theorem prospective_iff (t : Trace) : Check.prospective t = [] ↔ SubjectsProper t := by
  unfold Check.prospective SubjectsProper
  simp only [List.append_eq_nil_iff]
  rw [flatMap_zipIdx_eq_nil (P := fun s => (s.kind = .prospective ↔ s.createdBy.isSome) ∧
        ∀ e, s.createdBy = some e → ∀ x, t.experiment? e = some x → x.subject = s.id)
      (fun s i => by
        unfold subjectProper
        cases hc : s.createdBy with
        | none => cases hk : s.kind <;> simp [ensure_eq_nil, hk]
        | some e =>
          cases hx : t.experiment? e <;> cases hk : s.kind <;> simp [ensure_eq_nil, hx, hk]),
    flatMap_zipIdx_eq_nil (P := fun f => ∀ s, t.subject? f.subject = some s →
        s.kind = .prospective → f.status = .«open»)
      (fun f i => by
        unfold prospectiveOpen
        cases hs : t.subject? f.subject with
        | none => simp [ensure_eq_nil]
        | some s => cases hk : s.kind <;> simp [ensure_eq_nil, hk])]
  simp [ensure_eq_nil, List.any_eq_true, and_assoc]

theorem variant_iff (t : Trace) : Check.variant t = [] ↔ VariantsProper t := by
  unfold Check.variant VariantsProper
  rw [flatMap_zipIdx_eq_nil]
  intro c i
  cases hv : c.variantOf with
  | none => simp [hv]
  | some v =>
    cases hd : t.claim? v <;> simp [ensure_eq_nil, subjectKind_iff, hd, hv]

theorem samePair_iff (x y : Exclusion) : samePair x y = true ↔
    (x.subject = y.subject ∧ (x.between = y.between ∨ x.between = y.between.swap)) := by
  simp [samePair]

theorem exclusion_iff (t : Trace) : Check.exclusion t = [] ↔ ExclusionsProper t := by
  unfold Check.exclusion ExclusionsProper
  simp only [List.append_eq_nil_iff]
  rw [flatMap_zipIdx_eq_nil (P := fun x => x.between.1 ≠ x.between.2)
      (fun x i => by simp [ensure_eq_nil]),
    flatMap_zipIdx_eq_nil_idx (P := fun i x => ∀ y ∈ t.exclusions.take i,
        ¬ (x.subject = y.subject ∧ (x.between = y.between ∨ x.between = y.between.swap)))
      (fun x i => by simp [ensure_eq_nil, List.any_eq_false, samePair_iff])]

theorem assertedFact_iff (t : Trace) (id : String) :
    assertedFact t id = true ↔ ∃ f, t.fact? id = some f ∧ f.status.asserted = true := by
  unfold assertedFact
  cases t.fact? id <;> simp

theorem consistent_iff (t : Trace) : Check.consistent t = [] ↔ RecordedConsistent t := by
  unfold Check.consistent RecordedConsistent
  rw [flatMap_zipIdx_eq_nil]
  intro x i
  simp only [ensure_eq_nil, Bool.not_eq_true', Bool.and_eq_false_iff, ← assertedFact_iff]
  cases x.status.asserted <;> cases assertedFact t x.between.1 <;>
    cases assertedFact t x.between.2 <;>
    simp

theorem waiver_iff (t : Trace) : Check.waiver t = [] ↔ WaiversProper t := by
  unfold Check.waiver WaiversProper
  simp only [List.append_eq_nil_iff]
  rw [flatMap_zipIdx_eq_nil (P := fun w => w.rule ∈ lintRules) (fun w i => by simp [ensure_eq_nil])]
  simp [ensure_eq_nil]

theorem rule_check_iff (r : Check.Rule) (t : Trace) : r.check t = [] ↔ Rule.Holds r t := by
  cases r
  · exact ids_iff t
  · exact refs_iff t
  · exact subject_iff t
  · exact entail_iff t
  · exact needs_iff t
  · exact route_iff t
  · exact outcome_iff t
  · exact receipt_iff t
  · exact path_iff t
  · exact prospective_iff t
  · exact variant_iff t
  · exact exclusion_iff t
  · exact consistent_iff t
  · exact waiver_iff t
  · exact kind_iff t

theorem violations_eq_nil (t : Trace) :
    violations t = [] ↔ ∀ r ∈ Check.Rule.all, Rule.Holds r t := by
  unfold violations
  simp only [List.flatMap_eq_nil_iff, List.map_eq_nil_iff]
  exact forall_congr' fun r => imp_congr_right fun _ => rule_check_iff r t

theorem checkAcceptsExactlyWellFormed : Spec.CheckAcceptsExactlyWellFormed := by
  intro t
  rw [violations_eq_nil]
  simp [Check.Rule.all, Rule.Holds, WellFormed]

theorem checkViolationsSound : Spec.CheckViolationsSound := by
  intro t v hv
  unfold violations at hv
  obtain ⟨r, _, hr⟩ := List.mem_flatMap.mp hv
  obtain ⟨⟨p, m⟩, hpm, rfl⟩ := List.mem_map.mp hr
  intro hholds
  have := (rule_check_iff r t).mpr hholds
  rw [this] at hpm
  simp at hpm

end Fvtrace.Proofs.Check
