import Fvtrace.Answers.Fast
import Fvtrace.Proofs.Lookups

/-! Positions + counts behind `Fvtrace.Answers.Fast` (`kernel.md` P-delta): an index answer is a
filtered range of positions; reading a list at such positions, then filtering, equals filtering
the list; a count patched over the moved occurrences equals the count recomputed. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false
set_option linter.unusedSectionVars false

namespace Fvtrace.Proofs.Positions
open Fvtrace Fvtrace.Answers Fvtrace.Proofs.Index Fvtrace.Proofs.Lookups

/-! ## Increasing position lists -/

/-- Two strictly increasing lists with the same members are equal. -/
theorem eq_of_increasing {a b : List Nat} (ha : a.Pairwise (· < ·)) (hb : b.Pairwise (· < ·))
    (hm : ∀ x, x ∈ a ↔ x ∈ b) : a = b := by
  have hp : a.Perm b := (List.perm_ext_iff_of_nodup (ha.imp Nat.ne_of_lt)
    (hb.imp Nat.ne_of_lt)).mpr hm
  exact hp.eq_of_pairwise (le := (· ≤ ·)) (fun x y _ _ h1 h2 => Nat.le_antisymm h1 h2)
    (ha.imp Nat.le_of_lt) (hb.imp Nat.le_of_lt)

theorem range_filter_increasing (n : Nat) (q : Nat → Bool) :
    ((List.range n).filter q).Pairwise (· < ·) :=
  (List.pairwise_lt_range).sublist List.filter_sublist

/-- A strictly increasing list of positions below `n` = the range filtered by membership. -/
theorem increasing_eq_range {P : List Nat} {n : Nat} (hP : P.Pairwise (· < ·))
    (hn : ∀ x ∈ P, x < n) : P = (List.range n).filter (fun i => decide (i ∈ P)) := by
  apply eq_of_increasing hP (range_filter_increasing n _)
  intro x
  simp only [List.mem_filter, List.mem_range, decide_eq_true_eq]
  exact ⟨fun h => ⟨hn x h, h⟩, fun h => h.2⟩

/-- The reference behind `dedupSorted`: a run of equal neighbours kept once. -/
def dedupRef : Option Nat → List Nat → List Nat
  | _, [] => []
  | last, p :: ps => if last == some p then dedupRef last ps else p :: dedupRef (some p) ps

theorem dedup_fold (l : List Nat) (acc : Array Nat) (last : Option Nat) :
    (l.foldl (init := (acc, last)) fun (acc, last) p =>
        if last == some p then (acc, last) else (acc.push p, some p)).1.toList =
      acc.toList ++ dedupRef last l := by
  induction l generalizing acc last with
  | nil => simp [dedupRef]
  | cons p ps ih =>
    simp only [List.foldl_cons, dedupRef]
    split
    · exact ih acc last
    · rw [ih]; simp

theorem dedupSorted_eq (l : List Nat) : dedupSorted l = dedupRef none l := by
  unfold dedupSorted
  rw [dedup_fold]
  simp

theorem mem_dedupRef : ∀ {l : List Nat} {last : Option Nat} {x : Nat},
    x ∈ dedupRef last l → x ∈ l
  | [], _, _, h => by simp [dedupRef] at h
  | p :: ps, last, x, h => by
    simp only [dedupRef] at h
    split at h
    · exact List.mem_cons_of_mem _ (mem_dedupRef h)
    · rcases List.mem_cons.mp h with rfl | h
      · exact List.mem_cons_self
      · exact List.mem_cons_of_mem _ (mem_dedupRef h)

/-- On a sorted list whose members are not below `last`, the run of `last` drops, the rest
stays. -/
theorem dedupRef_spec : ∀ {l : List Nat} {last : Option Nat},
    l.Pairwise (· ≤ ·) → (∀ x ∈ l, ∀ y, last = some y → y ≤ x) →
    (dedupRef last l).Pairwise (· < ·) ∧
      (∀ x, x ∈ dedupRef last l ↔ x ∈ l ∧ last ≠ some x) ∧
      (∀ x ∈ dedupRef last l, ∀ y, last = some y → y < x)
  | [], _, _, _ => by simp [dedupRef]
  | p :: ps, last, hs, hl => by
    rw [List.pairwise_cons] at hs
    simp only [dedupRef]
    split
    · rename_i heq
      have hlast : last = some p := by simpa using heq
      have ih := dedupRef_spec (l := ps) (last := last) hs.2 (fun x hx y hy => by
        rw [hlast] at hy; cases hy; exact hs.1 x hx)
      refine ⟨ih.1, fun x => ?_, ih.2.2⟩
      rw [ih.2.1]
      constructor
      · rintro ⟨h1, h2⟩; exact ⟨List.mem_cons_of_mem _ h1, h2⟩
      · rintro ⟨h1, h2⟩
        rcases List.mem_cons.mp h1 with rfl | h1
        · exact absurd hlast h2
        · exact ⟨h1, h2⟩
    · rename_i hne
      have hne' : last ≠ some p := by simpa using hne
      have ih := dedupRef_spec (l := ps) (last := some p) hs.2 (fun x hx y hy => by
        cases hy; exact hs.1 x hx)
      refine ⟨List.pairwise_cons.mpr ⟨fun x hx => ih.2.2 x hx p rfl, ih.1⟩, fun x => ?_, ?_⟩
      · simp only [List.mem_cons, ih.2.1]
        constructor
        · rintro (rfl | ⟨h1, h2⟩)
          · exact ⟨Or.inl rfl, hne'⟩
          · refine ⟨Or.inr h1, fun h => ?_⟩
            have h3 := hl p List.mem_cons_self x h
            have h4 := hs.1 x h1
            exact h2 (by rw [show x = p by omega])
        · rintro ⟨rfl | h1, h2⟩
          · exact Or.inl rfl
          · by_cases hxp : x = p
            · exact Or.inl hxp
            · exact Or.inr ⟨h1, fun h => hxp (by cases h; rfl)⟩
      · intro x hx y hy
        rcases List.mem_cons.mp hx with rfl | hx
        · have := hl x List.mem_cons_self y hy
          rcases Nat.lt_or_eq_of_le this with h | h
          · exact h
          · subst h; exact absurd hy hne'
        · have h1 := ih.2.2 x hx p rfl
          have h2 := hl p List.mem_cons_self y hy
          omega

/-- `dedupSorted` of a sorted list: its members, increasing, each once. -/
theorem dedupSorted_spec {l : List Nat} (hs : l.Pairwise (· ≤ ·)) :
    (dedupSorted l).Pairwise (· < ·) ∧ ∀ x, x ∈ dedupSorted l ↔ x ∈ l := by
  rw [dedupSorted_eq]
  have := dedupRef_spec (last := none) hs (fun _ _ _ h => by cases h)
  exact ⟨this.1, fun x => by rw [this.2.1]; simp⟩

theorem ascending_spec (l : List Nat) :
    (ascending l).Pairwise (· < ·) ∧ ∀ x, x ∈ ascending l ↔ x ∈ l := by
  unfold ascending
  have hs : (l.mergeSort fun a b => decide (a ≤ b)).Pairwise (· ≤ ·) := by
    have := List.pairwise_mergeSort (le := fun a b : Nat => decide (a ≤ b))
      (fun a b c hab hbc => by simp at *; omega) (fun a b => by simp; omega) l
    exact this.imp fun h => by simpa using h
  obtain ⟨h1, h2⟩ := dedupSorted_spec hs
  exact ⟨h1, fun x => by rw [h2]; exact List.mem_mergeSort⟩

/-- `ascending` = the range filtered by membership. -/
theorem ascending_eq {l : List Nat} {n : Nat} (hn : ∀ x ∈ l, x < n) :
    ascending l = (List.range n).filter (fun i => decide (i ∈ l)) := by
  obtain ⟨h1, h2⟩ := ascending_spec l
  rw [increasing_eq_range h1 (fun x hx => hn x ((h2 x).mp hx))]
  congr 1
  funext i
  simp [h2]

/-- `dedupSorted` of a sorted list = the range filtered by membership. -/
theorem dedupSorted_eq_range {l : List Nat} {n : Nat} (hs : l.Pairwise (· ≤ ·))
    (hn : ∀ x ∈ l, x < n) : dedupSorted l = (List.range n).filter (fun i => decide (i ∈ l)) := by
  obtain ⟨h1, h2⟩ := dedupSorted_spec hs
  rw [increasing_eq_range h1 (fun x hx => hn x ((h2 x).mp hx))]
  congr 1
  funext i
  simp [h2]

/-! ## Reading a list at filtered positions -/

section Read

variable {α : Type}

theorem filterMap_congr' {β γ : Type} {f g : β → Option γ} :
    ∀ {L : List β}, (∀ x ∈ L, f x = g x) → L.filterMap f = L.filterMap g
  | [], _ => rfl
  | x :: xs, h => by
    simp only [List.filterMap_cons, h x List.mem_cons_self,
      filterMap_congr' (L := xs) (fun y hy => h y (List.mem_cons_of_mem _ hy))]

theorem filterMap_eq_map_of {β γ : Type} {f : β → Option γ} {g : β → γ} :
    ∀ {L : List β}, (∀ x ∈ L, f x = some (g x)) → L.filterMap f = L.map g
  | [], _ => rfl
  | x :: xs, h => by
    simp only [List.filterMap_cons, List.map_cons, h x List.mem_cons_self,
      filterMap_eq_map_of (L := xs) (fun y hy => h y (List.mem_cons_of_mem _ hy))]

/-- An index over a list's keys: the positions holding key `k`, ascending. -/
theorem group_map (l : List α) (key : α → String) (k : String) :
    (Index.ofKeys compare (l.map key)).group (cmp := compare) k =
      (l.zipIdx.filter fun x => key x.1 == k).map (·.2) := by
  rw [group_ofKeys, List.zipIdx_map, List.filter_map, List.map_map]
  congr 1
  apply List.filter_congr
  intro x _
  simp only [Function.comp_apply, Prod.map_fst]
  exact cmp_beq _ _

theorem mem_positions {α : Type} {l : List α} {q : α → Bool} {p : Nat} :
    p ∈ (l.zipIdx.filter fun x => q x.1).map (·.2) ↔ ∃ h : p < l.length, q l[p] = true := by
  simp only [List.mem_map, List.mem_filter]
  constructor
  · rintro ⟨x, ⟨hx, hq⟩, rfl⟩
    obtain ⟨hlt, heq⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) hx
    exact ⟨hlt, by rw [← heq]; exact hq⟩
  · rintro ⟨h, hq⟩
    exact ⟨(l[p], p), ⟨List.mem_zipIdx_iff_getElem?.mpr (by simp [h]), hq⟩, rfl⟩

/-- Positions read back: the items at those positions. -/
theorem read_positions (l : List α) (q : α × Nat → Bool) :
    ((l.zipIdx.filter q).map (·.2)).filterMap (l.toArray[·]?) = (l.zipIdx.filter q).map (·.1) := by
  rw [List.filterMap_map]
  apply filterMap_eq_map_of
  intro x hx
  have := (List.mem_filter.mp hx).1
  rw [List.mem_zipIdx_iff_getElem?] at this
  simp [this]

/-- A filter of the list = the same filter of the items at any superset of its positions. -/
theorem filter_positions (l : List α) (q : α × Nat → Bool) (p : α → Bool)
    (hq : ∀ x ∈ l.zipIdx, p x.1 = true → q x = true) :
    ((l.zipIdx.filter q).map (·.1)).filter p = l.filter p := by
  rw [List.filter_map, List.filter_filter]
  have : (l.zipIdx.filter fun y => (p ∘ Prod.fst) y && q y) = l.zipIdx.filter (p ∘ Prod.fst) := by
    apply List.filter_congr
    intro y hy
    simp only [Function.comp_apply]
    cases hp : p y.1
    · simp
    · simp [hq y hy hp]
  rw [this, ← List.filter_map, List.zipIdx_map_fst]

/-- The same for `filterMap`: positions outside the superset map to `none`. -/
theorem filterMap_positions {β : Type} (l : List α) (q : α × Nat → Bool) (f : α → Option β)
    (hq : ∀ x ∈ l.zipIdx, (f x.1).isSome = true → q x = true) :
    ((l.zipIdx.filter q).map (·.1)).filterMap f = l.filterMap f := by
  rw [List.filterMap_map, List.filterMap_filter]
  have : (l.zipIdx.filterMap fun x => if q x then (f ∘ Prod.fst) x else none) =
      l.zipIdx.filterMap (f ∘ Prod.fst) := by
    apply filterMap_congr'
    intro x hx
    cases hf : f x.1 with
    | none => simp [hf]
    | some v => simp [hf, hq x hx (by simp [hf])]
  rw [this, ← List.filterMap_map, List.zipIdx_map_fst]

/-- The items of the zipIdx pairs passing a test on the item = the filtered list. -/
theorem zipIdx_filter_fst (l : List α) (q : α → Bool) :
    (l.zipIdx.filter fun x => q x.1).map (·.1) = l.filter q := by
  have h : (l.zipIdx.filter fun x => q x.1) = l.zipIdx.filter (q ∘ Prod.fst) := rfl
  rw [h, ← List.filter_map, List.zipIdx_map_fst]

/-- A range filtered by `r` = the zipIdx positions filtered by `r`. -/
theorem range_filter_eq (l : List α) (r : Nat → Bool) :
    (List.range l.length).filter r = (l.zipIdx.filter fun x => r x.2).map (·.2) := by
  have h1 : (l.zipIdx.filter fun x => r x.2).map (·.2) = (l.zipIdx.map (·.2)).filter r := by
    rw [List.filter_map]; rfl
  rw [h1, List.zipIdx_map_snd, List.range_eq_range']

end Read

/-! ## Counts patched over the moved occurrences -/

/-- A count over `l` after its moved members change test (`f` → `g`, equal elsewhere) = the old
count, plus the new count over the moved occurrences `occ`, minus their old count. -/
theorem countP_patch {α : Type} {l occ : List α} {f g moved : α → Bool}
    (hocc : occ.Perm (l.filter moved)) (hfg : ∀ x ∈ l, moved x = false → f x = g x) :
    l.countP g = l.countP f + occ.countP g - occ.countP f := by
  have hg := List.countP_eq_countP_filter_add l g moved
  have hf := List.countP_eq_countP_filter_add l f moved
  have hrest : (l.filter fun a => !moved a).countP g = (l.filter fun a => !moved a).countP f := by
    apply List.countP_congr
    intro x hx
    have := List.mem_filter.mp hx
    rw [hfg x this.1 (by simpa using this.2)]
  rw [hocc.countP_eq g, hocc.countP_eq f]
  omega

theorem sum_single {β : Type} [BEq β] [LawfulBEq β] (a : β) (g : β → Nat) :
    ∀ {L : List β}, L.Nodup → (L.map fun d => if d == a then g d else 0).sum =
      if a ∈ L then g a else 0
  | [], _ => by simp
  | d :: ds, hnd => by
    rw [List.nodup_cons] at hnd
    have ih := sum_single a g hnd.2
    simp only [List.map_cons, List.sum_cons, ih, List.mem_cons]
    by_cases hd : d = a
    · subst hd; simp [hnd.1]
    · have : (d == a) = false := by simpa using hd
      simp only [this, Bool.false_eq_true, ite_false, Nat.zero_add]
      by_cases ha : a ∈ ds
      · simp [ha]
      · simp [ha, Ne.symm hd]

theorem occurrences_perm (needs moved : List String) (hnd : moved.Nodup) (times : String → Nat)
    (htimes : ∀ d ∈ moved, times d = needs.count d) (isMoved : String → Bool)
    (hm : ∀ x, isMoved x = true ↔ x ∈ moved) :
    (occurrences needs needs.length moved moved.length times isMoved).Perm
      (needs.filter isMoved) := by
  unfold occurrences
  split
  · rw [List.perm_iff_count]
    intro a
    rw [List.count_flatMap]
    have hsum : (moved.map (List.count a ∘ fun d => List.replicate (times d) d)).sum =
        (moved.map fun d => if d == a then times d else 0).sum := by
      congr 1
      apply List.map_congr_left
      intro d _
      simp [List.count_replicate]
    rw [hsum, sum_single a times hnd]
    by_cases ha : a ∈ moved
    · simp only [ha, ↓reduceIte]
      rw [htimes a ha]
      exact (List.count_filter ((hm a).mpr ha)).symm
    · simp only [ha, ↓reduceIte]
      symm
      rw [List.count_eq_zero]
      intro hmem
      exact ha ((hm a).mp (List.mem_filter.mp hmem).2)
  · exact List.Perm.refl _

end Fvtrace.Proofs.Positions
