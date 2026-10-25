import Fvtrace.Encode
import Fvtrace.Json
import Fvtrace.Lint
import Fvtrace.Request
import Fvtrace.Answers.Fast

/-!
# Evaluation envelope (`fvtrace.evaluation/1`)

The one JSON document every surface renders: CLI projections, the server, the export. Sentences
+ labels are engine output (contract § Sentences); a surface adds no judgment of its own.
-/

namespace Fvtrace
open Fvtrace.Json

namespace Evaluate

def strs (xs : List String) : Value := .arr (xs.map .str)

def stateCounts (A : Answers) (claims : List Claim) : Value :=
  let finals := claims.map A.final
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

def factJson (A : Answers) (bindingFor : String → Option Receipt.Binding) (f : Fact) : Value :=
  let e := A.eff f.id
  let b := bindingFor f.id
  .obj ([("id", .str f.id), ("subject", .str f.subject), ("kind", .str f.kind.name),
    ("text", .str f.text), ("route", .str f.route.name), ("recorded", .str f.status.name),
    ("effective", .str e.name), ("closable", .bool (A.closable f)),
    ("supposed", .bool ((A.override? f.id).isSome)),
    ("derivedFrom", .arr ((A.derivations f.id).map fun (x, src) =>
      .obj [("exclusion", .str x), ("source", .str src)])),
    ("trusts", strs f.trusts)] ++
    (match f.instantiates with | some src => [("instantiates", .str src)] | none => []) ++
    (match f.why with | some w => [("why", .str w)] | none => []) ++
    (match f.evidence with | some ev => [("evidence", Encode.evidence ev)] | none => []) ++
    (match b with
     | some b => [("receipt", .obj [("current", .bool b.current), ("reasons", strs b.reasons)])]
     | none => []))

def claimJson (A : Answers) (review : Receipt.ReviewState) (c : Claim) (plan : PlanResult) :
    Value :=
  .obj ([("id", .str c.id), ("question", .str c.question), ("subject", .str c.subject),
    ("level", .str c.level.name), ("text", .str c.text)] ++
    (match c.headline with | some h => [("headline", .str h)] | none => []) ++
    [("latent", .bool c.latent), ("needs", strs c.needs)] ++
    (match c.entailment with | some e => [("entailment", .str e)] | none => []) ++
    [("restates", .bool c.restates),
    ("final", .str (A.final c).name), ("intrinsic", .str (A.intrinsic c).name),
    ("sentence", .str (A.sentence c)),
    ("label", .obj [("verdict", .str (A.final c).verdict),
      ("qualifiers", strs (A.qualifiers c review))]),
    ("verified", strs (A.verifiedNeeds c)), ("premises", strs (A.premises c)),
    ("gaps", strs (A.gaps c)), ("blockers", strs (A.blockers c)),
    ("incompatible", strs (A.incompatible c)), ("conflicts", strs (A.conflicts c.subject)),
    ("hypothetical", .bool (A.hypothetical c)), ("provisional", .bool (review != .reviewed)),
    ("plan", planJson plan)] ++
    (match c.variantOf with | some v => [("variantOf", .str v)] | none => []))

def overridesJson (o : Overrides) : Value :=
  .arr (o.map fun (k, st) => .obj [("fact", .str k), ("status", .str st.name)])

/-- An experiment's lists (`kernel.md` V-details): its closure, the overrides its success raises,
the moves of its success + its failure. -/
def experimentLists (A : Answers) (e : Experiment) : List (String × Value) :=
  let cl := A.closure [e.id]
  let losses := if e.failure.isEmpty then [] else A.failureMoves e
  [("closure", strs cl), ("raises", overridesJson (A.raised cl)),
   ("wins", .arr ((A.successMoves cl).map moveJson)), ("losses", .arr (losses.map moveJson))]

def experimentJson (A : Answers) (e : Experiment) : Value :=
  let cl := A.closure [e.id]
  let wins := A.successMoves cl
  let losses := if e.failure.isEmpty then [] else A.failureMoves e
  let mergedHere := A.merged cl
  .obj [("id", .str e.id), ("subject", .str e.subject), ("kind", .str e.kind.name),
    ("effort", .str e.effort.name), ("title", .str e.title), ("method", .str e.method),
    ("resources", .str e.resources), ("caveat", .str e.caveat),
    ("success", Encode.outcome e.success), ("failure", Encode.outcome e.failure),
    ("requires", strs e.requires), ("closure", strs cl), ("raises", overridesJson (A.raised cl)),
    ("applied", .bool (mergedHere.all fun (k, st) => A.override? k == some st)),
    ("contingent", .bool (mergedHere.any fun (k, _) => A.isResult k)),
    ("prospective", .bool (A.prospective e.subject)), ("creates", .bool (A.creates e)),
    ("wins", .arr (wins.map moveJson)), ("losses", .arr (losses.map moveJson)),
    ("lights", .num (Scenario.lights wins)), ("clears", .num (Scenario.clears wins)),
    ("lowers", .num (Scenario.lowers wins)), ("breaks", .num (Scenario.breaks losses))]

/-- The one-click what-ifs from this scenario, each as the complete what-if it leads to (so a
click replaces the what-if): suppose a closable fact at its route's ceiling, an experiment's
success or failure, a claim's plan (`claimPlans` = each claim with its plan, in trace order). -/
def actionsWith (t : Trace) (A : Answers) (claimPlans : List (Claim × PlanResult)) :
    List (String × String × String × Overrides) :=
  (t.facts.filter A.closable).map (fun f =>
      (s!"suppose:{f.id}", "suppose", f.id, A.withOverrides [(f.id, f.ceiling)])) ++
  t.experiments.map (fun e =>
      (s!"success:{e.id}", "success", e.id, A.withOverrides (A.raised (A.closure [e.id])))) ++
  (t.experiments.filter (!·.failure.isEmpty)).map (fun e =>
      (s!"failure:{e.id}", "failure", e.id,
        A.withOverrides (e.failure.map fun (k, _) => (k, .violated)))) ++
  claimPlans.filterMap fun (c, p) =>
    match p with
    | .planned _ exps .. => some (s!"plan:{c.id}", "plan", c.id, A.withOverrides (A.raised exps))
    | _ => none

/-- The one-click what-ifs from this scenario (`actionsWith` on its fast answers). -/
def actions (sc : Scenario) : List (String × String × String × Overrides) :=
  let A := Answers.fast sc
  actionsWith sc.trace A (sc.trace.claims.map fun c => (c, A.plan c))

/-- The action `id`'s complete what-if (`kernel.md` V-action): the first entry `actionsWith` lists
under that id, computed alone (a plan action plans its own claim only), normalized as a parsed
what-if is. -/
def expandWith (t : Trace) (A : Answers) (id : String) : Except String Overrides :=
  let refuse : Except String Overrides := .error s!"\"{id}\" is not a suggested what-if"
  let done := fun (extra : Overrides) => Except.ok (Overrides.normalize (A.withOverrides extra))
  match id.splitOn ":" with
  | [kind, target] =>
    match kind with
    | "suppose" =>
      match t.facts.find? (fun f => f.id == target && A.closable f) with
      | some f => done [(f.id, f.ceiling)]
      | none => refuse
    | "success" =>
      match t.experiments.find? (·.id == target) with
      | some e => done (A.raised (A.closure [e.id]))
      | none => refuse
    | "failure" =>
      match t.experiments.find? (fun e => e.id == target && !e.failure.isEmpty) with
      | some e => done (e.failure.map fun (k, _) => (k, .violated))
      | none => refuse
    | "plan" =>
      let planned := t.claims.findSome? fun c =>
        if c.id != target then none
        else match A.plan c with
          | .planned _ exps .. => some exps
          | _ => none
      match planned with
      | some exps => done (A.raised exps)
      | none => refuse
    | _ => refuse
  | _ => refuse

/-- The envelope's `trace` member: the review digest + the review state. -/
def traceJson (t : Trace) (digest : String) (review : Receipt.ReviewState) : Value :=
  .obj ([("digest", .str digest), ("review", .obj ([("state", .str review.name)] ++
    (match t.review with
     | some r => [("reviewer", .str r.reviewer), ("date", .str r.date)]
     | none => [])))])

/-- An item's lists (`kernel.md` V-details), the item resolved by its first match. -/
def itemLists (t : Trace) (A : Answers) : Item → Except String (List (String × Value))
  | .experiment id => match t.experiments.find? (·.id == id) with
    | some e => .ok (experimentLists A e)
    | none => .error s!"\"{id}\" is not an experiment on record"
  | .claim id => match A.lookups.claim? id with
    | some c => .ok [("sentence", .str (A.sentence c)), ("incompatible", strs (A.incompatible c)),
        ("plan", planJson (A.plan c))]
    | none => .error s!"\"{id}\" is not a claim on record"
  | .fact id => match A.lookups.fact? id with
    | some _ => .ok [("raisedBy", strs (((A.experimentOrder ()).filter fun e =>
        (A.raised (A.closure [e.id])).any (·.1 == id)).map (·.id)))]
    | none => .error s!"\"{id}\" is not a fact on record"

/-- The details document of one item (`fvtrace.details/1`), or the item's refusal. -/
def detailsWith (sc : Scenario) (A : Answers) (digest : String) (review : Receipt.ReviewState)
    (item : String) : Except String Value := do
  let it ← Item.parse item
  let lists ← itemLists sc.trace A it
  return .obj ([("schema", .str "fvtrace.details/1"),
    ("mode", .str (if sc.overrides.isEmpty then "recorded" else "what-if")),
    ("overrides", overridesJson sc.overrides), ("trace", traceJson sc.trace digest review),
    ("item", .str it.name)] ++ lists)

/-- The full envelope for one snapshot (trace + receipt bindings + overrides + review state), read
off the answers `A`. -/
def envelopeWith (sc : Scenario) (A : Answers) (bindings : List Receipt.Binding) (digest : String)
    (review : Receipt.ReviewState) : Value :=
  let t := sc.trace
  let existing := t.claims.filter fun c => !A.prospective c.subject
  -- Paired by `map`, never `List.zip`: Init's zip specialization recurses once per claim, which
  -- overflows the page engine's WebAssembly stack near 9,600 claims.
  let claimPlans := t.claims.map fun c => (c, A.plan c)
  let byId := Receipt.BindingIndex.of bindings
  .obj [("schema", .str "fvtrace.evaluation/1"),
    ("mode", .str (if sc.overrides.isEmpty then "recorded" else "what-if")),
    ("overrides", overridesJson sc.overrides),
    ("trace", traceJson t digest review),
    ("analysis", Encode.analysis t.analysis),
    ("subjects", .arr (t.subjects.map fun sub =>
      .obj [("id", .str sub.id), ("title", .str sub.title), ("kind", .str sub.kind.name),
        ("valid", .bool (A.valid sub.id)), ("conflicts", strs (A.conflicts sub.id))])),
    ("counts", stateCounts A existing),
    ("prospectiveCounts", .arr ((t.subjects.filter (·.kind == .prospective)).map fun sub =>
      .obj [("subject", .str sub.id), ("counts", stateCounts A (A.claimsOn sub.id))])),
    ("questions", .arr (t.questions.map Encode.question)),
    ("facts", .arr (t.facts.map (factJson A byId.find))),
    ("claims", .arr (claimPlans.map fun (c, p) => claimJson A review c p)),
    ("work", .arr ((A.work ()).map fun w =>
      .obj [("fact", .str w.fact), ("unlocks", strs w.unlocks), ("gates", strs w.gates)])),
    ("blockers", .arr ((A.blockerFacts ()).map fun (f, cs) =>
      .obj [("fact", .str f), ("claims", strs cs)])),
    ("experiments", .arr ((A.experimentOrder ()).map (experimentJson A))),
    ("exclusions", .arr (t.exclusions.map fun x =>
      .obj [("id", .str x.id), ("subject", .str x.subject),
        ("between", strs [x.between.1, x.between.2]), ("text", .str x.text),
        ("recorded", .str x.status.name), ("effective", .str (sc.exclusionEff x).name),
        ("active", .bool (A.active x))])),
    ("lints", .arr ((Lint.warningsWith A.lookups t).map fun w =>
      .obj ([("rule", .str w.rule), ("claim", .str w.claim), ("path", .str w.path),
        ("message", .str w.message)] ++
        (match w.waived with | some r => [("waived", .str r)] | none => [])))),
    ("actions", .arr ((actionsWith t A claimPlans).map fun (id, kind, target, o) =>
      .obj [("id", .str id), ("kind", .str kind), ("target", .str target),
        ("overrides", overridesJson o)]))]

/-- The full envelope for one snapshot, read off the scenario's fast answers (`Answers.fast`,
proved equal to the `Scenario` functions for every scenario: `Spec.AnswersAgree`). -/
def envelope (sc : Scenario) (bindings : List Receipt.Binding) (digest : String)
    (review : Receipt.ReviewState) : Value :=
  envelopeWith sc (Answers.fast sc) bindings digest review

/-- The batch document (`fvtrace.complete/1`, `kernel.md` V-complete): the envelope + the lists of
every item, one header for all: each experiment (envelope order), each claim, each fact. -/
def completeWith (sc : Scenario) (A : Answers) (bindings : List Receipt.Binding) (digest : String)
    (review : Receipt.ReviewState) : Value :=
  let t := sc.trace
  let item := fun (name : String) (lists : List (String × Value)) =>
    Value.obj ([("item", .str name)] ++ lists)
  let claimLists := fun (c : Claim) => [("sentence", Value.str (A.sentence c)),
    ("incompatible", strs (A.incompatible c)), ("plan", planJson (A.plan c))]
  let order := (A.experimentOrder ()).toArray
  -- Each experiment's raised facts once, inverted: a fact's raisers in experiment order.
  let raisers := Index.build compare (order.toList.zipIdx.flatMap fun (e, p) =>
    (A.raised (A.closure [e.id])).map fun x => (x.1, p))
  .obj [("schema", .str "fvtrace.complete/1"),
    ("envelope", envelopeWith sc A bindings digest review),
    ("items", .arr (order.toList.map (fun e => item s!"experiment:{e.id}" (experimentLists A e)) ++
      t.claims.map (fun c => item s!"claim:{c.id}" (claimLists c)) ++
      t.facts.map (fun f => item s!"fact:{f.id}" [("raisedBy", strs
        ((raisers.group (cmp := compare) f.id).filterMap fun p => (order[p]?).map (·.id)))])))]

end Evaluate
end Fvtrace
