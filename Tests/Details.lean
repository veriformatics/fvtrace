import Fvtrace
import Tests.Harness
import Tests.Snapshot

/-! Reference paths (`kernel.md` V-action, V-details, V-request, V-complete): every expansion = the
complete what-if v1 listed, every item's lists = the ones v1's envelope carried. -/

namespace Tests.Details
open Tests Fvtrace Fvtrace.Json

/-- An answer as (value, refusal), comparable. -/
def outcome {α : Type} (r : Except String α) : Option α × String :=
  match r with
  | .ok a => (some a, "")
  | .error m => (none, m)

def detailsOf (sc : Scenario) (item : String) : Except String Value :=
  Evaluate.detailsWith sc (Answers.fast sc) "digest" .draft item

/-- The oracles on one scenario: each item's lists = the reference answers' (the `Scenario`
functions v1's envelope read), each expansion = v1's complete what-if. -/
def oracles (name : String) (sc : Scenario) : TestM Unit := do
  let t := sc.trace
  let A := Answers.fast sc
  let R := Answers.reference sc
  for (id, _, _, o) in Evaluate.actions sc do
    checkEq s!"details ({name}): {id} expands to v1's complete what-if, normalized"
      (Evaluate.expandWith t A id).toOption (some (Overrides.normalize o))
  for e in t.experiments do
    let got := match detailsOf sc s!"experiment:{e.id}" with
      | .ok d => ["closure", "raises", "wins", "losses"].filterMap fun k => (field d k).map (k, ·)
      | .error _ => []
    checkEq s!"details ({name}): experiment:{e.id} = v1's lists" got (Evaluate.experimentLists R e)
  for c in t.claims do
    let got := match detailsOf sc s!"claim:{c.id}" with
      | .ok d => (field d "plan", field d "sentence", field d "incompatible")
      | .error _ => (none, none, none)
    let want := (some (Evaluate.planJson (R.plan c)), some (Value.str (R.sentence c)),
      some (Evaluate.strs (R.incompatible c)))
    checkEq s!"details ({name}): claim:{c.id} = v1's plan, sentence + incompatible" got want
  for f in t.facts do
    checkEq s!"details ({name}): fact:{f.id} raisedBy = v1's derived list"
      ((detailsOf sc s!"fact:{f.id}").toOption.bind (field · "raisedBy"))
      (some (Evaluate.strs (((R.experimentOrder ()).filter fun e =>
        (R.raised (R.closure [e.id])).any (·.1 == f.id)).map (·.id))))
  -- The batch document: the envelope + every item's lists, one header.
  let all := Evaluate.completeWith sc A [] "digest" .draft
  checkEq s!"details ({name}): complete carries the envelope" (field all "envelope")
    (some (Evaluate.envelope sc [] "digest" .draft))
  checkEq s!"details ({name}): complete lists every experiment, claim + fact"
    (match field all "items" with | some (.arr xs) => xs.length | _ => 0)
    (t.experiments.length + t.claims.length + t.facts.length)

def tests : TestM Unit := do
  let fixture ← Tests.Snapshot.traceOf "tests/fixtures/synthetic.trace.json"
  let synthetic ← Tests.Snapshot.traceOf "examples/synthetic/trace.json"
  let self ← Tests.Snapshot.traceOf "examples/fvtrace/trace.json"
  let base := fun (t : Trace) => ({ trace := t, current := fun _ => true } : Scenario)
  oracles "fixture" (base fixture)
  oracles "synthetic" (base synthetic)
  oracles "self-trace" (base self)
  oracles "synthetic, a what-if" ((base synthetic).withOverrides [("O2", .checked)])
  -- A success that raises nothing leaves the recorded view recorded (mode from ω').
  let sc := base synthetic
  match synthetic.facts.find? (·.status == .assumed), synthetic.experiments.head? with
  | some f, some e =>
    let noop := { e with id := "XN", success := [(f.id, .assumed)], failure := [], requires := [] }
    let sc' := base { synthetic with experiments := synthetic.experiments ++ [noop] }
    checkEq "details: a success that raises nothing expands to the recorded view"
      (Evaluate.expandWith sc'.trace (Answers.fast sc') "success:XN").toOption (some [])
  | _, _ => check "details: the synthetic study has an assumed fact + an experiment" false
  -- Refusals (V-action, V-details): the token first.
  let A := Answers.fast sc
  checkEq "details: an action not suggested is refused"
    (outcome (Evaluate.expandWith synthetic A "plan:C9"))
    (none, "\"plan:C9\" is not a suggested what-if")
  checkEq "details: an action without a kind is refused"
    (outcome (Evaluate.expandWith synthetic A "O2")) (none, "\"O2\" is not a suggested what-if")
  for (item, msg) in [("E9", "\"E9\" is not of the form KIND:ID"),
      ("experiment:", "\"experiment:\" is not of the form KIND:ID"),
      ("thing:E1", "\"thing:E1\" is not of the form KIND:ID"),
      ("experiment:E9", "\"E9\" is not an experiment on record"),
      ("claim:C9", "\"C9\" is not a claim on record"),
      ("fact:F9", "\"F9\" is not a fact on record")] do
    checkEq s!"details: item {item} refused" (outcome (detailsOf sc item)) (none, msg)
  checkEq "details: the header names the item + the view"
    ((detailsOf sc "fact:O2").toOption.map fun d =>
      (field d "schema", field d "item", field d "mode"))
    (some (some (.str "fvtrace.details/1"), some (.str "fact:O2"), some (.str "recorded")))
  -- V-request: exact keys, string values.
  checkEq "request: whatif alone" (Request.parse "{\"whatif\":\"O2=checked\"}").toOption
    (some { whatif := "O2=checked" })
  checkEq "request: all three keys"
    (Request.parse "{\"whatif\":\"\",\"action\":\"plan:C2\",\"details\":\"claim:C2\"}").toOption
    (some { whatif := "", action := some "plan:C2", details := some "claim:C2" })
  for bad in ["{}", "{\"whatif\":1}", "{\"whatif\":\"\",\"extra\":\"x\"}", "[\"whatif\"]", "nope",
      "{\"whatif\":\"\",\"action\":null}"] do
    checkEq s!"request: {bad} refused" (outcome (Request.parse bad)) (none, Request.malformed)

end Tests.Details
