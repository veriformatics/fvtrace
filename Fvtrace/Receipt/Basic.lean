import Fvtrace.Index
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

/-- The bindings by id, indexed once (`kernel.md` P-shell). A structure, not a function: a
definition returning a closure is compiled to its full arity, so its index would be rebuilt at
every call. -/
structure BindingIndex where
  ix : Index String
  arr : Array Binding

def BindingIndex.of (bindings : List Binding) : BindingIndex :=
  ⟨Index.ofKeys compare (bindings.map (·.id)), bindings.toArray⟩

/-- `bindings.find? (·.id == id)` in O(log n). -/
def BindingIndex.find (b : BindingIndex) (id : String) : Option Binding :=
  (b.ix.first? (cmp := compare) id).bind (b.arr[·]?)

/-- The review state for a given content digest (contract § Review). -/
def reviewStateOf (t : Trace) (digest : String) : ReviewState :=
  match t.review with
  | none => .draft
  | some r => if r.digest == digest then .reviewed else .stale

end Fvtrace.Receipt
