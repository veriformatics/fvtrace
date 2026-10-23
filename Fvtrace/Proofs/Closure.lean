import Fvtrace.Proofs.Plan
import Fvtrace.Proofs.Positions

/-! `Ctx.closureOf (Ctx.closures)` = `Scenario.closure` (`kernel.md` P-delta) on every trace: a
level of `Ctx.levels` adds what one step of `Scenario.closureFuel` adds (its frontier stands for
the rest, whose additions are in already), so the reached experiments after the reference's own
fuel are the reference's; marks are cleared after each experiment; a closure of several ids is the
union of theirs. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false
set_option linter.unusedSectionVars false

namespace Fvtrace.Proofs.Closure
open Fvtrace Fvtrace.Answers Fvtrace.Proofs.Index Fvtrace.Proofs.Lookups
  Fvtrace.Proofs.Positions
open Fvtrace.Proofs.Plan (adds closureFuelRef mem_closureStep closureFuel_eq_ref)

variable (s : Scenario)

local notation "cx" => Ctx.build s.trace
local notation "n" => s.trace.experiments.length

/-! ## First positions -/

theorem ctx_experiments : (cx).experiments = s.trace.experiments.toArray := rfl

theorem adds_eq (id : String) : (cx).adds id = adds s id := by
  unfold Ctx.adds Fvtrace.Proofs.Plan.adds
  rw [show (cx).L = Lookups.reference s.trace from fast_eq_reference s.trace]
  rfl

theorem firstPos_eq (id : String) :
    (cx).firstPos id = s.trace.experiments.findIdx? (·.id == id) :=
  first?_map s.trace.experiments (·.id) id

theorem firstPos_some {id : String} {p : Nat} (h : (cx).firstPos id = some p) :
    ∃ hp : p < n, s.trace.experiments[p].id = id := by
  rw [firstPos_eq, List.findIdx?_eq_some_iff_getElem] at h
  obtain ⟨hp, he, _⟩ := h
  exact ⟨hp, by simpa using he⟩

theorem firstPos_inj {a b : String} {p : Nat} (ha : (cx).firstPos a = some p)
    (hb : (cx).firstPos b = some p) : a = b := by
  obtain ⟨_, ha'⟩ := firstPos_some s ha
  obtain ⟨_, hb'⟩ := firstPos_some s hb
  rw [← ha', ← hb']

theorem firstPos_isSome (id : String) :
    ((cx).firstPos id).isSome ↔ id ∈ s.trace.experimentIds := by
  rw [firstPos_eq, List.findIdx?_isSome, List.any_eq_true]
  simp [Trace.experimentIds]

theorem adds_none {id : String} (h : (cx).firstPos id = none) : adds s id = [] := by
  have hn : id ∉ s.trace.experimentIds := by
    rw [← firstPos_isSome]; simp [h]
  unfold adds Trace.experiment?
  rw [List.find?_eq_none.mpr]
  intro e he hid
  exact hn (List.mem_map.mpr ⟨e, he, by simpa using hid⟩)

/-! ## Marking -/

/-- A mark at position `p`. -/
def Marked (a : Array Bool) (p : Nat) : Prop := a[p]? = some true

theorem marked_set (a : Array Bool) (p q : Nat) (hp : p < a.size) :
    Marked (a.set! p true) q ↔ q = p ∨ Marked a q := by
  unfold Marked
  rw [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds]
  by_cases h : p = q
  · subst h; simp [hp]
  · simp [h, Ne.symm h]

theorem mark_none {st : Array Bool × List String} {x : String} (h : (cx).firstPos x = none) :
    (cx).mark st x = st := by
  unfold Ctx.mark; rw [h]

theorem mark_some {st : Array Bool × List String} {x : String} {p : Nat}
    (h : (cx).firstPos x = some p) :
    (cx).mark st x = if st.1[p]?.getD true then st else (st.1.set! p true, x :: st.2) := by
  unfold Ctx.mark; rw [h]

theorem mark_fold : ∀ (L : List String) (seen : Array Bool) (acc : List String),
    seen.size = n →
    (L.foldl (cx).mark (seen, acc)).1.size = n ∧
    (∀ p, Marked (L.foldl (cx).mark (seen, acc)).1 p ↔
      Marked seen p ∨ ∃ x ∈ L, (cx).firstPos x = some p) ∧
    (∀ x, x ∈ (L.foldl (cx).mark (seen, acc)).2 ↔
      x ∈ acc ∨ (x ∈ L ∧ ∃ p, (cx).firstPos x = some p ∧ ¬ Marked seen p))
  | [], seen, acc, hsz => by simp [hsz]
  | x :: L, seen, acc, hsz => by
    simp only [List.foldl_cons]
    cases hx : (cx).firstPos x with
    | none =>
      rw [mark_none s hx]
      obtain ⟨h1, h2, h3⟩ := mark_fold L seen acc hsz
      refine ⟨h1, fun p => ?_, fun y => ?_⟩
      · rw [h2]
        constructor
        · rintro (h | ⟨z, hz, hzp⟩)
          · exact Or.inl h
          · exact Or.inr ⟨z, List.mem_cons_of_mem _ hz, hzp⟩
        · rintro (h | ⟨z, hz, hzp⟩)
          · exact Or.inl h
          · rcases List.mem_cons.mp hz with rfl | hz
            · rw [hx] at hzp; cases hzp
            · exact Or.inr ⟨z, hz, hzp⟩
      · rw [h3]
        constructor
        · rintro (h | ⟨hy, p, hp, hm⟩)
          · exact Or.inl h
          · exact Or.inr ⟨List.mem_cons_of_mem _ hy, p, hp, hm⟩
        · rintro (h | ⟨hy, p, hp, hm⟩)
          · exact Or.inl h
          · rcases List.mem_cons.mp hy with rfl | hy
            · rw [hx] at hp; cases hp
            · exact Or.inr ⟨hy, p, hp, hm⟩
    | some p =>
      rw [mark_some s hx]
      obtain ⟨hpn, _⟩ := firstPos_some s hx
      have hget : seen[p]? = some seen[p] := Array.getElem?_eq_getElem (by omega)
      simp only [hget, Option.getD_some]
      split
      · rename_i hm
        have hmark : Marked seen p := by unfold Marked; rw [hget, hm]
        obtain ⟨h1, h2, h3⟩ := mark_fold L seen acc hsz
        refine ⟨h1, fun q => ?_, fun y => ?_⟩
        · rw [h2]
          constructor
          · rintro (h | ⟨z, hz, hzp⟩)
            · exact Or.inl h
            · exact Or.inr ⟨z, List.mem_cons_of_mem _ hz, hzp⟩
          · rintro (h | ⟨z, hz, hzq⟩)
            · exact Or.inl h
            · rcases List.mem_cons.mp hz with rfl | hz
              · rw [hx] at hzq; cases hzq; exact Or.inl hmark
              · exact Or.inr ⟨z, hz, hzq⟩
        · rw [h3]
          constructor
          · rintro (h | ⟨hy, q, hq, hm'⟩)
            · exact Or.inl h
            · exact Or.inr ⟨List.mem_cons_of_mem _ hy, q, hq, hm'⟩
          · rintro (h | ⟨hy, q, hq, hm'⟩)
            · exact Or.inl h
            · rcases List.mem_cons.mp hy with rfl | hy
              · rw [hx] at hq; cases hq; exact absurd hmark hm'
              · exact Or.inr ⟨hy, q, hq, hm'⟩
      · rename_i hm
        have hnot : ¬ Marked seen p := by unfold Marked; rw [hget]; simpa using hm
        have hsz' : (seen.set! p true).size = n := by
          rw [Array.set!_eq_setIfInBounds, Array.size_setIfInBounds, hsz]
        obtain ⟨h1, h2, h3⟩ := mark_fold L (seen.set! p true) (x :: acc) hsz'
        refine ⟨h1, fun q => ?_, fun y => ?_⟩
        · rw [h2, marked_set seen p q (by omega)]
          constructor
          · rintro ((rfl | h) | ⟨z, hz, hzq⟩)
            · exact Or.inr ⟨x, List.mem_cons_self, hx⟩
            · exact Or.inl h
            · exact Or.inr ⟨z, List.mem_cons_of_mem _ hz, hzq⟩
          · rintro (h | ⟨z, hz, hzq⟩)
            · exact Or.inl (Or.inr h)
            · rcases List.mem_cons.mp hz with rfl | hz
              · rw [hx] at hzq; cases hzq; exact Or.inl (Or.inl rfl)
              · exact Or.inr ⟨z, hz, hzq⟩
        · rw [h3, List.mem_cons]
          constructor
          · rintro ((rfl | h) | ⟨hy, q, hq, hm'⟩)
            · exact Or.inr ⟨List.mem_cons_self, p, hx, hnot⟩
            · exact Or.inl h
            · refine Or.inr ⟨List.mem_cons_of_mem _ hy, q, hq, fun h => hm' ?_⟩
              rw [marked_set seen p q (by omega)]
              exact Or.inr h
          · rintro (h | ⟨hy, q, hq, hm'⟩)
            · exact Or.inl (Or.inr h)
            · rcases List.mem_cons.mp hy with rfl | hy
              · exact Or.inl (Or.inl rfl)
              · by_cases hqp : q = p
                · subst hqp
                  exact Or.inl (Or.inl (firstPos_inj s hq hx))
                · refine Or.inr ⟨hy, q, hq, fun h => hm' ?_⟩
                  rcases (marked_set seen p q (by omega)).mp h with h | h
                  · exact absurd h hqp
                  · exact h

/-! ## Levels = closure steps -/

/-- Membership-equal lists stay so through the reference's steps. -/
theorem fuel_same {a b : List String} (h : ∀ x, x ∈ a ↔ x ∈ b) :
    ∀ f x, x ∈ closureFuelRef s f a ↔ x ∈ closureFuelRef s f b := by
  intro f
  induction f generalizing a b with
  | zero => exact h
  | succ f ih =>
    exact ih (fun x => Fvtrace.Proofs.Plan.closureStep_same s h x)

/-- A list closed under `adds` is its own closure, at any fuel. -/
theorem fuel_closed {R : List String} (hc : ∀ x ∈ R, ∀ a ∈ adds s x, a ∈ R) :
    ∀ f x, x ∈ closureFuelRef s f R ↔ x ∈ R := by
  intro f
  induction f with
  | zero => intro x; exact Iff.rfl
  | succ f ih =>
    intro x
    have hstep : ∀ y, y ∈ s.closureStep R ↔ y ∈ R := by
      intro y
      rw [mem_closureStep]
      constructor
      · rintro (h | ⟨z, hz, hy⟩)
        · exact h
        · exact hc z hz y hy
      · exact Or.inl
    show x ∈ closureFuelRef s f (s.closureStep R) ↔ x ∈ R
    rw [fuel_same s hstep f x, ih x]

theorem levels_spec : ∀ (f : Nat) (R : List String) (seen : Array Bool)
    (frontier all : List String),
    seen.size = n →
    (∀ p, Marked seen p ↔ ∃ x ∈ R, (cx).firstPos x = some p) →
    (∀ x, x ∈ all ↔ x ∈ R ∧ x ∈ s.trace.experimentIds) →
    (∀ x ∈ frontier, x ∈ R) →
    (∀ x ∈ R, x ∉ frontier → ∀ a ∈ adds s x, a ∈ R) →
    ((cx).levels f seen frontier all).1.size = n ∧
    (∀ p, Marked ((cx).levels f seen frontier all).1 p ↔
      ∃ x ∈ closureFuelRef s f R, (cx).firstPos x = some p) ∧
    (∀ x, x ∈ ((cx).levels f seen frontier all).2 ↔
      x ∈ closureFuelRef s f R ∧ x ∈ s.trace.experimentIds)
  | 0, R, seen, frontier, all, hsz, hA, hB, _, _ => ⟨hsz, hA, hB⟩
  | f + 1, R, seen, frontier, all, hsz, hA, hB, hD, hC => by
    unfold Ctx.levels
    split
    · rename_i he
      have hfr : frontier = [] := List.isEmpty_iff.mp he
      subst hfr
      have hcl := fuel_closed s (fun x hx a ha => hC x hx (List.not_mem_nil) a ha) (f + 1)
      exact ⟨hsz, fun p => by simp only [hA, hcl], fun x => by rw [hB, hcl]⟩
    · dsimp only
      have hfa : ∀ a, a ∈ frontier.flatMap (cx).adds ↔ ∃ y ∈ frontier, a ∈ adds s y := by
        intro a; simp [List.mem_flatMap, adds_eq]
      obtain ⟨h1, h2, h3⟩ := mark_fold s (frontier.flatMap (cx).adds) seen [] hsz
      -- One reference step: the frontier's additions alone are new.
      have hstep : ∀ x, x ∈ s.closureStep R ↔ x ∈ R ∨ ∃ y ∈ frontier, x ∈ adds s y := by
        intro x
        rw [mem_closureStep]
        constructor
        · rintro (h | ⟨y, hy, hx⟩)
          · exact Or.inl h
          · by_cases hyf : y ∈ frontier
            · exact Or.inr ⟨y, hyf, hx⟩
            · exact Or.inl (hC y hy hyf x hx)
        · rintro (h | ⟨y, hy, hx⟩)
          · exact Or.inl h
          · exact Or.inr ⟨y, hD y hy, hx⟩
      have hfp : ∀ x p, (cx).firstPos x = some p → Marked seen p → x ∈ R := by
        intro x p hx hm
        obtain ⟨z, hz, hzp⟩ := (hA p).mp hm
        rw [firstPos_inj s hx hzp]; exact hz
      have := levels_spec f (s.closureStep R)
        ((frontier.flatMap (cx).adds).foldl (cx).mark (seen, [])).1
        ((frontier.flatMap (cx).adds).foldl (cx).mark (seen, [])).2
        (((frontier.flatMap (cx).adds).foldl (cx).mark (seen, [])).2 ++ all) h1 ?A ?B ?D ?C
      · exact this
      case A =>
        intro p
        rw [h2, hA]
        constructor
        · rintro (⟨x, hx, hxp⟩ | ⟨x, hx, hxp⟩)
          · exact ⟨x, (hstep x).mpr (Or.inl hx), hxp⟩
          · exact ⟨x, (hstep x).mpr (Or.inr ((hfa x).mp hx)), hxp⟩
        · rintro ⟨x, hx, hxp⟩
          rcases (hstep x).mp hx with hx | hx
          · exact Or.inl ⟨x, hx, hxp⟩
          · exact Or.inr ⟨x, (hfa x).mpr hx, hxp⟩
      case B =>
        intro x
        rw [List.mem_append, h3, hB, hstep]
        constructor
        · rintro ((h | ⟨hx, p, hxp, _⟩) | ⟨hx, hE⟩)
          · cases h
          · exact ⟨Or.inr ((hfa x).mp hx), (firstPos_isSome s x).mp (by simp [hxp])⟩
          · exact ⟨Or.inl hx, hE⟩
        · rintro ⟨hx | hx, hE⟩
          · exact Or.inr ⟨hx, hE⟩
          · obtain ⟨p, hxp⟩ := Option.isSome_iff_exists.mp ((firstPos_isSome s x).mpr hE)
            by_cases hm : Marked seen p
            · exact Or.inr ⟨hfp x p hxp hm, hE⟩
            · exact Or.inl (Or.inr ⟨(hfa x).mpr hx, p, hxp, hm⟩)
      case D =>
        intro x hx
        rcases (h3 x).mp hx with h | ⟨hx, _⟩
        · cases h
        · exact (hstep x).mpr (Or.inr ((hfa x).mp hx))
      case C =>
        intro x hx hxn a ha
        rw [mem_closureStep]
        by_cases hxR : x ∈ R
        · exact Or.inr ⟨x, hxR, ha⟩
        · exfalso
          rcases (hstep x).mp hx with h | hx'
          · exact hxR h
          · cases hxp : (cx).firstPos x with
            | none => rw [adds_none s hxp] at ha; cases ha
            | some p =>
              by_cases hm : Marked seen p
              · exact hxR (hfp x p hxp hm)
              · exact hxn ((h3 x).mpr (Or.inr ⟨(hfa x).mpr hx', p, hxp, hm⟩))

/-- The walk from `ids` with nothing marked: the experiments the reference closure reaches, their
first positions marked. -/
theorem reach_spec (seen : Array Bool) (ids : List String) (hsz : seen.size = n)
    (h0 : ∀ p, ¬ Marked seen p) :
    ((cx).reach seen ids).1.size = n ∧
    (∀ p, Marked ((cx).reach seen ids).1 p ↔
      ∃ x ∈ closureFuelRef s (n + 1) ids, (cx).firstPos x = some p) ∧
    (∀ x, x ∈ ((cx).reach seen ids).2 ↔
      x ∈ closureFuelRef s (n + 1) ids ∧ x ∈ s.trace.experimentIds) := by
  unfold Ctx.reach
  dsimp only
  obtain ⟨h1, h2, h3⟩ := mark_fold s ids seen [] hsz
  have hB : ∀ x, x ∈ (ids.foldl (cx).mark (seen, [])).2 ↔ x ∈ ids ∧ x ∈ s.trace.experimentIds := by
    intro x
    rw [h3]
    constructor
    · rintro (h | ⟨hx, p, hxp, _⟩)
      · cases h
      · exact ⟨hx, (firstPos_isSome s x).mp (by simp [hxp])⟩
    · rintro ⟨hx, hE⟩
      obtain ⟨p, hxp⟩ := Option.isSome_iff_exists.mp ((firstPos_isSome s x).mpr hE)
      exact Or.inr ⟨hx, p, hxp, h0 p⟩
  have hsize : (cx).experiments.size = n := by rw [ctx_experiments, List.size_toArray]
  rw [hsize]
  refine levels_spec s (n + 1) ids _ _ _ h1 (fun p => ?_) hB (fun x hx => ((hB x).mp hx).1) ?_
  · rw [h2]
    constructor
    · rintro (h | h)
      · exact absurd h (h0 p)
      · exact h
    · exact Or.inr
  · intro x hx hxn a ha
    exfalso
    cases hxp : (cx).firstPos x with
    | none => rw [adds_none s hxp] at ha; cases ha
    | some p =>
      exact hxn ((hB x).mpr ⟨hx, (firstPos_isSome s x).mp (by simp [hxp])⟩)

/-! ## Clearing + the per-experiment memo -/

theorem unmark_spec : ∀ (L : List String) (a : Array Bool),
    ((cx).unmark a L).size = a.size ∧
    ∀ p, Marked ((cx).unmark a L) p ↔ Marked a p ∧ ¬ ∃ x ∈ L, (cx).firstPos x = some p
  | [], a => by simp [Ctx.unmark]
  | x :: L, a => by
    unfold Ctx.unmark
    simp only [List.foldl_cons]
    have ih := unmark_spec L (((cx).firstPos x).map (fun p => a.set! p false) |>.getD a)
    unfold Ctx.unmark at ih
    refine ⟨?_, fun p => ?_⟩
    · rw [ih.1]
      cases (cx).firstPos x <;> simp [Array.set!_eq_setIfInBounds]
    · rw [ih.2]
      cases hx : (cx).firstPos x with
      | none =>
        simp only [Option.map_none, Option.getD_none]
        constructor
        · rintro ⟨hm, hn⟩
          refine ⟨hm, fun ⟨z, hz, hzp⟩ => ?_⟩
          rcases List.mem_cons.mp hz with rfl | hz
          · rw [hx] at hzp; cases hzp
          · exact hn ⟨z, hz, hzp⟩
        · rintro ⟨hm, hn⟩
          exact ⟨hm, fun ⟨z, hz, hzp⟩ => hn ⟨z, List.mem_cons_of_mem _ hz, hzp⟩⟩
      | some q =>
        simp only [Option.map_some, Option.getD_some]
        unfold Marked
        rw [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds]
        by_cases hqp : q = p
        · subst hqp
          simp only [ite_true]
          constructor
          · rintro ⟨h, _⟩
            split at h <;> simp at h
          · rintro ⟨_, hn⟩
            exact absurd ⟨x, List.mem_cons_self, hx⟩ hn
        · simp only [hqp, ite_false]
          constructor
          · rintro ⟨hm, hn⟩
            refine ⟨hm, fun ⟨z, hz, hzp⟩ => ?_⟩
            rcases List.mem_cons.mp hz with rfl | hz
            · rw [hx] at hzp; exact hqp (Option.some.inj hzp)
            · exact hn ⟨z, hz, hzp⟩
          · rintro ⟨hm, hn⟩
            exact ⟨hm, fun ⟨z, hz, hzp⟩ => hn ⟨z, List.mem_cons_of_mem _ hz, hzp⟩⟩

/-- An array of n marks, none set. -/
abbrev blank : Array Bool := Array.replicate n false

theorem blank_unmarked (p : Nat) : ¬ Marked (blank s) p := by
  unfold Marked
  rw [Array.getElem?_replicate]
  split <;> simp

/-- Clearing what one walk from a blank array marked gives the blank array back. -/
theorem reach_cleared (ids : List String) :
    (cx).unmark ((cx).reach (blank s) ids).1 ((cx).reach (blank s) ids).2 = blank s := by
  obtain ⟨h1, h2, h3⟩ := reach_spec s (blank s) ids (by simp) (blank_unmarked s)
  obtain ⟨u1, u2⟩ := unmark_spec s ((cx).reach (blank s) ids).2 ((cx).reach (blank s) ids).1
  apply Array.ext
  · rw [u1, h1]; simp
  · intro i hi _
    have hnot : ¬ Marked ((cx).unmark ((cx).reach (blank s) ids).1
        ((cx).reach (blank s) ids).2) i := by
      rw [u2, h2]
      rintro ⟨⟨x, hx, hxp⟩, hn⟩
      exact hn ⟨x, (h3 x).mpr ⟨hx, (firstPos_isSome s x).mp (by simp [hxp])⟩, hxp⟩
    unfold Marked at hnot
    rw [Array.getElem?_eq_getElem hi] at hnot
    simp only [Array.getElem_replicate]
    simpa using hnot

theorem closures_eq : (cx).closures = (s.trace.experiments.map fun e =>
    (cx).positions ((cx).reach (blank s) [e.id]).2).toArray := by
  unfold Ctx.closures
  have hstep : ∀ (L : List Experiment) (acc : Array (List Nat)),
      L.foldl (fun st e =>
        ((cx).unmark ((cx).reach st.1 [e.id]).1 ((cx).reach st.1 [e.id]).2,
          st.2.push ((cx).positions ((cx).reach st.1 [e.id]).2))) (blank s, acc) =
        (blank s,
          acc ++ (L.map fun e => (cx).positions ((cx).reach (blank s) [e.id]).2).toArray) := by
    intro L
    induction L with
    | nil => intro acc; simp
    | cons e L ih =>
      intro acc
      simp only [List.foldl_cons]
      rw [reach_cleared, ih]
      simp
  rw [ctx_experiments, List.foldl_toArray, List.size_toArray]
  rw [hstep]
  simp

/-! ## A closure from the memo -/

theorem mem_positions_of (L : List String) (q : Nat) :
    q ∈ (cx).positions L ↔ ∃ hq : q < n, s.trace.experiments[q].id ∈ L := by
  unfold Ctx.positions
  rw [(ascending_spec _).2, List.mem_flatMap]
  constructor
  · rintro ⟨k, hk, hq⟩
    rw [show (cx).experimentIx = Index.ofKeys compare (s.trace.experiments.map (·.id)) from rfl,
      group_map, mem_positions (q := fun (e : Experiment) => e.id == k)] at hq
    obtain ⟨hlt, he⟩ := hq
    exact ⟨hlt, by simp only [beq_iff_eq] at he; rw [he]; exact hk⟩
  · rintro ⟨hlt, hk⟩
    refine ⟨s.trace.experiments[q].id, hk, ?_⟩
    rw [show (cx).experimentIx = Index.ofKeys compare (s.trace.experiments.map (·.id)) from rfl,
      group_map, mem_positions (q := fun (e : Experiment) => e.id == s.trace.experiments[q].id)]
    exact ⟨hlt, by simp⟩

/-- A reference closure of several ids = the union of theirs. -/
theorem fuel_union : ∀ (f : Nat) (ids : List String) (x : String),
    x ∈ closureFuelRef s f ids ↔ ∃ id ∈ ids, x ∈ closureFuelRef s f [id]
  | 0, ids, x => by simp [closureFuelRef]
  | f + 1, ids, x => by
    show x ∈ closureFuelRef s f (s.closureStep ids) ↔
      ∃ id ∈ ids, x ∈ closureFuelRef s f (s.closureStep [id])
    rw [fuel_union f]
    constructor
    · rintro ⟨y, hy, hx⟩
      rcases (mem_closureStep s).mp hy with hy | ⟨z, hz, hyz⟩
      · exact ⟨y, hy, (fuel_union f _ x).mpr ⟨y, (mem_closureStep s).mpr (Or.inl (by simp)), hx⟩⟩
      · exact ⟨z, hz, (fuel_union f _ x).mpr
          ⟨y, (mem_closureStep s).mpr (Or.inr ⟨z, by simp, hyz⟩), hx⟩⟩
    · rintro ⟨id, hid, hx⟩
      obtain ⟨y, hy, hx⟩ := (fuel_union f _ x).mp hx
      refine ⟨y, ?_, hx⟩
      rcases (mem_closureStep s).mp hy with hy | ⟨z, hz, hyz⟩
      · simp only [List.mem_singleton] at hy
        subst hy
        exact (mem_closureStep s).mpr (Or.inl hid)
      · simp only [List.mem_singleton] at hz
        subst hz
        exact (mem_closureStep s).mpr (Or.inr ⟨z, hid, hyz⟩)

/-- Positions whose experiment's id an `all` list holds, read back in order = the reference's
filter of the experiment ids. -/
theorem read_closure (P : List Nat) (all : List String)
    (hP : ∀ q, q ∈ P ↔ ∃ hq : q < n, s.trace.experiments[q].id ∈ all) :
    (ascending P).filterMap (fun p => ((cx).experiments[p]?).map (·.id)) =
      s.trace.experimentIds.filter all.contains := by
  have hb : ∀ q ∈ P, q < n := fun q hq => ((hP q).mp hq).1
  rw [ascending_eq hb, ctx_experiments, range_filter_eq]
  have hmap : ∀ Q : List Nat, Q.filterMap (fun p => (s.trace.experiments.toArray[p]?).map (·.id)) =
      (Q.filterMap (s.trace.experiments.toArray[·]?)).map (·.id) := by
    intro Q; rw [List.map_filterMap]
  rw [hmap, read_positions]
  unfold Trace.experimentIds
  rw [List.filter_map]
  congr 1
  have : (s.trace.experiments.zipIdx.filter fun x => decide (x.2 ∈ P)) =
      s.trace.experiments.zipIdx.filter fun x => (all.contains ∘ (·.id)) x.1 := by
    apply List.filter_congr
    intro x hx
    obtain ⟨hlt, heq⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) hx
    rw [Bool.eq_iff_iff, decide_eq_true_iff, hP]
    simp only [Function.comp_apply, List.contains_iff_mem]
    constructor
    · rintro ⟨_, h⟩; rw [heq]; exact h
    · intro h; exact ⟨hlt, by rw [← heq]; exact h⟩
  rw [this]
  exact zipIdx_filter_fst s.trace.experiments (all.contains ∘ (·.id))

theorem closureOf_eq : (cx).closureOf (cx).closures = s.closure := by
  funext ids
  unfold Ctx.closureOf Scenario.closure
  rw [closureFuel_eq_ref]
  apply read_closure
  intro q
  rw [List.mem_flatMap]
  constructor
  · rintro ⟨id, hid, hq⟩
    cases hp : (cx).firstPos id with
    | none => simp [hp] at hq
    | some p =>
      obtain ⟨hpn, hpid⟩ := firstPos_some s hp
      rw [hp, Option.bind_some, closures_eq] at hq
      simp only [List.getElem?_toArray, List.getElem?_map, List.getElem?_eq_getElem hpn,
        Option.map_some, Option.getD_some] at hq
      obtain ⟨hqn, hq⟩ := (mem_positions_of s _ q).mp hq
      obtain ⟨hq, _⟩ := ((reach_spec s (blank s) _ (by simp) (blank_unmarked s)).2.2 _).mp hq
      rw [hpid] at hq
      exact ⟨hqn, (fuel_union s _ ids _).mpr ⟨id, hid, hq⟩⟩
  · rintro ⟨hqn, hq⟩
    obtain ⟨id, hid, hq⟩ := (fuel_union s _ ids _).mp hq
    have hE : s.trace.experiments[q].id ∈ s.trace.experimentIds :=
      List.mem_map.mpr ⟨_, List.getElem_mem hqn, rfl⟩
    cases hp : (cx).firstPos id with
    | none =>
      exfalso
      -- A non-experiment id adds nothing: its closure is itself.
      have hcl := fuel_closed s (R := [id]) (by
        intro x hx a ha
        simp only [List.mem_singleton] at hx
        subst hx
        rw [adds_none s hp] at ha; cases ha) (n + 1) s.trace.experiments[q].id
      rw [hcl, List.mem_singleton] at hq
      rw [← hq] at hp
      have := (firstPos_isSome s _).mpr hE
      rw [hp] at this; cases this
    | some p =>
      obtain ⟨hpn, hpid⟩ := firstPos_some s hp
      refine ⟨id, hid, ?_⟩
      rw [hp, Option.bind_some, closures_eq]
      simp only [List.getElem?_toArray, List.getElem?_map, List.getElem?_eq_getElem hpn,
        Option.map_some, Option.getD_some]
      rw [mem_positions_of]
      refine ⟨hqn, ((reach_spec s (blank s) _ (by simp) (blank_unmarked s)).2.2 _).mpr ⟨?_, hE⟩⟩
      rw [hpid]; exact hq

end Fvtrace.Proofs.Closure
