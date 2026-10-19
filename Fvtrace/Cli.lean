import Fvtrace.Args
import Fvtrace.Assets
import Fvtrace.Check
import Fvtrace.Decode
import Fvtrace.Encode
import Fvtrace.Json
import Fvtrace.Lint
import Fvtrace.Receipt
import Fvtrace.Render
import Fvtrace.Version

namespace Fvtrace.Cli
open Fvtrace.Json

def usage : String :=
  "usage: fvtrace <command> [options]\n\n" ++
  "Commands:\n" ++
  "  check TRACE [--project DIR] [--rehash] [--strict] [--json]\n" ++
  "      Check a trace. With --project, also check each verified fact's receipt against the\n" ++
  "      project folder. Exit 0 = valid, 1 = invalid (with --strict: also on a warning or a\n" ++
  "      stale receipt), 2 = usage or read error.\n" ++
  "  pin TRACE --project DIR\n" ++
  "      Record the sha256 of every evidence artifact and statement in TRACE.\n" ++
  "  review TRACE --reviewer NAME [--note TEXT]\n" ++
  "      Record that NAME reviewed the current content of TRACE.\n" ++
  "  schema      Print the JSON Schema of the trace format.\n" ++
  "  --version   Print the fvTrace version.\n" ++
  "  --help      Print this help.\n"

def say (line : String) : IO Unit := IO.println (Render.safe line)
def complain (line : String) : IO Unit := IO.eprintln (Render.safe line)

/-- Usage error: message + usage on stderr, exit 2. -/
def usageError (message : String) : IO UInt32 := do
  complain s!"fvtrace: {message}"
  IO.eprint usage
  return 2

def readTrace (file : String) : IO (Except UInt32 (Except (Array Decode.Diag) Trace)) := do
  try
    return .ok (decodeTrace (← IO.FS.readBinFile file))
  catch e =>
    complain s!"fvtrace: cannot read {file}: {(toString e).replace "\n" " "}"
    return .error 2

/-- Writes `t` to `file` through a sibling temporary file, so a reader never sees half a trace. -/
def writeTrace (file : String) (t : Trace) : IO Unit := do
  let tmp : System.FilePath := file ++ ".fvtrace-tmp"
  IO.FS.writeFile tmp (Encode.trace t).pretty
  IO.FS.rename tmp file

def diagJson (code path message : String) : Value :=
  .obj [("code", .str code), ("path", .str path), ("message", .str message)]

def warningJson (w : Lint.Warning) : Value :=
  .obj ([("rule", .str w.rule), ("claim", .str w.claim), ("path", .str w.path),
    ("message", .str w.message)] ++
    (match w.waived with | some r => [("waived", .str r)] | none => []))

def bindingJson (b : Receipt.Binding) : Value :=
  .obj [("id", .str b.id), ("current", .bool b.current), ("reasons", .arr (b.reasons.map .str))]

def checkSpec : Args.Spec :=
  { valued := ["--project"], switches := ["--json", "--rehash", "--strict"], positional := [1] }

def pinSpec : Args.Spec := { valued := ["--project"], positional := [1] }

def reviewSpec : Args.Spec := { valued := ["--reviewer", "--note"], positional := [1] }

def check (args : List String) : IO UInt32 := do
  let p ← match Args.parse checkSpec args with
    | .ok p => pure p
    | .error m => return ← usageError m
  let file := p.positional.head!
  let decoded ← match ← readTrace file with
    | .ok d => pure d
    | .error rc => return rc
  let (errors, warnings, trace?) :
      List (String × String × String) × List Lint.Warning × Option Trace :=
    match decoded with
    | .error ds => (ds.toList.map fun d => (d.code, d.path, d.message), [], none)
    | .ok t =>
      ((Check.violations t).map fun v => (v.rule.code, v.path, v.message), Lint.warnings t,
        some t)
  let mut receipts : Option (List Receipt.Binding) := none
  let mut review : Option (Receipt.ReviewState × Option Review) := none
  if let some t := trace? then
    review := some (← Receipt.reviewState t, t.review)
    if errors.isEmpty then
      if let some dir := p.value? "--project" then
        let cache ← IO.mkRef ({} : Receipt.Cache)
        receipts := some (← Receipt.bindings t dir cache (p.has "--rehash"))
  let stale := (receipts.getD []).filter (!·.current)
  if p.has "--json" then
    IO.print (Value.obj ([("valid", .bool errors.isEmpty),
      ("errors", .arr (errors.map fun (c, path, m) => diagJson c path m)),
      ("warnings", .arr (warnings.map warningJson))] ++
      (match receipts with | some bs => [("receipts", .arr (bs.map bindingJson))] | none => []) ++
      (match review with
       | some (st, r) => [("review", .obj ([("state", .str st.name)] ++
           (match r with
            | some r => [("reviewer", .str r.reviewer), ("date", .str r.date)]
            | none => [])))]
       | none => []))).pretty
  else
    say s!"{file}: {if errors.isEmpty then "valid" else "invalid"}"
    for (code, path, message) in errors do say s!"  error {code} {path}: {message}"
    for w in warnings do
      let tail := match w.waived with | some r => s!" (waived: {r})" | none => ""
      say s!"  warning {w.rule} {w.path}: {w.message}{tail}"
    match receipts with
    | some bs =>
      for b in bs do
        let state := if b.current then "current" else s!"stale ({", ".intercalate b.reasons})"
        say s!"  receipt {b.id}: {state}"
    | none => if errors.isEmpty then say "  receipts: not checked (give --project DIR)"
    if let some (st, r) := review then
      let by_ := match r with | some r => s!" by {r.reviewer} on {r.date}" | none => ""
      say s!"  review: {st.name}{by_}"
  let strictFail := p.has "--strict" && (!warnings.isEmpty || !stale.isEmpty)
  return if !errors.isEmpty || strictFail then 1 else 0

def pin (args : List String) : IO UInt32 := do
  let p ← match Args.parse pinSpec args with
    | .ok p => pure p
    | .error m => return ← usageError m
  let file := p.positional.head!
  let some dir := p.value? "--project" | return ← usageError "pin needs --project DIR"
  let t ← match ← readTrace file with
    | .ok (.ok t) => pure t
    | .ok (.error ds) =>
      for d in ds do complain s!"  error {d.code} {d.path}: {d.message}"
      complain s!"fvtrace: {file} does not decode; nothing pinned"
      return 1
    | .error rc => return rc
  let cache ← IO.mkRef ({} : Receipt.Cache)
  let (pinned, problems) ← Receipt.pin t dir cache
  if pinned != t then writeTrace file pinned
  for prob in problems do complain s!"  cannot pin {prob}"
  let tail := if problems.isEmpty then "" else s!", {problems.length} artifact(s) not found"
  say s!"{file}: pinned{tail}"
  return if problems.isEmpty then 0 else 1

def review (args : List String) : IO UInt32 := do
  let p ← match Args.parse reviewSpec args with
    | .ok p => pure p
    | .error m => return ← usageError m
  let file := p.positional.head!
  let some reviewer := p.value? "--reviewer" | return ← usageError "review needs --reviewer NAME"
  unless Decode.validText reviewer && (p.value? "--note").all Decode.validText do
    return ← usageError "--reviewer and --note need non-empty text without control characters"
  let t ← match ← readTrace file with
    | .ok (.ok t) => pure t
    | .ok (.error _) => complain s!"fvtrace: {file} does not decode; run fvtrace check"; return 1
    | .error rc => return rc
  unless (Check.violations t).isEmpty do
    complain s!"fvtrace: {file} is not well-formed; run fvtrace check before reviewing"
    return 1
  let reviewed ← Receipt.review t reviewer (p.value? "--note")
  writeTrace file reviewed
  say s!"{file}: reviewed by {reviewer}"
  return 0

/-- Exit codes: 0 = success, 1 = an invalid or failing trace, 2 = usage or read error. -/
def run (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println s!"fvtrace {version}"; pure 0
  | ["--help"] | ["-h"] => IO.print usage; pure 0
  | ["schema"] => IO.print Assets.traceSchema; pure 0
  | "check" :: rest => check rest
  | "pin" :: rest => pin rest
  | "review" :: rest => review rest
  | [] => IO.eprint usage; pure 2
  | cmd :: _ => usageError s!"unknown command '{cmd}'"

end Fvtrace.Cli
