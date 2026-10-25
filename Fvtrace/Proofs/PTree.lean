import Fvtrace.PTree

/-! `PTree` reads back what was set, positions below `2 ^ d` in a tree of depth `d`. -/

namespace Fvtrace.Proofs.PTree
open Fvtrace Fvtrace.PTree

variable {α : Type}

/-- Every leaf at depth `d`. -/
inductive Complete : PTree α → Nat → Prop
  | leaf (a : α) : Complete (.leaf a) 0
  | node {l r : PTree α} {d : Nat} : Complete l d → Complete r d → Complete (.node l r) (d + 1)

theorem complete_const (a : α) : ∀ d, Complete (const a d) d
  | 0 => .leaf a
  | d + 1 => .node (complete_const a d) (complete_const a d)

theorem complete_set {t : PTree α} {d : Nat} (h : Complete t d) (i : Nat) (v : α) :
    Complete (t.set i v) d := by
  induction h generalizing i with
  | leaf a => exact .leaf v
  | node _ _ ihl ihr =>
    unfold PTree.set
    split
    · exact .node (ihl _) ‹_›
    · exact .node ‹_› (ihr _)

theorem get_const (a : α) : ∀ d i, (const a d).get i = a
  | 0, _ => rfl
  | d + 1, i => by
    show (PTree.node (const a d) (const a d)).get i = a
    unfold PTree.get
    split <;> exact get_const a d _

theorem get_node (l r : PTree α) (i : Nat) :
    (PTree.node l r).get i = if i % 2 == 0 then l.get (i / 2) else r.get (i / 2) := rfl

theorem set_node (l r : PTree α) (i : Nat) (v : α) :
    (PTree.node l r).set i v =
      if i % 2 == 0 then .node (l.set (i / 2) v) r else .node l (r.set (i / 2) v) := rfl

theorem get_set {t : PTree α} {d : Nat} (h : Complete t d) {i j : Nat} (hi : i < 2 ^ d)
    (hj : j < 2 ^ d) (v : α) : (t.set i v).get j = if i = j then v else t.get j := by
  induction h generalizing i j with
  | leaf a =>
    simp only [Nat.pow_zero] at hi hj
    have : i = j := by omega
    simp [PTree.set, PTree.get, this]
  | @node l r d hl hr ihl ihr =>
    have hi' : i / 2 < 2 ^ d := by rw [Nat.pow_succ] at hi; omega
    have hj' : j / 2 < 2 ^ d := by rw [Nat.pow_succ] at hj; omega
    rw [set_node]
    rcases Nat.mod_two_eq_zero_or_one i with hpi | hpi <;>
      rcases Nat.mod_two_eq_zero_or_one j with hpj | hpj
    · simp only [hpi, hpj, get_node, beq_self_eq_true, ↓reduceIte]
      rw [ihl hi' hj']
      by_cases hij : i = j
      · simp [hij]
      · have : i / 2 ≠ j / 2 := by omega
        simp [hij, this]
    · have hne : i ≠ j := by omega
      simp [hpi, hpj, get_node, hne]
    · have hne : i ≠ j := by omega
      simp [hpi, hpj, get_node, hne]
    · simp only [hpi, hpj, get_node, Nat.one_ne_zero, beq_iff_eq, ↓reduceIte]
      rw [ihr hi' hj']
      by_cases hij : i = j
      · simp [hij]
      · have : i / 2 ≠ j / 2 := by omega
        simp [hij, this]

theorem lt_depthFor (n : Nat) : n < 2 ^ depthFor n := Nat.lt_log2_self

end Fvtrace.Proofs.PTree
