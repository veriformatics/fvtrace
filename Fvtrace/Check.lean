import Fvtrace.Lint

/-!
# Trace checker (contract WF-*)

`violations t` lists every broken well-formedness rule instance with a JSON pointer + message.
`Fvtrace.Spec.WellFormed` states the rules; `Fvtrace.Proofs.Check` proves the list is empty
exactly for well-formed traces and names only rules that fail.
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

/-- One finding at `path` ensure `ok`. -/
def ensure (ok : Bool) (path message : String) : Found := if ok then [] else [(path, message)]

def onSubject (t : Trace) (id s : String) : Bool :=
  match t.factSubject? id with
  | some sub => sub == s
  | none => true

/-- Ids seen before index `i` (for first-duplicate reporting). -/
def duplicates (ids : List String) : List String :=
  (ids.zipIdx.filter fun (x, i) => (ids.take i).contains x).map (·.1)

def ids (t : Trace) : Found :=
  ensure (decide t.allIds.Nodup) ""
    s!"ids declared more than once: {", ".intercalate (duplicates t.allIds).eraseDups}"

def claimRefs (t : Trace) (c : Claim) (i : Nat) : Found :=
  let p := s!"/claims/{i}"
  ensure (t.questionIds.contains c.question) (p ++ "/question") s!"no question \"{c.question}\"" ++
  ensure (t.subjectIds.contains c.subject) (p ++ "/subject") s!"no subject \"{c.subject}\"" ++
  (c.needs.flatMap fun n => ensure (t.factIds.contains n) (p ++ "/needs") s!"no fact \"{n}\"") ++
  ensure (t.factIds.contains c.entailment) (p ++ "/entailment") s!"no fact \"{c.entailment}\"" ++
  (match c.variantOf with
   | some v => ensure (t.claimIds.contains v) (p ++ "/variantOf") s!"no claim \"{v}\""
   | none => [])

def factRefs (t : Trace) (f : Fact) (i : Nat) : Found :=
  let p := s!"/facts/{i}"
  ensure (t.subjectIds.contains f.subject) (p ++ "/subject") s!"no subject \"{f.subject}\"" ++
  (match f.instantiates with
   | some s => ensure (t.factIds.contains s) (p ++ "/instantiates") s!"no fact \"{s}\""
   | none => [])

def experimentRefs (t : Trace) (e : Experiment) (i : Nat) : Found :=
  let p := s!"/experiments/{i}"
  ensure (t.subjectIds.contains e.subject) (p ++ "/subject") s!"no subject \"{e.subject}\"" ++
  ((e.success ++ e.failure).flatMap fun q =>
    ensure (t.factIds.contains q.1) p s!"outcome names no fact \"{q.1}\"") ++
  (e.requires.flatMap fun r =>
    ensure (t.experimentIds.contains r) (p ++ "/requires") s!"no experiment \"{r}\"")

def exclusionRefs (t : Trace) (x : Exclusion) (i : Nat) : Found :=
  let p := s!"/exclusions/{i}"
  ensure (t.subjectIds.contains x.subject) (p ++ "/subject") s!"no subject \"{x.subject}\"" ++
  ensure (t.factIds.contains x.between.1) (p ++ "/between/0") s!"no fact \"{x.between.1}\"" ++
  ensure (t.factIds.contains x.between.2) (p ++ "/between/1") s!"no fact \"{x.between.2}\""

def subjectRefs (t : Trace) (s : Subject) (i : Nat) : Found :=
  match s.createdBy with
  | some e =>
    ensure (t.experimentIds.contains e) s!"/subjects/{i}/createdBy" s!"no experiment \"{e}\""
  | none => []

def waiverRefs (t : Trace) (w : Waiver) (i : Nat) : Found :=
  ensure (t.claimIds.contains w.claim) s!"/waivers/{i}/claim" s!"no claim \"{w.claim}\""

def refs (t : Trace) : Found :=
  (t.claims.zipIdx.flatMap fun (c, i) => claimRefs t c i) ++
  (t.facts.zipIdx.flatMap fun (f, i) => factRefs t f i) ++
  (t.experiments.zipIdx.flatMap fun (e, i) => experimentRefs t e i) ++
  (t.exclusions.zipIdx.flatMap fun (x, i) => exclusionRefs t x i) ++
  (t.subjects.zipIdx.flatMap fun (s, i) => subjectRefs t s i) ++
  (t.waivers.zipIdx.flatMap fun (w, i) => waiverRefs t w i)

def claimSubjects (t : Trace) (c : Claim) (i : Nat) : Found :=
  c.needsAll.flatMap fun n =>
    ensure (onSubject t n c.subject) s!"/claims/{i}" s!"\"{n}\" is not on subject \"{c.subject}\""

def experimentSubjects (t : Trace) (e : Experiment) (i : Nat) : Found :=
  (e.success ++ e.failure).flatMap fun q =>
    ensure (onSubject t q.1 e.subject) s!"/experiments/{i}"
      s!"outcome \"{q.1}\" is not on subject \"{e.subject}\""

def exclusionSubjects (t : Trace) (x : Exclusion) (i : Nat) : Found :=
  ensure (onSubject t x.between.1 x.subject && onSubject t x.between.2 x.subject)
    s!"/exclusions/{i}/between" s!"the pair is not on subject \"{x.subject}\""

def instantiationSubject (t : Trace) (f : Fact) (i : Nat) : Found :=
  match f.instantiates with
  | some s =>
    match t.factSubject? s with
    | some sub => ensure (sub != f.subject) s!"/facts/{i}/instantiates"
        "an instantiation names a fact on another subject"
    | none => []
  | none => []

def subject (t : Trace) : Found :=
  (t.claims.zipIdx.flatMap fun (c, i) => claimSubjects t c i) ++
  (t.experiments.zipIdx.flatMap fun (e, i) => experimentSubjects t e i) ++
  (t.exclusions.zipIdx.flatMap fun (x, i) => exclusionSubjects t x i) ++
  (t.facts.zipIdx.flatMap fun (f, i) => instantiationSubject t f i)

def entailmentKind (t : Trace) (id : String) : Bool :=
  match t.fact? id with
  | some f => f.kind == .entailment
  | none => true

def needNotEntailment (t : Trace) (id : String) : Bool :=
  match t.fact? id with
  | some f => f.kind != .entailment
  | none => true

def claimEntail (t : Trace) (c : Claim) (i : Nat) : Found :=
  let p := s!"/claims/{i}"
  ensure (entailmentKind t c.entailment) (p ++ "/entailment")
    "the entailment fact must have kind entailment" ++
  ensure (!c.needs.contains c.entailment) (p ++ "/needs")
    "the entailment fact is listed as a need" ++
  ensure (t.claims.all fun d => d.entailment != c.entailment || d.id == c.id) (p ++ "/entailment")
    "another claim uses the same entailment fact" ++
  (c.needs.flatMap fun n =>
    ensure (needNotEntailment t n) (p ++ "/needs") s!"\"{n}\" is an entailment fact")

def entail (t : Trace) : Found := t.claims.zipIdx.flatMap fun (c, i) => claimEntail t c i

def needs (t : Trace) : Found :=
  t.claims.zipIdx.flatMap fun (c, i) =>
    ensure (!c.needs.isEmpty) s!"/claims/{i}/needs" "a claim needs at least one fact" ++
    ensure (decide c.needs.Nodup) s!"/claims/{i}/needs" "a fact is listed twice"

def outcomeRoutes (t : Trace) (e : Experiment) (i : Nat) : Found :=
  (e.success ++ e.failure).flatMap fun q =>
    match t.fact? q.1 with
    | some f => ensure (f.route.allows q.2) s!"/experiments/{i}"
        s!"\"{q.1}\" cannot reach {q.2.name} by route {f.route.name}"
    | none => []

def route (t : Trace) : Found :=
  (t.facts.zipIdx.flatMap fun (f, i) =>
    ensure (f.route.allows f.status) s!"/facts/{i}/status"
      s!"{f.status.name} exceeds route {f.route.name}") ++
  (t.experiments.zipIdx.flatMap fun (e, i) => outcomeRoutes t e i) ++
  (t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (x.route.allows x.status) s!"/exclusions/{i}/status"
      s!"{x.status.name} exceeds route {x.route.name}")

def requiresEarlier (earlier : List Experiment) (e : Experiment) (i : Nat) : Found :=
  e.requires.flatMap fun r =>
    ensure (earlier.any fun d => d.id == r && d.subject == e.subject) s!"/experiments/{i}/requires"
      s!"\"{r}\" must be an earlier experiment on subject \"{e.subject}\""

def outcome (t : Trace) : Found :=
  (t.experiments.zipIdx.flatMap fun (e, i) =>
    ensure (!e.success.isEmpty) s!"/experiments/{i}/success"
      "a success asserts at least one fact" ++
    (e.success.flatMap fun q =>
      ensure q.2.asserted s!"/experiments/{i}/success" s!"a success cannot set {q.2.name}") ++
    (e.failure.flatMap fun q =>
      ensure (q.2 == .violated) s!"/experiments/{i}/failure" "a failure sets violated alone")) ++
  (t.experiments.zipIdx.flatMap fun (e, i) => requiresEarlier (t.experiments.take i) e i)

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

def subjectProper (t : Trace) (s : Subject) (i : Nat) : Found :=
  let p := s!"/subjects/{i}"
  ensure ((s.kind == .prospective) == s.createdBy.isSome) p
    "a prospective subject names createdBy; an existing one does not" ++
  (match s.createdBy with
   | some e =>
     match t.experiment? e with
     | some x => ensure (x.subject == s.id) (p ++ "/createdBy")
         s!"experiment \"{e}\" is not on subject \"{s.id}\""
     | none => []
   | none => [])

def prospectiveOpen (t : Trace) (f : Fact) : Bool :=
  match t.subject? f.subject with
  | some s => s.kind != .prospective || f.status == .«open»
  | none => true

def prospective (t : Trace) : Found :=
  (t.subjects.zipIdx.flatMap fun (s, i) => subjectProper t s i) ++
  ensure (t.subjects.any (·.kind == .existing)) "/subjects" "at least one existing subject" ++
  (t.facts.zipIdx.flatMap fun (f, i) =>
    ensure (prospectiveOpen t f) s!"/facts/{i}/status"
      "a fact on a prospective subject records open: its data does not exist yet")

def subjectKind (t : Trace) (id : String) (k : SubjectKind) : Bool :=
  match t.subject? id with
  | some s => s.kind == k
  | none => true

def variant (t : Trace) : Found :=
  t.claims.zipIdx.flatMap fun (c, i) =>
    match c.variantOf with
    | some v =>
      ensure (subjectKind t c.subject .prospective) s!"/claims/{i}/variantOf"
        "a variant claim sits on a prospective subject" ++
      (match t.claim? v with
       | some d => ensure (subjectKind t d.subject .existing) s!"/claims/{i}/variantOf"
           s!"claim \"{v}\" is not on an existing subject"
       | none => [])
    | none => []

def samePair (x y : Exclusion) : Bool :=
  x.subject == y.subject && (x.between == y.between || x.between == y.between.swap)

def exclusion (t : Trace) : Found :=
  (t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (x.between.1 != x.between.2) s!"/exclusions/{i}/between"
      "an exclusion relates two facts") ++
  (t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (!(t.exclusions.take i).any (samePair x)) s!"/exclusions/{i}"
      "the same pair is excluded twice on one subject")

def assertedFact (t : Trace) (id : String) : Bool :=
  match t.fact? id with
  | some f => f.status.asserted
  | none => false

def consistent (t : Trace) : Found :=
  t.exclusions.zipIdx.flatMap fun (x, i) =>
    ensure (!(x.status.asserted && assertedFact t x.between.1 && assertedFact t x.between.2))
      s!"/exclusions/{i}"
      "both facts of this exclusion are recorded as holding: the trace contradicts itself"

def waiver (t : Trace) : Found :=
  (t.waivers.zipIdx.flatMap fun (w, i) =>
    ensure (lintRules.contains w.rule) s!"/waivers/{i}/rule" s!"no lint rule \"{w.rule}\"") ++
  ensure (decide (t.waivers.map fun w => (w.rule, w.claim)).Nodup) "/waivers"
    "a rule is waived twice for one claim"

def kind (t : Trace) : Found :=
  t.facts.zipIdx.flatMap fun (f, i) =>
    ensure ((f.kind == .instantiation) == f.instantiates.isSome) s!"/facts/{i}"
      "an instantiation fact (and only one) names `instantiates`"

def Rule.check : Rule → Trace → Found
  | .ids => Check.ids | .refs => Check.refs | .subject => Check.subject
  | .entail => Check.entail | .needs => Check.needs | .route => Check.route
  | .outcome => Check.outcome | .receipt => Check.receipt | .path => Check.path
  | .prospective => Check.prospective | .variant => Check.variant
  | .exclusion => Check.exclusion | .consistent => Check.consistent | .waiver => Check.waiver
  | .kind => Check.kind

/-- Every broken rule instance, in rule order. -/
def violations (t : Trace) : List Violation :=
  Rule.all.flatMap fun r => (r.check t).map fun (p, m) => { rule := r, path := p, message := m }

end Check
end Fvtrace
