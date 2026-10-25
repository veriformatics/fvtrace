/-!
# Sorted indexes (`.agent/contracts/kernel.md` P-index)

Answers to "which positions carry key k" in O(log n) + the positions returned: a stable sort of
(key, position) pairs (O(n log n), once per index) + a lower-bound binary search. Keys are
ordered by a `compare` that is transitive + lawful (`Std.TransCmp`, `Std.LawfulEqCmp`): ids,
positions + pairs of them. No hash map: a trace's ids are its author's choice, so collisions
would come on demand. `Init` alone: the exported page's engine compiles this module.
`Fvtrace.Proofs.Index` states what each answer equals.
-/

namespace Fvtrace

/-- (key, position) pairs sorted by key; positions keep their input order within a key. -/
structure Index (κ : Type) where
  sorted : Array (κ × Nat)

namespace Index

variable {κ : Type} (cmp : κ → κ → Ordering)

/-- `a` sorts before or with `b`: by key alone, so the sort keeps input order within a key. -/
@[specialize] def le (a b : κ × Nat) : Bool := (cmp a.1 b.1).isLE

@[specialize] def build (pairs : List (κ × Nat)) : Index κ := ⟨(pairs.mergeSort (le cmp)).toArray⟩

/-- Each item's key at its position. -/
@[specialize] def ofKeys (keys : List κ) : Index κ := build cmp keys.zipIdx

/-- The first index in `[lo, hi)` whose key is not below `k` (`hi` when there is none). -/
@[specialize] def lowerBound (a : Array (κ × Nat)) (k : κ) (lo hi : Nat) : Nat :=
  if lo < hi then
    let mid := (lo + hi) / 2
    match a[mid]? with
    | some (x, _) =>
      if cmp x k == .lt then lowerBound a k (mid + 1) hi else lowerBound a k lo mid
    | none => lo
  else lo
termination_by hi - lo

/-- The first index in `[lo, hi)` whose key is above `k` (`hi` when there is none). -/
@[specialize] def upperBound (a : Array (κ × Nat)) (k : κ) (lo hi : Nat) : Nat :=
  if lo < hi then
    let mid := (lo + hi) / 2
    match a[mid]? with
    | some (x, _) =>
      if cmp x k == .gt then upperBound a k lo mid else upperBound a k (mid + 1) hi
    | none => lo
  else lo
termination_by hi - lo

/-- The positions of the run of key `k` that starts at sorted index `i`, after `acc`. -/
@[specialize] def scan (a : Array (κ × Nat)) (k : κ) (i : Nat) (acc : Array Nat) : Array Nat :=
  if h : i < a.size then
    if cmp a[i].1 k == .eq then scan a k (i + 1) (acc.push a[i].2) else acc
  else acc
termination_by a.size - i

variable {cmp}

/-- Where the run of key `k` starts (or would start). -/
@[specialize] def start (ix : Index κ) (k : κ) : Nat := lowerBound cmp ix.sorted k 0 ix.sorted.size

/-- The position of the run's `n`-th member (from 0), when the run has one. -/
@[specialize] def nth? (ix : Index κ) (k : κ) (n : Nat) : Option Nat :=
  match ix.sorted[ix.start (cmp := cmp) k + n]? with
  | some (x, p) => if cmp x k == .eq then some p else none
  | none => none

/-- How many positions carry key `k`. -/
@[specialize] def count (ix : Index κ) (k : κ) : Nat :=
  upperBound cmp ix.sorted k 0 ix.sorted.size - ix.start (cmp := cmp) k

/-- The first position whose key is `k`. -/
@[specialize] def first? (ix : Index κ) (k : κ) : Option Nat := ix.nth? (cmp := cmp) k 0

/-- Every position whose key is `k`, in input order. -/
@[specialize] def group (ix : Index κ) (k : κ) : List Nat :=
  (scan cmp ix.sorted k (ix.start (cmp := cmp) k) #[]).toList

end Index

/-! ## Lists through an index -/

namespace Index

variable {α κ : Type} (cmp : κ → κ → Ordering)

/-- No key twice: adjacent keys of the sorted list all differ. -/
@[specialize] def nodup (keys : List κ) : Bool :=
  go (keys.mergeSort fun a b => (cmp a b).isLE)
where
  go : List κ → Bool
    | a :: b :: rest => cmp a b != .eq && go (b :: rest)
    | _ => true

/-- `List.eraseDups`: each key at its first position, in input order. -/
@[specialize] def eraseDups (keys : List κ) : List κ :=
  let ix := ofKeys cmp keys
  (keys.zipIdx.filter fun (k, i) => ix.first? (cmp := cmp) k == some i).map (·.1)

end Index

end Fvtrace
