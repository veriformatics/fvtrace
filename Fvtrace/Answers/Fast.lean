import Fvtrace.Answers

/-!
# Fast answers (`.agent/contracts/kernel.md` P-delta)

`Answers.fast s` = the answers of `Answers.reference s`, read from sorted indexes (`Fvtrace.Index`)
+ memos instead of list scans. `Fvtrace.Proofs.Answers` proves the two records equal for every
scenario (`Spec.AnswersAgree`).

- `Ctx`: one trace, indexed once (facts, exclusions by endpoint / subject / first endpoint, claims
  by need / subject, success entries by fact, experiments by id).
- `Core`: one scenario's effective statuses + subject validity, memoized per fact + per subject.
- `Delta`: a what-if `extra` on top of the scenario. It changes `eff1` on its keys alone, `eff` on
  its keys + their exclusion partners alone (`changed`), validity only through the exclusions at
  its keys (`touched`); a claim's final state follows from per-claim counts patched over
  `changed`. Unlocks, experiment moves + plan nodes read deltas, never a fresh scenario.
-/

namespace Fvtrace.Answers

attribute [local instance] lexOrd

/-! ## Positions -/

/-- `l` without adjacent repeats (for a sorted list: without repeats). -/
def dedupSorted (l : List Nat) : List Nat :=
  (l.foldl (init := ((#[] : Array Nat), (none : Option Nat))) fun (acc, last) p =>
    if last == some p then (acc, last) else (acc.push p, some p)).1.toList

/-- The positions in increasing order, each once. -/
def ascending (l : List Nat) : List Nat := dedupSorted (l.mergeSort (· ≤ ·))

/-! ## The trace, indexed once -/

structure Ctx where
  L : Lookups
  facts : Array Fact
  subjects : Array Subject
  claims : Array Claim
  experiments : Array Experiment
  exclusions : Array Exclusion
  factIx : Index String
  subjectIx : Index String
  /-- Exclusion positions by endpoint (an exclusion of a fact with itself: once). -/
  exclAt : Index String
  exclSubject : Index String
  exclFirst : Index String
  /-- Claim positions by each fact of `needsAll` (once per occurrence). -/
  gates : Index String
  /-- (fact, claim position) by each occurrence in the claim's `needsAll`. -/
  needCount : Index (String × Nat)
  claimSubject : Index String
  /-- Success entries (experiment position, status), in experiment then entry order. -/
  entries : Array (Nat × Status)
  /-- Success entry numbers by the fact they name. -/
  touches : Index String
  experimentIx : Index String
  claimIx : Index String
  /-- The ids of the `result` facts. -/
  resultIx : Index String
  /-- Exclusion positions by the claim position that needs both of its endpoints (an exclusion
  of any status; `Core.incompatible` tests the status). -/
  bothNeeded : Index Nat

/-- An exclusion's endpoints, each once. -/
def endpoints (x : Exclusion) : List String :=
  if x.between.2 == x.between.1 then [x.between.1] else [x.between.1, x.between.2]

/-- Each success entry of each experiment: (fact, (experiment position, status)). -/
def successEntries (t : Trace) : List (String × Nat × Status) :=
  t.experiments.zipIdx.flatMap fun (e, p) => e.success.map fun (k, st) => (k, p, st)

/-- Claim positions needing `id`, each once (from the claims-by-need pairs). -/
def gateList (gates : Index String) (id : String) : List Nat :=
  dedupSorted (gates.group (cmp := compare) id)

/-- The claim positions needing both `a` and `b`: the shorter list of either, tested against the
other through the (need, claim) counts. -/
def needingBoth (gates : Index String) (needCount : Index (String × Nat)) (a b : String) :
    List Nat :=
  if gates.count (cmp := compare) a ≤ gates.count (cmp := compare) b then
    (gateList gates a).filter fun p => needCount.count (cmp := compare) (b, p) > 0
  else (gateList gates b).filter fun p => needCount.count (cmp := compare) (a, p) > 0

def Ctx.build (t : Trace) : Ctx :=
  let entries := successEntries t
  let gates := Index.build compare (t.claims.zipIdx.flatMap fun (c, p) => c.needsAll.map (·, p))
  let needCount := Index.build compare
    (t.claims.zipIdx.flatMap fun (c, p) => c.needsAll.map fun n => ((n, p), p))
  { L := Lookups.fast t
    facts := t.facts.toArray
    subjects := t.subjects.toArray
    claims := t.claims.toArray
    experiments := t.experiments.toArray
    exclusions := t.exclusions.toArray
    factIx := Index.ofKeys compare (t.facts.map (·.id))
    subjectIx := Index.ofKeys compare (t.subjects.map (·.id))
    exclAt := Index.build compare (t.exclusions.zipIdx.flatMap fun (x, p) =>
      (endpoints x).map (·, p))
    exclSubject := Index.ofKeys compare (t.exclusions.map (·.subject))
    exclFirst := Index.ofKeys compare (t.exclusions.map (·.between.1))
    gates, needCount
    claimSubject := Index.ofKeys compare (t.claims.map (·.subject))
    entries := (entries.map (·.2)).toArray
    touches := Index.ofKeys compare (entries.map (·.1))
    experimentIx := Index.ofKeys compare (t.experiments.map (·.id))
    claimIx := Index.ofKeys compare (t.claims.map (·.id))
    resultIx := Index.ofKeys compare ((t.facts.filter (·.kind == .result)).map (·.id))
    bothNeeded := Index.build compare (t.exclusions.zipIdx.flatMap fun (x, i) =>
      (needingBoth gates needCount x.between.1 x.between.2).map (·, i)) }

namespace Ctx

variable (cx : Ctx)

/-- Claims needing `id`, by position, each once. -/
def gatePositions (id : String) : List Nat := gateList cx.gates id

/-- The trace's own claim at its position, when `c` is it (a claim outside the trace, or one
sharing an id with an earlier one, has none). -/
def positionOf (c : Claim) : Option Nat :=
  (cx.claimIx.first? (cmp := compare) c.id).bind fun p =>
    if cx.claims[p]? == some c then some p else none

/-- How often claim `p`'s `needsAll` names `id`. -/
def needs (id : String) (p : Nat) : Nat := cx.needCount.count (cmp := compare) (id, p)

def mustVerify (id : String) : Bool := (cx.L.fact? id).any (·.kind.mustVerify)

end Ctx

/-! ## One scenario: effective statuses + validity, memoized -/

structure Core where
  override? : String → Option Status
  eff1 : String → EStatus
  derivations : String → List (String × String)
  eff : String → EStatus
  active : Exclusion → Bool
  conflicts : String → List String
  /-- Active exclusions on a subject. -/
  activeCount : String → Nat

/-- The S-exclude witnesses of `id`, read on `eff1` (the body of `Scenario.derivations`), over the
exclusions at `id`. -/
def derive (cx : Ctx) (s : Scenario) (eff1 : String → EStatus) (id : String) :
    List (String × String) :=
  (cx.exclAt.group (cmp := compare) id).filterMap fun p => (cx.exclusions[p]?).bind fun x =>
    if (s.exclusionEff x).verified && !(eff1 id).asserted then
      if x.between.1 == id && (eff1 x.between.2).verified then some (x.id, x.between.2)
      else if x.between.2 == id && (eff1 x.between.1).verified then some (x.id, x.between.1)
      else none
    else none

def activeWith (s : Scenario) (eff1 : String → EStatus) (x : Exclusion) : Bool :=
  (s.exclusionEff x).asserted && (eff1 x.between.1).asserted && (eff1 x.between.2).asserted

def Core.build (cx : Ctx) (s : Scenario) : Core :=
  let ovArr := s.overrides.toArray
  let ovIx := Index.ofKeys compare (s.overrides.map (·.1))
  let override? := fun id => ((ovIx.first? (cmp := compare) id).bind (ovArr[·]?)).map (·.2)
  let eff1 := fun id => match override? id with
    | some st => EStatus.ofStatus st
    | none =>
      match cx.L.fact? id with
      | some f => s.eff0 f.status f.id
      | none => .«open»
  let effAt := fun id => if (derive cx s eff1 id).isEmpty then eff1 id else .violated
  let effArr := cx.facts.map fun f => effAt f.id
  let onSubject := fun sub =>
    ((cx.exclSubject.group (cmp := compare) sub).filterMap (cx.exclusions[·]?)).filter fun x =>
      x.subject == sub && activeWith s eff1 x
  let conflictsArr := cx.subjects.map fun sub => (onSubject sub.id).map (·.id)
  let conflicts := fun sub => match cx.subjectIx.first? (cmp := compare) sub with
    | some p => conflictsArr[p]?.getD ((onSubject sub).map (·.id))
    | none => (onSubject sub).map (·.id)
  { override?, eff1, derivations := derive cx s eff1
    eff := fun id => match cx.factIx.first? (cmp := compare) id with
      | some p => effArr[p]?.getD (effAt id)
      | none => effAt id
    active := activeWith s eff1
    conflicts
    activeCount := fun sub => (conflicts sub).length }

namespace Core

variable (cx : Ctx) (s : Scenario) (core : Core)

def valid (sub : String) : Bool := (core.conflicts sub).isEmpty

def restsOn (id : String) : Bool :=
  (core.eff id).asserted && (!cx.mustVerify id || (core.eff id).verified)

/-- `Scenario.incompatible`: a trace claim reads the exclusions needing both endpoints from
`bothNeeded`; any other claim tests the exclusions whose first endpoint is a need. -/
def incompatible (c : Claim) : List String :=
  let cands := match cx.positionOf c with
    | some p => cx.bothNeeded.group (cmp := compare) p
    | none => ascending (c.needsAll.flatMap (cx.exclFirst.group (cmp := compare) ·))
  let needs := Index.ofKeys compare c.needsAll
  let has := fun n => (needs.first? (cmp := compare) n).isSome
  ((cands.filterMap (cx.exclusions[·]?)).filter fun x =>
      (s.exclusionEff x).asserted && has x.between.1 && has x.between.2).map (·.id)

def intrinsic (c : Claim) : State :=
  let sts := c.needsAll.map core.eff
  if sts.any (· == .violated) || !(incompatible cx s c).isEmpty then .cannot
  else if sts.all (·.verified) then .can
  else if c.needsAll.all (restsOn cx core) then .conditional
  else .«open»

def final (c : Claim) : State := if core.valid c.subject then intrinsic cx s core c else .cannot

end Core

/-! ## Counts: a claim's state from how many needs fail each test -/

/-- How many needs are violated, unverified, not rested on (`Scenario.intrinsic`'s tests). -/
structure Counts where
  violated : Nat
  unverified : Nat
  unrested : Nat
  deriving BEq, Repr

def Counts.of (eff : String → EStatus) (rests : String → Bool) (needs : List String) : Counts :=
  { violated := needs.countP (eff · == .violated)
    unverified := needs.countP fun n => !(eff n).verified
    unrested := needs.countP (!rests ·) }

/-- The state the three counts + the incompatibility test give. -/
def Counts.state (k : Counts) (incompatible : Bool) : State :=
  if k.violated > 0 || incompatible then .cannot
  else if k.unverified == 0 then .can
  else if k.unrested == 0 then .conditional
  else .«open»

/-- The counts after the needs `occ` (the occurrences of the ids that move, in any order) move
from `eff` to `eff'`. -/
def Counts.patch (k : Counts) (occ : List String) (eff eff' : String → EStatus)
    (rests rests' : String → Bool) : Counts :=
  { violated := k.violated + occ.countP (eff' · == .violated) - occ.countP (eff · == .violated)
    unverified := k.unverified + occ.countP (fun n => !(eff' n).verified) -
      occ.countP (fun n => !(eff n).verified)
    unrested := k.unrested + occ.countP (!rests' ·) - occ.countP (!rests ·) }

/-- The occurrences among `needs` (`needsCount` of them) of the ids in `moved` (`movedCount` of
them), from the smaller side: each moved id as often as `times` counts it among the needs, or the
needs filtered by `isMoved` (the same multiset). The counts come precomputed: a long claim's
length would cost its size at every patch. -/
def occurrences (needs : List String) (needsCount : Nat) (moved : List String) (movedCount : Nat)
    (times : String → Nat) (isMoved : String → Bool) : List String :=
  if movedCount ≤ needsCount then moved.flatMap fun d => List.replicate (times d) d
  else needs.filter isMoved

/-! ## A what-if on top of the scenario -/

structure Delta where
  /-- The extra keys, each once (the only ids whose `eff1` moves). -/
  keys : List String
  isKey : String → Bool
  isChanged : String → Bool
  keyCount : Nat
  changedCount : Nat
  /-- `(s.withOverrides extra).eff1`. -/
  eff1 : String → EStatus
  /-- The extra keys + their exclusion partners, each once: the only ids whose `eff` moves. -/
  changed : List String
  /-- `(s.withOverrides extra).eff`. -/
  eff : String → EStatus
  /-- Positions of the exclusions at an extra key, ascending. -/
  touched : List Nat
  /-- `(s.withOverrides extra).valid`. -/
  valid : String → Bool

/-- `extra`'s statuses over the scenario's (`Scenario.withOverrides`'s `eff1`), its keys indexed
(`exIx` over `exArr`'s keys). -/
def eff1Under (core : Core) (exIx : Index String) (exArr : Array (String × Status))
    (id : String) : EStatus :=
  match ((exIx.first? (cmp := compare) id).bind (exArr[·]?)).map (·.2) with
  | some st => EStatus.ofStatus st
  | none => core.eff1 id

/-- `Scenario.eff` read on `eff1`. -/
def effUnder (cx : Ctx) (s : Scenario) (eff1 : String → EStatus) (id : String) : EStatus :=
  if (derive cx s eff1 id).isEmpty then eff1 id else .violated

/-- Positions of the exclusions at one of `keys`, ascending. -/
def touchedBy (cx : Ctx) (keys : List String) : List Nat :=
  ascending (keys.flatMap (cx.exclAt.group (cmp := compare) ·))

/-- Per subject of some of `xs`: how many of its exclusions among `xs` pass `before`, `after`. -/
structure Shifts where
  ix : Index String
  counts : Array (Nat × Nat)

def Shifts.of (xs : List Exclusion) (before after : Exclusion → Bool) : Shifts :=
  let subjects := Index.eraseDups compare (xs.map (·.subject))
  { ix := Index.ofKeys compare subjects
    counts := (subjects.map fun sub =>
      let ys := xs.filter (·.subject == sub)
      ((ys.filter before).length, (ys.filter after).length)).toArray }

/-- A subject's pair of counts ((0, 0) for a subject none of `xs` is on). -/
def Shifts.at (sh : Shifts) (sub : String) : Nat × Nat :=
  ((sh.ix.first? (cmp := compare) sub).bind (sh.counts[·]?)).getD (0, 0)

def Delta.build (cx : Ctx) (s : Scenario) (core : Core) (extra : Overrides) : Delta :=
  let exArr := extra.toArray
  let exIx := Index.ofKeys compare (extra.map (·.1))
  let eff1 := eff1Under core exIx exArr
  let keys := Index.eraseDups compare (extra.map (·.1))
  let touched := touchedBy cx keys
  let excls := touched.filterMap (cx.exclusions[·]?)
  let changed := Index.eraseDups compare (keys ++ excls.flatMap fun x => [x.between.1, x.between.2])
  -- Per subject of a touched exclusion, its active exclusions among them before + after (once).
  let shifts := Shifts.of excls core.active (activeWith s eff1)
  let keyIx := Index.ofKeys compare keys
  let changedIx := Index.ofKeys compare changed
  -- `eff` moves on `changed` alone: computed there once, read from the scenario elsewhere.
  let changedEff := (changed.map (effUnder cx s eff1)).toArray
  { keys, eff1, changed, touched
    keyCount := keys.length
    changedCount := changed.length
    isKey := fun id => (keyIx.first? (cmp := compare) id).isSome
    isChanged := fun id => (changedIx.first? (cmp := compare) id).isSome
    valid := fun sub => core.activeCount sub - (shifts.at sub).1 + (shifts.at sub).2 == 0
    eff := fun id => match changedIx.first? (cmp := compare) id with
      | some i => changedEff[i]?.getD (effUnder cx s eff1 id)
      | none => core.eff id }

namespace Delta

variable (cx : Ctx) (s : Scenario) (core : Core) (δ : Delta)

def restsOn (id : String) : Bool :=
  (δ.eff id).asserted && (!cx.mustVerify id || (δ.eff id).verified)

/-- The claim's final state under the what-if, from its needs, its base counts, how often it names
an id, and its incompatibility. -/
def final (needs : List String) (needsCount : Nat) (base : Counts) (times : String → Nat)
    (incompatible : Bool) (subject : String) : State :=
  if δ.valid subject then
    (base.patch (occurrences needs needsCount δ.changed δ.changedCount times δ.isChanged) core.eff
      δ.eff
      (Core.restsOn cx core) (restsOn cx δ)).state incompatible
  else .cannot

end Delta

/-! ## Per-claim memo (the trace's claims, by position) -/

structure ClaimMemo where
  /-- `c.needsAll`, built once (each call appends the entailment to the needs: O(needs)). -/
  needs : List String
  needsCount : Nat
  counts : Counts
  incompatible : Bool
  final : State

def ClaimMemo.of (cx : Ctx) (s : Scenario) (core : Core) (c : Claim) : ClaimMemo :=
  let needs := c.needsAll
  { needs, needsCount := needs.length
    counts := Counts.of core.eff (Core.restsOn cx core) needs
    incompatible := !(Core.incompatible cx s c).isEmpty
    final := Core.final cx s core c }

end Fvtrace.Answers

namespace Fvtrace.Answers

attribute [local instance] lexOrd

/-! ## Experiments -/

namespace Ctx

variable (cx : Ctx)

/-- What one closure member adds: its `requires` + the creator of its subject. -/
def adds (id : String) : List String :=
  match cx.L.experiment? id with
  | some e => e.requires ++
      (match cx.L.subject? e.subject with
       | some sub => sub.createdBy.toList
       | none => [])
  | none => []

/-- An experiment id's first position (the experiment `adds` reads); none for any other id. -/
def firstPos (id : String) : Option Nat := cx.experimentIx.first? (cmp := compare) id

/-- Marks `id`'s first position, adding `id` to the reached list, unless it is marked already or
names no experiment (such an id adds nothing to a closure). -/
def mark (st : Array Bool × List String) (id : String) : Array Bool × List String :=
  match cx.firstPos id with
  | some p => if st.1[p]?.getD true then st else (st.1.set! p true, id :: st.2)
  | none => st

/-- `fuel` levels of `Scenario.closureFuel` from the reached experiments `all`, whose newest level
is `frontier`: a level marks what the frontier's members add, so each experiment is expanded once;
an empty frontier ends the walk (later levels add nothing). -/
def levels : Nat → Array Bool → List String → List String → Array Bool × List String
  | 0, seen, _, all => (seen, all)
  | fuel + 1, seen, frontier, all =>
    if frontier.isEmpty then (seen, all)
    else
      let next := (frontier.flatMap cx.adds).foldl cx.mark (seen, [])
      levels fuel next.1 next.2 (next.2 ++ all)

/-- The experiments reachable from `ids`, each once, + `seen` with their first positions marked. -/
def reach (seen : Array Bool) (ids : List String) : Array Bool × List String :=
  let start := ids.foldl cx.mark (seen, [])
  cx.levels (cx.experiments.size + 1) start.1 start.2 start.2

/-- `seen` with the first positions of `ids` cleared. -/
def unmark (seen : Array Bool) (ids : List String) : Array Bool :=
  ids.foldl (fun a id => ((cx.firstPos id).map fun p => a.set! p false).getD a) seen

/-- The positions of the experiments named by `ids`, ascending. -/
def positions (ids : List String) : List Nat :=
  ascending (ids.flatMap (cx.experimentIx.group (cmp := compare) ·))

/-- Each experiment's own closure (`closure [e.id]`) as ascending positions, all in one pass
over one array of marks, cleared after each experiment: a closure costs its size, not the
trace's. -/
def closures : Array (List Nat) :=
  (cx.experiments.foldl (init := (Array.replicate cx.experiments.size false, #[])) fun st e =>
    let r := cx.reach st.1 [e.id]
    (cx.unmark r.1 r.2, st.2.push (cx.positions r.2))).2

/-- `Scenario.closure` from the per-experiment closures `memo` (`closures`): a closure of several
experiments is the union of theirs, in trace order. -/
def closureOf (memo : Array (List Nat)) (ids : List String) : List String :=
  (ascending (ids.flatMap fun id => ((cx.firstPos id).bind (memo[·]?)).getD [])).filterMap fun p =>
    (cx.experiments[p]?).map (·.id)

def successPairs (ids : List String) : List (String × Status) :=
  ids.flatMap fun id => ((cx.L.experiment? id).map (·.success)).getD []

/-- `Scenario.merged`: per fact (first-seen order), the strongest status the successes set. -/
def merged (ids : List String) : List (String × Status) :=
  let pairs := successPairs cx ids
  let arr := pairs.toArray
  let ix := Index.ofKeys compare (pairs.map (·.1))
  (Index.eraseDups compare (pairs.map (·.1))).map fun k =>
    (k, (((ix.group (cmp := compare) k).filterMap (arr[·]?)).map (·.2)).foldl Status.stronger
      .assumed)

def isResult (k : String) : Bool := (cx.resultIx.first? (cmp := compare) k).isSome

end Ctx

/-! ## The record -/

/-- The scenario's moves under the what-if `extra` (`Scenario.moves`): only claims needing a
changed id, or on a subject whose validity may move (an exclusion at a key), can move. -/
def movesUnder (cx : Ctx) (s : Scenario) (core : Core) (memo : Thunk (Array ClaimMemo))
    (extra : Overrides) : List Scenario.Move :=
  let δ := Delta.build cx s core extra
  let subjects := Index.eraseDups compare (δ.touched.filterMap fun p =>
    (cx.exclusions[p]?).map (·.subject))
  let flipped := subjects.filter fun sub => δ.valid sub != core.valid sub
  let cands := ascending (δ.changed.flatMap (cx.gates.group (cmp := compare) ·) ++
    flipped.flatMap (cx.claimSubject.group (cmp := compare) ·))
  cands.filterMap fun p => (cx.claims[p]?).bind fun c =>
    match memo.get[p]? with
    | some m =>
      let b := Delta.final cx core δ m.needs m.needsCount m.counts (cx.needs · p)
        m.incompatible c.subject
      if m.final != b then some { claim := c.id, before := m.final, after := b } else none
    | none => none

/-- `Scenario.unlocks`: the claims needing `f` whose state moves from open/cannot to
conditional/can when `f` alone reaches its ceiling. -/
def unlocksOf (cx : Ctx) (s : Scenario) (core : Core) (memo : Thunk (Array ClaimMemo))
    (f : Fact) : List String :=
  let δ := Delta.build cx s core [(f.id, f.ceiling)]
  (cx.gatePositions f.id).filterMap fun p => (cx.claims[p]?).bind fun c =>
    match memo.get[p]? with
    | some m =>
      if m.final.rank ≤ 1 &&
          (Delta.final cx core δ m.needs m.needsCount m.counts (cx.needs · p) m.incompatible
            c.subject).rank ≥ 2 then
        some c.id
      else none
    | none => none

/-- `Scenario.workBefore` on a work row with its list lengths beside it. -/
def workKeyBefore (a b : Nat × Nat × Scenario.Work) : Bool :=
  a.1 > b.1 || (a.1 == b.1 && (a.2.1 > b.2.1 || (a.2.1 == b.2.1 && a.2.2.fact < b.2.2.fact)))

/-- `Evaluate.experimentBefore` on an experiment with its lights + clears beside it. -/
def experimentKeyBefore (a b : Nat × Nat × Experiment) : Bool :=
  let ea := Effort.all.idxOf a.2.2.effort
  let eb := Effort.all.idxOf b.2.2.effort
  a.1 > b.1 || (a.1 == b.1 && (a.2.1 > b.2.1 || (a.2.1 == b.2.1 &&
    (ea < eb || (ea == eb && a.2.2.id < b.2.2.id)))))

/-! ## Plans -/

/-- `Scenario.search` over node answers: `closure`, `valid`/`optimistic`/`final` after a set of
successes, `cost`. Proved equal to `Scenario.search` for the scenario's own answers. -/
def searchWith (closure : List String → List String) (validAfter : List String → Bool)
    (optimisticRank finalRank : List String → Nat) (cost : List String → List Nat) :
    List String → List String → List String → List String
  | inc, [], best =>
    let p := closure inc
    if validAfter p && (let ra := finalRank p; let rb := finalRank best
        ra > rb || (ra == rb && (lexLt (cost p) (cost best) ||
          (cost p == cost best && idsLt p best)))) then p else best
  | inc, r :: rest, best =>
    let lo := closure inc
    let skip := if !validAfter lo then true
      else
        let bound := optimisticRank (closure (inc ++ r :: rest))
        let rank := finalRank best
        bound < rank || (bound == rank && lexLt (cost best) (cost lo))
    if skip then best
    else searchWith closure validAfter optimisticRank finalRank cost (inc ++ [r]) rest
      (searchWith closure validAfter optimisticRank finalRank cost inc rest best)

/-- `costOf` through the experiment index. -/
def costWith (cx : Ctx) (ids : List String) : List Nat :=
  let efforts := ids.filterMap fun id => (cx.L.experiment? id).map (·.effort)
  [Effort.months, .weeks, .days, .hours].map fun e => (efforts.filter (· == e)).length

/-- A success status `st` raises `n` above its status before the what-if. -/
def Core.raises (core : Core) (n : String) (st : Status) : Bool :=
  (EStatus.ofStatus st).strength > (core.eff1 n).strength

/-- `Scenario.raised`: the facts a success of `ids` raises, at their merged status. -/
def raisedBy (cx : Ctx) (core : Core) (ids : List String) : Overrides :=
  (cx.merged ids).filter fun x => core.raises x.1 x.2

/-- `Scenario.premises` under `eff`. -/
def premisesUnder (cx : Ctx) (eff : String → EStatus) (needs : List String) : List String :=
  needs.filter fun n => eff n == .assumed && !cx.mustVerify n

/-- `Scenario.gaps` under `eff`. -/
def gapsUnder (cx : Ctx) (eff : String → EStatus) (needs : List String) : List String :=
  needs.filter fun n => (eff n).strength == 1 || (eff n == .assumed && cx.mustVerify n)

/-- Positions of the experiments with a success entry raising one of `needs`, ascending. -/
def raisingPositions (cx : Ctx) (core : Core) (needs : List String) : List Nat :=
  ascending (needs.flatMap fun n => (cx.touches.group (cmp := compare) n).filterMap fun i =>
    (cx.entries[i]?).bind fun e => if core.raises n e.2 then some e.1 else none)

/-- The first of each run of entries at one position: one left fold carrying the previous
position (`List.zip` recurses once per entry, past the page engine's WebAssembly stack). -/
def firstPerRun (l : List (Nat × Status)) : List (Nat × Status) :=
  (l.foldl (init := ((#[] : Array (Nat × Status)), (none : Option Nat))) fun st x =>
    (if st.2 != some x.1 then st.1.push x else st.1, some x.1)).1.toList

/-- `Scenario.coverage`'s alternatives for `n`: of each relevant experiment (positions `relIx`),
its first success entry naming `n`, when it raises `n`. The entries naming `n` sit in experiment
then entry order, so an experiment's first is what `success.lookup n` reads. -/
def alternativesFor (cx : Ctx) (core : Core) (relIx : Index Nat) (n : String) :
    List Alternative :=
  (firstPerRun ((cx.touches.group (cmp := compare) n).filterMap (cx.entries[·]?))).filterMap
    fun e => if (relIx.first? (cmp := compare) e.1).isSome && core.raises n e.2 then
      (cx.experiments[e.1]?).map fun x => { need := n, experiment := x.id, status := e.2 }
    else none

/-- `Scenario.coverage` over the relevant positions' index. -/
def coverageOf (cx : Ctx) (core : Core) (needs : List String) (relIx : Index Nat) : Coverage :=
  let per := (needs.filter fun n => !(core.eff n).verified).map fun n =>
    (n, alternativesFor cx core relIx n)
  { premises := premisesUnder cx core.eff needs
    gaps := gapsUnder cx core.eff needs
    uncovered := (per.filter (·.2.isEmpty)).map (·.1)
    alternatives := per.flatMap (·.2) }

/-- `Scenario.plan` for any claim: relevance + coverage from the success-entry index, a search
whose nodes read deltas over the claim's own counts. -/
def planOf (cx : Ctx) (closure : List String → List String) (s : Scenario) (core : Core)
    (c : Claim) : PlanResult :=
  let needsAll := c.needsAll
  let relPos := (raisingPositions cx core needsAll).filter fun p =>
    (cx.experiments[p]?).any (·.subject == c.subject)
  let rel := relPos.filterMap (cx.experiments[·]?)
  let cov := coverageOf cx core needsAll (Index.ofKeys compare relPos)
  if !core.valid c.subject then .inconsistent cov
  else if rel.length > maxRelevant then .tooLarge cov
  else
    let needs := Index.ofKeys compare needsAll
    let times := fun d => needs.count (cmp := compare) d
    let incompatible := !(Core.incompatible cx s c).isEmpty
    let counts := Counts.of core.eff (Core.restsOn cx core) needsAll
    let rests1 := fun (eff1 : String → EStatus) (n : String) =>
      (eff1 n).asserted && (!cx.mustVerify n || (eff1 n).verified)
    let counts1 := Counts.of core.eff1 (rests1 core.eff1) needsAll
    let delta := fun ids => Delta.build cx s core (raisedBy cx core ids)
    let needsCount := needsAll.length
    let finalAfter := fun ids =>
      Delta.final cx core (delta ids) needsAll needsCount counts times incompatible c.subject
    let optimisticAfter := fun ids =>
      let δ := delta ids
      (counts1.patch (occurrences needsAll needsCount δ.keys δ.keyCount times δ.isKey) core.eff1
        δ.eff1
        (rests1 core.eff1) (rests1 δ.eff1)).state incompatible
    let p := searchWith closure (fun ids => (delta ids).valid c.subject)
      (fun ids => (optimisticAfter ids).rank) (fun ids => (finalAfter ids).rank) (costWith cx) []
      (rel.map (·.id)) []
    let δ := delta p
    let after := finalAfter p
    if after.rank ≤ (Core.final cx s core c).rank then .noImprovement cov
    else .planned cov p after (premisesUnder cx δ.eff needsAll) (gapsUnder cx δ.eff needsAll)
      (p.any fun id => ((cx.L.experiment? id).map fun e =>
        e.success.any fun x => cx.isResult x.1).getD false)

/-- The same answers from indexes + memos. -/
def fast (s : Scenario) : Answers :=
  let t := s.trace
  let cx := Ctx.build t
  let core := Core.build cx s
  let base := if s.overrides.isEmpty then core else Core.build cx { s with overrides := [] }
  let memo := Thunk.mk fun _ => cx.claims.map (ClaimMemo.of cx s core)
  let closures := Thunk.mk fun _ => cx.closures
  let closure := fun ids => cx.closureOf closures.get ids
  let gates := fun (f : Fact) => (cx.gatePositions f.id).filterMap fun p =>
    (cx.claims[p]?).map (·.id)
  let closable := fun (f : Fact) =>
    let e := core.eff f.id
    e != .violated && e.strength < (EStatus.ofStatus f.ceiling).strength
  let premises := fun (c : Claim) => premisesUnder cx core.eff c.needsAll
  let factText := fun id => ((cx.L.fact? id).map (·.text)).getD id
  let final := Core.final cx s core
  let prospective := fun sub => ((cx.L.subject? sub).map (·.kind == .prospective)).getD false
  let changedByWhatif := fun (c : Claim) =>
    c.needsAll.any (fun n => core.eff n != base.eff n) ||
      core.valid c.subject != base.valid c.subject
  let successMoves := fun ids => movesUnder cx s core memo (raisedBy cx core ids)
  { lookups := cx.L
    override? := core.override?
    eff := core.eff
    derivations := core.derivations
    active := core.active
    valid := core.valid
    conflicts := core.conflicts
    closable
    final
    intrinsic := Core.intrinsic cx s core
    sentence := fun c => String.join (Scenario.sentenceWith (final c) (premises c) factText c)
    qualifiers := fun c review =>
      Scenario.qualifiersWith (changedByWhatif c) review
        (if prospective c.subject then
          Scenario.creatorTitleWith cx.L.subject? cx.L.experiment? c.subject
        else none)
        (core.valid c.subject)
    verifiedNeeds := fun c => c.needsAll.filter fun n => (core.eff n).verified
    premises
    gaps := fun c => gapsUnder cx core.eff c.needsAll
    blockers := fun c => c.needsAll.filter fun n => core.eff n == .violated
    incompatible := Core.incompatible cx s
    hypothetical := fun c => prospective c.subject || changedByWhatif c
    prospective
    creates := fun e => (cx.L.subject? e.subject).any (·.createdBy == some e.id)
    factText
    isResult := cx.isResult
    claimsOn := fun sub => (cx.claimSubject.group (cmp := compare) sub).filterMap (cx.claims[·]?)
    plan := planOf cx closure s core
    work := fun _ =>
      let rows := t.facts.filterMap fun f =>
        let g := gates f
        if closable f && !g.isEmpty then
          some (({ fact := f.id, unlocks := unlocksOf cx s core memo f, gates := g } :
            Scenario.Work))
        else none
      ((rows.map fun w => (w.unlocks.length, w.gates.length, w)).mergeSort
        fun a b => !workKeyBefore b a).map (·.2.2)
    blockerFacts := fun _ => (t.facts.filter fun f => core.eff f.id == .violated).map fun f =>
      (f.id, gates f)
    closure
    merged := cx.merged
    raised := raisedBy cx core
    successMoves
    failureMoves := fun e => movesUnder cx s core memo (e.failure.map fun (k, _) => (k, .violated))
    experimentOrder := fun _ =>
      ((t.experiments.map fun e =>
          let ms := successMoves (closure [e.id])
          (Scenario.lights ms, Scenario.clears ms, e)).mergeSort
        fun a b => experimentKeyBefore a b).map (·.2.2)
    withOverrides := fun extra =>
      let ex := Index.ofKeys compare (extra.map (·.1))
      extra ++ s.overrides.filter fun (k, _) => (ex.first? (cmp := compare) k).isNone }

end Fvtrace.Answers
