import Fvtrace.Lint
import Fvtrace.Lookups

/-!
# Trace checker (contract WF-*)

`violations t` lists every broken well-formedness rule instance with a JSON pointer + message.
`Fvtrace.Spec.WellFormed` states the rules; `Fvtrace.Proofs.Check` proves the list is empty
exactly for well-formed traces and names only rules that fail. The rules read the trace through a
`Lookups` record: `violations` runs them on the indexed one, which `Fvtrace.Proofs.Lookups` proves
equal to the one reading the trace's lists.
-/

namespace Fvtrace

/-- An artifact path stays inside the project: relative, `/`-separated, no empty, `.` or `..`
segment, no backslash or NUL. -/
def Artifact.pathSafe (p : String) : Bool :=
  !p.isEmpty && !p.any (fun c => c == '\\' || c == '\x00') &&
    (p.splitOn "/").all fun seg => !seg.isEmpty && seg != "." && seg != ".."

namespace Check

inductive Rule where
  | ids | refs | subject | entail | needs | route | outcome | receipt | path | prospective
  | variant | exclusion | consistent | waiver | kind
  deriving DecidableEq, Repr, Inhabited

def Rule.all : List Rule :=
  [.ids, .refs, .subject, .entail, .needs, .route, .outcome, .receipt, .path, .prospective,
   .variant, .exclusion, .consistent, .waiver, .kind]

def Rule.code : Rule → String
  | .ids => "WF-ids" | .refs => "WF-refs" | .subject => "WF-subject" | .entail => "WF-entail"
  | .needs => "WF-needs" | .route => "WF-route" | .outcome => "WF-outcome"
  | .receipt => "WF-receipt" | .path => "WF-path" | .prospective => "WF-prospective"
  | .variant => "WF-variant" | .exclusion => "WF-exclusion" | .consistent => "WF-consistent"
  | .waiver => "WF-waiver" | .kind => "WF-kind"

structure Violation where
  rule : Rule
  /-- RFC 6901 pointer into the trace document. -/
  path : String
  message : String
  deriving Repr, Inhabited

/-- Lint rule ids a waiver may name. -/
def lintRules : List String := Lint.rules.map (·.1)

abbrev Found := List (String × String)

/-- One finding at `path` unless `ok`; inlined, so a passing check never builds its message. -/
@[macro_inline] def ensure (ok : Bool) (path message : String) : Found :=
  if ok then [] else [(path, message)]

def onSubject (L : Lookups) (id s : String) : Bool :=
  match L.factSubject? id with
  | some sub => sub == s
  | none => true

def ids (L : Lookups) : Found :=
  ensure (L.idsNodup ()) "" s!"ids declared more than once: {", ".intercalate (L.duplicateIds ())}"

def claimRefs (L : Lookups) (c : Claim) (i : Nat) : Found :=
  let p := s!"/claims/{i}"
  ensure (L.hasQuestion c.question) (p ++ "/question") s!"no question \"{c.question}\"" ++
  ensure (L.hasSubject c.subject) (p ++ "/subject") s!"no subject \"{c.subject}\"" ++
  (c.needs.flatMap fun n => ensure (L.hasFact n) (p ++ "/needs") s!"no fact \"{n}\"") ++
  (match c.entailment with
   | some e => ensure (L.hasFact e) (p ++ "/entailment") s!"no fact \"{e}\""
   | none => []) ++
  (match c.variantOf with
   | some v => ensure (L.hasClaim v) (p ++ "/variantOf") s!"no claim \"{v}\""
   | none => [])

def factRefs (L : Lookups) (f : Fact) (i : Nat) : Found :=
  let p := s!"/facts/{i}"
  ensure (L.hasSubject f.subject) (p ++ "/subject") s!"no subject \"{f.subject}\"" ++
  (match f.instantiates with
   | some s => ensure (L.hasFact s) (p ++ "/instantiates") s!"no fact \"{s}\""
   | none => [])

def experimentRefs (L : Lookups) (e : Experiment) (i : Nat) : Found :=
  let p := s!"/experiments/{i}"
  ensure (L.hasSubject e.subject) (p ++ "/subject") s!"no subject \"{e.subject}\"" ++
  ((e.success ++ e.failure).flatMap fun q =>
    ensure (L.hasFact q.1) p s!"outcome names no fact \"{q.1}\"") ++
  (e.requires.flatMap fun r =>
    ensure (L.hasExperiment r) (p ++ "/requires") s!"no experiment \"{r}\"")

def exclusionRefs (L : Lookups) (x : Exclusion) (i : Nat) : Found :=
  let p := s!"/exclusions/{i}"
  ensure (L.hasSubject x.subject) (p ++ "/subject") s!"no subject \"{x.subject}\"" ++
  ensure (L.hasFact x.between.1) (p ++ "/between/0") s!"no fact \"{x.between.1}\"" ++
  ensure (L.hasFact x.between.2) (p ++ "/between/1") s!"no fact \"{x.between.2}\""

def subjectRefs (L : Lookups) (s : Subject) (i : Nat) : Found :=
  match s.createdBy with
  | some e =>
    ensure (L.hasExperiment e) s!"/subjects/{i}/createdBy" s!"no experiment \"{e}\""
  | none => []

def waiverRefs (L : Lookups) (w : Waiver) (i : Nat) : Found :=
  ensure (L.hasClaim w.claim) s!"/waivers/{i}/claim" s!"no claim \"{w.claim}\""

def refs (L : Lookups) (t : Trace) : Found :=
  (t.claims.zipIdx.flatMap fun (c, i) => claimRefs L c i) ++
  (t.facts.zipIdx.flatMap fun (f, i) => factRefs L f i) ++
  (t.experiments.zipIdx.flatMap fun (e, i) => experimentRefs L e i) ++
  (t.exclusions.zipIdx.flatMap fun (x, i) => exclusionRefs L x i) ++
  (t.subjects.zipIdx.flatMap fun (s, i) => subjectRefs L s i) ++
  (t.waivers.zipIdx.flatMap fun (w, i) => waiverRefs L w i)

def claimSubjects (L : Lookups) (c : Claim) (i : Nat) : Found :=
  c.needsAll.flatMap fun n =>
    ensure (onSubject L n c.subject) s!"/claims/{i}" s!"\"{n}\" is not on subject \"{c.subject}\""

def experimentSubjects (L : Lookups) (e : Experiment) (i : Nat) : Found :=
  (e.success ++ e.failure).flatMap fun q =>
    ensure (onSubject L q.1 e.subject) s!"/experiments/{i}"
      s!"outcome \"{q.1}\" is not on subject \"{e.subject}\""

def exclusionSubjects (L : Lookups) (x : Exclusion) (i : Nat) : Found :=
  ensure (onSubject L x.between.1 x.subject && onSubject L x.between.2 x.subject)
    s!"/exclusions/{i}/between" s!"the pair is not on subject \"{x.subject}\""

def instantiationSubject (L : Lookups) (f : Fact) (i : Nat) : Found :=
  match f.instantiates with
  | some s =>
    match L.factSubject? s with
    | some sub => ensure (sub != f.subject) s!"/facts/{i}/instantiates"
        "an instantiation names a fact on another subject"
    | none => []
  | none => []

def subject (L : Lookups) (t : Trace) : Found :=
  (t.claims.zipIdx.flatMap fun (c, i) => claimSubjects L c i) ++
  (t.experiments.zipIdx.flatMap fun (e, i) => experimentSubjects L e i) ++
  (t.exclusions.zipIdx.flatMap fun (x, i) => exclusionSubjects L x i) ++
  (t.facts.zipIdx.flatMap fun (f, i) => instantiationSubject L f i)

def entailmentKind (L : Lookups) (id : String) : Bool :=
  match L.fact? id with
  | some f => f.kind == .entailment
  | none => true

def needNotEntailment (L : Lookups) (id : String) : Bool :=
  match L.fact? id with
  | some f => f.kind != .entailment
  | none => true

def resultKind (L : Lookups) (id : String) : Bool :=
  match L.fact? id with
  | some f => f.kind == .result
  | none => true

/-- The entailment fact's own rules (kind, not a need, one claim each). -/
def entailmentFact (L : Lookups) (c : Claim) (p e : String) : Found :=
  ensure (entailmentKind L e) (p ++ "/entailment")
    "the entailment fact must have kind entailment" ++
  ensure (!c.needs.contains e) (p ++ "/needs") "the entailment fact is listed as a need" ++
  ensure (L.soleEntailment e c.id) (p ++ "/entailment")
    "another claim uses the same entailment fact"

/-- A restating claim's shape: one result need, restated by no other claim. -/
def restating (L : Lookups) (c : Claim) (p : String) : Found :=
  ensure (c.needs.length == 1 && c.needs.all (resultKind L)) (p ++ "/needs")
    "a restating claim needs exactly one fact, of kind result" ++
  ensure (L.soleRestater c.needs c.id) (p ++ "/needs")
    "another claim restates the same result"

def claimEntail (L : Lookups) (c : Claim) (i : Nat) : Found :=
  let p := s!"/claims/{i}"
  ensure (c.restates == c.entailment.isNone) p
    (if c.restates then "a restating claim names no entailment fact"
     else "a claim names an entailment fact unless it restates one result (\"restates\": true)") ++
  (match c.entailment with
   | some e => entailmentFact L c p e
   | none => []) ++
  (if c.restates then restating L c p else []) ++
  (c.needs.flatMap fun n =>
    ensure (needNotEntailment L n) (p ++ "/needs") s!"\"{n}\" is an entailment fact")

def entail (L : Lookups) (t : Trace) : Found :=
  t.claims.zipIdx.flatMap fun (c, i) => claimEntail L c i

def needs (L : Lookups) (t : Trace) : Found :=
  t.claims.zipIdx.flatMap fun (c, i) =>
    ensure (!c.needs.isEmpty) s!"/claims/{i}/needs" "a claim needs at least one fact" ++
    ensure (L.nodup c.needs) s!"/claims/{i}/needs" "a fact is listed twice"

/-- Why fact `f` may not hold `st`: above its route, or an assumed must-verify fact. -/
def disallowed (f : Fact) (st : Status) : String :=
  if f.route.allows st then
    s!"{f.id} cannot be assumed: facts of kind {f.kind.name} must be verified, so record open, \
      tested or a verified status"
  else s!"{st.name} exceeds route {f.route.name}"

/-- Why an outcome may not set `st` on fact `f`: a success only asserts, so its repair is a verified
status or no entry at all. -/
def disallowedOutcome (f : Fact) (st : Status) : String :=
  if f.route.allows st then
    s!"a success cannot assume {f.id}: facts of kind {f.kind.name} must be verified; set a \
      verified status that its route allows, or leave {f.id} out"
  else s!"{st.name} exceeds route {f.route.name}"

def outcomeRoutes (L : Lookups) (e : Experiment) (i : Nat) : Found :=
  (e.success ++ e.failure).flatMap fun q =>
    match L.fact? q.1 with
    | some f =>
      ensure (f.allows q.2) s!"/experiments/{i}" s!"outcome \"{q.1}\": {disallowedOutcome f q.2}"
    | none => []

def route (L : Lookups) (t : Trace) : Found :=
  (t.facts.zipIdx.flatMap fun (f, i) =>
    ensure (f.allows f.status) s!"/facts/{i}/status" (disallowed f f.status)) ++
  (t.experiments.zipIdx.flatMap fun (e, i) => outcomeRoutes L e i) ++
  (t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (x.route.allows x.status) s!"/exclusions/{i}/status"
      s!"{x.status.name} exceeds route {x.route.name}")

def requiresEarlier (L : Lookups) (e : Experiment) (i : Nat) : Found :=
  e.requires.flatMap fun r =>
    ensure (L.earlierExperiment i r e.subject) s!"/experiments/{i}/requires"
      s!"\"{r}\" must be an earlier experiment on subject \"{e.subject}\""

def outcome (L : Lookups) (t : Trace) : Found :=
  (t.experiments.zipIdx.flatMap fun (e, i) =>
    ensure (!e.success.isEmpty) s!"/experiments/{i}/success"
      "a success asserts at least one fact" ++
    (e.success.flatMap fun q =>
      ensure q.2.asserted s!"/experiments/{i}/success" s!"a success cannot set {q.2.name}") ++
    (e.failure.flatMap fun q =>
      ensure (q.2 == .violated) s!"/experiments/{i}/failure" "a failure sets violated alone")) ++
  (t.experiments.zipIdx.flatMap fun (e, i) => requiresEarlier L e i)

def receiptOk (s : Status) (e : Option Evidence) : Bool :=
  !s.verified ||
    match e with
    | some ev => !ev.artifacts.isEmpty && ev.artifacts.all (·.sha256.isSome) &&
        ev.verifier.isSome && ev.statement.isSome && ev.statementDigest.isSome
    | none => false

def receiptMessage : String :=
  "a verified status needs artifacts with sha256, a verifier, a statement and a statementDigest"

def receipt (t : Trace) : Found :=
  (t.facts.zipIdx.flatMap fun (f, i) =>
    ensure (receiptOk f.status f.evidence) s!"/facts/{i}/evidence" receiptMessage) ++
  (t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (receiptOk x.status x.evidence) s!"/exclusions/{i}/evidence" receiptMessage)

def path (t : Trace) : Found :=
  (t.facts.filterMap (·.evidence) ++ t.exclusions.filterMap (·.evidence)).flatMap fun ev =>
    ev.artifacts.flatMap fun a =>
      ensure (Artifact.pathSafe a.path) "" s!"artifact path \"{a.path}\" leaves the project folder"

def subjectProper (L : Lookups) (s : Subject) (i : Nat) : Found :=
  let p := s!"/subjects/{i}"
  ensure ((s.kind == .prospective) == s.createdBy.isSome) p
    "a prospective subject names createdBy; an existing one does not" ++
  (match s.createdBy with
   | some e =>
     match L.experiment? e with
     | some x => ensure (x.subject == s.id) (p ++ "/createdBy")
         s!"experiment \"{e}\" is not on subject \"{s.id}\""
     | none => []
   | none => [])

def prospectiveOpen (L : Lookups) (f : Fact) : Bool :=
  match L.subject? f.subject with
  | some s => s.kind != .prospective || f.status == .«open»
  | none => true

def prospective (L : Lookups) (t : Trace) : Found :=
  (t.subjects.zipIdx.flatMap fun (s, i) => subjectProper L s i) ++
  ensure (t.subjects.any (·.kind == .existing)) "/subjects" "at least one existing subject" ++
  (t.facts.zipIdx.flatMap fun (f, i) =>
    ensure (prospectiveOpen L f) s!"/facts/{i}/status"
      "a fact on a prospective subject records open: its data does not exist yet")

def subjectKind (L : Lookups) (id : String) (k : SubjectKind) : Bool :=
  match L.subject? id with
  | some s => s.kind == k
  | none => true

def variant (L : Lookups) (t : Trace) : Found :=
  t.claims.zipIdx.flatMap fun (c, i) =>
    match c.variantOf with
    | some v =>
      ensure (subjectKind L c.subject .prospective) s!"/claims/{i}/variantOf"
        "a variant claim sits on a prospective subject" ++
      (match L.claim? v with
       | some d => ensure (subjectKind L d.subject .existing) s!"/claims/{i}/variantOf"
           s!"claim \"{v}\" is not on an existing subject"
       | none => [])
    | none => []

def exclusion (L : Lookups) (t : Trace) : Found :=
  (t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (x.between.1 != x.between.2) s!"/exclusions/{i}/between"
      "an exclusion relates two facts") ++
  (t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (!L.earlierPair i x) s!"/exclusions/{i}"
      "the same pair is excluded twice on one subject")

def assertedFact (L : Lookups) (id : String) : Bool :=
  match L.fact? id with
  | some f => f.status.asserted
  | none => false

def consistent (L : Lookups) (t : Trace) : Found :=
  t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (!(x.status.asserted && assertedFact L x.between.1 && assertedFact L x.between.2))
      s!"/exclusions/{i}"
      "both facts of this exclusion are recorded as holding: the trace contradicts itself"

def waiver (L : Lookups) (t : Trace) : Found :=
  (t.waivers.zipIdx.flatMap fun (w, i) =>
    ensure (lintRules.contains w.rule) s!"/waivers/{i}/rule" s!"no lint rule \"{w.rule}\"") ++
  ensure (L.waiversNodup ()) "/waivers"
    "a rule is waived twice for one claim"

def kind (t : Trace) : Found :=
  t.facts.zipIdx.flatMap fun (f, i) =>
    ensure ((f.kind == .instantiation) == f.instantiates.isSome) s!"/facts/{i}"
      "an instantiation fact (and only one) names `instantiates`"

def Rule.check : Rule → Lookups → Trace → Found
  | .ids => fun L _ => Check.ids L | .refs => Check.refs | .subject => Check.subject
  | .entail => Check.entail | .needs => Check.needs | .route => Check.route
  | .outcome => Check.outcome | .receipt => fun _ => Check.receipt
  | .path => fun _ => Check.path | .prospective => Check.prospective
  | .variant => Check.variant | .exclusion => Check.exclusion
  | .consistent => Check.consistent | .waiver => Check.waiver | .kind => fun _ => Check.kind

/-- Every broken rule instance, in rule order, read through `L`. -/
def violationsWith (L : Lookups) (t : Trace) : List Violation :=
  Rule.all.flatMap fun r => (r.check L t).map fun (p, m) => { rule := r, path := p, message := m }

/-- Every broken rule instance, in rule order (the trace read through its indexes). -/
def violations (t : Trace) : List Violation := violationsWith (Lookups.fast t) t

end Check
end Fvtrace
