import Fvtrace.Args
import Fvtrace.Assets
import Fvtrace.Check
import Fvtrace.Decode
import Fvtrace.Encode
import Fvtrace.Engine
import Fvtrace.Evaluate
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
  "  claims TRACE --project DIR [--whatif F=S,...] [--question Q] [--json]\n" ++
  "      What the analysis can and cannot claim, grouped by question and verdict.\n" ++
  "  gaps TRACE --project DIR [--whatif F=S,...] [--json]\n" ++
  "      Facts whose verification would make the most claims available; violated facts apart.\n" ++
  "  experiments TRACE --project DIR [--whatif F=S,...] [--json]\n" ++
  "      Suggested experiments, ranked by the claims their success would make available.\n" ++
  "  plan TRACE CLAIM --project DIR [--whatif F=S,...] [--json]\n" ++
  "      The cheapest coherent experiments that raise CLAIM as far as the suggestions allow.\n" ++
  "  eval TRACE --project DIR [--whatif F=S,...]\n" ++
  "      The full evaluation as JSON (fvtrace.evaluation/1).\n" ++
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

/-! ## Evaluation commands -/

structure Loaded where
  scenario : Scenario
  bindings : List Receipt.Binding
  digest : String
  review : Receipt.ReviewState

def evalSpec (positional : Nat) : Args.Spec :=
  { valued := ["--project", "--whatif", "--question"], switches := ["--json", "--rehash"],
    positional := [positional] }

/-- Reads, checks + binds a trace; prints why not and returns the exit code otherwise. -/
def load (p : Args.Parsed) : IO (Except UInt32 Loaded) := do
  let file := p.positional.head!
  let t ← match ← readTrace file with
    | .ok (.ok t) => pure t
    | .ok (.error _) =>
      complain s!"fvtrace: {file} does not decode; run fvtrace check {file}"
      return .error 1
    | .error rc => return .error rc
  unless (Check.violations t).isEmpty do
    complain s!"fvtrace: {file} is not well-formed; run fvtrace check {file}"
    return .error 1
  let some dir := p.value? "--project" | return .error (← usageError "give --project DIR")
  let overrides ← match p.value? "--whatif" with
    | none => pure []
    | some spec =>
      match Overrides.parse t spec with
      | .ok o => pure o
      | .error m => return .error (← usageError m)
  let cache ← IO.mkRef ({} : Receipt.Cache)
  let bindings ← Receipt.bindings t dir cache (p.has "--rehash")
  let current := fun id => (bindings.find? (·.id == id)).any (·.current)
  return .ok { scenario := { trace := t, current, overrides }, bindings,
               digest := ← Receipt.reviewDigest t, review := ← Receipt.reviewState t }

def envelopeOf (l : Loaded) : Value :=
  Evaluate.envelope l.scenario l.bindings l.digest l.review

/-- The envelope's members named in `keys`, in envelope order (contract CLI projections). -/
def project (env : Value) (keys : List String) : Value :=
  match env with
  | .obj kvs => .obj (kvs.filter fun (k, _) => keys.contains k)
  | v => v

def projectionKeys : List String := ["schema", "mode", "overrides", "trace"]

def withLoaded (args : List String) (positional : Nat) (k : Args.Parsed → Loaded → IO UInt32) :
    IO UInt32 := do
  let p ← match Args.parse (evalSpec positional) args with
    | .ok p => pure p
    | .error m => return ← usageError m
  match ← load p with
  | .ok l => k p l
  | .error rc => return rc

def footer (l : Loaded) : IO Unit := do
  let mode := if l.scenario.overrides.isEmpty then "recorded statuses" else
    "what-if: " ++ ", ".intercalate (l.scenario.overrides.map fun (k, st) => s!"{k}={st.name}")
  let review := match l.review with
    | .reviewed => "reviewed"
    | .draft => "draft: every verdict is provisional until a reviewer signs off"
    | .stale => "the trace changed since its review: every verdict is provisional"
  say s!"({mode}; {review})"

def claimsCmd (args : List String) : IO UInt32 :=
  withLoaded args 1 fun p l => do
    let sc := l.scenario
    if p.has "--json" then
      IO.print (project (envelopeOf l) (projectionKeys ++ ["subjects", "counts", "claims"])).pretty
      return 0
    let qs := sc.trace.questions.filter fun q => (p.value? "--question").all (· == q.id)
    for q in qs do
      say s!"{q.id} {q.title}: {q.text}"
      let mine := sc.trace.claims.filter (·.question == q.id)
      let groups : List (String × List Claim) :=
        [State.can, .conditional, .«open», .cannot].map (fun st =>
          (st.verdict, mine.filter fun c =>
            !c.latent && !sc.prospective c.subject && sc.final c == st)) ++
        [("Overlooked directions", mine.filter fun c => c.latent && !sc.prospective c.subject)] ++
        ((sc.trace.subjects.filter (·.kind == .prospective)).map fun sub =>
          (s!"If {(sc.creatorTitle sub.id).getD sub.title} runs",
            mine.filter (·.subject == sub.id)))
      for (title, cs) in groups do
        unless cs.isEmpty do
          say s!"  {title}"
          for c in cs do
            let qual := sc.qualifiers c l.review
            let tail := if qual.isEmpty then "" else s!" [{", ".intercalate qual}]"
            say s!"    {c.id} {(sc.final c).verdict}{tail}: {sc.sentence c}"
            let list := fun (xs : List String) => ", ".intercalate xs
            let detail :=
              (if (sc.blockers c).isEmpty then [] else [s!"violated: {list (sc.blockers c)}"]) ++
              (if (sc.incompatible c).isEmpty then []
               else [s!"needs both sides of: {list (sc.incompatible c)}"]) ++
              (if (sc.gaps c).isEmpty then [] else [s!"gaps: {", ".intercalate (sc.gaps c)}"]) ++
              (if (sc.premises c).isEmpty || sc.final c == .conditional then []
               else [s!"assumes: {", ".intercalate (sc.premises c)}"])
            unless detail.isEmpty do say s!"      {"; ".intercalate detail}"
    footer l
    return 0

def gapsCmd (args : List String) : IO UInt32 :=
  withLoaded args 1 fun p l => do
    let sc := l.scenario
    if p.has "--json" then
      IO.print (project (envelopeOf l) (projectionKeys ++ ["work", "blockers"])).pretty
      return 0
    say "Facts whose verification pays (claims each would make available, alone):"
    for w in sc.work do
      let unlocked := ", ".intercalate w.unlocks
      say s!"  {w.fact}: unlocks {w.unlocks.length} ({unlocked}); needed by {w.gates.length}: \
        {sc.factText w.fact}"
    unless sc.blockerFacts.isEmpty do
      say "Violated facts (reword the claim or gather new data):"
      for (f, cs) in sc.blockerFacts do
        say s!"  {f}: blocks {", ".intercalate cs}: {sc.factText f}"
    footer l
    return 0

def experimentsCmd (args : List String) : IO UInt32 :=
  withLoaded args 1 fun p l => do
    let sc := l.scenario
    let env := envelopeOf l
    if p.has "--json" then
      IO.print (project env (projectionKeys ++ ["experiments"])).pretty
      return 0
    for e in sc.trace.experiments.mergeSort (Evaluate.experimentBefore sc) do
      let wins := sc.moves (sc.applySuccess (sc.closure [e.id]))
      let note := if sc.prospective e.subject then " (new data)" else ""
      say s!"  {e.id} [{e.kind.name}, {e.effort.name}]{note} {e.title}: \
        lights {Scenario.lights wins}, clears {Scenario.clears wins}"
    footer l
    return 0

def planCmd (args : List String) : IO UInt32 :=
  withLoaded args 2 fun p l => do
    let sc := l.scenario
    let id := p.positional[1]!
    let some c := sc.trace.claim? id | return ← usageError s!"no claim \"{id}\""
    if p.has "--json" then
      let claim := match envelopeOf l with
        | .obj kvs => match kvs.lookup "claims" with
          | some (.arr cs) => cs.find? fun (v : Value) => match v with
            | .obj ckv => ckv.lookup "id" == some (Value.str id)
            | _ => false
          | _ => none
        | _ => none
      IO.print (Value.obj ((match project (envelopeOf l) projectionKeys with
        | .obj kvs => kvs | _ => []) ++ [("claim", claim.getD .null)])).pretty
      return 0
    say s!"{c.id} {(sc.final c).verdict}: {sc.sentence c}"
    match sc.plan c with
    | .planned cov exps st _ _ contingent =>
      say s!"  Plan (coverage, not scientific priority): {", ".intercalate exps} → {st.verdict}"
      if contingent then
        say "  Its success touches a result fact: it holds only if that result is observed."
      for a in cov.alternatives do say s!"    {a.need}: {a.experiment} sets {a.status.name}"
      unless cov.uncovered.isEmpty do
        say s!"  No suggested experiment raises: {", ".intercalate cov.uncovered}"
    | .noImprovement cov =>
      say "  No suggested experiment raises this claim."
      unless cov.uncovered.isEmpty do say s!"  Uncovered: {", ".intercalate cov.uncovered}"
    | .inconsistent _ => say "  The what-if conflicts on this subject: no plan."
    | .tooLarge _ => say s!"  More than {maxRelevant} relevant experiments: no optimum claimed."
    footer l
    return 0

def evalCmd (args : List String) : IO UInt32 :=
  withLoaded args 1 fun _ l => do
    IO.print (envelopeOf l).pretty
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
  | "claims" :: rest => claimsCmd rest
  | "gaps" :: rest => gapsCmd rest
  | "experiments" :: rest => experimentsCmd rest
  | "plan" :: rest => planCmd rest
  | "eval" :: rest => evalCmd rest
  | [] => IO.eprint usage; pure 2
  | cmd :: _ => usageError s!"unknown command '{cmd}'"

end Fvtrace.Cli
