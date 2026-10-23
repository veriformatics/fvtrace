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
decoder's size rule). -/
def readWithin (limit : Nat) (t : Store.Target) (explicit : Bool) :
    IO (Except Problem (Except (Array Decode.Diag) Trace)) := do
  if !explicit && !(← t.trace.pathExists) then return .error (.noTrace t.project)
  try
    let m ← t.trace.metadata
    unless m.type == .file do return .error (.unreadable t.trace "not a regular file")
    if m.byteSize.toNat > limit then return .ok (.error #[sizeDiag m.byteSize.toNat limit])
    return .ok (decodeTraceWithin limit (← readPrefix t.trace (limit + 1)))
  catch e =>
    return .error (.unreadable t.trace ((toString e).replace "\n" " "))

/-- D-json: at most 16 MiB. -/
def read : Store.Target → Bool → IO (Except Problem (Except (Array Decode.Diag) Trace)) :=
  readWithin maxTraceBytes

/-- Reads, checks + binds the trace, then applies the what-if (`FACT=STATUS,…`). -/
def load (t : Store.Target) (explicit : Bool) (whatif : Option String) (rehash : Bool)
    (cache : IO.Ref Receipt.Cache) : IO (Except Problem Loaded) := do
  let tr ← match ← read t explicit with
    | .ok (.ok tr) => pure tr
    | .ok (.error ds) => return .error (.undecodable t.trace ds)
    | .error p => return .error p
  let L := Lookups.fast tr
  let vs := Check.violationsWith L tr
  unless vs.isEmpty do return .error (.illFormed t.trace vs)
  let overrides ← match whatif with
    | none => pure []
    | some spec =>
      match Overrides.parse tr spec with
      | .ok o => pure o
      | .error m => return .error (.badWhatif m)
  let bindings ← Receipt.bindings tr t.project cache rehash L
  let byId := Receipt.BindingIndex.of bindings
  let current := fun id => (byId.find id).any (·.current)
  return .ok { target := t, scenario := { trace := tr, current, overrides }, bindings,
               digest := ← Receipt.reviewDigest tr, review := ← Receipt.reviewState tr }

def envelope (l : Loaded) : Value := Evaluate.envelope l.scenario l.bindings l.digest l.review

end Fvtrace.Session
