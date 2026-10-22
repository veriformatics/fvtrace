import Fvtrace.Check
import Fvtrace.Decode
import Fvtrace.Evaluate

/-!
# Snapshot: the engine's inputs, frozen for an exported page (`kernel.md` E-snap, E-eval)

`fvtrace export --html` freezes what `Session.envelope` reads (the trace + its receipt bindings +
review digest + state) into a snapshot; the page's engine, this module compiled to WebAssembly,
evaluates any what-if against it with the native engine's own definitions. Its import closure
stays `Init` + engine modules: the WebAssembly build compiles exactly that closure.
-/

namespace Fvtrace.Snapshot
open Fvtrace.Json

structure Snapshot where
  trace : Trace
  bindings : List Receipt.Binding
  digest : String
  review : Receipt.ReviewState
  deriving BEq

def schema : String := "fvtrace.snapshot/1"

def bindingJson (b : Receipt.Binding) : Value :=
  .obj [("id", .str b.id), ("current", .bool b.current), ("reasons", .arr (b.reasons.map .str))]

/-- The trace travels as its canonical text, so the page decodes it as the command line decodes a
trace file (`decodeTrace`: same size, depth + shape rules). -/
def encode (s : Snapshot) : Value :=
  .obj [("schema", .str schema), ("trace", .str (Encode.trace s.trace).canonical),
    ("bindings", .arr (s.bindings.map bindingJson)), ("digest", .str s.digest),
    ("review", .str s.review.name)]

/-- The members of an object with exactly the keys `keys` (any order), or why not. -/
def exactly (what : String) (keys : List String) : Value → Except String (List (String × Value))
  | .obj kvs =>
    if kvs.length == keys.length && keys.all (fun k => (kvs.lookup k).isSome) then .ok kvs
    else .error s!"{what} must hold exactly {", ".intercalate keys}"
  | _ => .error s!"{what} is not an object"

def binding (v : Value) : Except String Receipt.Binding := do
  let kvs ← exactly "a binding" ["id", "current", "reasons"] v
  let (some (.str id), some (.bool current), some (.arr rs)) :=
      (kvs.lookup "id", kvs.lookup "current", kvs.lookup "reasons")
    | throw "a binding holds a string id, a boolean current and a list of reasons"
  let reasons ← rs.mapM fun | .str r => pure r | _ => throw "a binding reason is not a string"
  return { id, current, reasons }

def decode (input : String) : Except String Snapshot := do
  let v ← match Json.parse input.toUTF8 with
    | .ok v => pure v
    | .error e => throw s!"the snapshot is not JSON ({e.message})"
  let kvs ← exactly "the snapshot" ["schema", "trace", "bindings", "digest", "review"] v
  unless kvs.lookup "schema" == some (.str schema) do throw s!"the snapshot is not {schema}"
  let (some (.str text), some (.arr bs), some (.str digest), some (.str r)) :=
      (kvs.lookup "trace", kvs.lookup "bindings", kvs.lookup "digest", kvs.lookup "review")
    | throw "the snapshot holds a trace text, a list of bindings, a digest and a review state"
  let t ← match decodeTrace text.toUTF8 with
    | .ok t => pure t
    | .error ds => throw s!"the trace does not decode ({(ds[0]?.map (·.message)).getD "?"})"
  unless (Check.violations t).isEmpty do throw "the trace is not well-formed"
  let bindings ← bs.mapM binding
  let some review := [Receipt.ReviewState.draft, .stale, .reviewed].find? (·.name == r)
    | throw s!"unknown review state \"{r}\""
  return { trace := t, bindings, digest, review }

def problem (kind message : String) : Value :=
  .obj [("problem", .obj [("kind", .str kind), ("message", .str message)])]

/-- The page's one call: the envelope `fvtrace eval --whatif spec` prints for the frozen state, or
the problem the server would answer. -/
@[export fvtrace_snapshot_evaluate]
def evaluate (snapshot spec : String) : String :=
  match decode snapshot with
  | .error m => (problem "invalid" m).pretty
  | .ok s =>
    match Overrides.parse s.trace spec with
    | .error m => (problem "what-if" m).pretty
    | .ok o =>
      let current := fun id => (s.bindings.find? (·.id == id)).any (·.current)
      (Evaluate.envelope { trace := s.trace, current, overrides := o } s.bindings s.digest
        s.review).pretty

end Fvtrace.Snapshot
