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

end Fvtrace.Proofs.Engine
