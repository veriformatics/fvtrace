import Fvtrace.Proofs.Engine

/-! Proofs of the plan claims G4a + G4b in `Fvtrace.Spec.Engine`: the closure reaches its fixed
point within its fuel, experiments outside the relevant set never raise a claim (pruning), and
the search keeps a best candidate. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false

namespace Fvtrace.Proofs.Plan
open Fvtrace Fvtrace.Spec Fvtrace.Proofs.Engine

theorem experiment?_mem {t : Trace} {id : String} {e : Experiment}
    (h : t.experiment? id = some e) : e ∈ t.experiments ∧ e.id = id := by
  unfold Trace.experiment? at h
  exact ⟨List.mem_of_find?_eq_some h, by simpa using List.find?_some h⟩

theorem subject?_mem {t : Trace} {id : String} {sub : Subject}
    (h : t.subject? id = some sub) : sub ∈ t.subjects := by
  unfold Trace.subject? at h
  exact List.mem_of_find?_eq_some h

/-! ## Closure -/

section Closure

variable (s : Scenario)

/-- What one member adds to the closure. -/
def adds (id : String) : List String :=
  match s.trace.experiment? id with
  | some e => e.requires ++
    (match s.trace.subject? e.subject with
     | some sub => sub.createdBy.toList
     | none => [])
  | none => []

theorem mem_closureStep {ids : List String} {x : String} :
    x ∈ s.closureStep ids ↔ x ∈ ids ∨ ∃ id ∈ ids, x ∈ adds s id := by
  unfold Scenario.closureStep adds
  simp only [List.mem_append, List.mem_flatMap]
  exact Iff.rfl

theorem closureStep_same {a b : List String} (h : ∀ x, x ∈ a ↔ x ∈ b) (x : String) :
    x ∈ s.closureStep a ↔ x ∈ s.closureStep b := by
  simp only [mem_closureStep, h]

theorem closureFuel_succ (n : Nat) (ids : List String) :
    s.closureFuel (n + 1) ids = s.closureStep (s.closureFuel n ids) := by
  induction n generalizing ids with
  | zero => rfl
  | succ n ih => exact ih (s.closureStep ids)

theorem mem_closureFuel {n : Nat} {ids : List String} {x : String} (h : x ∈ ids) :
    x ∈ s.closureFuel n ids := by
  induction n with
  | zero => exact h
  | succ n ih => rw [closureFuel_succ]; exact (mem_closureStep s).mpr (Or.inl ih)

theorem fixed_from {ids : List String} {m : Nat}
    (hf : ∀ x ∈ s.closureStep (s.closureFuel m ids), x ∈ s.closureFuel m ids) (k : Nat) :
    ∀ x, x ∈ s.closureFuel (m + k) ids ↔ x ∈ s.closureFuel m ids := by
  induction k with
  | zero => intro x; exact Iff.rfl
  | succ k ih =>
    intro x
    rw [← Nat.add_assoc, closureFuel_succ, closureStep_same s ih]
    exact ⟨hf x, fun h => (mem_closureStep s).mpr (Or.inl h)⟩

theorem adds_mem (hwf : WellFormed s.trace) {id x : String} (h : x ∈ adds s id) :
    x ∈ s.trace.experimentIds := by
  unfold adds at h
  split at h
  · rename_i e he
    rcases List.mem_append.mp h with hr | hc
    · exact (hwf.2.1.2.2.1 e (experiment?_mem he).1).2.2 x hr
    · split at hc
      · rename_i sub hsub
        exact hwf.2.1.2.2.2.2.1 sub (subject?_mem hsub) x (by simpa using hc)
      · cases hc
  · cases h

/-- Experiment ids a list holds (the measure the fuel bound counts). -/
def count (l : List String) : Nat := (s.trace.experimentIds.filter l.contains).length

theorem filter_length_le {E : List String} {p q : String → Bool}
    (hpq : ∀ x ∈ E, p x = true → q x = true) : (E.filter p).length ≤ (E.filter q).length := by
  induction E with
  | nil => simp
  | cons a E ih =>
    have ih := ih fun x hx => hpq x (List.mem_cons_of_mem a hx)
    by_cases hpa : p a = true
    · have hqa := hpq a (by simp) hpa
      simp [List.filter_cons, hpa, hqa]; omega
    · by_cases hqa : q a = true
      · simp [List.filter_cons, hpa, hqa]; omega
      · simp [List.filter_cons, hpa, hqa]; omega

theorem filter_length_lt {E : List String} {p q : String → Bool}
    (hpq : ∀ x ∈ E, p x = true → q x = true) {y : String} (hy : y ∈ E) (hq : q y = true)
    (hp : p y = false) : (E.filter p).length < (E.filter q).length := by
  induction E with
  | nil => cases hy
  | cons a E ih =>
    have hpq' : ∀ x ∈ E, p x = true → q x = true := fun x hx =>
      hpq x (List.mem_cons_of_mem a hx)
    by_cases hya : y = a
    · subst hya
      have := filter_length_le hpq'
      simp [List.filter_cons, hp, hq]; omega
    · have hyE : y ∈ E := by simpa [hya] using hy
      have := ih hpq' hyE
      by_cases hpa : p a = true
      · simp [List.filter_cons, hpa, hpq a (by simp) hpa]; omega
      · by_cases hqa : q a = true
        · simp [List.filter_cons, hpa, hqa]; omega
        · simp [List.filter_cons, hpa, hqa]; omega

/-- Each closure step either reaches a fixed point or adds an experiment id. -/
theorem fuel_fixed (hwf : WellFormed s.trace) (ids : List String) (n : Nat) :
    (∃ m ≤ n, ∀ x ∈ s.closureStep (s.closureFuel m ids), x ∈ s.closureFuel m ids) ∨
      n ≤ count s (s.closureFuel n ids) := by
  induction n with
  | zero => exact Or.inr (Nat.zero_le _)
  | succ n ih =>
    rcases ih with ⟨m, hm, hf⟩ | hle
    · exact Or.inl ⟨m, Nat.le_succ_of_le hm, hf⟩
    · by_cases hf : ∀ x ∈ s.closureStep (s.closureFuel n ids), x ∈ s.closureFuel n ids
      · exact Or.inl ⟨n, Nat.le_succ n, hf⟩
      · right
        obtain ⟨x, hx⟩ := Classical.not_forall.mp hf
        have hxs : x ∈ s.closureStep (s.closureFuel n ids) :=
          Classical.byContradiction fun h => hx fun h' => absurd h' h
        have hxn : x ∉ s.closureFuel n ids := fun h => hx fun _ => h
        have hxE : x ∈ s.trace.experimentIds := by
          rcases (mem_closureStep s).mp hxs with h | ⟨id, _, h⟩
          · exact absurd h hxn
          · exact adds_mem s hwf h
        have hlt : count s (s.closureFuel n ids) < count s (s.closureFuel (n + 1) ids) := by
          rw [closureFuel_succ]
          unfold count
          refine filter_length_lt ?_ hxE ?_ ?_
          · intro z _ hz
            rw [List.contains_iff_mem] at hz ⊢
            exact (mem_closureStep s).mpr (Or.inl hz)
          · exact List.contains_iff_mem.mpr hxs
          · cases h : (s.closureFuel n ids).contains x
            · rfl
            · exact absurd (List.contains_iff_mem.mp h) hxn
        omega

/-- The fuel `experiments.length + 1` reaches the fixed point. -/
theorem closure_fixed (hwf : WellFormed s.trace) (ids : List String) :
    ∀ x ∈ s.closureStep (s.closureFuel (s.trace.experiments.length + 1) ids),
      x ∈ s.closureFuel (s.trace.experiments.length + 1) ids := by
  rcases fuel_fixed s hwf ids (s.trace.experiments.length + 1) with ⟨m, hm, hf⟩ | hle
  · obtain ⟨k, hk⟩ := Nat.exists_eq_add_of_le hm
    rw [hk]
    intro x hx
    have h1 := fixed_from s hf (k + 1) x
    rw [← Nat.add_assoc, closureFuel_succ] at h1
    exact (fixed_from s hf k x).mpr (h1.mp hx)
  · exfalso
    have hb := List.length_filter_le
      (s.closureFuel (s.trace.experiments.length + 1) ids).contains s.trace.experimentIds
    simp only [Trace.experimentIds, List.length_map] at hb
    unfold count at hle
    simp only [Trace.experimentIds] at hle
    omega

theorem mem_closure_iff {ids : List String} {x : String} :
    x ∈ s.closure ids ↔
      x ∈ s.trace.experimentIds ∧ x ∈ s.closureFuel (s.trace.experiments.length + 1) ids := by
  simp only [Scenario.closure, List.mem_filter, List.contains_iff_mem]

theorem closure_closed (hwf : WellFormed s.trace) (ids : List String) :
    Closed s.trace (s.closure ids) := by
  intro id hid e he
  have hidM := ((mem_closure_iff s).mp hid).2
  have hadds : ∀ x ∈ adds s id, x ∈ s.closure ids := fun x hx =>
    (mem_closure_iff s).mpr ⟨adds_mem s hwf hx,
      closure_fixed s hwf ids x ((mem_closureStep s).mpr (Or.inr ⟨id, hidM, hx⟩))⟩
  refine ⟨fun r hr => hadds r ?_, fun sub hsub x hx => hadds x ?_⟩
  · simp [adds, he, hr]
  · simp [adds, he, hsub, hx]

theorem closure_subset {ids q : List String} (hq : Closed s.trace q) (h : ∀ x ∈ ids, x ∈ q) :
    ∀ x ∈ s.closure ids, x ∈ q := by
  have hfuel : ∀ n, ∀ x ∈ s.closureFuel n ids, x ∈ q := by
    intro n
    induction n with
    | zero => exact h
    | succ n ih =>
      intro x hx
      rw [closureFuel_succ] at hx
      rcases (mem_closureStep s).mp hx with hx | ⟨id, hid, hx⟩
      · exact ih x hx
      · unfold adds at hx
        split at hx
        · rename_i e he
          rcases List.mem_append.mp hx with hr | hc
          · exact (hq id (ih id hid) e he).1 x hr
          · split at hc
            · rename_i sub hsub
              exact (hq id (ih id hid) e he).2 sub hsub x (by simpa using hc)
            · cases hc
        · cases hx
  intro x hx
  exact hfuel _ x ((mem_closure_iff s).mp hx).2

theorem mem_closure {ids : List String} {x : String} (hx : x ∈ ids)
    (hE : x ∈ s.trace.experimentIds) : x ∈ s.closure ids :=
  (mem_closure_iff s).mpr ⟨hE, mem_closureFuel s hx⟩

end Closure

/-! ## Applying successes -/

section Success

variable (s : Scenario)

/-- A status's strength. -/
abbrev str (st : Status) : Nat := (EStatus.ofStatus st).strength

theorem asserted_str {st : Status} (h : st.asserted = true) : 2 ≤ str st := by
  cases st <;> simp_all [Status.asserted] <;> decide

theorem stronger_ge_left (a b : Status) : str a ≤ str (a.stronger b) := by
  unfold Status.stronger; split <;> simp only [str] at * <;> omega

theorem stronger_ge_right (a b : Status) : str b ≤ str (a.stronger b) := by
  unfold Status.stronger; split <;> simp only [str] at * <;> omega

theorem stronger_cases (a b : Status) : a.stronger b = a ∨ a.stronger b = b := by
  unfold Status.stronger; split <;> simp

theorem foldl_stronger_ge_init (l : List Status) :
    ∀ init, str init ≤ str (l.foldl Status.stronger init) := by
  induction l with
  | nil => intro init; exact Nat.le_refl _
  | cons a l ih => intro init; exact Nat.le_trans (stronger_ge_left init a) (ih _)

theorem foldl_stronger_ge_mem (l : List Status) :
    ∀ init, ∀ st ∈ l, str st ≤ str (l.foldl Status.stronger init) := by
  induction l with
  | nil => intro _ _ h; cases h
  | cons a l ih =>
    intro init st hst
    rcases List.mem_cons.mp hst with rfl | h
    · exact Nat.le_trans (stronger_ge_right init st) (foldl_stronger_ge_init l _)
    · exact ih _ st h

theorem foldl_stronger_cases (l : List Status) :
    ∀ init, l.foldl Status.stronger init = init ∨ l.foldl Status.stronger init ∈ l := by
  induction l with
  | nil => intro init; exact Or.inl rfl
  | cons a l ih =>
    intro init
    rcases ih (init.stronger a) with h | h
    · rcases stronger_cases init a with h' | h'
      · exact Or.inl (h.trans h')
      · exact Or.inr (by rw [List.foldl_cons, h, h']; exact List.mem_cons_self)
    · exact Or.inr (List.mem_cons_of_mem a h)

theorem mem_successPairs {ids : List String} {p : String × Status} :
    p ∈ s.successPairs ids ↔
      ∃ id ∈ ids, ∃ e, s.trace.experiment? id = some e ∧ p ∈ e.success := by
  unfold Scenario.successPairs
  simp only [List.mem_flatMap]
  constructor
  · rintro ⟨id, hid, hp⟩
    cases he : s.trace.experiment? id with
    | none => simp [he] at hp
    | some e => exact ⟨id, hid, e, he, by simpa [he] using hp⟩
  · rintro ⟨id, hid, e, he, hp⟩
    exact ⟨id, hid, by simpa [he] using hp⟩

/-- The value `merged ids` gives fact `k`. -/
def top (ids : List String) (k : String) : Status :=
  (((s.successPairs ids).filter (·.1 == k)).map (·.2)).foldl Status.stronger .assumed

theorem lookup_graph (l : List String) (g : String → Status) (P : String × Status → Bool)
    (k : String) :
    ((l.map fun k' => (k', g k')).filter P).lookup k =
      if k ∈ l ∧ P (k, g k) = true then some (g k) else none := by
  induction l with
  | nil => simp
  | cons a l ih =>
    by_cases hka : k = a
    · subst hka
      by_cases hP : P (k, g k) = true
      · simp [List.filter_cons, hP, List.lookup]
      · simp [List.filter_cons, hP, ih]
    · have hne : (k == a) = false := by simp [hka]
      by_cases hP : P (a, g a) = true
      · simp [List.filter_cons, hP, List.lookup, hne, ih, hka]
      · simp [List.filter_cons, hP, ih, hka]

theorem lookup_filter_absent {extra : Overrides} {j : String} (h : extra.lookup j = none) :
    ∀ o : Overrides,
      (o.filter fun (k, _) => !extra.any (·.1 == k)).lookup j = o.lookup j := by
  intro o
  induction o with
  | nil => rfl
  | cons p ps ih =>
    obtain ⟨k, st⟩ := p
    by_cases hk : extra.any (·.1 == k) = true
    · have hkj : k ≠ j := by
        rintro rfl
        obtain ⟨q, hq, hqk⟩ := List.any_eq_true.mp hk
        have := (List.lookup_eq_none_iff.mp h) q hq
        simp_all
      have hjk : (j == k) = false := by simp [Ne.symm hkj]
      simp [List.filter_cons, hk, List.lookup, hjk, ih]
    · simp only [Bool.not_eq_true] at hk
      simp [List.filter_cons, hk, List.lookup, ih]

theorem withOverrides_eff1_gen (extra : Overrides) (j : String) :
    (s.withOverrides extra).eff1 j =
      match extra.lookup j with
      | some st => .ofStatus st
      | none => s.eff1 j := by
  cases h : extra.lookup j with
  | some st => simp only [Scenario.withOverrides, Scenario.eff1, List.lookup_append, h,
      Option.some_or]
  | none =>
    simp only [Scenario.withOverrides, Scenario.eff1, List.lookup_append, h, Option.none_or,
      lookup_filter_absent h]
    rfl

theorem applySuccess_eff1 (ids : List String) (k : String) :
    (s.applySuccess ids).eff1 k =
      if k ∈ (s.successPairs ids).map (·.1) ∧ (s.eff1 k).strength < str (top s ids k) then
        .ofStatus (top s ids k)
      else s.eff1 k := by
  unfold Scenario.applySuccess
  rw [withOverrides_eff1_gen]
  have hm : s.merged ids =
      ((s.successPairs ids).map (·.1)).eraseDups.map fun k => (k, top s ids k) := rfl
  rw [hm, lookup_graph]
  by_cases hc : k ∈ (s.successPairs ids).map (·.1) ∧ (s.eff1 k).strength < str (top s ids k)
  · rw [ite_eq_left hc, ite_eq_left ⟨List.mem_eraseDups.mpr hc.1, by simpa using hc.2⟩]
  · rw [ite_eq_right hc, ite_eq_right]
    rintro ⟨h1, h2⟩
    exact hc ⟨List.mem_eraseDups.mp h1, by simpa using h2⟩

theorem eff1_le_applySuccess (ids : List String) (k : String) :
    (s.eff1 k).strength ≤ ((s.applySuccess ids).eff1 k).strength := by
  rw [applySuccess_eff1]
  split
  · rename_i h; exact Nat.le_of_lt h.2
  · exact Nat.le_refl _

theorem top_mono {X Y : List String} (hXY : ∀ x ∈ X, x ∈ Y) (k : String) :
    str (top s X k) ≤ str (top s Y k) := by
  unfold top
  rcases foldl_stronger_cases (((s.successPairs X).filter (·.1 == k)).map (·.2)) .assumed
    with h | h
  · rw [h]; exact foldl_stronger_ge_init _ _
  · apply foldl_stronger_ge_mem
    simp only [List.mem_map, List.mem_filter] at h ⊢
    obtain ⟨p, ⟨hp, hk⟩, hv⟩ := h
    refine ⟨p, ⟨?_, hk⟩, hv⟩
    obtain ⟨id, hid, e, he, hpe⟩ := (mem_successPairs s).mp hp
    exact (mem_successPairs s).mpr ⟨id, hXY id hid, e, he, hpe⟩

/-- Applying more successes never lowers a fact. -/
theorem applySuccess_mono {X Y : List String} (hXY : ∀ x ∈ X, x ∈ Y) (k : String) :
    ((s.applySuccess X).eff1 k).strength ≤ ((s.applySuccess Y).eff1 k).strength := by
  rw [applySuccess_eff1 s X]
  split
  · rename_i h
    have hkY : k ∈ (s.successPairs Y).map (·.1) := by
      obtain ⟨p, hp, hk⟩ := List.mem_map.mp h.1
      obtain ⟨id, hid, e, he, hpe⟩ := (mem_successPairs s).mp hp
      exact List.mem_map.mpr ⟨p, (mem_successPairs s).mpr ⟨id, hXY id hid, e, he, hpe⟩, hk⟩
    have hle := top_mono s hXY k
    rw [applySuccess_eff1 s Y, ite_eq_left ⟨hkY, Nat.lt_of_lt_of_le h.2 hle⟩]
    exact hle
  · exact eff1_le_applySuccess s Y k

/-- If every member of `Y` whose success raises `k` is in `X`, `X` raises `k` as far. -/
theorem applySuccess_covered (hwf : WellFormed s.trace) {X Y : List String} {k : String}
    (hcov : ∀ id ∈ Y, ∀ e, s.trace.experiment? id = some e → ∀ st, (k, st) ∈ e.success →
      (s.eff1 k).strength < str st → id ∈ X) :
    ((s.applySuccess Y).eff1 k).strength ≤ ((s.applySuccess X).eff1 k).strength := by
  rw [applySuccess_eff1 s Y]
  split
  · rename_i h
    obtain ⟨st, hst, hval⟩ : ∃ st ∈ ((s.successPairs Y).filter (·.1 == k)).map (·.2),
        str (top s Y k) ≤ str st := by
      rcases foldl_stronger_cases (((s.successPairs Y).filter (·.1 == k)).map (·.2)) .assumed
        with h0 | h0
      · obtain ⟨p, hp, hk⟩ := List.mem_map.mp h.1
        refine ⟨p.2, List.mem_map.mpr ⟨p, List.mem_filter.mpr ⟨hp, by simp [hk]⟩, rfl⟩, ?_⟩
        obtain ⟨id, _, e, he, hpe⟩ := (mem_successPairs s).mp hp
        have hass := ((hwf.2.2.2.2.2.2.1).1 e (experiment?_mem he).1).2.1 p hpe
        unfold top
        rw [h0]
        exact asserted_str hass
      · exact ⟨_, h0, Nat.le_refl _⟩
    obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hst
    obtain ⟨hpY, hpk⟩ := List.mem_filter.mp hp
    have hpk' : p.1 = k := by simpa using hpk
    obtain ⟨id, hid, e, he, hpe⟩ := (mem_successPairs s).mp hpY
    have hlt : (s.eff1 k).strength < str p.2 := Nat.lt_of_lt_of_le h.2 hval
    have hidX := hcov id hid e he p.2 (by rw [← hpk']; exact hpe) hlt
    have hpX : p ∈ s.successPairs X := (mem_successPairs s).mpr ⟨id, hidX, e, he, hpe⟩
    have hge : str p.2 ≤ str (top s X k) := by
      unfold top
      apply foldl_stronger_ge_mem
      exact List.mem_map.mpr ⟨p, List.mem_filter.mpr ⟨hpX, hpk⟩, rfl⟩
    have hkX : k ∈ (s.successPairs X).map (·.1) := List.mem_map.mpr ⟨p, hpX, hpk'⟩
    rw [applySuccess_eff1 s X, ite_eq_left ⟨hkX, Nat.lt_of_lt_of_le hlt hge⟩]
    exact Nat.le_trans hval hge
  · exact eff1_le_applySuccess s X k

end Success

/-! ## Pruning: experiments outside the relevant set never raise the claim -/

section Pruning

variable (s : Scenario)

theorem strength_zero {e : EStatus} (h : e.strength = 0) : e = .violated := by
  cases e <;> simp_all [EStatus.strength]

/-- A derivation entry (the shape `derivations` computes per exclusion) vanishes under weaker
verified tests when it vanishes under stronger ones. -/
theorem entry_none_mono (V A e1 e2 va1 va2 vb1 vb2 : Bool) (u w : String × String)
    (h1 : va1 = true → vb1 = true) (h2 : va2 = true → vb2 = true)
    (hb : (if (V && !A) = true then (if (e1 && vb2) = true then some u
      else if (e2 && vb1) = true then some w else none) else none) = none) :
    (if (V && !A) = true then (if (e1 && va2) = true then some u
      else if (e2 && va1) = true then some w else none) else none) = none := by
  cases V <;> cases A <;> cases e1 <;> cases e2 <;> cases va1 <;> cases va2 <;> cases vb1 <;>
    cases vb2 <;> simp_all

theorem derivations_nil_of {X Y : List String} {n : String}
    (hle : ∀ k, ((s.applySuccess X).eff1 k).strength ≤ ((s.applySuccess Y).eff1 k).strength)
    (heq : ((s.applySuccess X).eff1 n).strength = ((s.applySuccess Y).eff1 n).strength)
    (hb : (s.applySuccess Y).derivations n = []) : (s.applySuccess X).derivations n = [] := by
  unfold Scenario.derivations at hb ⊢
  rw [List.filterMap_eq_nil_iff] at hb ⊢
  intro x hx
  have hbx := hb x hx
  have hA : ((s.applySuccess X).eff1 n).asserted = ((s.applySuccess Y).eff1 n).asserted := by
    simp only [EStatus.asserted, heq]
  have hv : ∀ k, ((s.applySuccess X).eff1 k).verified = true →
      ((s.applySuccess Y).eff1 k).verified = true := by
    intro k hk
    have := hle k
    have := strength_le_three ((s.applySuccess Y).eff1 k)
    simp only [EStatus.verified, beq_iff_eq] at hk ⊢
    omega
  rw [hA]
  exact entry_none_mono _ _ _ _ _ _ _ _ _ _ (hv _) (hv _) hbx

theorem eff_le_of {X Y : List String} {n : String}
    (hle : ∀ k, ((s.applySuccess X).eff1 k).strength ≤ ((s.applySuccess Y).eff1 k).strength)
    (heq : ((s.applySuccess X).eff1 n).strength = ((s.applySuccess Y).eff1 n).strength) :
    ((s.applySuccess Y).eff n).strength ≤ ((s.applySuccess X).eff n).strength := by
  by_cases hb : (s.applySuccess Y).derivations n = []
  · have ha := derivations_nil_of s hle heq hb
    simp [Scenario.eff, ha, hb, heq]
  · have hv : (s.applySuccess Y).eff n = .violated := by
      unfold Scenario.eff
      rw [ite_eq_right (by simpa [List.isEmpty_iff] using hb)]
    rw [hv]; exact Nat.zero_le _

theorem active_mono {X Y : List String} (x : Exclusion)
    (hle : ∀ k, ((s.applySuccess X).eff1 k).strength ≤ ((s.applySuccess Y).eff1 k).strength)
    (h : (s.applySuccess X).active x = true) : (s.applySuccess Y).active x = true := by
  unfold Scenario.active at h ⊢
  simp only [Bool.and_eq_true, EStatus.asserted, decide_eq_true_eq] at h ⊢
  exact ⟨⟨h.1.1, Nat.le_trans h.1.2 (hle _)⟩, Nat.le_trans h.2 (hle _)⟩

theorem valid_of {X Y : List String} (T : String)
    (hle : ∀ k, ((s.applySuccess X).eff1 k).strength ≤ ((s.applySuccess Y).eff1 k).strength)
    (hv : (s.applySuccess Y).valid T = true) : (s.applySuccess X).valid T = true := by
  unfold Scenario.valid Scenario.conflicts at hv ⊢
  simp only [List.isEmpty_iff, List.map_eq_nil_iff, List.filter_eq_nil_iff, Bool.and_eq_true,
    beq_iff_eq, not_and] at hv ⊢
  intro x hx hs ha
  exact hv x hx hs (active_mono s x hle ha)

theorem mem_sublists_of_sublist {α : Type} : ∀ {l' l : List α}, List.Sublist l' l →
    l' ∈ sublists l
  | _, _, .slnil => by simp [sublists]
  | _, _, .cons _ h => by
    simp only [sublists, List.mem_append]
    exact Or.inl (mem_sublists_of_sublist h)
  | _, _, .cons_cons _ h => by
    simp only [sublists, List.mem_append, List.mem_map]
    exact Or.inr ⟨_, mem_sublists_of_sublist h, rfl⟩

/-- The closure of `q`'s relevant members: the candidate standing in for `q`. -/
def pruned (c : Claim) (q : List String) : List String :=
  s.closure (((s.relevant c).map (·.id)).filter q.contains)

/-- Pruning: a prerequisite-closed `q` keeping the subject consistent reaches no higher state
than its pruned candidate, which lies inside `q`. -/
theorem pruning (hwf : WellFormed s.trace) {c : Claim} (hc : c ∈ s.trace.claims)
    {q : List String} (hq : Closed s.trace q) (hqv : (s.applySuccess q).valid c.subject = true) :
    pruned s c q ∈ s.candidates c ∧
      ((s.applySuccess q).final c).rank ≤ ((s.applySuccess (pruned s c q)).final c).rank ∧
      ∀ x ∈ pruned s c q, x ∈ q := by
  have hsub : ∀ x ∈ pruned s c q, x ∈ q := closure_subset s hq fun x hx =>
    List.contains_iff_mem.mp (List.mem_filter.mp hx).2
  have hle : ∀ k, ((s.applySuccess (pruned s c q)).eff1 k).strength ≤
      ((s.applySuccess q).eff1 k).strength := applySuccess_mono s hsub
  have hneeds : ∀ n ∈ c.needsAll, s.trace.factSubject? n = some c.subject := by
    intro n hn
    have ⟨_, _, hneedsR, hentR, _⟩ := hwf.2.1.1 c hc
    have hres : n ∈ s.trace.factIds := by
      simp only [Claim.needsAll, List.mem_append, List.mem_singleton] at hn
      rcases hn with hn | rfl
      · exact hneedsR n hn
      · exact hentR
    obtain ⟨sub, hsub⟩ := factSubject?_of_mem hres
    rw [hsub, hwf.2.2.1.1 c hc n hn sub hsub]
  have hcov : ∀ n ∈ c.needsAll, ∀ id ∈ q, ∀ e, s.trace.experiment? id = some e →
      ∀ st, (n, st) ∈ e.success → (s.eff1 n).strength < str st → id ∈ pruned s c q := by
    intro n hn id hid e he st hst hlt
    have ⟨hem, heid⟩ := experiment?_mem he
    have hsubj : e.subject = c.subject :=
      ((hwf.2.2.1).2.1 e hem (n, st) (List.mem_append_left _ hst) c.subject (hneeds n hn)).symm
    have hrel : e ∈ s.relevant c := by
      unfold Scenario.relevant
      refine List.mem_filter.mpr ⟨hem, ?_⟩
      simp only [Bool.and_eq_true, beq_iff_eq, List.any_eq_true]
      exact ⟨hsubj, (n, st), hst, by simp [List.contains_iff_mem, hn]; exact hlt⟩
    apply mem_closure s
    · exact List.mem_filter.mpr ⟨List.mem_map.mpr ⟨e, hrel, heid⟩,
        List.contains_iff_mem.mpr hid⟩
    · exact List.mem_map.mpr ⟨e, hem, heid⟩
  have hneq : ∀ n ∈ c.needsAll, ((s.applySuccess (pruned s c q)).eff1 n).strength =
      ((s.applySuccess q).eff1 n).strength := fun n hn =>
    Nat.le_antisymm (hle n) (applySuccess_covered s hwf (hcov n hn))
  have hPv : (s.applySuccess (pruned s c q)).valid c.subject = true := valid_of s c.subject hle hqv
  refine ⟨?_, ?_, hsub⟩
  · unfold Scenario.candidates
    exact List.mem_filter.mpr ⟨List.mem_map.mpr ⟨_, mem_sublists_of_sublist List.filter_sublist,
      rfl⟩, by simpa using hPv⟩
  · simp only [Scenario.final, hqv, hPv, ↓reduceIte]
    apply intrinsic_rank_mono
    · rfl
    · intro n hn; exact eff_le_of s hle (hneq n hn)
    · intro n hn hv
      have := eff_le_of s hle (hneq n hn)
      rw [hv] at this
      exact strength_zero (Nat.le_zero.mp this)

end Pruning

/-! ## Search: the fold keeps a best candidate -/

section Search

variable (s : Scenario)

theorem lexLt_irrefl : ∀ a : List Nat, lexLt a a = false
  | [] => rfl
  | x :: xs => by simp [lexLt, lexLt_irrefl xs]

theorem lexLt_trans : ∀ a b c : List Nat, lexLt a b = true → lexLt b c = true → lexLt a c = true
  | [], [], _, h, _ => by simp [lexLt] at h
  | [], _ :: _, [], _, h => by simp [lexLt] at h
  | [], _ :: _, _ :: _, _, _ => rfl
  | _ :: _, [], _, h, _ => by simp [lexLt] at h
  | _ :: _, _ :: _, [], _, h => by simp [lexLt] at h
  | x :: xs, y :: ys, z :: zs, h1, h2 => by
    simp only [lexLt, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq]
      at h1 h2 ⊢
    rcases h1 with h1 | ⟨rfl, h1⟩ <;> rcases h2 with h2 | ⟨rfl, h2⟩
    · exact Or.inl (Nat.lt_trans h1 h2)
    · exact Or.inl h1
    · exact Or.inl h2
    · exact Or.inr ⟨rfl, lexLt_trans xs ys zs h1 h2⟩

/-- Pointwise lower counts stay lexicographically below whatever the higher ones are below. -/
theorem lexLt_map_le {es : List Effort} {f g : Effort → Nat} (h : ∀ e, f e ≤ g e) :
    ∀ c : List Nat, lexLt (es.map g) c = true → lexLt (es.map f) c = true := by
  induction es with
  | nil => intro c hc; exact hc
  | cons e es ih =>
    intro c hc
    cases c with
    | nil => simp [lexLt] at hc
    | cons z zs =>
      simp only [List.map_cons, lexLt, Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq,
        beq_iff_eq] at hc ⊢
      have := h e
      rcases hc with hc | ⟨hz, hc⟩
      · exact Or.inl (Nat.lt_of_le_of_lt this hc)
      · rcases Nat.lt_or_eq_of_le this with hlt | heq
        · exact Or.inl (hz ▸ hlt)
        · exact Or.inr ⟨heq.trans hz, ih zs hc⟩

/-- Experiments of effort `e` among `ids`. -/
def effortCount (t : Trace) (ids : List String) (e : Effort) : Nat :=
  ((ids.filterMap fun id => (t.experiment? id).map (·.effort)).filter (· == e)).length

theorem costOf_eq (t : Trace) (ids : List String) :
    costOf t ids = [Effort.months, .weeks, .days, .hours].map (effortCount t ids) := rfl

theorem effortCount_eq (t : Trace) (ids : List String) (e : Effort) :
    effortCount t ids e =
      (ids.filter fun id => (t.experiment? id).map (·.effort) == some e).length := by
  unfold effortCount
  induction ids with
  | nil => rfl
  | cons a ids ih =>
    cases h : t.experiment? a with
    | none => simp [List.filterMap_cons, List.filter_cons, h, ih]
    | some x =>
      by_cases hx : x.effort = e <;> simp [List.filterMap_cons, List.filter_cons, h, hx, ih]

theorem effortCount_le {t : Trace} {A B : List String} (hA : A.Nodup) (hAB : ∀ x ∈ A, x ∈ B)
    (e : Effort) : effortCount t A e ≤ effortCount t B e := by
  rw [effortCount_eq, effortCount_eq]
  apply List.Nodup.length_le_of_subset (List.Pairwise.filter _ hA)
  intro x hx
  have ⟨h1, h2⟩ := List.mem_filter.mp hx
  exact List.mem_filter.mpr ⟨hAB x h1, h2⟩

theorem experimentIds_nodup {t : Trace} (hwf : WellFormed t) : t.experimentIds.Nodup := by
  have h := hwf.1
  unfold IdsUnique Trace.allIds at h
  exact (List.nodup_append.mp (List.nodup_append.mp h).1).2.1

theorem closure_nodup (hwf : WellFormed s.trace) (ids : List String) : (s.closure ids).Nodup := by
  unfold Scenario.closure
  exact List.Pairwise.filter _ (experimentIds_nodup hwf)

/-- `p` does not beat `r` on the plan order's first two keys (state, then cost). -/
def NoBetter (c : Claim) (p r : List String) : Prop :=
  ((s.applySuccess p).final c).rank ≤ ((s.applySuccess r).final c).rank ∧
    (((s.applySuccess p).final c).rank = ((s.applySuccess r).final c).rank →
      lexLt (costOf s.trace p) (costOf s.trace r) = false)

theorem noBetter_self (c : Claim) (p : List String) : NoBetter s c p p :=
  ⟨Nat.le_refl _, fun _ => lexLt_irrefl _⟩

theorem noBetter_of_not_better {c : Claim} {p r : List String}
    (h : s.planBetter c p r = false) : NoBetter s c p r := by
  unfold Scenario.planBetter at h
  refine ⟨?_, fun heq => ?_⟩
  · apply Nat.not_lt.mp
    intro hlt
    simp [hlt] at h
  · cases hl : lexLt (costOf s.trace p) (costOf s.trace r)
    · rfl
    · simp [heq, hl] at h

theorem noBetter_of_better {c : Claim} {p' p r : List String} (h0 : NoBetter s c p' r)
    (h : s.planBetter c p r = true) : NoBetter s c p' p := by
  unfold Scenario.planBetter at h
  simp only [Bool.or_eq_true, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at h
  obtain ⟨hr, hc⟩ := h0
  refine ⟨?_, fun heq => ?_⟩
  · rcases h with h | ⟨h, _⟩ <;> omega
  · rcases h with h | ⟨h, hcost⟩
    · omega
    · have hf := hc (by omega)
      cases hl : lexLt (costOf s.trace p') (costOf s.trace p)
      · rfl
      · rcases hcost with hcost | ⟨hcost, _⟩
        · rw [lexLt_trans _ _ _ hl hcost] at hf; cases hf
        · rw [hcost] at hl; rw [hl] at hf; cases hf

theorem fold_best (c : Claim) : ∀ (l : List (List String)) (acc : List String)
    (seen : List (List String)), (∀ p ∈ seen, NoBetter s c p acc) →
    (l.foldl (fun acc p => if s.planBetter c p acc then p else acc) acc = acc ∨
      l.foldl (fun acc p => if s.planBetter c p acc then p else acc) acc ∈ l) ∧
    ∀ p ∈ seen ++ l,
      NoBetter s c p (l.foldl (fun acc p => if s.planBetter c p acc then p else acc) acc)
  | [], acc, seen, h => ⟨Or.inl rfl, by simpa using h⟩
  | p :: l, acc, seen, h => by
    have hstep : ∀ p' ∈ seen ++ [p],
        NoBetter s c p' (if s.planBetter c p acc then p else acc) := by
      intro p' hp'
      cases hb : s.planBetter c p acc
      · simp only [Bool.false_eq_true, ↓reduceIte]
        rcases List.mem_append.mp hp' with hp' | hp'
        · exact h p' hp'
        · rw [List.mem_singleton.mp hp']; exact noBetter_of_not_better s hb
      · simp only [↓reduceIte]
        rcases List.mem_append.mp hp' with hp' | hp'
        · exact noBetter_of_better s (h p' hp') hb
        · rw [List.mem_singleton.mp hp']; exact noBetter_self s c p
    obtain ⟨hr, hall⟩ := fold_best c l _ (seen ++ [p]) hstep
    refine ⟨?_, fun p' hp' => hall p' (by rw [← List.append_cons]; exact hp')⟩
    simp only [List.foldl_cons]
    rcases hr with hr | hr
    · rw [hr]
      by_cases hb : s.planBetter c p acc = true <;> simp [hb]
    · exact Or.inr (List.mem_cons_of_mem p hr)

theorem best_spec (c : Claim) :
    (s.best c = [] ∨ s.best c ∈ s.candidates c) ∧
      ∀ p ∈ s.candidates c, NoBetter s c p (s.best c) := by
  have h := fold_best s c (s.candidates c) [] [[]] fun p hp => by
    rw [List.mem_singleton.mp hp]; exact noBetter_self s c []
  unfold Scenario.best
  exact ⟨h.1, fun p hp => h.2 p (List.mem_append_right _ hp)⟩

theorem applySuccess_nil : s.applySuccess [] = s := by
  have hm : s.merged [] = [] := rfl
  cases s
  simp [Scenario.applySuccess, Scenario.withOverrides, hm]

theorem plan_planned {c : Claim} {cov p st prem gaps ct}
    (h : s.plan c = .planned cov p st prem gaps ct) :
    s.valid c.subject = true ∧ p = s.best c ∧ st = (s.applySuccess (s.best c)).final c := by
  unfold Scenario.plan at h
  by_cases hv : s.valid c.subject = true
  · by_cases hl : (s.relevant c).length > maxRelevant
    · simp [hv, hl] at h
    · by_cases hr : ((s.applySuccess (s.best c)).final c).rank ≤ (s.final c).rank
      · simp [hv, hl, hr] at h
      · simp only [hv, hl, hr, Bool.not_true, Bool.false_eq_true, ↓reduceIte,
          PlanResult.planned.injEq] at h
        exact ⟨hv, h.2.1.symm, h.2.2.1.symm⟩
  · simp [hv] at h

theorem plan_noImprovement {c : Claim} {cov} (h : s.plan c = .noImprovement cov) :
    ((s.applySuccess (s.best c)).final c).rank ≤ (s.final c).rank := by
  unfold Scenario.plan at h
  by_cases hv : s.valid c.subject = true
  · by_cases hl : (s.relevant c).length > maxRelevant
    · simp [hv, hl] at h
    · by_cases hr : ((s.applySuccess (s.best c)).final c).rank ≤ (s.final c).rank
      · exact hr
      · simp [hv, hl, hr] at h
  · simp [hv] at h

end Search

theorem planSound : Spec.PlanSound := by
  intro s c cov p st prem gaps ct hwf h
  obtain ⟨hv, rfl, rfl⟩ := plan_planned s h
  rcases (best_spec s c).1 with h0 | h0
  · rw [h0, applySuccess_nil]
    exact ⟨(fun _ hid => nomatch hid), hv, rfl⟩
  · unfold Scenario.candidates at h0
    obtain ⟨hmap, hval⟩ := List.mem_filter.mp h0
    obtain ⟨S, _, hS⟩ := List.mem_map.mp hmap
    refine ⟨?_, by simpa using hval, rfl⟩
    rw [← hS]
    exact closure_closed s hwf S

theorem planOptimal : Spec.PlanOptimal := by
  intro s c q hwf hc hq hqv
  obtain ⟨hcand, hrank, hsub⟩ := pruning s hwf hc hq hqv
  have hbest := (best_spec s c).2 _ hcand
  have hcost : ∀ x, lexLt (costOf s.trace q) x = true →
      lexLt (costOf s.trace (pruned s c q)) x = true := by
    intro x hx
    rw [costOf_eq] at hx ⊢
    exact lexLt_map_le (fun e => effortCount_le (closure_nodup s hwf _) hsub e) x hx
  refine ⟨fun cov p st prem gaps ct h => ?_, fun cov h => ?_⟩
  · obtain ⟨_, rfl, rfl⟩ := plan_planned s h
    refine ⟨Nat.le_trans hrank hbest.1, fun heq => ?_⟩
    have hPeq : ((s.applySuccess (pruned s c q)).final c).rank =
        ((s.applySuccess (s.best c)).final c).rank := by
      have := hbest.1; omega
    cases hl : lexLt (costOf s.trace q) (costOf s.trace (s.best c))
    · rfl
    · have := hbest.2 hPeq
      rw [hcost _ hl] at this
      cases this
  · exact Nat.le_trans hrank (Nat.le_trans hbest.1 (plan_noImprovement s h))

end Fvtrace.Proofs.Plan
