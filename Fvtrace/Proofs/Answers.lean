import Fvtrace.Proofs.Positions
import Fvtrace.Proofs.Forest
import Fvtrace.Proofs.Plan

/-! `Answers.fast s = Answers.reference s` (`kernel.md` P-claims `AnswersAgree`), field by field:
the trace's indexes answer as its lists (`Ctx`), the memoized statuses + validity as the
`Scenario` functions (`Core`), a what-if delta as the scenario under its overrides (`Delta`),
then each record field. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false
set_option linter.unusedSectionVars false

namespace Fvtrace.Proofs.Answers
open Fvtrace Fvtrace.Answers Fvtrace.Proofs.Index Fvtrace.Proofs.Lookups
  Fvtrace.Proofs.Positions

attribute [local instance] lexOrd

/-! ## Index answers over a list -/

section Groups

variable {α : Type}

theorem first?_pos {l : List α} {key : α → String} {k : String} {p : Nat}
    (h : (Index.ofKeys compare (l.map key)).first? (cmp := compare) k = some p) :
    ∃ hp : p < l.length, key l[p] = k := by
  rw [first?_map, List.findIdx?_eq_some_iff_getElem] at h
  obtain ⟨hp, hk, _⟩ := h
  exact ⟨hp, by simpa using hk⟩

theorem filter_beq_nodup {κ : Type} [BEq κ] [LawfulBEq κ] {l : List κ} (hnd : l.Nodup) (k : κ) :
    l.filter (· == k) = if k ∈ l then [k] else [] := by
  induction l with
  | nil => simp
  | cons a as ih =>
    rw [List.nodup_cons] at hnd
    by_cases ha : a = k
    · subst ha
      rw [List.filter_cons, ih hnd.2]
      simp [hnd.1]
    · rw [List.filter_cons, ih hnd.2]
      have : (a == k) = false := by simpa using ha
      have hka : ¬ k = a := fun h => ha h.symm
      simp [this, hka]

theorem flatMap_single {β γ : Type} (L : List β) (P : β → Bool) (f : β → γ) :
    L.flatMap (fun y => if P y then [f y] else []) = (L.filter P).map f := by
  induction L with
  | nil => rfl
  | cons y ys ih => cases h : P y <;> simp [h, ih, List.filter_cons]

/-- Keys per item, each item's keys distinct: the positions of the items carrying `k`. -/
theorem group_flat {κ : Type} [Ord κ] [Std.TransOrd κ] [Std.LawfulEqOrd κ] [BEq κ] [LawfulBEq κ]
    (l : List α) (keys : α → List κ) (hnd : ∀ x, (keys x).Nodup) (k : κ) :
    (Index.build compare (l.zipIdx.flatMap fun x => (keys x.1).map (·, x.2))).group
        (cmp := compare) k =
      (l.zipIdx.filter fun x => decide (k ∈ keys x.1)).map (·.2) := by
  rw [group_build, List.filter_flatMap, List.map_flatMap]
  have : ∀ x : α × Nat, (((keys x.1).map (·, x.2)).filter (Is compare k)).map (·.2) =
      if decide (k ∈ keys x.1) then [x.2] else [] := by
    intro x
    rw [List.filter_map, List.map_map]
    have hf : ((keys x.1).filter (Is compare k ∘ fun y => (y, x.2))) =
        (keys x.1).filter (· == k) := by
      apply List.filter_congr; intro y _; simp [Is, cmp_beq]
    rw [hf, filter_beq_nodup (hnd x.1)]
    by_cases hk : k ∈ keys x.1 <;> simp [hk]
  simp only [this]
  exact flatMap_single _ _ _

/-- zipIdx positions increase. -/
theorem zipIdx_increasing (l : List α) : l.zipIdx.Pairwise fun a b => a.2 < b.2 := by
  have := (List.pairwise_lt_range (n := l.length))
  rw [List.range_eq_range', ← List.zipIdx_map_snd 0 l, List.pairwise_map] at this
  exact this

theorem mem_zipIdx_lt {l : List α} {x : α × Nat} (h : x ∈ l.zipIdx) : x.2 < l.length :=
  (List.mem_zipIdx' (x := x.1) (i := x.2) h).1

/-- Keys per item with repeats: the group lists a position once per repeat; deduplicated, the
positions of the items carrying `k`. -/
theorem group_multi (l : List α) (keys : α → List String) (k : String) :
    dedupSorted ((Index.build compare (l.zipIdx.flatMap fun x => (keys x.1).map (·, x.2))).group
        (cmp := compare) k) =
      (l.zipIdx.filter fun x => decide (k ∈ keys x.1)).map (·.2) := by
  rw [group_build, List.filter_flatMap, List.map_flatMap]
  have hE : (l.zipIdx.flatMap fun a =>
      (((keys a.1).map (·, a.2)).filter (Is compare k)).map (·.2)) =
      l.zipIdx.flatMap fun a => ((keys a.1).filter (· == k)).map fun _ => a.2 := by
    congr 1; funext a
    rw [List.filter_map, List.map_map]
    congr 1
    apply List.filter_congr; intro y _; simp [Is, cmp_beq]
  rw [hE]
  have hmem : ∀ i, i ∈ (l.zipIdx.flatMap fun a => ((keys a.1).filter (· == k)).map fun _ => a.2) ↔
      ∃ x ∈ l.zipIdx, x.2 = i ∧ k ∈ keys x.1 := by
    intro i
    simp only [List.mem_flatMap, List.mem_map, List.mem_filter, beq_iff_eq]
    constructor
    · rintro ⟨x, hx, y, ⟨hy, rfl⟩, rfl⟩
      exact ⟨x, hx, rfl, hy⟩
    · rintro ⟨x, hx, rfl, hk⟩
      exact ⟨x, hx, k, ⟨hk, rfl⟩, rfl⟩
  have hsorted : (l.zipIdx.flatMap fun a => ((keys a.1).filter (· == k)).map fun _ => a.2).Pairwise
      (· ≤ ·) := by
    rw [List.pairwise_flatMap]
    refine ⟨fun x _ => ?_, ?_⟩
    · apply List.pairwise_of_forall_mem_list
      intro a ha b hb
      simp only [List.mem_map] at ha hb
      obtain ⟨_, _, rfl⟩ := ha
      obtain ⟨_, _, rfl⟩ := hb
      exact Nat.le_refl _
    · refine (zipIdx_increasing l).imp fun hab => ?_
      intro a ha b hb
      simp only [List.mem_map] at ha hb
      obtain ⟨_, _, rfl⟩ := ha
      obtain ⟨_, _, rfl⟩ := hb
      exact Nat.le_of_lt hab
  rw [dedupSorted_eq_range (n := l.length) hsorted (fun i hi => by
    obtain ⟨x, hx, rfl, _⟩ := (hmem i).mp hi; exact mem_zipIdx_lt hx)]
  rw [range_filter_eq]
  congr 1
  apply List.filter_congr
  intro x hx
  rw [Bool.eq_iff_iff, decide_eq_true_iff, decide_eq_true_iff, hmem]
  constructor
  · rintro ⟨y, hy, hyx, hk⟩
    have h1 := (List.mem_zipIdx' (x := y.1) (i := y.2) hy).2
    have h2 := (List.mem_zipIdx' (x := x.1) (i := x.2) hx).2
    have : y.1 = x.1 := by rw [h1, h2]; congr 1
    rw [← this]; exact hk
  · intro hk; exact ⟨x, hx, rfl, hk⟩

theorem eraseDups_nodup {β : Type} [BEq β] [LawfulBEq β] (l : List β) : l.eraseDups.Nodup := by
  rw [eraseDups_eq_filter, List.Nodup, List.pairwise_map]
  have hz := (zipIdx_increasing l).sublist
    (List.filter_sublist (p := fun p => !(l.take p.2).contains p.1))
  refine hz.imp_of_mem ?_
  intro a b ha hb hab heq
  have hbk := (List.mem_filter.mp hb).2
  have ha' := (List.mem_filter.mp ha).1
  obtain ⟨halt, haeq⟩ := List.mem_zipIdx' (x := a.1) (i := a.2) ha'
  have hblt := (List.mem_zipIdx' (x := b.1) (i := b.2) (List.mem_filter.mp hb).1).1
  have : b.1 ∈ l.take b.2 := by
    rw [← heq, haeq]
    exact List.mem_take_iff_getElem.mpr ⟨a.2, Nat.lt_min.mpr ⟨hab, halt⟩, rfl⟩
  simp only [Bool.not_eq_eq_eq_not, Bool.not_true, List.contains_iff_mem] at hbk
  exact absurd this (by simpa using hbk)

end Groups

/-! ## The trace, indexed (`Ctx.build`) -/

section Ctx

variable (t : Trace)

theorem ctx_L : (Ctx.build t).L = Lookups.reference t := fast_eq_reference t

@[simp] theorem ctx_facts : (Ctx.build t).facts = t.facts.toArray := rfl
@[simp] theorem ctx_subjects : (Ctx.build t).subjects = t.subjects.toArray := rfl
@[simp] theorem ctx_claims : (Ctx.build t).claims = t.claims.toArray := rfl
@[simp] theorem ctx_experiments : (Ctx.build t).experiments = t.experiments.toArray := rfl
@[simp] theorem ctx_exclusions : (Ctx.build t).exclusions = t.exclusions.toArray := rfl
@[simp] theorem ctx_entries :
    (Ctx.build t).entries = ((successEntries t).map (·.2)).toArray := rfl

theorem endpoints_nodup (x : Exclusion) : (endpoints x).Nodup := by
  unfold endpoints
  split
  · simp
  · rename_i h
    simp only [List.nodup_cons, List.mem_cons, List.mem_nil_iff, or_false, List.not_mem_nil,
      not_false_eq_true, List.nodup_nil, and_true]
    intro he; exact h (by simp [he])

theorem mem_endpoints (x : Exclusion) (id : String) :
    id ∈ endpoints x ↔ x.between.1 = id ∨ x.between.2 = id := by
  unfold endpoints
  split
  · rename_i h
    simp only [beq_iff_eq] at h
    simp only [List.mem_cons, List.mem_nil_iff, or_false]
    constructor
    · intro h'; exact Or.inl h'.symm
    · rintro (h' | h')
      · exact h'.symm
      · rw [← h', h]
  · simp only [List.mem_cons, List.mem_nil_iff, or_false]
    constructor
    · rintro (h' | h')
      · exact Or.inl h'.symm
      · exact Or.inr h'.symm
    · rintro (h' | h')
      · exact Or.inl h'.symm
      · exact Or.inr h'.symm

theorem exclAt_group (id : String) :
    (Ctx.build t).exclAt.group (cmp := compare) id =
      (t.exclusions.zipIdx.filter fun x => decide (id ∈ endpoints x.1)).map (·.2) :=
  group_flat t.exclusions endpoints endpoints_nodup id

theorem exclSubject_group (sub : String) :
    (Ctx.build t).exclSubject.group (cmp := compare) sub =
      (t.exclusions.zipIdx.filter fun x => x.1.subject == sub).map (·.2) :=
  group_map t.exclusions (·.subject) sub

theorem exclFirst_group (n : String) :
    (Ctx.build t).exclFirst.group (cmp := compare) n =
      (t.exclusions.zipIdx.filter fun x => x.1.between.1 == n).map (·.2) :=
  group_map t.exclusions (·.between.1) n

theorem gatePositions_eq (id : String) :
    (Ctx.build t).gatePositions id =
      (t.claims.zipIdx.filter fun x => decide (id ∈ x.1.needsAll)).map (·.2) :=
  group_multi t.claims (·.needsAll) id

theorem claimSubject_group (sub : String) :
    (Ctx.build t).claimSubject.group (cmp := compare) sub =
      (t.claims.zipIdx.filter fun x => x.1.subject == sub).map (·.2) :=
  group_map t.claims (·.subject) sub

theorem isResult_eq (k : String) :
    (Ctx.build t).isResult k =
      (Scenario.resultFacts { trace := t, current := fun _ => true }).contains k := by
  show ((Index.ofKeys compare ((t.facts.filter (·.kind == .result)).map (·.id))).first?
    (cmp := compare) k).isSome = _
  rw [mem_map]
  rfl

theorem gateList_eq (id : String) :
    gateList (Ctx.build t).gates id =
      (t.claims.zipIdx.filter fun x => decide (id ∈ x.1.needsAll)).map (·.2) :=
  gatePositions_eq t id

/-- The positions of `l` passing `q` (read on the item). -/
theorem positions_nodup {α : Type} (l : List α) (q : α × Nat → Bool) :
    ((l.zipIdx.filter q).map (·.2)).Nodup := by
  have := ((zipIdx_increasing l).sublist (List.filter_sublist (p := q)))
  rw [List.Nodup, List.pairwise_map]
  exact this.imp Nat.ne_of_lt

theorem sum_at {α : Type} (f : α → Nat) (p : Nat) :
    ∀ (l : List α) (n : Nat), ((l.zipIdx n).map fun x => if x.2 == p then f x.1 else 0).sum =
      if n ≤ p then ((l[p - n]?).map f).getD 0 else 0
  | [], n => by simp
  | y :: ys, n => by
    rw [List.zipIdx_cons, List.map_cons, List.sum_cons, sum_at f p ys (n + 1)]
    by_cases h : n = p
    · subst h
      simp [show ¬ n + 1 ≤ n by omega]
    · have hb : (n == p) = false := by simpa using h
      simp only [hb, Bool.false_eq_true, ↓reduceIte, Nat.zero_add]
      by_cases hle : n ≤ p
      · have hlt : n + 1 ≤ p := by omega
        simp only [hlt, hle, ↓reduceIte]
        have : p - n = (p - (n + 1)) + 1 := by omega
        rw [this, List.getElem?_cons_succ]
      · have : ¬ n + 1 ≤ p := by omega
        simp [hle, this]

theorem needCount_count (b : String) (p : Nat) :
    (Ctx.build t).needCount.count (cmp := compare) (b, p) =
      ((t.claims[p]?).map fun c => c.needsAll.count b).getD 0 := by
  show (Index.build compare (t.claims.zipIdx.flatMap fun x =>
      x.1.needsAll.map fun n => ((n, x.2), x.2))).count (cmp := compare) (b, p) = _
  rw [count_build, ← List.countP_eq_length_filter, List.countP_flatMap]
  have : ∀ x : Claim × Nat, (x.1.needsAll.map fun n => ((n, x.2), x.2)).countP (Is compare (b, p)) =
      if x.2 == p then x.1.needsAll.count b else 0 := by
    intro x
    rw [List.countP_map, List.count_eq_length_filter, ← List.countP_eq_length_filter]
    by_cases hp : x.2 = p
    · simp only [hp, beq_self_eq_true, ↓reduceIte]
      apply List.countP_congr
      intro n _
      simp [Is, cmp_beq, hp]
    · have : (x.2 == p) = false := by simpa using hp
      simp only [this, Bool.false_eq_true, ↓reduceIte]
      rw [List.countP_eq_zero]
      intro n _ h
      simp only [Function.comp_apply, Is, cmp_beq, beq_iff_eq, Prod.mk.injEq] at h
      exact hp h.2
  simp only [Function.comp_def, this]
  rw [sum_at (fun c => c.needsAll.count b) p t.claims 0]
  simp

theorem mem_needingBoth (a b : String) (p : Nat) :
    p ∈ needingBoth (Ctx.build t).gates (Ctx.build t).needCount a b ↔
      ∃ h : p < t.claims.length, a ∈ t.claims[p].needsAll ∧ b ∈ t.claims[p].needsAll := by
  unfold needingBoth
  have hc : ∀ (n : String) (q : Nat) (hq : q < t.claims.length),
      ((Ctx.build t).needCount.count (cmp := compare) (n, q) > 0 ↔ n ∈ t.claims[q].needsAll) := by
    intro n q hq
    rw [needCount_count]
    simp [List.getElem?_eq_getElem hq, List.count_pos_iff]
  split
  · rw [List.mem_filter, gateList_eq,
      mem_positions (q := fun (c : Claim) => decide (a ∈ c.needsAll))]
    constructor
    · rintro ⟨⟨hp, ha⟩, hb⟩
      exact ⟨hp, by simpa using ha, (hc b p hp).mp (by simpa using hb)⟩
    · rintro ⟨hp, ha, hb⟩
      exact ⟨⟨hp, by simpa using ha⟩, by simpa using (hc b p hp).mpr hb⟩
  · rw [List.mem_filter, gateList_eq,
      mem_positions (q := fun (c : Claim) => decide (b ∈ c.needsAll))]
    constructor
    · rintro ⟨⟨hp, hb⟩, ha⟩
      exact ⟨hp, (hc a p hp).mp (by simpa using ha), by simpa using hb⟩
    · rintro ⟨hp, ha, hb⟩
      exact ⟨⟨hp, by simpa using hb⟩, by simpa using (hc a p hp).mpr ha⟩

theorem needingBoth_nodup (a b : String) :
    (needingBoth (Ctx.build t).gates (Ctx.build t).needCount a b).Nodup := by
  unfold needingBoth
  split <;> exact (List.Nodup.sublist List.filter_sublist (by
    rw [gateList_eq]; exact positions_nodup _ _))

theorem bothNeeded_group (p : Nat) :
    (Ctx.build t).bothNeeded.group (cmp := compare) p =
      (t.exclusions.zipIdx.filter fun x => decide (p ∈ needingBoth (Ctx.build t).gates
        (Ctx.build t).needCount x.1.between.1 x.1.between.2)).map (·.2) :=
  group_flat t.exclusions (fun x => needingBoth (Ctx.build t).gates (Ctx.build t).needCount
    x.between.1 x.between.2) (fun _ => needingBoth_nodup t _ _) p

end Ctx

/-! ## One scenario, memoized (`Core.build`) -/

theorem find_lookup {β : Type} (l : List (String × β)) (k : String) :
    (l.find? (·.1 == k)).map (·.2) = l.lookup k := by
  induction l with
  | nil => rfl
  | cons x xs ih =>
    obtain ⟨a, v⟩ := x
    by_cases h : a = k
    · subst h; simp [List.lookup]
    · have h1 : (a == k) = false := by simpa using h
      have h2 : (k == a) = false := by simpa using fun e => h e.symm
      simp [List.find?_cons, h1, List.lookup, h2, ih]

section Core

variable (s : Scenario)

/-- The scenario's fast pieces. -/
abbrev cxOf : Ctx := Ctx.build s.trace
abbrev coreOf : Core := Core.build (cxOf s) s

theorem override_eq (id : String) : (coreOf s).override? id = s.overrides.lookup id := by
  show (((Index.ofKeys compare (s.overrides.map (·.1))).first? (cmp := compare) id).bind
    (s.overrides.toArray[·]?)).map (·.2) = _
  rw [find?_map, find_lookup]

theorem eff1_eq : (coreOf s).eff1 = s.eff1 := by
  funext id
  show (match (coreOf s).override? id with
    | some st => EStatus.ofStatus st
    | none => match (cxOf s).L.fact? id with
      | some f => s.eff0 f.status f.id
      | none => .«open») = _
  rw [override_eq, ctx_L]
  rfl

theorem derive_eq (id : String) : derive (cxOf s) s s.eff1 id = s.derivations id := by
  unfold derive Scenario.derivations
  rw [exclAt_group, ← List.filterMap_filterMap]
  show (((s.trace.exclusions.zipIdx.filter fun x => decide (id ∈ endpoints x.1)).map
    (·.2)).filterMap (s.trace.exclusions.toArray[·]?)).filterMap _ = _
  rw [read_positions, filterMap_positions]
  intro x _ hsome
  simp only [decide_eq_true_eq, mem_endpoints]
  by_cases h1 : x.1.between.1 = id
  · exact Or.inl h1
  · by_cases h2 : x.1.between.2 = id
    · exact Or.inr h2
    · exfalso
      have e1 : (x.1.between.1 == id) = false := by simpa using h1
      have e2 : (x.1.between.2 == id) = false := by simpa using h2
      revert hsome
      split <;> simp [e1, e2]

theorem effAt_eq (id : String) :
    (if (derive (cxOf s) s (coreOf s).eff1 id).isEmpty then (coreOf s).eff1 id else .violated) =
      s.eff id := by
  rw [eff1_eq, derive_eq]
  rfl

theorem eff_eq : (coreOf s).eff = s.eff := by
  funext id
  show (match (cxOf s).factIx.first? (cmp := compare) id with
    | some p => ((cxOf s).facts.map fun (f : Fact) =>
        if (derive (cxOf s) s (coreOf s).eff1 f.id).isEmpty then (coreOf s).eff1 f.id
        else .violated)[p]?.getD
          (if (derive (cxOf s) s (coreOf s).eff1 id).isEmpty then (coreOf s).eff1 id else .violated)
    | none => if (derive (cxOf s) s (coreOf s).eff1 id).isEmpty then (coreOf s).eff1 id
        else .violated) = _
  split
  · rename_i p hp
    obtain ⟨hlt, hid⟩ := first?_pos hp
    simp only [cxOf, ctx_facts, Array.getElem?_map, List.getElem?_toArray,
      List.getElem?_eq_getElem hlt, Option.map_some, Option.getD_some]
    rw [hid]
    exact effAt_eq s id
  · exact effAt_eq s id

theorem active_eq : (coreOf s).active = s.active := by
  funext x
  show activeWith s (coreOf s).eff1 x = _
  rw [eff1_eq]
  rfl

theorem onSubject_eq (sub : String) :
    (((cxOf s).exclSubject.group (cmp := compare) sub).filterMap ((cxOf s).exclusions[·]?)).filter
      (fun x => x.subject == sub && activeWith s (coreOf s).eff1 x) =
      s.trace.exclusions.filter fun x => x.subject == sub && s.active x := by
  rw [exclSubject_group]
  show ((((s.trace.exclusions.zipIdx.filter fun x => x.1.subject == sub).map (·.2)).filterMap
    (s.trace.exclusions.toArray[·]?)).filter _) = _
  rw [read_positions, filter_positions, eff1_eq]
  · rfl
  · intro x _ h
    simp only [Bool.and_eq_true] at h
    exact h.1

theorem conflicts_eq : (coreOf s).conflicts = s.conflicts := by
  funext sub
  show (match (cxOf s).subjectIx.first? (cmp := compare) sub with
    | some p => ((cxOf s).subjects.map fun (x : Subject) =>
        ((((cxOf s).exclSubject.group (cmp := compare) x.id).filterMap
          ((cxOf s).exclusions[·]?)).filter (fun (e : Exclusion) => e.subject == x.id &&
            activeWith s (coreOf s).eff1 e)).map (fun (e : Exclusion) => e.id))[p]?.getD
        (((((cxOf s).exclSubject.group (cmp := compare) sub).filterMap
          ((cxOf s).exclusions[·]?)).filter (fun (e : Exclusion) => e.subject == sub &&
            activeWith s (coreOf s).eff1 e)).map (fun (e : Exclusion) => e.id))
    | none => ((((cxOf s).exclSubject.group (cmp := compare) sub).filterMap
          ((cxOf s).exclusions[·]?)).filter (fun (e : Exclusion) => e.subject == sub &&
            activeWith s (coreOf s).eff1 e)).map (fun (e : Exclusion) => e.id)) = _
  unfold Scenario.conflicts
  split
  · rename_i p hp
    obtain ⟨hlt, hid⟩ := first?_pos hp
    simp only [cxOf, ctx_subjects, Array.getElem?_map, List.getElem?_toArray,
      List.getElem?_eq_getElem hlt, Option.map_some, Option.getD_some]
    rw [hid, onSubject_eq]
  · rw [onSubject_eq]

theorem valid_eq : Core.valid (coreOf s) = s.valid := by
  funext sub
  unfold Core.valid Scenario.valid
  rw [conflicts_eq]

theorem activeCount_eq (sub : String) : (coreOf s).activeCount sub = (s.conflicts sub).length := by
  show ((coreOf s).conflicts sub).length = _
  rw [conflicts_eq]

theorem mustVerify_eq : (cxOf s).mustVerify = s.mustVerify := by
  funext id
  unfold Ctx.mustVerify Scenario.mustVerify
  rw [ctx_L]
  rfl

theorem restsOn_eq : Core.restsOn (cxOf s) (coreOf s) = s.restsOn := by
  funext id
  unfold Core.restsOn Scenario.restsOn
  rw [eff_eq, mustVerify_eq]

theorem positionOf_some {c : Claim} {p : Nat} (h : (cxOf s).positionOf c = some p) :
    ∃ hp : p < s.trace.claims.length, s.trace.claims[p] = c := by
  unfold Ctx.positionOf at h
  cases hq : (cxOf s).claimIx.first? (cmp := compare) c.id with
  | none => simp [hq] at h
  | some q =>
    simp only [hq, Option.bind_some] at h
    split at h
    · rename_i heq
      cases h
      simp only [cxOf, ctx_claims, List.getElem?_toArray, beq_iff_eq] at heq
      obtain ⟨hlt, hget⟩ := List.getElem?_eq_some_iff.mp heq
      exact ⟨hlt, hget⟩
    · cases h

theorem has_eq (c : Claim) (n : String) :
    ((Index.ofKeys compare c.needsAll).first? (cmp := compare) n).isSome =
      c.needsAll.contains n := by
  have := mem_map c.needsAll (fun x => x) n
  simpa using this

theorem incompatible_eq : Core.incompatible (cxOf s) s = s.incompatible := by
  funext c
  unfold Core.incompatible Scenario.incompatible
  simp only [has_eq]
  congr 1
  split
  · rename_i p hp
    obtain ⟨hlt, hc⟩ := positionOf_some s hp
    rw [bothNeeded_group, ctx_exclusions, read_positions, filter_positions]
    intro x _ hpred
    simp only [Bool.and_eq_true, List.contains_iff_mem] at hpred
    simp only [decide_eq_true_eq]
    rw [mem_needingBoth]
    exact ⟨hlt, by rw [hc]; exact hpred.1.2, by rw [hc]; exact hpred.2⟩
  · have hbound : ∀ i ∈ c.needsAll.flatMap ((cxOf s).exclFirst.group (cmp := compare) ·),
        i < s.trace.exclusions.length := by
      intro i hi
      obtain ⟨n, _, hin⟩ := List.mem_flatMap.mp hi
      rw [exclFirst_group] at hin
      obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hin
      exact mem_zipIdx_lt (List.mem_filter.mp hx).1
    rw [ascending_eq hbound, range_filter_eq, ctx_exclusions, read_positions, filter_positions]
    intro x hx hpred
    simp only [Bool.and_eq_true, List.contains_iff_mem] at hpred
    simp only [decide_eq_true_eq, List.mem_flatMap]
    refine ⟨x.1.between.1, hpred.1.2, ?_⟩
    rw [exclFirst_group]
    exact List.mem_map.mpr ⟨x, List.mem_filter.mpr ⟨hx, by simp⟩, rfl⟩

theorem intrinsic_eq : Core.intrinsic (cxOf s) s (coreOf s) = s.intrinsic := by
  funext c
  unfold Core.intrinsic Scenario.intrinsic
  rw [eff_eq, incompatible_eq, restsOn_eq]

theorem final_eq : Core.final (cxOf s) s (coreOf s) = s.final := by
  funext c
  unfold Core.final Scenario.final
  rw [valid_eq, intrinsic_eq]

end Core

/-! ## Counts -/

theorem counts_state (eff : String → EStatus) (rests : String → Bool) (needs : List String)
    (inc : Bool) :
    (Counts.of eff rests needs).state inc =
      (if (needs.map eff).any (· == .violated) || inc then State.cannot
       else if (needs.map eff).all (·.verified) then .can
       else if needs.all rests then .conditional else .«open») := by
  have h1 :
      decide (needs.countP (eff · == .violated) > 0) = (needs.map eff).any (· == .violated) := by
    rw [List.any_map, Bool.eq_iff_iff, decide_eq_true_iff, List.any_eq_true]
    exact List.countP_pos_iff
  have h2 :
      (needs.countP (fun n => !(eff n).verified) == 0) = (needs.map eff).all (·.verified) := by
    rw [List.all_map, Bool.eq_iff_iff, beq_iff_eq, List.all_eq_true, List.countP_eq_zero]
    simp
  have h3 : (needs.countP (!rests ·) == 0) = needs.all rests := by
    rw [Bool.eq_iff_iff, beq_iff_eq, List.all_eq_true, List.countP_eq_zero]
    simp
  unfold Counts.state Counts.of
  dsimp only
  rw [← h1, ← h2, ← h3]

/-- Counts after the moved needs change tests = the counts recomputed. -/
theorem patch_eq (e e' : String → EStatus) (r r' : String → Bool) (needs occ : List String)
    (moved : String → Bool) (hocc : occ.Perm (needs.filter moved))
    (he : ∀ x ∈ needs, moved x = false → e x = e' x)
    (hr : ∀ x ∈ needs, moved x = false → r x = r' x) :
    (Counts.of e r needs).patch occ e e' r r' = Counts.of e' r' needs := by
  unfold Counts.patch Counts.of
  dsimp only
  congr 1
  · exact (countP_patch hocc (fun x hx hm => by simp [he x hx hm])).symm
  · exact (countP_patch hocc (fun x hx hm => by simp [he x hx hm])).symm
  · exact (countP_patch hocc (fun x hx hm => by simp [hr x hx hm])).symm

/-! ## A what-if on top of the scenario (`Delta.build`) -/

section Delta

variable (s : Scenario) (extra : Overrides)

abbrev deltaOf : Delta := Delta.build (cxOf s) s (coreOf s) extra
abbrev afterOf : Scenario := s.withOverrides extra

/-- `derive` on any `eff1` = the witnesses `Scenario.derivations` collects with that `eff1`. -/
theorem derive_gen (e1 : String → EStatus) (id : String) :
    derive (cxOf s) s e1 id = s.trace.exclusions.filterMap fun x =>
      if (s.exclusionEff x).verified && !(e1 id).asserted then
        if x.between.1 == id && (e1 x.between.2).verified then some (x.id, x.between.2)
        else if x.between.2 == id && (e1 x.between.1).verified then some (x.id, x.between.1)
        else none
      else none := by
  unfold derive
  rw [exclAt_group, ← List.filterMap_filterMap]
  show (((s.trace.exclusions.zipIdx.filter fun x => decide (id ∈ endpoints x.1)).map
    (·.2)).filterMap (s.trace.exclusions.toArray[·]?)).filterMap _ = _
  rw [read_positions, filterMap_positions]
  intro x _ hsome
  simp only [decide_eq_true_eq, mem_endpoints]
  by_cases h1 : x.1.between.1 = id
  · exact Or.inl h1
  · by_cases h2 : x.1.between.2 = id
    · exact Or.inr h2
    · exfalso
      have e1' : (x.1.between.1 == id) = false := by simpa using h1
      have e2' : (x.1.between.2 == id) = false := by simpa using h2
      revert hsome
      split <;> simp [e1', e2']

theorem derive_after (id : String) :
    derive (cxOf s) s (afterOf s extra).eff1 id = (afterOf s extra).derivations id := by
  rw [derive_gen]
  rfl

theorem delta_eff1 : (deltaOf s extra).eff1 = (afterOf s extra).eff1 := by
  funext j
  show eff1Under (coreOf s) (Index.ofKeys compare (extra.map (·.1))) extra.toArray j = _
  unfold eff1Under
  rw [find?_map, find_lookup, eff1_eq, Fvtrace.Proofs.Plan.withOverrides_eff1_gen]
  rfl

theorem lookup_none_iff {β : Type} (l : List (String × β)) (k : String) :
    l.lookup k = none ↔ k ∉ l.map (·.1) := by
  induction l with
  | nil => simp [List.lookup]
  | cons x xs ih =>
    obtain ⟨a, v⟩ := x
    by_cases h : k = a
    · subst h; simp [List.lookup]
    · have : (k == a) = false := by simpa using h
      simp [List.lookup, this, ih, h]

theorem eff1_off_keys {j : String} (h : j ∉ extra.map (·.1)) :
    (afterOf s extra).eff1 j = s.eff1 j := by
  rw [Fvtrace.Proofs.Plan.withOverrides_eff1_gen, (lookup_none_iff extra j).mpr h]

theorem delta_keys : (deltaOf s extra).keys = (extra.map (·.1)).eraseDups :=
  eraseDups_eq _

/-- An exclusion moves under the what-if: an endpoint is a key. -/
def Moved (x : Exclusion) : Prop := ∃ k ∈ extra.map (·.1), k ∈ endpoints x

instance (x : Exclusion) : Decidable (Moved extra x) := by unfold Moved; exact inferInstance

theorem flatGroups_mem (i : Nat) :
    i ∈ (deltaOf s extra).keys.flatMap ((cxOf s).exclAt.group (cmp := compare) ·) ↔
      ∃ h : i < s.trace.exclusions.length, Moved extra s.trace.exclusions[i] := by
  simp only [List.mem_flatMap, delta_keys, List.mem_eraseDups]
  constructor
  · rintro ⟨k, hk, hi⟩
    rw [exclAt_group, mem_positions (q := fun (x : Exclusion) => decide (k ∈ endpoints x))] at hi
    obtain ⟨hlt, hq⟩ := hi
    exact ⟨hlt, k, hk, by simpa using hq⟩
  · rintro ⟨hlt, k, hk, hend⟩
    refine ⟨k, hk, ?_⟩
    rw [exclAt_group, mem_positions (q := fun (x : Exclusion) => decide (k ∈ endpoints x))]
    exact ⟨hlt, by simpa using hend⟩

/-- The exclusions at a key, in trace order. -/
theorem delta_excls :
    (deltaOf s extra).touched.filterMap ((cxOf s).exclusions[·]?) =
      s.trace.exclusions.filter fun x => decide (Moved extra x) := by
  have hb : ∀ i ∈ (deltaOf s extra).keys.flatMap ((cxOf s).exclAt.group (cmp := compare) ·),
      i < s.trace.exclusions.length := fun i hi => ((flatGroups_mem s extra i).mp hi).1
  have ht : (deltaOf s extra).touched =
      ascending ((deltaOf s extra).keys.flatMap ((cxOf s).exclAt.group (cmp := compare) ·)) := rfl
  rw [ht, ascending_eq hb, range_filter_eq, ctx_exclusions, read_positions]
  have : (s.trace.exclusions.zipIdx.filter fun x => decide (x.2 ∈
      (deltaOf s extra).keys.flatMap ((cxOf s).exclAt.group (cmp := compare) ·))) =
      s.trace.exclusions.zipIdx.filter fun x => decide (Moved extra x.1) := by
    apply List.filter_congr
    intro x hx
    rw [Bool.eq_iff_iff, decide_eq_true_iff, decide_eq_true_iff, flatGroups_mem]
    obtain ⟨hlt, heq⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) hx
    constructor
    · rintro ⟨_, hm⟩; rw [heq]; exact hm
    · intro hm; exact ⟨hlt, by rw [← heq]; exact hm⟩
  rw [this]
  exact zipIdx_filter_fst s.trace.exclusions (fun y => decide (Moved extra y))

theorem delta_changed : (deltaOf s extra).changed =
    ((extra.map (·.1)).eraseDups ++
      (s.trace.exclusions.filter fun x => decide (Moved extra x)).flatMap
        fun x => [x.between.1, x.between.2]).eraseDups := by
  show Index.eraseDups compare ((deltaOf s extra).keys ++
    ((deltaOf s extra).touched.filterMap ((cxOf s).exclusions[·]?)).flatMap
      fun x => [x.between.1, x.between.2]) = _
  rw [eraseDups_eq, delta_excls, delta_keys]

theorem mem_changed (j : String) : j ∈ (deltaOf s extra).changed ↔
    j ∈ extra.map (·.1) ∨ ∃ x ∈ s.trace.exclusions, Moved extra x ∧
      (x.between.1 = j ∨ x.between.2 = j) := by
  rw [delta_changed, List.mem_eraseDups, List.mem_append, List.mem_eraseDups, List.mem_flatMap]
  simp only [List.mem_filter, decide_eq_true_eq, List.mem_cons, List.mem_nil_iff, or_false]
  constructor
  · rintro (h | ⟨x, ⟨hx, hm⟩, h⟩)
    · exact Or.inl h
    · exact Or.inr ⟨x, hx, hm, h.imp Eq.symm Eq.symm⟩
  · rintro (h | ⟨x, hx, hm, h⟩)
    · exact Or.inl h
    · exact Or.inr ⟨x, ⟨hx, hm⟩, h.imp Eq.symm Eq.symm⟩

theorem changed_nodup : (deltaOf s extra).changed.Nodup := by
  rw [delta_changed]; exact eraseDups_nodup _

/-- Off the keys + their partners, the what-if leaves `eff` as it was. -/
theorem eff_off_changed {j : String} (h : j ∉ (deltaOf s extra).changed) :
    (afterOf s extra).eff j = s.eff j := by
  have hk : j ∉ extra.map (·.1) := fun hk => h ((mem_changed s extra j).mpr (Or.inl hk))
  unfold Scenario.eff
  have hd : (afterOf s extra).derivations j = s.derivations j := by
    unfold Scenario.derivations
    apply filterMap_congr'
    intro x hx
    by_cases hj : x.between.1 = j ∨ x.between.2 = j
    · have hnm : ¬ Moved extra x := fun hm =>
        h ((mem_changed s extra j).mpr (Or.inr ⟨x, hx, hm, hj⟩))
      have e1 : ∀ k, (x.between.1 = k ∨ x.between.2 = k) →
          (afterOf s extra).eff1 k = s.eff1 k := by
        intro k hk'
        apply eff1_off_keys
        intro hkk
        exact hnm ⟨k, hkk, (mem_endpoints x k).mpr hk'⟩
      rw [e1 j hj, e1 x.between.1 (Or.inl rfl), e1 x.between.2 (Or.inr rfl)]
      rfl
    · simp only [not_or] at hj
      have h1 : (x.between.1 == j) = false := by simpa using hj.1
      have h2 : (x.between.2 == j) = false := by simpa using hj.2
      simp [h1, h2]
  rw [hd, eff1_off_keys s extra hk]

theorem effUnder_after (id : String) :
    effUnder (cxOf s) s (deltaOf s extra).eff1 id = (afterOf s extra).eff id := by
  unfold effUnder
  rw [delta_eff1, derive_after]
  rfl

theorem delta_eff : (deltaOf s extra).eff = (afterOf s extra).eff := by
  funext j
  show (match (Index.ofKeys compare (deltaOf s extra).changed).first? (cmp := compare) j with
    | some i => (((deltaOf s extra).changed.map
        (effUnder (cxOf s) s (deltaOf s extra).eff1)).toArray)[i]?.getD
          (effUnder (cxOf s) s (deltaOf s extra).eff1 j)
    | none => (coreOf s).eff j) = _
  split
  · rename_i i hi
    rw [first?_ofKeys, List.findIdx?_eq_some_iff_getElem] at hi
    obtain ⟨hlt, hj, _⟩ := hi
    have hj' : (deltaOf s extra).changed[i] = j := by
      simpa [cmp_beq] using hj
    simp only [List.getElem?_toArray, List.getElem?_map, List.getElem?_eq_getElem hlt,
      Option.map_some, Option.getD_some]
    rw [hj', effUnder_after]
  · rename_i hn
    have hnot : j ∉ (deltaOf s extra).changed := by
      intro hj
      have := mem_map (deltaOf s extra).changed (fun x => x) j
      simp only [List.map_id'] at this
      rw [hn] at this
      simp [List.contains_iff_mem.mpr hj] at this
      exact this hj
    rw [eff_eq, eff_off_changed s extra hnot]

theorem active_off_moved {x : Exclusion} (h : ¬ Moved extra x) :
    (afterOf s extra).active x = s.active x := by
  unfold Scenario.active
  have e : ∀ k, (x.between.1 = k ∨ x.between.2 = k) → (afterOf s extra).eff1 k = s.eff1 k := by
    intro k hk
    apply eff1_off_keys
    intro hkk
    exact h ⟨k, hkk, (mem_endpoints x k).mpr hk⟩
  rw [e _ (Or.inl rfl), e _ (Or.inr rfl)]
  rfl

theorem shifts_at (xs : List Exclusion) (before after : Exclusion → Bool) (sub : String) :
    (Shifts.of xs before after).at sub =
      (xs.countP fun x => x.subject == sub && before x,
        xs.countP fun x => x.subject == sub && after x) := by
  unfold Shifts.at Shifts.of
  dsimp only
  have hcount : ∀ q : Exclusion → Bool,
      ((xs.filter (·.subject == sub)).filter q).length =
        xs.countP fun x => x.subject == sub && q x := by
    intro q
    rw [List.filter_filter, ← List.countP_eq_length_filter]
    apply List.countP_congr
    intro x _
    rw [Bool.and_comm]
  cases hi : (Index.ofKeys compare (Index.eraseDups compare (xs.map (·.subject)))).first?
      (cmp := compare) sub with
  | none =>
    simp only [Option.bind_none, Option.getD_none]
    have hnot : sub ∉ xs.map (·.subject) := by
      intro hm
      have := mem_map (Index.eraseDups compare (xs.map (·.subject))) (fun x => x) sub
      simp only [List.map_id'] at this
      rw [hi, eraseDups_eq] at this
      simp [List.contains_iff_mem.mpr (List.mem_eraseDups.mpr hm)] at this
      obtain ⟨x, hx, hxs⟩ := List.mem_map.mp hm
      exact this x hx hxs
    have h0 : ∀ q : Exclusion → Bool, (xs.countP fun x => x.subject == sub && q x) = 0 := by
      intro q
      rw [List.countP_eq_zero]
      intro x hx hq
      simp only [Bool.and_eq_true, beq_iff_eq] at hq
      exact hnot (List.mem_map.mpr ⟨x, hx, hq.1⟩)
    rw [h0, h0]
  | some i =>
    rw [first?_ofKeys, List.findIdx?_eq_some_iff_getElem] at hi
    obtain ⟨hlt, hk, _⟩ := hi
    have hk' : (Index.eraseDups compare (xs.map (·.subject)))[i] = sub := by
      simpa [cmp_beq] using hk
    simp only [Option.bind_some, List.getElem?_toArray, List.getElem?_map,
      List.getElem?_eq_getElem hlt, Option.map_some, Option.getD_some]
    rw [hk', hcount, hcount]

theorem delta_activeCount (sub : String) :
    (deltaOf s extra).activeCount sub = ((afterOf s extra).conflicts sub).length := by
  show (coreOf s).activeCount sub -
      ((Shifts.of ((deltaOf s extra).touched.filterMap ((cxOf s).exclusions[·]?)) (coreOf s).active
        (activeWith s (deltaOf s extra).eff1)).at sub).1 +
      ((Shifts.of ((deltaOf s extra).touched.filterMap ((cxOf s).exclusions[·]?)) (coreOf s).active
        (activeWith s (deltaOf s extra).eff1)).at sub).2 = _
  rw [shifts_at, delta_excls, activeCount_eq, active_eq, delta_eff1]
  have ha : activeWith s (afterOf s extra).eff1 = (afterOf s extra).active := rfl
  rw [ha]
  unfold Scenario.conflicts
  have hp := countP_patch (l := s.trace.exclusions)
    (occ := s.trace.exclusions.filter fun x => decide (Moved extra x))
    (f := fun x => x.subject == sub && s.active x)
    (g := fun x => x.subject == sub && (afterOf s extra).active x)
    (moved := fun x => decide (Moved extra x)) (List.Perm.refl _) (by
      intro x _ hm
      have : ¬ Moved extra x := by simpa using hm
      rw [active_off_moved s extra this])
  have hle : (s.trace.exclusions.filter fun x => decide (Moved extra x)).countP
      (fun x => x.subject == sub && s.active x) ≤
      s.trace.exclusions.countP (fun x => x.subject == sub && s.active x) :=
    List.Sublist.countP_le List.filter_sublist
  have hlen : ∀ q : Exclusion → Bool,
      ((s.trace.exclusions.filter q).map fun x => x.id).length = s.trace.exclusions.countP q := by
    intro q; rw [List.length_map, List.countP_eq_length_filter]
  rw [show (afterOf s extra).trace.exclusions = s.trace.exclusions from rfl, hlen, hlen]
  omega

theorem delta_valid : (deltaOf s extra).valid = (afterOf s extra).valid := by
  funext sub
  show ((deltaOf s extra).activeCount sub == 0) = _
  rw [delta_activeCount]
  unfold Scenario.valid
  cases (afterOf s extra).conflicts sub <;> simp

theorem delta_restsOn : Delta.restsOn (cxOf s) (deltaOf s extra) = (afterOf s extra).restsOn := by
  funext id
  unfold Delta.restsOn Scenario.restsOn
  rw [delta_eff, mustVerify_eq]
  rfl

theorem incompatible_after : (afterOf s extra).incompatible = s.incompatible := rfl

theorem isChanged_iff (j : String) :
    (deltaOf s extra).isChanged j = true ↔ j ∈ (deltaOf s extra).changed := by
  show ((Index.ofKeys compare (deltaOf s extra).changed).first? (cmp := compare) j).isSome = true ↔
    _
  have := mem_map (deltaOf s extra).changed (fun x => x) j
  simp only [List.map_id'] at this
  rw [this, List.contains_iff_mem]

/-- The claim's final state under the what-if, from its base counts patched over the changed
needs = the scenario's under the what-if. -/
theorem delta_final (c : Claim) (base : Counts) (times : String → Nat) (incompat : Bool)
    (hbase : base = Counts.of s.eff s.restsOn c.needsAll)
    (htimes : ∀ d ∈ (deltaOf s extra).changed, times d = c.needsAll.count d)
    (hinc : incompat = !(s.incompatible c).isEmpty) :
    Delta.final (cxOf s) (coreOf s) (deltaOf s extra) c.needsAll c.needsAll.length base times
      incompat c.subject = (afterOf s extra).final c := by
  unfold Delta.final Delta.counts Scenario.final
  rw [delta_valid]
  split
  · rw [hbase, ← eff_eq, ← restsOn_eq]
    have hocc := occurrences_perm c.needsAll (deltaOf s extra).changed (changed_nodup s extra)
      times htimes (deltaOf s extra).isChanged (isChanged_iff s extra)
    have hcount : (deltaOf s extra).changedCount = (deltaOf s extra).changed.length := rfl
    rw [hcount, patch_eq _ _ _ _ c.needsAll _ (deltaOf s extra).isChanged hocc]
    · rw [delta_eff, delta_restsOn, counts_state, hinc, ← incompatible_after s extra]
      rfl
    · intro x _ hm
      have : x ∉ (deltaOf s extra).changed := fun h => by
        simp [(isChanged_iff s extra x).mpr h] at hm
      rw [eff_eq, delta_eff, eff_off_changed s extra this]
    · intro x _ hm
      have : x ∉ (deltaOf s extra).changed := fun h => by
        simp [(isChanged_iff s extra x).mpr h] at hm
      rw [restsOn_eq, delta_restsOn]
      unfold Scenario.restsOn
      rw [eff_off_changed s extra this]
      rfl
  · rfl

/-- What `Delta.build` + `Delta.final` read of a base core: a core answering as the scenario on
these four (a forest node's overlays over the base, `kernel.md` P-forest) gives the same delta. -/
structure CoreSpec (s : Scenario) (k : Core) : Prop where
  eff1 : k.eff1 = s.eff1
  eff : k.eff = s.eff
  active : k.active = s.active
  activeCount : ∀ sub, k.activeCount sub = (s.conflicts sub).length

theorem coreSpec : CoreSpec s (coreOf s) :=
  ⟨eff1_eq s, eff_eq s, active_eq s, activeCount_eq s⟩

theorem delta_core {k : Core} (hk : CoreSpec s k) :
    Delta.build (cxOf s) s k extra = deltaOf s extra := by
  have h1 : k.eff1 = (coreOf s).eff1 := hk.eff1.trans (eff1_eq s).symm
  have h2 : k.eff = (coreOf s).eff := hk.eff.trans (eff_eq s).symm
  have h3 : k.active = (coreOf s).active := hk.active.trans (active_eq s).symm
  have h4 : k.activeCount = (coreOf s).activeCount :=
    funext fun sub => (hk.activeCount sub).trans (activeCount_eq s sub).symm
  show Delta.build (cxOf s) s k extra = Delta.build (cxOf s) s (coreOf s) extra
  unfold Delta.build eff1Under
  rw [h1, h2, h3, h4]

theorem restsOn_core {k : Core} (hk : CoreSpec s k) :
    Core.restsOn (cxOf s) k = s.restsOn := by
  funext id
  unfold Core.restsOn Scenario.restsOn
  rw [hk.eff, mustVerify_eq]

/-- `Delta.build` reads its scenario through receipt bindings alone (`exclusionEff`). -/
theorem delta_scenario (o : Overrides) (k : Core) :
    Delta.build (cxOf s) s k extra =
      Delta.build (cxOf (s.withOverrides o)) (s.withOverrides o) k extra := rfl

end Delta

/-! ## Experiments: closure, merged outcomes -/

section Experiments

variable (s : Scenario)

/-- The fast closure (`Ctx.closureWith` over the forest) = `Scenario.closure`. -/
theorem closure_eq (ids : List String) :
    (cxOf s).closureWith (Forest.build (cxOf s)) ids = s.closure ids :=
  congrFun (Fvtrace.Proofs.Forest.closureWith_eq s) ids

theorem successPairs_eq (ids : List String) :
    (cxOf s).successPairs ids = s.successPairs ids := by
  unfold Ctx.successPairs Scenario.successPairs
  rw [ctx_L]
  rfl

theorem merged_eq : (cxOf s).merged = s.merged := by
  funext ids
  unfold Ctx.merged Scenario.merged
  dsimp only
  rw [successPairs_eq, eraseDups_eq]
  congr 1
  funext k
  congr 1
  have hg := group_map (s.successPairs ids) (·.1) k
  rw [hg, read_positions]
  congr 2
  exact zipIdx_filter_fst (s.successPairs ids) (fun x => x.1 == k)

end Experiments

/-! ## Unlocks + gates -/

section Unlocks

variable (s : Scenario)

theorem filterMap_ite {β γ : Type} (l : List β) (P : β → Bool) (f : β → γ) :
    l.filterMap (fun c => if P c then some (f c) else none) = (l.filter P).map f := by
  induction l with
  | nil => rfl
  | cons y ys ih => cases h : P y <;> simp [h, ih, List.filter_cons]

/-- Reading the trace's claims at positions, through a function of the claim alone. -/
theorem read_claims {β : Type} (q : Claim × Nat → Bool) (h : Claim → Option β)
    (hq : ∀ x ∈ s.trace.claims.zipIdx, (h x.1).isSome = true → q x = true) :
    ((s.trace.claims.zipIdx.filter q).map (·.2)).filterMap (fun p =>
      (s.trace.claims.toArray[p]?).bind h) = s.trace.claims.filterMap h := by
  rw [← List.filterMap_filterMap, read_positions, filterMap_positions _ _ _ hq]

theorem memo_get (p : Nat) (hp : p < s.trace.claims.length) :
    ((cxOf s).claims.map (ClaimMemo.of (cxOf s) s (coreOf s)))[p]? =
      some (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[p]) := by
  simp [cxOf, ctx_claims, List.getElem?_eq_getElem hp]

theorem needs_at (p : Nat) (hp : p < s.trace.claims.length) (d : String) :
    (cxOf s).needs d p = s.trace.claims[p].needsAll.count d := by
  unfold Ctx.needs
  rw [needCount_count]
  simp [List.getElem?_eq_getElem hp]

theorem gates_eq (f : Fact) :
    ((cxOf s).gatePositions f.id).filterMap (fun p => ((cxOf s).claims[p]?).map
      (fun (c : Claim) => c.id)) = s.gates f := by
  rw [gatePositions_eq]
  simp only [cxOf, ctx_claims]
  rw [← List.map_filterMap, read_positions]
  unfold Scenario.gates
  congr 1
  rw [zipIdx_filter_fst s.trace.claims (fun (c : Claim) => decide (f.id ∈ c.needsAll))]
  apply List.filter_congr
  intro c _
  simp [List.contains_iff_mem]

/-- A trace claim's final state under a what-if, from its memo. -/
theorem memo_final (extra : Overrides) (p : Nat) (hp : p < s.trace.claims.length) :
    let m := ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[p]
    Delta.final (cxOf s) (coreOf s) (deltaOf s extra) m.needs m.needsCount m.counts
      ((cxOf s).needs · p) m.incompatible s.trace.claims[p].subject =
      (afterOf s extra).final s.trace.claims[p] := by
  intro m
  apply delta_final
  · show Counts.of (coreOf s).eff (Core.restsOn (cxOf s) (coreOf s)) _ = _
    rw [eff_eq, restsOn_eq]
  · intro d _; exact needs_at s p hp d
  · show (!(Core.incompatible (cxOf s) s _).isEmpty) = _
    rw [incompatible_eq]

theorem memo_base_final (p : Nat) (hp : p < s.trace.claims.length) :
    (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[p]).final = s.final s.trace.claims[p] := by
  show Core.final (cxOf s) s (coreOf s) _ = _
  rw [final_eq]

theorem unlocks_eq (f : Fact) :
    unlocksOf (cxOf s) s (coreOf s)
      (Thunk.mk fun _ => (cxOf s).claims.map (ClaimMemo.of (cxOf s) s (coreOf s))) f =
      s.unlocks f := by
  unfold unlocksOf Scenario.unlocks
  dsimp only
  rw [gatePositions_eq]
  let h := fun (c : Claim) => if (c.needsAll.contains f.id && (s.final c).rank ≤ 1 &&
      ((s.withOverrides [(f.id, f.ceiling)]).final c).rank ≥ 2) then some c.id else none
  have hsup : ∀ x ∈ s.trace.claims.zipIdx, (h x.1).isSome = true →
      decide (f.id ∈ x.1.needsAll) = true := by
    intro x _ hs
    simp only [h] at hs
    split at hs
    · rename_i hc
      simp only [Bool.and_eq_true, List.contains_iff_mem] at hc
      simpa using hc.1.1
    · cases hs
  rw [filterMap_congr' (g := fun p => (s.trace.claims.toArray[p]?).bind h)]
  · rw [read_claims s _ h hsup, filterMap_ite]
  · intro p hp
    obtain ⟨hlt, hq⟩ := (mem_positions (q := fun (c : Claim) => decide (f.id ∈ c.needsAll))).mp hp
    simp only [decide_eq_true_eq] at hq
    simp only [cxOf, ctx_claims, List.getElem?_toArray, List.getElem?_eq_getElem hlt,
      Option.bind_some, thunk_get_mk, Array.getElem?_map, Option.map_some]
    have h1 := memo_final s [(f.id, f.ceiling)] p hlt
    have h2 := memo_base_final s p hlt
    simp only [cxOf, deltaOf] at h1 h2
    rw [h1, h2]
    simp only [h, List.contains_iff_mem.mpr hq, Bool.true_and]

end Unlocks

/-! ## Moves -/

section Moves

variable (s : Scenario) (extra : Overrides)

theorem touched_subjects :
    (deltaOf s extra).touched.filterMap (fun p => ((cxOf s).exclusions[p]?).map (·.subject)) =
      (s.trace.exclusions.filter fun x => decide (Moved extra x)).map (·.subject) := by
  rw [← List.map_filterMap, delta_excls]

theorem valid_unchanged {sub : String}
    (h : sub ∉ (s.trace.exclusions.filter fun x => decide (Moved extra x)).map (·.subject)) :
    (afterOf s extra).valid sub = s.valid sub := by
  rw [← delta_valid]
  show ((coreOf s).activeCount sub -
      ((Shifts.of ((deltaOf s extra).touched.filterMap ((cxOf s).exclusions[·]?)) (coreOf s).active
        (activeWith s (deltaOf s extra).eff1)).at sub).1 +
      ((Shifts.of ((deltaOf s extra).touched.filterMap ((cxOf s).exclusions[·]?)) (coreOf s).active
        (activeWith s (deltaOf s extra).eff1)).at sub).2 == 0) = _
  rw [shifts_at, delta_excls, activeCount_eq]
  have h0 : ∀ q : Exclusion → Bool,
      ((s.trace.exclusions.filter fun x => decide (Moved extra x)).countP
        fun x => x.subject == sub && q x) = 0 := by
    intro q
    rw [List.countP_eq_zero]
    intro x hx hq
    simp only [Bool.and_eq_true, beq_iff_eq] at hq
    exact h (List.mem_map.mpr ⟨x, hx, hq.1⟩)
  rw [h0, h0]
  unfold Scenario.valid
  cases s.conflicts sub <;> simp

theorem final_unchanged (c : Claim) (hn : ∀ d ∈ c.needsAll, d ∉ (deltaOf s extra).changed)
    (hv : (afterOf s extra).valid c.subject = s.valid c.subject) :
    (afterOf s extra).final c = s.final c := by
  unfold Scenario.final
  rw [hv]
  congr 1
  unfold Scenario.intrinsic Scenario.restsOn
  have he : ∀ d ∈ c.needsAll, (afterOf s extra).eff d = s.eff d :=
    fun d hd => eff_off_changed s extra (hn d hd)
  rw [List.map_congr_left he, incompatible_after]
  have hall : (c.needsAll.all fun id => ((afterOf s extra).eff id).asserted &&
      (!(afterOf s extra).mustVerify id || ((afterOf s extra).eff id).verified)) =
      (c.needsAll.all fun id =>
        (s.eff id).asserted && (!s.mustVerify id || (s.eff id).verified)) := by
    apply Fvtrace.Proofs.Engine.all_congr'
    intro n hn'
    rw [he n hn']
    rfl
  simp only [hall]

theorem mem_gatesGroup (d : String) (p : Nat) :
    p ∈ (cxOf s).gates.group (cmp := compare) d ↔
      ∃ h : p < s.trace.claims.length, d ∈ s.trace.claims[p].needsAll := by
  show p ∈ (Index.build compare (s.trace.claims.zipIdx.flatMap fun x =>
    x.1.needsAll.map (·, x.2))).group (cmp := compare) d ↔ _
  rw [group_build]
  simp only [List.mem_map, List.mem_filter, List.mem_flatMap, is_iff]
  constructor
  · rintro ⟨y, ⟨⟨x, hx, ⟨n, hn, rfl⟩⟩, hk⟩, rfl⟩
    obtain ⟨hlt, heq⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) hx
    refine ⟨hlt, ?_⟩
    rw [← heq]; simp only at hk; rw [← hk]; exact hn
  · rintro ⟨hlt, hd⟩
    refine ⟨(d, p), ⟨⟨(s.trace.claims[p], p), ?_, ⟨d, hd, rfl⟩⟩, rfl⟩, rfl⟩
    exact List.mem_zipIdx_iff_getElem?.mpr (by simp [hlt])

theorem mem_claimSubjectGroup (sub : String) (p : Nat) :
    p ∈ (cxOf s).claimSubject.group (cmp := compare) sub ↔
      ∃ h : p < s.trace.claims.length, s.trace.claims[p].subject = sub := by
  rw [claimSubject_group, mem_positions (q := fun (c : Claim) => c.subject == sub)]
  simp

theorem moves_eq :
    movesUnder (cxOf s) s (coreOf s)
      (Thunk.mk fun _ => (cxOf s).claims.map (ClaimMemo.of (cxOf s) s (coreOf s))) extra =
      s.moves (afterOf s extra) := by
  unfold movesUnder Scenario.moves
  dsimp only
  rw [show (Delta.build (cxOf s) s (coreOf s) extra) = deltaOf s extra from rfl, touched_subjects,
    eraseDups_eq]
  generalize hF : ((s.trace.exclusions.filter fun x => decide (Moved extra x)).map
    (·.subject)).eraseDups.filter
      (fun sub => (deltaOf s extra).valid sub != (coreOf s).valid sub) = F
  have hmemF : ∀ sub, sub ∈ F ↔
      sub ∈ (s.trace.exclusions.filter fun x => decide (Moved extra x)).map (·.subject) ∧
        (afterOf s extra).valid sub ≠ s.valid sub := by
    intro sub
    rw [← hF, List.mem_filter, List.mem_eraseDups, delta_valid, valid_eq]
    simp
  let U := (deltaOf s extra).changed.flatMap ((cxOf s).gates.group (cmp := compare) ·) ++
    F.flatMap ((cxOf s).claimSubject.group (cmp := compare) ·)
  have hmemU : ∀ p, p ∈ U ↔ ∃ h : p < s.trace.claims.length,
      (∃ d ∈ (deltaOf s extra).changed, d ∈ s.trace.claims[p].needsAll) ∨
        s.trace.claims[p].subject ∈ F := by
    intro p
    simp only [U, List.mem_append, List.mem_flatMap, mem_gatesGroup, mem_claimSubjectGroup]
    constructor
    · rintro (⟨d, hd, hlt, hn⟩ | ⟨sub, hsub, hlt, hs⟩)
      · exact ⟨hlt, Or.inl ⟨d, hd, hn⟩⟩
      · exact ⟨hlt, Or.inr (hs ▸ hsub)⟩
    · rintro ⟨hlt, ⟨d, hd, hn⟩ | hs⟩
      · exact Or.inl ⟨d, hd, hlt, hn⟩
      · exact Or.inr ⟨_, hs, hlt, rfl⟩
  have hb : ∀ p ∈ U, p < s.trace.claims.length := fun p hp => ((hmemU p).mp hp).1
  rw [show (deltaOf s extra).changed.flatMap ((cxOf s).gates.group (cmp := compare) ·) ++
    F.flatMap ((cxOf s).claimSubject.group (cmp := compare) ·) = U from rfl]
  rw [ascending_eq hb, range_filter_eq]
  let h := fun (c : Claim) => if s.final c != (afterOf s extra).final c then
    some ({ claim := c.id, before := s.final c, after := (afterOf s extra).final c } :
      Scenario.Move)
    else none
  have hsup : ∀ x ∈ s.trace.claims.zipIdx, (h x.1).isSome = true → decide (x.2 ∈ U) = true := by
    intro x hx hs
    obtain ⟨hlt, heq⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) hx
    simp only [h] at hs
    split at hs
    · rename_i hne
      simp only [decide_eq_true_eq, hmemU]
      refine ⟨hlt, ?_⟩
      rw [← heq]
      by_cases hn : ∃ d ∈ (deltaOf s extra).changed, d ∈ x.1.needsAll
      · exact Or.inl hn
      · right
        rw [hmemF]
        have hn' : ∀ d ∈ x.1.needsAll, d ∉ (deltaOf s extra).changed :=
          fun d hd hc => hn ⟨d, hc, hd⟩
        by_cases hm : x.1.subject ∈ (s.trace.exclusions.filter fun x => decide (Moved extra x)).map
          (·.subject)
        · refine ⟨hm, fun hv => ?_⟩
          have := final_unchanged s extra x.1 hn' hv
          simp [this] at hne
        · have := final_unchanged s extra x.1 hn' (valid_unchanged s extra hm)
          simp [this] at hne
    · cases hs
  rw [filterMap_congr' (g := fun p => (s.trace.claims.toArray[p]?).bind h)]
  · rw [read_claims s _ h hsup]
  · intro p hp
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hp
    have hlt := mem_zipIdx_lt (List.mem_filter.mp hx).1
    simp only [cxOf, ctx_claims, List.getElem?_toArray, List.getElem?_eq_getElem hlt,
      Option.bind_some, thunk_get_mk, Array.getElem?_map, Option.map_some]
    have h1 := memo_final s extra x.2 hlt
    have h2 := memo_base_final s x.2 hlt
    simp only [cxOf, deltaOf] at h1 h2
    rw [h1, h2]

end Moves

/-! ## Small fields -/

section Small

variable (s : Scenario)

theorem raises_eq (n : String) (st : Status) :
    (coreOf s).raises n st = decide ((EStatus.ofStatus st).strength > (s.eff1 n).strength) := by
  unfold Core.raises; rw [eff1_eq]

theorem raised_eq (ids : List String) : raisedBy (cxOf s) (coreOf s) ids = s.raised ids := by
  unfold raisedBy
  rw [merged_eq]
  unfold Scenario.raised
  congr 1
  funext x
  rw [raises_eq]

theorem withOverrides_eq (extra : Overrides) :
    extra ++ s.overrides.filter (fun (k, _) =>
      ((Index.ofKeys compare (extra.map (·.1))).first? (cmp := compare) k).isNone) =
      (s.withOverrides extra).overrides := by
  unfold Scenario.withOverrides
  congr 1
  apply List.filter_congr
  rintro ⟨k, st⟩ _
  have := mem_map extra (·.1) k
  dsimp only
  rw [← Option.not_isSome, this, List.contains_eq_any_beq, List.any_map]
  congr 1
  congr 1
  funext y
  simp only [Function.comp_apply]
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq]
  exact eq_comm

/-- The baseline core: the scenario's own when it has no what-if. -/
abbrev baseOf : Core :=
  if s.overrides.isEmpty then coreOf s else Core.build (cxOf s) { s with overrides := [] }

theorem baseline_self (h : s.overrides.isEmpty = true) : s.baseline = s := by
  unfold Scenario.baseline
  cases s with
  | mk t c o => simp only [List.isEmpty_iff] at h; subst h; rfl

theorem base_eff : (baseOf s).eff = s.baseline.eff := by
  unfold baseOf
  split
  · rename_i h; rw [eff_eq, baseline_self s h]
  · exact eff_eq s.baseline

theorem base_valid : Core.valid (baseOf s) = s.baseline.valid := by
  unfold baseOf
  split
  · rename_i h; rw [valid_eq, baseline_self s h]
  · exact valid_eq s.baseline

end Small

/-! ## Sorted lists: work rows, experiment order -/

section Sorted

variable (s : Scenario)

theorem closable_eq (f : Fact) :
    (let e := (coreOf s).eff f.id
     e != .violated && e.strength < (EStatus.ofStatus f.ceiling).strength) = s.closable f := by
  rw [eff_eq]; rfl

theorem work_eq :
    (((s.trace.facts.filterMap fun f =>
        if s.closable f && !(s.gates f).isEmpty then
          some (({ fact := f.id, unlocks := s.unlocks f, gates := s.gates f } : Scenario.Work))
        else none).map fun w => (w.unlocks.length, w.gates.length, w)).mergeSort
      fun a b => !workKeyBefore b a).map (·.2.2) = s.work := by
  unfold Scenario.work
  rw [filterMap_ite, ← List.map_mergeSort (f := fun w => (w.unlocks.length, w.gates.length, w))
    (r := fun a b => !Scenario.workBefore b a)]
  · rw [List.map_map]
    exact List.map_id _
  · intro a _ b _; rfl

/-- An experiment's row from the `Scenario` functions (the reference record's). -/
abbrev rowRefOf : Experiment → ExperimentRow :=
  rowOf s.closure s.merged (fun ids => s.moves (s.applySuccess ids))
    (fun e => s.moves (s.applyFailure e)) (s.overrides.lookup ·) (s.resultFacts.contains ·)

/-- The rows sorted once by their own keys = the reference rows in the reference order. -/
theorem rows_eq :
    (s.trace.experiments.map (rowRefOf s)).mergeSort rowBefore =
      (s.trace.experiments.mergeSort (Evaluate.experimentBefore s)).map (rowRefOf s) :=
  (List.map_mergeSort (l := s.trace.experiments) (f := rowRefOf s)
    (r := Evaluate.experimentBefore s) (s := rowBefore) fun _ _ _ _ => rfl).symm

theorem experimentOrder_eq :
    ((s.trace.experiments.map (rowRefOf s)).mergeSort rowBefore).map (·.experiment) =
      s.trace.experiments.mergeSort (Evaluate.experimentBefore s) := by
  rw [rows_eq, List.map_map]
  exact List.map_id _

end Sorted

/-! ## Plans -/

section Plans

variable (s : Scenario)

theorem searchWith_eq (c : Claim) (validAfter : List String → Bool)
    (optRank finRank : List String → Nat)
    (hv : ∀ ids, validAfter ids = (s.applySuccess ids).valid c.subject)
    (ho : ∀ ids, optRank ids = ((s.applySuccess ids).optimistic c).rank)
    (hf : ∀ ids, finRank ids = ((s.applySuccess ids).final c).rank) :
    ∀ (rest inc best : List String),
      searchWith s.closure validAfter optRank finRank (costOf s.trace) inc rest best =
        s.search c inc rest best
  | [], inc, best => by
    unfold searchWith Scenario.search Scenario.planBetter
    simp only [hv, hf]
  | r :: rest, inc, best => by
    unfold searchWith Scenario.search Scenario.skips
    simp only [hv, ho, hf]
    rw [searchWith_eq c validAfter optRank finRank hv ho hf rest inc best,
      searchWith_eq c validAfter optRank finRank hv ho hf rest (inc ++ [r])]

theorem count_ofKeys (l : List String) (d : String) :
    (Index.ofKeys compare l).count (cmp := compare) d = l.count d := by
  rw [Index.ofKeys, count_build, List.count_eq_length_filter]
  have := zipIdx_filter_fst l (fun x => x == d)
  rw [← this, List.length_map]
  congr 2
  funext x
  simp [Is, cmp_beq]

theorem node_valid (c : Claim) (ids : List String) :
    (Delta.build (cxOf s) s (coreOf s) (s.raised ids)).valid c.subject =
      (s.applySuccess ids).valid c.subject := by
  have := delta_valid s (s.raised ids)
  simp only [deltaOf] at this
  rw [this]; rfl

theorem node_final (c : Claim) (ids : List String) :
    Delta.final (cxOf s) (coreOf s) (Delta.build (cxOf s) s (coreOf s) (s.raised ids)) c.needsAll
      c.needsAll.length (Counts.of (coreOf s).eff (Core.restsOn (cxOf s) (coreOf s)) c.needsAll)
      (fun d => (Index.ofKeys compare c.needsAll).count (cmp := compare) d)
      (!(Core.incompatible (cxOf s) s c).isEmpty) c.subject =
      (s.applySuccess ids).final c := by
  have := delta_final s (s.raised ids) c
    (Counts.of (coreOf s).eff (Core.restsOn (cxOf s) (coreOf s)) c.needsAll)
    (fun d => (Index.ofKeys compare c.needsAll).count (cmp := compare) d)
    (!(Core.incompatible (cxOf s) s c).isEmpty)
    (by rw [eff_eq, restsOn_eq]) (fun d _ => count_ofKeys _ d) (by rw [incompatible_eq])
  simp only [deltaOf] at this
  rw [this]; rfl

theorem isKey_iff (extra : Overrides) (j : String) :
    (deltaOf s extra).isKey j = true ↔ j ∈ (deltaOf s extra).keys := by
  show ((Index.ofKeys compare (deltaOf s extra).keys).first? (cmp := compare) j).isSome = true ↔ _
  have := mem_map (deltaOf s extra).keys (fun x => x) j
  simp only [List.map_id'] at this
  rw [this, List.contains_iff_mem]

theorem node_optimistic (c : Claim) (ids : List String) :
    let δ := deltaOf s (s.raised ids)
    let rests1 := fun (e : String → EStatus) (n : String) =>
      (e n).asserted && (!(cxOf s).mustVerify n || (e n).verified)
    ((Counts.of (coreOf s).eff1 (rests1 (coreOf s).eff1) c.needsAll).patch
      (occurrences c.needsAll c.needsAll.length δ.keys δ.keyCount
        (fun d => (Index.ofKeys compare c.needsAll).count (cmp := compare) d) δ.isKey)
      (coreOf s).eff1 δ.eff1 (rests1 (coreOf s).eff1) (rests1 δ.eff1)).state
      (!(Core.incompatible (cxOf s) s c).isEmpty) = (s.applySuccess ids).optimistic c := by
  intro δ rests1
  have hkeys : δ.keys.Nodup := by
    show (deltaOf s (s.raised ids)).keys.Nodup
    rw [delta_keys]; exact eraseDups_nodup _
  have hocc := occurrences_perm c.needsAll δ.keys hkeys _ (fun d _ => count_ofKeys _ d) δ.isKey
    (isKey_iff s (s.raised ids))
  have hkc : δ.keyCount = δ.keys.length := rfl
  rw [hkc, patch_eq _ _ _ _ c.needsAll _ δ.isKey hocc]
  · rw [counts_state, incompatible_eq, delta_eff1]
    simp only [rests1, mustVerify_eq]
    rfl
  · intro x _ hm
    have hx : x ∉ (s.raised ids).map (·.1) := by
      intro hx
      have : x ∈ δ.keys := by
        show x ∈ (deltaOf s (s.raised ids)).keys
        rw [delta_keys]; exact List.mem_eraseDups.mpr hx
      have h2 : δ.isKey x = true := (isKey_iff s (s.raised ids) x).mpr this
      rw [hm] at h2; cases h2
    rw [eff1_eq, show δ.eff1 = (afterOf s (s.raised ids)).eff1 from delta_eff1 s _,
      eff1_off_keys s _ hx]
  · intro x _ hm
    have hx : x ∉ (s.raised ids).map (·.1) := by
      intro hx
      have : x ∈ δ.keys := by
        show x ∈ (deltaOf s (s.raised ids)).keys
        rw [delta_keys]; exact List.mem_eraseDups.mpr hx
      have h2 : δ.isKey x = true := (isKey_iff s (s.raised ids) x).mpr this
      rw [hm] at h2; cases h2
    simp only [rests1]
    rw [eff1_eq, show δ.eff1 = (afterOf s (s.raised ids)).eff1 from delta_eff1 s _,
      eff1_off_keys s _ hx]

theorem mem_successEntries (k : String) (p : Nat) (st : Status) :
    (k, p, st) ∈ successEntries s.trace ↔
      ∃ h : p < s.trace.experiments.length, (k, st) ∈ s.trace.experiments[p].success := by
  unfold successEntries
  simp only [List.mem_flatMap, List.mem_map]
  constructor
  · rintro ⟨x, hx, ⟨⟨k', st'⟩, hm, heq⟩⟩
    simp only [Prod.mk.injEq] at heq
    obtain ⟨rfl, rfl, rfl⟩ := heq
    obtain ⟨hlt, hx'⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) hx
    exact ⟨hlt, by rw [← hx']; exact hm⟩
  · rintro ⟨hlt, hm⟩
    exact ⟨(s.trace.experiments[p], p), List.mem_zipIdx_iff_getElem?.mpr (by simp [hlt]),
      ⟨(k, st), hm, rfl⟩⟩

theorem touches_group (n : String) :
    (cxOf s).touches.group (cmp := compare) n =
      ((successEntries s.trace).zipIdx.filter fun x => x.1.1 == n).map (·.2) :=
  group_map (successEntries s.trace) (·.1) n

theorem mem_hits (c : Claim) (p : Nat) :
    p ∈ c.needsAll.flatMap (fun n => ((cxOf s).touches.group (cmp := compare) n).filterMap fun i =>
      ((cxOf s).entries[i]?).bind fun e => if (coreOf s).raises n e.2 then some e.1 else none) ↔
    ∃ h : p < s.trace.experiments.length, ∃ k st, (k, st) ∈ s.trace.experiments[p].success ∧
      k ∈ c.needsAll ∧ (coreOf s).raises k st = true := by
  simp only [List.mem_flatMap, List.mem_filterMap, touches_group]
  constructor
  · rintro ⟨n, hn, i, hi, hb⟩
    obtain ⟨⟨⟨k, q, st⟩, j⟩, hx, rfl⟩ := List.mem_map.mp hi
    obtain ⟨hxz, hkey⟩ := List.mem_filter.mp hx
    simp only [beq_iff_eq] at hkey
    subst hkey
    have hj := List.mem_zipIdx_iff_getElem?.mp hxz
    have hget : ((successEntries s.trace).map (·.2)).toArray[j]? = some (q, st) := by
      rw [List.getElem?_toArray, List.getElem?_map, hj]; rfl
    simp only [cxOf, ctx_entries, hget, Option.bind_some] at hb
    split at hb
    · rename_i hr
      obtain rfl : q = p := Option.some.inj hb
      obtain ⟨hlt, hsucc⟩ := (mem_successEntries s k q st).mp (List.mem_of_getElem? hj)
      exact ⟨hlt, k, st, hsucc, hn, hr⟩
    · cases hb
  · rintro ⟨hlt, k, st, hsucc, hk, hr⟩
    have hmem := (mem_successEntries s k p st).mpr ⟨hlt, hsucc⟩
    obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hmem
    refine ⟨k, hk, i, ?_, ?_⟩
    · exact List.mem_map.mpr ⟨((k, p, st), i), List.mem_filter.mpr
        ⟨List.mem_zipIdx_iff_getElem?.mpr hi, by simp⟩, rfl⟩
    · simp [cxOf, ctx_entries, List.getElem?_toArray, List.getElem?_map, hi, hr]

/-- `Scenario.relevant`'s test. -/
def relPred (c : Claim) (e : Experiment) : Bool :=
  e.subject == c.subject && e.success.any fun (k, st) =>
    c.needsAll.contains k && (EStatus.ofStatus st).strength > (s.eff1 k).strength

/-- The relevant positions = the positions whose experiment passes `Scenario.relevant`'s test. -/
theorem relPos_eq (c : Claim) :
    (raisingPositions (cxOf s) (coreOf s) c.needsAll).filter
        (fun p => ((cxOf s).experiments[p]?).any (·.subject == c.subject)) =
      (List.range s.trace.experiments.length).filter fun p =>
        (s.trace.experiments[p]?).any (relPred s c) := by
  unfold raisingPositions
  generalize hh : (c.needsAll.flatMap fun n => ((cxOf s).touches.group (cmp := compare) n).filterMap
    fun i => ((cxOf s).entries[i]?).bind fun e =>
      if (coreOf s).raises n e.2 then some e.1 else none) = hits
  have hmem : ∀ p, p ∈ hits ↔ ∃ h : p < s.trace.experiments.length, ∃ k st,
      (k, st) ∈ s.trace.experiments[p].success ∧ k ∈ c.needsAll ∧
        (coreOf s).raises k st = true := by
    intro p; rw [← hh]; exact mem_hits s c p
  have hlt : ∀ p ∈ hits, p < s.trace.experiments.length := fun p hp => ((hmem p).mp hp).1
  rw [ascending_eq hlt, List.filter_filter]
  apply List.filter_congr
  intro p hp
  have hp := List.mem_range.mp hp
  have hget : s.trace.experiments[p]? = some s.trace.experiments[p] :=
    List.getElem?_eq_getElem hp
  simp only [ctx_experiments, List.getElem?_toArray, hget, Option.any_some, relPred]
  congr 1
  apply Bool.eq_iff_iff.mpr
  rw [decide_eq_true_iff, hmem p, List.any_eq_true]
  constructor
  · rintro ⟨_, k, st, hm, hk, hr⟩
    refine ⟨(k, st), hm, ?_⟩
    rw [raises_eq] at hr
    simp only [Bool.and_eq_true, List.contains_iff_mem]
    exact ⟨hk, hr⟩
  · rintro ⟨⟨k, st⟩, hm, hb⟩
    simp only [Bool.and_eq_true, List.contains_iff_mem] at hb
    exact ⟨hp, k, st, hm, hb.1, by rw [raises_eq]; exact hb.2⟩

theorem relevant_read (c : Claim) :
    ((List.range s.trace.experiments.length).filter fun p =>
      (s.trace.experiments[p]?).any (relPred s c)).filterMap ((cxOf s).experiments[·]?) =
      s.relevant c := by
  show _ = s.trace.experiments.filter (relPred s c)
  rw [ctx_experiments, range_filter_eq s.trace.experiments, read_positions,
    ← zipIdx_filter_fst s.trace.experiments (relPred s c)]
  congr 1
  apply List.filter_congr
  rintro ⟨e, p⟩ hx
  obtain ⟨hp, he⟩ := List.mem_zipIdx' hx
  simp only [List.getElem?_eq_getElem hp, Option.any_some, he]

/-! ### Coverage: each experiment's first entry naming a need -/

/-- `firstPerRun`, recursively: an entry whose position differs from the previous one's. -/
def firstsFrom {β : Type} : Option Nat → List (Nat × β) → List (Nat × β)
  | _, [] => []
  | prev, (p, x) :: rest => (if prev != some p then [(p, x)] else []) ++ firstsFrom (some p) rest

theorem foldl_firsts {β : Type} : ∀ (l : List (Nat × β)) (acc : Array (Nat × β))
    (prev : Option Nat),
    (l.foldl (fun st x => (if st.2 != some x.1 then st.1.push x else st.1, some x.1))
      (acc, prev)).1.toList = acc.toList ++ firstsFrom prev l
  | [], _, _ => by simp [firstsFrom]
  | (p, x) :: rest, acc, prev => by
    simp only [List.foldl_cons, firstsFrom]
    rw [foldl_firsts rest]
    split <;> simp_all

theorem firstPerRun_eq (l : List (Nat × Status)) : firstPerRun l = firstsFrom none l := by
  simp only [firstPerRun, foldl_firsts, Array.toList_empty, List.nil_append]

theorem firstsFrom_skip {β : Type} (p : Nat) : ∀ (L : List β) (rest : List (Nat × β)),
    firstsFrom (some p) (L.map (p, ·) ++ rest) = firstsFrom (some p) rest
  | [], _ => rfl
  | x :: L, rest => by
    simp only [List.map_cons, List.cons_append, firstsFrom, bne_self_eq_false, Bool.false_eq_true,
      ite_false, List.nil_append]
    exact firstsFrom_skip p L rest

/-- Over groups at distinct positions: the head of each nonempty group. -/
theorem firstsFrom_groups {β : Type} : ∀ (G : List (Nat × List β)) (prev : Option Nat),
    (G.map (·.1)).Nodup → (∀ g ∈ G, prev ≠ some g.1) →
    firstsFrom prev (G.flatMap fun g => g.2.map (g.1, ·)) =
      G.filterMap fun g => g.2.head?.map (g.1, ·)
  | [], _, _, _ => rfl
  | (p, []) :: G, prev, hnd, hne => by
    simp only [List.flatMap_cons, List.map_nil, List.nil_append, List.filterMap_cons,
      List.head?_nil, Option.map_none]
    exact firstsFrom_groups G prev (List.nodup_cons.mp hnd).2
      (fun g hg => hne g (List.mem_cons_of_mem _ hg))
  | (p, x :: L) :: G, prev, hnd, hne => by
    have hp : prev ≠ some p := hne (p, x :: L) List.mem_cons_self
    simp only [List.flatMap_cons, List.map_cons, List.cons_append, firstsFrom, List.filterMap_cons,
      List.head?_cons, Option.map_some]
    rw [firstsFrom_skip, firstsFrom_groups G (some p) (List.nodup_cons.mp hnd).2]
    · simp [hp]
    · intro g hg h
      exact (List.nodup_cons.mp hnd).1 (List.mem_map.mpr ⟨g, hg, (Option.some.inj h).symm⟩)

theorem head_lookup {β : Type} (n : String) : ∀ l : List (String × β),
    ((l.filter fun x => x.1 == n).map (·.2)).head? = l.lookup n
  | [] => rfl
  | (k, b) :: l => by
    simp only [List.filter_cons, List.lookup_cons]
    by_cases h : k = n
    · subst h; simp
    · have h' : (n == k) = false := by simp; exact fun e => h e.symm
      simp [h, h', head_lookup n l]

theorem seen_eq (n : String) :
    ((cxOf s).touches.group (cmp := compare) n).filterMap ((cxOf s).entries[·]?) =
      ((successEntries s.trace).filter (·.1 == n)).map (·.2) := by
  rw [touches_group, List.filterMap_map]
  rw [filterMap_eq_map_of (g := fun x => x.1.2)]
  · have h := zipIdx_filter_fst (successEntries s.trace) (fun y => y.1 == n)
    rw [← h, List.map_map]
    rfl
  · intro x hx
    have := (List.mem_filter.mp hx).1
    rw [List.mem_zipIdx_iff_getElem?] at this
    simp [this]

/-- Per experiment: its position + the statuses of its success entries naming `n`. -/
def groupsOf (n : String) : List (Nat × List Status) :=
  s.trace.experiments.zipIdx.map fun (e, p) => (p, (e.success.filter (·.1 == n)).map (·.2))

theorem entries_groups (n : String) :
    ((successEntries s.trace).filter (·.1 == n)).map (·.2) =
      (groupsOf s n).flatMap fun g => g.2.map (g.1, ·) := by
  unfold successEntries groupsOf
  rw [List.filter_flatMap, List.map_flatMap, List.flatMap_map]
  congr 1
  funext x
  rw [List.filter_map, List.map_map, List.map_map]
  rfl

theorem groups_nodup (n : String) : ((groupsOf s n).map (·.1)).Nodup := by
  unfold groupsOf
  rw [List.map_map]
  have : ((fun x : Nat × List Status => x.1) ∘ fun (x : Experiment × Nat) =>
      (x.2, (x.1.success.filter (·.1 == n)).map (·.2))) = (·.2) := rfl
  rw [this, List.zipIdx_map_snd]
  exact List.nodup_range'

/-- `Scenario.coverage`'s alternatives for one need. -/
abbrev altsRef (c : Claim) (n : String) : List Alternative :=
  (s.relevant c).filterMap fun e =>
    match e.success.lookup n with
    | some st => if (EStatus.ofStatus st).strength > (s.eff1 n).strength then
        some { need := n, experiment := e.id, status := st } else none
    | none => none

abbrev relIxOf (c : Claim) : Index Nat :=
  Index.ofKeys compare ((List.range s.trace.experiments.length).filter fun p =>
    (s.trace.experiments[p]?).any (relPred s c))

theorem alternativesFor_eq (c : Claim) (n : String) :
    alternativesFor (cxOf s) (coreOf s) (relIxOf s c) n = altsRef s c n := by
  unfold alternativesFor
  rw [firstPerRun_eq, seen_eq, entries_groups,
    firstsFrom_groups _ none (groups_nodup s n) (fun _ _ h => by cases h), List.filterMap_filterMap]
  show _ = (s.trace.experiments.filter (relPred s c)).filterMap _
  rw [List.filterMap_filter, ← List.zipIdx_map_fst 0 s.trace.experiments, List.filterMap_map,
    groupsOf, List.filterMap_map]
  apply filterMap_congr'
  rintro ⟨e, p⟩ hx
  obtain ⟨hp, he⟩ := List.mem_zipIdx' hx
  have hrel : ((relIxOf s c).first? (cmp := compare) p).isSome = relPred s c e := by
    have := mem_map ((List.range s.trace.experiments.length).filter fun p =>
      (s.trace.experiments[p]?).any (relPred s c)) (fun x => x) p
    simp only [List.map_id'] at this
    rw [this, Bool.eq_iff_iff, List.contains_iff_mem, List.mem_filter, List.mem_range,
      List.getElem?_eq_getElem hp, Option.any_some, he]
    exact ⟨fun h => h.2, fun h => ⟨hp, h⟩⟩
  simp only [Function.comp_apply, head_lookup]
  cases hl : e.success.lookup n with
  | none => simp
  | some st =>
    simp only [Option.map_some, Option.bind_some, hrel, raises_eq, ctx_experiments,
      List.getElem?_toArray, List.getElem?_eq_getElem hp, ← he]
    cases relPred s c e <;> simp

theorem need_of_mem_alts {c : Claim} {n : String} {a : Alternative} (h : a ∈ altsRef s c n) :
    a.need = n := by
  obtain ⟨e, _, he⟩ := List.mem_filterMap.mp h
  split at he
  · split at he
    · cases he; rfl
    · cases he
  · cases he

theorem coverageOf_eq (c : Claim) :
    coverageOf (cxOf s) (coreOf s) c.needsAll (relIxOf s c) = s.coverage c := by
  unfold coverageOf Scenario.coverage premisesUnder gapsUnder Scenario.premises Scenario.gaps
  simp only [eff_eq, mustVerify_eq, alternativesFor_eq]
  congr 1
  · rw [List.filter_map, List.map_map]
    show List.map id _ = _
    rw [List.map_id]
    apply List.filter_congr
    intro n hn
    simp only [Function.comp_apply, List.any_flatMap]
    rw [Bool.eq_iff_iff]
    simp only [List.isEmpty_iff, Bool.not_eq_true', List.any_eq_false, List.any_eq_true,
      beq_iff_eq, not_exists, not_and]
    constructor
    · intro h m _ a ha hn'
      have hm : a.need = m := need_of_mem_alts s ha
      rw [← hn', hm] at h
      have ha' : a ∈ altsRef s c m := ha
      rw [h] at ha'; cases ha'
    · intro h
      cases hn' : altsRef s c n with
      | nil => rfl
      | cons a l =>
        have ha : a ∈ altsRef s c n := by rw [hn']; exact List.mem_cons_self
        exact absurd (need_of_mem_alts s ha) (h n hn a ha)
  · rw [List.flatMap_map]; rfl

theorem costWith_eq : costWith (cxOf s) = costOf s.trace := by
  funext ids
  unfold costWith costOf
  rw [ctx_L]
  rfl

theorem premisesUnder_eq (s' : Scenario) (h : s'.trace = s.trace) (c : Claim) :
    premisesUnder (cxOf s) s'.eff c.needsAll = s'.premises c := by
  unfold premisesUnder Scenario.premises
  rw [mustVerify_eq]
  unfold Scenario.mustVerify
  rw [h]

theorem gapsUnder_eq (s' : Scenario) (h : s'.trace = s.trace) (c : Claim) :
    gapsUnder (cxOf s) s'.eff c.needsAll = s'.gaps c := by
  unfold gapsUnder Scenario.gaps
  rw [mustVerify_eq]
  unfold Scenario.mustVerify
  rw [h]

theorem contingent_eq (p : List String) :
    (p.any fun id => (((cxOf s).L.experiment? id).map fun e =>
        e.success.any fun x => (cxOf s).isResult x.1).getD false) =
      (p.any fun id => ((s.trace.experiment? id).map fun e =>
        e.success.any fun (k, _) => s.resultFacts.contains k).getD false) := by
  rw [ctx_L]
  congr 1
  funext id
  show ((s.trace.experiment? id).map _).getD false = _
  congr 2
  funext e
  congr 1
  funext x
  rw [isResult_eq]
  rfl

theorem node_optimistic' (c : Claim) (ids : List String) :
    ((Counts.of (coreOf s).eff1 (fun n => ((coreOf s).eff1 n).asserted &&
        (!(cxOf s).mustVerify n || ((coreOf s).eff1 n).verified)) c.needsAll).patch
      (occurrences c.needsAll c.needsAll.length
        (Delta.build (cxOf s) s (coreOf s) (s.raised ids)).keys
        (Delta.build (cxOf s) s (coreOf s) (s.raised ids)).keyCount
        (fun d => (Index.ofKeys compare c.needsAll).count (cmp := compare) d)
        (Delta.build (cxOf s) s (coreOf s) (s.raised ids)).isKey)
      (coreOf s).eff1 (Delta.build (cxOf s) s (coreOf s) (s.raised ids)).eff1
      (fun n => ((coreOf s).eff1 n).asserted &&
        (!(cxOf s).mustVerify n || ((coreOf s).eff1 n).verified))
      (fun n => ((Delta.build (cxOf s) s (coreOf s) (s.raised ids)).eff1 n).asserted &&
        (!(cxOf s).mustVerify n ||
          ((Delta.build (cxOf s) s (coreOf s) (s.raised ids)).eff1 n).verified))).state
      (!(Core.incompatible (cxOf s) s c).isEmpty) = (s.applySuccess ids).optimistic c :=
  node_optimistic s c ids

theorem memoAt_eq {α : Type} {key : List String} {v : α} {f : List String → α}
    (h : v = f key) : memoAt key v f = f := by
  funext ids
  unfold memoAt
  split
  · next h' => rw [beq_iff_eq.mp h', h]
  · rfl

theorem plan_eq (closure : List String → List String) (hcl : closure = s.closure) (c : Claim) :
    planOf (cxOf s) closure s (coreOf s) c = s.plan c := by
  subst hcl
  unfold planOf Scenario.plan Scenario.best
  dsimp only
  rw [memoAt_eq
    (f := fun ids => Delta.build (cxOf s) s (coreOf s) (raisedBy (cxOf s) (coreOf s) ids)) rfl]
  rw [relPos_eq, relevant_read, coverageOf_eq, valid_eq, costWith_eq, final_eq]
  simp only [raised_eq, node_valid, node_final, node_optimistic']
  rw [searchWith_eq s c _ _ _ (fun _ => rfl) (fun _ => rfl) (fun _ => rfl)]
  generalize s.search c [] (List.map (fun x => x.id) (s.relevant c)) [] = P
  have h1 : (Delta.build (cxOf s) s (coreOf s) (s.raised P)).eff = (s.applySuccess P).eff :=
    delta_eff s (s.raised P)
  rw [h1, premisesUnder_eq s (s.applySuccess P) rfl, gapsUnder_eq s (s.applySuccess P) rfl,
    contingent_eq]

end Plans

end Fvtrace.Proofs.Answers
