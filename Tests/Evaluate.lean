import Fvtrace
import Tests.Harness
import Tests.Engine

namespace Tests.Evaluate
open Tests Fvtrace Fvtrace.Json

def envOf (s : Scenario) (review : Receipt.ReviewState := .draft)
    (bindings : List Receipt.Binding := []) : Value :=
  Evaluate.envelope s bindings "digest" review

def counts (can conditional «open» cannot : Int) : Value :=
  .obj [("can", .num can), ("conditional", .num conditional), ("open", .num «open»),
    ("cannot", .num cannot)]

/-- The envelope fields no proof covers: counts, flags, receipt lookup, experiment order. -/
def tests : TestM Unit := do
  let t ← Tests.Engine.fixture
  let s : Scenario := { trace := t, current := fun _ => true }
  let env := envOf s
  -- C1 conditional + C2 open on S; C3 sits on the prospective subject N.
  checkEq "evaluate: counts cover the existing subject's claims" (field env "counts")
    (some (counts 0 1 1 0))
  checkEq "evaluate: prospective counts per new subject" (field env "prospectiveCounts")
    (some (.arr [.obj [("subject", .str "N"), ("counts", counts 0 0 1 0)]]))
  checkEq "evaluate: a draft trace's claims are provisional"
    ((claimOf env "C1").bind (field · "provisional")) (some (.bool true))
  checkEq "evaluate: a reviewed trace's claims are not provisional"
    ((claimOf (envOf s .reviewed) "C1").bind (field · "provisional")) (some (.bool false))
  checkEq "evaluate: applied = the what-if already holds the experiment's success"
    (((recordOf (envOf (s.withOverrides [("O2", .checked)])) "experiments" "E1").bind
      (field · "applied")), ((recordOf env "experiments" "E1").bind (field · "applied")))
    (some (.bool true), some (.bool false))
  let e1 := fun (k : String) => (recordOf env "experiments" "E1").bind (field · k)
  checkEq "evaluate: E1's failure breaks C2; its success touches result fact O2"
    (e1 "breaks", e1 "contingent") (some (.num 1), some (.bool true))
  let ask : Experiment := { (t.experiment? "E1").get! with
    id := "XN", success := [("O4", .assumed)], failure := [] }
  checkEq "evaluate: a success that touches no result fact is not contingent"
    ((recordOf (envOf { s with trace := { t with experiments := t.experiments ++ [ask] } })
      "experiments" "XN").bind (field · "contingent")) (some (.bool false))
  -- V-env: a failure action for each experiment with failure outcomes (E1 alone; E2 + E3 have
  -- none); a prospective claim's creator qualifier = the token, its other qualifiers unchanged.
  let actions := match field env "actions" with | some (.arr xs) => xs | _ => []
  checkEq "evaluate: failure actions name the experiments with failure outcomes"
    (actions.filterMap fun a =>
      if field a "kind" == some (.str "failure") then field a "target" else none) [.str "E1"]
  checkEq "evaluate: a prospective claim's creator qualifier = the token, beside the others"
    ((claimOf env "C3").bind (field · "label"))
    (some (.obj [("verdict", .str "Pending verification"),
      ("qualifiers", .arr [.str "draft", .str "if-creator-runs"]), ("creator", .str "E3")]))
  let stale : Receipt.Binding := { id := "O1", current := false, reasons := ["changed p"] }
  let other : Receipt.Binding := { id := "O2", current := true, reasons := [] }
  checkEq "evaluate: a fact carries its own receipt binding"
    ((recordOf (envOf s (bindings := [other, stale])) "facts" "O1").bind (field · "receipt"))
    (some (.obj [("current", .bool false), ("reasons", .arr [.str "changed p"])]))
  -- Experiment order: lights desc, then clears desc, then effort asc, then id asc.
  let v : Fact := { id := "V", subject := "S", kind := .numerical, text := "V holds.",
                    status := .violated, route := .runtimeChecker }
  let g : Fact := { v with id := "G", text := "G holds.", status := .«open» }
  let env' : Fact := { id := "ENV", subject := "S", kind := .entailment,
                       text := "V and G entail CV.", status := .assumed, route := .humanRuling }
  let cv : Claim := { id := "CV", question := "Q1", subject := "S", level := .estimand,
                      text := "V and G hold.", needs := ["V", "G"], entailment := some "ENV" }
  let x : Experiment := { id := "XA", subject := "S", kind := .dry, effort := .months,
                          title := "x", method := "m", resources := "r", caveat := "c",
                          success := [("O2", .checked), ("EN2", .proved)] }
  let added := [x, { x with id := "XB", effort := .weeks, success := [("V", .assumed)] },
    { x with id := "XD", effort := .hours, success := [("G", .checked)] },
    { x with id := "XC", effort := .hours, success := [("G", .checked)] },
    { x with id := "XE", effort := .days, success := [("G", .checked)] },
    { x with id := "XF", effort := .weeks, success := [("G", .checked)] },
    { x with id := "XG", effort := .weeks, success := [("G", .checked)] }]
  let order := { t with
    facts := t.facts ++ [v, g, env'], claims := t.claims ++ [cv]
    experiments := t.experiments ++ added }
  let ids := match field (envOf { s with trace := order }) "experiments" with
    | some (.arr xs) => xs.filterMap fun e => match field e "id" with
      | some (.str i) => if i.startsWith "X" then some i else none
      | _ => none
    | _ => []
  -- Id ties both ways round: XD is listed before XC, XF before XG.
  checkEq "evaluate: experiments order by lights, clears, effort, then id" ids
    ["XA", "XB", "XC", "XD", "XE", "XF", "XG"]

end Tests.Evaluate
