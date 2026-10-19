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

/-- G1: with no what-if, "Can claim" means every need, the claim's own entailment fact
included, is recorded verified with a current receipt. -/
def RecordedCanIsVerified : Prop :=
  ∀ (t : Trace) (current : String → Bool) (c : Claim),
    (({ trace := t, current } : Scenario).final c = .can) →
      ∀ n ∈ c.needsAll, ∃ f, t.fact? n = some f ∧ f.status.verified = true ∧ current n = true

/-- G2: a claim's verified, assumed, gap and violated needs partition its needs: each need is in
exactly one of the four lists. -/
def BreakdownPartitions : Prop :=
  ∀ (s : Scenario) (c : Claim), ∀ n ∈ c.needsAll,
    [decide (n ∈ s.verifiedNeeds c), decide (n ∈ s.premises c), decide (n ∈ s.gaps c),
      decide (n ∈ s.blockers c)].count true = 1

/-- G5: a claim whose entailment is only human-ruled or empirical never reads "Can claim", in a
well-formed trace under any valid what-if. -/
def RulingCeiling : Prop :=
  ∀ (s : Scenario) (c : Claim) (f : Fact),
    WellFormed s.trace → Overrides.valid s.trace s.overrides = true →
    s.trace.fact? c.entailment = some f → (f.route = .humanRuling ∨ f.route = .empirical) →
      s.final c ≠ .can

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

/-- G7: two what-ifs that agree on every fact of subject `T` give every claim on `T` the same
state, in a well-formed trace (what happens to other subjects cannot reach it). -/
def SubjectIsolation : Prop :=
  ∀ (t : Trace) (current : String → Bool) (o₁ o₂ : Overrides) (c : Claim),
    WellFormed t → c ∈ t.claims →
    (∀ k, t.factSubject? k = some c.subject → o₁.lookup k = o₂.lookup k) →
    ({ trace := t, current, overrides := o₁ } : Scenario).final c =
      ({ trace := t, current, overrides := o₂ } : Scenario).final c

/-- G6: the verdict "Can claim" is emitted exactly for final state `can`. -/
def CanVerdictExact : Prop := ∀ st : State, st.verdict = "Can claim" ↔ st = .can

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

end Fvtrace.Spec
