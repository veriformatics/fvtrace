import Fvtrace.Json

namespace Tests

structure Outcome where
  name : String
  ok : Bool
  detail : String

structure Run where
  outcomes : Array Outcome := #[]
  /-- Wall-clock (ms) per suite area, in run order. -/
  times : Array (String × Nat) := #[]

/-- The record lives in a reference, so an exception keeps what an area recorded before it. -/
abbrev TestM := ReaderT (IO.Ref Run) IO

def check (name : String) (ok : Bool) (detail : String := "") : TestM Unit := do
  (← read).modify fun r => { r with outcomes := r.outcomes.push { name, ok, detail } }

def checkEq {α : Type} [BEq α] [Repr α] (name : String) (got want : α) : TestM Unit :=
  check name (got == want) s!"got {repr got}, want {repr want}"

def fields : Fvtrace.Json.Value → List (String × Fvtrace.Json.Value)
  | .obj kvs => kvs
  | _ => []

def field (v : Fvtrace.Json.Value) (k : String) : Option Fvtrace.Json.Value := (fields v).lookup k

/-- The record with this `id` in array `key` of an envelope. -/
def recordOf (env : Fvtrace.Json.Value) (key id : String) : Option Fvtrace.Json.Value := do
  let .arr xs ← field env key | none
  xs.find? fun x => field x "id" == some (.str id)

def claimOf (env : Fvtrace.Json.Value) (id : String) : Option Fvtrace.Json.Value :=
  recordOf env "claims" id

/-- Runs `act` with stdout + stderr captured; returns (result, stdout, stderr). -/
def capture {α : Type} (act : IO α) : IO (α × String × String) := do
  let out ← IO.mkRef ({} : IO.FS.Stream.Buffer)
  let err ← IO.mkRef ({} : IO.FS.Stream.Buffer)
  let r ← IO.withStdout (IO.FS.Stream.ofBuffer out) <| IO.withStderr (IO.FS.Stream.ofBuffer err) act
  let o := String.fromUTF8! (← out.get).data
  let e := String.fromUTF8! (← err.get).data
  return (r, o, e)

/-- Creates `link` → `target` (`ln -s`; `mklink` on Windows, where CI runs as administrator). -/
def symlink (target link : System.FilePath) (dir : Bool) : IO Bool := do
  let out ← if System.Platform.isWindows then
      IO.Process.output { cmd := "cmd", args := #["/c", "mklink"] ++
        (if dir then #["/D"] else #[]) ++ #[link.toString, target.toString] }
    else IO.Process.output { cmd := "ln", args := #["-s", target.toString, link.toString] }
  return out.exitCode == 0

/-- Runs one suite area + records its wall-clock (the gate prints a suite's slowest parts). An
exception fails the area as one more check and the next areas still run, so one run (a CI job on
another platform) reports every failure. -/
def area (name : String) (suite : TestM Unit) : TestM Unit := do
  let t0 ← IO.monoMsNow
  try suite catch e => check s!"{name}: the area runs to its end" false (toString e)
  let ms := (← IO.monoMsNow) - t0
  (← read).modify fun r => { r with times := r.times.push (name, ms) }

/-- Runs `suite` from an empty record. -/
def exec (suite : TestM Unit) : IO Run := do
  let ref ← IO.mkRef {}
  suite ref
  ref.get

/-- Prints each failure + a summary with the three slowest areas; rc 0 iff every check passed. -/
def report (r : Run) : IO UInt32 := do
  let failed := r.outcomes.filter (!·.ok)
  for f in failed do
    IO.eprintln s!"FAIL {f.name}: {f.detail}"
  let slow := ((r.times.qsort fun a b => a.2 > b.2).toList.take 3).map fun (n, ms) =>
    s!"{n} {ms} ms"
  IO.println s!"{r.outcomes.size - failed.size}/{r.outcomes.size} checks passed \
    (slowest: {", ".intercalate slow})"
  return if failed.isEmpty then 0 else 1

end Tests
