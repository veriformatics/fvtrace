import Fvtrace.Model

/-!
# Engine (contract § Effective status, § Claim state, § Ranking, § Experiments, § Plans)

Pure functions of a scenario = trace + receipt binding + what-if overrides. Every judgment a
surface shows is computed here; `Fvtrace.Spec.Engine` states what they guarantee.
-/

namespace Fvtrace

/-- Effective status: a recorded status, or `stale` (recorded verified, receipt not current). -/
inductive EStatus where
  | proved
  | checked
  | assumed
  | tested
  | «open»
  | violated
  | stale
  deriving DecidableEq, Repr, Inhabited

def EStatus.ofStatus : Status → EStatus
  | .proved => .proved | .checked => .checked | .assumed => .assumed
  | .tested => .tested | .«open» => .«open» | .violated => .violated

/-- violated 0 < open = tested = stale 1 < assumed 2 < checked = proved 3. -/
def EStatus.strength : EStatus → Nat
  | .violated => 0
  | .«open» | .tested | .stale => 1
  | .assumed => 2
  | .checked | .proved => 3

def EStatus.verified (s : EStatus) : Bool := s.strength == 3
def EStatus.asserted (s : EStatus) : Bool := s.strength ≥ 2

def EStatus.name : EStatus → String
  | .stale => "stale"
  | .proved => "proved" | .checked => "checked" | .assumed => "assumed"
  | .tested => "tested" | .«open» => "open" | .violated => "violated"

inductive State where
  | cannot
  | «open»
  | conditional
  | can
  deriving DecidableEq, Repr, Inhabited

def State.rank : State → Nat
  | .cannot => 0 | .«open» => 1 | .conditional => 2 | .can => 3

def State.name : State → String
  | .cannot => "cannot" | .«open» => "open" | .conditional => "conditional" | .can => "can"

/-- What-if overrides: fact id → supposed status, keys sorted + distinct. -/
abbrev Overrides := List (String × Status)

/-- A trace evaluated against receipt bindings (`current`) and what-if overrides. -/
structure Scenario where
  trace : Trace
  /-- Receipt binding of a fact or exclusion id (consulted for recorded verified statuses). -/
  current : String → Bool
  overrides : Overrides := []

namespace Scenario

variable (s : Scenario)

/-- S-bind: a recorded verified status whose receipt is not current reads `stale`. -/
def eff0 (status : Status) (id : String) : EStatus :=
  if status.verified && !s.current id then .stale else .ofStatus status

/-- S-override: a what-if replaces the recorded status (it may lower it). -/
def eff1 (id : String) : EStatus :=
  match s.overrides.lookup id with
  | some st => .ofStatus st
  | none =>
    match s.trace.fact? id with
    | some f => s.eff0 f.status f.id
    | none => .«open»

def exclusionEff (x : Exclusion) : EStatus := s.eff0 x.status x.id

/-- S-exclude witnesses: (exclusion, verified source) pairs that make `id` violated. -/
def derivations (id : String) : List (String × String) :=
  s.trace.exclusions.filterMap fun x =>
    if (s.exclusionEff x).verified && !(s.eff1 id).asserted then
      if x.between.1 == id && (s.eff1 x.between.2).verified then some (x.id, x.between.2)
      else if x.between.2 == id && (s.eff1 x.between.1).verified then some (x.id, x.between.1)
      else none
    else none

/-- The effective status every judgment reads. -/
def eff (id : String) : EStatus :=
  if (s.derivations id).isEmpty then s.eff1 id else .violated

/-- S-conflict: an asserted exclusion whose two sides both read asserted. -/
def active (x : Exclusion) : Bool :=
  (s.exclusionEff x).asserted && (s.eff1 x.between.1).asserted && (s.eff1 x.between.2).asserted

def conflicts (subject : String) : List String :=
  (s.trace.exclusions.filter fun x => x.subject == subject && s.active x).map (·.id)

def valid (subject : String) : Bool := (s.conflicts subject).isEmpty

/-- Asserted exclusions with both sides among the claim's needs: unsatisfiable as written. -/
def incompatible (c : Claim) : List String :=
  (s.trace.exclusions.filter fun x =>
    (s.exclusionEff x).asserted && c.needsAll.contains x.between.1 &&
      c.needsAll.contains x.between.2).map (·.id)

/-- S-state, ignoring the subject's validity. -/
def intrinsic (c : Claim) : State :=
  let sts := c.needsAll.map s.eff
  if sts.any (· == .violated) || !(s.incompatible c).isEmpty then .cannot
  else if sts.all (·.verified) then .can
  else if sts.all (·.asserted) then .conditional
  else .«open»

/-- What a surface shows: a conflicting what-if on the claim's subject makes it cannot. -/
def final (c : Claim) : State := if s.valid c.subject then s.intrinsic c else .cannot

def verifiedNeeds (c : Claim) : List String := c.needsAll.filter fun n => (s.eff n).verified
def premises (c : Claim) : List String := c.needsAll.filter fun n => s.eff n == .assumed
def gaps (c : Claim) : List String :=
  c.needsAll.filter fun n => (s.eff n).strength == 1
def blockers (c : Claim) : List String := c.needsAll.filter fun n => s.eff n == .violated

/-- The same scenario under extra overrides (later keys replace earlier ones). -/
def withOverrides (extra : Overrides) : Scenario :=
  { s with overrides := extra ++ s.overrides.filter fun (k, _) => !extra.any (·.1 == k) }

end Scenario

/-! ## Ranking: where verification pays -/

namespace Scenario

variable (s : Scenario)

def claimsOf : List Claim := s.trace.claims

/-- A fact verification work could still raise (not violated, below its route's ceiling). -/
def closable (f : Fact) : Bool :=
  let e := s.eff f.id
  e != .violated && e.strength < (EStatus.ofStatus f.route.ceiling).strength

def gates (f : Fact) : List String :=
  (s.trace.claims.filter fun c => c.needsAll.contains f.id).map (·.id)

/-- Claims that verifying `f` to its ceiling alone would move from open/cannot to
can/conditional. -/
def unlocks (f : Fact) : List String :=
  let raised := s.withOverrides [(f.id, f.route.ceiling)]
  (s.trace.claims.filter fun c =>
    c.needsAll.contains f.id && (s.final c).rank ≤ 1 && (raised.final c).rank ≥ 2).map (·.id)

structure Work where
  fact : String
  unlocks : List String
  gates : List String
  deriving Repr, BEq

def workKey (w : Work) : Nat × Nat × String := (w.unlocks.length, w.gates.length, w.fact)

/-- `a` before `b`: more unlocks, then more gates, then smaller id. -/
def workBefore (a b : Work) : Bool :=
  a.unlocks.length > b.unlocks.length ||
    (a.unlocks.length == b.unlocks.length &&
      (a.gates.length > b.gates.length || (a.gates.length == b.gates.length && a.fact < b.fact)))

def work : List Work :=
  let ws := (s.trace.facts.filter fun f => s.closable f && !(s.gates f).isEmpty).map fun f =>
    { fact := f.id, unlocks := s.unlocks f, gates := s.gates f }
  ws.mergeSort fun a b => !workBefore b a

/-- Violated facts + the claims they block (reword the claim or gather new data). -/
def blockerFacts : List (String × List String) :=
  (s.trace.facts.filter fun f => s.eff f.id == .violated).map fun f => (f.id, s.gates f)

end Scenario

/-! ## Experiments -/

/-- The stronger of two statuses (the first on a tie). -/
def Status.stronger (a b : Status) : Status :=
  if (EStatus.ofStatus b).strength > (EStatus.ofStatus a).strength then b else a

namespace Scenario

variable (s : Scenario)

/-- One closure step: each member's `requires` + the creator of its subject when prospective. -/
def closureStep (ids : List String) : List String :=
  ids ++ ids.flatMap fun id =>
    match s.trace.experiment? id with
    | some e => e.requires ++
        (match s.trace.subject? e.subject with
         | some sub => sub.createdBy.toList
         | none => [])
    | none => []

def closureFuel : Nat → List String → List String
  | 0, ids => ids
  | n + 1, ids => closureFuel n (closureStep s ids)

/-- The least prerequisite-closed set containing `ids`, in trace order (a fixed point: every
experiment enters within `experiments.length` steps). -/
def closure (ids : List String) : List String :=
  let all := closureFuel s (s.trace.experiments.length + 1) ids
  s.trace.experimentIds.filter all.contains

/-- The success outcomes the experiments `ids` name, in order. -/
def successPairs (ids : List String) : List (String × Status) :=
  ids.flatMap fun id => ((s.trace.experiment? id).map (·.success)).getD []

/-- Per fact, the strongest value any success in `ids` sets (successes only assert). -/
def merged (ids : List String) : List (String × Status) :=
  let pairs := s.successPairs ids
  (pairs.map (·.1)).eraseDups.map fun k =>
    (k, ((pairs.filter (·.1 == k)).map (·.2)).foldl Status.stronger .assumed)

/-- Success of `ids` (closed): raises each touched fact to the merged value, never lowering it. -/
def applySuccess (ids : List String) : Scenario :=
  s.withOverrides ((s.merged ids).filter fun (k, st) =>
    (EStatus.ofStatus st).strength > (s.eff1 k).strength)

def applyFailure (e : Experiment) : Scenario :=
  s.withOverrides (e.failure.map fun (k, _) => (k, .violated))

structure Move where
  claim : String
  before : State
  after : State
  deriving Repr, BEq

def moves (after : Scenario) : List Move :=
  s.trace.claims.filterMap fun c =>
    let a := s.final c
    let b := after.final c
    if a != b then some { claim := c.id, before := a, after := b } else none

def lights (ms : List Move) : Nat :=
  (ms.filter fun m => m.after.rank ≥ 2 && m.after.rank > m.before.rank).length
def clears (ms : List Move) : Nat :=
  (ms.filter fun m => m.before == .cannot && m.after == .«open»).length
def breaks (ms : List Move) : Nat := (ms.filter fun m => m.after == .cannot).length

def resultFacts : List String := (s.trace.facts.filter (·.kind == .result)).map (·.id)

end Scenario

/-! ## Plans -/

/-- Effort counts, months first: a cheaper plan is lexicographically smaller. -/
def costOf (t : Trace) (ids : List String) : List Nat :=
  let efforts := ids.filterMap fun id => (t.experiment? id).map (·.effort)
  [Effort.months, .weeks, .days, .hours].map fun e => (efforts.filter (· == e)).length

def lexLt : List Nat → List Nat → Bool
  | [], [] => false
  | [], _ :: _ => true
  | _ :: _, [] => false
  | a :: as, b :: bs => a < b || (a == b && lexLt as bs)

def idsLt : List String → List String → Bool
  | [], [] => false
  | [], _ :: _ => true
  | _ :: _, [] => false
  | a :: as, b :: bs => a < b || (a == b && idsLt as bs)

def sublists {α : Type} : List α → List (List α)
  | [] => [[]]
  | x :: xs => let r := sublists xs; r ++ r.map (x :: ·)

/-- Plan search stops claiming an optimum above this many relevant experiments. -/
def maxRelevant : Nat := 20

structure Alternative where
  need : String
  experiment : String
  status : Status
  deriving Repr, BEq

structure Coverage where
  premises : List String
  gaps : List String
  /-- Needs no relevant experiment raises (route hint: a ruling or a new method). -/
  uncovered : List String
  alternatives : List Alternative
  deriving Repr, BEq

inductive PlanResult where
  | inconsistent (coverage : Coverage)
  | tooLarge (coverage : Coverage)
  | noImprovement (coverage : Coverage)
  | planned (coverage : Coverage) (experiments : List String) (state : State)
      (premises : List String) (gaps : List String) (contingent : Bool)
  deriving Repr, BEq

namespace Scenario

variable (s : Scenario)

/-- Experiments on the claim's subject whose success raises a need above its current status. -/
def relevant (c : Claim) : List Experiment :=
  s.trace.experiments.filter fun e =>
    e.subject == c.subject && e.success.any fun (k, st) =>
      c.needsAll.contains k && (EStatus.ofStatus st).strength > (s.eff1 k).strength

def coverage (c : Claim) : Coverage :=
  let rel := s.relevant c
  let unverified := c.needsAll.filter fun n => !(s.eff n).verified
  let alternatives := unverified.flatMap fun n => rel.filterMap fun e =>
    match e.success.lookup n with
    | some st => if (EStatus.ofStatus st).strength > (s.eff1 n).strength then
        some { need := n, experiment := e.id, status := st } else none
    | none => none
  { premises := s.premises c, gaps := s.gaps c,
    uncovered := unverified.filter fun n => !alternatives.any (·.need == n),
    alternatives }

/-- `a` beats `b`: higher final rank, then cheaper, then smaller ids. -/
def planBetter (c : Claim) (a b : List String) : Bool :=
  let ra := ((s.applySuccess a).final c).rank
  let rb := ((s.applySuccess b).final c).rank
  ra > rb || (ra == rb && (lexLt (costOf s.trace a) (costOf s.trace b) ||
    (costOf s.trace a == costOf s.trace b && idsLt a b)))

/-- Closed candidates (closures of subsets of the relevant experiments) that stay consistent. -/
def candidates (c : Claim) : List (List String) :=
  ((sublists ((s.relevant c).map (·.id))).map s.closure).filter fun p =>
    (s.applySuccess p).valid c.subject

def best (c : Claim) : List String :=
  (s.candidates c).foldl (fun acc p => if s.planBetter c p acc then p else acc) []

def plan (c : Claim) : PlanResult :=
  let cov := s.coverage c
  if !s.valid c.subject then .inconsistent cov
  else if (s.relevant c).length > maxRelevant then .tooLarge cov
  else
    let p := s.best c
    let after := s.applySuccess p
    if (after.final c).rank ≤ (s.final c).rank then .noImprovement cov
    else .planned cov p (after.final c) (after.premises c) (after.gaps c)
      (p.any fun id => ((s.trace.experiment? id).map fun e =>
        e.success.any fun (k, _) => s.resultFacts.contains k).getD false)

end Scenario

/-! ## What-if input -/

/-- S-override validity: each key names a fact, once, with a status its route allows. -/
def Overrides.valid (t : Trace) (o : Overrides) : Bool :=
  (o.map (·.1)).Nodup && o.all fun (k, st) => (t.fact? k).any fun f => f.route.allows st

/-- Keys in ascending order (one normalized form per what-if). -/
def Overrides.normalize (o : Overrides) : Overrides := o.mergeSort fun a b => a.1 ≤ b.1

/-- `O1=proved,O3=assumed` → validated, normalized overrides; never clamped or dropped. -/
def Overrides.parse (t : Trace) (spec : String) : Except String Overrides := do
  let entries := (spec.splitOn ",").filter (!·.isEmpty)
  let mut out : Overrides := []
  for e in entries do
    match e.splitOn "=" with
    | [k, v] =>
      let some st := Status.all.find? (·.name == v)
        | throw s!"unknown status \"{v}\" in --whatif"
      let some f := t.fact? k | throw s!"no fact \"{k}\" in --whatif"
      unless f.route.allows st do
        throw s!"{k} cannot reach {v} by route {f.route.name}"
      if out.any (·.1 == k) then throw s!"{k} appears twice in --whatif"
      out := out ++ [(k, st)]
    | _ => throw s!"--whatif entries read FACT=STATUS, got \"{e}\""
  return Overrides.normalize out

end Fvtrace
