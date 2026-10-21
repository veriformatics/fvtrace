import Fvtrace.Check

/-!
# Well-formedness (contract WF-*)

The rules a trace must satisfy before fvTrace evaluates it. Each rule is stated over the decoded
trace; `fvtrace check` lists violations (`Fvtrace.Check.violations`), and the claims at the end
say that list is empty exactly for well-formed traces and names only rules that truly fail.
-/

namespace Fvtrace.Spec
open Fvtrace

/-- WF-ids: no id appears twice across subjects, questions, facts, claims, experiments and
exclusions. -/
def IdsUnique (t : Trace) : Prop := t.allIds.Nodup

/-- WF-refs: every reference names an object of the right collection. -/
def RefsResolve (t : Trace) : Prop :=
  (∀ c ∈ t.claims, c.question ∈ t.questionIds ∧ c.subject ∈ t.subjectIds ∧
    (∀ n ∈ c.needs, n ∈ t.factIds) ∧ c.entailment ∈ t.factIds ∧
    ∀ v, c.variantOf = some v → v ∈ t.claimIds) ∧
  (∀ f ∈ t.facts, f.subject ∈ t.subjectIds ∧ ∀ s, f.instantiates = some s → s ∈ t.factIds) ∧
  (∀ e ∈ t.experiments, e.subject ∈ t.subjectIds ∧ (∀ p ∈ e.success ++ e.failure, p.1 ∈ t.factIds) ∧
    ∀ r ∈ e.requires, r ∈ t.experimentIds) ∧
  (∀ x ∈ t.exclusions, x.subject ∈ t.subjectIds ∧ x.between.1 ∈ t.factIds ∧
    x.between.2 ∈ t.factIds) ∧
  (∀ s ∈ t.subjects, ∀ e, s.createdBy = some e → e ∈ t.experimentIds) ∧
  (∀ w ∈ t.waivers, w.claim ∈ t.claimIds)

/-- A fact id that resolves lives on subject `s` (unresolved ids are WF-refs' concern). -/
def OnSubject (t : Trace) (id s : String) : Prop := ∀ sub, t.factSubject? id = some sub → sub = s

/-- WF-subject: a claim's needs + entailment, an experiment's outcomes and an exclusion's pair
all sit on the owner's subject; an instantiation names a fact on another subject. -/
def SubjectsAgree (t : Trace) : Prop :=
  (∀ c ∈ t.claims, (∀ n ∈ c.needsAll, OnSubject t n c.subject)) ∧
  (∀ e ∈ t.experiments, ∀ p ∈ e.success ++ e.failure, OnSubject t p.1 e.subject) ∧
  (∀ x ∈ t.exclusions, OnSubject t x.between.1 x.subject ∧ OnSubject t x.between.2 x.subject) ∧
  (∀ f ∈ t.facts, ∀ s, f.instantiates = some s →
    ∀ sub, t.factSubject? s = some sub → sub ≠ f.subject)

/-- WF-entail: a claim's entailment fact has kind `entailment`, is not among its needs and
belongs to that claim alone; no `entailment` fact is listed as a need. -/
def EntailmentsProper (t : Trace) : Prop :=
  ∀ c ∈ t.claims, (∀ f, t.fact? c.entailment = some f → f.kind = .entailment) ∧
    c.entailment ∉ c.needs ∧ (∀ d ∈ t.claims, d.entailment = c.entailment → d.id = c.id) ∧
    ∀ n ∈ c.needs, ∀ f, t.fact? n = some f → f.kind ≠ .entailment

/-- WF-needs: a claim needs at least one fact, each listed once. -/
def NeedsProper (t : Trace) : Prop := ∀ c ∈ t.claims, c.needs ≠ [] ∧ c.needs.Nodup

/-- WF-route: no recorded status or outcome status exceeds its fact's route or assumes a
must-verify fact (reasoning, result, measurement, calculation, code, data flow); no exclusion
status exceeds its route. -/
def RoutesRespected (t : Trace) : Prop :=
  (∀ f ∈ t.facts, f.allows f.status = true) ∧
  (∀ e ∈ t.experiments, ∀ p ∈ e.success ++ e.failure, ∀ f, t.fact? p.1 = some f →
    f.allows p.2 = true) ∧
  (∀ x ∈ t.exclusions, x.route.allows x.status = true)

/-- WF-outcome: a success asserts at least one fact and only asserts; a failure only violates;
`requires` names an experiment listed earlier on the same subject (so prerequisites are
acyclic). -/
def OutcomesProper (t : Trace) : Prop :=
  (∀ e ∈ t.experiments, e.success ≠ [] ∧ (∀ p ∈ e.success, p.2.asserted = true) ∧
    ∀ p ∈ e.failure, p.2 = .violated) ∧
  ∀ i (h : i < t.experiments.length), ∀ r ∈ t.experiments[i].requires,
    ∃ d ∈ t.experiments.take i, d.id = r ∧ d.subject = t.experiments[i].subject

/-- A verified recorded status needs a complete receipt. -/
def ReceiptComplete (s : Status) (e : Option Evidence) : Prop :=
  s.verified = true → ∃ ev, e = some ev ∧ ev.artifacts ≠ [] ∧
    (∀ a ∈ ev.artifacts, a.sha256.isSome) ∧
    ev.verifier.isSome ∧ ev.statement.isSome ∧ ev.statementDigest.isSome

/-- WF-receipt: every recorded verified fact or exclusion carries artifacts with digests, a
verifier, a statement and a statement digest. -/
def ReceiptsComplete (t : Trace) : Prop :=
  (∀ f ∈ t.facts, ReceiptComplete f.status f.evidence) ∧
  (∀ x ∈ t.exclusions, ReceiptComplete x.status x.evidence)

/-- WF-path: an artifact path is relative, `/`-separated, without empty, `.` or `..`
segments, backslashes or NUL. -/
def PathsSafe (t : Trace) : Prop :=
  ∀ ev ∈ (t.facts.filterMap (·.evidence) ++ t.exclusions.filterMap (·.evidence)),
    ∀ a ∈ ev.artifacts, Artifact.pathSafe a.path = true

/-- WF-prospective: a prospective subject names the experiment that creates it (an experiment on
that subject); an existing subject names none; at least one subject exists; facts on a
prospective subject record `open`. -/
def SubjectsProper (t : Trace) : Prop :=
  (∀ s ∈ t.subjects, (s.kind = .prospective ↔ s.createdBy.isSome) ∧
    ∀ e, s.createdBy = some e → ∀ x, t.experiment? e = some x → x.subject = s.id) ∧
  (∃ s ∈ t.subjects, s.kind = .existing) ∧
  (∀ f ∈ t.facts, ∀ s, t.subject? f.subject = some s → s.kind = .prospective → f.status = .«open»)

/-- WF-variant: a variant is a prospective-subject claim mirroring a claim on an existing
subject. -/
def VariantsProper (t : Trace) : Prop :=
  ∀ c ∈ t.claims, ∀ v, c.variantOf = some v →
    (∀ s, t.subject? c.subject = some s → s.kind = .prospective) ∧
    ∀ d, t.claim? v = some d → ∀ s, t.subject? d.subject = some s → s.kind = .existing

/-- WF-exclusion: an exclusion relates two different facts; one unordered pair per subject. -/
def ExclusionsProper (t : Trace) : Prop :=
  (∀ x ∈ t.exclusions, x.between.1 ≠ x.between.2) ∧
  ∀ i (h : i < t.exclusions.length), ∀ y ∈ t.exclusions.take i,
    ¬ (t.exclusions[i].subject = y.subject ∧
      (t.exclusions[i].between = y.between ∨ t.exclusions[i].between = y.between.swap))

/-- WF-consistent: no asserted exclusion has both sides recorded asserted (a contradictory trace
is an error, not a scenario). -/
def RecordedConsistent (t : Trace) : Prop :=
  ∀ x ∈ t.exclusions, x.status.asserted = true →
    ¬ ((∃ f, t.fact? x.between.1 = some f ∧ f.status.asserted = true) ∧
       (∃ f, t.fact? x.between.2 = some f ∧ f.status.asserted = true))

/-- WF-waiver: a waiver names a lint rule, at most once per claim. -/
def WaiversProper (t : Trace) : Prop :=
  (∀ w ∈ t.waivers, w.rule ∈ Check.lintRules) ∧ (t.waivers.map fun w => (w.rule, w.claim)).Nodup

/-- WF-kind: exactly the `instantiation` facts name a source fact. -/
def KindsProper (t : Trace) : Prop := ∀ f ∈ t.facts, f.kind = .instantiation ↔ f.instantiates.isSome

/-- A trace fvTrace will evaluate. -/
def WellFormed (t : Trace) : Prop :=
  IdsUnique t ∧ RefsResolve t ∧ SubjectsAgree t ∧ EntailmentsProper t ∧ NeedsProper t ∧
  RoutesRespected t ∧ OutcomesProper t ∧ ReceiptsComplete t ∧ PathsSafe t ∧ SubjectsProper t ∧
  VariantsProper t ∧ ExclusionsProper t ∧ RecordedConsistent t ∧ WaiversProper t ∧ KindsProper t

/-- The rule a listed violation names. -/
def Rule.Holds : Check.Rule → Trace → Prop
  | .ids => IdsUnique | .refs => RefsResolve | .subject => SubjectsAgree
  | .entail => EntailmentsProper | .needs => NeedsProper | .route => RoutesRespected
  | .outcome => OutcomesProper | .receipt => ReceiptsComplete | .path => PathsSafe
  | .prospective => SubjectsProper | .variant => VariantsProper | .exclusion => ExclusionsProper
  | .consistent => RecordedConsistent | .waiver => WaiversProper | .kind => KindsProper

/-- The well-formedness check in `fvtrace check` (`Check.violations`) reports no violation
exactly when the decoded trace is well-formed. -/
def CheckAcceptsExactlyWellFormed : Prop :=
  ∀ t : Trace, Check.violations t = [] ↔ WellFormed t

/-- Every violation the well-formedness check lists names a rule the decoded trace truly
breaks. -/
def CheckViolationsSound : Prop :=
  ∀ t : Trace, ∀ v ∈ Check.violations t, ¬ Rule.Holds v.rule t

end Fvtrace.Spec
