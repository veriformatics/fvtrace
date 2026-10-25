import Fvtrace.Proofs.Closure

/-! `Ctx.closureWith` over `Forest.build` = `Scenario.closure` (`kernel.md` P-forest) on every
trace: a forest experiment's parent links reach exactly the experiments its closure holds (each
prerequisite is itself or on its parent's path, and each parent is a prerequisite); any other id
takes the walk `Fvtrace.Proofs.Closure` proves. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false
set_option linter.unusedSectionVars false

namespace Fvtrace.Proofs.Forest
open Fvtrace Fvtrace.Answers Fvtrace.Proofs.Index Fvtrace.Proofs.Lookups
  Fvtrace.Proofs.Positions Fvtrace.Proofs.Closure
open Fvtrace.Proofs.Plan (adds closureFuelRef mem_closureStep closureFuel_eq_ref closureFuel_succ
  mem_closureFuel closureFuelRef_mono)

/-! ## Paths up parent links -/

/-- `q` is reached from `p` by following parent links. -/
inductive Reaches (A : Array (Option Nat)) : Nat → Nat → Prop
  | refl (p : Nat) : Reaches A p p
  | step {p r q : Nat} : A[p]? = some (some r) → Reaches A r q → Reaches A p q

/-- Each link points to an earlier position. -/
abbrev Decreasing (A : Array (Option Nat)) : Prop :=
  ∀ (k r : Nat), A[k]? = some (some r) → r < k

theorem reaches_trans {A : Array (Option Nat)} {p q r : Nat} (h1 : Reaches A p q)
    (h2 : Reaches A q r) : Reaches A p r := by
  induction h1 with
  | refl => exact h2
  | step h _ ih => exact .step h (ih h2)

theorem reaches_le {A : Array (Option Nat)} (hdec : Decreasing A) {p q : Nat} (h : Reaches A p q) :
    q ≤ p := by
  induction h with
  | refl => exact Nat.le_refl _
  | step h _ ih => exact Nat.le_trans ih (Nat.le_of_lt (hdec _ _ h))

theorem reaches_link {A : Array (Option Nat)} {p q r : Nat} (h : A[p]? = some (some r)) :
    Reaches A p q ↔ q = p ∨ Reaches A r q := by
  constructor
  · intro hr
    cases hr with
    | refl => exact Or.inl rfl
    | step h' hr' =>
      rw [h] at h'
      cases h'
      exact Or.inr hr'
  · rintro (rfl | hr)
    · exact .refl _
    · exact .step h hr

theorem reaches_root {A : Array (Option Nat)} {p q : Nat} (h : ∀ r, A[p]? ≠ some (some r)) :
    Reaches A p q ↔ q = p := by
  constructor
  · intro hr
    cases hr with
    | refl => rfl
    | step h' _ => exact absurd h' (h _)
  · rintro rfl; exact .refl _

theorem onPath_sound (A : Array (Option Nat)) :
    ∀ fuel p q, onPath A fuel p q = true → Reaches A p q
  | 0, _, _, h => by simp [onPath] at h
  | fuel + 1, p, q, h => by
    unfold onPath at h
    rcases Bool.or_eq_true_iff.mp h with h | h
    · rw [beq_iff_eq.mp h]; exact .refl _
    · rw [Bool.and_eq_true] at h
      split at h
      · rename_i r hr
        exact .step hr (onPath_sound A fuel r q h.2)
      · simp at h

theorem mem_pathUp (A : Array (Option Nat)) (hdec : Decreasing A) :
    ∀ fuel p (acc : List Nat), p < fuel → ∀ q, q ∈ pathUp A fuel p acc ↔ Reaches A p q ∨ q ∈ acc
  | 0, _, _, h, _ => absurd h (Nat.not_lt_zero _)
  | fuel + 1, p, acc, h, q => by
    unfold pathUp
    split
    · rename_i r hr
      have hrp := hdec p r hr
      rw [mem_pathUp A hdec fuel r (p :: acc) (by omega) q, reaches_link hr, List.mem_cons]
      constructor
      · rintro (h | h | h)
        · exact Or.inl (Or.inr h)
        · exact Or.inl (Or.inl h)
        · exact Or.inr h
      · rintro ((h | h) | h)
        · exact Or.inr (Or.inl h)
        · exact Or.inl h
        · exact Or.inr (Or.inr h)
    · rename_i hn
      rw [List.mem_cons, reaches_root (fun r hr => hn r hr)]

/-- A path from below an array's size reads the same links once the array grows. -/
theorem reaches_push {A : Array (Option Nat)} {x : Option Nat} (hdec : Decreasing A) {p q : Nat}
    (hp : p < A.size) : Reaches (A.push x) p q ↔ Reaches A p q := by
  have hget : ∀ k, k < A.size → (A.push x)[k]? = A[k]? := by
    intro k hk
    simp [Array.getElem?_push, Nat.ne_of_lt hk]
  constructor
  · intro h
    induction h with
    | refl => exact .refl _
    | @step p r q hr _ ih =>
      rw [hget p hp] at hr
      exact .step hr (ih (Nat.lt_trans (hdec p r hr) hp))
  · intro h
    induction h with
    | refl => exact .refl _
    | @step p r q hr _ ih =>
      have hr' := hr
      rw [← hget p hp] at hr'
      exact .step hr' (ih (Nat.lt_trans (hdec p r hr) hp))

/-! ## The links `Forest.build` sets -/

section Build

variable (s : Scenario)

local notation "cx" => Ctx.build s.trace
local notation "n" => s.trace.experiments.length

/-- What the links built so far guarantee about the positions they cover: a link points to an
earlier forest position that is one of the child's prerequisites, and each prerequisite of a
forest position is itself or on its parent's path. -/
structure LinkInv (st : Array (Option Nat) × Array Bool) : Prop where
  size : st.2.size = st.1.size
  dec : Decreasing st.1
  parent : ∀ (k r : Nat), st.1[k]? = some (some r) →
    st.2[r]? = some true ∧ st.2[k]? = some true ∧
      ∃ e : Experiment, s.trace.experiments[k]? = some e ∧
        ∃ x ∈ adds s e.id, (cx).firstPos x = some r
  deps : ∀ (k : Nat) (e : Experiment), s.trace.experiments[k]? = some e → st.2[k]? = some true →
    ∀ x ∈ adds s e.id, ∀ (q : Nat), (cx).firstPos x = some q →
      q = k ∨ ∃ r, st.1[k]? = some (some r) ∧ Reaches st.1 r q

theorem push_get {α : Type} {A : Array α} {x : α} {k : Nat} (hk : k < A.size) :
    (A.push x)[k]? = A[k]? := by
  simp [Array.getElem?_push, Nat.ne_of_lt hk]

theorem get_size_lt {α : Type} {A : Array α} {k : Nat} {x : α} (h : A[k]? = some x) :
    k < A.size := by
  rcases Nat.lt_or_ge k A.size with hk | hk
  · exact hk
  · rw [Array.getElem?_eq_none hk] at h; cases h

/-- Pushing one link keeps the guarantees (`Forest.link`'s three branches). -/
theorem link_inv {st : Array (Option Nat) × Array Bool} (h : LinkInv s st) {e : Experiment}
    (he : s.trace.experiments[st.1.size]? = some e) : LinkInv s (Forest.link (cx) st e) := by
  have hsz := h.size
  -- The positions of `e`'s declared prerequisites other than itself.
  have hdeps : ∀ x ∈ adds s e.id, ∀ q, (cx).firstPos x = some q → q ≠ st.1.size →
      q ∈ (((cx).adds e.id).filterMap (cx).firstPos).filter (· != st.1.size) := by
    intro x hx q hq hne
    rw [List.mem_filter, List.mem_filterMap, adds_eq]
    exact ⟨⟨x, hx, hq⟩, by simpa using hne⟩
  -- Links below the new position are the old ones.
  have keep : ∀ (A : Array (Option Nat)) (G : Array Bool), A = st.1.push (A.back?.getD none) →
      True := fun _ _ _ => trivial
  clear keep
  unfold Forest.link
  dsimp only
  split
  · -- A root: no prerequisite but itself.
    rename_i hnone
    rw [List.max?_eq_none_iff] at hnone
    refine ⟨by simp [hsz], ?_, ?_, ?_⟩
    · intro k r hk
      rw [Array.getElem?_push] at hk
      split at hk
      · cases hk
      · exact h.dec k r hk
    · intro k r hk
      rw [Array.getElem?_push] at hk
      split at hk
      · cases hk
      · have hkl := get_size_lt hk
        obtain ⟨h1, h2, h3⟩ := h.parent k r hk
        have hr := h.dec k r hk
        refine ⟨?_, ?_, h3⟩
        · rw [push_get (by omega)]; exact h1
        · rw [push_get (by omega)]; exact h2
    · intro k e' he' hg x hx q hq
      by_cases hk : k = st.1.size
      · subst hk
        rw [he] at he'
        cases he'
        refine Classical.byContradiction fun hne => ?_
        have hq' := hdeps x hx q hq (by omega)
        rw [hnone] at hq'
        cases hq'
      · have hkl : k < st.1.size := by
          have := get_size_lt hg
          simp only [Array.size_push] at this
          omega
        rw [push_get (by omega)] at hg
        rcases h.deps k e' he' hg x hx q hq with hq' | ⟨r, hr, hreach⟩
        · exact Or.inl hq'
        · refine Or.inr ⟨r, by rw [push_get hkl]; exact hr, ?_⟩
          exact (reaches_push h.dec (Nat.lt_trans (h.dec k r hr) hkl)).mpr hreach
  · rename_i p hp
    have hpmem := List.max?_mem hp
    split
    · -- A forest link: the latest prerequisite, every other one on its path.
      rename_i hc
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
      obtain ⟨⟨hpi, hgp⟩, hall⟩ := hc
      have hgp' : st.2[p]? = some true := by
        cases hh : st.2[p]? with
        | none => rw [hh] at hgp; cases hgp
        | some b => rw [hh] at hgp; simp at hgp; rw [hgp]
      have hdec' : Decreasing (st.1.push (some p)) := by
        intro k r hk
        rw [Array.getElem?_push] at hk
        split at hk
        · rename_i hk'
          cases hk
          omega
        · exact h.dec k r hk
      refine ⟨by simp [hsz], hdec', ?_, ?_⟩
      · intro k r hk
        rw [Array.getElem?_push] at hk
        split at hk
        · rename_i hk'
          cases hk
          subst hk'
          refine ⟨by rw [push_get (by omega)]; exact hgp', by rw [← hsz, Array.getElem?_push_size],
            e, he, ?_⟩
          rw [List.mem_filter, List.mem_filterMap] at hpmem
          obtain ⟨⟨x, hx, hxp⟩, _⟩ := hpmem
          rw [adds_eq] at hx
          exact ⟨x, hx, hxp⟩
        · have hkl := get_size_lt hk
          obtain ⟨h1, h2, h3⟩ := h.parent k r hk
          have hr := h.dec k r hk
          exact ⟨by rw [push_get (by omega)]; exact h1, by rw [push_get (by omega)]; exact h2, h3⟩
      · intro k e' he' hg x hx q hq
        by_cases hk : k = st.1.size
        · subst hk
          rw [he] at he'
          cases he'
          by_cases hqk : q = st.1.size
          · exact Or.inl hqk
          · right
            refine ⟨p, by simp, ?_⟩
            have hon := List.all_eq_true.mp hall q (hdeps x hx q hq hqk)
            exact (reaches_push h.dec hpi).mpr (onPath_sound st.1 _ p q hon)
        · have hkl : k < st.1.size := by
            have := get_size_lt hg
            simp only [Array.size_push] at this
            omega
          rw [push_get (by omega)] at hg
          rcases h.deps k e' he' hg x hx q hq with hq' | ⟨r, hr, hreach⟩
          · exact Or.inl hq'
          · refine Or.inr ⟨r, by rw [push_get hkl]; exact hr, ?_⟩
            exact (reaches_push h.dec (Nat.lt_trans (h.dec k r hr) hkl)).mpr hreach
    · -- Off the forest: no link, not good.
      refine ⟨by simp [hsz], ?_, ?_, ?_⟩
      · intro k r hk
        rw [Array.getElem?_push] at hk
        split at hk
        · cases hk
        · exact h.dec k r hk
      · intro k r hk
        rw [Array.getElem?_push] at hk
        split at hk
        · cases hk
        · have hkl := get_size_lt hk
          obtain ⟨h1, h2, h3⟩ := h.parent k r hk
          have hr := h.dec k r hk
          exact ⟨by rw [push_get (by omega)]; exact h1, by rw [push_get (by omega)]; exact h2, h3⟩
      · intro k e' he' hg x hx q hq
        by_cases hk : k = st.1.size
        · subst hk
          rw [← hsz, Array.getElem?_push_size] at hg
          cases hg
        · have hkl : k < st.1.size := by
            have := get_size_lt hg
            simp only [Array.size_push] at this
            omega
          rw [push_get (by omega)] at hg
          rcases h.deps k e' he' hg x hx q hq with hq' | ⟨r, hr, hreach⟩
          · exact Or.inl hq'
          · refine Or.inr ⟨r, by rw [push_get hkl]; exact hr, ?_⟩
            exact (reaches_push h.dec (Nat.lt_trans (h.dec k r hr) hkl)).mpr hreach

theorem foldl_inv : ∀ (L : List Experiment) (st : Array (Option Nat) × Array Bool),
    LinkInv s st → (∀ j e, L[j]? = some e → s.trace.experiments[st.1.size + j]? = some e) →
    LinkInv s (L.foldl (Forest.link (cx)) st) ∧
      (L.foldl (Forest.link (cx)) st).1.size = st.1.size + L.length
  | [], st, h, _ => ⟨h, by simp⟩
  | e :: L, st, h, hL => by
    have he : s.trace.experiments[st.1.size]? = some e := by simpa using hL 0 e rfl
    have h' := link_inv s h he
    have hsz : (Forest.link (cx) st e).1.size = st.1.size + 1 := by
      unfold Forest.link; dsimp only; split
      · simp
      · split <;> simp
    obtain ⟨h1, h2⟩ := foldl_inv L _ h' (by
      intro j e' hj
      rw [hsz, Nat.add_assoc, Nat.add_comm 1 j]
      exact hL (j + 1) e' (by simpa using hj))
    refine ⟨by simpa using h1, ?_⟩
    simp only [List.foldl_cons, List.length_cons]
    rw [h2, hsz]; omega

/-- The forest's links hold the guarantees over every experiment position. -/
theorem build_inv : LinkInv s ((Forest.build (cx)).parent, (Forest.build (cx)).good) ∧
    (Forest.build (cx)).parent.size = n := by
  unfold Forest.build
  dsimp only
  split
  · rw [ctx_experiments, List.foldl_toArray]
    have := foldl_inv s s.trace.experiments (#[], #[])
      ⟨rfl, fun _ _ h => by simp at h, fun _ _ h => by simp at h, fun _ _ _ h => by simp at h⟩
      (fun j e h => by simpa using h)
    exact ⟨this.1, by simpa using this.2⟩
  · refine ⟨⟨by simp, ?_, ?_, ?_⟩, by simp [ctx_experiments]⟩
    · intro k r hk; simp at hk
    · intro k r hk; simp at hk
    · intro k e _ hg; simp at hg

/-- A forest position needs distinct experiment ids (`Forest.build` sets none otherwise). -/
theorem good_nodup {p : Nat} (hp : (Forest.build (cx)).good[p]? = some true) :
    (s.trace.experiments.map (·.id)).Nodup := by
  revert hp
  unfold Forest.build
  dsimp only
  split
  · rename_i hn
    intro _
    rw [show (cx).L = Lookups.reference s.trace from fast_eq_reference s.trace,
      ctx_experiments] at hn
    simpa [Lookups.reference] using hn
  · intro hp; simp at hp

theorem reaches_good {p q : Nat} (h : Reaches (Forest.build (cx)).parent p q)
    (hp : (Forest.build (cx)).good[p]? = some true) :
    (Forest.build (cx)).good[q]? = some true := by
  induction h with
  | refl => exact hp
  | step hr _ ih => exact ih ((build_inv s).1.parent _ _ hr).1

end Build

/-! ## A forest experiment's closure = its path -/

section Closure

variable (s : Scenario)

local notation "cx" => Ctx.build s.trace
local notation "n" => s.trace.experiments.length
local notation "fo" => Forest.build (Ctx.build s.trace)

theorem fuel_mono {f : Nat} {ids : List String} {x : String} (h : x ∈ closureFuelRef s f ids) :
    ∀ k, x ∈ closureFuelRef s (f + k) ids
  | 0 => h
  | k + 1 => by
    rw [← Nat.add_assoc, closureFuel_succ]
    exact (mem_closureStep s).mpr (Or.inl (fuel_mono h k))

/-- Every position on a forest experiment's path is in its closure, within as many steps as its
position allows. -/
theorem path_in_closure {p q : Nat} (h : Reaches (fo).parent p q)
    (hp : (fo).good[p]? = some true) :
    ∃ hq : q < n, ∃ hp' : p < n,
      s.trace.experiments[q].id ∈ closureFuelRef s (p + 1) [s.trace.experiments[p].id] := by
  have hinv := (build_inv s).1
  have hsize : (fo).good.size = n := by rw [hinv.size, (build_inv s).2]
  have hpn : p < n := by have := get_size_lt hp; omega
  induction h with
  | refl p =>
    exact ⟨hpn, hpn, mem_closureFuel s (List.mem_singleton.mpr rfl)⟩
  | @step p r q hr hrq ih =>
    obtain ⟨hgr, _, e, he, x, hx, hxr⟩ := hinv.parent p r hr
    have hrp := hinv.dec p r hr
    obtain ⟨hqn, hrn, hmem⟩ := ih hgr (by omega)
    refine ⟨hqn, hpn, ?_⟩
    obtain ⟨hrn', hxid⟩ := firstPos_some s hxr
    have hep : s.trace.experiments[p] = e := by
      rw [List.getElem?_eq_getElem hpn] at he; exact Option.some.inj he
    -- One step from `p` adds `r`; the rest of `r`'s path follows within `r + 1` steps.
    have hstep : s.trace.experiments[r].id ∈ s.closureStep [s.trace.experiments[p].id] := by
      rw [mem_closureStep]
      exact Or.inr ⟨_, List.mem_singleton.mpr rfl, by rw [hep, hxid]; exact hx⟩
    have h1 : s.trace.experiments[q].id ∈ closureFuelRef s (r + 1)
        (s.closureStep [s.trace.experiments[p].id]) :=
      closureFuelRef_mono s (fun y hy => by
        rw [List.mem_singleton] at hy; rw [hy]; exact hstep) _ _ hmem
    have h2 : s.trace.experiments[q].id ∈ closureFuelRef s (r + 1 + 1)
        [s.trace.experiments[p].id] := h1
    have := fuel_mono s h2 (p - r - 1)
    rwa [show r + 1 + 1 + (p - r - 1) = p + 1 by omega] at this

/-- The closure of a forest experiment holds only its path's experiments (+ ids naming none). -/
theorem closure_in_path {p : Nat} (hp : (fo).good[p]? = some true) (hpn : p < n) :
    ∀ f x, x ∈ closureFuelRef s f [s.trace.experiments[p].id] →
      (∃ j, ∃ hj : j < n, Reaches (fo).parent p j ∧ s.trace.experiments[j].id = x) ∨
        (cx).firstPos x = none := by
  have hinv := (build_inv s).1
  intro f
  induction f with
  | zero =>
    intro x hx
    rw [show closureFuelRef s 0 [s.trace.experiments[p].id] = [s.trace.experiments[p].id] from rfl,
      List.mem_singleton] at hx
    exact Or.inl ⟨p, hpn, .refl _, hx.symm⟩
  | succ f ih =>
    intro x hx
    rw [closureFuel_succ] at hx
    rcases (mem_closureStep s).mp hx with hx | ⟨y, hy, hxy⟩
    · exact ih x hx
    · rcases ih y hy with ⟨j, hjn, hpj, hjy⟩ | hy0
      · cases hxq : (cx).firstPos x with
        | none => exact Or.inr rfl
        | some q =>
          obtain ⟨hqn, hqx⟩ := firstPos_some s hxq
          have hgj := reaches_good s hpj hp
          rw [← hjy] at hxy
          rcases hinv.deps j _ (List.getElem?_eq_getElem hjn) hgj x hxy q hxq with
            hq | ⟨r, hr, hrq⟩
          · exact Or.inl ⟨q, hqn, hq ▸ hpj, hqx⟩
          · exact Or.inl ⟨q, hqn, reaches_trans hpj (.step hr hrq), hqx⟩
      · rw [adds_none s hy0] at hxy; cases hxy

/-- A forest experiment's path = the experiments of its closure. -/
theorem path_iff {p : Nat} (hp : (fo).good[p]? = some true) (q : Nat) :
    Reaches (fo).parent p q ↔ ∃ hq : q < n, ∃ hp' : p < n,
      s.trace.experiments[q].id ∈ closureFuelRef s (n + 1) [s.trace.experiments[p].id] := by
  have hinv := (build_inv s).1
  have hsize : (fo).good.size = n := by rw [hinv.size, (build_inv s).2]
  have hpn : p < n := by have := get_size_lt hp; omega
  constructor
  · intro h
    obtain ⟨hqn, _, hmem⟩ := path_in_closure s h hp
    refine ⟨hqn, hpn, ?_⟩
    have := fuel_mono s hmem (n - p)
    rwa [show p + 1 + (n - p) = n + 1 by omega] at this
  · rintro ⟨hqn, _, hmem⟩
    rcases closure_in_path s hp hpn _ _ hmem with ⟨j, hjn, hpj, hjq⟩ | h0
    · have hnd := good_nodup s hp
      have : j = q := by
        apply hnd.eq_of_getElem_eq (by simpa using hjn) (by simpa using hqn)
        simpa using hjq
      rw [← this]; exact hpj
    · exfalso
      have hE : s.trace.experiments[q].id ∈ s.trace.experimentIds :=
        List.mem_map.mpr ⟨_, List.getElem_mem hqn, rfl⟩
      have := (firstPos_isSome s _).mpr hE
      rw [h0] at this; cases this

theorem path?_mem {p : Nat} {ps : List Nat} (h : (fo).path? p = some ps) (q : Nat) :
    q ∈ ps ↔ ∃ hq : q < n, ∃ hp' : p < n,
      s.trace.experiments[q].id ∈ closureFuelRef s (n + 1) [s.trace.experiments[p].id] := by
  unfold Forest.path? at h
  split at h
  · rename_i hg
    cases h
    have hg' : (fo).good[p]? = some true := by
      cases hh : (fo).good[p]? with
      | none => rw [hh] at hg; cases hg
      | some b => rw [hh] at hg; simp at hg; rw [hg]
    have hinv := (build_inv s).1
    have hsize : (fo).good.size = n := by rw [hinv.size, (build_inv s).2]
    have hpn : p < n := by have := get_size_lt hg'; omega
    rw [mem_pathUp _ hinv.dec _ _ _ (by omega), List.mem_nil_iff, or_false]
    exact path_iff s hg' q
  · cases h

/-- The forest closure = `Scenario.closure`, on every trace. -/
theorem closureWith_eq : (cx).closureWith fo = s.closure := by
  funext ids
  unfold Ctx.closureWith Scenario.closure
  rw [closureFuel_eq_ref]
  have hsize : (cx).experiments.size = n := by rw [ctx_experiments, List.size_toArray]
  apply read_closure
  intro q
  rw [List.mem_flatMap]
  constructor
  · rintro ⟨id, hid, hq⟩
    cases hp : (cx).firstPos id with
    | none => rw [hp] at hq; cases hq
    | some p =>
      rw [hp] at hq
      obtain ⟨hpn, hpid⟩ := firstPos_some s hp
      dsimp only at hq
      cases hps : (fo).path? p with
      | some ps =>
        rw [hps] at hq
        obtain ⟨hqn, _, hmem⟩ := (path?_mem s hps q).mp hq
        rw [hpid] at hmem
        exact ⟨hqn, (fuel_union s _ ids _).mpr ⟨id, hid, hmem⟩⟩
      | none =>
        rw [hps] at hq
        dsimp only at hq
        rw [hsize] at hq
        obtain ⟨hqn, hq⟩ := (mem_positions_of s _ q).mp hq
        obtain ⟨hq, _⟩ := ((reach_spec s (blank s) _ (by simp) (blank_unmarked s)).2.2 _).mp hq
        exact ⟨hqn, (fuel_union s _ ids _).mpr ⟨id, hid, hq⟩⟩
  · rintro ⟨hqn, hq⟩
    obtain ⟨id, hid, hq⟩ := (fuel_union s _ ids _).mp hq
    have hE : s.trace.experiments[q].id ∈ s.trace.experimentIds :=
      List.mem_map.mpr ⟨_, List.getElem_mem hqn, rfl⟩
    refine ⟨id, hid, ?_⟩
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
      dsimp only
      cases hps : (fo).path? p with
      | some ps =>
        dsimp only
        rw [path?_mem s hps q]
        exact ⟨hqn, hpn, by rw [hpid]; exact hq⟩
      | none =>
        dsimp only
        rw [hsize, mem_positions_of]
        exact ⟨hqn, ((reach_spec s (blank s) _ (by simp) (blank_unmarked s)).2.2 _).mpr ⟨hq, hE⟩⟩

end Closure

end Fvtrace.Proofs.Forest
