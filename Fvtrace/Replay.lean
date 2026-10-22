import Fvtrace.Digest
import Fvtrace.Model

/-!
# Replay: re-running a declared verifier (`fvtrace verify --run`, `fvtrace pin --replay`)

Opt-in alone (the CLI asks for `--run` / `--replay`) and never part of a verdict: receipts stay
digest-only. A command runs as argv (no shell) in the project folder; its standard output is
hashed as raw bytes while it streams, the last 4 KiB of its standard error kept for display.
-/

namespace Fvtrace.Replay

/-- Every fact, then every exclusion, whose evidence carries a replay, in array order. -/
def targets (t : Trace) : List (String × Replay) :=
  (t.facts.filterMap fun f => (f.evidence.bind (·.replay)).map (f.id, ·)) ++
  (t.exclusions.filterMap fun x => (x.evidence.bind (·.replay)).map (x.id, ·))

/-- A command line for display: an argument with a space or a quote gets quoted. -/
def display (command : List String) : String :=
  " ".intercalate (command.map fun a =>
    if a.any (fun c => c.isWhitespace || c == '"' || c == '\'') then
      "\"" ++ (a.replace "\\" "\\\\").replace "\"" "\\\"" ++ "\""
    else a)

structure Run where
  /-- `none` = killed at the deadline. -/
  exit : Option UInt32
  /-- SHA-256 of standard output, lowercase hex. -/
  digest : String
  stderrTail : String

def tailBytes : Nat := 4096

/-- How often a run under a deadline checks the process + its pipes (ms). -/
def pollMs : UInt32 := 20

/-- The deadline (monotonic ms) of a run started at `start` with `--timeout s`. -/
def deadline (start s : Nat) : Nat := start + s * 1000

def expired (now limit : Nat) : Bool := now ≥ limit

/-- Runs `command` in `cwd`, `timeout` in whole seconds; `.error` = the process did not start. -/
def run (cwd : System.FilePath) (command : List String) (timeout : Option Nat) :
    IO (Except String Run) := do
  let program :: args := command | return .error "cannot start: an empty command"
  -- `setsid`: a deadline kill reaches the whole process group (POSIX; a no-op elsewhere).
  let child ← try
      IO.Process.spawn
        { cmd := program, args := args.toArray, cwd := some cwd, stdin := .null,
          stdout := .piped, stderr := .piped, setsid := true }
    catch e => return .error s!"cannot start: {e}"
  let sha ← Digest.Sha256.new
  -- Both pipes drain at once: a verifier filling one pipe while fvTrace waits on the other would
  -- block forever.
  let out ← IO.asTask (prio := .dedicated) do
    repeat
      let chunk ← child.stdout.read 65536
      if chunk.isEmpty then break
      sha.update chunk
  let err ← IO.asTask (prio := .dedicated) do
    let mut tail := ByteArray.empty
    repeat
      let chunk ← child.stderr.read 65536
      if chunk.isEmpty then break
      let all := tail ++ chunk
      tail := if all.size ≤ tailBytes then all else all.extract (all.size - tailBytes) all.size
    return tail
  let exit ← match timeout with
    | none =>
      let _ ← IO.wait out
      let _ ← IO.wait err
      pure (some (← child.wait))
    | some s =>
      -- The deadline covers exit and both pipes' end (a child may hold a pipe after its parent
      -- exits); `tryWait` reaps once, so its code is kept, never waited for again.
      let limit := deadline (← IO.monoMsNow) s
      let mut code : Option UInt32 := none
      let mut killed := false
      repeat
        if code.isNone then code ← child.tryWait
        if code.isSome && (← IO.hasFinished out) && (← IO.hasFinished err) then break
        if expired (← IO.monoMsNow) limit then
          child.kill
          killed := true
          break
        IO.sleep pollMs
      if killed then
        let _ ← IO.wait out
        let _ ← IO.wait err
        if code.isNone then let _ ← child.wait
        pure none
      else pure code
  let tail ← match ← IO.wait err with
    | .ok bytes => pure (String.fromUTF8? bytes |>.getD "(not UTF-8)")
    | .error e => pure s!"(unreadable: {e})"
  return .ok { exit, digest := Digest.hex (← sha.finish), stderrTail := tail }

/-- Why a run fails the pinned `output`, first match first; `[]` = it passes. -/
def reasons (pinned : Option String) : Except String Run → List String
  | .error e => [e]
  | .ok r =>
    match r.exit with
    | none => ["timeout"]
    | some 0 =>
      match pinned with
      | none => ["output not pinned"]
      | some d => if d == r.digest then [] else ["output changed"]
    | some n => [s!"exit {n}"]

/-- `t` with each id's replay `output` set (pairs from `pin --replay`). -/
def withOutputs (t : Trace) (outputs : List (String × String)) : Trace :=
  let setReplay := fun (id : String) (r : Replay) =>
    match outputs.lookup id with
    | some d => { r with output := some d }
    | none => r
  let set := fun (id : String) (ev : Option Evidence) =>
    ev.map fun e => { e with replay := e.replay.map (setReplay id) }
  { t with
    facts := t.facts.map fun f => { f with evidence := set f.id f.evidence }
    exclusions := t.exclusions.map fun x => { x with evidence := set x.id x.evidence } }

end Fvtrace.Replay
