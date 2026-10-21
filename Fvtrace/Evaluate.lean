import Fvtrace.Engine
import Fvtrace.Encode
import Fvtrace.Json
import Fvtrace.Lint
import Fvtrace.Receipt

/-!
# Evaluation envelope (`fvtrace.evaluation/1`)

The one JSON document every surface renders: CLI projections, the server, the export. Sentences
+ labels are engine output (contract § Sentences); a surface adds no judgment of its own.
-/

namespace Fvtrace
open Fvtrace.Json

def State.verdict : State → String
  | .can => "Fully supported" | .conditional => "Conditional" | .«open» => "Pending verification"
  | .cannot => "Claim not possible"

namespace Scenario

variable (s : Scenario)

def factText (id : String) : String := ((s.trace.fact? id).map (·.text)).getD id

/-- Quoted items with `; ` between them. -/
def joinParts : List String → List String
  | [] => []
  | [q] => [q]
  | q :: qs => q :: "; " :: joinParts qs

/-- The sentence's pieces: verbatim claim + premise texts (`Assuming “p₁”; “p₂”: text` for a
conditional claim); the sentence is their concatenation. -/
def sentenceParts (c : Claim) : List String :=
  if s.final c == .conditional then
    ["Assuming "] ++ joinParts ((s.premises c).map fun p => "“" ++ s.factText p ++ "”") ++
      [": ", c.text]
  else [c.text]

def sentence (c : Claim) : String := String.join (s.sentenceParts c)

def baseline : Scenario := { s with overrides := [] }

def prospective (subject : String) : Bool :=
  ((s.trace.subject? subject).map (·.kind == .prospective)).getD false

/-- The what-if changes a need of the claim or its subject's consistency. -/
def changedByWhatif (c : Claim) : Bool :=
  c.needsAll.any (fun n => s.eff n != s.baseline.eff n) ||
    s.valid c.subject != s.baseline.valid c.subject

/-- The claim's state depends on the what-if (or its subject does not exist yet). -/
def hypothetical (c : Claim) : Bool := s.prospective c.subject || s.changedByWhatif c

/-- The experiment creates its subject (a prospective subject names it in `createdBy`). -/
def creates (e : Experiment) : Bool :=
  (s.trace.subject? e.subject).any (·.createdBy == some e.id)

def creatorTitle (subject : String) : Option String := do
  let sub ← s.trace.subject? subject
  let e ← sub.createdBy
  let x ← s.trace.experiment? e
  return x.title

def qualifiers (c : Claim) (review : Receipt.ReviewState) : List String :=
  (if s.changedByWhatif c then ["what-if"] else []) ++
  (match review with | .draft => ["draft"] | .stale => ["stale review"] | .reviewed => []) ++
  ((if s.prospective c.subject then s.creatorTitle c.subject else none).map
    (fun t => [s!"if {t} runs"])).getD [] ++
  (if !s.valid c.subject then ["conflicting what-if"] else [])

end Scenario

namespace Evaluate

def strs (xs : List String) : Value := .arr (xs.map .str)

def stateCounts (sc : Scenario) (claims : List Claim) : Value :=
  let finals := claims.map sc.final
  .obj ([State.can, .conditional, .«open», .cannot].map fun st =>
    (st.name, .num (finals.filter (· == st)).length))

def moveJson (m : Scenario.Move) : Value :=
  .obj [("claim", .str m.claim), ("from", .str m.before.name), ("to", .str m.after.name)]

def coverageJson (c : Coverage) : List (String × Value) :=
  [("premises", strs c.premises), ("gaps", strs c.gaps), ("uncovered", strs c.uncovered),
   ("alternatives", .arr (c.alternatives.map fun a =>
     .obj [("need", .str a.need), ("experiment", .str a.experiment),
       ("status", .str a.status.name)]))]

def planJson : PlanResult → Value
  | .inconsistent cov => .obj ([("result", .str "inconsistent")] ++ coverageJson cov)
  | .tooLarge cov => .obj ([("result", .str "tooLarge")] ++ coverageJson cov)
  | .noImprovement cov => .obj ([("result", .str "noImprovement")] ++ coverageJson cov)
  | .planned cov exps st prem gaps contingent =>
    .obj ([("result", .str "planned"), ("experiments", strs exps), ("state", .str st.name),
      ("planPremises", strs prem), ("planGaps", strs gaps), ("contingent", .bool contingent)] ++
      coverageJson cov)

def bindingFor (bindings : List Receipt.Binding) (id : String) : Option Receipt.Binding :=
  bindings.find? (·.id == id)

def factJson (sc : Scenario) (bindings : List Receipt.Binding) (f : Fact) : Value :=
  let e := sc.eff f.id
  let b := bindingFor bindings f.id
  .obj ([("id", .str f.id), ("subject", .str f.subject), ("kind", .str f.kind.name),
    ("text", .str f.text), ("route", .str f.route.name), ("recorded", .str f.status.name),
    ("effective", .str e.name), ("closable", .bool (sc.closable f)),
    ("supposed", .bool ((sc.overrides.lookup f.id).isSome)),
    ("derivedFrom", .arr ((sc.derivations f.id).map fun (x, src) =>
      .obj [("exclusion", .str x), ("source", .str src)])),
    ("trusts", strs f.trusts)] ++
    (match f.instantiates with | some src => [("instantiates", .str src)] | none => []) ++
    (match f.why with | some w => [("why", .str w)] | none => []) ++
    (match f.evidence with | some ev => [("evidence", Encode.evidence ev)] | none => []) ++
    (match b with
     | some b => [("receipt", .obj [("current", .bool b.current), ("reasons", strs b.reasons)])]
     | none => []))

def claimJson (sc : Scenario) (review : Receipt.ReviewState) (c : Claim) : Value :=
  .obj ([("id", .str c.id), ("question", .str c.question), ("subject", .str c.subject),
    ("level", .str c.level.name), ("text", .str c.text)] ++
    (match c.headline with | some h => [("headline", .str h)] | none => []) ++
    [("latent", .bool c.latent), ("needs", strs c.needs)] ++
    (match c.entailment with | some e => [("entailment", .str e)] | none => []) ++
    [("restates", .bool c.restates),
    ("final", .str (sc.final c).name), ("intrinsic", .str (sc.intrinsic c).name),
    ("sentence", .str (sc.sentence c)),
    ("label", .obj [("verdict", .str (sc.final c).verdict),
      ("qualifiers", strs (sc.qualifiers c review))]),
    ("verified", strs (sc.verifiedNeeds c)), ("premises", strs (sc.premises c)),
    ("gaps", strs (sc.gaps c)), ("blockers", strs (sc.blockers c)),
    ("incompatible", strs (sc.incompatible c)), ("conflicts", strs (sc.conflicts c.subject)),
    ("hypothetical", .bool (sc.hypothetical c)), ("provisional", .bool (review != .reviewed)),
    ("plan", planJson (sc.plan c))] ++
    (match c.variantOf with | some v => [("variantOf", .str v)] | none => []))

def overridesJson (o : Overrides) : Value :=
  .arr (o.map fun (k, st) => .obj [("fact", .str k), ("status", .str st.name)])

def experimentJson (sc : Scenario) (e : Experiment) : Value :=
  let cl := sc.closure [e.id]
  let wins := sc.moves (sc.applySuccess cl)
  let losses := if e.failure.isEmpty then [] else sc.moves (sc.applyFailure e)
  let mergedHere := sc.merged cl
  .obj [("id", .str e.id), ("subject", .str e.subject), ("kind", .str e.kind.name),
    ("effort", .str e.effort.name), ("title", .str e.title), ("method", .str e.method),
    ("resources", .str e.resources), ("caveat", .str e.caveat),
    ("success", Encode.outcome e.success), ("failure", Encode.outcome e.failure),
    ("requires", strs e.requires), ("closure", strs cl), ("raises", overridesJson (sc.raised cl)),
    ("applied", .bool (mergedHere.all fun (k, st) => sc.overrides.lookup k == some st)),
    ("contingent", .bool (mergedHere.any fun (k, _) => sc.resultFacts.contains k)),
    ("prospective", .bool (sc.prospective e.subject)), ("creates", .bool (sc.creates e)),
    ("wins", .arr (wins.map moveJson)), ("losses", .arr (losses.map moveJson)),
    ("lights", .num (Scenario.lights wins)), ("clears", .num (Scenario.clears wins)),
    ("lowers", .num (Scenario.lowers wins)), ("breaks", .num (Scenario.breaks losses))]

def experimentBefore (sc : Scenario) (a b : Experiment) : Bool :=
  let ka := Scenario.lights (sc.moves (sc.applySuccess (sc.closure [a.id])))
  let kb := Scenario.lights (sc.moves (sc.applySuccess (sc.closure [b.id])))
  let ca := Scenario.clears (sc.moves (sc.applySuccess (sc.closure [a.id])))
  let cb := Scenario.clears (sc.moves (sc.applySuccess (sc.closure [b.id])))
  let ea := (Effort.all.idxOf a.effort)
  let eb := (Effort.all.idxOf b.effort)
  ka > kb || (ka == kb && (ca > cb || (ca == cb && (ea < eb || (ea == eb && a.id < b.id)))))

/-- The one-click what-ifs from this scenario, each as the complete what-if it leads to (so a
click replaces the what-if): suppose a closable fact at its route's ceiling, an experiment's
success or failure, a claim's plan. A recorded scenario gives the export's finite domain. -/
def actions (sc : Scenario) : List (String × String × String × Overrides) :=
  (sc.trace.facts.filter sc.closable).map (fun f =>
      (s!"suppose:{f.id}", "suppose", f.id,
        (sc.withOverrides [(f.id, f.ceiling)]).overrides)) ++
  sc.trace.experiments.map (fun e =>
      (s!"success:{e.id}", "success", e.id, (sc.applySuccess (sc.closure [e.id])).overrides)) ++
  (sc.trace.experiments.filter (!·.failure.isEmpty)).map (fun e =>
      (s!"failure:{e.id}", "failure", e.id, (sc.applyFailure e).overrides)) ++
  sc.trace.claims.filterMap fun c =>
    match sc.plan c with
    | .planned _ exps .. => some (s!"plan:{c.id}", "plan", c.id, (sc.applySuccess exps).overrides)
    | _ => none

/-- The full envelope for one snapshot (trace + receipt bindings + overrides + review state). -/
def envelope (sc : Scenario) (bindings : List Receipt.Binding) (digest : String)
    (review : Receipt.ReviewState) : Value :=
  let t := sc.trace
  let existing := t.claims.filter fun c => !sc.prospective c.subject
  .obj [("schema", .str "fvtrace.evaluation/1"),
    ("mode", .str (if sc.overrides.isEmpty then "recorded" else "what-if")),
    ("overrides", overridesJson sc.overrides),
    ("trace", .obj ([("digest", .str digest), ("review", .obj ([("state", .str review.name)] ++
      (match t.review with
       | some r => [("reviewer", .str r.reviewer), ("date", .str r.date)]
       | none => [])))])),
    ("analysis", Encode.analysis t.analysis),
    ("subjects", .arr (t.subjects.map fun sub =>
      .obj [("id", .str sub.id), ("title", .str sub.title), ("kind", .str sub.kind.name),
        ("valid", .bool (sc.valid sub.id)), ("conflicts", strs (sc.conflicts sub.id))])),
    ("counts", stateCounts sc existing),
    ("prospectiveCounts", .arr ((t.subjects.filter (·.kind == .prospective)).map fun sub =>
      .obj [("subject", .str sub.id),
        ("counts", stateCounts sc (t.claims.filter (·.subject == sub.id)))])),
    ("questions", .arr (t.questions.map Encode.question)),
    ("facts", .arr (t.facts.map (factJson sc bindings))),
    ("claims", .arr (t.claims.map (claimJson sc review))),
    ("work", .arr (sc.work.map fun w =>
      .obj [("fact", .str w.fact), ("unlocks", strs w.unlocks), ("gates", strs w.gates)])),
    ("blockers", .arr (sc.blockerFacts.map fun (f, cs) =>
      .obj [("fact", .str f), ("claims", strs cs)])),
    ("experiments", .arr ((t.experiments.mergeSort (experimentBefore sc)).map (experimentJson sc))),
    ("exclusions", .arr (t.exclusions.map fun x =>
      .obj [("id", .str x.id), ("subject", .str x.subject),
        ("between", strs [x.between.1, x.between.2]), ("text", .str x.text),
        ("recorded", .str x.status.name), ("effective", .str (sc.exclusionEff x).name),
        ("active", .bool (sc.active x))])),
    ("lints", .arr ((Lint.warnings t).map fun w =>
      .obj ([("rule", .str w.rule), ("claim", .str w.claim), ("path", .str w.path),
        ("message", .str w.message)] ++
        (match w.waived with | some r => [("waived", .str r)] | none => [])))),
    ("actions", .arr ((actions sc).map fun (id, kind, target, o) =>
      .obj [("id", .str id), ("kind", .str kind), ("target", .str target),
        ("overrides", overridesJson o)]))]

end Evaluate
end Fvtrace
