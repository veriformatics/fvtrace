import Fvtrace.Version

/-!
# fvTrace specification

The human-read layer. Each claim is a `Prop`-valued definition; its proof lives in
`Fvtrace.Proofs`, which nothing here imports, so reading this module (and the definitions it
names) suffices to know what fvTrace guarantees. `fvtrace-trust` lists every claim with its
proofs, their axioms and any escape hatch in their closure.
-/

namespace Fvtrace.Spec

/-- The version string is non-empty and short enough for one display line. -/
def VersionWellFormed : Prop :=
  Fvtrace.version ≠ "" ∧ Fvtrace.version.length ≤ 32

end Fvtrace.Spec
