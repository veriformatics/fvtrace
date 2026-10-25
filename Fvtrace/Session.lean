import Fvtrace.Check
import Fvtrace.Evaluate
import Fvtrace.Receipt
import Fvtrace.Store

/-!
# One evaluation of a project's trace

Reads, checks + binds a trace and evaluates it under a what-if: the step the CLI and the server
share. Each surface words a `Problem` its own way (exit code + message, or an error response).
-/

namespace Fvtrace.Session
open Fvtrace.Json

/-- Why a trace cannot be evaluated. -/
inductive Problem where
  /-- The project has no trace in the data folder yet. -/
  | noTrace (project : System.FilePath)
  | unreadable (file : System.FilePath) (reason : String)
  | undecodable (file : System.FilePath) (diags : Array Decode.Diag)
  | illFormed (file : System.FilePath) (violations : List Check.Violation)
  | badWhatif (reason : String)
  /-- The action is not among the suggested what-ifs (`kernel.md` V-action). -/
  | badAction (reason : String)
  /-- The item is malformed or names no record (`kernel.md` V-details). -/
  | badItem (reason : String)

structure Loaded where
  target : Store.Target
  scenario : Scenario
  bindings : List Receipt.Binding
  digest : String
  review : Receipt.ReviewState

/-- The digest cache of the target's data folder entry (in memory alone when there is none). -/
def openCache (t : Store.Target) : IO (IO.Ref Receipt.Cache) := do
  if ← t.entry.isDir then IO.mkRef (← Receipt.Cache.load t.cacheFile) else IO.mkRef {}

def closeCache (t : Store.Target) (cache : IO.Ref Receipt.Cache) : IO Unit := do
  if ← t.entry.isDir then (← cache.get).save t.cacheFile

/-- The first `n` bytes of `path` (all of it when shorter), read in 1 MiB chunks. -/
def readPrefix (path : System.FilePath) (n : Nat) : IO ByteArray := do
  let h ← IO.FS.Handle.mk path .read
  let mut out := ByteArray.empty
  while out.size < n do
    let chunk ← h.read (min 1048576 (n - out.size)).toUSize
    if chunk.isEmpty then break
    out := out ++ chunk
  return out

/-- Reads the target's trace, at most `limit` bytes; `explicit` = the user named the file
(`--trace`). A trace can come from someone else (a bundle), so only a regular file is opened (a
FIFO blocks on open, a device such as `/dev/zero` never ends), its size decides before any byte is
read, and at most one byte past the limit is read (a file growing meanwhile still meets the
decoder's size rule). `reader` = how a prefix is read (a test grows the file inside it). -/
def readRawWithin (limit : Nat) (t : Store.Target) (explicit : Bool)
    (reader : System.FilePath → Nat → IO ByteArray := readPrefix) :
    IO (Except Problem (Except (Array Decode.Diag) ByteArray)) := do
  if !explicit && !(← t.trace.pathExists) then return .error (.noTrace t.project)
  try
    let m ← t.trace.metadata
    unless m.type == .file do return .error (.unreadable t.trace "not a regular file")
    if m.byteSize.toNat > limit then return .ok (.error #[sizeDiag m.byteSize.toNat limit])
    return .ok (.ok (← reader t.trace (limit + 1)))
  catch e =>
    return .error (.unreadable t.trace ((toString e).replace "\n" " "))

def readWithin (limit : Nat) (t : Store.Target) (explicit : Bool) :
    IO (Except Problem (Except (Array Decode.Diag) Trace)) := do
  return match ← readRawWithin limit t explicit with
  | .ok (.ok bytes) => .ok (decodeTraceWithin limit bytes)
  | .ok (.error ds) => .ok (.error ds)
  | .error p => .error p

/-- D-json: at most 16 MiB. -/
def read : Store.Target → Bool → IO (Except Problem (Except (Array Decode.Diag) Trace)) :=
  readWithin maxTraceBytes

/-- What a checked trace's content alone decides: its lookups, review digest + review state
(`fvtrace serve` keeps it beside the trace, both keyed by the trace's bytes: kernel.md P-cache). -/
structure Prepared where
  digest : String
  review : Receipt.ReviewState

def prepare (tr : Trace) : IO Prepared := do
  let digest ← Receipt.reviewDigest tr
  return { digest, review := Receipt.reviewStateOf tr digest }

/-- `bindChecked` on the trace's prepared parts: receipts bound afresh (evidence is read again),
then the what-if. -/
def bindPrepared (t : Store.Target) (tr : Trace) (p : Prepared) (whatif : Option String)
    (rehash : Bool) (cache : IO.Ref Receipt.Cache) : IO (Except Problem Loaded) := do
  let L := Lookups.fast tr
  let overrides ← match whatif with
    | none => pure []
    | some spec =>
      match Overrides.parseWith L spec with
      | .ok o => pure o
      | .error m => return .error (.badWhatif m)
  let bindings ← Receipt.bindings tr t.project cache rehash L
  let byId := Receipt.BindingIndex.of bindings
  let current := fun id => (byId.find id).any (·.current)
  return .ok { target := t, scenario := { trace := tr, current, overrides }, bindings,
               digest := p.digest, review := p.review }

/-- Binds a checked trace + applies the what-if (`FACT=STATUS,…`): `load` past its reading. -/
def bindChecked (t : Store.Target) (tr : Trace) (whatif : Option String) (rehash : Bool)
    (cache : IO.Ref Receipt.Cache) : IO (Except Problem Loaded) := do
  bindPrepared t tr (← prepare tr) whatif rehash cache

/-- A trace decoded + checked: the trace, or why not. -/
def checked (t : Store.Target) (decoded : Except (Array Decode.Diag) Trace) :
    Except Problem Trace :=
  match decoded with
  | .error ds => .error (.undecodable t.trace ds)
  | .ok tr =>
    let vs := Check.violationsWith (Lookups.fast tr) tr
    if vs.isEmpty then .ok tr else .error (.illFormed t.trace vs)

/-- Reads, checks + binds the trace, then applies the what-if (`FACT=STATUS,…`). -/
def load (t : Store.Target) (explicit : Bool) (whatif : Option String) (rehash : Bool)
    (cache : IO.Ref Receipt.Cache) : IO (Except Problem Loaded) := do
  let tr ← match ← read t explicit with
    | .ok d => match checked t d with
      | .ok tr => pure tr
      | .error p => return .error p
    | .error p => return .error p
  bindChecked t tr whatif rehash cache

def envelope (l : Loaded) : Value := Evaluate.envelope l.scenario l.bindings l.digest l.review

/-- The loaded evaluation at the action's complete what-if (`kernel.md` V-action). -/
def expand (l : Loaded) (action : String) : Except Problem Loaded :=
  match Evaluate.expandWith l.scenario.trace (Answers.fast l.scenario) action with
  | .ok o => .ok { l with scenario := { l.scenario with overrides := o } }
  | .error m => .error (.badAction m)

/-- The details of one item at the loaded what-if (`kernel.md` V-details). -/
def details (l : Loaded) (item : String) : Except Problem Value :=
  (Evaluate.detailsWith l.scenario (Answers.fast l.scenario) l.digest l.review item).mapError
    .badItem

/-- The view an answer reads (`kernel.md` V-serve `X-Fvtrace-View`): the envelope's `trace` member
(content digest + review), the receipt bindings with their reasons, the what-if. -/
def viewOf (l : Loaded) : IO String :=
  Digest.ofString (Value.obj [("trace", Evaluate.traceJson l.scenario.trace l.digest l.review),
    ("bindings", .arr (l.bindings.map fun b => .obj [("id", .str b.id),
      ("current", .bool b.current), ("reasons", .arr (b.reasons.map .str))])),
    ("overrides", Evaluate.overridesJson l.scenario.overrides)]).canonical

/-- The batch document (`kernel.md` V-complete). -/
def complete (l : Loaded) : Value :=
  Evaluate.completeWith l.scenario (Answers.fast l.scenario) l.bindings l.digest l.review

end Fvtrace.Session
