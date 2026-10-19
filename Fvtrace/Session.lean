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

/-- Reads the target's trace; `explicit` = the user named the file (`--trace`). -/
def read (t : Store.Target) (explicit : Bool) :
    IO (Except Problem (Except (Array Decode.Diag) Trace)) := do
  if !explicit && !(← t.trace.pathExists) then return .error (.noTrace t.project)
  try
    return .ok (decodeTrace (← IO.FS.readBinFile t.trace))
  catch e =>
    return .error (.unreadable t.trace ((toString e).replace "\n" " "))

/-- Reads, checks + binds the trace, then applies the what-if (`FACT=STATUS,…`). -/
def load (t : Store.Target) (explicit : Bool) (whatif : Option String) (rehash : Bool)
    (cache : IO.Ref Receipt.Cache) : IO (Except Problem Loaded) := do
  let tr ← match ← read t explicit with
    | .ok (.ok tr) => pure tr
    | .ok (.error ds) => return .error (.undecodable t.trace ds)
    | .error p => return .error p
  let vs := Check.violations tr
  unless vs.isEmpty do return .error (.illFormed t.trace vs)
  let overrides ← match whatif with
    | none => pure []
    | some spec =>
      match Overrides.parse tr spec with
      | .ok o => pure o
      | .error m => return .error (.badWhatif m)
  let bindings ← Receipt.bindings tr t.project cache rehash
  let current := fun id => (bindings.find? (·.id == id)).any (·.current)
  return .ok { target := t, scenario := { trace := tr, current, overrides }, bindings,
               digest := ← Receipt.reviewDigest tr, review := ← Receipt.reviewState tr }

def envelope (l : Loaded) : Value := Evaluate.envelope l.scenario l.bindings l.digest l.review

end Fvtrace.Session
