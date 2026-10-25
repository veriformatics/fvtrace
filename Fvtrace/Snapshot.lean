import Fvtrace.Check
import Fvtrace.Decode
import Fvtrace.Evaluate
import Fvtrace.Request

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
      let byId := Receipt.BindingIndex.of s.bindings
      let current := fun id => (byId.find id).any (·.current)
      (Evaluate.envelope { trace := s.trace, current, overrides := o } s.bindings s.digest
        s.review).pretty

/-- The page engine's state (`kernel.md` E-state): the snapshot, decoded once. -/
structure Engine where
  snap : Snapshot

/-- Decodes the snapshot once; the refusal = the `invalid` problem's text. -/
def Engine.load (text : String) : Except String Engine :=
  match decode text with
  | .ok s => .ok { snap := s }
  | .error m => .error (problem "invalid" m).pretty

/-- One request's answer (`kernel.md` V-request, E-request): the envelope at the action's what-if,
or the details of an item there, or a problem; checked in that order: the request, the what-if,
the action, the item. The same text `fvtrace eval` prints or the server answers. -/
def Engine.answer (e : Engine) (request : String) : Engine × String :=
  let s := e.snap
  let text := match Request.parse request with
    | .error m => (problem "invalid" m).pretty
    | .ok r =>
      match Overrides.parse s.trace r.whatif with
      | .error m => (problem "what-if" m).pretty
      | .ok o =>
        let byId := Receipt.BindingIndex.of s.bindings
        let current := fun id => (byId.find id).any (·.current)
        let sc : Scenario := { trace := s.trace, current, overrides := o }
        let expanded := match r.action with
          | some a => (Evaluate.expandWith s.trace (Answers.fast sc) a).map fun o' =>
              ({ sc with overrides := o' } : Scenario)
          | none => .ok sc
        match expanded with
        | .error m => (problem "action" m).pretty
        | .ok sc' =>
          match r.details with
          | some item =>
            match Evaluate.detailsWith sc' (Answers.fast sc') s.digest s.review item with
            | .ok v => v.pretty
            | .error m => (problem "item" m).pretty
          | none => (Evaluate.envelope sc' s.bindings s.digest s.review).pretty
  (e, text)

/-- The page's start-up call: the engine, or the problem text. -/
@[export fvtrace_snapshot_load]
def loadExport (snapshot : String) : Except String Engine := Engine.load snapshot

/-- The page's request call: the next engine state + the answer's text. -/
@[export fvtrace_snapshot_answer]
def answerExport (e : Engine) (request : String) : Engine × String := e.answer request

end Fvtrace.Snapshot
