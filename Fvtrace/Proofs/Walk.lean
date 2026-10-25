import Fvtrace.Proofs.Answers
import Fvtrace.Proofs.Forest
import Fvtrace.Proofs.PTree
import Fvtrace.Proofs.Singleton

/-! The forest walk (`Fvtrace.Answers.walk`, `kernel.md` P-forest) = the reference rows + plan
summaries on every scenario. A node stands for the base after its closure's successes; its
overlays answer as that scenario (`NodeRepr`), and one step on top of a parent's node answers as the
child's: the merged success per key (`Node.merge`), the overrides it raises over the base (`extra`
≡ the child's `eff1`), one `Delta` on the parent's scenario (`delta_core`), the claims it can move
re-tallied (`countP_patch`). -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false
set_option linter.unusedSectionVars false

namespace Fvtrace.Proofs.Walk
open Fvtrace Fvtrace.Answers Fvtrace.Proofs.Index Fvtrace.Proofs.Lookups
  Fvtrace.Proofs.Positions Fvtrace.Proofs.Answers Fvtrace.Proofs.PTree
open Fvtrace.Proofs.Plan (top lookup_graph withOverrides_eff1_gen applySuccess_eff1 str
  foldl_stronger_ge_init)

/-! ## Merged success over a list of entries -/

/-- `Scenario.merged`'s body over any entries: each key once (first-seen order), its strongest
status (the `.assumed` floor, a tie keeping the earlier). -/
def topOf (P : List (String × Status)) (k : String) : Status :=
  ((P.filter (·.1 == k)).map (·.2)).foldl Status.stronger .assumed

def mergedOf (P : List (String × Status)) : List (String × Status) :=
  (P.map (·.1)).eraseDups.map fun k => (k, topOf P k)

theorem merged_of (s : Scenario) (ids : List String) :
    s.merged ids = mergedOf (s.successPairs ids) :=
  rfl

theorem top_of (s : Scenario) (ids : List String) (k : String) :
    top s ids k = topOf (s.successPairs ids) k := rfl

theorem lookup_map_pair (l : List String) (g : String → Status) (k : String) :
    (l.map fun k' => (k', g k')).lookup k = if k ∈ l then some (g k) else none := by
  induction l with
  | nil => simp [List.lookup]
  | cons a l ih =>
    by_cases h : k = a
    · subst h; simp [List.lookup]
    · have : (k == a) = false := by simpa using h
      simp [List.lookup, this, ih, h]

theorem lookup_mergedOf (P : List (String × Status)) (k : String) :
    (mergedOf P).lookup k = if k ∈ P.map (·.1) then some (topOf P k) else none := by
  unfold mergedOf
  rw [lookup_map_pair]
  simp only [List.mem_eraseDups]

theorem topOf_snoc (P : List (String × Status)) (k' : String) (st : Status) (k : String) :
    topOf (P ++ [(k', st)]) k = if k' = k then (topOf P k).stronger st else topOf P k := by
  unfold topOf
  rw [List.filter_append, List.map_append, List.foldl_append]
  by_cases h : k' = k
  · subst h; simp
  · have : (k' == k) = false := by simpa using h
    simp [List.filter_cons, this, h]

theorem topOf_absent {P : List (String × Status)} {k : String} (h : k ∉ P.map (·.1)) :
    topOf P k = .assumed := by
  unfold topOf
  rw [List.filter_eq_nil_iff.mpr]
  · rfl
  · intro x hx hk
    exact h (List.mem_map.mpr ⟨x, hx, by simpa using hk⟩)

/-- `b` as a count. -/
abbrev one (b : Bool) : Nat := if b then 1 else 0

theorem countP_map_pair (l : List String) (g : String → Status) (p : String × Status → Bool) :
    (l.map fun k => (k, g k)).countP p = l.countP fun k => p (k, g k) := by
  rw [List.countP_map]; rfl

theorem countP_single {α : Type} (p : α → Bool) (a : α) : [a].countP p = one (p a) := by
  simp [List.countP_cons, one]

/-- One more entry: the merged keys gain it once, its value joins the old one. -/
theorem countP_mergedOf_snoc (P : List (String × Status)) (k' : String) (st : Status)
    (p : String × Status → Bool) :
    (mergedOf (P ++ [(k', st)])).countP p =
      if k' ∈ P.map (·.1) then
        (mergedOf P).countP p - one (p (k', topOf P k')) + one (p (k', (topOf P k').stronger st))
      else (mergedOf P).countP p + one (p (k', Status.assumed.stronger st)) := by
  unfold mergedOf
  rw [countP_map_pair, countP_map_pair, List.map_append, List.eraseDups_append]
  have hnd := eraseDups_nodup (P.map (·.1))
  by_cases hk : k' ∈ P.map (·.1)
  · rw [ite_eq_left hk]
    have hrm : ([(k', st)].map (·.1)).removeAll (P.map (·.1)) = [] := by
      simp [List.removeAll, hk]
    rw [hrm, List.eraseDups_nil, List.append_nil]
    have hmem : k' ∈ (P.map (·.1)).eraseDups := List.mem_eraseDups.mpr hk
    have hocc : ((P.map (·.1)).eraseDups.filter (· == k')).Perm [k'] := by
      rw [filter_beq_nodup hnd, ite_eq_left hmem]
    have hp := countP_patch (l := (P.map (·.1)).eraseDups) (occ := [k'])
      (f := fun k => p (k, topOf P k)) (g := fun k => p (k, topOf (P ++ [(k', st)]) k))
      (moved := (· == k')) hocc.symm (by
        intro x _ hx
        have : k' ≠ x := by intro h; subst h; simp at hx
        rw [topOf_snoc, ite_eq_right this])
    rw [hp, countP_single, countP_single, topOf_snoc, ite_eq_left rfl]
    have hle : one (p (k', topOf P k')) ≤
        (P.map (·.1)).eraseDups.countP fun k => p (k, topOf P k) := by
      cases h : p (k', topOf P k')
      · simp [one]
      · exact List.countP_pos_iff.mpr ⟨k', hmem, h⟩
    omega
  · rw [ite_eq_right hk]
    have hrm : ([(k', st)].map (·.1)).removeAll (P.map (·.1)) = [k'] := by
      simp [List.removeAll, hk]
    rw [hrm, List.eraseDups_cons, List.filter_nil, List.eraseDups_nil, List.countP_append]
    have hsame : ((P.map (·.1)).eraseDups.countP fun k => p (k, topOf (P ++ [(k', st)]) k)) =
        (P.map (·.1)).eraseDups.countP fun k => p (k, topOf P k) := by
      apply List.countP_congr
      intro x hx
      have : k' ≠ x := by
        intro h; subst h; exact hk (List.mem_eraseDups.mp hx)
      rw [topOf_snoc, ite_eq_right this]
    rw [hsame, countP_single, topOf_snoc, ite_eq_left rfl, topOf_absent hk]

/-! ## The merged-success cells (`Node.merge`) -/

section Cells

variable (s : Scenario)

/-- A fact id's first position (the overlays' index). -/
abbrev factPos (k : String) : Option Nat := (cxOf s).factIx.first? (cmp := compare) k

theorem factPos_some {k : String} {j : Nat} (h : factPos s k = some j) :
    ∃ hj : j < s.trace.facts.length, s.trace.facts[j].id = k := first?_pos h

theorem factPos_inj {k k' : String} {j : Nat} (h : factPos s k = some j)
    (h' : factPos s k' = some j) : k = k' := by
  obtain ⟨_, h1⟩ := factPos_some s h
  obtain ⟨_, h2⟩ := factPos_some s h'
  rw [← h1, ← h2]

/-- The fact overlays' depth. -/
abbrev factDepth : Nat := PTree.depthFor (cxOf s).facts.size

theorem factPos_lt {k : String} {j : Nat} (h : factPos s k = some j) : j < 2 ^ factDepth s := by
  obtain ⟨hj, _⟩ := factPos_some s h
  have := lt_depthFor (cxOf s).facts.size
  simp only [cxOf, ctx_facts, List.size_toArray] at this
  exact Nat.lt_trans hj this

/-- The what-if does not hold a merged value exactly. -/
abbrev mis (x : String × Status) : Bool := (coreOf s).override? x.1 != some x.2

/-- Cells hold the merged lookup of `P` at each key's position. -/
structure CellRepr (cell : PTree (Option Status)) (P : List (String × Status)) : Prop where
  complete : Complete cell (factDepth s)
  get : ∀ k j, factPos s k = some j → cell.get j = (mergedOf P).lookup k

theorem mis_count (k : String) (st : Status) :
    (if (coreOf s).override? k == some st then 0 else 1) = one (mis s (k, st)) := by
  unfold mis one
  cases h : (coreOf s).override? k == some st <;> simp [h, bne]

theorem getD_lookup (P : List (String × Status)) (k : String) :
    ((mergedOf P).lookup k).getD .assumed = topOf P k := by
  rw [lookup_mergedOf]
  split
  · rfl
  · rename_i h; rw [topOf_absent h]; rfl

theorem mergeEntry_repr {acc : PTree (Option Status) × Nat} {P : List (String × Status)}
    (hc : CellRepr s acc.1 P) (hb : acc.2 = (mergedOf P).countP (mis s)) (x : String × Status)
    (hx : (factPos s x.1).isSome) :
    CellRepr s (Node.mergeEntry (cxOf s) (coreOf s) acc x).1 (P ++ [x]) ∧
      (Node.mergeEntry (cxOf s) (coreOf s) acc x).2 = (mergedOf (P ++ [x])).countP (mis s) := by
  obtain ⟨j, hj⟩ := Option.isSome_iff_exists.mp hx
  have hcell : acc.1.get j = (mergedOf P).lookup x.1 := hc.get x.1 j hj
  have hnew : ((acc.1.get j).getD .assumed).stronger x.2 = topOf (P ++ [x]) x.1 := by
    rw [hcell, getD_lookup, show x = (x.1, x.2) from rfl, topOf_snoc, ite_eq_left rfl]
  unfold Node.mergeEntry
  simp only [show (cxOf s).factIx.first? (cmp := compare) x.1 = some j from hj]
  refine ⟨⟨complete_set hc.complete _ _, ?_⟩, ?_⟩
  · intro k j' hk
    rw [get_set hc.complete (factPos_lt s hj) (factPos_lt s hk)]
    by_cases hjj : j = j'
    · subst hjj
      have hkx := factPos_inj s hk hj
      subst hkx
      rw [ite_eq_left rfl, hnew, lookup_mergedOf, ite_eq_left (by simp)]
    · rw [ite_eq_right hjj, hc.get k j' hk, lookup_mergedOf, lookup_mergedOf]
      have hkx : x.1 ≠ k := by
        intro h; subst h; rw [hj] at hk; exact hjj (Option.some.inj hk)
      have hmem : k ∈ (P ++ [x]).map (·.1) ↔ k ∈ P.map (·.1) := by
        simp only [List.map_append, List.mem_append, List.map_cons, List.map_nil,
          List.mem_singleton]
        exact ⟨fun h => h.resolve_right (Ne.symm hkx), Or.inl⟩
      rw [show x = (x.1, x.2) from rfl, topOf_snoc, ite_eq_right hkx]
      by_cases h : k ∈ P.map (·.1)
      · rw [ite_eq_left h, ite_eq_left (hmem.mpr h)]
      · rw [ite_eq_right h, ite_eq_right (fun h' => h (hmem.mp h'))]
  · rw [show x = (x.1, x.2) from rfl, countP_mergedOf_snoc, ← hb]
    rw [hcell, lookup_mergedOf]
    by_cases h : x.1 ∈ P.map (·.1)
    · rw [ite_eq_left h, ite_eq_left h]
      simp only [Option.getD_some, mis_count]
    · rw [ite_eq_right h, ite_eq_right h]
      simp only [Option.getD_none, mis_count]

theorem merge_repr : ∀ (E : List (String × Status)) (acc : PTree (Option Status) × Nat)
    (P : List (String × Status)), (∀ x ∈ E, (factPos s x.1).isSome) →
    CellRepr s acc.1 P → acc.2 = (mergedOf P).countP (mis s) →
    CellRepr s (E.foldl (Node.mergeEntry (cxOf s) (coreOf s)) acc).1 (P ++ E) ∧
      (E.foldl (Node.mergeEntry (cxOf s) (coreOf s)) acc).2 = (mergedOf (P ++ E)).countP (mis s)
  | [], acc, P, _, hc, hb => by simpa using ⟨hc, hb⟩
  | x :: E, acc, P, hE, hc, hb => by
    obtain ⟨hc', hb'⟩ := mergeEntry_repr s hc hb x (hE x List.mem_cons_self)
    have := merge_repr E _ (P ++ [x]) (fun y hy => hE y (List.mem_cons_of_mem _ hy)) hc' hb'
    simpa using this

end Cells

/-! ## The overrides one step raises over the base -/

section Extra

variable (s : Scenario)

/-- The step's what-if on the parent's scenario: each of `e`'s keys at the closure's merged value
`P` gives it, where that raises it over the base. -/
def extraRef (P : List (String × Status)) (E : List (String × Status)) : Overrides :=
  E.filterMap fun x =>
    if str (topOf P x.1) > (s.eff1 x.1).strength then some (x.1, topOf P x.1) else none

theorem lookup_extraRef (P : List (String × Status)) :
    ∀ (E : List (String × Status)) (k : String), (extraRef s P E).lookup k =
      if k ∈ E.map (·.1) ∧ str (topOf P k) > (s.eff1 k).strength then some (topOf P k) else none
  | [], k => by simp [extraRef, List.lookup]
  | x :: E, k => by
    have ih := lookup_extraRef P E k
    unfold extraRef at ih ⊢
    rw [List.filterMap_cons]
    by_cases hx : str (topOf P x.1) > (s.eff1 x.1).strength
    · rw [ite_eq_left hx]
      dsimp only
      rw [List.lookup_cons]
      by_cases hk : k = x.1
      · subst hk; simp [hx]
      · have : (k == x.1) = false := by simpa using hk
        rw [this, ih]
        simp only [List.map_cons, List.mem_cons, hk, false_or]
    · rw [ite_eq_right hx]
      dsimp only
      rw [ih]
      by_cases hk : k = x.1
      · subst hk; simp [hx]
      · simp only [List.map_cons, List.mem_cons, hk, false_or]

theorem successPairs_snoc (L : List String) {e : Experiment}
    (he : s.trace.experiment? e.id = some e) :
    s.successPairs (L ++ [e.id]) = s.successPairs L ++ e.success := by
  unfold Scenario.successPairs
  rw [List.flatMap_append]
  simp [he]

/-- The step's what-if on the parent's scenario gives the child's `eff1`: a key of `e` at the
child's merged value where that raises it over the base (else neither raises it), any other key
as the parent left it. -/
theorem extra_eff1 (L : List String) {e : Experiment} (he : s.trace.experiment? e.id = some e) :
    ((s.applySuccess L).withOverrides (extraRef s (s.successPairs L ++ e.success) e.success)).eff1 =
      (s.applySuccess (L ++ [e.id])).eff1 := by
  funext k
  have hl := lookup_extraRef s (s.successPairs L ++ e.success) e.success k
  have h1 := applySuccess_eff1 s L k
  have h2 := applySuccess_eff1 s (L ++ [e.id]) k
  rw [top_of] at h1
  rw [top_of, successPairs_snoc s L he] at h2
  rw [withOverrides_eff1_gen, h2]
  generalize s.successPairs L = P at hl h1
  -- `e`'s entries only ever strengthen a key's merged value.
  have hge : str (topOf P k) ≤ str (topOf (P ++ e.success) k) := by
    unfold topOf
    rw [List.filter_append, List.map_append, List.foldl_append]
    exact foldl_stronger_ge_init _ _
  have hkeys : k ∈ (P ++ e.success).map (·.1) ↔ k ∈ P.map (·.1) ∨ k ∈ e.success.map (·.1) := by
    simp [List.map_append]
  by_cases hke : k ∈ e.success.map (·.1)
  · by_cases hr : str (topOf (P ++ e.success) k) > (s.eff1 k).strength
    · rw [ite_eq_left ⟨hke, hr⟩] at hl
      rw [hl, ite_eq_left ⟨hkeys.mpr (Or.inr hke), hr⟩]
    · rw [ite_eq_right (fun h => hr h.2)] at hl
      rw [hl, ite_eq_right (fun h => hr h.2)]
      dsimp only
      rw [h1, ite_eq_right]
      intro h
      exact hr (Nat.lt_of_lt_of_le h.2 hge)
  · rw [ite_eq_right (fun h => hke h.1)] at hl
    rw [hl]
    dsimp only
    have hsame : topOf (P ++ e.success) k = topOf P k := by
      unfold topOf
      rw [List.filter_append, List.map_append, List.foldl_append]
      have : e.success.filter (·.1 == k) = [] := by
        apply List.filter_eq_nil_iff.mpr
        intro x hx hxk
        exact hke (List.mem_map.mpr ⟨x, hx, by simpa using hxk⟩)
      rw [this]
      rfl
    have hk' : k ∈ (P ++ e.success).map (·.1) ↔ k ∈ P.map (·.1) := by
      rw [hkeys]; exact ⟨fun h => h.resolve_right hke, Or.inl⟩
    rw [h1, hsame]
    simp only [hk']

end Extra

/-! ## Scenarios that agree on `eff1` agree on every judgment -/

section Congr

variable {S T : Scenario} (ht : S.trace = T.trace) (hc : S.current = T.current)
  (h1 : S.eff1 = T.eff1)
include ht hc h1

theorem derivations_congr : S.derivations = T.derivations := by
  funext id
  unfold Scenario.derivations Scenario.exclusionEff Scenario.eff0
  rw [ht, hc, h1]

theorem eff_congr : S.eff = T.eff := by
  funext id
  unfold Scenario.eff
  rw [derivations_congr ht hc h1, h1]

theorem active_congr : S.active = T.active := by
  funext x
  unfold Scenario.active Scenario.exclusionEff Scenario.eff0
  rw [hc, h1]

theorem conflicts_congr : S.conflicts = T.conflicts := by
  funext sub
  unfold Scenario.conflicts
  rw [ht, active_congr ht hc h1]

theorem valid_congr : S.valid = T.valid := by
  funext sub
  unfold Scenario.valid
  rw [conflicts_congr ht hc h1]

theorem restsOn_congr : S.restsOn = T.restsOn := by
  funext id
  unfold Scenario.restsOn Scenario.mustVerify
  rw [eff_congr ht hc h1, ht]

theorem incompatible_congr : S.incompatible = T.incompatible := by
  funext c
  unfold Scenario.incompatible Scenario.exclusionEff Scenario.eff0
  rw [ht, hc]

theorem final_congr : S.final = T.final := by
  funext c
  unfold Scenario.final Scenario.intrinsic
  rw [valid_congr ht hc h1, eff_congr ht hc h1, incompatible_congr ht hc h1,
    restsOn_congr ht hc h1]

end Congr

/-! ## Writing an overlay -/

section Overlay

variable {α : Type}

theorem setAt_get (pos : String → Option Nat)
    (hinj : ∀ a b j, pos a = some j → pos b = some j → a = b)
    {d : Nat} (hlt : ∀ a j, pos a = some j → j < 2 ^ d) (v : String → α) :
    ∀ (keys : List String) (t : PTree (Option α)), Complete t d →
      Complete (setAt pos keys v t) d ∧
      ∀ a j, pos a = some j → (setAt pos keys v t).get j = if a ∈ keys then some (v a) else t.get j
  | [], t, hc => ⟨hc, fun _ _ _ => by simp [setAt]⟩
  | k :: keys, t, hc => by
    have hstep : setAt pos (k :: keys) v t = setAt pos keys v (match pos k with
        | some j => t.set j (some (v k))
        | none => t) := rfl
    rw [hstep]
    cases hk : pos k with
    | none =>
      obtain ⟨h1, h2⟩ := setAt_get pos hinj hlt v keys t hc
      refine ⟨h1, fun a j ha => ?_⟩
      rw [h2 a j ha]
      have : a ≠ k := by intro h; subst h; rw [hk] at ha; cases ha
      simp [this]
    | some jk =>
      obtain ⟨h1, h2⟩ := setAt_get pos hinj hlt v keys _ (complete_set hc jk (some (v k)))
      refine ⟨h1, fun a j ha => ?_⟩
      rw [h2 a j ha, get_set hc (hlt k jk hk) (hlt a j ha)]
      by_cases hak : a = k
      · subst hak
        rw [hk] at ha
        cases ha
        by_cases hm : a ∈ keys <;> simp [hm]
      · have hj : jk ≠ j := by intro h; subst h; exact hak (hinj a k jk ha hk)
        simp [hak, hj]

end Overlay

/-! ## The walk's guard: every key the overlays index names a fact (or a subject) -/

section Dense

variable (s : Scenario)

/-- A subject id's first position (the `act` overlay's index). -/
abbrev subjectPos (sub : String) : Option Nat := (cxOf s).subjectIx.first? (cmp := compare) sub

theorem factPos_isSome (k : String) : (factPos s k).isSome ↔ k ∈ s.trace.factIds := by
  show ((Index.ofKeys compare (s.trace.facts.map (·.id))).first? (cmp := compare) k).isSome ↔ _
  rw [first?_map, List.findIdx?_isSome, List.any_eq_true]
  simp [Trace.factIds]

theorem subjectPos_isSome (sub : String) :
    (subjectPos s sub).isSome ↔ sub ∈ s.trace.subjectIds := by
  show ((Index.ofKeys compare (s.trace.subjects.map (·.id))).first? (cmp := compare) sub).isSome ↔ _
  rw [first?_map, List.findIdx?_isSome, List.any_eq_true]
  simp [Trace.subjectIds]

theorem subjectPos_some {sub : String} {u : Nat} (h : subjectPos s sub = some u) :
    ∃ hu : u < s.trace.subjects.length, s.trace.subjects[u].id = sub := first?_pos h

theorem subjectPos_inj {a b : String} {u : Nat} (ha : subjectPos s a = some u)
    (hb : subjectPos s b = some u) : a = b := by
  obtain ⟨_, h1⟩ := subjectPos_some s ha
  obtain ⟨_, h2⟩ := subjectPos_some s hb
  rw [← h1, ← h2]

/-- The subject overlay's depth. -/
abbrev subjectDepth : Nat := PTree.depthFor (cxOf s).subjects.size

theorem subjectPos_lt {sub : String} {u : Nat} (h : subjectPos s sub = some u) :
    u < 2 ^ subjectDepth s := by
  obtain ⟨hu, _⟩ := subjectPos_some s h
  have := lt_depthFor (cxOf s).subjects.size
  simp only [cxOf, ctx_subjects, List.size_toArray] at this
  exact Nat.lt_trans hu this

theorem dense_spec (hd : (cxOf s).dense = true) :
    (∀ e ∈ s.trace.experiments, ∀ x ∈ e.success, (factPos s x.1).isSome) ∧
      ∀ x ∈ s.trace.exclusions, (factPos s x.between.1).isSome ∧ (factPos s x.between.2).isSome ∧
        (subjectPos s x.subject).isSome := by
  unfold Ctx.dense at hd
  rw [ctx_L, cxOf, ctx_experiments, ctx_exclusions, Bool.and_eq_true] at hd
  obtain ⟨he, hx⟩ := hd
  rw [List.all_toArray, List.all_eq_true] at he
  rw [List.all_toArray, List.all_eq_true] at hx
  refine ⟨fun e he' x hx' => ?_, fun x hx' => ?_⟩
  · have := List.all_eq_true.mp (he e he') x hx'
    rw [factPos_isSome]
    simpa [Lookups.reference, List.contains_iff_mem] using this
  · have := hx x hx'
    simp only [Lookups.reference, Bool.and_eq_true, List.contains_iff_mem] at this
    exact ⟨(factPos_isSome s _).mpr this.1.1, (factPos_isSome s _).mpr this.1.2,
      (subjectPos_isSome s _).mpr this.2⟩

variable {s}

/-- Off the facts, no success raises an id. -/
theorem dense_eff1 (hd : (cxOf s).dense = true) (L : List String) {k : String}
    (hk : factPos s k = none) : (s.applySuccess L).eff1 k = s.eff1 k := by
  rw [applySuccess_eff1, ite_eq_right]
  rintro ⟨hm, _⟩
  obtain ⟨x, hx, hxk⟩ := List.mem_map.mp hm
  obtain ⟨id, _, e, he, hxe⟩ := (Fvtrace.Proofs.Plan.mem_successPairs s).mp hx
  have := (dense_spec s hd).1 e (Fvtrace.Proofs.Plan.experiment?_mem he).1 x hxe
  rw [hxk, hk] at this
  cases this

/-- Off the facts, no exclusion derives a violation. -/
theorem dense_derivations (hd : (cxOf s).dense = true) {T : Scenario} (ht : T.trace = s.trace)
    {k : String} (hk : factPos s k = none) : T.derivations k = [] := by
  unfold Scenario.derivations
  rw [ht, List.filterMap_eq_nil_iff]
  intro x hx
  obtain ⟨h1, h2, _⟩ := (dense_spec s hd).2 x hx
  have n1 : (x.between.1 == k) = false := by
    rw [beq_eq_false_iff_ne]; intro h; rw [h, hk] at h1; cases h1
  have n2 : (x.between.2 == k) = false := by
    rw [beq_eq_false_iff_ne]; intro h; rw [h, hk] at h2; cases h2
  simp [n1, n2]

theorem dense_eff (hd : (cxOf s).dense = true) (L : List String) {k : String}
    (hk : factPos s k = none) : (s.applySuccess L).eff k = s.eff k := by
  unfold Scenario.eff
  rw [dense_derivations hd (T := s.applySuccess L) rfl hk, dense_derivations hd (T := s) rfl hk,
    dense_eff1 hd L hk]

/-- Off the declared subjects, no exclusion is active. -/
theorem dense_conflicts (hd : (cxOf s).dense = true) {T : Scenario} (ht : T.trace = s.trace)
    {sub : String} (hs : subjectPos s sub = none) : T.conflicts sub = [] := by
  unfold Scenario.conflicts
  rw [ht, List.map_eq_nil_iff, List.filter_eq_nil_iff]
  intro x hx hm
  obtain ⟨_, _, h3⟩ := (dense_spec s hd).2 x hx
  simp only [Bool.and_eq_true, beq_iff_eq] at hm
  rw [hm.1, hs] at h3
  cases h3

end Dense

/-! ## What a node stands for -/

section Nodes

variable (s : Scenario)

/-- The base claim memos `fast` passes the walk. -/
abbrev memoOf : Array ClaimMemo := (cxOf s).claims.map (ClaimMemo.of (cxOf s) s (coreOf s))

/-- The claim overlay's depth. -/
abbrev claimDepth : Nat := PTree.depthFor (cxOf s).claims.size

/-- Node `nd` answers as the base after the successes of `L`: its overlays (over the base core)
hold that scenario's statuses, active counts + claim counts, its cells `L`'s merged success, its
tallies the moves against the base. -/
structure NodeRepr (nd : Node) (L : List String) : Prop where
  eff1C : Complete nd.eff1 (factDepth s)
  effC : Complete nd.eff (factDepth s)
  actC : Complete nd.act (subjectDepth s)
  cntC : Complete nd.cnt (claimDepth s)
  eff1 : ∀ k j, factPos s k = some j →
    (nd.eff1.get j).getD ((coreOf s).eff1 k) = (s.applySuccess L).eff1 k
  eff : ∀ k j, factPos s k = some j →
    (nd.eff.get j).getD ((coreOf s).eff k) = (s.applySuccess L).eff k
  act : ∀ sub u, subjectPos s sub = some u →
    (nd.act.get u).getD ((coreOf s).activeCount sub) = ((s.applySuccess L).conflicts sub).length
  cnt : ∀ q (hq : q < s.trace.claims.length), nd.countsAt (memoOf s) q =
    Counts.of (s.applySuccess L).eff (s.applySuccess L).restsOn s.trace.claims[q].needsAll
  cells : CellRepr s nd.cell (s.successPairs L)
  bad : nd.bad = (s.merged L).countP (mis s)
  contingent : nd.contingent = ((s.successPairs L).map (·.1)).any (cxOf s).isResult
  lights : nd.lights =
    s.trace.claims.countP fun c => lightsTo (s.final c) ((s.applySuccess L).final c)
  clears : nd.clears =
    s.trace.claims.countP fun c => clearsTo (s.final c) ((s.applySuccess L).final c)
  lowers : nd.lowers =
    s.trace.claims.countP fun c => lowersTo (s.final c) ((s.applySuccess L).final c)

variable {s}

/-- A node's overlays read as a core of its scenario (`Delta.build`'s base). -/
theorem node_core (hd : (cxOf s).dense = true) {nd : Node} {L : List String}
    (hn : NodeRepr s nd L) : CoreSpec (s.applySuccess L) (nd.core (cxOf s) s (coreOf s)) := by
  have he1 : (nd.core (cxOf s) s (coreOf s)).eff1 = (s.applySuccess L).eff1 := by
    funext k
    show (match factPos s k with
      | some j => (match nd.eff1.get j with
        | some e => e
        | none => (coreOf s).eff1 k)
      | none => (coreOf s).eff1 k) = _
    cases hk : factPos s k with
    | some j =>
      have := hn.eff1 k j hk
      cases h : nd.eff1.get j <;> simp_all
    | none => rw [eff1_eq, dense_eff1 hd L hk]
  refine ⟨he1, ?_, ?_, ?_⟩
  · funext k
    show (match factPos s k with
      | some j => (match nd.eff.get j with
        | some e => e
        | none => (coreOf s).eff k)
      | none => (coreOf s).eff k) = _
    cases hk : factPos s k with
    | some j =>
      have := hn.eff k j hk
      cases h : nd.eff.get j <;> simp_all
    | none => rw [eff_eq, dense_eff hd L hk]
  · funext x
    show activeWith s (nd.core (cxOf s) s (coreOf s)).eff1 x = _
    rw [he1]
    rfl
  · intro sub
    show (match subjectPos s sub with
      | some u => (match nd.act.get u with
        | some k => k
        | none => (coreOf s).activeCount sub)
      | none => (coreOf s).activeCount sub) = _
    cases hs : subjectPos s sub with
    | some u =>
      have := hn.act sub u hs
      cases h : nd.act.get u <;> simp_all
    | none =>
      rw [activeCount_eq, dense_conflicts hd (T := s) rfl hs,
        dense_conflicts hd (T := s.applySuccess L) rfl hs]

variable (s)

theorem lightsTo_self (b : State) : lightsTo b b = false := by
  unfold lightsTo; simp
theorem clearsTo_self (b : State) : clearsTo b b = false := by
  unfold clearsTo; cases b <;> decide
theorem lowersTo_self (b : State) : lowersTo b b = false := by
  unfold lowersTo; simp

/-- The root: the base itself. -/
theorem root_repr : NodeRepr s (Node.root (cxOf s)) [] := by
  have h0 : s.applySuccess [] = s := Fvtrace.Proofs.Plan.applySuccess_nil s
  have hp : s.successPairs [] = [] := rfl
  unfold Node.root
  refine ⟨complete_const _ _, complete_const _ _, complete_const _ _, complete_const _ _,
    ?_, ?_, ?_, ?_, ⟨complete_const _ _, ?_⟩, ?_, ?_, ?_, ?_, ?_⟩
  · intro k j _; rw [get_const, h0, eff1_eq]; rfl
  · intro k j _; rw [get_const, h0, eff_eq]; rfl
  · intro sub u _; rw [get_const, h0, activeCount_eq]; rfl
  · intro q hq
    unfold Node.countsAt
    rw [get_const, h0]
    simp only [memoOf, cxOf, ctx_claims, List.getElem?_toArray, Array.getElem?_map,
      List.getElem?_eq_getElem hq, Option.map_some, Option.getD_some]
    show Counts.of (coreOf s).eff (Core.restsOn (cxOf s) (coreOf s)) _ = _
    rw [eff_eq, restsOn_eq]
  · intro k j _; rw [get_const, hp]; rfl
  · rfl
  · rfl
  · rw [h0]; simp [lightsTo_self]
  · rw [h0]; simp [clearsTo_self]
  · rw [h0]; simp [lowersTo_self]

end Nodes

/-! ## One step: its merge, its overrides, its delta -/

section Step

variable {s : Scenario} (hd : (cxOf s).dense = true) {nd : Node} {L : List String}
  (hn : NodeRepr s nd L) {e : Experiment} (he : s.trace.experiment? e.id = some e)
include hd hn he

theorem step_keys : ∀ x ∈ e.success, (factPos s x.1).isSome :=
  (dense_spec s hd).1 e (Fvtrace.Proofs.Plan.experiment?_mem he).1

theorem step_merge :
    CellRepr s (Node.merge (cxOf s) (coreOf s) e nd.cell nd.bad).1 (s.successPairs (L ++ [e.id])) ∧
      (Node.merge (cxOf s) (coreOf s) e nd.cell nd.bad).2 =
        (s.merged (L ++ [e.id])).countP (mis s) := by
  rw [successPairs_snoc s L he, merged_of, successPairs_snoc s L he]
  exact merge_repr s e.success (nd.cell, nd.bad) _ (step_keys hd hn he) hn.cells hn.bad

theorem step_extra :
    stepExtra (cxOf s) (coreOf s) (Node.merge (cxOf s) (coreOf s) e nd.cell nd.bad).1 e =
      extraRef s (s.successPairs L ++ e.success) e.success := by
  have hc := (step_merge hd hn he).1
  rw [successPairs_snoc s L he] at hc
  unfold stepExtra extraRef
  apply filterMap_congr'
  intro x hx
  obtain ⟨j, hj⟩ := Option.isSome_iff_exists.mp (step_keys hd hn he x hx)
  show (match factPos s x.1 with
    | some j => _
    | none => none) = _
  rw [hj]
  dsimp only
  rw [hc.get x.1 j hj, lookup_mergedOf,
    ite_eq_left (List.mem_map.mpr ⟨x, List.mem_append_right _ hx, rfl⟩), Option.bind_some, eff1_eq]

/-- The step's delta = the parent scenario's delta of its overrides. -/
theorem step_delta :
    Delta.build (cxOf s) s (nd.core (cxOf s) s (coreOf s))
        (stepExtra (cxOf s) (coreOf s) (Node.merge (cxOf s) (coreOf s) e nd.cell nd.bad).1 e) =
      deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success) := by
  rw [step_extra hd hn he]
  rw [delta_scenario s _ (s.raised L)]
  exact delta_core (s.applySuccess L) _ (node_core hd hn)

/-- After the step's overrides, the parent scenario answers as the child's. -/
theorem step_after :
    (afterOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)).eff1 =
      (s.applySuccess (L ++ [e.id])).eff1 :=
  extra_eff1 s L he

end Step

/-! ## A delta's counts + active exclusions, on any core of its scenario -/

section DeltaCounts

variable (S : Scenario) (extra : Overrides)

/-- `Delta.counts` = the counts recomputed after the what-if (any core of the scenario). -/
theorem delta_counts {k : Core} (hk : CoreSpec S k) (c : Claim) (base : Counts)
    (times : String → Nat)
    (hbase : base = Counts.of S.eff S.restsOn c.needsAll)
    (htimes : ∀ d ∈ (deltaOf S extra).changed, times d = c.needsAll.count d) :
    Delta.counts (cxOf S) k (deltaOf S extra) c.needsAll c.needsAll.length base times =
      Counts.of (afterOf S extra).eff (afterOf S extra).restsOn c.needsAll := by
  unfold Delta.counts
  rw [hbase, ← hk.eff, ← restsOn_core S hk]
  have hocc := occurrences_perm c.needsAll (deltaOf S extra).changed (changed_nodup S extra)
    times htimes (deltaOf S extra).isChanged (isChanged_iff S extra)
  have hcount : (deltaOf S extra).changedCount = (deltaOf S extra).changed.length := rfl
  rw [hcount, patch_eq _ _ _ _ c.needsAll _ (deltaOf S extra).isChanged hocc]
  · rw [delta_eff, delta_restsOn]
  · intro x _ hm
    have : x ∉ (deltaOf S extra).changed := fun h => by
      simp [(isChanged_iff S extra x).mpr h] at hm
    rw [hk.eff, delta_eff, eff_off_changed S extra this]
  · intro x _ hm
    have : x ∉ (deltaOf S extra).changed := fun h => by
      simp [(isChanged_iff S extra x).mpr h] at hm
    rw [restsOn_core S hk, delta_restsOn]
    unfold Scenario.restsOn
    rw [eff_off_changed S extra this]
    rfl

/-- A subject no touched exclusion lies on keeps its active count. -/
theorem activeCount_off {sub : String}
    (h : sub ∉ (S.trace.exclusions.filter fun x => decide (Moved extra x)).map (·.subject)) :
    ((afterOf S extra).conflicts sub).length = (S.conflicts sub).length := by
  rw [← delta_activeCount]
  show (coreOf S).activeCount sub -
      ((Shifts.of ((deltaOf S extra).touched.filterMap ((cxOf S).exclusions[·]?)) (coreOf S).active
        (activeWith S (deltaOf S extra).eff1)).at sub).1 +
      ((Shifts.of ((deltaOf S extra).touched.filterMap ((cxOf S).exclusions[·]?)) (coreOf S).active
        (activeWith S (deltaOf S extra).eff1)).at sub).2 = _
  rw [shifts_at, delta_excls, activeCount_eq]
  have h0 : ∀ q : Exclusion → Bool,
      ((S.trace.exclusions.filter fun x => decide (Moved extra x)).countP
        fun x => x.subject == sub && q x) = 0 := by
    intro q
    rw [List.countP_eq_zero]
    intro x hx hq
    simp only [Bool.and_eq_true, beq_iff_eq] at hq
    exact h (List.mem_map.mpr ⟨x, hx, hq.1⟩)
  rw [h0, h0]
  omega

/-- The touched subjects as `Node.step` lists them. -/
theorem touchedSubjects_mem {k : Core} (hk : CoreSpec S k) (sub : String) :
    sub ∈ touchedSubjects (cxOf S) (Delta.build (cxOf S) S k extra) ↔
      sub ∈ (S.trace.exclusions.filter fun x => decide (Moved extra x)).map (·.subject) := by
  rw [delta_core S extra hk]
  unfold touchedSubjects
  rw [eraseDups_eq, List.mem_eraseDups, touched_subjects]

end DeltaCounts

/-! ## Writing a list of positions -/

section Sets

variable {α β : Type} (pos : β → Nat) (val : β → α) {d : Nat}

theorem foldSet_complete : ∀ (xs : List β) (t : PTree (Option α)), Complete t d →
    Complete (xs.foldl (fun t x => t.set (pos x) (some (val x))) t) d
  | [], _, hc => hc
  | _ :: xs, _, hc => foldSet_complete xs _ (complete_set hc _ _)

theorem foldSet_off : ∀ (xs : List β) (t : PTree (Option α)), Complete t d →
    (∀ x ∈ xs, pos x < 2 ^ d) → ∀ q, q < 2 ^ d → (∀ x ∈ xs, pos x ≠ q) →
      (xs.foldl (fun t x => t.set (pos x) (some (val x))) t).get q = t.get q
  | [], _, _, _, _, _, _ => rfl
  | x :: xs, t, hc, hlt, q, hq, hne => by
    rw [List.foldl_cons, foldSet_off xs _ (complete_set hc _ _)
      (fun y hy => hlt y (List.mem_cons_of_mem _ hy)) q hq
      (fun y hy => hne y (List.mem_cons_of_mem _ hy)),
      get_set hc (hlt x List.mem_cons_self) hq, ite_eq_right (hne x List.mem_cons_self)]

theorem foldSet_on : ∀ (xs : List β) (t : PTree (Option α)), Complete t d →
    (∀ x ∈ xs, pos x < 2 ^ d) → (xs.map pos).Nodup → ∀ x ∈ xs,
      (xs.foldl (fun t x => t.set (pos x) (some (val x))) t).get (pos x) = some (val x)
  | [], _, _, _, _, _, h => by cases h
  | y :: xs, t, hc, hlt, hnd, x, hx => by
    rw [List.foldl_cons]
    rw [List.map_cons, List.nodup_cons] at hnd
    rcases List.mem_cons.mp hx with rfl | hx
    · rw [foldSet_off pos val xs _ (complete_set hc _ _)
        (fun z hz => hlt z (List.mem_cons_of_mem _ hz)) _ (hlt x List.mem_cons_self)
        (fun z hz h => hnd.1 (List.mem_map.mpr ⟨z, hz, h⟩)),
        get_set hc (hlt x List.mem_cons_self) (hlt x List.mem_cons_self), ite_eq_left rfl]
    · exact foldSet_on xs _ (complete_set hc _ _) (fun z hz => hlt z (List.mem_cons_of_mem _ hz))
        hnd.2 x hx

end Sets

/-- The counts a step writes: at each re-tallied claim's position, its new counts. -/
theorem foldCounts_get (s : Scenario) (p : Claim × Nat → Bool) (R : Claim × Nat → Recount)
    (hR : ∀ x, (R x).pos = x.2) (t : PTree (Option Counts)) (hc : Complete t (claimDepth s))
    {q : Nat} (hq : q < s.trace.claims.length) :
    (((s.trace.claims.zipIdx.filter p).map R).foldl (fun t r => t.set r.pos (some r.counts))
      t).get q =
      if p (s.trace.claims[q], q) then some (R (s.trace.claims[q], q)).counts else t.get q := by
  have hltC : ∀ q, q < s.trace.claims.length → q < 2 ^ claimDepth s := by
    intro q hq
    have := lt_depthFor (cxOf s).claims.size
    simp only [cxOf, ctx_claims, List.size_toArray] at this
    exact Nat.lt_trans hq this
  have hlt : ∀ r ∈ (s.trace.claims.zipIdx.filter p).map R, r.pos < 2 ^ claimDepth s := by
    intro r hr
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hr
    rw [hR]
    exact hltC _ (List.mem_zipIdx' (x := x.1) (i := x.2) (List.mem_filter.mp hx).1).1
  by_cases hp : p (s.trace.claims[q], q)
  · rw [ite_eq_left hp]
    have hx : (s.trace.claims[q], q) ∈ s.trace.claims.zipIdx.filter p :=
      List.mem_filter.mpr ⟨List.mem_zipIdx_iff_getElem?.mpr (by simp [hq]), hp⟩
    have hnd : (((s.trace.claims.zipIdx.filter p).map R).map (·.pos)).Nodup := by
      rw [List.map_map]
      have : ((·.pos) ∘ R) = (·.2) := funext hR
      rw [this]
      exact positions_nodup _ _
    have := foldSet_on (fun (r : Recount) => r.pos) (fun (r : Recount) => r.counts) _ t hc hlt hnd
      (R (s.trace.claims[q], q)) (List.mem_map.mpr ⟨_, hx, rfl⟩)
    rw [hR] at this
    exact this
  · rw [ite_eq_right hp]
    apply foldSet_off (fun (r : Recount) => r.pos) (fun (r : Recount) => r.counts) _ t hc hlt q
      (hltC q hq)
    intro r hr hrq
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hr
    rw [hR] at hrq
    obtain ⟨hlt', heq⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) (List.mem_filter.mp hx).1
    apply hp
    have := (List.mem_filter.mp hx).2
    subst hrq
    rw [← heq]
    exact this

/-! ## The claims a step re-tallies -/

section Recount

variable (s : Scenario)

theorem final_of_counts (T : Scenario) (c : Claim) :
    (if T.valid c.subject then
      (Counts.of T.eff T.restsOn c.needsAll).state (!(T.incompatible c).isEmpty) else .cannot) =
      T.final c := by
  unfold Scenario.final Scenario.intrinsic
  rw [counts_state]

theorem valid_count (T : Scenario) (sub : String) :
    ((T.conflicts sub).length == 0) = T.valid sub := by
  unfold Scenario.valid
  cases T.conflicts sub <;> rfl

theorem mem_movable (k : Core) (δ : Delta) (q : Nat) :
    q ∈ movable (cxOf s) k δ ↔ ∃ hq : q < s.trace.claims.length,
      (∃ d ∈ δ.changed, d ∈ s.trace.claims[q].needsAll) ∨
        (s.trace.claims[q].subject ∈ touchedSubjects (cxOf s) δ ∧
          δ.valid s.trace.claims[q].subject != (k.activeCount s.trace.claims[q].subject == 0)) := by
  unfold movable
  rw [(ascending_spec _).2, List.mem_append, List.mem_flatMap, List.mem_flatMap]
  simp only [mem_gatesGroup, mem_claimSubjectGroup, List.mem_filter]
  constructor
  · rintro (⟨d, hd, hq, hn⟩ | ⟨sub, ⟨hs, hv⟩, hq, rfl⟩)
    · exact ⟨hq, Or.inl ⟨d, hd, hn⟩⟩
    · exact ⟨hq, Or.inr ⟨hs, hv⟩⟩
  · rintro ⟨hq, ⟨d, hd, hn⟩ | ⟨hs, hv⟩⟩
    · exact Or.inl ⟨d, hd, hq, hn⟩
    · exact Or.inr ⟨_, ⟨hs, hv⟩, hq, rfl⟩

variable {s} (hd : (cxOf s).dense = true) {nd : Node} {L : List String}
  (hn : NodeRepr s nd L) {e : Experiment} (he : s.trace.experiment? e.id = some e)
include hd hn he

/-- Claim `q` at the node + after the step, from the node's counts + the step's delta. -/
theorem step_recount {q : Nat} (hq : q < s.trace.claims.length) :
    nd.recount (cxOf s) (memoOf s) (nd.core (cxOf s) s (coreOf s))
        (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)) q =
      some { pos := q, base := s.final s.trace.claims[q]
             before := (s.applySuccess L).final s.trace.claims[q]
             counts := Counts.of (s.applySuccess (L ++ [e.id])).eff
               (s.applySuccess (L ++ [e.id])).restsOn s.trace.claims[q].needsAll
             after := (s.applySuccess (L ++ [e.id])).final s.trace.claims[q] } := by
  have hk := node_core hd hn
  have h1 := step_after hd hn he
  have hcl : (cxOf s).claims[q]? = some s.trace.claims[q] := by
    simp [cxOf, ctx_claims, List.getElem?_eq_getElem hq]
  unfold Node.recount
  rw [hcl, memo_get s q hq]
  dsimp only
  have hcounts : Delta.counts (cxOf s) (nd.core (cxOf s) s (coreOf s))
      (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))
      s.trace.claims[q].needsAll s.trace.claims[q].needsAll.length (nd.countsAt (memoOf s) q)
      ((cxOf s).needs · q) =
      Counts.of
        (afterOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)).eff
        (afterOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)).restsOn
        s.trace.claims[q].needsAll :=
    delta_counts (s.applySuccess L)
      (extraRef s (s.successPairs L ++ e.success) e.success) hk s.trace.claims[q]
      (nd.countsAt (memoOf s) q) ((cxOf s).needs · q) (hn.cnt q hq) (fun d _ => needs_at s q hq d)
  have hk' : Delta.counts (cxOf s) (nd.core (cxOf s) s (coreOf s))
      (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))
      (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[q]).needs
      (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[q]).needsCount
      (nd.countsAt (memoOf s) q) ((cxOf s).needs · q) =
      Counts.of (s.applySuccess (L ++ [e.id])).eff (s.applySuccess (L ++ [e.id])).restsOn
        s.trace.claims[q].needsAll := by
    rw [show (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[q]).needs =
      s.trace.claims[q].needsAll from rfl,
      show (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[q]).needsCount =
      s.trace.claims[q].needsAll.length from rfl, hcounts,
      eff_congr (S := afterOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success)
        e.success)) (T := s.applySuccess (L ++ [e.id])) rfl rfl h1,
      restsOn_congr (S := afterOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success)
        e.success)) (T := s.applySuccess (L ++ [e.id])) rfl rfl h1]
  have hinc : (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[q]).incompatible =
      !((s.applySuccess (L ++ [e.id])).incompatible s.trace.claims[q]).isEmpty := by
    show (!(Core.incompatible (cxOf s) s s.trace.claims[q]).isEmpty) = _
    rw [incompatible_eq]
    rfl
  have hinc' : (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[q]).incompatible =
      !((s.applySuccess L).incompatible s.trace.claims[q]).isEmpty := hinc
  rw [hk']
  congr 1
  congr 1
  · show Core.final (cxOf s) s (coreOf s) _ = _
    rw [final_eq]
  · rw [hk.activeCount, valid_count, hn.cnt q hq, hinc', final_of_counts]
  · rw [delta_valid, valid_congr (S := afterOf (s.applySuccess L) (extraRef s
      (s.successPairs L ++ e.success) e.success)) (T := s.applySuccess (L ++ [e.id])) rfl rfl h1,
      hinc, final_of_counts]

/-- A claim the step's re-tally skips keeps its needs off the changed facts + its state. -/
theorem step_unmoved {q : Nat} (hq : q < s.trace.claims.length)
    (hm : q ∉ movable (cxOf s) (nd.core (cxOf s) s (coreOf s))
      (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))) :
    (∀ d ∈ s.trace.claims[q].needsAll,
      d ∉ (deltaOf (s.applySuccess L)
        (extraRef s (s.successPairs L ++ e.success) e.success)).changed) ∧
      (s.applySuccess (L ++ [e.id])).final s.trace.claims[q] =
        (s.applySuccess L).final s.trace.claims[q] := by
  have hk := node_core hd hn
  have h1 := step_after hd hn he
  rw [mem_movable] at hm
  have hnd : ∀ d ∈ s.trace.claims[q].needsAll,
      d ∉ (deltaOf (s.applySuccess L)
        (extraRef s (s.successPairs L ++ e.success) e.success)).changed :=
    fun d hdn hdc => hm ⟨hq, Or.inl ⟨d, hdc, hdn⟩⟩
  refine ⟨hnd, ?_⟩
  rw [← final_congr (S := afterOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success)
    e.success)) (T := s.applySuccess (L ++ [e.id])) rfl rfl h1]
  apply final_unchanged _ _ _ hnd
  by_cases hs : s.trace.claims[q].subject ∈ touchedSubjects (cxOf s)
      (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))
  · have hv : ¬ ((deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success)
        e.success)).valid s.trace.claims[q].subject !=
        ((nd.core (cxOf s) s (coreOf s)).activeCount s.trace.claims[q].subject == 0)) = true :=
      fun hv => hm ⟨hq, Or.inr ⟨hs, hv⟩⟩
    simp only [bne_iff_ne, ne_eq, Classical.not_not] at hv
    rw [← delta_valid, hv, hk.activeCount, valid_count]
  · rw [← delta_core (s.applySuccess L) _ hk] at hs
    exact valid_unchanged _ _ (fun h => hs ((touchedSubjects_mem _ _ hk _).mpr h))

/-- The step's re-tallied claims, as the (claim, position) pairs it may move, each before +
after. -/
theorem step_moved :
    (movable (cxOf s) (nd.core (cxOf s) s (coreOf s))
        (deltaOf (s.applySuccess L)
          (extraRef s (s.successPairs L ++ e.success) e.success))).filterMap
      (nd.recount (cxOf s) (memoOf s) (nd.core (cxOf s) s (coreOf s))
        (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))) =
      ((s.trace.claims.zipIdx.filter fun x => decide (x.2 ∈ movable (cxOf s)
          (nd.core (cxOf s) s (coreOf s))
          (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)))).map
        fun x => ({ pos := x.2, base := s.final x.1, before := (s.applySuccess L).final x.1
                    counts := Counts.of (s.applySuccess (L ++ [e.id])).eff
                      (s.applySuccess (L ++ [e.id])).restsOn x.1.needsAll
                    after := (s.applySuccess (L ++ [e.id])).final x.1 } : Recount)) := by
  generalize hδ : deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)
    = δ
  have hraw : ∀ q, q ∈ movable (cxOf s) (nd.core (cxOf s) s (coreOf s)) δ →
      q < s.trace.claims.length := fun q hq => ((mem_movable s _ δ q).mp hq).1
  have hmv : movable (cxOf s) (nd.core (cxOf s) s (coreOf s)) δ =
      (s.trace.claims.zipIdx.filter fun x => decide (x.2 ∈ movable (cxOf s)
        (nd.core (cxOf s) s (coreOf s)) δ)).map (·.2) := by
    have h1 := ascending_eq (l := movable (cxOf s) (nd.core (cxOf s) s (coreOf s)) δ)
      (n := s.trace.claims.length) hraw
    have h2 : ascending (movable (cxOf s) (nd.core (cxOf s) s (coreOf s)) δ) =
        movable (cxOf s) (nd.core (cxOf s) s (coreOf s)) δ := by
      unfold movable
      obtain ⟨hs, hm⟩ := ascending_spec
        (δ.changed.flatMap ((cxOf s).gates.group (cmp := compare) ·) ++
        ((touchedSubjects (cxOf s) δ).filter fun sub =>
          δ.valid sub != ((nd.core (cxOf s) s (coreOf s)).activeCount sub == 0)).flatMap
          ((cxOf s).claimSubject.group (cmp := compare) ·))
      exact eq_of_increasing (ascending_spec _).1 hs fun x => by rw [(ascending_spec _).2, hm]
    exact h2.symm.trans (h1.trans (range_filter_eq _ _))
  conv => lhs; rw [hmv]
  rw [List.filterMap_map]
  apply filterMap_eq_map_of
  intro x hx
  obtain ⟨hlt, heq⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) (List.mem_filter.mp hx).1
  show nd.recount (cxOf s) (memoOf s) (nd.core (cxOf s) s (coreOf s)) δ x.2 = _
  rw [← hδ, step_recount hd hn he hlt]
  simp only [← heq]

/-- A re-tally over the claims the step can move = the count over every claim after it. -/
theorem step_tally (F : State → State → Bool) (n : Nat)
    (h0 : n = s.trace.claims.countP fun c => F (s.final c) ((s.applySuccess L).final c)) :
    n + ((movable (cxOf s) (nd.core (cxOf s) s (coreOf s))
        (deltaOf (s.applySuccess L)
          (extraRef s (s.successPairs L ++ e.success) e.success))).filterMap
      (nd.recount (cxOf s) (memoOf s) (nd.core (cxOf s) s (coreOf s))
        (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)))).countP
        (fun r => F r.base r.after) -
      ((movable (cxOf s) (nd.core (cxOf s) s (coreOf s))
        (deltaOf (s.applySuccess L)
          (extraRef s (s.successPairs L ++ e.success) e.success))).filterMap
      (nd.recount (cxOf s) (memoOf s) (nd.core (cxOf s) s (coreOf s))
        (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)))).countP
        (fun r => F r.base r.before) =
      s.trace.claims.countP fun c => F (s.final c) ((s.applySuccess (L ++ [e.id])).final c) := by
  rw [step_moved hd hn he, List.countP_map, List.countP_map]
  have hfst : ∀ h : Claim → Bool, s.trace.claims.countP h =
      s.trace.claims.zipIdx.countP fun x => h x.1 := by
    intro h
    conv => lhs; rw [← List.zipIdx_map_fst 0 s.trace.claims]
    rw [List.countP_map]; rfl
  rw [h0, hfst, hfst]
  have hp := countP_patch (l := s.trace.claims.zipIdx)
    (occ := s.trace.claims.zipIdx.filter fun x => decide (x.2 ∈ movable (cxOf s)
      (nd.core (cxOf s) s (coreOf s))
      (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))))
    (f := fun x => F (s.final x.1) ((s.applySuccess L).final x.1))
    (g := fun x => F (s.final x.1) ((s.applySuccess (L ++ [e.id])).final x.1))
    (moved := fun x => decide (x.2 ∈ movable (cxOf s) (nd.core (cxOf s) s (coreOf s))
      (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))))
    (List.Perm.refl _) (by
      intro x hx hm
      obtain ⟨hlt, heq⟩ := List.mem_zipIdx' (x := x.1) (i := x.2) hx
      have hnot := (step_unmoved hd hn he hlt (by simpa using hm)).2
      simp only [heq, hnot])
  rw [hp]
  rfl

/-- One step on top of a node answers as the child's scenario (`L` + `e`). -/
theorem step_repr (attached : List Nat) :
    NodeRepr s (nd.step (cxOf s) s (coreOf s) (memoOf s) e attached).node (L ++ [e.id]) := by
  have hk := node_core hd hn
  have h1 := step_after hd hn he
  have hmerge := step_merge hd hn he
  have hinjF : ∀ a b j, factPos s a = some j → factPos s b = some j → a = b :=
    fun _ _ _ ha hb => factPos_inj s ha hb
  have hltF : ∀ a j, factPos s a = some j → j < 2 ^ factDepth s := fun _ _ h => factPos_lt s h
  have hinjU : ∀ a b u, subjectPos s a = some u → subjectPos s b = some u → a = b :=
    fun _ _ _ ha hb => subjectPos_inj s ha hb
  have hltU : ∀ a u, subjectPos s a = some u → u < 2 ^ subjectDepth s :=
    fun _ _ h => subjectPos_lt s h
  have hltC : ∀ q, q < s.trace.claims.length → q < 2 ^ claimDepth s := by
    intro q hq
    have := lt_depthFor (cxOf s).claims.size
    simp only [cxOf, ctx_claims, List.size_toArray] at this
    exact Nat.lt_trans hq this
  -- The scenario after the step's overrides answers as the child's.
  have hA1 := h1
  have hAeff := eff_congr
    (S := afterOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))
    (T := s.applySuccess (L ++ [e.id])) rfl rfl h1
  have hAconf := conflicts_congr (S := afterOf (s.applySuccess L) (extraRef s
    (s.successPairs L ++ e.success) e.success)) (T := s.applySuccess (L ++ [e.id])) rfl rfl h1
  have hArest := restsOn_congr (S := afterOf (s.applySuccess L) (extraRef s
    (s.successPairs L ++ e.success) e.success)) (T := s.applySuccess (L ++ [e.id])) rfl rfl h1
  unfold Node.step
  dsimp only
  rw [step_delta hd hn he]
  have heff1 := setAt_get (factPos s) hinjF hltF
    (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)).eff1
    (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)).keys
    nd.eff1 hn.eff1C
  have heff := setAt_get (factPos s) hinjF hltF
    (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)).eff
    (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)).changed
    nd.eff hn.effC
  have hact := setAt_get (subjectPos s) hinjU hltU
    (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)).activeCount
    (touchedSubjects (cxOf s)
      (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success)))
    nd.act hn.actC
  refine ⟨heff1.1, heff.1, hact.1, foldSet_complete _ _ _ _ hn.cntC, ?_, ?_, ?_, ?_, hmerge.1,
    hmerge.2, ?_, ?_, ?_, ?_⟩
  · -- eff1: a key of the step at the delta's status, any other as the parent had it.
    intro k j hkj
    rw [heff1.2 k j hkj]
    by_cases hkk : k ∈ (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success)
        e.success)).keys
    · rw [ite_eq_left hkk, Option.getD_some, delta_eff1, h1]
    · rw [ite_eq_right hkk, hn.eff1 k j hkj, ← h1, eff1_off_keys]
      rw [delta_keys, List.mem_eraseDups] at hkk
      exact hkk
  · intro k j hkj
    rw [heff.2 k j hkj]
    by_cases hkc : k ∈ (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success)
        e.success)).changed
    · rw [ite_eq_left hkc, Option.getD_some, delta_eff, hAeff]
    · rw [ite_eq_right hkc, hn.eff k j hkj, ← hAeff, eff_off_changed _ _ hkc]
  · intro sub u hsu
    rw [hact.2 sub u hsu]
    by_cases hst : sub ∈ touchedSubjects (cxOf s)
        (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))
    · rw [ite_eq_left hst, Option.getD_some, delta_activeCount, hAconf]
    · rw [ite_eq_right hst, hn.act sub u hsu, ← hAconf, activeCount_off]
      intro hm
      apply hst
      rw [← delta_core (s.applySuccess L) _ hk]
      exact (touchedSubjects_mem _ _ hk _).mpr hm
  · -- cnt: a re-tallied claim at its new counts, any other at its old ones (needs unchanged).
    intro q hq
    unfold Node.countsAt
    rw [step_moved hd hn he, foldCounts_get s _ _ (fun _ => rfl) nd.cnt hn.cntC hq]
    by_cases hqm : q ∈ movable (cxOf s) (nd.core (cxOf s) s (coreOf s))
        (deltaOf (s.applySuccess L) (extraRef s (s.successPairs L ++ e.success) e.success))
    · rw [ite_eq_left (by simpa using hqm)]
    · rw [ite_eq_right (by simpa using hqm)]
      have hnc := hn.cnt q hq
      unfold Node.countsAt at hnc
      rw [hnc]
      obtain ⟨hoff, _⟩ := step_unmoved hd hn he hq hqm
      unfold Counts.of
      have he' : ∀ d ∈ s.trace.claims[q].needsAll,
          (s.applySuccess (L ++ [e.id])).eff d = (s.applySuccess L).eff d := by
        intro d hd'
        rw [← hAeff, eff_off_changed _ _ (hoff d hd')]
      have hr' : ∀ d ∈ s.trace.claims[q].needsAll,
          (s.applySuccess (L ++ [e.id])).restsOn d = (s.applySuccess L).restsOn d := by
        intro d hd'
        unfold Scenario.restsOn Scenario.mustVerify
        rw [he' d hd']
        rfl
      congr 1
      · exact List.countP_congr fun d hd' => by rw [he' d hd']
      · exact List.countP_congr fun d hd' => by rw [he' d hd']
      · exact List.countP_congr fun d hd' => by rw [hr' d hd']
  · -- contingent: the closure's keys gain `e`'s.
    rw [successPairs_snoc s L he, List.map_append, List.any_append, ← hn.contingent, List.any_map]
    rfl
  · exact step_tally hd hn he lightsTo nd.lights hn.lights
  · exact step_tally hd hn he clearsTo nd.clears hn.clears
  · exact step_tally hd hn he lowersTo nd.lowers hn.lowers

/-- The states a step reports for its attached claims: each one's state after the step. -/
theorem step_answers (attached : List Nat) :
    ∀ x ∈ (nd.step (cxOf s) s (coreOf s) (memoOf s) e attached).answers,
      x.1 ∈ attached ∧ ∃ hq : x.1 < s.trace.claims.length,
        x.2 = (s.applySuccess (L ++ [e.id])).final s.trace.claims[x.1] := by
  unfold Node.step
  dsimp only
  rw [step_delta hd hn he]
  intro x hx
  obtain ⟨q, hqa, hrq⟩ := List.mem_filterMap.mp hx
  have hq : q < s.trace.claims.length := by
    rcases Nat.lt_or_ge q s.trace.claims.length with h | h
    · exact h
    · exfalso
      unfold Node.recount at hrq
      simp [cxOf, ctx_claims, List.getElem?_eq_none h] at hrq
  rw [step_recount hd hn he hq] at hrq
  simp only [Option.map_some, Option.some.injEq] at hrq
  subst hrq
  exact ⟨hqa, hq, rfl⟩

end Recount

/-! ## A node's row -/

section Row

variable (s : Scenario)

theorem filterMap_moves_count (T : Scenario) (P : Scenario.Move → Bool)
    (hP : ∀ c, P { claim := c.id, before := s.final c, after := T.final c } = true →
      s.final c ≠ T.final c) :
    ((s.moves T).filter P).length = s.trace.claims.countP fun c =>
      P { claim := c.id, before := s.final c, after := T.final c } := by
  unfold Scenario.moves
  generalize s.trace.claims = l
  induction l with
  | nil => rfl
  | cons c l ih =>
    rw [List.filterMap_cons, List.countP_cons]
    by_cases hne : s.final c != T.final c
    · rw [ite_eq_left hne]
      dsimp only
      rw [List.filter_cons]
      split <;> simp_all
    · rw [ite_eq_right hne]
      dsimp only
      have : P { claim := c.id, before := s.final c, after := T.final c } = false := by
        cases h : P { claim := c.id, before := s.final c, after := T.final c }
        · rfl
        · exact absurd (by simpa using hne) (hP c h)
      rw [this, ih]
      rfl

theorem lights_count (T : Scenario) :
    Scenario.lights (s.moves T) =
      s.trace.claims.countP fun c => lightsTo (s.final c) (T.final c) := by
  unfold Scenario.lights
  refine (filterMap_moves_count s T _ ?_).trans rfl
  intro c h heq
  unfold lightsTo at h
  rw [heq] at h
  simp at h

theorem clears_count (T : Scenario) :
    Scenario.clears (s.moves T) =
      s.trace.claims.countP fun c => clearsTo (s.final c) (T.final c) := by
  unfold Scenario.clears
  refine (filterMap_moves_count s T _ ?_).trans rfl
  intro c h heq
  simp only at h
  rw [heq] at h
  generalize T.final c = x at h
  cases x <;> simp at h

theorem lowers_count (T : Scenario) :
    Scenario.lowers (s.moves T) =
      s.trace.claims.countP fun c => lowersTo (s.final c) (T.final c) := by
  unfold Scenario.lowers
  refine (filterMap_moves_count s T _ ?_).trans rfl
  intro c h heq
  simp only at h
  rw [heq] at h
  simp at h

theorem applied_count (L : List String) :
    ((s.merged L).countP (mis s) == 0) =
      (s.merged L).all fun x => s.overrides.lookup x.1 == some x.2 := by
  rw [Bool.eq_iff_iff, beq_iff_eq, List.countP_eq_zero, List.all_eq_true]
  unfold mis
  simp only [override_eq, bne_iff_ne, ne_eq, Bool.not_eq_true, beq_eq_false_iff_ne,
    Classical.not_not, beq_iff_eq]

theorem contingent_keys (L : List String) :
    ((s.successPairs L).map (·.1)).any (cxOf s).isResult =
      (s.merged L).any fun x => s.resultFacts.contains x.1 := by
  rw [merged_of]
  unfold mergedOf
  rw [Bool.eq_iff_iff, List.any_eq_true, List.any_eq_true]
  constructor
  · rintro ⟨k, hk, hr⟩
    refine ⟨(k, topOf (s.successPairs L) k),
      List.mem_map.mpr ⟨k, List.mem_eraseDups.mpr hk, rfl⟩, ?_⟩
    rw [isResult_eq] at hr
    exact hr
  · rintro ⟨x, hx, hr⟩
    obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hx
    refine ⟨k, List.mem_eraseDups.mp hk, ?_⟩
    rw [isResult_eq]
    exact hr

end Row

/-! ## A forest position's closure, from its parent's -/

section ForestClosure

open Fvtrace.Proofs.Forest

variable (s : Scenario)

theorem pathUp_acc (A : Array (Option Nat)) (hdec : Decreasing A) :
    ∀ fuel p (acc : List Nat), p < fuel → pathUp A fuel p acc = pathUp A fuel p [] ++ acc
  | 0, _, _, h => absurd h (Nat.not_lt_zero _)
  | fuel + 1, p, acc, h => by
    unfold pathUp
    split
    · rename_i r hr
      have := hdec p r hr
      rw [pathUp_acc A hdec fuel r (p :: acc) (by omega), pathUp_acc A hdec fuel r [p] (by omega)]
      simp
    · simp

theorem pathUp_fuel (A : Array (Option Nat)) (hdec : Decreasing A) :
    ∀ f f' p, p < f → p < f' → pathUp A f p [] = pathUp A f' p []
  | 0, _, _, h, _ => absurd h (Nat.not_lt_zero _)
  | _, 0, _, _, h => absurd h (Nat.not_lt_zero _)
  | f + 1, f' + 1, p, h, h' => by
    unfold pathUp
    split
    · rename_i r hr
      have := hdec p r hr
      rw [pathUp_acc A hdec f r [p] (by omega), pathUp_acc A hdec f' r [p] (by omega),
        pathUp_fuel A hdec f f' r (by omega) (by omega)]
    · rfl

theorem pathUp_increasing (A : Array (Option Nat)) (hdec : Decreasing A) :
    ∀ fuel p, p < fuel → (pathUp A fuel p []).Pairwise (· < ·) ∧ ∀ x ∈ pathUp A fuel p [], x ≤ p
  | 0, _, h => absurd h (Nat.not_lt_zero _)
  | fuel + 1, p, h => by
    unfold pathUp
    split
    · rename_i r hr
      have hrp := hdec p r hr
      rw [pathUp_acc A hdec fuel r [p] (by omega)]
      obtain ⟨h1, h2⟩ := pathUp_increasing A hdec fuel r (by omega)
      refine ⟨List.pairwise_append.mpr ⟨h1, by simp, fun x hx y hy => ?_⟩, fun x hx => ?_⟩
      · rw [List.mem_singleton] at hy; subst hy; have := h2 x hx; omega
      · rcases List.mem_append.mp hx with hx | hx
        · have := h2 x hx; omega
        · rw [List.mem_singleton] at hx; omega
    · simp

local notation "fo" => Forest.build (cxOf s)

theorem firstPos_self (hnd : (s.trace.experiments.map (·.id)).Nodup) {i : Nat}
    (hi : i < s.trace.experiments.length) :
    (cxOf s).firstPos s.trace.experiments[i].id = some i := by
  rw [Fvtrace.Proofs.Closure.firstPos_eq, List.findIdx?_eq_some_iff_getElem]
  refine ⟨hi, by simp, fun j hj => ?_⟩
  have hjn : j < s.trace.experiments.length := Nat.lt_trans hj hi
  have : s.trace.experiments[j].id ≠ s.trace.experiments[i].id := by
    intro h
    have := hnd.eq_of_getElem_eq (by simpa using hjn) (by simpa using hi) (by simpa using h)
    omega
  simpa using this

theorem good_lt {i : Nat} (hg : (fo).good[i]? = some true) : i < s.trace.experiments.length := by
  have hinv := (build_inv s).1
  have := get_size_lt hg
  rw [hinv.size, (build_inv s).2] at this
  exact this

/-- A forest position's closure = its path's experiments, in trace order. -/
theorem closure_good {i : Nat} (hg : (fo).good[i]? = some true) :
    s.closure [(s.trace.experiments[i]'(good_lt s hg)).id] =
      (pathUp (fo).parent (i + 1) i []).filterMap
        fun p => (s.trace.experiments[p]?).map (·.id) := by
  have hi := good_lt s hg
  have hinv := (build_inv s).1
  rw [← congrFun (closureWith_eq s)]
  unfold Ctx.closureWith
  rw [List.flatMap_singleton, firstPos_self s (good_nodup s hg) hi]
  dsimp only
  have hp : (fo).path? i = some (pathUp (fo).parent (i + 1) i []) := by
    unfold Forest.path?
    rw [hg]
    rfl
  rw [hp]
  dsimp only
  obtain ⟨hinc, _⟩ := pathUp_increasing (fo).parent hinv.dec (i + 1) i (by omega)
  have hasc : ascending (pathUp (fo).parent (i + 1) i []) = pathUp (fo).parent (i + 1) i [] :=
    eq_of_increasing (ascending_spec _).1 hinc fun x => (ascending_spec _).2 x
  rw [hasc]
  simp [cxOf, ctx_experiments]

/-- A forest child's closure = its parent's + itself (it comes last in trace order). -/
theorem closure_child {i p : Nat} (hg : (fo).good[i]? = some true)
    (hp : (fo).parent[i]? = some (some p)) :
    ∃ hp' : p < s.trace.experiments.length,
      s.closure [(s.trace.experiments[i]'(good_lt s hg)).id] =
        s.closure [s.trace.experiments[p].id] ++ [(s.trace.experiments[i]'(good_lt s hg)).id] := by
  have hinv := (build_inv s).1
  have hpi := hinv.dec i p hp
  obtain ⟨hgp, _, _⟩ := hinv.parent i p hp
  have hpn := good_lt s hgp
  refine ⟨hpn, ?_⟩
  rw [closure_good s hg, closure_good s hgp]
  have hpath : pathUp (fo).parent (i + 1) i [] = pathUp (fo).parent (p + 1) p [] ++ [i] := by
    show (match (fo).parent[i]? with
      | some (some r) => pathUp (fo).parent i r [i]
      | _ => [i]) = _
    rw [hp]
    dsimp only
    rw [pathUp_acc _ hinv.dec i p [i] hpi, pathUp_fuel _ hinv.dec i (p + 1) p hpi (by omega)]
  rw [hpath, List.filterMap_append]
  simp [List.getElem?_eq_getElem (good_lt s hg)]

/-- A forest root's closure = itself. -/
theorem closure_root {i : Nat} (hg : (fo).good[i]? = some true)
    (hp : ∀ r, (fo).parent[i]? ≠ some (some r)) :
    s.closure [(s.trace.experiments[i]'(good_lt s hg)).id] =
      [] ++ [(s.trace.experiments[i]'(good_lt s hg)).id] := by
  rw [closure_good s hg]
  have hpath : pathUp (fo).parent (i + 1) i [] = [i] := by
    show (match (fo).parent[i]? with
      | some (some r) => pathUp (fo).parent i r [i]
      | _ => [i]) = _
    split
    · rename_i r hr; exact absurd hr (hp r)
    · rfl
  rw [hpath]
  simp [List.getElem?_eq_getElem (good_lt s hg)]

end ForestClosure

/-! ## Plans the walk answers: one relevant experiment, on the forest -/

section Plans

variable (s : Scenario)

/-- A plan over one relevant experiment (`Singleton.search_singleton`): planned at the state its
closure gives the claim when that ranks higher, else no improvement. -/
theorem summary_single {c : Claim} {r : Experiment} (hv : s.valid c.subject = true)
    (hr : s.relevant c = [r]) :
    (s.plan c).summary =
      if ((s.applySuccess (s.closure [r.id])).final c).rank > (s.final c).rank
      then .planned ((s.applySuccess (s.closure [r.id])).final c) else .noImprovement := by
  unfold Scenario.plan
  rw [hv, hr]
  simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte, List.length_singleton]
  rw [ite_eq_right (by unfold maxRelevant; omega)]
  unfold Scenario.best
  rw [hr]
  simp only [List.map_cons, List.map_nil]
  rw [Fvtrace.Proofs.Singleton.search_singleton]
  by_cases hup : ((s.applySuccess (s.closure [r.id])).final c).rank > (s.final c).rank
  · have hval : (s.applySuccess (s.closure [r.id])).valid c.subject = true := by
      cases hvv : (s.applySuccess (s.closure [r.id])).valid c.subject
      · unfold Scenario.final at hup; rw [hvv] at hup; simp [State.rank] at hup
      · rfl
    have hsel : (if ((s.applySuccess (s.closure [r.id])).valid c.subject &&
        decide (((s.applySuccess (s.closure [r.id])).final c).rank > (s.final c).rank)) = true
        then s.closure [r.id] else []) = s.closure [r.id] := ite_eq_left (by simp [hval, hup])
    rw [hsel, ite_eq_left hup, ite_eq_right (by omega)]
    rfl
  · have hsel : (if ((s.applySuccess (s.closure [r.id])).valid c.subject &&
        decide (((s.applySuccess (s.closure [r.id])).final c).rank > (s.final c).rank)) = true
        then s.closure [r.id] else []) = [] := ite_eq_right (by simp [hup])
    rw [hsel, ite_eq_right hup, Fvtrace.Proofs.Plan.applySuccess_nil, ite_eq_left (Nat.le_refl _)]
    rfl

local notation "fo" => Forest.build (cxOf s)

/-- Each claim position the walk attaches to a forest position has a consistent subject and that
experiment as its one relevant one. -/
theorem attachments_spec :
    ∀ r q, q ∈ ((attachments (cxOf s) (coreOf s) fo (memoOf s))[r]?).getD [] →
      ∃ hq : q < s.trace.claims.length, ∃ hr : r < s.trace.experiments.length,
        s.valid s.trace.claims[q].subject = true ∧
          s.relevant s.trace.claims[q] = [s.trace.experiments[r]] ∧ (fo).good[r]? = some true := by
  unfold attachments
  rw [cxOf, ctx_claims, List.foldl_toArray]
  -- The positions attached so far: each below the claims processed, each with the property.
  have key : ∀ (l : List Claim) (acc : Array (List Nat) × Nat),
      (∀ j c, l[j]? = some c → s.trace.claims[acc.2 + j]? = some c) →
      (∀ r q, q ∈ (acc.1[r]?).getD [] → ∃ hq : q < s.trace.claims.length,
        ∃ hr : r < s.trace.experiments.length, s.valid s.trace.claims[q].subject = true ∧
          s.relevant s.trace.claims[q] = [s.trace.experiments[r]] ∧ (fo).good[r]? = some true) →
      ∀ r q, q ∈ ((l.foldl (fun acc c =>
          (match (memoOf s)[acc.2]? with
            | some m =>
              if (coreOf s).valid c.subject then
                match relevantPositions (cxOf s) (coreOf s) m.needs c.subject with
                | [r] => if (fo).good[r]?.getD false then acc.1.modify r (acc.2 :: ·) else acc.1
                | _ => acc.1
              else acc.1
            | none => acc.1, acc.2 + 1)) acc).1[r]?).getD [] →
        ∃ hq : q < s.trace.claims.length, ∃ hr : r < s.trace.experiments.length,
          s.valid s.trace.claims[q].subject = true ∧
            s.relevant s.trace.claims[q] = [s.trace.experiments[r]] ∧
              (fo).good[r]? = some true := by
    intro l
    induction l with
    | nil => intro acc _ h; simpa using h
    | cons c l ih =>
      intro acc hl hacc
      rw [List.foldl_cons]
      apply ih
      · intro j c' hj
        have := hl (j + 1) c' (by simpa using hj)
        rw [show acc.2 + 1 + j = acc.2 + (j + 1) by omega]
        exact this
      · have hc : s.trace.claims[acc.2]? = some c := by simpa using hl 0 c rfl
        have hq0 : acc.2 < s.trace.claims.length := by
          rcases Nat.lt_or_ge acc.2 s.trace.claims.length with h | h
          · exact h
          · rw [List.getElem?_eq_none h] at hc; cases hc
        have hc' : s.trace.claims[acc.2] = c := by
          rw [List.getElem?_eq_getElem hq0] at hc; exact Option.some.inj hc
        intro r q hq
        simp only [memoOf, cxOf, ctx_claims, List.getElem?_toArray, Array.getElem?_map,
          List.getElem?_eq_getElem hq0, Option.map_some] at hq
        split at hq
        · rename_i hv
          split at hq
          · rename_i r0 hrel
            split at hq
            · rename_i hg
              rw [Array.getElem?_modify] at hq
              by_cases hrr : r0 = r
              · subst hrr
                rw [ite_eq_left rfl] at hq
                cases hacc' : acc.1[r0]? with
                | none => rw [hacc'] at hq; simp at hq
                | some old =>
                  rw [hacc'] at hq
                  simp only [Option.map_some, Option.getD_some, List.mem_cons] at hq
                  rcases hq with rfl | hq
                  · -- the claim just attached
                    have hrv : s.valid c.subject = true := by rw [valid_eq] at hv; exact hv
                    have hg' : (fo).good[r0]? = some true := by
                      cases hh : (fo).good[r0]? with
                      | none => rw [hh] at hg; cases hg
                      | some b => rw [hh] at hg; simp at hg; rw [hg]
                    have hrn : r0 < s.trace.experiments.length := good_lt s hg'
                    refine ⟨hq0, hrn, by rw [hc']; exact hrv, ?_, hg'⟩
                    rw [hc']
                    have h1 := relPos_eq s c
                    have h2 := relevant_read s c
                    rw [show (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[acc.2]).needs =
                      c.needsAll by rw [hc']; rfl] at hrel
                    unfold relevantPositions at hrel
                    rw [hrel] at h1
                    rw [← h1] at h2
                    rw [← h2]
                    simp [cxOf, ctx_experiments, List.getElem?_eq_getElem hrn]
                  · exact hacc r0 q (by rw [hacc']; exact hq)
              · rw [ite_eq_right hrr] at hq
                exact hacc r q hq
            · exact hacc r q hq
          · exact hacc r q hq
        · exact hacc r q hq
  intro r q hq
  exact key s.trace.claims (Array.replicate (cxOf s).experiments.size [], 0)
    (fun j c h => by simpa using h)
    (fun r q h => by
      simp only [Array.getElem?_replicate] at h
      split at h <;> simp at h) r q hq

end Plans

/-! ## The plan summaries no search decides (`presummaries`) -/

section Pre

variable (s : Scenario)

/-- No relevant experiment: the search keeps the empty plan, which improves nothing. -/
theorem summary_none {c : Claim} (hv : s.valid c.subject = true) (hr : s.relevant c = []) :
    (s.plan c).summary = .noImprovement := by
  unfold Scenario.plan Scenario.best
  rw [hv, hr]
  simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte, List.length_nil, List.map_nil]
  rw [ite_eq_right (by unfold maxRelevant; omega)]
  have hs : s.search c [] [] [] = [] := by
    unfold Scenario.search
    rw [Fvtrace.Proofs.Singleton.closure_nil]
    dsimp only
    split <;> rfl
  rw [hs, Fvtrace.Proofs.Plan.applySuccess_nil, ite_eq_left (Nat.le_refl _)]
  rfl

theorem relevant_of_positions (c : Claim) :
    (relevantPositions (cxOf s) (coreOf s) c.needsAll c.subject).filterMap
      ((cxOf s).experiments[·]?) = s.relevant c := by
  unfold relevantPositions
  rw [relPos_eq]
  exact relevant_read s c

theorem positions_length (c : Claim) :
    (relevantPositions (cxOf s) (coreOf s) c.needsAll c.subject).length =
      (s.relevant c).length := by
  rw [← relevant_of_positions s c]
  unfold relevantPositions
  rw [relPos_eq]
  rw [filterMap_eq_map_of (g := fun p => s.trace.experiments[p]!) ?_]
  · rw [List.length_map]
  · intro p hp
    have hpn := List.mem_range.mp (List.mem_filter.mp hp).1
    simp [cxOf, ctx_experiments, List.getElem?_eq_getElem hpn, hpn]

/-- Every summary `presummaries` fills = the plan's. -/
theorem presummaries_spec :
    ∀ q sm, (presummaries (cxOf s) (coreOf s) (memoOf s))[q]? = some (some sm) →
      ∃ hq : q < s.trace.claims.length, sm = (s.plan s.trace.claims[q]).summary := by
  unfold presummaries
  rw [cxOf, ctx_claims, List.foldl_toArray]
  have key : ∀ (l : List Claim) (acc : Array (Option PlanSummary) × Nat),
      acc.1.size = acc.2 →
      (∀ j c, l[j]? = some c → s.trace.claims[acc.2 + j]? = some c) →
      (∀ q sm, acc.1[q]? = some (some sm) →
        ∃ hq : q < s.trace.claims.length, sm = (s.plan s.trace.claims[q]).summary) →
      ∀ q sm, (l.foldl (fun acc c =>
          (acc.1.push (match (memoOf s)[acc.2]? with
            | some m =>
              if !(coreOf s).valid c.subject then some .inconsistent
              else match relevantPositions (cxOf s) (coreOf s) m.needs c.subject with
                | [] => some .noImprovement
                | rel => if rel.length > maxRelevant then some .tooLarge else none
            | none => none), acc.2 + 1)) acc).1[q]? = some (some sm) →
        ∃ hq : q < s.trace.claims.length, sm = (s.plan s.trace.claims[q]).summary := by
    intro l
    induction l with
    | nil => intro acc _ _ h; simpa using h
    | cons c l ih =>
      intro acc hsz hl hacc
      rw [List.foldl_cons]
      have hc : s.trace.claims[acc.2]? = some c := by simpa using hl 0 c rfl
      have hq0 : acc.2 < s.trace.claims.length := by
        rcases Nat.lt_or_ge acc.2 s.trace.claims.length with h | h
        · exact h
        · rw [List.getElem?_eq_none h] at hc; cases hc
      have hc' : s.trace.claims[acc.2] = c := by
        rw [List.getElem?_eq_getElem hq0] at hc; exact Option.some.inj hc
      apply ih
      · simp [hsz]
      · intro j c' hj
        have := hl (j + 1) c' (by simpa using hj)
        rw [show acc.2 + 1 + j = acc.2 + (j + 1) by omega]
        exact this
      · intro q sm hq
        rw [Array.getElem?_push] at hq
        split at hq
        · rename_i hqs
          rw [hsz] at hqs
          subst hqs
          refine ⟨hq0, ?_⟩
          rw [hc']
          simp only [memoOf, cxOf, ctx_claims, List.getElem?_toArray, Array.getElem?_map,
            List.getElem?_eq_getElem hq0, Option.map_some, Option.some.injEq] at hq
          rw [show (ClaimMemo.of (Ctx.build s.trace) s (coreOf s) s.trace.claims[acc.2]).needs =
            c.needsAll by rw [hc']; rfl] at hq
          by_cases hv : (coreOf s).valid c.subject = true
          · rw [hv] at hq
            simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte] at hq
            have hsv : s.valid c.subject = true := by rw [← valid_eq]; exact hv
            cases hrp : relevantPositions (cxOf s) (coreOf s) c.needsAll c.subject with
            | nil =>
              rw [hrp] at hq
              simp only [Option.some.injEq] at hq
              subst hq
              have : s.relevant c = [] := by
                rw [← relevant_of_positions s c, hrp]; rfl
              exact (summary_none s hsv this).symm
            | cons r rs =>
              rw [hrp] at hq
              dsimp only at hq
              split at hq
              · rename_i hlen
                simp only [Option.some.injEq] at hq
                subst hq
                unfold Scenario.plan
                rw [hsv]
                simp only [Bool.not_true, Bool.false_eq_true, ↓reduceIte]
                rw [ite_eq_left (by rw [← positions_length s c, hrp]; exact hlen)]
                rfl
              · cases hq
          · simp only [Bool.not_eq_true] at hv
            rw [hv] at hq
            simp only [Bool.not_false, ↓reduceIte, Option.some.injEq] at hq
            subst hq
            have hsv : s.valid c.subject = false := by rw [← valid_eq]; exact hv
            unfold Scenario.plan
            rw [hsv]
            rfl
        · exact hacc q sm hq
  exact key s.trace.claims (#[], 0) rfl (fun j c h => by simpa using h)
    (fun q sm h => by simp at h)

end Pre

/-! ## The walk = the reference rows + the summaries it answers -/

section WalkEq

open Fvtrace.Proofs.Forest

variable (s : Scenario) (fallback : Experiment → ExperimentRow)
  (failureMoves : Experiment → List Scenario.Move)

/-- The environment `fast` runs the walk in. -/
abbrev envOf : WalkEnv :=
  { cx := cxOf s, s, core := coreOf s, memo := memoOf s, fo := Forest.build (cxOf s), fallback
    failureMoves
    dense := (cxOf s).dense
    attached := if (cxOf s).dense then
        attachments (cxOf s) (coreOf s) (Forest.build (cxOf s)) (memoOf s) else #[]
    hasChild := (Forest.build (cxOf s)).hasChild }

local notation "fo" => Forest.build (cxOf s)

/-- What the walk's state holds after its first positions. -/
structure WalkInv (acc : WalkState) : Prop where
  size : acc.1.size = acc.2.1.size
  row : ∀ j (hj : j < acc.2.1.size), ∃ hjn : j < s.trace.experiments.length,
    acc.2.1[j] = rowRefOf s s.trace.experiments[j]
  node : ∀ j nd, acc.1[j]? = some (some nd) → ∃ hg : (fo).good[j]? = some true,
    (cxOf s).dense = true ∧ NodeRepr s nd (s.closure [(s.trace.experiments[j]'(good_lt s hg)).id])
  plan : ∀ q sm, acc.2.2[q]? = some (some sm) → ∃ hq : q < s.trace.claims.length,
    sm = (s.plan s.trace.claims[q]).summary

theorem experiment?_self (hnd : (s.trace.experiments.map (·.id)).Nodup) {i : Nat}
    (hi : i < s.trace.experiments.length) :
    s.trace.experiment? s.trace.experiments[i].id = some s.trace.experiments[i] := by
  unfold Trace.experiment?
  rw [List.find?_eq_some_iff_getElem]
  refine ⟨by simp, i, hi, rfl, fun j hj => ?_⟩
  have hjn : j < s.trace.experiments.length := Nat.lt_trans hj hi
  have : s.trace.experiments[j].id ≠ s.trace.experiments[i].id := by
    intro h
    have := hnd.eq_of_getElem_eq (by simpa using hjn) (by simpa using hi) (by simpa using h)
    omega
  simpa using this

/-- The plans an answer fold writes keep every entry a correct summary. -/
theorem plans_fold : ∀ (xs : List (Nat × State)) (ps : Array (Option PlanSummary)),
    (∀ x ∈ xs, ∃ hq : x.1 < s.trace.claims.length,
      (if x.2.rank > (s.final s.trace.claims[x.1]).rank then PlanSummary.planned x.2
        else .noImprovement) = (s.plan s.trace.claims[x.1]).summary) →
    (∀ q sm, ps[q]? = some (some sm) →
      ∃ hq : q < s.trace.claims.length, sm = (s.plan s.trace.claims[q]).summary) →
    ∀ q sm, (xs.foldl (fun ps x =>
        let b := (((memoOf s)[x.1]?).map (·.final)).getD .cannot
        ps.set! x.1 (some (if x.2.rank > b.rank then .planned x.2 else .noImprovement))) ps)[q]? =
          some (some sm) → ∃ hq : q < s.trace.claims.length, sm = (s.plan s.trace.claims[q]).summary
  | [], ps, _, hps => by simpa using hps
  | x :: xs, ps, hrep, hps => by
    rw [List.foldl_cons]
    apply plans_fold xs _ (fun y hy => hrep y (List.mem_cons_of_mem _ hy))
    intro q sm hq
    obtain ⟨hx1, hx⟩ := hrep x List.mem_cons_self
    simp only [Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds] at hq
    split at hq
    · rename_i h
      split at hq
      · subst h
        simp only [Option.some.injEq] at hq
        refine ⟨hx1, ?_⟩
        rw [← hq, ← hx]
        have hm : (ClaimMemo.of (cxOf s) s (coreOf s) s.trace.claims[x.1]).final =
            s.final s.trace.claims[x.1] := by
          show Core.final (cxOf s) s (coreOf s) _ = _
          rw [final_eq]
        simp only [memoOf, cxOf, ctx_claims, List.getElem?_toArray, Array.getElem?_map,
          List.getElem?_eq_getElem hx1, Option.map_some, Option.getD_some]
        rw [show (ClaimMemo.of (Ctx.build s.trace) s (coreOf s) s.trace.claims[x.1]).final =
          s.final s.trace.claims[x.1] from hm]
      · cases hq
    · exact hps q sm hq

/-- Before a forest position's step, its parent's node (the root's for a root) answers as its
parent's closure, and its own closure = that + itself. -/
theorem parent_node {acc : WalkState} (h : WalkInv s acc) {i : Nat} {nd : Node}
    (hpar : (if (cxOf s).dense && (fo).good[i]?.getD false then
        match (fo).parent[i]? with
        | some (some p) => (acc.1[p]?).bind id
        | _ => some (Node.root (cxOf s))
      else none) = some nd) :
    ∃ hg : (fo).good[i]? = some true, (cxOf s).dense = true ∧ ∃ L, NodeRepr s nd L ∧
      s.closure [(s.trace.experiments[i]'(good_lt s hg)).id] =
        L ++ [(s.trace.experiments[i]'(good_lt s hg)).id] := by
  by_cases hc : ((cxOf s).dense && (fo).good[i]?.getD false) = true
  · rw [ite_eq_left hc] at hpar
    simp only [Bool.and_eq_true] at hc
    obtain ⟨hd, hg⟩ := hc
    have hg' : (fo).good[i]? = some true := by
      cases hh : (fo).good[i]? with
      | none => rw [hh] at hg; cases hg
      | some b => rw [hh] at hg; simp at hg; rw [hg]
    refine ⟨hg', hd, ?_⟩
    split at hpar
    · rename_i p hp
      cases hn : acc.1[p]? with
      | none => rw [hn] at hpar; cases hpar
      | some o =>
        rw [hn] at hpar
        simp only [Option.bind_some, id] at hpar
        subst hpar
        obtain ⟨hgp, _, hrep⟩ := h.node p _ hn
        obtain ⟨hpn, hcl⟩ := closure_child s hg' hp
        exact ⟨_, hrep, hcl⟩
    · rename_i hnp
      simp only [Option.some.injEq] at hpar
      subst hpar
      refine ⟨[], root_repr s, closure_root s hg' ?_⟩
      intro r hr
      exact hnp r hr
  · rw [ite_eq_right hc] at hpar
    cases hpar

/-- One position keeps the walk's guarantees. -/
theorem walkStep_inv (hfb : fallback = rowRefOf s)
    (hfm : ∀ e, failureMoves e = s.moves (s.applyFailure e)) {acc : WalkState} (h : WalkInv s acc)
    {e : Experiment} (he : s.trace.experiments[acc.2.1.size]? = some e) :
    WalkInv s (walkStep (envOf s fallback failureMoves) acc e) ∧
      (walkStep (envOf s fallback failureMoves) acc e).2.1.size = acc.2.1.size + 1 := by
  have hin : acc.2.1.size < s.trace.experiments.length := by
    rcases Nat.lt_or_ge acc.2.1.size s.trace.experiments.length with h' | h'
    · exact h'
    · rw [List.getElem?_eq_none h'] at he; cases he
  have hei : s.trace.experiments[acc.2.1.size] = e := by
    rw [List.getElem?_eq_getElem hin] at he; exact Option.some.inj he
  unfold walkStep
  dsimp only
  split
  · rename_i nd hpar
    obtain ⟨hg, hd, L, hn, hcl⟩ := parent_node s h hpar
    have hnd := good_nodup s hg
    have he' : s.trace.experiment? e.id = some e := by
      rw [← hei]; exact experiment?_self s hnd hin
    have hcl' : s.closure [e.id] = L ++ [e.id] := by
      have := hcl; simp only [hei] at this; exact this
    have hrep := step_repr hd hn he' ((if (cxOf s).dense then
      attachments (cxOf s) (coreOf s) (Forest.build (cxOf s)) (memoOf s)
        else #[])[acc.2.1.size]?.getD [])
    rw [← hcl'] at hrep
    refine ⟨⟨by simp [h.size], ?_, ?_, ?_⟩, by simp⟩
    · -- rows: the old ones, then this position's from its node
      intro j hj
      simp only [Array.size_push] at hj
      by_cases hji : j < acc.2.1.size
      · obtain ⟨hjn, hrow⟩ := h.row j hji
        refine ⟨hjn, ?_⟩
        rw [Array.getElem_push_lt hji]
        exact hrow
      · have hj' : j = acc.2.1.size := by omega
        subst hj'
        refine ⟨hin, ?_⟩
        rw [Array.getElem_push_eq, hei]
        unfold rowRefOf rowOf
        dsimp only
        rw [hcl', ← hcl']
        rw [lights_count, clears_count, lowers_count, ← hrep.lights, ← hrep.clears,
          ← hrep.lowers, hfm, ← applied_count, ← contingent_keys, ← hrep.bad, ← hrep.contingent]
        rfl
    · -- nodes: the old ones, then this one's when kept
      intro j nd' hj
      by_cases hji : j < acc.1.size
      · rw [Array.getElem?_push, ite_eq_right (by omega)] at hj
        exact h.node j nd' hj
      · rw [Array.getElem?_push] at hj
        split at hj
        · rename_i hjs
          simp only [Option.some.injEq] at hj
          split at hj
          · simp only [Option.some.injEq] at hj
            subst hj
            have hji' : j = acc.2.1.size := by rw [hjs, h.size]
            subst hji'
            refine ⟨hg, hd, ?_⟩
            simp only [hei]
            exact hrep
          · cases hj
        · rw [Array.getElem?_eq_none (by omega)] at hj; cases hj
    · -- plans: each attached claim's summary from the state its closure gives it
      apply plans_fold s
      · intro x hx
        obtain ⟨hxa, hxq, hxs⟩ := step_answers hd hn he' _ x hx
        rw [ite_eq_left hd] at hxa
        obtain ⟨hq, hrn, hv, hr, _⟩ := attachments_spec s _ _ hxa
        refine ⟨hxq, ?_⟩
        rw [summary_single s hv hr, hxs, hei, hcl']
      · exact h.plan
  · rename_i hpar
    refine ⟨⟨by simp [h.size], ?_, ?_, h.plan⟩, by simp⟩
    · intro j hj
      simp only [Array.size_push] at hj
      by_cases hji : j < acc.2.1.size
      · obtain ⟨hjn, hrow⟩ := h.row j hji
        refine ⟨hjn, ?_⟩
        rw [Array.getElem_push_lt hji]
        exact hrow
      · have hj' : j = acc.2.1.size := by omega
        subst hj'
        refine ⟨hin, ?_⟩
        rw [Array.getElem_push_eq, hei, hfb]
    · intro j nd' hj
      rw [Array.getElem?_push] at hj
      split at hj
      · cases hj
      · exact h.node j nd' hj

theorem walkFold_inv (hfb : fallback = rowRefOf s)
    (hfm : ∀ e, failureMoves e = s.moves (s.applyFailure e)) :
    ∀ (l : List Experiment) (acc : WalkState), WalkInv s acc →
      (∀ j e, l[j]? = some e → s.trace.experiments[acc.2.1.size + j]? = some e) →
      WalkInv s (l.foldl (walkStep (envOf s fallback failureMoves)) acc) ∧
        (l.foldl (walkStep (envOf s fallback failureMoves)) acc).2.1.size = acc.2.1.size + l.length
  | [], acc, h, _ => ⟨h, by simp⟩
  | e :: l, acc, h, hl => by
    have he : s.trace.experiments[acc.2.1.size]? = some e := by simpa using hl 0 e rfl
    obtain ⟨h', hsz⟩ := walkStep_inv s fallback failureMoves hfb hfm h he
    obtain ⟨h1, h2⟩ := walkFold_inv hfb hfm l _ h' (by
      intro j e' hj
      rw [hsz, Nat.add_assoc, Nat.add_comm 1 j]
      exact hl (j + 1) e' (by simpa using hj))
    refine ⟨by simpa using h1, ?_⟩
    simp only [List.foldl_cons, List.length_cons]
    rw [h2, hsz]; omega

/-- The walk's rows = the reference rows in trace order; every summary it answers = the plan's. -/
theorem walk_eq (hfb : fallback = rowRefOf s)
    (hfm : ∀ e, failureMoves e = s.moves (s.applyFailure e)) :
    (walk (cxOf s) s (coreOf s) (memoOf s) (fo) fallback failureMoves).1.toList =
        s.trace.experiments.map (rowRefOf s) ∧
      ∀ q sm, (walk (cxOf s) s (coreOf s) (memoOf s) (fo) fallback failureMoves).2[q]? =
        some (some sm) → ∃ hq : q < s.trace.claims.length,
          sm = (s.plan s.trace.claims[q]).summary := by
  have h0 : WalkInv s ((#[], #[], presummaries (cxOf s) (coreOf s) (memoOf s)) : WalkState) :=
    ⟨rfl, fun _ hj => by simp at hj, fun _ _ h => by simp at h, presummaries_spec s⟩
  have hfold := walkFold_inv s fallback failureMoves hfb hfm s.trace.experiments _ h0
    (fun j e h => by simpa using h)
  have hw : walk (cxOf s) s (coreOf s) (memoOf s) (fo) fallback failureMoves =
      (((cxOf s).experiments.foldl (walkStep (envOf s fallback failureMoves))
        (#[], #[], presummaries (cxOf s) (coreOf s) (memoOf s))).2.1,
       ((cxOf s).experiments.foldl (walkStep (envOf s fallback failureMoves))
        (#[], #[], presummaries (cxOf s) (coreOf s) (memoOf s))).2.2) := rfl
  rw [hw]
  dsimp only
  rw [cxOf, ctx_experiments, List.foldl_toArray]
  obtain ⟨hinv, hsz⟩ := hfold
  simp only [Array.size_empty, Nat.zero_add] at hsz
  refine ⟨?_, hinv.plan⟩
  apply List.ext_getElem
  · rw [Array.length_toList, hsz, List.length_map]
  · intro j h1 h2
    rw [Array.getElem_toList]
    obtain ⟨hjn, hrow⟩ := hinv.row j (by simpa using h1)
    rw [hrow, List.getElem_map]

end WalkEq

/-! ## Which experiments raise a fact (`raisersWith`) -/

section Raisers

open Fvtrace.Proofs.Forest

theorem str_stronger (a b : Status) : str (a.stronger b) = max (str a) (str b) := by
  unfold Status.stronger
  split <;> simp only [str] at * <;> omega

theorem str_foldl : ∀ (sts : List Status) (a : Status),
    str (sts.foldl Status.stronger a) = (sts.map str).foldl max (str a)
  | [], _ => rfl
  | b :: sts, a => by
    rw [List.foldl_cons, str_foldl sts, List.map_cons, List.foldl_cons, str_stronger]

theorem foldl_max_gt : ∀ (l : List Nat) (x b : Nat),
    l.foldl max x > b ↔ x > b ∨ ∃ y ∈ l, y > b
  | [], x, b => by simp
  | y :: l, x, b => by
    rw [List.foldl_cons, foldl_max_gt l]
    simp only [List.mem_cons]
    constructor
    · rintro (h | ⟨z, hz, hzb⟩)
      · rcases Nat.le_total x y with hxy | hxy
        · rw [Nat.max_eq_right hxy] at h; exact Or.inr ⟨y, Or.inl rfl, h⟩
        · rw [Nat.max_eq_left hxy] at h; exact Or.inl h
      · exact Or.inr ⟨z, Or.inr hz, hzb⟩
    · rintro (h | ⟨z, hz | hz, hzb⟩)
      · exact Or.inl (Nat.lt_of_lt_of_le h (Nat.le_max_left _ _))
      · subst hz; exact Or.inl (Nat.lt_of_lt_of_le hzb (Nat.le_max_right _ _))
      · exact Or.inr ⟨z, hz, hzb⟩

variable (s : Scenario)

/-- A closure raises `f` ⇔ one of its success entries at `f` beats the base (the floor included). -/
theorem raised_any (L : List String) (f : String) :
    (s.raised L).any (·.1 == f) = (s.successPairs L).any fun x =>
      x.1 == f && max 2 (EStatus.ofStatus x.2).strength > (s.eff1 f).strength := by
  unfold Scenario.raised
  rw [merged_of]
  unfold mergedOf
  rw [Bool.eq_iff_iff, List.any_eq_true, List.any_eq_true]
  have htop : ∀ k, str (topOf (s.successPairs L) k) > (s.eff1 k).strength ↔
      2 > (s.eff1 k).strength ∨
        ∃ x ∈ s.successPairs L, x.1 = k ∧ str x.2 > (s.eff1 k).strength := by
    intro k
    unfold topOf
    rw [str_foldl, foldl_max_gt]
    simp only [List.map_map, List.mem_map, List.mem_filter, beq_iff_eq, Function.comp_apply]
    constructor
    · rintro (h | ⟨y, ⟨x, ⟨hx, hk⟩, rfl⟩, hy⟩)
      · exact Or.inl h
      · exact Or.inr ⟨x, hx, hk, hy⟩
    · rintro (h | ⟨x, hx, hk, hy⟩)
      · exact Or.inl h
      · exact Or.inr ⟨_, ⟨x, ⟨hx, hk⟩, rfl⟩, hy⟩
  constructor
  · rintro ⟨y, hy, hyf⟩
    obtain ⟨hym, hyr⟩ := List.mem_filter.mp hy
    obtain ⟨k, hk, rfl⟩ := List.mem_map.mp hym
    simp only [beq_iff_eq] at hyf
    subst hyf
    simp only [decide_eq_true_eq] at hyr
    obtain ⟨x0, hx0, hx0k⟩ := List.mem_map.mp (List.mem_eraseDups.mp hk)
    rcases (htop _).mp hyr with h2 | ⟨x, hx, hxk, hxs⟩
    · refine ⟨x0, hx0, ?_⟩
      simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq]
      exact ⟨hx0k, Nat.lt_of_lt_of_le h2 (Nat.le_max_left _ _)⟩
    · refine ⟨x, hx, ?_⟩
      simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq]
      exact ⟨hxk, Nat.lt_of_lt_of_le hxs (Nat.le_max_right _ _)⟩
  · rintro ⟨x, hx, hxf⟩
    simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at hxf
    obtain ⟨hxk, hxs⟩ := hxf
    refine ⟨(x.1, topOf (s.successPairs L) x.1), List.mem_filter.mpr ⟨List.mem_map.mpr ⟨x.1,
      List.mem_eraseDups.mpr (List.mem_map.mpr ⟨x, hx, rfl⟩), rfl⟩, ?_⟩, by simp [hxk]⟩
    simp only [decide_eq_true_eq]
    rw [hxk]
    apply (htop f).mpr
    by_cases h2 : 2 > (s.eff1 f).strength
    · exact Or.inl h2
    · refine Or.inr ⟨x, hx, hxk, ?_⟩
      simp only [str]
      omega

local notation "fo" => Forest.build (cxOf s)

/-- A forest experiment's closure's entries = its path's own successes. -/
theorem path_any {j : Nat} (hg : (fo).good[j]? = some true) (P : String × Status → Bool) :
    (s.successPairs (s.closure [(s.trace.experiments[j]'(good_lt s hg)).id])).any P =
      true ↔ ∃ p, Reaches (fo).parent j p ∧ ∃ hp : p < s.trace.experiments.length,
        s.trace.experiments[p].success.any P = true := by
  have hinv := (build_inv s).1
  have hnd := good_nodup s hg
  rw [closure_good s hg]
  have hpath : ∀ p ∈ pathUp (fo).parent (j + 1) j [], p < s.trace.experiments.length := by
    intro p hp
    have := (pathUp_increasing (fo).parent hinv.dec (j + 1) j (by omega)).2 p hp
    have := good_lt s hg
    omega
  unfold Scenario.successPairs
  rw [List.any_eq_true]
  constructor
  · rintro ⟨x, hx, hpx⟩
    obtain ⟨id, hid, hxid⟩ := List.mem_flatMap.mp hx
    obtain ⟨p, hp, hpid⟩ := List.mem_filterMap.mp hid
    have hpn := hpath p hp
    rw [List.getElem?_eq_getElem hpn, Option.map_some, Option.some.injEq] at hpid
    subst hpid
    rw [experiment?_self s hnd hpn, Option.map_some, Option.getD_some] at hxid
    refine ⟨p, ?_, hpn, List.any_eq_true.mpr ⟨x, hxid, hpx⟩⟩
    rw [mem_pathUp _ hinv.dec _ _ _ (by omega), List.mem_nil_iff, or_false] at hp
    exact hp
  · rintro ⟨p, hrp, hpn, hpa⟩
    obtain ⟨x, hx, hpx⟩ := List.any_eq_true.mp hpa
    refine ⟨x, List.mem_flatMap.mpr ⟨s.trace.experiments[p].id, List.mem_filterMap.mpr
      ⟨p, ?_, by rw [List.getElem?_eq_getElem hpn]; rfl⟩, ?_⟩, hpx⟩
    · rw [mem_pathUp _ hinv.dec _ _ _ (by omega), List.mem_nil_iff, or_false]
      exact hrp
    · rw [experiment?_self s hnd hpn, Option.map_some, Option.getD_some]
      exact hx

/-- What `pathRaises` holds after a prefix: one entry per position, each forest one = some
experiment on its path raises `f` on its own. -/
theorem pathRaises_fold (f : String) : ∀ (l : List Experiment) (acc : Array Bool),
    (∀ j e, l[j]? = some e → s.trace.experiments[acc.size + j]? = some e) →
    (∀ k (hk : k < acc.size), (fo).good[k]? = some true →
      (acc[k] = true ↔ ∃ p, Reaches (fo).parent k p ∧ ∃ hp : p < s.trace.experiments.length,
        raisesOwn (coreOf s) f s.trace.experiments[p] = true)) →
    (l.foldl (pathRaisesStep (coreOf s) (fo) f) acc).size = acc.size + l.length ∧
      ∀ k (hk : k < (l.foldl (pathRaisesStep (coreOf s) (fo) f) acc).size),
        (fo).good[k]? = some true →
        ((l.foldl (pathRaisesStep (coreOf s) (fo) f) acc)[k] = true ↔
          ∃ p, Reaches (fo).parent k p ∧ ∃ hp : p < s.trace.experiments.length,
            raisesOwn (coreOf s) f s.trace.experiments[p] = true)
  | [], acc, _, h => ⟨by simp, h⟩
  | e :: l, acc, hl, hacc => by
    have hinv := (build_inv s).1
    have he : s.trace.experiments[acc.size]? = some e := by simpa using hl 0 e rfl
    have hin : acc.size < s.trace.experiments.length := by
      rcases Nat.lt_or_ge acc.size s.trace.experiments.length with h | h
      · exact h
      · rw [List.getElem?_eq_none h] at he; cases he
    have hei : s.trace.experiments[acc.size] = e := by
      rw [List.getElem?_eq_getElem hin] at he; exact Option.some.inj he
    rw [List.foldl_cons]
    have hstep : ∀ k (hk : k < (pathRaisesStep (coreOf s) (fo) f acc e).size),
        (fo).good[k]? = some true →
        ((pathRaisesStep (coreOf s) (fo) f acc e)[k] = true ↔
          ∃ p, Reaches (fo).parent k p ∧ ∃ hp : p < s.trace.experiments.length,
            raisesOwn (coreOf s) f s.trace.experiments[p] = true) := by
      intro k hk hg
      unfold pathRaisesStep at hk ⊢
      rw [Array.size_push] at hk
      by_cases hka : k < acc.size
      · rw [Array.getElem_push_lt hka]
        exact hacc k hka hg
      · have hk' : k = acc.size := by omega
        subst hk'
        rw [Array.getElem_push_eq, Bool.or_eq_true]
        split
        · rename_i p hp
          have hpk := hinv.dec _ p hp
          obtain ⟨hgp, _, _⟩ := hinv.parent _ p hp
          simp only [reaches_link hp]
          rw [show acc[p]?.getD false = acc[p] by
              rw [Array.getElem?_eq_getElem (by omega)]; rfl,
            hacc p (by omega) hgp]
          constructor
          · rintro (h | ⟨q, hq, hqn, hqr⟩)
            · exact ⟨acc.size, Or.inl rfl, hin, by rw [hei]; exact h⟩
            · exact ⟨q, Or.inr hq, hqn, hqr⟩
          · rintro ⟨q, rfl | hq, hqn, hqr⟩
            · left; rw [← hei]; exact hqr
            · exact Or.inr ⟨q, hq, hqn, hqr⟩
        · rename_i hnp
          simp only [reaches_root (fun r hr => hnp r hr), Bool.false_eq_true, or_false]
          constructor
          · intro h; exact ⟨acc.size, rfl, hin, by rw [hei]; exact h⟩
          · rintro ⟨q, rfl, _, hqr⟩; rw [← hei]; exact hqr
    have hsz : (pathRaisesStep (coreOf s) (fo) f acc e).size = acc.size + 1 := by
      unfold pathRaisesStep; simp
    obtain ⟨h1, h2⟩ := pathRaises_fold f l _ (by
      intro j e' hj
      rw [hsz, Nat.add_assoc, Nat.add_comm 1 j]
      exact hl (j + 1) e' (by simpa using hj)) hstep
    refine ⟨by rw [h1, hsz]; simp; omega, h2⟩

/-- `pathRaises`: a forest position's entry = some experiment on its path raises `f` on its own. -/
theorem pathRaises_spec (f : String) {k : Nat} (hg : (fo).good[k]? = some true) :
    ((pathRaises (cxOf s) (coreOf s) (fo) f)[k]?.getD false) = true ↔
      ∃ p, Reaches (fo).parent k p ∧ ∃ hp : p < s.trace.experiments.length,
        raisesOwn (coreOf s) f s.trace.experiments[p] = true := by
  unfold pathRaises
  rw [cxOf, ctx_experiments, List.foldl_toArray]
  obtain ⟨h1, h2⟩ := pathRaises_fold s f s.trace.experiments #[] (fun j e h => by simpa using h)
    (fun k hk => by simp at hk)
  have hkn := good_lt s hg
  simp only [Array.size_empty, Nat.zero_add] at h1
  rw [Array.getElem?_eq_getElem (by rw [h1]; exact hkn), Option.getD_some]
  exact h2 k _ hg

/-- The forest raisers = the closure scan, for any order of experiments. -/
theorem raisersWith_eq (order : List Experiment) (f : String) :
    raisersWith (cxOf s) (coreOf s) (fo) ((cxOf s).closureWith (fo)) order f =
      raisersOf order s.closure s.raised f := by
  unfold raisersWith raisersOf
  dsimp only
  congr 1
  apply List.filter_congr
  intro e _
  have hgen : (raisedBy (cxOf s) (coreOf s) ((cxOf s).closureWith (fo) [e.id])).any (·.1 == f) =
      (s.raised (s.closure [e.id])).any (·.1 == f) := by
    rw [closure_eq, raised_eq]
  split
  · rename_i j hj
    split
    · rename_i hgb
      have hg : (fo).good[j]? = some true := by
        cases hh : (fo).good[j]? with
        | none => rw [hh] at hgb; cases hgb
        | some b => rw [hh] at hgb; simp at hgb; rw [hgb]
      obtain ⟨hjn, hjid⟩ := Fvtrace.Proofs.Closure.firstPos_some s hj
      rw [Bool.eq_iff_iff, pathRaises_spec s f hg, ← hjid, raised_any,
        path_any s hg]
      constructor
      · rintro ⟨p, hp, hpn, hpr⟩
        refine ⟨p, hp, hpn, ?_⟩
        unfold raisesOwn at hpr
        rw [eff1_eq] at hpr
        exact hpr
      · rintro ⟨p, hp, hpn, hpr⟩
        refine ⟨p, hp, hpn, ?_⟩
        unfold raisesOwn
        rw [eff1_eq]
        exact hpr
    · exact hgen
  · exact hgen

end Raisers

end Fvtrace.Proofs.Walk
