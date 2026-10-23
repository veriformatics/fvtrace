import Fvtrace.Index
import Fvtrace.Model

/-!
# Lookups (`.agent/contracts/kernel.md` P-shared)

Every by-id or whole-list question the checker, the lints, the receipt manifests + the engine ask
of one trace, as one record of plain functions. `reference` = the original expressions over the
trace's lists (the definitions the claims read); `fast` = the same answers from sorted indexes
(`Fvtrace.Index`): O(log n) per by-id question, O(n log n) once per whole-list
one. `Fvtrace.Proofs.Lookups` proves the two records equal, so code
written over a `Lookups` prints the same bytes with either.
-/

namespace Fvtrace

namespace Check

/-- Ids seen before index `i` (for first-duplicate reporting). -/
def duplicates (ids : List String) : List String :=
  (ids.zipIdx.filter fun (x, i) => (ids.take i).contains x).map (·.1)

/-- Two exclusions of one unordered pair on one subject. -/
def samePair (x y : Exclusion) : Bool :=
  x.subject == y.subject && (x.between == y.between || x.between == y.between.swap)

end Check

structure Lookups where
  fact? : String → Option Fact
  subject? : String → Option Subject
  claim? : String → Option Claim
  experiment? : String → Option Experiment
  hasQuestion : String → Bool
  hasSubject : String → Bool
  hasFact : String → Bool
  hasClaim : String → Bool
  hasExperiment : String → Bool
  /-- No id is declared twice across the collections (computed when asked). -/
  idsNodup : Unit → Bool
  /-- The ids declared more than once, in the order of their second declaration. -/
  duplicateIds : Unit → List String
  /-- Every claim naming entailment fact `e` is the claim with id `c`. -/
  soleEntailment : String → String → Bool
  /-- Every claim restating `needs` is the claim with id `c`. -/
  soleRestater : List String → String → Bool
  /-- An experiment before position `i` has id `r` + subject `s`. -/
  earlierExperiment : Nat → String → String → Bool
  /-- An exclusion before position `i` relates the same pair on the same subject. -/
  earlierPair : Nat → Exclusion → Bool
  /-- No (rule, claim) is waived twice. -/
  waiversNodup : Unit → Bool
  /-- The reason of the first waiver of `rule` for claim `c`. -/
  waiver? : String → String → Option String
  /-- The first claim naming entailment fact `e`. -/
  entailmentClaim? : String → Option Claim
  /-- The first claim restating exactly the result `f`. -/
  restatingClaim? : String → Option Claim
  nodup : List String → Bool

namespace Lookups

/-- The subject a fact id lives on, when it resolves. -/
def factSubject? (L : Lookups) (id : String) : Option String := (L.fact? id).map (·.subject)

/-- The original expressions over the trace's lists. -/
def reference (t : Trace) : Lookups where
  fact? := t.fact?
  subject? := t.subject?
  claim? := t.claim?
  experiment? := t.experiment?
  hasQuestion id := t.questionIds.contains id
  hasSubject id := t.subjectIds.contains id
  hasFact id := t.factIds.contains id
  hasClaim id := t.claimIds.contains id
  hasExperiment id := t.experimentIds.contains id
  idsNodup _ := decide t.allIds.Nodup
  duplicateIds _ := (Check.duplicates t.allIds).eraseDups
  soleEntailment e c := t.claims.all fun d => d.entailment != some e || d.id == c
  soleRestater needs c := t.claims.all fun d => !d.restates || d.needs != needs || d.id == c
  earlierExperiment i r s := (t.experiments.take i).any fun d => d.id == r && d.subject == s
  earlierPair i x := (t.exclusions.take i).any (Check.samePair x)
  waiversNodup _ := decide (t.waivers.map fun w => (w.rule, w.claim)).Nodup
  waiver? rule c := (t.waivers.find? fun w => w.rule == rule && w.claim == c).map (·.reason)
  entailmentClaim? e := t.claims.find? (·.entailment == some e)
  restatingClaim? f := t.claims.find? fun c => c.restates && c.needs == [f]
  nodup l := decide l.Nodup

attribute [local instance] lexOrd

/-- An exclusion's subject + its pair with the smaller id first: equal exactly for `samePair`. -/
def pairKey (x : Exclusion) : String × String × String :=
  (x.subject, if x.between.1 ≤ x.between.2 then x.between else x.between.swap)

/-- The positions of a list's items, keyed by `key` where it has one. -/
def keyed {α κ : Type} (l : List α) (key : α → Option κ) : List (κ × Nat) :=
  l.zipIdx.filterMap fun (x, i) => (key x).map (·, i)

/-- The restated result of a claim that restates exactly one fact. -/
def restatedOne (c : Claim) : Option String :=
  if c.restates then match c.needs with | [n] => some n | _ => none else none

/-- The same answers from sorted indexes: O(log n) per by-id question, a whole-list answer once.
An index is built on its first question (a `Thunk`), so a consumer pays for the ones it asks
alone. -/
@[noinline] def fast (t : Trace) : Lookups :=
  let facts := Thunk.mk fun _ => t.facts.toArray
  let subjects := Thunk.mk fun _ => t.subjects.toArray
  let claims := Thunk.mk fun _ => t.claims.toArray
  let experiments := Thunk.mk fun _ => t.experiments.toArray
  let waivers := Thunk.mk fun _ => t.waivers.toArray
  let factIx := Thunk.mk fun _ => Index.ofKeys compare (t.facts.map (·.id))
  let subjectIx := Thunk.mk fun _ => Index.ofKeys compare (t.subjects.map (·.id))
  let questionIx := Thunk.mk fun _ => Index.ofKeys compare (t.questions.map (·.id))
  let claimIx := Thunk.mk fun _ => Index.ofKeys compare (t.claims.map (·.id))
  let experimentIx := Thunk.mk fun _ => Index.ofKeys compare (t.experiments.map (·.id))
  let idsIx := Thunk.mk fun _ => Index.ofKeys compare t.allIds
  let entIx := Thunk.mk fun _ => Index.build compare (keyed t.claims (·.entailment))
  let entIdIx := Thunk.mk fun _ =>
    Index.build compare (keyed t.claims fun c => c.entailment.map (·, c.id))
  let restIx := Thunk.mk fun _ => Index.build compare
    (keyed t.claims fun c => if c.restates then some c.needs else none)
  let restIdIx := Thunk.mk fun _ => Index.build compare
    (keyed t.claims fun c => if c.restates then some (c.needs, c.id) else none)
  let restOneIx := Thunk.mk fun _ => Index.build compare (keyed t.claims restatedOne)
  let earlierIx := Thunk.mk fun _ =>
    Index.ofKeys compare (t.experiments.map fun d => (d.id, d.subject))
  let pairIx := Thunk.mk fun _ => Index.ofKeys compare (t.exclusions.map pairKey)
  let waiverIx := Thunk.mk fun _ => Index.ofKeys compare (t.waivers.map fun w => (w.rule, w.claim))
  { fact? := fun id => (factIx.get.first? (cmp := compare) id).bind (facts.get[·]?)
    subject? := fun id => (subjectIx.get.first? (cmp := compare) id).bind (subjects.get[·]?)
    claim? := fun id => (claimIx.get.first? (cmp := compare) id).bind (claims.get[·]?)
    experiment? := fun id =>
      (experimentIx.get.first? (cmp := compare) id).bind (experiments.get[·]?)
    hasQuestion := fun id => (questionIx.get.first? (cmp := compare) id).isSome
    hasSubject := fun id => (subjectIx.get.first? (cmp := compare) id).isSome
    hasFact := fun id => (factIx.get.first? (cmp := compare) id).isSome
    hasClaim := fun id => (claimIx.get.first? (cmp := compare) id).isSome
    hasExperiment := fun id => (experimentIx.get.first? (cmp := compare) id).isSome
    idsNodup := fun _ => Index.nodup compare t.allIds
    duplicateIds := fun _ => Index.eraseDups compare
      ((t.allIds.zipIdx.filter fun (x, i) =>
        (idsIx.get.first? (cmp := compare) x).any (· < i)).map (·.1))
    soleEntailment := fun e c =>
      entIx.get.count (cmp := compare) e == entIdIx.get.count (cmp := compare) (e, c)
    soleRestater := fun needs c =>
      restIx.get.count (cmp := compare) needs == restIdIx.get.count (cmp := compare) (needs, c)
    earlierExperiment := fun i r s => (earlierIx.get.first? (cmp := compare) (r, s)).any (· < i)
    earlierPair := fun i x => (pairIx.get.first? (cmp := compare) (pairKey x)).any (· < i)
    waiversNodup := fun _ => Index.nodup compare (t.waivers.map fun w => (w.rule, w.claim))
    waiver? := fun rule c =>
      (waiverIx.get.first? (cmp := compare) (rule, c)).bind fun p => waivers.get[p]?.map (·.reason)
    entailmentClaim? := fun e => (entIx.get.first? (cmp := compare) e).bind (claims.get[·]?)
    restatingClaim? := fun f => (restOneIx.get.first? (cmp := compare) f).bind (claims.get[·]?)
    nodup := Index.nodup compare }

end Lookups

end Fvtrace
