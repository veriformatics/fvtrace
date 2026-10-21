/-!
# Trace model

The decoded form of a trace (`.agent/contracts/kernel.md` § Model). Collections are lists: the
kernel's proofs reason over `List` lemmas, and traces are small.
-/

namespace Fvtrace

/-- Recorded status of a fact. `proved` + `checked` count as verified. -/
inductive Status where
  | proved
  | checked
  | assumed
  | tested
  | «open»
  | violated
  deriving DecidableEq, Repr, Inhabited, Hashable

/-- How a fact could be verified; bounds the status it may reach. -/
inductive Route where
  | lean
  | runtimeChecker
  | refinement
  | humanRuling
  | empirical
  deriving DecidableEq, Repr, Inhabited

inductive Kind where
  | entailment
  | result
  | estimand
  | statistical
  | numerical
  | implementation
  | dataflow
  | provenance
  | interpretation
  | release
  | specReview
  | instantiation
  deriving DecidableEq, Repr, Inhabited

inductive Level where
  | estimand
  | descriptive
  | inferential
  | causal
  | release
  deriving DecidableEq, Repr, Inhabited

inductive Effort where
  | hours
  | days
  | weeks
  | months
  deriving DecidableEq, Repr, Inhabited

inductive ExpKind where
  | dry
  | wet
  deriving DecidableEq, Repr, Inhabited

inductive SubjectKind where
  | existing
  | prospective
  deriving DecidableEq, Repr, Inhabited

structure Analysis where
  id : String
  title : String
  summary : String
  source : Option String := none
  deriving DecidableEq, Repr, Inhabited

structure Subject where
  id : String
  title : String
  kind : SubjectKind
  createdBy : Option String := none
  deriving DecidableEq, Repr, Inhabited

structure Question where
  id : String
  title : String
  text : String
  deriving DecidableEq, Repr, Inhabited

structure Artifact where
  path : String
  sha256 : Option String := none
  role : Option String := none
  deriving DecidableEq, Repr, Inhabited

structure Evidence where
  summary : String
  artifacts : List Artifact := []
  verifier : Option String := none
  statement : Option String := none
  statementDigest : Option String := none
  deriving DecidableEq, Repr, Inhabited

structure Fact where
  id : String
  subject : String
  kind : Kind
  text : String
  status : Status
  route : Route
  evidence : Option Evidence := none
  trusts : List String := []
  instantiates : Option String := none
  deriving DecidableEq, Repr, Inhabited

structure Claim where
  id : String
  question : String
  subject : String
  level : Level
  text : String
  needs : List String
  entailment : String
  latent : Bool := false
  variantOf : Option String := none
  deriving DecidableEq, Repr, Inhabited

/-- `needs ++ [entailment]`: everything the claim's state depends on. -/
def Claim.needsAll (c : Claim) : List String := c.needs ++ [c.entailment]

structure Experiment where
  id : String
  subject : String
  kind : ExpKind
  effort : Effort
  title : String
  method : String
  resources : String
  success : List (String × Status)
  failure : List (String × Status) := []
  requires : List String := []
  caveat : String
  deriving DecidableEq, Repr, Inhabited

structure Exclusion where
  id : String
  subject : String
  between : String × String
  text : String
  status : Status
  route : Route
  evidence : Option Evidence := none
  deriving DecidableEq, Repr, Inhabited

structure Waiver where
  rule : String
  claim : String
  reason : String
  deriving DecidableEq, Repr, Inhabited

structure Review where
  reviewer : String
  date : String
  digest : String
  note : Option String := none
  deriving DecidableEq, Repr, Inhabited

structure Trace where
  analysis : Analysis
  subjects : List Subject
  questions : List Question
  facts : List Fact
  claims : List Claim
  experiments : List Experiment := []
  exclusions : List Exclusion := []
  waivers : List Waiver := []
  review : Option Review := none
  deriving DecidableEq, Repr, Inhabited

/-! ## Wire names (the JSON strings each constructor reads and writes) -/

def Status.name : Status → String
  | .proved => "proved" | .checked => "checked" | .assumed => "assumed"
  | .tested => "tested" | .«open» => "open" | .violated => "violated"

def Route.name : Route → String
  | .lean => "lean" | .runtimeChecker => "runtime-checker" | .refinement => "refinement"
  | .humanRuling => "human-ruling" | .empirical => "empirical"

def Kind.name : Kind → String
  | .entailment => "entailment" | .result => "result" | .estimand => "estimand"
  | .statistical => "statistical" | .numerical => "numerical"
  | .implementation => "implementation" | .dataflow => "dataflow"
  | .provenance => "provenance" | .interpretation => "interpretation" | .release => "release"
  | .specReview => "spec-review" | .instantiation => "instantiation"

def Level.name : Level → String
  | .estimand => "estimand" | .descriptive => "descriptive" | .inferential => "inferential"
  | .causal => "causal" | .release => "release"

def Effort.name : Effort → String
  | .hours => "hours" | .days => "days" | .weeks => "weeks" | .months => "months"

def ExpKind.name : ExpKind → String
  | .dry => "dry" | .wet => "wet"

def SubjectKind.name : SubjectKind → String
  | .existing => "existing" | .prospective => "prospective"

def Status.all : List Status := [.proved, .checked, .assumed, .tested, .«open», .violated]
def Route.all : List Route := [.lean, .runtimeChecker, .refinement, .humanRuling, .empirical]
def Kind.all : List Kind :=
  [.entailment, .result, .estimand, .statistical, .numerical, .implementation, .dataflow,
   .provenance, .interpretation, .release, .specReview, .instantiation]
def Level.all : List Level := [.estimand, .descriptive, .inferential, .causal, .release]
def Effort.all : List Effort := [.hours, .days, .weeks, .months]
def ExpKind.all : List ExpKind := [.dry, .wet]
def SubjectKind.all : List SubjectKind := [.existing, .prospective]

end Fvtrace

namespace Fvtrace

/-! ## Status + route semantics shared by the spec and the engine -/

/-- `proved` + `checked` = verified (contract § Model). -/
def Status.verified : Status → Bool
  | .proved | .checked => true
  | _ => false

/-- Verified or a declared premise. -/
def Status.asserted : Status → Bool
  | .proved | .checked | .assumed => true
  | _ => false

/-- The strongest status a route can reach. -/
def Route.ceiling : Route → Status
  | .lean | .refinement => .proved
  | .runtimeChecker => .checked
  | .humanRuling | .empirical => .assumed

/-- `proved` needs `lean` | `refinement`, `checked` needs `runtime-checker`; every route may
record `open`, `tested`, `violated` or `assumed`. -/
def Route.allows (r : Route) (s : Status) : Bool :=
  match s with
  | .«open» | .tested | .violated | .assumed => true
  | .proved | .checked => s == r.ceiling

/-- Kinds a claim may never assume (user ruling): its reasoning, results, measurements,
calculations, code + data flow. Every other kind is a background condition. -/
def Kind.mustVerify : Kind → Bool
  | .entailment | .result | .estimand | .numerical | .implementation | .dataflow => true
  | _ => false

/-- A status the fact may hold (recorded, in an outcome or a what-if): its route allows it, and a
must-verify fact is never `assumed`. -/
def Fact.allows (f : Fact) (s : Status) : Bool :=
  f.route.allows s && (s != .assumed || !f.kind.mustVerify)

/-- The strongest status the fact may reach: its route's ceiling, or `tested` where that ceiling is
`assumed` and the fact must be verified. -/
def Fact.ceiling (f : Fact) : Status :=
  if f.kind.mustVerify && f.route.ceiling == .assumed then .tested else f.route.ceiling

/-! ## Lookups -/

namespace Trace

def subjectIds (t : Trace) : List String := t.subjects.map (·.id)
def questionIds (t : Trace) : List String := t.questions.map (·.id)
def factIds (t : Trace) : List String := t.facts.map (·.id)
def claimIds (t : Trace) : List String := t.claims.map (·.id)
def experimentIds (t : Trace) : List String := t.experiments.map (·.id)
def exclusionIds (t : Trace) : List String := t.exclusions.map (·.id)

/-- Every id the trace declares, in one namespace. -/
def allIds (t : Trace) : List String :=
  t.subjectIds ++ t.questionIds ++ t.factIds ++ t.claimIds ++ t.experimentIds ++ t.exclusionIds

def fact? (t : Trace) (id : String) : Option Fact := t.facts.find? (·.id == id)
def subject? (t : Trace) (id : String) : Option Subject := t.subjects.find? (·.id == id)
def claim? (t : Trace) (id : String) : Option Claim := t.claims.find? (·.id == id)
def experiment? (t : Trace) (id : String) : Option Experiment := t.experiments.find? (·.id == id)

/-- The subject a fact id lives on, when it resolves. -/
def factSubject? (t : Trace) (id : String) : Option String := (t.fact? id).map (·.subject)

end Trace

end Fvtrace
