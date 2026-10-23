import Fvtrace.Spec.Fast

/-! Proof of `Fvtrace.Spec.SortMembersAgree`: the merge sort of the reversed members and the
insertion sort it replaces are both sorted permutations whose members of each key come in reversed
input order; such a list is unique. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false

namespace Fvtrace.Proofs.Json
open Fvtrace Fvtrace.Json

abbrev Member := String × Value

/-- The sort's order: by key alone. -/
def le (a b : Member) : Bool := a.1 ≤ b.1

/-- The members with key `k`. -/
def Key (k : String) (a : Member) : Bool := a.1 == k

theorem le_trans' : ∀ a b c : Member, le a b = true → le b c = true → le a c = true := by
  intro a b c hab hbc
  simp only [le, decide_eq_true_eq] at *
  exact String.le_trans hab hbc

theorem le_total' : ∀ a b : Member, (le a b || le b a) = true := by
  intro a b
  simp only [le, Bool.or_eq_true, decide_eq_true_eq]
  exact String.le_total _ _

/-- Sorted permutations with the same members per key are equal. -/
theorem eq_of_sorted : ∀ {A B : List Member}, A.Perm B →
    A.Pairwise (fun a b => le a b = true) → B.Pairwise (fun a b => le a b = true) →
    (∀ k, A.filter (Key k) = B.filter (Key k)) → A = B
  | [], B, hp, _, _, _ => (List.Perm.nil_eq hp)
  | a :: A', [], hp, _, _, _ => absurd hp.length_eq (by simp)
  | a :: A', b :: B', hp, hA, hB, hk => by
    rw [List.pairwise_cons] at hA hB
    have hab : a.1 = b.1 := by
      have hb : b ∈ a :: A' := hp.symm.subset List.mem_cons_self
      have ha : a ∈ b :: B' := hp.subset List.mem_cons_self
      have h1 : a.1 ≤ b.1 := by
        rcases List.mem_cons.mp hb with h | h
        · rw [h]; exact String.le_refl _
        · simpa [le] using hA.1 b h
      have h2 : b.1 ≤ a.1 := by
        rcases List.mem_cons.mp ha with h | h
        · rw [h]; exact String.le_refl _
        · simpa [le] using hB.1 a h
      exact String.le_antisymm h1 h2
    have hhead := hk a.1
    simp only [List.filter_cons, Key, beq_self_eq_true, ite_true, hab] at hhead
    have heq : a = b := (List.cons.inj hhead).1
    subst heq
    have htail : ∀ k, A'.filter (Key k) = B'.filter (Key k) := by
      intro k
      have := hk k
      simp only [List.filter_cons] at this
      split at this
      · exact (List.cons.inj this).2
      · exact this
    rw [eq_of_sorted (hp.cons_inv) hA.2 hB.2 htail]

theorem insertBy_perm (x : Member) : ∀ S : List Member, (insertBy x S).Perm (x :: S)
  | [] => List.Perm.refl _
  | y :: S' => by
    unfold insertBy
    split
    · exact List.Perm.refl _
    · exact ((insertBy_perm x S').cons y).trans (List.Perm.swap x y S')

theorem mem_insertBy {x z : Member} {S : List Member} (h : z ∈ insertBy x S) : z = x ∨ z ∈ S := by
  have := (insertBy_perm x S).subset h
  simpa using this

theorem insertBy_sorted (x : Member) : ∀ {S : List Member},
    S.Pairwise (fun a b => le a b = true) → (insertBy x S).Pairwise (fun a b => le a b = true)
  | [], _ => by simp [insertBy]
  | y :: S', hS => by
    unfold insertBy
    rw [List.pairwise_cons] at hS
    split
    · rename_i hlt
      refine List.pairwise_cons.mpr ⟨?_, List.pairwise_cons.mpr hS⟩
      intro z hz
      have hxy : x.1 ≤ y.1 := String.not_lt.mp (String.lt_asymm hlt)
      rcases List.mem_cons.mp hz with rfl | hz
      · simpa [le] using hxy
      · have := hS.1 z hz
        simp only [le, decide_eq_true_eq] at this ⊢
        exact String.le_trans hxy this
    · rename_i hnlt
      refine List.pairwise_cons.mpr ⟨?_, insertBy_sorted x hS.2⟩
      intro z hz
      rcases mem_insertBy hz with rfl | hz
      · simpa [le] using String.not_lt.mp hnlt
      · exact hS.1 z hz

theorem insertBy_filter (x : Member) (k : String) : ∀ {S : List Member},
    S.Pairwise (fun a b => le a b = true) →
      (insertBy x S).filter (Key k) = if Key k x then S.filter (Key k) ++ [x] else S.filter (Key k)
  | [], _ => by by_cases hx : Key k x = true <;> simp [insertBy, hx]
  | y :: S', hS => by
    unfold insertBy
    rw [List.pairwise_cons] at hS
    split
    · rename_i hlt
      by_cases hx : Key k x = true
      · -- nothing in `y :: S'` has key `k`: every key there is above `x`'s
        have hnone : (y :: S').filter (Key k) = [] := by
          rw [List.filter_eq_nil_iff]
          intro z hz hkz
          simp only [Key, beq_iff_eq] at hx hkz
          have hyz : y.1 ≤ z.1 := by
            rcases List.mem_cons.mp hz with rfl | hz
            · exact String.le_refl _
            · simpa [le] using hS.1 z hz
          rw [hkz, ← hx] at hyz
          exact String.not_lt.mpr hyz hlt
        rw [List.filter_cons_of_pos hx, hnone]
        simp [hx]
      · rw [List.filter_cons_of_neg hx]
        simp [hx]
    · rw [List.filter_cons, List.filter_cons, insertBy_filter x k hS.2]
      by_cases hy : Key k y = true <;> by_cases hx : Key k x = true <;> simp [hy, hx]

theorem foldr_spec (k : String) : ∀ l : List Member,
    (l.foldr insertBy []).Perm l ∧ (l.foldr insertBy []).Pairwise (fun a b => le a b = true) ∧
      (l.foldr insertBy []).filter (Key k) = (l.filter (Key k)).reverse
  | [] => by simp
  | x :: xs => by
    obtain ⟨hp, hs, hf⟩ := foldr_spec k xs
    refine ⟨((insertBy_perm x _).trans (hp.cons x)), insertBy_sorted x hs, ?_⟩
    rw [List.foldr_cons, insertBy_filter x k hs, hf, List.filter_cons]
    by_cases hx : Key k x = true <;> simp [hx]

theorem mergeSort_filter (L : List Member) (k : String) :
    (L.mergeSort le).filter (Key k) = L.filter (Key k) := by
  have hc : (L.filter (Key k)).Pairwise fun a b => le a b = true := by
    rw [List.pairwise_filter]
    refine List.Pairwise.imp_of_mem ?_ (List.pairwise_of_forall (R := fun _ _ => True)
      (fun _ _ => trivial))
    intro a b _ _ _ ha hb
    simp only [Key, beq_iff_eq] at ha hb
    simp [le, ha, hb, String.le_refl]
  have hsub := List.sublist_mergeSort le_trans' le_total' hc List.filter_sublist
  have h1 : List.Sublist (L.filter (Key k)) ((L.mergeSort le).filter (Key k)) := by
    have := hsub.filter (Key k)
    simpa only [List.filter_filter, Bool.and_self] using this
  have hperm := (List.mergeSort_perm L le).filter (Key k)
  exact (h1.eq_of_length hperm.length_eq.symm).symm

theorem sortMembersAgree : Spec.SortMembersAgree := by
  intro kvs
  obtain ⟨hp, hs, _⟩ := foldr_spec "" kvs
  refine (eq_of_sorted ?_ ?_ hs ?_)
  · exact ((List.mergeSort_perm _ _).trans (List.reverse_perm _)).trans hp.symm
  · exact List.pairwise_mergeSort le_trans' le_total' _
  · intro k
    rw [Json.sortMembers, show (fun a b : String × Value => decide (a.1 ≤ b.1)) = le from rfl,
      mergeSort_filter, List.filter_reverse, (foldr_spec k kvs).2.2]

end Fvtrace.Proofs.Json
