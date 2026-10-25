import Fvtrace.Answers.Delta
import Fvtrace.PTree

/-!
# Prerequisite forest (`.agent/contracts/kernel.md` P-forest)

An experiment's closure is the path from it up to its root when its prerequisites (`Ctx.adds`:
`requires` + its subject's creator) chain in trace order: each one's parent = its latest
prerequisite, listed before it, with every other prerequisite on the parent's path. A closure then
reads off parent links, and a success applies once on top of its parent's. Anything else (longer
cycles, forward or incomparable prerequisites, repeated experiment ids) takes the on-demand path:
a walk from a blank array of marks.
-/

namespace Fvtrace.Answers

/-- Parent links over experiment positions: `parent[i]` = position `i`'s parent; `good[i]` =
position `i` is on the forest (a root: no prerequisite but itself). -/
structure Forest where
  parent : Array (Option Nat)
  good : Array Bool

/-- `q` lies on the path from `p` up its parent links. A parent sits before its child, so the walk
stops once it passes `q`. -/
def onPath (parent : Array (Option Nat)) : Nat → Nat → Nat → Bool
  | 0, _, _ => false
  | fuel + 1, p, q =>
    p == q || (q < p && match parent[p]? with
      | some (some r) => onPath parent fuel r q
      | _ => false)

/-- The positions from `p` up to its root, root first, ahead of `acc`. -/
def pathUp (parent : Array (Option Nat)) : Nat → Nat → List Nat → List Nat
  | 0, _, acc => acc
  | fuel + 1, p, acc =>
    match parent[p]? with
    | some (some r) => pathUp parent fuel r (p :: acc)
    | _ => p :: acc

/-- One position's link from the links before it: its prerequisites' positions (itself dropped: a
creator of its own subject adds nothing new), the latest = its parent when that one is on the
forest + every other one lies on its path. -/
def Forest.link (cx : Ctx) (st : Array (Option Nat) × Array Bool) (e : Experiment) :
    Array (Option Nat) × Array Bool :=
  let i := st.1.size
  let deps := ((cx.adds e.id).filterMap cx.firstPos).filter (· != i)
  match deps.max? with
  | none => (st.1.push none, st.2.push true)
  | some p =>
    if p < i && st.2[p]?.getD false && deps.all (onPath st.1 (i + 1) p ·) then
      (st.1.push (some p), st.2.push true)
    else (st.1.push none, st.2.push false)

/-- The forest, in trace order; none of it when two experiments share an id (a position would no
longer name one experiment). -/
def Forest.build (cx : Ctx) : Forest :=
  let st := if cx.L.nodup (cx.experiments.toList.map (·.id)) then
      cx.experiments.foldl (Forest.link cx) (#[], #[])
    else (cx.experiments.map fun _ => none, cx.experiments.map fun _ => false)
  { parent := st.1, good := st.2 }

/-- Position `p`'s closure as ascending positions, when `p` is on the forest. -/
def Forest.path? (fo : Forest) (p : Nat) : Option (List Nat) :=
  if fo.good[p]?.getD false then some (pathUp fo.parent (p + 1) p []) else none

/-- `Scenario.closure`: per id, a forest experiment's path or a walk from a blank array of marks;
the union, in trace order. -/
def Ctx.closureWith (cx : Ctx) (fo : Forest) (ids : List String) : List String :=
  (ascending (ids.flatMap fun id => match cx.firstPos id with
    | some p => match fo.path? p with
      | some ps => ps
      | none => cx.positions (cx.reach (Array.replicate cx.experiments.size false) [id]).2
    | none => [])).filterMap fun p => (cx.experiments[p]?).map (·.id)

/-! ## Which experiments raise a fact -/

/-- `e`'s success raises `f` over the base on its own (the merged `.assumed` floor included). -/
def raisesOwn (core : Core) (f : String) (e : Experiment) : Bool :=
  e.success.any fun x => x.1 == f && max 2 (EStatus.ofStatus x.2).strength > (core.eff1 f).strength

/-- One position of `pathRaises`: itself, or its parent's entry. -/
def pathRaisesStep (core : Core) (fo : Forest) (f : String) (acc : Array Bool)
    (e : Experiment) : Array Bool :=
  acc.push (raisesOwn core f e || match fo.parent[acc.size]? with
    | some (some p) => acc[p]?.getD false
    | _ => false)

/-- Per position: some experiment on its forest path raises `f` on its own. -/
def pathRaises (cx : Ctx) (core : Core) (fo : Forest) (f : String) : Array Bool :=
  cx.experiments.foldl (pathRaisesStep core fo f) #[]

/-- The experiments of `order` whose success closure raises `f` (`kernel.md` P-raisers): a forest
experiment's when one on its path raises `f` on its own, any other's from its closure. -/
def raisersWith (cx : Ctx) (core : Core) (fo : Forest) (closure : List String → List String)
    (order : List Experiment) (f : String) : List String :=
  let reach := pathRaises cx core fo f
  let viaClosure := fun (e : Experiment) => (raisedBy cx core (closure [e.id])).any (·.1 == f)
  (order.filter fun e => match cx.firstPos e.id with
    | some j => if fo.good[j]?.getD false then reach[j]?.getD false else viaClosure e
    | none => viaClosure e).map (·.id)

/-! ## The walk: each forest experiment's success on top of its parent's -/

/-- The forest's preconditions on the facts the walk keeps per position: every success key + both
ends of every exclusion name a fact, every exclusion's subject is declared. Outside them every
experiment takes the on-demand path. -/
def Ctx.dense (cx : Ctx) : Bool :=
  cx.experiments.all (fun e => e.success.all fun x => cx.L.hasFact x.1) &&
    cx.exclusions.all fun x =>
      cx.L.hasFact x.between.1 && cx.L.hasFact x.between.2 && cx.L.hasSubject x.subject

/-- One node's scenario (`s.applySuccess` of its closure) as overlays on the base (none = the
base's value): `eff1`, `eff` + `cell` (the closure's merged success) per fact position, `act`
(active exclusions) per subject position, `cnt` (counts) per claim position; then its row against
the base: how many claims it lights, clears, lowers; how many merged keys the what-if does not hold
exactly (`applied` ⇔ none); whether a merged key is a `result` fact. -/
structure Node where
  eff1 : PTree (Option EStatus)
  eff : PTree (Option EStatus)
  cell : PTree (Option Status)
  act : PTree (Option Nat)
  cnt : PTree (Option Counts)
  lights : Nat
  clears : Nat
  lowers : Nat
  bad : Nat
  contingent : Bool

/-- The base scenario itself (the empty closure). -/
def Node.root (cx : Ctx) : Node :=
  let facts := PTree.depthFor cx.facts.size
  { eff1 := .const none facts, eff := .const none facts, cell := .const none facts
    act := .const none (PTree.depthFor cx.subjects.size)
    cnt := .const none (PTree.depthFor cx.claims.size)
    lights := 0, clears := 0, lowers := 0, bad := 0, contingent := false }

/-- The node's scenario as a `Core` over the base `core` (what `Delta.build` + `Delta.final`
read: `eff1`, `eff`, `active`, `activeCount`; the other fields are the base's, unread). -/
def Node.core (cx : Ctx) (s : Scenario) (core : Core) (nd : Node) : Core :=
  let eff1 := fun id => match cx.factIx.first? (cmp := compare) id with
    | some j => match nd.eff1.get j with
      | some e => e
      | none => core.eff1 id
    | none => core.eff1 id
  { override? := core.override?, eff1, derivations := core.derivations
    eff := fun id => match cx.factIx.first? (cmp := compare) id with
      | some j => match nd.eff.get j with
        | some e => e
        | none => core.eff id
      | none => core.eff id
    active := activeWith s eff1
    conflicts := core.conflicts
    activeCount := fun sub => match cx.subjectIx.first? (cmp := compare) sub with
      | some u => match nd.act.get u with
        | some k => k
        | none => core.activeCount sub
      | none => core.activeCount sub }

/-- A claim's counts at the node (the base's where the node changed none). -/
def Node.countsAt (nd : Node) (memo : Array ClaimMemo) (q : Nat) : Counts :=
  match nd.cnt.get q with
  | some k => k
  | none => ((memo[q]?).map (·.counts)).getD ⟨0, 0, 0⟩

/-- `Scenario.lights` / `clears` / `lowers` on one claim moving from `b` (the base) to `a` (a claim
that stays put meets none). -/
def lightsTo (b a : State) : Bool := a.rank ≥ 2 && a.rank > b.rank
def clearsTo (b a : State) : Bool := b == .cannot && a == .«open»
def lowersTo (b a : State) : Bool := a.rank < b.rank

/-- One claim the step may move: its position, base state, state at the node, counts + state after
the step. -/
structure Recount where
  pos : Nat
  base : State
  before : State
  counts : Counts
  after : State

/-- One node's row + the states of the claims attached to it. -/
structure StepOut where
  lights : Nat
  clears : Nat
  lowers : Nat
  applied : Bool
  contingent : Bool
  answers : List (Nat × State)
  node : Node

/-- One success entry joins its key's merged value (`e` comes last in trace order); the count of
merged keys the what-if does not hold exactly follows. -/
def Node.mergeEntry (cx : Ctx) (core : Core) (acc : PTree (Option Status) × Nat)
    (x : String × Status) : PTree (Option Status) × Nat :=
  let mis := fun (st : Status) => if core.override? x.1 == some st then 0 else 1
  match cx.factIx.first? (cmp := compare) x.1 with
  | some j =>
    let new := ((acc.1.get j).getD .assumed).stronger x.2
    (acc.1.set j (some new), match acc.1.get j with
      | some old => acc.2 - mis old + mis new
      | none => acc.2 + mis new)
  | none => acc

/-- The merged success after `e`'s entries + how many merged keys the what-if does not hold
exactly. -/
def Node.merge (cx : Ctx) (core : Core) (e : Experiment) (cell : PTree (Option Status))
    (bad : Nat) : PTree (Option Status) × Nat :=
  e.success.foldl (Node.mergeEntry cx core) (cell, bad)

/-- Writes `v k` at each key's position. -/
def setAt {α : Type} (pos : String → Option Nat) (keys : List String) (v : String → α)
    (t : PTree (Option α)) : PTree (Option α) :=
  keys.foldl (fun t k => match pos k with
    | some j => t.set j (some (v k))
    | none => t) t

/-- The subjects of the exclusions at `δ`'s keys, each once. -/
def touchedSubjects (cx : Ctx) (δ : Delta) : List String :=
  Index.eraseDups compare (δ.touched.filterMap fun p => (cx.exclusions[p]?).map (·.subject))

/-- The claim positions `δ` (on a node whose core is `base`) can move: needing a changed fact, or on
a subject whose validity flips. -/
def movable (cx : Ctx) (base : Core) (δ : Delta) : List Nat :=
  ascending (δ.changed.flatMap (cx.gates.group (cmp := compare) ·) ++
    ((touchedSubjects cx δ).filter fun sub => δ.valid sub != (base.activeCount sub == 0)).flatMap
      (cx.claimSubject.group (cmp := compare) ·))

/-- Claim `q` at node `nd` (core `base`) + after `δ`. -/
def Node.recount (cx : Ctx) (memo : Array ClaimMemo) (nd : Node) (base : Core) (δ : Delta)
    (q : Nat) : Option Recount :=
  match cx.claims[q]?, memo[q]? with
  | some c, some m =>
    let k := nd.countsAt memo q
    let k' := Delta.counts cx base δ m.needs m.needsCount k (cx.needs · q)
    some { pos := q, base := m.final, counts := k'
           before := if base.activeCount c.subject == 0 then k.state m.incompatible else .cannot
           after := if δ.valid c.subject then k'.state m.incompatible else .cannot }
  | _, _ => none

/-- The overrides `e`'s success raises over the base, its keys at their merged values `cell`. -/
def stepExtra (cx : Ctx) (core : Core) (cell : PTree (Option Status)) (e : Experiment) :
    Overrides :=
  e.success.filterMap fun x =>
    match cx.factIx.first? (cmp := compare) x.1 with
    | some j => (cell.get j).bind fun m =>
      if (EStatus.ofStatus m).strength > (core.eff1 x.1).strength then some (x.1, m) else none
    | none => none

/-- `e`'s success on top of node `nd` (`kernel.md` P-forest): the merged success per key, the
overrides it raises over the base, one delta on the node's scenario, the claims it can move
re-tallied against the base, the overlays patched. -/
def Node.step (cx : Ctx) (s : Scenario) (core : Core) (memo : Array ClaimMemo) (nd : Node)
    (e : Experiment) (attached : List Nat) : StepOut :=
  let merge := Node.merge cx core e nd.cell nd.bad
  let base := nd.core cx s core
  let δ := Delta.build cx s base (stepExtra cx core merge.1 e)
  let moved := (movable cx base δ).filterMap (nd.recount cx memo base δ)
  let tally := fun (n : Nat) (f : State → State → Bool) =>
    n + moved.countP (fun r => f r.base r.after) - moved.countP (fun r => f r.base r.before)
  let lights := tally nd.lights lightsTo
  let clears := tally nd.clears clearsTo
  let lowers := tally nd.lowers lowersTo
  let contingent := nd.contingent || e.success.any fun x => cx.isResult x.1
  { lights, clears, lowers, applied := merge.2 == 0, contingent
    answers := attached.filterMap fun q => (nd.recount cx memo base δ q).map fun r => (q, r.after)
    node :=
      { eff1 := setAt (cx.factIx.first? (cmp := compare)) δ.keys δ.eff1 nd.eff1
        eff := setAt (cx.factIx.first? (cmp := compare)) δ.changed δ.eff nd.eff
        cell := merge.1
        act := setAt (cx.subjectIx.first? (cmp := compare)) (touchedSubjects cx δ) δ.activeCount
          nd.act
        cnt := moved.foldl (fun t r => t.set r.pos (some r.counts)) nd.cnt
        lights, clears, lowers, bad := merge.2, contingent } }

/-- `Scenario.relevant c`'s positions (`planOf`'s): success entries raising a need, on the claim's
subject. -/
def relevantPositions (cx : Ctx) (core : Core) (needs : List String) (subject : String) :
    List Nat :=
  (raisingPositions cx core needs).filter fun p => (cx.experiments[p]?).any (·.subject == subject)

/-- The claim positions whose plan a forest position answers: subject consistent, that position
their one relevant experiment. -/
def attachments (cx : Ctx) (core : Core) (fo : Forest) (memo : Array ClaimMemo) :
    Array (List Nat) :=
  (cx.claims.foldl (init := (Array.replicate cx.experiments.size ([] : List Nat), 0)) fun acc c =>
    let q := acc.2
    let next := match memo[q]? with
      | some m =>
        if core.valid c.subject then
          match relevantPositions cx core m.needs c.subject with
          | [r] => if fo.good[r]?.getD false then acc.1.modify r (q :: ·) else acc.1
          | _ => acc.1
        else acc.1
      | none => acc.1
    (next, q + 1)).1

/-- The plan summaries no search decides, by claim position: an inconsistent subject, more relevant
experiments than a search takes, or none at all. -/
def presummaries (cx : Ctx) (core : Core) (memo : Array ClaimMemo) : Array (Option PlanSummary) :=
  (cx.claims.foldl (init := ((#[] : Array (Option PlanSummary)), 0)) fun acc c =>
    let q := acc.2
    (acc.1.push (match memo[q]? with
      | some m =>
        if !core.valid c.subject then some .inconsistent
        else match relevantPositions cx core m.needs c.subject with
          | [] => some .noImprovement
          | rel => if rel.length > maxRelevant then some .tooLarge else none
      | none => none), q + 1)).1

/-- Positions with a child on the forest (their state is kept for it). -/
def Forest.hasChild (fo : Forest) : Array Bool :=
  fo.parent.foldl (init := Array.replicate fo.parent.size false) fun acc p => match p with
    | some r => acc.set! r true
    | none => acc

/-- What every step of the walk reads. -/
structure WalkEnv where
  cx : Ctx
  s : Scenario
  core : Core
  memo : Array ClaimMemo
  fo : Forest
  /-- A row from the experiment's closure on demand (outside the forest). -/
  fallback : Experiment → ExperimentRow
  failureMoves : Experiment → List Scenario.Move
  dense : Bool
  attached : Array (List Nat)
  hasChild : Array Bool

/-- The walk after some positions: each one's node (kept for its children), each row, each
attached claim's plan summary. -/
abbrev WalkState := Array (Option Node) × Array ExperimentRow × Array (Option PlanSummary)

/-- One position: on the forest, its success on top of its parent's node (the root's when it has
none); elsewhere, the fallback row. -/
def walkStep (w : WalkEnv) (acc : WalkState) (e : Experiment) : WalkState :=
  let i := acc.2.1.size
  let parent? : Option Node := if w.dense && w.fo.good[i]?.getD false then
      match w.fo.parent[i]? with
      | some (some p) => (acc.1[p]?).bind id
      | _ => some (Node.root w.cx)
    else none
  match parent? with
  | some nd =>
    let out := nd.step w.cx w.s w.core w.memo e (w.attached[i]?.getD [])
    let row : ExperimentRow :=
      { experiment := e, lights := out.lights, clears := out.clears, lowers := out.lowers
        breaks := Scenario.breaks (if e.failure.isEmpty then [] else w.failureMoves e)
        applied := out.applied, contingent := out.contingent }
    let plans := out.answers.foldl (init := acc.2.2) fun ps x =>
      let b := ((w.memo[x.1]?).map (·.final)).getD .cannot
      ps.set! x.1 (some (if x.2.rank > b.rank then .planned x.2 else .noImprovement))
    (acc.1.push (if w.hasChild[i]?.getD false then some out.node else none), acc.2.1.push row,
      plans)
  | none => (acc.1.push none, acc.2.1.push (w.fallback e), acc.2.2)

/-- Every experiment's row in trace order + each attached claim's plan summary by position: a
forest experiment from its node, any other one from `fallback` (its closure on demand). -/
def walk (cx : Ctx) (s : Scenario) (core : Core) (memo : Array ClaimMemo) (fo : Forest)
    (fallback : Experiment → ExperimentRow) (failureMoves : Experiment → List Scenario.Move) :
    Array ExperimentRow × Array (Option PlanSummary) :=
  let dense := cx.dense
  let w : WalkEnv := { cx, s, core, memo, fo, fallback, failureMoves, dense
                       attached := if dense then attachments cx core fo memo else #[]
                       hasChild := fo.hasChild }
  let st := cx.experiments.foldl (walkStep w) (#[], #[], presummaries cx core memo)
  (st.2.1, st.2.2)

end Fvtrace.Answers
