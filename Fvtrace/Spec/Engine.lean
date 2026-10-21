import Fvtrace.Evaluate
import Fvtrace.Spec.WellFormed

/-!
# What the engine guarantees (contract G1–G11)

Each claim below is about the shipped engine (`Fvtrace.Scenario`, `Fvtrace.Evaluate`); its proof
lives in `Fvtrace.Proofs`. "Verified" = `proved` or `checked`; a scenario = a trace, the receipt
binding of each id (`current`), and what-if overrides.
-/

namespace Fvtrace.Spec
open Fvtrace

/-- G1: with no what-if, "Fully supported" means the claim's subject is consistent and every
need, the claim's own entailment fact included, is recorded verified with a current receipt. -/
def RecordedCanIsVerified : Prop :=
  ∀ (t : Trace) (current : String → Bool) (c : Claim),
    (({ trace := t, current } : Scenario).final c = .can) →
      ({ trace := t, current } : Scenario).valid c.subject = true ∧
      ∀ n ∈ c.needsAll, ∃ f, t.fact? n = some f ∧ f.status.verified = true ∧ current n = true

/-- G1b: in a well-formed trace, a recorded "Fully supported" sits on an existing subject (facts on
a subject that does not exist yet record `open`). -/
def RecordedCanIsExisting : Prop :=
  ∀ (t : Trace) (current : String → Bool) (c : Claim), WellFormed t → c ∈ t.claims →
    ({ trace := t, current } : Scenario).final c = .can →
      ∃ sub, t.subject? c.subject = some sub ∧ sub.kind = .existing

/-- G2: a claim's verified, assumed, gap and violated needs partition its needs: each need is in
exactly one of the four lists, and each list keeps the needs' order. -/
def BreakdownPartitions : Prop :=
  ∀ (s : Scenario) (c : Claim),
    (∀ n ∈ c.needsAll,
      [decide (n ∈ s.verifiedNeeds c), decide (n ∈ s.premises c), decide (n ∈ s.gaps c),
        decide (n ∈ s.blockers c)].count true = 1) ∧
    ∀ l ∈ [s.verifiedNeeds c, s.premises c, s.gaps c, s.blockers c], l.Sublist c.needsAll

/-- G2b: "Claim not possible" always has a stated reason: a violated need or an asserted exclusion
between two needs (intrinsic), or a conflicting what-if on the subject. -/
def CannotExplained : Prop :=
  ∀ (s : Scenario) (c : Claim),
    (s.intrinsic c = .cannot ↔ s.blockers c ≠ [] ∨ s.incompatible c ≠ []) ∧
    (s.final c = .cannot ↔ s.intrinsic c = .cannot ∨ s.conflicts c.subject ≠ [])

/-- G5: in a well-formed trace under any valid what-if, a claim of the trace whose entailment
(its reasoning) is only human-ruled or empirical reads neither "Fully supported" nor
"Conditional": its reasoning can never be verified. -/
def RulingCeiling : Prop :=
  ∀ (s : Scenario) (c : Claim) (e : String) (f : Fact),
    WellFormed s.trace → c ∈ s.trace.claims → Overrides.valid s.trace s.overrides = true →
    c.entailment = some e → s.trace.fact? e = some f →
    (f.route = .humanRuling ∨ f.route = .empirical) → (s.final c).rank ≤ 1

/-- G12: a claim reads "Conditional" only when every need of a must-verify kind (its reasoning,
results, measurements, calculations, code, data flow) is verified: its assumptions are
background conditions alone. Holds for every scenario, valid or not. -/
def ConditionalNeedsVerified : Prop :=
  ∀ (s : Scenario) (c : Claim), s.final c = .conditional →
    ∀ n ∈ c.needsAll, s.mustVerify n = true → (s.eff n).verified = true

/-- G13: in a well-formed trace under a valid what-if, a fact that reads "assumed" is a background
condition: no must-verify fact is ever assumed. -/
def AssumedNeedsArePremises : Prop :=
  ∀ (s : Scenario) (n : String),
    WellFormed s.trace → Overrides.valid s.trace s.overrides = true →
    s.eff n = .assumed → s.mustVerify n = false

/-- G8a: a verified exclusion with a current receipt makes the unasserted side of a verified
fact violated. -/
def ExclusionDerives : Prop :=
  ∀ (s : Scenario) (x : Exclusion) (b : String),
    x ∈ s.trace.exclusions → (s.exclusionEff x).verified = true →
    x.between.2 = b → (s.eff1 x.between.1).verified = true → (s.eff1 b).asserted = false →
      s.eff b = .violated

/-- G8b: a claim needing both sides of an asserted exclusion cannot be made as written. -/
def BothSidesCannot : Prop :=
  ∀ (s : Scenario) (c : Claim) (x : Exclusion),
    x ∈ s.trace.exclusions → (s.exclusionEff x).asserted = true →
    x.between.1 ∈ c.needsAll → x.between.2 ∈ c.needsAll → s.final c = .cannot

/-- G6: a sentence is the concatenation of its parts; a conditional claim's parts quote each
premise verbatim, and every sentence ends with the claim text verbatim. -/
def SentenceVerbatim : Prop :=
  ∀ (s : Scenario) (c : Claim),
    s.sentence c = String.join (s.sentenceParts c) ∧
    (s.sentenceParts c).getLast? = some c.text ∧
    (s.final c = .conditional →
      ∀ p ∈ s.premises c, ("“" ++ s.factText p ++ "”") ∈ s.sentenceParts c)

/-- G11: a review record counts exactly when its digest equals the content's digest. -/
def ReviewStateExact : Prop :=
  ∀ (t : Trace) (digest : String),
    Receipt.reviewStateOf t digest = .reviewed ↔ ∃ r, t.review = some r ∧ r.digest = digest

/-- G7: two what-ifs that agree on every fact of a claim's subject give that claim the same state
and breakdown, in a well-formed trace (what happens to other subjects cannot reach it). -/
def SubjectIsolation : Prop :=
  ∀ (t : Trace) (current : String → Bool) (o₁ o₂ : Overrides) (c : Claim),
    WellFormed t → c ∈ t.claims →
    (∀ k, t.factSubject? k = some c.subject → o₁.lookup k = o₂.lookup k) →
    let s₁ : Scenario := { trace := t, current, overrides := o₁ }
    let s₂ : Scenario := { trace := t, current, overrides := o₂ }
    s₁.final c = s₂.final c ∧ s₁.verifiedNeeds c = s₂.verifiedNeeds c ∧
      s₁.premises c = s₂.premises c ∧ s₁.gaps c = s₂.gaps c ∧ s₁.blockers c = s₂.blockers c

/-- G9: raising one fact's status (staying non-violated) never lowers any claim's state, when
the fact sits in no exclusion (an exclusion can turn verifying one side into the other's
violation). -/
def RaisingMonotone : Prop :=
  ∀ (s : Scenario) (c : Claim) (k : String) (st : Status),
    (∀ x ∈ s.trace.exclusions, x.between.1 ≠ k ∧ x.between.2 ≠ k) → st ≠ .violated →
    (s.eff1 k).strength ≤ (EStatus.ofStatus st).strength →
      (s.final c).rank ≤ ((s.withOverrides [(k, st)]).final c).rank

/-- G6: the verdict "Fully supported" is emitted exactly for final state `can`. -/
def CanVerdictExact : Prop := ∀ st : State, st.verdict = "Fully supported" ↔ st = .can

/-- G10: every claim is counted under exactly one state. -/
def CountsComplete : Prop :=
  ∀ (s : Scenario) (claims : List Claim),
    ([State.can, .conditional, .«open», .cannot].map fun st =>
      (claims.filter fun c => s.final c == st).length).sum = claims.length

/-- G3: every move an experiment preview lists is a real change of that claim's state, and
every claim whose state changes is listed. -/
def MovesExact : Prop :=
  ∀ (s after : Scenario),
    (∀ m ∈ s.moves after, ∃ c ∈ s.trace.claims, c.id = m.claim ∧ m.before = s.final c ∧
      m.after = after.final c ∧ m.before ≠ m.after) ∧
    (∀ c ∈ s.trace.claims, s.final c ≠ after.final c → ∃ m ∈ s.moves after, m.claim = c.id)

/-- G3b: the preview counts partition the moves: each move counts once, as lighting (up into
can or conditional), clearing (cannot to open) or lowering a claim. -/
def CountsPartition : Prop :=
  ∀ (s after : Scenario),
    Scenario.lights (s.moves after) + Scenario.clears (s.moves after) +
      Scenario.lowers (s.moves after) = (s.moves after).length

/-- Ranking: `work` lists exactly the closable facts gating some claim (once each in a well-formed
trace), each with that fact's unlocks + gates, ordered by unlocks, then gates, then id. -/
def WorkExact : Prop :=
  ∀ s : Scenario,
    (∀ w ∈ s.work, ∃ f ∈ s.trace.facts, w.fact = f.id ∧ s.closable f = true ∧ s.gates f ≠ [] ∧
      w.unlocks = s.unlocks f ∧ w.gates = s.gates f) ∧
    (∀ f ∈ s.trace.facts, s.closable f = true → s.gates f ≠ [] → ∃ w ∈ s.work, w.fact = f.id) ∧
    (WellFormed s.trace → (s.work.map (·.fact)).Nodup) ∧
    s.work.Pairwise fun a b => Scenario.workBefore b a = false

/-- Experiment ids closed under prerequisites: each member's `requires` + the creator of its
subject (a prospective subject) are members. -/
def Closed (t : Trace) (q : List String) : Prop :=
  ∀ id ∈ q, ∀ e, t.experiment? id = some e →
    (∀ r ∈ e.requires, r ∈ q) ∧
      ∀ sub, t.subject? e.subject = some sub → ∀ x, sub.createdBy = some x → x ∈ q

/-- G4a: a plan holds its prerequisites, keeps the claim's subject consistent and reports the
state its success reaches. -/
def PlanSound : Prop :=
  ∀ (s : Scenario) (c : Claim) cov p st prem gaps contingent, WellFormed s.trace →
    s.plan c = .planned cov p st prem gaps contingent →
      Closed s.trace p ∧ (s.applySuccess p).valid c.subject = true ∧
        st = (s.applySuccess p).final c

/-- G4b: no prerequisite-closed set of experiments that keeps the claim's subject consistent
reaches a higher state than the plan, or the plan's state at a strictly lower cost (effort
counts, months first); with `noImprovement`, none beats the current state. `tooLarge` and
`inconsistent` claim no optimality. -/
def PlanOptimal : Prop :=
  ∀ (s : Scenario) (c : Claim) (q : List String), WellFormed s.trace → c ∈ s.trace.claims →
    Closed s.trace q → (s.applySuccess q).valid c.subject = true →
      (∀ cov p st prem gaps contingent, s.plan c = .planned cov p st prem gaps contingent →
        ((s.applySuccess q).final c).rank ≤ st.rank ∧
        (((s.applySuccess q).final c).rank = st.rank →
          lexLt (costOf s.trace q) (costOf s.trace p) = false)) ∧
      (∀ cov, s.plan c = .noImprovement cov →
        ((s.applySuccess q).final c).rank ≤ (s.final c).rank)

end Fvtrace.Spec
