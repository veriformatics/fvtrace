import Fvtrace.Spec.Fast
import Fvtrace.Proofs.Index

/-! `Lookups.fast t = Lookups.reference t` (`kernel.md` P-claims `LookupsAgree`): each index
answer equals the original expression over the trace's lists. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false
set_option linter.unusedSectionVars false

namespace Fvtrace.Proofs.Lookups
open Fvtrace Fvtrace.Proofs.Index

attribute [local instance] lexOrd

/-! ## The reference record, field by field (simp lemmas for proofs over `Lookups.reference`) -/

section Reference

variable (t : Trace)

@[simp] theorem ref_fact? : (Lookups.reference t).fact? = t.fact? := rfl
@[simp] theorem ref_subject? : (Lookups.reference t).subject? = t.subject? := rfl
@[simp] theorem ref_claim? : (Lookups.reference t).claim? = t.claim? := rfl
@[simp] theorem ref_experiment? : (Lookups.reference t).experiment? = t.experiment? := rfl
@[simp] theorem ref_factSubject? : (Lookups.reference t).factSubject? = t.factSubject? := rfl
@[simp] theorem ref_hasQuestion (id : String) :
    (Lookups.reference t).hasQuestion id = t.questionIds.contains id := rfl
@[simp] theorem ref_hasSubject (id : String) :
    (Lookups.reference t).hasSubject id = t.subjectIds.contains id := rfl
@[simp] theorem ref_hasFact (id : String) :
    (Lookups.reference t).hasFact id = t.factIds.contains id := rfl
@[simp] theorem ref_hasClaim (id : String) :
    (Lookups.reference t).hasClaim id = t.claimIds.contains id := rfl
@[simp] theorem ref_hasExperiment (id : String) :
    (Lookups.reference t).hasExperiment id = t.experimentIds.contains id := rfl
@[simp] theorem ref_idsNodup : (Lookups.reference t).idsNodup () = decide t.allIds.Nodup := rfl
@[simp] theorem ref_soleEntailment (e c : String) : (Lookups.reference t).soleEntailment e c =
    t.claims.all fun d => d.entailment != some e || d.id == c := rfl
@[simp] theorem ref_soleRestater (needs : List String) (c : String) :
    (Lookups.reference t).soleRestater needs c =
      t.claims.all fun d => !d.restates || d.needs != needs || d.id == c := rfl
@[simp] theorem ref_earlierExperiment (i : Nat) (r s : String) :
    (Lookups.reference t).earlierExperiment i r s =
      (t.experiments.take i).any fun d => d.id == r && d.subject == s := rfl
@[simp] theorem ref_earlierPair (i : Nat) (x : Exclusion) :
    (Lookups.reference t).earlierPair i x = (t.exclusions.take i).any (Check.samePair x) := rfl
@[simp] theorem ref_waiversNodup :
    (Lookups.reference t).waiversNodup () =
      decide (t.waivers.map fun w => (w.rule, w.claim)).Nodup := rfl
@[simp] theorem ref_nodup (l : List String) : (Lookups.reference t).nodup l = decide l.Nodup := rfl

end Reference

/-! ## Lists -/

theorem findIdx?_bind {α : Type} {p : α → Bool} :
    ∀ {l : List α}, (l.findIdx? p).bind (fun i => l[i]?) = l.find? p
  | [] => rfl
  | x :: xs => by
    rw [List.findIdx?_cons, List.find?_cons]
    by_cases hx : p x = true
    · simp [hx]
    · simp only [hx, Bool.false_eq_true, ite_false, Option.bind_map]
      rw [← findIdx?_bind (l := xs)]
      rfl

theorem findIdx?_any_lt {α : Type} {p : α → Bool} :
    ∀ {l : List α} {i : Nat}, (l.findIdx? p).any (· < i) = (l.take i).any p
  | [], _ => by simp
  | x :: xs, 0 => by
    cases h : p x <;> simp [List.findIdx?_cons, h]
  | x :: xs, i + 1 => by
    rw [List.findIdx?_cons, List.take_succ_cons, List.any_cons]
    by_cases hx : p x = true
    · simp [hx]
    · simp only [hx, Bool.false_eq_true, ite_false, Bool.false_or, Option.any_map]
      rw [← findIdx?_any_lt (l := xs) (i := i)]
      cases xs.findIdx? p <;> simp

/-- Equal counts of a filter and its refinement: the refinement holds throughout. -/
theorem length_filter_beq {α : Type} (l : List α) (p q : α → Bool) :
    ((l.filter p).length == (l.filter fun x => p x && q x).length) =
      l.all fun x => !p x || q x := by
  have hpq : l.filter (fun x => p x && q x) = (l.filter p).filter q := by
    rw [List.filter_filter]; congr 1; funext x; exact Bool.and_comm _ _
  rw [hpq, Bool.eq_iff_iff, beq_iff_eq]
  constructor
  · intro h
    have := List.length_filter_eq_length_iff.mp h.symm
    simp only [List.all_eq_true, Bool.or_eq_true, Bool.not_eq_true']
    intro x hx
    cases hp : p x
    · exact Or.inl rfl
    · exact Or.inr (this x (List.mem_filter.mpr ⟨hx, hp⟩))
  · intro h
    simp only [List.all_eq_true, Bool.or_eq_true, Bool.not_eq_true'] at h
    refine (List.length_filter_eq_length_iff.mpr fun x hx => ?_).symm
    obtain ⟨hxl, hpx⟩ := List.mem_filter.mp hx
    rcases h x hxl with h1 | h1
    · rw [h1] at hpx; cases hpx
    · exact h1

/-! ## Index answers over a list -/

section Keys

variable {α κ : Type} [Ord κ] [Std.TransOrd κ] [Std.LawfulEqOrd κ] [BEq κ] [LawfulBEq κ]

theorem cmp_beq (a b : κ) : (compare a b == .eq) = (a == b) := by
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq, Std.LawfulEqCmp.compare_eq_iff_eq]

theorem first?_map (l : List α) (key : α → κ) (k : κ) :
    (Index.ofKeys compare (l.map key)).first? (cmp := compare) k = l.findIdx? (key · == k) := by
  rw [first?_ofKeys, List.findIdx?_map]
  congr 1
  funext x
  exact cmp_beq _ _

theorem find?_map (l : List α) (key : α → κ) (k : κ) :
    ((Index.ofKeys compare (l.map key)).first? (cmp := compare) k).bind (l.toArray[·]?) =
      l.find? (key · == k) := by
  rw [first?_map]
  simp only [List.getElem?_toArray]
  exact findIdx?_bind

theorem mem_map (l : List α) (key : α → κ) (k : κ) :
    ((Index.ofKeys compare (l.map key)).first? (cmp := compare) k).isSome =
      (l.map key).contains k := by
  rw [first?_map, List.findIdx?_isSome, List.contains_eq_any_beq, List.any_map]
  congr 1
  funext x
  simp only [Function.comp_apply]
  rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq]
  exact eq_comm

/-- The pairs `keyed` builds, read back: those with key `k`, by position. -/
theorem keyed_filter (key : α → Option κ) (k : κ) :
    ∀ (l : List α) (n : Nat),
      (((l.zipIdx n).filterMap fun p => (key p.1).map (·, p.2)).filter (Is compare k)) =
        ((l.zipIdx n).filter fun p => key p.1 == some k).map fun p => (k, p.2)
  | [], _ => rfl
  | x :: xs, n => by
    rw [List.zipIdx_cons, List.filterMap_cons, List.filter_cons]
    have ih := keyed_filter key k xs (n + 1)
    cases hx : key x with
    | none => simpa [hx] using ih
    | some k' =>
      by_cases hk : k' = k
      · subst hk
        simp [hx, Is, Std.ReflCmp.compare_self, ih]
      · have hne : (compare k' k == .eq) = false := by
          rw [cmp_beq]; simpa using hk
        simp [hx, Is, hne, hk, ih]

theorem keyed_count (l : List α) (key : α → Option κ) (k : κ) :
    (Index.build compare (Lookups.keyed l key)).count (cmp := compare) k =
      (l.filter fun x => key x == some k).length := by
  rw [count_build, Lookups.keyed, keyed_filter, List.length_map]
  have : ∀ n, ((l.zipIdx n).filter fun p => key p.1 == some k).length =
      (l.filter fun x => key x == some k).length := by
    intro n
    induction l generalizing n with
    | nil => rfl
    | cons x xs ih =>
      rw [List.zipIdx_cons, List.filter_cons, List.filter_cons]
      split <;> simp [ih]
  exact this 0

theorem zipIdx_first {q : α → Bool} :
    ∀ (l : List α) (n : Nat),
      ((l.zipIdx n).filter fun p => q p.1).head?.map (·.2) = (l.findIdx? q).map (· + n)
  | [], _ => rfl
  | x :: xs, n => by
    rw [List.zipIdx_cons, List.filter_cons, List.findIdx?_cons]
    by_cases hx : q x = true
    · simp [hx]
    · simp only [hx, Bool.false_eq_true, ite_false]
      rw [zipIdx_first xs (n + 1), Option.map_map]
      congr 1
      funext i
      simp only [Function.comp_apply]
      omega

theorem keyed_first (l : List α) (key : α → Option κ) (k : κ) :
    (Index.build compare (Lookups.keyed l key)).first? (cmp := compare) k =
      l.findIdx? (key · == some k) := by
  rw [first?_build, Lookups.keyed, ← List.head?_filter, keyed_filter, List.head?_map,
    Option.map_map]
  have := zipIdx_first (q := (key · == some k)) l 0
  simpa [Function.comp_def] using this

theorem keyed_find (l : List α) (key : α → Option κ) (k : κ) :
    ((Index.build compare (Lookups.keyed l key)).first? (cmp := compare) k).bind (l.toArray[·]?) =
      l.find? (key · == some k) := by
  rw [keyed_first]
  simp only [List.getElem?_toArray]
  exact findIdx?_bind

end Keys

/-! ## The record -/

/-- A pair with the smaller id first. -/
theorem norm_eq_iff (p q : String × String) :
    (if q.1 ≤ q.2 then q else q.swap) = (if p.1 ≤ p.2 then p else p.swap) ↔ p = q ∨ p = q.swap := by
  obtain ⟨a, b⟩ := p
  obtain ⟨c, d⟩ := q
  simp only [Prod.swap_prod_mk]
  by_cases hab : a ≤ b <;> by_cases hcd : c ≤ d <;> simp only [hab, hcd, ite_true, ite_false,
    Prod.mk.injEq]
  · constructor
    · rintro ⟨rfl, rfl⟩; exact Or.inl ⟨rfl, rfl⟩
    · rintro (⟨rfl, rfl⟩ | ⟨rfl, rfl⟩)
      · exact ⟨rfl, rfl⟩
      · have := String.le_antisymm hab hcd; subst this; exact ⟨rfl, rfl⟩
  · have hdc : d ≤ c := (String.le_total c d).resolve_left hcd
    constructor
    · rintro ⟨rfl, rfl⟩; exact Or.inr ⟨rfl, rfl⟩
    · rintro (⟨rfl, rfl⟩ | ⟨rfl, rfl⟩)
      · exact absurd hab hcd
      · exact ⟨rfl, rfl⟩
  · have hba : b ≤ a := (String.le_total a b).resolve_left hab
    constructor
    · rintro ⟨rfl, rfl⟩; exact Or.inr ⟨rfl, rfl⟩
    · rintro (⟨rfl, rfl⟩ | ⟨rfl, rfl⟩)
      · exact absurd hcd hab
      · exact ⟨rfl, rfl⟩
  · have hba : b ≤ a := (String.le_total a b).resolve_left hab
    have hdc : d ≤ c := (String.le_total c d).resolve_left hcd
    constructor
    · rintro ⟨rfl, rfl⟩; exact Or.inl ⟨rfl, rfl⟩
    · rintro (⟨rfl, rfl⟩ | ⟨rfl, rfl⟩)
      · exact ⟨rfl, rfl⟩
      · exact absurd hba hcd

theorem samePair_key (x y : Exclusion) :
    Check.samePair x y = (compare (Lookups.pairKey y) (Lookups.pairKey x) == .eq) := by
  rw [cmp_beq, Bool.eq_iff_iff]
  simp only [Check.samePair, Lookups.pairKey, Bool.and_eq_true, beq_iff_eq, Bool.or_eq_true,
    Prod.mk.injEq]
  rw [norm_eq_iff]
  constructor
  · rintro ⟨h1, h2⟩; exact ⟨h1.symm, h2⟩
  · rintro ⟨h1, h2⟩; exact ⟨h1.symm, h2⟩

theorem map_pair_beq {α β : Type} [BEq α] [LawfulBEq α] [BEq β] [LawfulBEq β] (o : Option α)
    (b : β) (e : α) (c : β) : (o.map (·, b) == some (e, c)) = (o == some e && b == c) := by
  cases o with
  | none => simp
  | some v => rfl

theorem restatedOne_beq (c : Claim) (f : String) :
    (Lookups.restatedOne c == some f) = (c.restates && c.needs == [f]) := by
  unfold Lookups.restatedOne
  cases hr : c.restates
  · simp
  · rcases hn : c.needs with _ | ⟨n, _ | ⟨m, rest⟩⟩ <;> simp

theorem cmp_beq_comm (x y : String) : (compare y x == .eq) = (x == y) := by
  rw [cmp_beq, Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq]; exact eq_comm

/-- `LookupsAgree`: every index answer = the original expression over the trace's lists. -/
@[simp] theorem thunk_get_mk {α : Type} (f : Unit → α) : (Thunk.mk f).get = f () := rfl

theorem fast_eq_reference (t : Trace) : Lookups.fast t = Lookups.reference t := by
  simp only [Lookups.fast, Lookups.reference, thunk_get_mk]
  congr 1
  · funext id; exact find?_map t.facts (·.id) id
  · funext id; exact find?_map t.subjects (·.id) id
  · funext id; exact find?_map t.claims (·.id) id
  · funext id; exact find?_map t.experiments (·.id) id
  · funext id; exact mem_map t.questions (·.id) id
  · funext id; exact mem_map t.subjects (·.id) id
  · funext id; exact mem_map t.facts (·.id) id
  · funext id; exact mem_map t.claims (·.id) id
  · funext id; exact mem_map t.experiments (·.id) id
  · funext u; exact nodup_eq _
  · funext u
    rw [eraseDups_eq]
    congr 1
    unfold Check.duplicates
    congr 1
    apply List.filter_congr
    rintro ⟨x, i⟩ _
    simp only
    rw [first?_ofKeys, findIdx?_any_lt, List.contains_eq_any_beq]
    congr 1
    funext y
    exact cmp_beq_comm x y
  · funext e c
    rw [keyed_count, keyed_count]
    have : (fun d : Claim => d.entailment.map (·, d.id) == some (e, c)) =
        fun d => d.entailment == some e && d.id == c := by
      funext d; exact map_pair_beq _ _ _ _
    rw [this, length_filter_beq]
    rfl
  · funext needs c
    rw [keyed_count, keyed_count]
    have h1 : (fun d : Claim => (if d.restates then some d.needs else none) == some needs) =
        fun d => d.restates && d.needs == needs := by
      funext d; cases d.restates <;> simp
    have h2 : (fun d : Claim => (if d.restates then some (d.needs, d.id) else none) ==
        some (needs, c)) = fun d => (d.restates && d.needs == needs) && d.id == c := by
      funext d; cases d.restates
      · simp
      · rfl
    rw [h1, h2, length_filter_beq]
    congr 1
    funext d
    cases d.restates <;> simp [bne]
  · funext i r s
    rw [first?_map, findIdx?_any_lt]
    rfl
  · funext i x
    rw [first?_ofKeys, List.findIdx?_map, findIdx?_any_lt]
    congr 1
    funext y
    exact (samePair_key x y).symm
  · funext u; exact nodup_eq _
  · funext rule c
    rw [show ((Index.ofKeys compare (t.waivers.map fun w => (w.rule, w.claim))).first?
        (cmp := compare) (rule, c)).bind (fun p => t.waivers.toArray[p]?.map (·.reason)) =
      (((Index.ofKeys compare (t.waivers.map fun w => (w.rule, w.claim))).first?
        (cmp := compare) (rule, c)).bind (t.waivers.toArray[·]?)).map (·.reason) from by
      rw [Option.map_bind]; rfl]
    rw [find?_map]
    rfl
  · funext e; exact keyed_find t.claims (·.entailment) e
  · funext f
    rw [keyed_find]
    congr 1
    funext c
    exact restatedOne_beq c f
  · funext l; exact nodup_eq l

theorem bindingIndex_find (bindings : List Receipt.Binding) :
    (Receipt.BindingIndex.of bindings).find = fun id => bindings.find? (·.id == id) := by
  funext id
  exact find?_map bindings (·.id) id

theorem lookupsAgree : Spec.LookupsAgree := ⟨fast_eq_reference, bindingIndex_find⟩

end Fvtrace.Proofs.Lookups
