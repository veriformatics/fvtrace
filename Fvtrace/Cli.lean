import Fvtrace.Args
import Fvtrace.Assets
import Fvtrace.Check
import Fvtrace.Decode
import Fvtrace.Encode
import Fvtrace.Engine
import FvtraceSkill
import Fvtrace.Export
import Fvtrace.Evaluate
import Fvtrace.Json
import Fvtrace.Lint
import Fvtrace.Receipt
import Fvtrace.Render
import Fvtrace.Server
import Fvtrace.Session
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
  "  check [--strict] [--json]\n" ++
  "      Check the trace, and the receipt of each verified fact against the project\n" ++
  "      folder. With --strict, a warning without a waiver or a stale receipt also\n" ++
  "      fails the check.\n" ++
  "      It reads every evidence file again.\n" ++
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
  "  export --html FILE | --bundle DIR\n" ++
  "      Share the claims. --html writes one page that opens in any browser, with\n" ++
  "      each one-click what-if computed in advance. --bundle writes the trace and\n" ++
  "      copies of its evidence files for another computer with fvtrace.\n" ++
  "  serve [--port N] [--host ADDRESS] [--cached]\n" ++
  "      Show the claims in a browser: open the link that the command prints. The\n" ++
  "      port is 8642 by default (0 = any free port). With --host, computers on your\n" ++
  "      network can open the page at ADDRESS. The page is not encrypted: share it\n" ++
  "      on a network that you trust.\n" ++
  "  schema\n" ++
  "      Print the JSON Schema of the trace format.\n" ++
  "  skills install [--agent claude|agents] [--dir DIR]\n" ++
  "      Install the fvtrace skill for coding agents: Claude Code reads it from\n" ++
  "      ~/.claude/skills, other agents from ~/.agents/skills (both by default).\n" ++
  "  skills show\n" ++
  "      Print the skill's instructions.\n\n" ++
  "claims, gaps, experiments, plan and eval accept --whatif FACT=STATUS,... to\n" ++
  "suppose statuses, and --cached to reuse the digest of an evidence file that kept\n" ++
  "its size and modification time (faster for large files, but it misses an edit\n" ++
  "that keeps both). check, claims, gaps, experiments and plan accept --json for\n" ++
  "machine output.\n" ++
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

/-- Writes `body` to `file` through a sibling temporary file, so a reader never sees half a file.
The temporary file is created new (`O_EXCL`): an entry already at that path, a planted link
included, is removed first and never written through. -/
def replaceFile (file : System.FilePath) (body : String) : IO Unit := do
  let tmp : System.FilePath := file.toString ++ ".fvtrace-tmp"
  try IO.FS.removeFile tmp catch _ => pure ()
  let h ← IO.FS.Handle.mk tmp .writeNew
  h.putStr body
  h.flush
  IO.FS.rename tmp file

def writeTrace (file : System.FilePath) (t : Trace) : IO Unit :=
  replaceFile file (Encode.trace t).pretty

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

/-- Says why a trace cannot be used; returns the exit code. -/
def report : Session.Problem → IO UInt32
  | .noTrace project => do
    complain s!"fvtrace: no trace for the project {project} yet; run fvtrace init"
    return 2
  | .unreadable file reason => do complain s!"fvtrace: cannot read {file}: {reason}"; return 2
  | .undecodable file _ => do
    complain s!"fvtrace: {file} does not decode; run fvtrace check"
    return 1
  | .illFormed file _ => do
    complain s!"fvtrace: {file} is not well-formed; run fvtrace check"
    return 1
  | .badWhatif m => usageError m

/-- Reads the target's trace (decoded or not), reporting a missing or unreadable file. -/
def readTarget (p : Args.Parsed) (t : Store.Target) :
    IO (Except UInt32 (Except (Array Decode.Diag) Trace)) := do
  match ← Session.read t (p.value? "--trace").isSome with
  | .ok d => return .ok d
  | .error prob => return .error (← report prob)

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

def checkSpec : Args.Spec := { valued := located, switches := ["--json", "--strict"] }

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
      let cache ← Session.openCache tg
      -- Every command reads each evidence file by default: the size + mtime cache could miss an
      -- edit that keeps both. The evaluation commands + serve reuse it on --cached alone.
      receipts ← Receipt.bindings t tg.project cache true
      Session.closeCache tg cache
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
  let strictFail := p.has "--strict" && (warnings.any (·.waived.isNone) || !stale.isEmpty)
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
  let cache ← Session.openCache tg
  let (pinned, problems) ← Receipt.pin t tg.project cache
  Session.closeCache tg cache
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
  say "The review vouches that the claims and facts match the study, that each headline says no \
    more than its exact statement, and that the universal premises hold: honest records, working \
    instruments, correct labels."
  return 0

/-! ## Evaluation commands -/

def evalSpec (positional : Nat) : Args.Spec :=
  { valued := located ++ ["--whatif", "--question"], switches := ["--json", "--cached"],
    positional := [positional] }

abbrev Loaded := Session.Loaded

/-- Reads, checks + binds the target's trace; prints why not and returns the exit code
otherwise. -/
def load (env : Store.Env) (p : Args.Parsed) : IO (Except UInt32 Loaded) := do
  let tg ← match ← target env p with
    | .ok t => pure t
    | .error rc => return .error rc
  let cache ← Session.openCache tg
  let r ← Session.load tg (p.value? "--trace").isSome (p.value? "--whatif") (!p.has "--cached")
    cache
  Session.closeCache tg cache
  match r with
  | .ok l => return .ok l
  | .error prob => return .error (← report prob)

def envelopeOf (l : Loaded) : Value := Session.envelope l

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

/-- `a`, `a and b`, `a, b and c`. -/
def andList : List String → String
  | [] => ""
  | [a] => a
  | [a, b] => s!"{a} and {b}"
  | a :: rest => s!"{a}, {andList rest}"

/-- A work row's claims beyond those it makes available alone, each with the facts it needs
together with this one (its gaps, minus the row's fact), a blocked one also flagged. -/
def neededBy (sc : Scenario) (w : Scenario.Work) : List String :=
  (w.gates.filter (!w.unlocks.contains ·)).filterMap fun id => (sc.trace.claim? id).map fun c =>
    let others := (sc.gaps c).filter (· != w.fact)
    let together := if others.isEmpty then "" else s!", together with {andList others}"
    match sc.final c with
    | .cannot => if others.isEmpty then s!"Needed by {id}, which is not possible as worded."
      else s!"Needed by {id}{together}, but {id} is not possible as worded."
    | .conditional => s!"Needed by {id}, which holds only if it is true."
    | _ => s!"Needed by {id}{together}."

def gapsCmd (env : Store.Env) (args : List String) : IO UInt32 :=
  withLoaded env args 0 fun p l => do
    let sc := l.scenario
    if p.has "--json" then
      IO.print (project (envelopeOf l) (projectionKeys ++ ["work", "blockers"])).pretty
      return 0
    if sc.work.isEmpty then
      say "No fact that a claim needs can rise further: each one is violated or has the \
        strongest status that its route allows."
    else say "Facts to verify, most useful first:"
    for w in sc.work do
      say s!"  {w.fact} {sc.factText w.fact}"
      let alone := if w.unlocks.isEmpty then []
        else [s!"Makes available alone: {", ".intercalate w.unlocks}."]
      say s!"      {" ".intercalate (alone ++ neededBy sc w)}"
    unless sc.blockerFacts.isEmpty do
      say "Violated facts (reword the claims or collect new data):"
      for (f, cs) in sc.blockerFacts do
        say s!"  {f} {sc.factText f}"
        say s!"      Blocks: {claimList cs}."
    footer l
    return 0

/-- One line per claim whose state changes: `C2 changes from Pending verification to
Conditional`. -/
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
      let created := if sc.creates e then "; creates new data"
        else if sc.prospective e.subject then "; on new data" else ""
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
      let (violated, rest) := cov.uncovered.partition (sc.eff · == .violated)
      let (open_, settled) := rest.partition fun n => (sc.trace.fact? n).any sc.closable
      unless violated.isEmpty do
        say s!"  Violated: {", ".intercalate violated} (reword the claim or collect new data)."
      unless open_.isEmpty do
        let they := if open_.length == 1 then "It needs" else "They need"
        say s!"  No suggested experiment raises {", ".intercalate open_}. \
          {they} a new experiment or a ruling."
      unless settled.isEmpty do
        say s!"  Stays as it is: {", ".intercalate settled} (no route allows a stronger status)."
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

/-! ## Agent skill -/

/-- `~/.claude/skills` (Claude Code) and `~/.agents/skills` (Codex, Gemini CLI, Copilot, Cursor). -/
def skillDirs (agent : Option String) : IO (Except String (List System.FilePath)) := do
  let some home ← Store.envVar (if System.Platform.isWindows then "USERPROFILE" else "HOME")
    | return .error "cannot find the home folder; give --dir DIR"
  let home : System.FilePath := home
  match agent with
  | none => return .ok [home / ".claude" / "skills", home / ".agents" / "skills"]
  | some "claude" => return .ok [home / ".claude" / "skills"]
  | some "agents" => return .ok [home / ".agents" / "skills"]
  | some a => return .error s!"--agent is claude or agents, got \"{a}\""

/-- The marker an installed copy carries, so a reinstall replaces it and nothing else. -/
def skillMarker : String := ".fvtrace-skill"

/-- Writes the skill into `root/fvtrace`; refuses a folder that fvtrace did not write. -/
def installSkill (root : System.FilePath) : IO (Except String System.FilePath) := do
  let dir := root / "fvtrace"
  if ← dir.pathExists then
    -- A link would make the replacement delete the files it points at.
    if (← dir.symlinkMetadata).type == .symlink then
      return .error s!"{dir} is a link; remove it or give --dir"
    unless ← (dir / skillMarker).pathExists do
      return .error s!"{dir} exists and was not written by fvtrace; remove it or give --dir"
    IO.FS.removeDirAll dir
  for (path, body) in FvtraceSkill.files do
    let dest := dir / path
    if let some parent := dest.parent then IO.FS.createDirAll parent
    IO.FS.writeFile dest body
  IO.FS.writeFile (dir / skillMarker) s!"fvtrace {version}\n"
  return .ok dir

def skillsCmd (args : List String) : IO UInt32 := do
  match args with
  | "show" :: [] =>
    IO.print ((FvtraceSkill.files.lookup "SKILL.md").getD "")
    return 0
  | "install" :: rest =>
    let p ← match ← parseArgs { valued := ["--agent", "--dir"] } rest with
      | .ok p => pure p
      | .error rc => return rc
    let roots ← match p.value? "--dir" with
      | some d =>
        if (p.value? "--agent").isSome then
          return ← usageError "give --agent or --dir, not both"
        pure [Store.absolute (← IO.currentDir) d]
      | none => match ← skillDirs (p.value? "--agent") with
        | .ok ds => pure ds
        | .error m => return ← usageError m
    let mut rc : UInt32 := 0
    for root in roots do
      match ← installSkill root with
      | .ok dir => say s!"Installed the fvtrace skill in {dir}"
      | .error m => complain s!"fvtrace: {m}"; rc := 1
    if rc == 0 then say "Start a new session of your coding agent to load it."
    return rc
  | _ => usageError "skills takes install [--agent claude|agents] [--dir DIR], or show"

/-! ## Sharing -/

def exportSpec : Args.Spec := { valued := located ++ ["--html", "--bundle"] }

/-- The real path `dest` would have, when its folder exists; refuses the project folder. -/
def outside (tg : Store.Target) (dest : System.FilePath) : IO (Except String System.FilePath) := do
  let some parent := dest.parent | return .error s!"{dest} has no folder"
  unless ← parent.isDir do return .error s!"no folder {parent}"
  -- An existing destination resolves through its own links too (a link into the project).
  let real ← if ← dest.pathExists then IO.FS.realPath dest
    else pure ((← IO.FS.realPath parent) / (dest.fileName.getD ""))
  if Export.within tg.project real then
    return .error s!"{dest} lies in the project folder; fvtrace writes nothing there"
  return .ok real

def exportCmd (env : Store.Env) (args : List String) : IO UInt32 := do
  let p ← match ← parseArgs exportSpec args with
    | .ok p => pure p
    | .error rc => return rc
  let (dest, html) ← match p.value? "--html", p.value? "--bundle" with
    | some f, none => pure (f, true)
    | none, some d => pure (d, false)
    | _, _ => return ← usageError "export needs either --html FILE or --bundle DIR"
  let tg ← match ← target env p with
    | .ok t => pure t
    | .error rc => return rc
  let real ← match ← outside tg (Store.absolute env.cwd dest) with
    | .ok r => pure r
    | .error m => complain s!"fvtrace: {m}"; return 2
  let cache ← Session.openCache tg
  let r ← Session.load tg (p.value? "--trace").isSome none true cache
  Session.closeCache tg cache
  let l ← match r with
    | .ok l => pure l
    | .error prob => return ← report prob
  if html then
    replaceFile real (← Export.page l)
    let n := (Evaluate.actions l.scenario).length
    say s!"Wrote {real}: the claims of {tg.project} with {n} one-click what-ifs."
    return 0
  if ← real.pathExists then
    unless (← real.readDir).isEmpty do
      complain s!"fvtrace: {real} is not empty"
      return 2
  let problems ← Export.writeBundle l.scenario.trace tg.project real
  for prob in problems do complain s!"  cannot copy {prob}"
  let tail := if problems.isEmpty then "" else s!", {problems.length} artifact(s) not found"
  say s!"Wrote the bundle {real}{tail}."
  return if problems.isEmpty then 0 else 1

/-! ## The GUI server -/

def serveSpec : Args.Spec := { valued := located ++ ["--port", "--host"], switches := ["--cached"] }

/-- The bind address: loopback, or the one `--host` names (an address others use to reach this
computer; a wildcard address has no single name to allow as `Host`). -/
def bindAddress (host : Option String) (port : UInt16) :
    Except String (Std.Net.SocketAddress × String) :=
  match host with
  | none => .ok (.v4 { addr := Std.Net.IPv4Addr.ofParts 127 0 0 1, port }, "127.0.0.1")
  | some h =>
    match Std.Net.IPv4Addr.ofString h, Std.Net.IPv6Addr.ofString h with
    | some a, _ =>
      if a == Std.Net.IPv4Addr.ofParts 0 0 0 0 then .error wildcard
      else .ok (.v4 { addr := a, port }, h)
    | none, some a =>
      if a == Std.Net.IPv6Addr.ofParts 0 0 0 0 0 0 0 0 then .error wildcard
      else .ok (.v6 { addr := a, port }, s!"[{h}]")
    | none, none => .error s!"--host needs an IP address, got \"{h}\""
where
  wildcard := "--host needs the address that others use to reach this computer, \
    not a wildcard address"

def serveCmd (env : Store.Env) (args : List String) : IO UInt32 := do
  let p ← match ← parseArgs serveSpec args with
    | .ok p => pure p
    | .error rc => return rc
  let port ← match p.value? "--port" with
    | none => pure 8642
    | some v => match v.toNat? with
      | some n => if n < 65536 then pure n.toUInt16 else return ← usageError "--port is 0 to 65535"
      | none => return ← usageError "--port is 0 to 65535"
  let (addr, name) ← match bindAddress (p.value? "--host") port with
    | .ok a => pure a
    | .error m => return ← usageError m
  let tg ← match ← target env p with
    | .ok t => pure t
    | .error rc => return rc
  let token := Digest.hex (← IO.getRandomBytes 16)
  let cache ← Session.openCache tg
  let initial : Server.Config :=
    { target := tg, explicit := (p.value? "--trace").isSome, token, port, hosts := [],
      cached := p.has "--cached" }
  let cfg ← IO.mkRef initial
  let bound ← try Server.start cfg addr cache catch e =>
    complain s!"fvtrace: cannot serve on {name}:{port}: {e}. Give another --port (0 = any)."
    return 2
  let aliases := if (p.value? "--host").isNone then [s!"localhost:{bound}"] else []
  cfg.modify ({ · with port := bound, hosts := s!"{name}:{bound}" :: aliases })
  say s!"Serving the project {tg.project}"
  say s!"Open http://{name}:{bound}/?token={token}"
  if (p.value? "--host").isSome then
    say "Anyone on your network who has this link can see the trace (the link is not encrypted)."
  say "Stop with Ctrl+C."
  (← IO.getStdout).flush
  repeat IO.sleep 3600000
  return 0

/-- Exit codes: 0 = success, 1 = an invalid or failing trace, 2 = usage or read error. -/
def dispatch (env : Store.Env) (args : List String) : IO UInt32 := do
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
  | "serve" :: rest => serveCmd env rest
  | "export" :: rest => exportCmd env rest
  | "skills" :: rest => skillsCmd rest
  | [] => IO.eprint usage; pure 2
  | cmd :: _ => usageError s!"unknown command '{cmd}'"

/-- A command in `env`. An I/O failure that no command anticipated (a permission, a vanished
file) is a read error: exit 2 with its message. -/
def runIn (env : Store.Env) (args : List String) : IO UInt32 := do
  try dispatch env args
  catch e =>
    complain s!"fvtrace: {(toString e).replace "\n" " "}"
    return 2

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
