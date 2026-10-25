import Fvtrace.Answers.Delta

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

end Fvtrace.Answers
