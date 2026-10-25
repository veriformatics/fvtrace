/-!
# Persistent arrays (`.agent/contracts/kernel.md` P-forest)

A complete binary tree over positions `0 … 2 ^ d - 1`, a position's bits choosing the branch from
the lowest up. `set` copies the one path it changes, so an older version stays readable after
every later `set`: a forest node's state shares all but its own changes with its parent's.
-/

namespace Fvtrace

inductive PTree (α : Type) where
  | leaf (a : α)
  | node (l r : PTree α)

namespace PTree

variable {α : Type}

/-- Depth `d`, every leaf `a`: one cell per level (the two branches are one shared tree). -/
def const (a : α) : Nat → PTree α
  | 0 => leaf a
  | d + 1 => let t := const a d; node t t

def get : PTree α → Nat → α
  | leaf a, _ => a
  | node l r, i => if i % 2 == 0 then get l (i / 2) else get r (i / 2)

def set : PTree α → Nat → α → PTree α
  | leaf _, _, v => leaf v
  | node l r, i, v => if i % 2 == 0 then node (l.set (i / 2) v) r else node l (r.set (i / 2) v)

/-- A depth whose `2 ^ d` positions cover `0 … n - 1`. -/
def depthFor (n : Nat) : Nat := n.log2 + 1

end PTree

end Fvtrace
