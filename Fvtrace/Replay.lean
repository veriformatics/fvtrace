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

/-- A run's verifier failure, its output aside (`kernel.md` § Replay, Notice); `none` = it exited
with 0. A spawn exception's message stays in the run's report + the log, out of the trace. -/
def verifierFailure? : Except String Run → Option String
  | .error _ => some "cannot start"
  | .ok r =>
    match r.exit with
    | none => some "timeout"
    | some 0 => none
    | some n => some s!"exit {n}"

/-- What a run does to its replay's notice. -/
inductive NoticeChange where
  | set (notice : ReplayFailure)
  | clear
  | keep
  deriving DecidableEq, Repr

/-- `verify --run` on `date`: a pass clears, a verifier failure or a changed output sets; `output
not pinned` is no verifier failure, so the notice stays as it was. -/
def verifyChange (date : String) (pinned : Option String) (res : Except String Run) :
    NoticeChange :=
  match verifierFailure? res, res with
  | some why, _ => .set { date, reason := why }
  | none, .ok r =>
    match pinned with
    | none => .keep
    | some d => if d == r.digest then .clear else .set { date, reason := "output changed" }
  | none, .error _ => .keep

/-- `pin --replay` on `date`: exit 0 pins the output, so it passes. -/
def pinChange (date : String) (res : Except String Run) : NoticeChange :=
  match verifierFailure? res with
  | some why => .set { date, reason := why }
  | none => .clear

/-- Why a `pin --replay` run failed, as `reasons` words it; `[]` = it exited with 0. -/
def pinReasons (res : Except String Run) : List String :=
  if (verifierFailure? res).isNone then [] else reasons none res

def NoticeChange.apply : NoticeChange → Replay → Replay
  | .set x, r => { r with failed := some x }
  | .clear, r => { r with failed := none }
  | .keep, r => r

/-- `t` with `g i r` in place of the `i`-th replay of `targets t`: by position, so each result
lands on its own record when a decode-only trace repeats an id. -/
def updateAt (t : Trace) (g : Nat → Replay → Replay) : Trace := Id.run do
  let mut i := 0
  let mut facts := #[]
  for f in t.facts do
    match f.evidence with
    | some ev@{ replay := some r, .. } =>
      facts := facts.push { f with evidence := some { ev with replay := some (g i r) } }
      i := i + 1
    | _ => facts := facts.push f
  let mut exclusions := #[]
  for x in t.exclusions do
    match x.evidence with
    | some ev@{ replay := some r, .. } =>
      exclusions := exclusions.push { x with evidence := some { ev with replay := some (g i r) } }
      i := i + 1
    | _ => exclusions := exclusions.push x
  return { t with facts := facts.toList, exclusions := exclusions.toList }

/-- `t` with each run's result applied to its replay, `results` in `targets t` order: the new
`output` (`pin --replay`'s exit 0) and the notice change. -/
def withResults (t : Trace) (results : Array (Option String × NoticeChange)) : Trace :=
  updateAt t fun i r =>
    match results[i]? with
    | some (out, change) => change.apply { r with output := out <|> r.output }
    | none => r

end Fvtrace.Replay
