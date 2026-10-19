# Kernel contract (U2) — tier `kernel`

Scope = the judgment-bearing core every surface (CLI, server, GUI, export) displays: trace decoding + well-formedness, effective statuses, claim states, ranking, experiments, plans, review state, sentences, the evaluation envelope. Proved in Lean 4.35 against `Fvtrace/Spec*` (human-read claims) where marked **proved**; the rest **tested** (red-first, or mutation credit). Gate = `lake build` (kernel check) + `fvtrace-trust` (axioms ⊆ `propext` · `Classical.choice` · `Quot.sound`; no escape hatch in a proof closure) + independent-kernel replay. `.agent/spec.md` Decisions bind; ids here (`D-*`, `WF-*`, `S-*`, `G*`) are cited by proofs + tests.

## Decode (D-*; tested + round-trip property)

- Input = UTF-8 JSON text. D-json: RFC 8259 syntax; duplicate object keys rejected; numbers = integers alone; nesting depth ≤ 64; size ≤ 16 MiB.
- D-shape: every object closed (unknown field ⇒ error); optional fields absent (never `null`); required fields listed below; enums exact lowercase strings. Defaults when absent: `experiments`, `exclusions`, `waivers`, `artifacts`, `trusts`, `requires` = `[]`; `failure` = `{}`; `latent` = `false`. Strings = Unicode scalar sequences: invalid UTF-8 and unpaired `\uD800`–`\uDFFF` escapes are rejected.
- D-id: ids match `^[A-Za-z][A-Za-z0-9_.-]{0,63}$`. D-text: text fields non-empty, contain no C0 control char except `\n`. D-date: `YYYY-MM-DD`. D-sha: 64 lowercase hex.
- Diagnostics = `{code, path (RFC 6901 pointer), message}`; decode errors stop the check (WF needs a decoded trace); every decode error found in one pass is reported. Exit codes (CLI): 0 = valid (warnings allowed), 1 = invalid trace, 2 = usage or I/O error.
- G-codec: `decode (encode t) = t` for every decoded trace; `encode` is canonical (D-canon).
- D-canon (review + statement digests): keys sorted by code point, no insignificant whitespace, strings escaped as ECMAScript `JSON.stringify` (`\"` `\\` `\b` `\f` `\n` `\r` `\t`, other C0 as `\u00xx` lowercase), non-ASCII raw UTF-8, integers in decimal.

## Model

- `Status` = `proved | checked | assumed | tested | open | violated`; `verified` = `{proved, checked}`; `asserted` = verified ∪ `{assumed}`.
- `Route` = `lean | runtime-checker | refinement | human-ruling | empirical`; `ceiling`: `lean` · `refinement` ↦ `proved`, `runtime-checker` ↦ `checked`, `human-ruling` · `empirical` ↦ `assumed`. `allowed r s` ⇔ `s ∈ {open, tested, violated, assumed}` ∨ `s = ceiling r`.
- `Kind` (fact) = `entailment | result | estimand | statistical | numerical | implementation | dataflow | provenance | interpretation | release | spec-review | instantiation`. `Level` (claim) = `estimand | descriptive | inferential | causal | release`. `Effort` = `hours < days < weeks < months`; `ExpKind` = `dry | wet`.
- Trace `{fvtrace: 1, analysis, subjects, questions, facts, claims, experiments?, exclusions?, waivers?, review?}` (absent arrays = empty):
  - analysis `{id, title, summary, source?}`; subject `{id, title, kind: existing | prospective, createdBy?}`; question `{id, title, text}`.
  - fact `{id, subject, kind, text, status, route, evidence?, trusts?, instantiates?}`; evidence `{summary, artifacts?: [{path, sha256?, role?: text}], verifier?, statement?, statementDigest?}`.
  - claim `{id, question, subject, level, text, needs: [F], entailment: F, latent?: bool, variantOf?}`; `needsAll c` = `needs ++ [entailment]`.
  - experiment `{id, subject, kind, effort, title, method, resources, success: {F: Status}, failure?: {F: Status}, requires?: [E], caveat}` (`resources` = prose; `requires` = experiments that must run first).
  - exclusion `{id, subject, between: [F, F], text, status, route, evidence?}` (a relation is itself a fact-like assertion: "these two cannot both hold").
  - waiver `{rule, claim, reason}`; review `{by, at, digest, note?}`.
- Scenario = trace + `current : F ∪ X → Bool` (receipt binding, computed by the shell; consulted for recorded verified statuses alone) + overrides `ω : F ⇀ Status`.

## Well-formedness (WF-*; `check` = list of violations; **proved**: `check t = [] ↔ WF t`, each listed violation ⇒ its rule fails)

- WF-ids: ids unique across all collections. WF-refs: every reference resolves (question, subject, needs, entailment, variantOf, outcome keys, requires, exclusion pair + subject, createdBy, waiver claim, instantiates).
- WF-subject: claim needs + entailment, experiment outcome keys, exclusion pair all on the owner's subject; `instantiates` names a fact on another subject.
- WF-entail: entailment fact has kind `entailment`, ∉ the claim's needs, used by exactly one claim; no `entailment` fact in any `needs`.
- WF-needs: needs non-empty + duplicate-free.
- WF-route: every recorded status, every outcome status + every exclusion status `allowed` by its route.
- WF-outcome: success non-empty, values ∈ asserted; failure values = `violated`; `requires` acyclic + on the experiment's subject.
- WF-receipt: recorded verified (fact or exclusion) ⇒ evidence with ≥1 artifact, every artifact with sha256, `verifier` + `statement` non-empty, `statementDigest` present.
- WF-path: artifact path non-empty, relative, `/`-separated, no `.` / `..` / empty segment, no backslash, no NUL.
- WF-prospective: `prospective` ⇔ `createdBy`; createdBy names an experiment on that subject; ≥1 `existing` subject; every fact on a prospective subject records `open` (its data does not exist yet).
- WF-variant: variantOf targets a claim on an existing subject; the variant's subject is prospective.
- WF-exclusion: the pair's facts differ; no duplicate unordered pair per subject.
- WF-consistent: no exclusion with recorded asserted status has both sides recorded asserted (a contradictory trace is an error, not a scenario).
- WF-waiver: rule ∈ lint ids; claim resolves; no duplicate (rule, claim).
- WF-kind: `instantiation` ⇔ `instantiates` present.

## Lints (warnings; a matching waiver suppresses + is listed with its reason)

- L-result: level ∈ {descriptive, inferential, causal} ∧ no `result` need. L-statistical: inferential | causal ∧ no `statistical` need. L-interpretation: causal ∧ no `interpretation` need. L-release: release ∧ no `release` need. L-estimand: estimand ∧ no `estimand` need.

## Receipts (shell computes `current`; tested against real files)

- statementDigest f = SHA-256 of D-canon `{id, subject, kind, text, route}` of f; for an entailment fact add its claim `{id, subject, level, text, needs: [{id, text}]}`; for an instantiation fact add the source fact's `{id, subject, kind, text}`. For an exclusion: `{id, subject, text, route, between: [{id, subject, kind, text} of each endpoint]}` (rewording an endpoint stales the relation's receipt).
- current x ⇔ every artifact exists under the project root + its sha256 matches ∧ statementDigest = the recomputed digest. Reasons (display): `changed`, `missing`, `statement-changed`. Path resolution never leaves the project root (symlinks resolved, then prefix-checked).
- Receipts are accepted as recorded (not replayed): the trusted base names receipt issuers.

## Effective status (S-*; total; **proved** lemmas)

- S-bind: `eff0 x` = `stale` if recorded verified ∧ ¬current x, else recorded. `EStatus` = `Status` + `stale`; strength `violated` 0 < `open` = `tested` = `stale` 1 < `assumed` 2 < `checked` = `proved` 3.
- S-override: `eff1 f` = `ω f` if defined, else `eff0 f` (a direct what-if may lower a status). ω valid ⇔ keys resolve to facts on existing or prospective subjects ∧ `allowed (route f) (ω f)`; invalid ω rejected with diagnostics, never clamped or dropped.
- S-exclude: exclusion x with `verified (eff0 x)`: `verified (eff1 a)` ∧ ¬`asserted (eff1 b)` ⇒ `eff b = violated`, derivation witnesses = every such (x, a) (symmetric). Otherwise `eff f = eff1 f`. One pass: a derived violation asserts nothing, so derives nothing.
- S-conflict: x active ⇔ `asserted (eff0 x)` ∧ `asserted (eff1 a)` ∧ `asserted (eff1 b)`. `valid s` ⇔ no active exclusion on subject s.

## Claim state (S-state)

- intrinsic c (on `eff`): `cannot` ⇔ ∃ n ∈ needsAll, `eff n = violated` ∨ ∃ asserted exclusion with both sides ∈ needsAll; `can` ⇔ ¬cannot ∧ ∀ n, verified (eff n); `conditional` ⇔ ¬cannot ∧ ¬can ∧ ∀ n, asserted (eff n); `open` otherwise.
- final c = `cannot` (reason `conflict`) if ¬valid (subject c), else intrinsic c.
- Breakdown (**proved** G2: an exact partition of needsAll, order kept): verified · premises (assumed) · gaps (open | tested | stale) · blockers (violated, with recorded or derived witnesses); plus `incompatible` = asserted exclusions with both endpoints ∈ needsAll (with relation status) and `conflicts` = active exclusions on the subject. **Proved**: intrinsic cannot ⇔ blockers ≠ [] ∨ incompatible ≠ []; final cannot with reason conflict ⇔ conflicts ≠ [].
- mode = `recorded` ⇔ normalized ω = [] (keys sorted, duplicates rejected); else `what-if`. `supposed c` = needsAll with ω defined. `hypothetical c` ⇔ subject prospective ∨ ∃ n ∈ needsAll, eff n ≠ eff n under ω = ∅ ∨ valid (subject c) differs from its ω = ∅ value. `provisional` ⇔ review state ≠ `reviewed`.
- Counts = final states over claims on existing subjects (zero-filled keys can · conditional · open · cannot); per prospective subject apart.

## Sentences (engine-owned; **proved** G6)

- Claim + premise texts emitted verbatim (no case or punctuation change). can: `text`; conditional: `Assuming “p₁”; “p₂”: text` (premises in needsAll order); open / cannot: `text` with the verdict word beside it.
- Label = verdict word + qualifier list: `what-if` (hypothetical), `draft` | `stale review` (provisional), `if <creator title> runs` (prospective), `conflicting what-if` (reason conflict).
- G6: a conditional sentence contains every premise text + the claim text verbatim; the emitted label's verdict word is `Can claim` only for final = can.

## Ranking + blockers

- closable f ⇔ `eff f ∈ {open, tested, stale, assumed}` ∧ `eff f ≠ ceiling (route f)`. gates f = claims with f ∈ needsAll. unlocks f = gates f with final ∈ {open, cannot} whose final under `ω[f ↦ ceiling (route f)]` ∈ {can, conditional}.
- work = every closable fact gating ≥1 claim, ordered |unlocks| desc, |gates| desc, id asc; **proved**: complete, duplicate-free, sorted, each entry's unlocks = the defining set. blockers = facts with `eff = violated` + the claims they block.

## Experiments

- closure E = the least set ⊇ E holding, for each member, its `requires` + the creator of its subject when prospective (a fixed point: a creator's own `requires` are included). merged P = per fact, the strongest asserted value any success in P sets. Applying a success never weakens: ω ⊕ P = per fact the strength join (max) of `eff1` and merged P; a failure sets its facts `violated`.
- preview e (success) = scenario ω ⊕ merged (closure {e}); preview e (failure) = ω ⊕ failure e. moves = claims whose final differs; lights = moves up into {can, conditional}; clears = cannot → open; breaks = failure moves into cannot. contingent ⇔ the success closure touches a `result` fact; applied ⇔ ω ⊇ merged (closure {e}). Order: lights desc, clears desc, effort asc, id asc. **Proved** G3: moves = exactly the replayed differences; counts match moves; outcomes touch only their subject.

## Plans (per claim with final ≠ can)

- Relevant R = experiments on the claim's subject whose success raises a needsAll fact above its `eff1` (strength up). Candidates = closure S for every S ⊆ R. coherent P ⇔ valid (subject) under ω ⊕ P.
- Result (tagged; first matching branch): `inconsistent` (ω already invalid on the subject) | `tooLarge` (|R| > 20: no plan claimed) | `noImprovement` (no coherent candidate beats the empty plan) | `planned P` (max rank of final under ω ⊕ P over coherent candidates; tie → min cost = effort counts months→hours lexicographic; tie → id list lexicographic). Every variant carries the coverage payload: remaining premises + gaps under the current scenario, uncovered needs (no member of R raises them; route hint), alternatives per need (experiment, status); `planned` adds experiments, final state, its premises + gaps under ω ⊕ P, contingent.
- **Proved** G4: P closed + coherent + its reported state = replay (G4a); ∀ closed coherent Q (any experiments): rank Q ≤ rank P, equal rank ⇒ Q not strictly cheaper; `noImprovement` ⇒ no closed coherent Q beats the current state (G4b). Pruning lemma: with join application, experiments outside R never raise the claim's rank, so Q's stand-in = closure (Q ∩ R) ⊆ Q, a candidate at least as high + no costlier.

## Review

- digest t = SHA-256 of D-canon of t without `review`. state = `draft` (absent) | `stale` (digest ≠) | `reviewed`. Review covers the recorded trace alone; what-ifs are never reviewed evidence.

## Evaluation envelope (`fvtrace.evaluation/1`; CLI `--json` projections + server + export share it)

- `{schema, mode: recorded | what-if, overrides (normalized, sorted), trace: {digest, review: {state, by?, at?}}, subjects: [{id, kind, valid, conflicts}], counts, questions, facts: [{…recorded, eff, current, reasons, derivedFrom, closable, supposed}], claims: [{id, question, subject, level, text, final, intrinsic, sentence, label, breakdown, hypothetical, provisional, plan}], work, blockers, experiments, lints, actions}`.
- actions = the one-click domain from the evaluated scenario: `suppose f` (closable f ↦ ceiling), `success e`, `failure e` (non-empty failure), `plan c` (planned results); each maps to the complete what-if it leads to (ω ⊕ the action), so a click replaces ω. Recorded (ω = []) = the export's finite domain: one envelope per action, never stacked; the server GUI stacks by clicking from a what-if.
- CLI projections: `claims --json` = envelope keys {schema, mode, overrides, trace, subjects, counts, claims}; `gaps --json` = {schema, mode, overrides, trace, work, blockers}; `experiments --json` = {schema, mode, overrides, trace, experiments}; `plan <c> --json` = {schema, mode, overrides, trace, claim c}. Parity = structural equality with the server envelope's same keys for one snapshot (trace bytes, bindings, ω).

## Outcome guarantees (**proved** unless noted)

- G1 recorded soundness: mode recorded (ω = []) ∧ final c = can ⇒ valid ∧ ∀ n ∈ needsAll: recorded verified n ∧ current n; WF ⇒ subject existing (G1b). (Its meaning: the receipts named for every need, incl. the claim's own entailment statement, are present + unchanged; receipt acceptance + the entailment's formal reading are the declared trust boundary.)
- G5 ruling ceiling: WF ∧ ω valid ∧ route (entailment c) ∈ {human-ruling, empirical} ⇒ final c ≠ can.
- G7 subject isolation: ω or an outcome touching only subject s leaves final + breakdown of every claim on another subject unchanged.
- G8 exclusion: verified current exclusion ∧ verified (eff1 a) ∧ ¬asserted (eff1 b) ⇒ eff b = violated; a claim needing both sides of an asserted exclusion ⇒ intrinsic cannot.
- G9 monotonicity: f in no exclusion, raising `eff1 f` in strength (staying non-violated), every other input fixed ⇒ no claim's final rank drops.
- G10 counts: Σ counts = #existing-subject claims; each claim counted once.
- G11 review: state = reviewed ⇔ review present ∧ review.digest = digest t.
- Tested: G-codec; receipts (`current`) against real files incl. symlink escape + missing + changed; CLI/server parity on one snapshot.

## Acceptance (from retired deferred rows)

- Exclusions: a what-if verifying both sides of an exclusion → that subject's claims cannot (`conflicting what-if`); fixture case shows it.
- Results: C2/C3/C5/C12 analogues need a `result` fact; no plan reaches can for them without one.
- New-data experiments: E4/E10/E11/E12 analogues light sibling claims only; existing claims keep their gaps.
- Plan rule: C6/C12 analogue plans = max state, then min cost; alternatives listed.
- Reduced motion (GUI unit): Playwright Chromium with reduce emulated shows zero transitions + animations in claim circuits.
- CLI parity (CLI unit): `fvtrace claims|gaps|experiments|plan --json` = the server envelope's projections for one snapshot.

## Regression witnesses (consultant-1 review; each becomes a production test)

- R1-P1 creator closure: a follow-up on a prospective subject plans with its creator. R2-C1: + the creator's own `requires` (fixed point).
- R1-P3 no coherent plan: an invalid ω yields `inconsistent`, never a fabricated plan.
- R1-P4 support merge: assumed + checked outcomes for one fact merge to checked, never a clash.
- R1-P5 stale what-if: overriding a stale fact verified marks the claim hypothetical + `what-if`; the review digest stays the recorded trace's.
- R1-P6 conflict scope: a conflict on subject P leaves every claim on subject S unchanged.
- R1-P7 verbatim text: `RNA is quantified.` stays `RNA`; premise periods kept.
- R2-P2b join: two experiments that each assert `assumed` on different checked exclusion sources never weaken them; the claim stays cannot.
- R2-E1 incompatible needs: open A, open B, asserted X(A, B), C needs A + B ⇒ cannot with `incompatible` = [X].
- R2-E2 coverage: `noImprovement` still lists alternatives per need + uncovered needs.
- R2-N1 exclusion receipt: rewording an endpoint fact stales the verified exclusion.
- R2-D1 Unicode: `"\ud800"` is rejected at decode.

## Trusted base (shipped by `fvtrace about`)

Lean kernel (replayed by independent kernels), Lean compiler + runtime + C compiler, `Std` (HTTP, async, file system), HACL* SHA-256 C (verified in F*; extraction + FFI shim trusted), JSON codec (tested), OS file system, receipt issuers (receipts accepted, not replayed), browser + GUI JS (display only). A claim's natural-language meaning reaches the kernel only through its entailment fact.
