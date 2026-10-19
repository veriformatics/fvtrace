import Fvtrace.Model

/-!
# Lints (contract § Lints)

Role checks per claim level: warnings, never errors. A waiver naming the rule + claim suppresses
the warning and is listed with its reason, so a waived gap stays visible.
-/

namespace Fvtrace.Lint

structure Warning where
  rule : String
  claim : String
  /-- RFC 6901 pointer into the trace document. -/
  path : String
  message : String
  /-- The recorded reason, when a waiver covers this warning. -/
  waived : Option String := none
  deriving Repr, Inhabited, BEq

/-- Whether claim `c` needs a fact of kind `k`. -/
def needsKind (t : Trace) (c : Claim) (k : Kind) : Bool :=
  c.needs.any fun n => (t.fact? n).any (·.kind == k)

/-- Rule id, the levels it applies to, the kind it asks for, and why. -/
def rules : List (String × List Level × Kind × String) :=
  [("L-result", [.descriptive, .inferential, .causal], .result,
     "asserts an observed value or pattern but needs no result fact"),
   ("L-statistical", [.inferential, .causal], .statistical,
     "draws an inference but needs no statistical fact"),
   ("L-interpretation", [.causal], .interpretation,
     "asserts a cause but needs no interpretation fact naming the identification assumptions"),
   ("L-release", [.release], .release, "concerns publication but needs no release fact"),
   ("L-estimand", [.estimand], .estimand, "defines an estimand but needs no estimand fact")]

def waiverFor (t : Trace) (rule claim : String) : Option String :=
  (t.waivers.find? fun w => w.rule == rule && w.claim == claim).map (·.reason)

/-- Every role warning, in claim order then rule order. -/
def warnings (t : Trace) : List Warning :=
  t.claims.zipIdx.flatMap fun (c, i) =>
    rules.filterMap fun (rule, levels, k, why) =>
      if levels.contains c.level && !needsKind t c k then
        some { rule, claim := c.id, path := s!"/claims/{i}", message := s!"{c.id} {why}",
               waived := waiverFor t rule c.id }
      else none

end Fvtrace.Lint
