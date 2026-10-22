import Fvtrace.Model

/-!
# Receipt binding + review state (the engine's inputs from `Fvtrace.Receipt`)

`Std`-free, so the engine's import closure stays `Init` alone: the exported page's WebAssembly
build compiles that closure (`kernel.md` E-wasm).
-/

namespace Fvtrace.Receipt

structure Binding where
  /-- Fact or exclusion id. -/
  id : String
  current : Bool
  /-- `changed <path>` · `missing <path>` · `outside <path>` · `not a file <path>` ·
  `statement-changed`. -/
  reasons : List String
  deriving Repr, BEq

inductive ReviewState where
  | draft
  | stale
  | reviewed
  deriving DecidableEq, Repr

def ReviewState.name : ReviewState → String
  | .draft => "draft" | .stale => "stale" | .reviewed => "reviewed"

/-- The review state for a given content digest (contract § Review). -/
def reviewStateOf (t : Trace) (digest : String) : ReviewState :=
  match t.review with
  | none => .draft
  | some r => if r.digest == digest then .reviewed else .stale

end Fvtrace.Receipt
