/-! Seeded generators for property tests (`.claude/rules/testing.md`): a linear congruential state,
so a suite's seed fixes every case and a failure reruns from committed state. -/

namespace Tests

abbrev Gen := StateM UInt64

/-- A number below `bound` (0 when `bound` = 0). -/
def draw (bound : Nat) : Gen Nat := do
  let x := (← get) * 6364136223846793005 + 1442695040888963407
  set x
  return (x >>> 32).toNat % max 1 bound

def pick {α : Type} [Inhabited α] (xs : List α) : Gen α := do
  return (xs[(← draw xs.length)]?).getD default

def shuffled {α : Type} (xs : List α) : Gen (List α) := do
  let keyed ← xs.mapM fun x => do return (← draw 1000003, x)
  return (keyed.mergeSort fun a b => a.1 ≤ b.1).map (·.2)

/-- `n` draws of `g`. -/
def listOf {α : Type} (n : Nat) (g : Gen α) : Gen (List α) :=
  (List.range n).mapM fun _ => g

def sample {α : Type} (salt : UInt64) (g : Gen α) : α := (g.run' salt).run

end Tests
