import Fvtrace.Index

/-! What `Fvtrace.Index` answers (`kernel.md` P-index): the run of a key = the positions with that
key in input order (`group_build`, `nth?_build`), so the first one = `findIdx?`; `nodup` =
`List.Nodup`; `eraseDups` = `List.eraseDups`. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false
-- Every lemma takes the order's two laws; some need only one.
set_option linter.unusedSectionVars false

namespace Fvtrace.Proofs.Index
open Fvtrace Fvtrace.Index

variable {κ : Type} {cmp : κ → κ → Ordering} [Std.TransCmp cmp] [Std.LawfulEqCmp cmp]

/-- The test every answer reads: the pair's key is `k`. -/
def Is (cmp : κ → κ → Ordering) (k : κ) (p : κ × Nat) : Bool := cmp p.1 k == .eq

theorem is_iff {k : κ} {p : κ × Nat} : Is cmp k p = true ↔ p.1 = k := by
  simp [Is, Std.LawfulEqCmp.compare_eq_iff_eq]

theorem le_trans' : ∀ a b c : κ × Nat,
    Index.le cmp a b = true → Index.le cmp b c = true → Index.le cmp a c = true := by
  intro a b c hab hbc
  simp only [Index.le] at *
  exact Std.TransCmp.isLE_trans hab hbc

theorem le_total' : ∀ a b : κ × Nat, (Index.le cmp a b || Index.le cmp b a) = true := by
  intro a b
  simp only [Index.le, Bool.or_eq_true]
  cases h : cmp a.1 b.1
  · simp
  · simp
  · right; rw [Std.OrientedCmp.gt_iff_lt.mp h]; rfl

theorem sorted (ps : List (κ × Nat)) :
    (ps.mergeSort (Index.le cmp)).Pairwise fun a b => Index.le cmp a b = true :=
  List.pairwise_mergeSort le_trans' le_total' ps

/-- Stability: the sort keeps the input order of the pairs with one key. -/
theorem filter_mergeSort (ps : List (κ × Nat)) (k : κ) :
    (ps.mergeSort (Index.le cmp)).filter (Is cmp k) = ps.filter (Is cmp k) := by
  have hc : (ps.filter (Is cmp k)).Pairwise fun a b => Index.le cmp a b = true := by
    rw [List.pairwise_filter]
    refine List.Pairwise.imp_of_mem ?_ (List.pairwise_of_forall (R := fun _ _ => True)
      (fun _ _ => trivial))
    intro a b _ _ _ ha hb
    rw [is_iff] at ha hb
    simp [Index.le, ha, hb, Std.ReflCmp.compare_self]
  have hsub := List.sublist_mergeSort le_trans' le_total' hc List.filter_sublist
  have h1 :
      List.Sublist (ps.filter (Is cmp k)) ((ps.mergeSort (Index.le cmp)).filter (Is cmp k)) := by
    have := hsub.filter (Is cmp k)
    simpa only [List.filter_filter, Bool.and_self] using this
  have hperm := (List.mergeSort_perm ps (Index.le cmp)).filter (Is cmp k)
  exact (h1.eq_of_length hperm.length_eq.symm).symm

/-! ## Binary search -/

section Search

variable (S : List (κ × Nat)) (hS : S.Pairwise fun a b => Index.le cmp a b = true) (k : κ)
include hS

theorem le_of_lt_index {i j : Nat} (hij : i < j) (hj : j < S.length) :
    (cmp (S[i]'(by omega)).1 (S[j]).1).isLE = true :=
  List.pairwise_iff_getElem.mp hS i j (by omega) hj hij

/-- Below `lo` every key is below `k`, from `hi` on none is: the search keeps both. -/
theorem lowerBound_spec (lo hi : Nat) (hle : hi ≤ S.length) (hlohi : lo ≤ hi)
    (hlo : ∀ j (h : j < S.length), j < lo → cmp S[j].1 k = .lt)
    (hhi : ∀ j (h : j < S.length), hi ≤ j → cmp S[j].1 k ≠ .lt) :
    lowerBound cmp S.toArray k lo hi ≤ S.length ∧
      (∀ j (h : j < S.length), j < lowerBound cmp S.toArray k lo hi → cmp S[j].1 k = .lt) ∧
      (∀ j (h : j < S.length), lowerBound cmp S.toArray k lo hi ≤ j → cmp S[j].1 k ≠ .lt) := by
  unfold lowerBound
  split
  · rename_i hlt
    have hmid : (lo + hi) / 2 < S.length := by omega
    simp only [List.getElem?_toArray, List.getElem?_eq_getElem hmid]
    split
    · rename_i hx
      have hxk : cmp S[(lo + hi) / 2].1 k = .lt := by simpa using hx
      refine lowerBound_spec ((lo + hi) / 2 + 1) hi hle (by omega) ?_ hhi
      intro j hj hjm
      by_cases hjlo : j < lo
      · exact hlo j hj hjlo
      · rcases Nat.lt_or_eq_of_le (Nat.le_of_lt_succ hjm) with hj' | hj'
        · exact Std.TransCmp.lt_of_isLE_of_lt (le_of_lt_index S hS hj' hmid) hxk
        · subst hj'; exact hxk
    · rename_i hx
      have hxk : cmp S[(lo + hi) / 2].1 k ≠ .lt := by simpa using hx
      refine lowerBound_spec lo ((lo + hi) / 2) (by omega) (by omega) hlo ?_
      intro j hj hmj
      rcases Nat.lt_or_eq_of_le hmj with hj' | hj'
      · intro hjk
        exact hxk (Std.TransCmp.lt_of_isLE_of_lt (le_of_lt_index S hS hj' hj) hjk)
      · subst hj'; exact hxk
  · rename_i hlt
    exact ⟨by omega, hlo, fun j hj hij => hhi j hj (by omega)⟩
termination_by hi - lo

/-- Below `lo` no key is above `k`, from `hi` on every key is: the search keeps both. -/
theorem upperBound_spec (lo hi : Nat) (hle : hi ≤ S.length) (hlohi : lo ≤ hi)
    (hlo : ∀ j (h : j < S.length), j < lo → cmp S[j].1 k ≠ .gt)
    (hhi : ∀ j (h : j < S.length), hi ≤ j → cmp S[j].1 k = .gt) :
    upperBound cmp S.toArray k lo hi ≤ S.length ∧
      (∀ j (h : j < S.length), j < upperBound cmp S.toArray k lo hi → cmp S[j].1 k ≠ .gt) ∧
      (∀ j (h : j < S.length), upperBound cmp S.toArray k lo hi ≤ j → cmp S[j].1 k = .gt) := by
  unfold upperBound
  split
  · rename_i hlt
    have hmid : (lo + hi) / 2 < S.length := by omega
    simp only [List.getElem?_toArray, List.getElem?_eq_getElem hmid]
    split
    · rename_i hx
      have hxk : cmp S[(lo + hi) / 2].1 k = .gt := by simpa using hx
      refine upperBound_spec lo ((lo + hi) / 2) (by omega) (by omega) hlo ?_
      intro j hj hmj
      rcases Nat.lt_or_eq_of_le hmj with hj' | hj'
      · have h1 := le_of_lt_index S hS hj' hj
        exact Std.TransCmp.gt_of_isGE_of_gt (Std.OrientedCmp.isGE_of_isLE h1) hxk
      · subst hj'; exact hxk
    · rename_i hx
      have hxk : cmp S[(lo + hi) / 2].1 k ≠ .gt := by simpa using hx
      refine upperBound_spec ((lo + hi) / 2 + 1) hi hle (by omega) ?_ hhi
      intro j hj hjm
      by_cases hjlo : j < lo
      · exact hlo j hj hjlo
      · rcases Nat.lt_or_eq_of_le (Nat.le_of_lt_succ hjm) with hj' | hj'
        · intro hjk
          have h1 := le_of_lt_index S hS hj' hmid
          exact hxk (Std.TransCmp.gt_of_isGE_of_gt (Std.OrientedCmp.isGE_of_isLE h1) hjk)
        · subst hj'; exact hxk
  · rename_i hlt
    exact ⟨by omega, hlo, fun j hj hij => hhi j hj (by omega)⟩
termination_by hi - lo

end Search

/-! ## Runs -/

/-- A list whose test holds on a prefix: filtering = taking while it holds. -/
theorem filter_eq_takeWhile {α : Type} {p : α → Bool} :
    ∀ {L : List α}, L.Pairwise (fun a b => p b = true → p a = true) →
      L.filter p = L.takeWhile p
  | [], _ => rfl
  | x :: xs, h => by
    rw [List.pairwise_cons] at h
    by_cases hx : p x = true
    · rw [List.filter_cons_of_pos hx, List.takeWhile_cons_of_pos hx, filter_eq_takeWhile h.2]
    · rw [List.filter_cons_of_neg hx, List.takeWhile_cons_of_neg hx, List.filter_eq_nil_iff]
      intro y hy hpy
      exact hx (h.1 y hy hpy)

/-- The same list read by index: the `n`-th member passing the test is the `n`-th member. -/
theorem getElem?_filter_prefix {α : Type} {p : α → Bool} :
    ∀ {L : List α} {n : Nat}, L.Pairwise (fun a b => p b = true → p a = true) →
      (L.filter p)[n]? = L[n]?.filter p
  | [], _, _ => rfl
  | x :: xs, n, h => by
    rw [List.pairwise_cons] at h
    by_cases hx : p x = true
    · rw [List.filter_cons_of_pos hx]
      cases n with
      | zero => simp [Option.filter_some, hx]
      | succ n => simpa using getElem?_filter_prefix (n := n) h.2
    · rw [List.filter_cons_of_neg hx]
      have hnil : xs.filter p = [] :=
        List.filter_eq_nil_iff.mpr fun y hy hpy => hx (h.1 y hy hpy)
      rw [hnil]
      cases n with
      | zero => simp [Option.filter_some, hx]
      | succ n =>
        simp only [List.getElem?_nil, List.getElem?_cons_succ]
        cases hn : xs[n]? with
        | none => rfl
        | some y =>
          have hy : y ∈ xs := List.mem_of_getElem? hn
          have hpy : p y = false := by
            cases hq : p y
            · rfl
            · exact absurd (h.1 y hy hq) hx
          simp [Option.filter_some, hpy]

theorem scan_spec (S : List (κ × Nat)) (k : κ) (i : Nat) (acc : Array Nat) :
    (scan cmp S.toArray k i acc).toList =
      acc.toList ++ ((S.drop i).takeWhile (Is cmp k)).map (·.2) := by
  unfold scan
  split
  · rename_i h
    simp only [List.size_toArray] at h
    have hd := List.drop_eq_getElem_cons h
    split
    · rename_i heq
      rw [scan_spec S k (i + 1) (acc.push _)]
      have hk : Is cmp k S[i] = true := by simpa [Is] using heq
      rw [hd, List.takeWhile_cons_of_pos hk]
      simp
    · rename_i hne
      have hk : ¬ Is cmp k S[i] = true := by simpa [Is] using hne
      rw [hd, List.takeWhile_cons_of_neg hk]
      simp
  · rename_i h
    simp only [List.size_toArray, Nat.not_lt] at h
    simp [List.drop_eq_nil_of_le h]
termination_by S.length - i
decreasing_by all_goals (have := List.size_toArray (as := S); omega)

section Run

variable (ps : List (κ × Nat)) (k : κ)

/-- The run of `k` in the sorted pairs starts at `start`: every key before it is below `k`, none
from it on is. -/
theorem start_spec :
    (Index.build cmp ps).start (cmp := cmp) k ≤ (ps.mergeSort (Index.le cmp)).length ∧
      (∀ j (h : j < (ps.mergeSort (Index.le cmp)).length),
        j < (Index.build cmp ps).start (cmp := cmp) k →
          cmp (ps.mergeSort (Index.le cmp))[j].1 k = .lt) ∧
      (∀ j (h : j < (ps.mergeSort (Index.le cmp)).length),
        (Index.build cmp ps).start (cmp := cmp) k ≤ j →
          cmp (ps.mergeSort (Index.le cmp))[j].1 k ≠ .lt) := by
  have := lowerBound_spec (ps.mergeSort (Index.le cmp)) (sorted ps) k 0
    (ps.mergeSort (Index.le cmp)).length (Nat.le_refl _) (Nat.zero_le _)
    (fun j _ hj => absurd hj (Nat.not_lt_zero j)) (fun j hj hle => absurd hj (by omega))
  simpa [Index.start, Index.build] using this

/-- From the run's start on, the pairs with key `k` come first. -/
theorem drop_prefix :
    ((ps.mergeSort (Index.le cmp)).drop ((Index.build cmp ps).start (cmp := cmp) k)).Pairwise
      (fun a b => Is cmp k b = true → Is cmp k a = true) := by
  obtain ⟨_, _, habove⟩ := start_spec (cmp := cmp) ps k
  have hsorted := (sorted ps).sublist
    (List.drop_sublist ((Index.build cmp ps).start (cmp := cmp) k) (ps.mergeSort (Index.le cmp)))
  refine hsorted.imp_of_mem ?_
  intro a b ha _ hab hb
  rw [is_iff] at hb ⊢
  obtain ⟨j, hj, hjeq⟩ := List.mem_drop_iff_getElem.mp ha
  have hge : cmp a.1 k ≠ .lt := by
    rw [← hjeq]; exact habove _ _ (by omega)
  have hle : (cmp a.1 k).isLE = true := by
    simpa [Index.le, hb] using hab
  apply Std.LawfulEqCmp.eq_of_compare (cmp := cmp)
  revert hle hge
  cases cmp a.1 k <;> simp

theorem filter_sorted :
    (ps.mergeSort (Index.le cmp)).filter (Is cmp k) =
      ((ps.mergeSort (Index.le cmp)).drop ((Index.build cmp ps).start (cmp := cmp) k)).filter
        (Is cmp k) := by
  obtain ⟨_, hbelow, _⟩ := start_spec (cmp := cmp) ps k
  conv => lhs; rw [← List.take_append_drop ((Index.build cmp ps).start (cmp := cmp) k)
    (ps.mergeSort (Index.le cmp))]
  rw [List.filter_append, List.filter_eq_nil_iff.mpr, List.nil_append]
  intro x hx hk
  obtain ⟨j, hj, hjx⟩ := List.mem_take_iff_getElem.mp hx
  have hj' := Nat.lt_min.mp hj
  have h1 := hbelow j hj'.2 hj'.1
  rw [hjx] at h1
  rw [is_iff] at hk
  rw [hk, Std.ReflCmp.compare_self (cmp := cmp)] at h1
  cases h1

/-- Every position whose key is `k`, in input order. -/
theorem group_build :
    (Index.build cmp ps).group (cmp := cmp) k = (ps.filter (Is cmp k)).map (·.2) := by
  rw [← filter_mergeSort ps k, filter_sorted ps k, filter_eq_takeWhile (drop_prefix ps k)]
  unfold Index.group
  rw [scan_spec]
  simp [Index.build]

/-- The run's `n`-th position (from 0). -/
theorem nth?_build (n : Nat) :
    (Index.build cmp ps).nth? (cmp := cmp) k n = ((ps.filter (Is cmp k)).map (·.2))[n]? := by
  rw [← filter_mergeSort ps k, filter_sorted ps k, List.getElem?_map,
    getElem?_filter_prefix (drop_prefix ps k), List.getElem?_drop]
  unfold Index.nth?
  simp only [Index.build, List.getElem?_toArray]
  cases h : (ps.mergeSort (Index.le cmp))[(Index.build cmp ps).start (cmp := cmp) k + n]? with
  | none => simp [Index.build] at h ⊢; simp [h]
  | some x =>
    simp only [Index.build] at h
    simp only [h, Option.filter_some]
    by_cases hx : Is cmp k x = true
    · simp [hx]; simp [Is] at hx; simp [hx]
    · simp [hx]; simp [Is] at hx; simp [hx]

theorem first?_build :
    (Index.build cmp ps).first? (cmp := cmp) k = (ps.find? (Is cmp k)).map (·.2) := by
  rw [Index.first?, nth?_build, ← List.head?_eq_getElem?, List.head?_map, List.head?_filter]

/-- A prefix of `m` members passing the test, then one failing it: taking while = taking `m`. -/
theorem takeWhile_eq_take {α : Type} {p : α → Bool} :
    ∀ {l : List α} {m : Nat}, (∀ j (h : j < l.length), j < m → p l[j] = true) →
      (∀ h : m < l.length, p l[m] = false) → l.takeWhile p = l.take m
  | [], _, _, _ => by simp
  | x :: xs, 0, _, hstop => by
    have := hstop (by simp)
    simp [List.takeWhile_cons_of_neg (by simpa using this)]
  | x :: xs, m + 1, hrun, hstop => by
    have hx := hrun 0 (by simp) (by omega)
    simp only [List.getElem_cons_zero] at hx
    rw [List.takeWhile_cons_of_pos hx, List.take_succ_cons,
      takeWhile_eq_take (m := m)
        (fun j hj hjm => by
          have := hrun (j + 1) (by simp; omega) (by omega)
          rwa [List.getElem_cons_succ] at this)
        (fun h => by
          have := hstop (by simp; omega)
          rwa [List.getElem_cons_succ] at this)]

/-- How many positions carry `k`. -/
theorem count_build :
    (Index.build cmp ps).count (cmp := cmp) k = (ps.filter (Is cmp k)).length := by
  obtain ⟨hlo, hbelow, habove⟩ := start_spec (cmp := cmp) ps k
  obtain ⟨hupl, hnotgt, hgt⟩ := upperBound_spec (ps.mergeSort (Index.le cmp)) (sorted ps) k 0
    (ps.mergeSort (Index.le cmp)).length (Nat.le_refl _) (Nat.zero_le _)
    (fun j _ hj => absurd hj (Nat.not_lt_zero j)) (fun j hj hle => absurd hj (by omega))
  have hcount : (Index.build cmp ps).count (cmp := cmp) k =
      upperBound cmp (ps.mergeSort (Index.le cmp)).toArray k 0
          (ps.mergeSort (Index.le cmp)).length -
        (Index.build cmp ps).start (cmp := cmp) k := rfl
  rw [hcount, ← filter_mergeSort ps k, filter_sorted ps k, filter_eq_takeWhile (drop_prefix ps k)]
  generalize (Index.build cmp ps).start (cmp := cmp) k = st at *
  generalize upperBound cmp (ps.mergeSort (Index.le cmp)).toArray k 0
    (ps.mergeSort (Index.le cmp)).length = up at *
  generalize ps.mergeSort (Index.le cmp) = S at *
  have hst : st ≤ up := by
    rcases Nat.lt_or_ge up st with h | h
    · exfalso
      have h1 := hbelow up (by omega) h
      have h2 := hgt up (by omega) (Nat.le_refl _)
      rw [h1] at h2; cases h2
    · exact h
  rw [takeWhile_eq_take (m := up - st)]
  · simp only [List.length_take, List.length_drop]; omega
  · intro j hj hjm
    rw [List.getElem_drop]
    simp only [List.length_drop] at hj
    have a := habove (st + j) (by omega) (by omega)
    have b := hnotgt (st + j) (by omega) (by omega)
    simp only [Is, beq_iff_eq]
    revert a b; cases cmp S[st + j].1 k <;> simp
  · intro h
    simp only [List.length_drop] at h
    rw [List.getElem_drop]
    have := hgt (st + (up - st)) (by omega) (by omega)
    simp only [Is, this]; rfl

end Run

/-- `ofKeys`: the first position of a key = `findIdx?`. -/
theorem first?_ofKeys (keys : List κ) (k : κ) :
    (Index.ofKeys cmp keys).first? (cmp := cmp) k = keys.findIdx? (fun x => cmp x k == .eq) := by
  rw [Index.ofKeys, first?_build, List.findIdx?_eq_fst_find?_zipIdx]
  rfl

theorem group_ofKeys (keys : List κ) (k : κ) :
    (Index.ofKeys cmp keys).group (cmp := cmp) k =
      (keys.zipIdx.filter fun p => cmp p.1 k == .eq).map (·.2) := by
  rw [Index.ofKeys, group_build]
  rfl

/-! ## Lists -/

theorem leK_trans : ∀ a b c : κ, (cmp a b).isLE = true → (cmp b c).isLE = true →
    (cmp a c).isLE = true := fun _ _ _ hab hbc => Std.TransCmp.isLE_trans hab hbc

theorem leK_total : ∀ a b : κ, ((cmp a b).isLE || (cmp b a).isLE) = true := by
  intro a b
  simp only [Bool.or_eq_true]
  cases h : cmp a b
  · simp
  · simp
  · right; rw [Std.OrientedCmp.gt_iff_lt.mp h]; rfl

theorem ne_of_cmp_ne {a b : κ} (h : cmp a b ≠ .eq) : a ≠ b := by
  intro hab; subst hab; exact h Std.ReflCmp.compare_self

theorem nodup_go_iff : ∀ {T : List κ}, T.Pairwise (fun a b => (cmp a b).isLE = true) →
    (Index.nodup.go cmp T = true ↔ T.Nodup)
  | [], _ => by simp [Index.nodup.go]
  | [a], _ => by simp [Index.nodup.go]
  | a :: b :: rest, hT => by
    have ih := nodup_go_iff (T := b :: rest) (List.pairwise_cons.mp hT).2
    simp only [Index.nodup.go, Bool.and_eq_true, bne_iff_ne, ne_eq, ih]
    constructor
    · rintro ⟨hab, hn⟩
      refine List.nodup_cons.mpr ⟨?_, hn⟩
      have hlt : cmp a b = .lt := by
        have := List.rel_of_pairwise_cons hT (List.mem_cons_self)
        revert this hab; cases cmp a b <;> simp
      intro hmem
      rcases List.mem_cons.mp hmem with h | h
      · exact ne_of_cmp_ne (cmp := cmp) hab h
      · have hbc := List.rel_of_pairwise_cons (List.pairwise_cons.mp hT).2 h
        have hac := Std.TransCmp.lt_of_lt_of_isLE hlt hbc
        rw [Std.ReflCmp.compare_self (cmp := cmp)] at hac
        cases hac
    · intro hn
      refine ⟨?_, (List.nodup_cons.mp hn).2⟩
      intro hab
      exact (List.nodup_cons.mp hn).1
        (List.mem_cons.mpr (Or.inl (Std.LawfulEqCmp.eq_of_compare hab)))

/-- `nodup` = `List.Nodup`. -/
theorem nodup_eq [DecidableEq κ] (keys : List κ) : Index.nodup cmp keys = decide keys.Nodup := by
  have hs := List.pairwise_mergeSort leK_trans leK_total keys (le := fun a b => (cmp a b).isLE)
  have := nodup_go_iff hs
  unfold Index.nodup
  rw [Bool.eq_iff_iff, this, decide_eq_true_iff]
  exact (List.mergeSort_perm keys _).nodup_iff

theorem snoc_induction {α : Type} {P : List α → Prop} (nil : P [])
    (snoc : ∀ l x, P l → P (l ++ [x])) : ∀ l, P l := by
  intro l
  rw [← List.reverse_reverse l]
  induction l.reverse with
  | nil => exact nil
  | cons x xs ih => rw [List.reverse_cons]; exact snoc _ _ ih

/-- `eraseDups` keeps a member exactly where no earlier member equals it. -/
theorem eraseDups_eq_filter {α : Type} [BEq α] [LawfulBEq α] (l : List α) :
    l.eraseDups = (l.zipIdx.filter fun p => !(l.take p.2).contains p.1).map (·.1) := by
  induction l using snoc_induction with
  | nil => rfl
  | snoc l x ih =>
    rw [List.eraseDups_append, ih, List.zipIdx_append, List.filter_append, List.map_append]
    congr 1
    · congr 1
      apply List.filter_congr
      intro p hp
      have := (List.mem_zipIdx' (x := p.1) (i := p.2) hp).1
      rw [List.take_append_of_le_length (by omega)]
    · simp only [List.zipIdx_singleton, Nat.zero_add, List.filter_cons, List.filter_nil,
        List.take_left, List.removeAll, List.elem_eq_contains]
      cases l.contains x <;> simp [List.eraseDups_cons]

/-- `eraseDups` = `List.eraseDups`. -/
theorem eraseDups_eq [BEq κ] [LawfulBEq κ] (keys : List κ) :
    Index.eraseDups cmp keys = keys.eraseDups := by
  rw [eraseDups_eq_filter, Index.eraseDups]
  congr 1
  apply List.filter_congr
  rintro ⟨y, i⟩ hp
  obtain ⟨hi, hx⟩ := List.mem_zipIdx' hp
  dsimp only
  rw [first?_ofKeys]
  have hfi : keys.findIdx? (fun z => cmp z y == .eq) = keys.findIdx? (· == y) := by
    congr 1; funext z
    rw [Bool.eq_iff_iff, beq_iff_eq, beq_iff_eq, Std.LawfulEqCmp.compare_eq_iff_eq]
  rw [hfi]
  cases hf : keys.findIdx? (· == y) with
  | none =>
    rw [List.findIdx?_eq_none_iff] at hf
    have := hf _ (List.getElem_mem hi)
    rw [← hx] at this
    simp at this
  | some j =>
    rw [List.findIdx?_eq_some_iff_getElem] at hf
    obtain ⟨hj, hjx, hbefore⟩ := hf
    simp only [beq_iff_eq] at hjx
    rw [Bool.eq_iff_iff, beq_iff_eq, Option.some.injEq, Bool.not_eq_true']
    have hc : (List.take i keys).contains y = false ↔ y ∉ List.take i keys := by
      cases h : (List.take i keys).contains y
      · simp only [true_iff]; intro hm; rw [List.contains_iff_mem.mpr hm] at h; cases h
      · simp only [Bool.true_eq_false, false_iff, Classical.not_not]
        exact List.contains_iff_mem.mp h
    rw [hc]
    constructor
    · rintro rfl hmem
      obtain ⟨m, hm, hmx⟩ := List.mem_take_iff_getElem.mp hmem
      have hm' := Nat.lt_min.mp hm
      exact hbefore m hm'.1 (by rw [hmx]; simp)
    · intro hnot
      rcases Nat.lt_trichotomy j i with h | h | h
      · exact absurd (List.mem_take_iff_getElem.mpr ⟨j, Nat.lt_min.mpr ⟨h, hj⟩, hjx⟩) hnot
      · exact h
      · exact absurd (by rw [← hx]; simp) (hbefore i h)

end Fvtrace.Proofs.Index
