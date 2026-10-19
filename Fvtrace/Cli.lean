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
import Fvtrace.Store
import Fvtrace.Version

namespace Fvtrace.Cli
open Fvtrace.Json

def usage : String :=
  "usage: fvtrace <command> [options]\n\n" ++
  "fvTrace keeps one trace for each project folder in its data folder (FVTRACE_HOME,\n" ++
  "else the data folder of the platform). A command works on the project in the\n" ++
  "current folder.\n" ++
  "  --project DIR   Use the project in the folder DIR.\n" ++
  "  --trace FILE    Read the trace in FILE (for example, a draft) instead.\n\n" ++
  "Commands:\n" ++
  "  init\n" ++
  "      Create the trace of the project and show where it is. The new trace is\n" ++
  "      valid and claims nothing.\n" ++
  "  path\n" ++
  "      Print the location of the trace of the project.\n" ++
  "  check [--strict] [--rehash] [--json]\n" ++
  "      Check the trace, and the receipt of each verified fact against the project\n" ++
  "      folder. With --strict, a warning or a stale receipt also fails the check.\n" ++
  "      With --rehash, read each artifact again instead of the digest cache.\n" ++
  "  pin\n" ++
  "      Record the sha256 of each evidence artifact and statement in the trace.\n" ++
  "  review --reviewer NAME [--note TEXT]\n" ++
  "      Record that NAME reviewed the current content of the trace.\n" ++
  "  claims [--question Q]\n" ++
  "      Show what the analysis can and cannot claim, by question and verdict.\n" ++
  "  gaps\n" ++
  "      Show the facts whose verification makes the most claims available, and the\n" ++
  "      violated facts.\n" ++
  "  experiments\n" ++
  "      Show the suggested experiments, ranked by the claims that they make\n" ++
  "      available when they succeed.\n" ++
  "  plan CLAIM\n" ++
  "      Show the cheapest coherent experiments that raise CLAIM as far as the\n" ++
  "      suggestions allow.\n" ++
  "  eval\n" ++
  "      Print the full evaluation as JSON (fvtrace.evaluation/1).\n" ++
  "  schema\n" ++
  "      Print the JSON Schema of the trace format.\n\n" ++
  "claims, gaps, experiments, plan and eval accept --whatif FACT=STATUS,... to\n" ++
  "suppose statuses, and --rehash. check, claims, gaps, experiments and plan accept\n" ++
  "--json for machine output.\n" ++
  "  --version   Print the fvTrace version.\n" ++
  "  --help      Print this help.\n\n" ++
  "Exit status: 0 = success, 1 = an invalid or failing trace, 2 = a usage or read\n" ++
  "error.\n"

def say (line : String) : IO Unit := IO.println (Render.safe line)
def complain (line : String) : IO Unit := IO.eprintln (Render.safe line)

/-- Usage error: message + usage on stderr, exit 2. -/
def usageError (message : String) : IO UInt32 := do
  complain s!"fvtrace: {message}"
  IO.eprint usage
  return 2

def readTrace (file : System.FilePath) :
    IO (Except UInt32 (Except (Array Decode.Diag) Trace)) := do
  try
    return .ok (decodeTrace (← IO.FS.readBinFile file))
  catch e =>
    complain s!"fvtrace: cannot read {file}: {(toString e).replace "\n" " "}"
    return .error 2

/-- Writes `t` to `file` through a sibling temporary file, so a reader never sees half a trace. -/
def writeTrace (file : System.FilePath) (t : Trace) : IO Unit := do
  let tmp : System.FilePath := file.toString ++ ".fvtrace-tmp"
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

/-- Flags every command that works on a trace accepts. -/
def located : List String := ["--project", "--trace"]

def parseArgs (spec : Args.Spec) (args : List String) : IO (Except UInt32 Args.Parsed) := do
  match Args.parse spec args with
  | .ok p => return .ok p
  | .error m => return .error (← usageError m)

/-- The trace + project a command works on. -/
def target (env : Store.Env) (p : Args.Parsed) : IO (Except UInt32 Store.Target) := do
  match ← Store.resolve env (p.value? "--project") (p.value? "--trace") with
  | .ok t => return .ok t
  | .error m => complain s!"fvtrace: {m}"; return .error 2

/-- Reads the target's trace; a missing trace names its fix. -/
def readTarget (p : Args.Parsed) (t : Store.Target) :
    IO (Except UInt32 (Except (Array Decode.Diag) Trace)) := do
  if (p.value? "--trace").isNone && !(← t.trace.pathExists) then
    complain s!"fvtrace: no trace for the project {t.project} yet; run fvtrace init"
    return .error 2
  readTrace t.trace

/-- The digest cache of the target's data folder entry (in memory alone when there is none). -/
def openCache (t : Store.Target) : IO (IO.Ref Receipt.Cache) := do
  if ← t.entry.isDir then IO.mkRef (← Receipt.Cache.load t.cacheFile) else IO.mkRef {}

def closeCache (t : Store.Target) (cache : IO.Ref Receipt.Cache) : IO Unit := do
  if ← t.entry.isDir then (← cache.get).save t.cacheFile

def initCmd (env : Store.Env) (args : List String) : IO UInt32 := do
  let p ← match ← parseArgs { valued := ["--project"] } args with
    | .ok p => pure p
    | .error rc => return rc
  let t ← match ← target env p with
    | .ok t => pure t
    | .error rc => return rc
  if ← t.trace.pathExists then
    complain s!"fvtrace: {t.trace} already exists"
    return 2
  IO.FS.createDirAll t.entry
  IO.FS.writeFile (Store.projectFile t.entry) (Store.projectJson t.project).pretty
  writeTrace t.trace (Store.starter t.project)
  say s!"Created the trace {t.trace}"
  say s!"for the project folder {t.project}."
  say "Describe the analysis in it (or let your coding agent draft it), then run fvtrace check."
  return 0

def pathCmd (env : Store.Env) (args : List String) : IO UInt32 := do
  let p ← match ← parseArgs { valued := ["--project"] } args with
    | .ok p => pure p
    | .error rc => return rc
  match ← target env p with
  | .ok t => say t.trace.toString; return 0
  | .error rc => return rc

def checkSpec : Args.Spec := { valued := located, switches := ["--json", "--rehash", "--strict"] }

def pinSpec : Args.Spec := { valued := located }

def reviewSpec : Args.Spec := { valued := located ++ ["--reviewer", "--note"] }

def check (env : Store.Env) (args : List String) : IO UInt32 := do
  let p ← match ← parseArgs checkSpec args with
    | .ok p => pure p
    | .error rc => return rc
  let tg ← match ← target env p with
    | .ok t => pure t
    | .error rc => return rc
  let decoded ← match ← readTarget p tg with
    | .ok d => pure d
    | .error rc => return rc
  let (errors, warnings, trace?) :
      List (String × String × String) × List Lint.Warning × Option Trace :=
    match decoded with
    | .error ds => (ds.toList.map fun d => (d.code, d.path, d.message), [], none)
    | .ok t =>
      ((Check.violations t).map fun v => (v.rule.code, v.path, v.message), Lint.warnings t,
        some t)
  let mut receipts : List Receipt.Binding := []
  let mut review : Option (Receipt.ReviewState × Option Review) := none
  if let some t := trace? then
    review := some (← Receipt.reviewState t, t.review)
    if errors.isEmpty then
      let cache ← openCache tg
      receipts ← Receipt.bindings t tg.project cache (p.has "--rehash")
      closeCache tg cache
  let stale := receipts.filter (!·.current)
  if p.has "--json" then
    IO.print (Value.obj ([("trace", .str tg.trace.toString),
      ("project", .str tg.project.toString), ("valid", .bool errors.isEmpty),
      ("errors", .arr (errors.map fun (c, path, m) => diagJson c path m)),
      ("warnings", .arr (warnings.map warningJson))] ++
      (if errors.isEmpty then [("receipts", .arr (receipts.map bindingJson))] else []) ++
      (match review with
       | some (st, r) => [("review", .obj ([("state", .str st.name)] ++
           (match r with
            | some r => [("reviewer", .str r.reviewer), ("date", .str r.date)]
            | none => [])))]
       | none => []))).pretty
  else
    say s!"{tg.trace}: {if errors.isEmpty then "valid" else "invalid"}"
    say s!"  project: {tg.project}"
    for (code, path, message) in errors do say s!"  error {code} {path}: {message}"
    for w in warnings do
      let tail := match w.waived with | some r => s!" (waived: {r})" | none => ""
      say s!"  warning {w.rule} {w.path}: {w.message}{tail}"
    for b in receipts do
      let state := if b.current then "current" else s!"stale ({", ".intercalate b.reasons})"
      say s!"  receipt {b.id}: {state}"
    if let some (st, r) := review then
      let by_ := match r with | some r => s!" by {r.reviewer} on {r.date}" | none => ""
      say s!"  review: {st.name}{by_}"
  let strictFail := p.has "--strict" && (!warnings.isEmpty || !stale.isEmpty)
  return if !errors.isEmpty || strictFail then 1 else 0

def pin (env : Store.Env) (args : List String) : IO UInt32 := do
  let p ← match ← parseArgs pinSpec args with
    | .ok p => pure p
    | .error rc => return rc
  let tg ← match ← target env p with
    | .ok t => pure t
    | .error rc => return rc
  let t ← match ← readTarget p tg with
    | .ok (.ok t) => pure t
    | .ok (.error ds) =>
      for d in ds do complain s!"  error {d.code} {d.path}: {d.message}"
      complain s!"fvtrace: {tg.trace} does not decode; nothing pinned"
      return 1
    | .error rc => return rc
  let cache ← openCache tg
  let (pinned, problems) ← Receipt.pin t tg.project cache
  closeCache tg cache
  if pinned != t then writeTrace tg.trace pinned
  for prob in problems do complain s!"  cannot pin {prob}"
  let tail := if problems.isEmpty then "" else s!", {problems.length} artifact(s) not found"
  say s!"{tg.trace}: pinned against {tg.project}{tail}"
  return if problems.isEmpty then 0 else 1

def review (env : Store.Env) (args : List String) : IO UInt32 := do
  let p ← match ← parseArgs reviewSpec args with
    | .ok p => pure p
    | .error rc => return rc
  let some reviewer := p.value? "--reviewer" | return ← usageError "review needs --reviewer NAME"
  unless Decode.validText reviewer && (p.value? "--note").all Decode.validText do
    return ← usageError "--reviewer and --note need non-empty text without control characters"
  let tg ← match ← target env p with
    | .ok t => pure t
    | .error rc => return rc
  let t ← match ← readTarget p tg with
    | .ok (.ok t) => pure t
    | .ok (.error _) =>
      complain s!"fvtrace: {tg.trace} does not decode; run fvtrace check"; return 1
    | .error rc => return rc
  unless (Check.violations t).isEmpty do
    complain s!"fvtrace: {tg.trace} is not well-formed; run fvtrace check before reviewing"
    return 1
  let reviewed ← Receipt.review t reviewer (p.value? "--note")
  writeTrace tg.trace reviewed
  say s!"{tg.trace}: reviewed by {reviewer}"
  return 0

/-! ## Evaluation commands -/

structure Loaded where
  target : Store.Target
  scenario : Scenario
  bindings : List Receipt.Binding
  digest : String
  review : Receipt.ReviewState

def evalSpec (positional : Nat) : Args.Spec :=
  { valued := located ++ ["--whatif", "--question"], switches := ["--json", "--rehash"],
    positional := [positional] }

/-- Reads, checks + binds the target's trace; prints why not and returns the exit code
otherwise. -/
def load (env : Store.Env) (p : Args.Parsed) : IO (Except UInt32 Loaded) := do
  let tg ← match ← target env p with
    | .ok t => pure t
    | .error rc => return .error rc
  let t ← match ← readTarget p tg with
    | .ok (.ok t) => pure t
    | .ok (.error _) =>
      complain s!"fvtrace: {tg.trace} does not decode; run fvtrace check"
      return .error 1
    | .error rc => return .error rc
  unless (Check.violations t).isEmpty do
    complain s!"fvtrace: {tg.trace} is not well-formed; run fvtrace check"
    return .error 1
  let overrides ← match p.value? "--whatif" with
    | none => pure []
    | some spec =>
      match Overrides.parse t spec with
      | .ok o => pure o
      | .error m => return .error (← usageError m)
  let cache ← openCache tg
  let bindings ← Receipt.bindings t tg.project cache (p.has "--rehash")
  closeCache tg cache
  let current := fun id => (bindings.find? (·.id == id)).any (·.current)
  return .ok { target := tg, scenario := { trace := t, current, overrides }, bindings,
               digest := ← Receipt.reviewDigest t, review := ← Receipt.reviewState t }

def envelopeOf (l : Loaded) : Value :=
  Evaluate.envelope l.scenario l.bindings l.digest l.review

/-- The envelope's members named in `keys`, in envelope order (contract CLI projections). -/
def project (env : Value) (keys : List String) : Value :=
  match env with
  | .obj kvs => .obj (kvs.filter fun (k, _) => keys.contains k)
  | v => v

def projectionKeys : List String := ["schema", "mode", "overrides", "trace"]

def withLoaded (env : Store.Env) (args : List String) (positional : Nat)
    (k : Args.Parsed → Loaded → IO UInt32) : IO UInt32 := do
  let p ← match ← parseArgs (evalSpec positional) args with
    | .ok p => pure p
    | .error rc => return rc
  match ← load env p with
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
  say s!"(project: {l.target.project})"

def claimsCmd (env : Store.Env) (args : List String) : IO UInt32 :=
  withLoaded env args 0 fun p l => do
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

def claimList (ids : List String) : String := if ids.isEmpty then "none" else ", ".intercalate ids

def gapsCmd (env : Store.Env) (args : List String) : IO UInt32 :=
  withLoaded env args 0 fun p l => do
    let sc := l.scenario
    if p.has "--json" then
      IO.print (project (envelopeOf l) (projectionKeys ++ ["work", "blockers"])).pretty
      return 0
    if sc.work.isEmpty then say "No fact is left to verify."
    else say "Facts to verify, most useful first:"
    for w in sc.work do
      say s!"  {w.fact} {sc.factText w.fact}"
      say s!"      Makes available alone: {claimList w.unlocks}. Needed by: {claimList w.gates}."
    unless sc.blockerFacts.isEmpty do
      say "Violated facts (reword the claims or collect new data):"
      for (f, cs) in sc.blockerFacts do
        say s!"  {f} {sc.factText f}"
        say s!"      Blocks: {claimList cs}."
    footer l
    return 0

/-- One line per claim whose state changes: `C2 changes from Not yet to On assumption`. -/
def movesText (ms : List Scenario.Move) : String :=
  if ms.isEmpty then "no claim changes."
  else "; ".intercalate (ms.map fun m =>
    s!"{m.claim} changes from {m.before.verdict} to {m.after.verdict}") ++ "."

def experimentsCmd (env : Store.Env) (args : List String) : IO UInt32 :=
  withLoaded env args 0 fun p l => do
    let sc := l.scenario
    if p.has "--json" then
      IO.print (project (envelopeOf l) (projectionKeys ++ ["experiments"])).pretty
      return 0
    if sc.trace.experiments.isEmpty then say "The trace suggests no experiment."
    else say "Suggested experiments, most useful first:"
    for e in sc.trace.experiments.mergeSort (Evaluate.experimentBefore sc) do
      let cl := sc.closure [e.id]
      let created := if sc.prospective e.subject then "; creates new data" else ""
      say s!"  {e.id} {e.title} ({e.kind.name}, {e.effort.name}{created})"
      let first := cl.filter (· != e.id)
      unless first.isEmpty do say s!"      Runs after: {", ".intercalate first}."
      let contingent := (sc.merged cl).any fun (k, _) => sc.resultFacts.contains k
      let when := if contingent then "If it succeeds and the result is observed" else
        "If it succeeds"
      say s!"      {when}: {movesText (sc.moves (sc.applySuccess cl))}"
      unless e.failure.isEmpty do
        say s!"      If it fails: {movesText (sc.moves (sc.applyFailure e))}"
    footer l
    return 0

def planCmd (env : Store.Env) (args : List String) : IO UInt32 :=
  withLoaded env args 1 fun p l => do
    let sc := l.scenario
    let id := p.positional[0]!
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
    let uncovered := fun (cov : Coverage) => do
      unless cov.uncovered.isEmpty do
        let they := if cov.uncovered.length == 1 then "It needs" else "They need"
        say s!"  No suggested experiment raises {", ".intercalate cov.uncovered}. \
          {they} a new experiment or a ruling."
    match sc.plan c with
    | .planned cov exps st _ _ contingent =>
      say s!"  Plan: {", ".intercalate exps}. If the plan succeeds, the claim reads {st.verdict}."
      say "  The plan shows coverage, not scientific priority."
      if contingent then
        say "  The plan touches a result fact: it holds only if the result is observed."
      unless cov.alternatives.isEmpty do
        say "  Experiments for each fact:"
        for a in cov.alternatives do say s!"    {a.need}: {a.experiment} sets {a.status.name}"
      uncovered cov
    | .noImprovement cov =>
      say "  No set of suggested experiments raises this claim."
      uncovered cov
    | .inconsistent _ => say "  The what-if conflicts on this subject, so no plan applies."
    | .tooLarge _ =>
      say s!"  More than {maxRelevant} suggested experiments apply: no best plan is claimed."
    footer l
    return 0

def evalCmd (env : Store.Env) (args : List String) : IO UInt32 :=
  withLoaded env args 0 fun _ l => do
    IO.print (envelopeOf l).pretty
    return 0

/-- Exit codes: 0 = success, 1 = an invalid or failing trace, 2 = usage or read error. -/
def runIn (env : Store.Env) (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println s!"fvtrace {version}"; pure 0
  | ["--help"] | ["-h"] => IO.print usage; pure 0
  | ["schema"] => IO.print Assets.traceSchema; pure 0
  | "init" :: rest => initCmd env rest
  | "path" :: rest => pathCmd env rest
  | "check" :: rest => check env rest
  | "pin" :: rest => pin env rest
  | "review" :: rest => review env rest
  | "claims" :: rest => claimsCmd env rest
  | "gaps" :: rest => gapsCmd env rest
  | "experiments" :: rest => experimentsCmd env rest
  | "plan" :: rest => planCmd env rest
  | "eval" :: rest => evalCmd env rest
  | [] => IO.eprint usage; pure 2
  | cmd :: _ => usageError s!"unknown command '{cmd}'"

/-- The process entry: reads the data folder + current folder once. -/
def run (args : List String) : IO UInt32 := do
  match ← Store.Env.detect with
  | .ok env => runIn env args
  | .error m =>
    match args with
    | ["--version"] | ["--help"] | ["-h"] | ["schema"] | [] =>
      runIn { home := ".", cwd := "." } args
    | _ => complain s!"fvtrace: {m}"; pure 2

end Fvtrace.Cli
