import Fvtrace.Spec.Engine

/-! Proofs of the engine claims in `Fvtrace.Spec.Engine`. -/

-- Proof scripts keep generous simp sets: an unused lemma costs nothing in soundness.
set_option linter.unusedSimpArgs false

namespace Fvtrace.Proofs.Engine
open Fvtrace Fvtrace.Spec

theorem canVerdictExact : Spec.CanVerdictExact := by
  intro st
  cases st <;> simp [State.verdict]

theorem movesExact : Spec.MovesExact := by
  intro s after
  constructor
  · intro m hm
    unfold Scenario.moves at hm
    obtain ⟨c, hc, h⟩ := List.mem_filterMap.mp hm
    by_cases hne : s.final c = after.final c
    · simp [hne] at h
    · simp only [bne_iff_ne, ne_eq, hne, not_false_eq_true, ite_true, Option.some.injEq] at h
      subst h
      exact ⟨c, hc, rfl, rfl, rfl, hne⟩
  · intro c hc hne
    refine ⟨{ claim := c.id, before := s.final c, after := after.final c }, ?_, rfl⟩
    unfold Scenario.moves
    exact List.mem_filterMap.mpr ⟨c, hc, by simp [hne]⟩

theorem countsComplete : Spec.CountsComplete := by
  intro s claims
  induction claims with
  | nil => simp
  | cons c cs ih =>
    simp only [List.map_cons, List.map_nil, List.sum_cons, List.sum_nil, List.filter_cons,
      List.length_cons] at ih ⊢
    cases h : s.final c <;> simp [h] at ih ⊢ <;> omega

theorem breakdownPartitions : Spec.BreakdownPartitions := by
  intro s c n hn
  simp only [Scenario.verifiedNeeds, Scenario.premises, Scenario.gaps, Scenario.blockers,
    List.mem_filter, hn, true_and]
  cases h : s.eff n <;> simp [h, EStatus.verified, EStatus.strength]

/-- `find?` by id returns an element of the list carrying that id. -/
theorem fact?_mem {t : Trace} {id : String} {f : Fact} (h : t.fact? id = some f) :
    f ∈ t.facts ∧ f.id = id := by
  unfold Trace.fact? at h
  exact ⟨List.mem_of_find?_eq_some h, by simpa using List.find?_some h⟩

theorem eff_verified {s : Scenario} {n : String} (h : (s.eff n).verified = true) :
    (s.eff1 n).verified = true := by
  unfold Scenario.eff at h
  split at h
  · exact h
  · simp [EStatus.verified, EStatus.strength] at h

theorem ofStatus_verified {st : Status} : (EStatus.ofStatus st).verified = st.verified := by
  cases st <;> rfl

/-- With no what-if, a verified effective status is a recorded verified status + a current
receipt. -/
theorem eff1_recorded {t : Trace} {current : String → Bool} {n : String}
    (h : ((({ trace := t, current } : Scenario)).eff1 n).verified = true) :
    ∃ f, t.fact? n = some f ∧ f.status.verified = true ∧ current n = true := by
  unfold Scenario.eff1 at h
  simp only [List.lookup] at h
  cases hf : t.fact? n with
  | none => simp [hf, EStatus.verified, EStatus.strength] at h
  | some f =>
    simp only [hf] at h
    unfold Scenario.eff0 at h
    have hid := (fact?_mem hf).2
    by_cases hv : f.status.verified = true
    · by_cases hc : current f.id = true
      · exact ⟨f, rfl, hv, hid ▸ hc⟩
      · simp [hv, hc, EStatus.verified, EStatus.strength] at h
    · simp [hv, ofStatus_verified] at h

theorem intrinsic_can {s : Scenario} {c : Claim} (h : s.intrinsic c = .can) :
    ∀ n ∈ c.needsAll, (s.eff n).verified = true := by
  unfold Scenario.intrinsic at h
  simp only at h
  split at h
  · cases h
  · split at h
    · rename_i hall
      intro n hn
      exact List.all_eq_true.mp hall (s.eff n) (List.mem_map_of_mem hn)
    · split at h <;> cases h

theorem final_can {s : Scenario} {c : Claim} (h : s.final c = .can) : s.intrinsic c = .can := by
  unfold Scenario.final at h
  split at h
  · exact h
  · cases h

theorem recordedCanIsVerified : Spec.RecordedCanIsVerified := by
  intro t current c hcan n hn
  exact eff1_recorded (eff_verified (intrinsic_can (final_can hcan) n hn))

theorem lookup_mem {o : Overrides} {k : String} {st : Status} (h : o.lookup k = some st) :
    (k, st) ∈ o := by
  induction o with
  | nil => simp [List.lookup] at h
  | cons p ps ih =>
    obtain ⟨k', st'⟩ := p
    by_cases hk : k = k'
    · subst hk
      simp [List.lookup] at h
      simp [h]
    · have hne : (k == k') = false := by simp [hk]
      simp only [List.lookup, hne] at h
      exact List.mem_cons_of_mem _ (ih h)

/-- A human-ruled or empirical route allows no verified status. -/
theorem ruling_not_verified {r : Route} {st : Status} (hr : r = .humanRuling ∨ r = .empirical)
    (ha : r.allows st = true) : st.verified = false := by
  rcases hr with rfl | rfl <;> cases st <;> simp_all [Route.allows, Route.ceiling, Status.verified]

theorem rulingCeiling : Spec.RulingCeiling := by
  intro s c f hwf hvalid hf hroute hcan
  have hent : c.entailment ∈ c.needsAll := by simp [Claim.needsAll]
  have h1 := eff_verified (intrinsic_can (final_can hcan) c.entailment hent)
  have ⟨hmem, hid⟩ := fact?_mem hf
  unfold Scenario.eff1 at h1
  cases hl : s.overrides.lookup c.entailment with
  | some st =>
    simp only [hl] at h1
    have hpair := lookup_mem hl
    unfold Overrides.valid at hvalid
    simp only [Bool.and_eq_true, List.all_eq_true] at hvalid
    have := hvalid.2 _ hpair
    simp only [hf, Option.any_some] at this
    have := ruling_not_verified hroute this
    simp [ofStatus_verified, this] at h1
  | none =>
    simp only [hl, hf] at h1
    unfold Scenario.eff0 at h1
    have hallow : f.route.allows f.status = true := hwf.2.2.2.2.2.1.1 f hmem
    have := ruling_not_verified hroute hallow
    simp [this, ofStatus_verified] at h1

theorem exclusionDerives : Spec.ExclusionDerives := by
  intro s x b hx hxv hb ha hnb
  unfold Scenario.eff
  have hne : s.derivations b ≠ [] := by
    unfold Scenario.derivations
    intro hnil
    have := List.filterMap_eq_nil_iff.mp hnil x hx
    by_cases h1 : x.between.1 = b
    · -- both sides would be `b`: a verified side cannot also be unasserted
      rw [h1] at ha
      simp [EStatus.verified, EStatus.asserted] at ha hnb
      omega
    · simp [hxv, hnb, h1, hb, ha] at this
  simp [List.isEmpty_iff, hne]

theorem bothSidesCannot : Spec.BothSidesCannot := by
  intro s c x hx hxa h1 h2
  unfold Scenario.final
  split
  · unfold Scenario.intrinsic
    have hinc : s.incompatible c ≠ [] := by
      unfold Scenario.incompatible
      intro hnil
      rw [List.map_eq_nil_iff] at hnil
      have hmem : x ∈ s.trace.exclusions.filter (fun x =>
          (s.exclusionEff x).asserted && c.needsAll.contains x.between.1 &&
            c.needsAll.contains x.between.2) :=
        List.mem_filter.mpr ⟨hx, by simp [hxa, h1, h2]⟩
      rw [hnil] at hmem
      simp at hmem
    simp [List.isEmpty_iff, hinc]
  · rfl

theorem mem_joinParts {q : String} {qs : List String} (h : q ∈ qs) : q ∈ Scenario.joinParts qs := by
  induction qs with
  | nil => cases h
  | cons x xs ih =>
    cases xs with
    | nil => simp [Scenario.joinParts] at h ⊢; exact h
    | cons y ys =>
      simp only [Scenario.joinParts, List.mem_cons] at h ⊢
      rcases h with h | h
      · exact Or.inl h
      · exact Or.inr (Or.inr (ih (by simpa using h)))

theorem getLast?_cons_pair (a : String) (l : List String) (x y : String) :
    (a :: (l ++ [x, y])).getLast? = some y := by
  have h : a :: (l ++ [x, y]) = (a :: l ++ [x]) ++ [y] := by simp
  rw [h, List.getLast?_concat]

theorem sentenceVerbatim : Spec.SentenceVerbatim := by
  intro s c
  refine ⟨rfl, ?_, ?_⟩
  · unfold Scenario.sentenceParts
    split
    · exact getLast?_cons_pair _ _ _ _
    · rfl
  · intro hcond p hp
    unfold Scenario.sentenceParts
    simp only [hcond, beq_self_eq_true, ite_true, List.mem_append, List.mem_cons]
    exact Or.inl (Or.inr (mem_joinParts (List.mem_map_of_mem hp)))

theorem reviewStateExact : Spec.ReviewStateExact := by
  intro t d
  unfold Receipt.reviewStateOf
  cases h : t.review with
  | none => simp
  | some r => by_cases hd : r.digest = d <;> simp [hd]

section Isolation

variable {t : Trace} {current : String → Bool} {o₁ o₂ : Overrides} {T : String}

/-- Scenarios that agree on the overrides of every fact on subject `T`. -/
abbrev s₁ (t : Trace) (current : String → Bool) (o₁ : Overrides) : Scenario :=
  { trace := t, current, overrides := o₁ }

theorem factSubject?_of_mem {id : String} (hr : id ∈ t.factIds) :
    ∃ sub, t.factSubject? id = some sub := by
  unfold Trace.factIds at hr
  obtain ⟨f, hf, rfl⟩ := List.mem_map.mp hr
  unfold Trace.factSubject? Trace.fact?
  cases h : t.facts.find? (·.id == f.id) with
  | none => simp [List.find?_eq_none] at h; exact absurd rfl (h f hf)
  | some g => exact ⟨g.subject, by simp⟩

theorem eff1_agree (hagree : ∀ k, t.factSubject? k = some T → o₁.lookup k = o₂.lookup k)
    {k : String} (hk : t.factSubject? k = some T) :
    (s₁ t current o₁).eff1 k = (s₁ t current o₂).eff1 k := by
  unfold Scenario.eff1
  rw [hagree k hk]
  rfl

/-- `filterMap` with functions agreeing on the list's members. -/
theorem filterMap_congr' {α β : Type} {f g : α → Option β} :
    ∀ {l : List α}, (∀ x ∈ l, f x = g x) → l.filterMap f = l.filterMap g
  | [], _ => rfl
  | x :: xs, h => by
    simp only [List.filterMap_cons, h x (by simp),
      filterMap_congr' (l := xs) (fun y hy => h y (by simp [hy]))]

/-- An exclusion endpoint on `T` puts the exclusion + its other endpoint on `T`. -/
theorem other_on (hwf : WellFormed t) {x : Exclusion} (hx : x ∈ t.exclusions)
    {k : String} (hk : t.factSubject? k = some T) (hend : x.between.1 = k ∨ x.between.2 = k) :
    t.factSubject? x.between.1 = some T ∧ t.factSubject? x.between.2 = some T := by
  have ⟨ha, hb⟩ := hwf.2.2.1.2.2.1 x hx
  have ⟨_, ra, rb⟩ := hwf.2.1.2.2.2.1 x hx
  have hT : T = x.subject := by
    rcases hend with rfl | rfl
    · exact ha T hk
    · exact hb T hk
  obtain ⟨sa, hsa⟩ := factSubject?_of_mem ra
  obtain ⟨sb, hsb⟩ := factSubject?_of_mem rb
  exact ⟨by rw [hsa, ha sa hsa, hT], by rw [hsb, hb sb hsb, hT]⟩

theorem derivations_agree (hwf : WellFormed t)
    (hagree : ∀ k, t.factSubject? k = some T → o₁.lookup k = o₂.lookup k)
    {k : String} (hk : t.factSubject? k = some T) :
    (s₁ t current o₁).derivations k = (s₁ t current o₂).derivations k := by
  unfold Scenario.derivations
  apply filterMap_congr'
  intro x hx
  simp only [Scenario.exclusionEff, eff1_agree hagree hk]
  by_cases h1 : x.between.1 = k
  · have ⟨_, hb⟩ := other_on hwf hx hk (Or.inl h1)
    simp [h1, Scenario.eff0, eff1_agree hagree hb, eff1_agree hagree hk]
  · by_cases h2 : x.between.2 = k
    · have ⟨ha, _⟩ := other_on hwf hx hk (Or.inr h2)
      simp [h1, h2, Scenario.eff0, eff1_agree hagree ha, eff1_agree hagree hk]
    · simp [h1, h2]

theorem eff_agree (hwf : WellFormed t)
    (hagree : ∀ k, t.factSubject? k = some T → o₁.lookup k = o₂.lookup k)
    {k : String} (hk : t.factSubject? k = some T) :
    (s₁ t current o₁).eff k = (s₁ t current o₂).eff k := by
  unfold Scenario.eff
  rw [derivations_agree hwf hagree hk, eff1_agree hagree hk]

theorem valid_agree (hwf : WellFormed t)
    (hagree : ∀ k, t.factSubject? k = some T → o₁.lookup k = o₂.lookup k) :
    (s₁ t current o₁).valid T = (s₁ t current o₂).valid T := by
  unfold Scenario.valid Scenario.conflicts
  congr 2
  apply List.filter_congr
  intro x hx
  by_cases hs : x.subject = T
  · have ⟨ha, hb⟩ := hwf.2.2.1.2.2.1 x hx
    have ⟨_, ra, rb⟩ := hwf.2.1.2.2.2.1 x hx
    obtain ⟨sa, hsa⟩ := factSubject?_of_mem ra
    obtain ⟨sb, hsb⟩ := factSubject?_of_mem rb
    have hsa' : t.factSubject? x.between.1 = some T := by rw [hsa, ha sa hsa, hs]
    have hsb' : t.factSubject? x.between.2 = some T := by rw [hsb, hb sb hsb, hs]
    have hact : (s₁ t current o₁).active x = (s₁ t current o₂).active x := by
      unfold Scenario.active Scenario.exclusionEff
      rw [eff1_agree hagree hsa', eff1_agree hagree hsb']
      rfl
    rw [hact]
  · have hne : (x.subject == T) = false := by simp [hs]
    simp [hne]

end Isolation

theorem subjectIsolation : Spec.SubjectIsolation := by
  intro t current o₁ o₂ c hwf hc hagree
  have hneeds : ∀ n ∈ c.needsAll, t.factSubject? n = some c.subject := by
    intro n hn
    have ⟨_, _, hneedsR, hentR, _⟩ := hwf.2.1.1 c hc
    have hres : n ∈ t.factIds := by
      simp only [Claim.needsAll, List.mem_append, List.mem_singleton] at hn
      rcases hn with hn | rfl
      · exact hneedsR n hn
      · exact hentR
    obtain ⟨sub, hsub⟩ := factSubject?_of_mem hres
    rw [hsub, hwf.2.2.1.1 c hc n hn sub hsub]
  have heff : c.needsAll.map (s₁ t current o₁).eff = c.needsAll.map (s₁ t current o₂).eff :=
    List.map_congr_left fun n hn => eff_agree hwf hagree (hneeds n hn)
  unfold Scenario.final Scenario.intrinsic
  rw [valid_agree hwf hagree, heff]
  rfl

end Fvtrace.Proofs.Engine
