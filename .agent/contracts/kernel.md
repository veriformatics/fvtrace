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
- `Kind` (fact) = `entailment | result | estimand | statistical | numerical | implementation | dataflow | provenance | interpretation | release | spec-review | instantiation`. Must-verify kinds `V` = `{entailment, result, estimand, numerical, implementation, dataflow}` (a claim may assume none of them); the rest = premise kinds (background conditions).
- Fact-level rule: `allows f s` ⇔ `allowed (route f) s` ∧ (`s ≠ assumed` ∨ `kind f ∉ V`). `ceiling f` = `tested` when `kind f ∈ V` ∧ `ceiling (route f) = assumed`, else `ceiling (route f)` (`allows f (ceiling f)` always holds). `Level` (claim) = `estimand | descriptive | inferential | causal | release`. `Effort` = `hours < days < weeks < months`; `ExpKind` = `dry | wet`.
- Trace `{fvtrace: 1, analysis, subjects, questions, facts, claims, experiments?, exclusions?, waivers?, review?}` (absent arrays = empty):
  - analysis `{id, title, summary, source?}`; subject `{id, title, kind: existing | prospective, createdBy?}`; question `{id, title, text}`.
  - fact `{id, subject, kind, text, status, route, evidence?, trusts?, instantiates?, why?}` (`why` = why a claim needs it, display text); evidence `{summary, artifacts?: [{path, sha256?, role?: text}], verifier?, statement?, statementDigest?}`.
  - claim `{id, question, subject, level, text, headline?, needs: [F], entailment?: F, restates?: bool, latent?: bool, variantOf?}` (`text` = the exact statement; `headline` = its plain display form, never stronger: the reviewer's call); `needsAll c` = `needs ++ [entailment]` (`needs` alone for a restating claim). Default `restates` = `false`.
  - experiment `{id, subject, kind, effort, title, method, resources, success: {F: Status}, failure?: {F: Status}, requires?: [E], caveat}` (`resources` = prose; `requires` = experiments that must run first).
  - exclusion `{id, subject, between: [F, F], text, status, route, evidence?}` (a relation is itself a fact-like assertion: "these two cannot both hold").
  - waiver `{rule, claim, reason}`; review `{reviewer, date, digest, note?}`.
- Scenario = trace + `current : F ∪ X → Bool` (receipt binding, computed by the shell; consulted for recorded verified statuses alone) + overrides `ω : F ⇀ Status`.

## Well-formedness (WF-*; `check` = list of violations; **proved**: `check t = [] ↔ WF t`, each listed violation ⇒ its rule fails)

- WF-ids: ids unique across all collections. WF-refs: every reference resolves (question, subject, needs, entailment, variantOf, outcome keys, requires, exclusion pair + subject, createdBy, waiver claim, instantiates).
- WF-subject: claim needs + entailment, experiment outcome keys, exclusion pair all on the owner's subject; `instantiates` names a fact on another subject.
- WF-entail: a claim names `entailment` ⇔ ¬`restates`; an entailment fact has kind `entailment`, ∉ the claim's needs, used by exactly one claim; no `entailment` fact in any `needs`. A restating claim needs exactly one fact, of kind `result`, restated by no other claim.
- WF-needs: needs non-empty + duplicate-free.
- WF-route: every recorded fact status + every outcome status `allows`-ed by its fact (route + kind: no must-verify fact holds `assumed`); every exclusion status `allowed` by its route.
- WF-outcome: success non-empty, values ∈ asserted; failure values = `violated`; `requires` names experiments listed earlier on the experiment's subject (acyclic by construction: list prerequisites first).
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

- statementDigest f = SHA-256 of D-canon `{id, subject, kind, text, route}` of f; for an entailment fact add its claim `{id, subject, level, text, needs: [{id, text}]}`; for a result fact a claim restates add `restatedBy` = that claim's `{id, subject, level, text}`; for an instantiation fact add the source fact's `{id, subject, kind, text}`. `why` + `headline` stay outside (display text; the review digest covers them). For an exclusion: `{id, subject, text, route, between: [{id, subject, kind, text} of each endpoint]}` (rewording an endpoint stales the relation's receipt).
- current x ⇔ every artifact exists under the project root + its sha256 matches ∧ statementDigest = the recomputed digest. Artifacts are read + hashed on every command; `--cached` (opt-in, disclosed) reuses a digest whose file kept its resolved path, size + mtime. Reasons (display): `changed`, `missing`, `statement-changed`. Path resolution never leaves the project root (symlinks resolved, then prefix-checked).
- Receipts are accepted as recorded (not replayed): the trusted base names receipt issuers.

## Effective status (S-*; total; **proved** lemmas)

- S-bind: `eff0 x` = `stale` if recorded verified ∧ ¬current x, else recorded. `EStatus` = `Status` + `stale`; strength `violated` 0 < `open` = `tested` = `stale` 1 < `assumed` 2 < `checked` = `proved` 3.
- S-override: `eff1 f` = `ω f` if defined, else `eff0 f` (a direct what-if may lower a status). ω valid ⇔ keys resolve to facts on existing or prospective subjects, once each ∧ `allows f (ω f)`; invalid ω rejected with diagnostics, never clamped or dropped.
- S-exclude: exclusion x with `verified (eff0 x)`: `verified (eff1 a)` ∧ ¬`asserted (eff1 b)` ⇒ `eff b = violated`, derivation witnesses = every such (x, a) (symmetric). Otherwise `eff f = eff1 f`. One pass: a derived violation asserts nothing, so derives nothing.
- S-conflict: x active ⇔ `asserted (eff0 x)` ∧ `asserted (eff1 a)` ∧ `asserted (eff1 b)`. `valid s` ⇔ no active exclusion on subject s.

## Claim state (S-state)

- mustVerify n ⇔ n names a fact with kind ∈ V (an id naming no fact: false).
- intrinsic c (on `eff`): `cannot` ⇔ ∃ n ∈ needsAll, `eff n = violated` ∨ ∃ asserted exclusion with both sides ∈ needsAll; `can` ⇔ ¬cannot ∧ ∀ n, verified (eff n); `conditional` ⇔ ¬cannot ∧ ¬can ∧ ∀ n, asserted (eff n) ∧ (mustVerify n ⇒ verified (eff n)); `open` otherwise. (The gate holds for any input; WF + valid ω keep every assumed need a premise kind, so on valid input it never fires: G13.)
- final c = `cannot` (reason `conflict`) if ¬valid (subject c), else intrinsic c.
- Breakdown (**proved** G2: an exact partition of needsAll, order kept): verified · premises (assumed, ¬mustVerify) · gaps (open | tested | stale, or assumed ∧ mustVerify) · blockers (violated, with recorded or derived witnesses); plus `incompatible` = asserted exclusions with both endpoints ∈ needsAll (with relation status) and `conflicts` = active exclusions on the subject. **Proved**: intrinsic cannot ⇔ blockers ≠ [] ∨ incompatible ≠ []; final cannot with reason conflict ⇔ conflicts ≠ [].
- mode = `recorded` ⇔ normalized ω = [] (keys sorted, duplicates rejected); else `what-if`. `supposed c` = needsAll with ω defined. `hypothetical c` ⇔ subject prospective ∨ ∃ n ∈ needsAll, eff n ≠ eff n under ω = ∅ ∨ valid (subject c) differs from its ω = ∅ value. `provisional` ⇔ review state ≠ `reviewed`.
- Counts = final states over claims on existing subjects (zero-filled keys can · conditional · open · cannot); per prospective subject apart.

## Sentences (engine-owned; **proved** G6)

- Claim + premise texts emitted verbatim (no case or punctuation change). can: `text`; conditional: `Assuming “p₁”; “p₂”: text` (premises in needsAll order); open / cannot: `text` with the verdict word beside it.
- Verdict words: can = `Fully supported`, conditional = `Conditional`, open = `Pending verification`, cannot = `Claim not possible`.
- Label = verdict word + qualifier list: `what-if` (hypothetical), `draft` | `stale review` (provisional), `if <creator title> runs` (prospective), `conflicting what-if` (reason conflict).
- G6: a conditional sentence contains every premise text + the claim text verbatim; the emitted label's verdict word is `Fully supported` only for final = can.

## Ranking + blockers

- closable f ⇔ `eff f ≠ violated` ∧ strength (eff f) < strength (ceiling f). gates f = claims with f ∈ needsAll. unlocks f = gates f with final ∈ {open, cannot} whose final under `ω[f ↦ ceiling f]` ∈ {can, conditional}.
- work = every closable fact gating ≥1 claim, ordered |unlocks| desc, |gates| desc, id asc; **proved**: complete, duplicate-free, sorted, each entry's unlocks = the defining set. blockers = facts with `eff = violated` + the claims they block.

## Experiments

- closure E = the least set ⊇ E holding, for each member, its `requires` + the creator of its subject when prospective (a fixed point: a creator's own `requires` are included). merged P = per fact, the strongest asserted value any success in P sets. Applying a success never weakens: ω ⊕ P = per fact the strength join (max) of `eff1` and merged P; a failure sets its facts `violated`.
- preview e (success) = scenario ω ⊕ merged (closure {e}); preview e (failure) = ω ⊕ failure e. moves = claims whose final differs; lights = moves up into {can, conditional}; clears = cannot → open; breaks = failure moves into cannot. contingent ⇔ the success closure touches a `result` fact; applied ⇔ ω ⊇ merged (closure {e}). lowers = success moves down in rank; raises = the overrides the success applies (merged values stronger than `eff1`). Order: lights desc, clears desc, effort asc, id asc. **Proved** G3 (`MovesExact`): moves = exactly the replayed differences; G3b (`CountsPartition`): lights + clears + lowers = |moves| (each move counted once). breaks = a definition over failure moves (tested). Outcome isolation = WF-subject + G7.

## Plans (per claim with final ≠ can)

- Relevant R = experiments on the claim's subject whose success raises a needsAll fact above its `eff1` (strength up). Candidates = closure S for every S ⊆ R. coherent P ⇔ valid (subject) under ω ⊕ P.
- Result (tagged; first matching branch): `inconsistent` (ω already invalid on the subject) | `tooLarge` (|R| > 20: no plan claimed) | `noImprovement` (no coherent candidate beats the empty plan) | `planned P` (max rank of final under ω ⊕ P over coherent candidates; tie → min cost = effort counts months→hours lexicographic; tie → id list lexicographic). Every variant carries the coverage payload: remaining premises + gaps under the current scenario, uncovered needs (no member of R raises them; route hint), alternatives per need (experiment, status); `planned` adds experiments, final state, its premises + gaps under ω ⊕ P, contingent.
- Search = branch and bound over R in trace order, from the empty plan: each experiment first left out of the seeds, then put in (seeds, not executions: a closure may still add a left-out experiment as a prerequisite or creator); node = (seeds I, still open A); leaf candidate = closure I when coherent, folded by the plan order. Skip a node ⇔ closure I already conflicts (more successes keep every conflict) ∨ rank bound < rank B ∨ (rank bound = rank B ∧ cost B <lex cost (closure I)), B = the best so far; bound = the claim's state under ω ⊕ closure (I ∪ A) read on `eff1` (derived violations + subject conflicts only lower a state; the `incompatible` test stays, no success changes it) ⇒ no leaf below ranks higher or, at equal rank, costs less: every skipped leaf loses to B. Closure stops at its first fixed point (a step that adds nothing repeats). Worst case still 2^|R| leaves (a bound that exclusions defeat without a conflict); |R| ≤ 20 (Decisions).
- **Proved** G4: P closed + coherent + its reported state = replay (G4a); ∀ closed coherent Q (any experiments): rank Q ≤ rank P, equal rank ⇒ Q not strictly cheaper; `noImprovement` ⇒ no closed coherent Q beats the current state (G4b). Pruning lemma: with join application, experiments outside R never raise the claim's rank, so Q's stand-in = closure (Q ∩ R) ⊆ Q, a candidate at least as high + no costlier. **Proved**: the search = the exhaustive fold over every S ⊆ R (`search_eq`, `best_eq_ref`) ⇒ the same plan, ids included. Measured (native `fvtrace plan`, 20 relevant experiments): each proving one need + the reasoning fact (one need each | one shared need | two per need) or a fact whose success makes every non-empty set conflict: ≤ 0.03 s; each proving 1–3 of 8 needs + the reasoning fact: 0.13–0.25 s (the exhaustive fold: 72 s at 20, 10–14 s at 16).

## Review

- digest t = SHA-256 of D-canon of t without `review`. state = `draft` (absent) | `stale` (digest ≠) | `reviewed`. Review covers the recorded trace alone; what-ifs are never reviewed evidence.

## Evaluation envelope (`fvtrace.evaluation/1`; CLI `--json` projections + server + export share it)

- `{schema, mode: recorded | what-if, overrides: [{fact, status}] (normalized, sorted), trace: {digest, review: {state, reviewer?, date?}}, analysis, subjects: [{id, title, kind, valid, conflicts}], counts: {can, conditional, open, cannot}, prospectiveCounts: [{subject, counts}], questions, facts, claims, work: [{fact, unlocks, gates}], blockers: [{fact, claims}], experiments, exclusions: [{id, subject, between, text, recorded, effective, active}], lints: [{rule, claim, path, message, waived?}], actions: [{id, kind, target, overrides}]}`.
- fact = `{id, subject, kind, text, route, recorded, effective, closable, supposed, derivedFrom: [{exclusion, source}], trusts, instantiates?, why?, evidence?, receipt?: {current, reasons}}`.
- claim = `{id, question, subject, level, text, headline?, latent, needs, entailment?, restates, final, intrinsic, sentence, label: {verdict, qualifiers}, verified, premises, gaps, blockers, incompatible, conflicts (= the breakdown), hypothetical, provisional, plan, variantOf?}`; plan = `{result, premises, gaps, uncovered, alternatives: [{need, experiment, status}]}` + for `planned`: `experiments, state, planPremises, planGaps, contingent`.
- experiment = `{id, subject, kind, effort, title, method, resources, caveat, success, failure, requires, closure, raises, applied, contingent, prospective, creates, wins, losses, lights, clears, lowers, breaks}`.
- actions = the one-click domain from the evaluated scenario: `suppose f` (closable f ↦ ceiling f), `success e`, `failure e` (non-empty failure), `plan c` (planned results); each maps to the complete what-if it leads to (ω ⊕ the action), so a click replaces ω. Recorded (ω = []) = the export's finite domain: one envelope per action, never stacked; the server GUI stacks by clicking from a what-if.
- CLI projections: `claims --json` = envelope keys {schema, mode, overrides, trace, subjects, counts, claims}; `gaps --json` = {schema, mode, overrides, trace, work, blockers}; `experiments --json` = {schema, mode, overrides, trace, experiments}; `plan <c> --json` = {schema, mode, overrides, trace, claim c}. Parity = structural equality with the server envelope's same keys for one snapshot (trace bytes, bindings, ω).

## Outcome guarantees (**proved** unless noted)

- G1 recorded soundness: mode recorded (ω = []) ∧ final c = can ⇒ valid ∧ ∀ n ∈ needsAll: recorded verified n ∧ current n; WF ⇒ subject existing (G1b). (Its meaning: the receipts named for every need, incl. the claim's own entailment statement or, for a restating claim, its result's statement bound to the claim text, are present + unchanged; receipt acceptance + the formal reading of each proved statement are the declared trust boundary.)
- G5 ruling ceiling: WF ∧ c ∈ claims ∧ ω valid ∧ entailment c names a fact on route human-ruling | empirical ⇒ final c ∉ {can, conditional} (claim membership: WF-entail fixes the fact's must-verify kind only for the trace's own claims).
- G12 reasoning gate: final c = conditional ⇒ every mustVerify need of c is verified (any scenario).
- G13 premises only: WF ∧ ω valid ∧ n ∈ needsAll c ∧ eff n = assumed ⇒ ¬mustVerify n.
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
- Must-verify kinds (IMPLEMENT GUI): a recorded `assumed` result, entailment, estimand, numerical, implementation or dataflow fact → `fvtrace check` error WF-route (CLI smoke case); an experiment success setting one `assumed` → WF-route error; `--whatif O2=assumed` on the result O2 → rejected (exit 2), the GUI shows the engine's problem.
- Restating claim: a WF, lint-clean, nonconflicting trace whose claim restates one result with no entailment fact passes `fvtrace check --strict` with a current receipt and reads as the result's effective state (checked → can; open → open; violated → cannot); separate cases: the result's receipt stale → open; a conflicting what-if on the subject → cannot (conflict); rewording the claim after `pin` stales the result's receipt.
- New fields: schema + decoder corpus cases cover `why`, `headline`, `restates` (valid + invalid); `fvtrace serve` on the synthetic study renders the ITERATE page with no proxy; `rg 'Can claim|On assumption|Not yet|Cannot claim' Fvtrace web` = 0 outside the rename's own test.
- Waived lints (GUI): C2's waiver appears in C2's details ("Not needed: a statistics fact. Reason: …"), not under "What may be missing" (e2e on the synthetic study).
- Work rows (GUI + CLI `gaps`): every row names each claim in `gates \ unlocks` with the facts that claim needs together with it (its engine `gaps` minus the row's fact: "Needed by C2, together with O3 and EN2."), whatever the row's count; a count shows only when > 0. A mixed row (one claim unlocked, another needing more) shows both.
- Sign-off: `fvtrace review` prints what the reviewer vouches for: the claims + facts match the study, each headline says no more than its exact statement, the universal premises hold (honest records, working instruments, correct labels) (CLI test).
- Self-trace (U6): C1, C3–C6 + C8 read Fully supported on the recorded trace with current receipts (provisional until reviewed), their reasoning facts `proved` with receipts naming the Lean statement(s) each claim's sentence reads; C2 + C7 read Pending verification (they need tested code; E2 + E7 stay `open`); no claim needs I1; I2 records `tested`; `check --strict` rc 0.
- Display fields: after `pin` + `review`, editing a fact's `why` alone, then a claim's `headline` alone, keeps every receipt current + the envelope's verdicts unchanged and makes the review stale.
- Actions: in a WF trace under a valid ω, every emitted action's overrides form a valid ω (`Overrides.valid`), incl. a success closure touching a must-verify fact + a premise fact.

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
- R3-K1 gate: a scenario that assumes a must-verify need (constructed directly, bypassing input checks) never reads conditional; its need lists under gaps.
- R3-K2 ceiling: a `result` fact on route `empirical` is not closable (ceiling `tested`): no suppose action, no work row; its plan coverage lists it as uncovered.
- R3-R1 restating shape: two claims restating one result, a restating claim that also names an entailment, one needing two facts or a non-result fact, a non-restating claim without an entailment → each a WF-entail error; two claims restating two different results → valid (an absent entailment is no shared one).

## Trusted base (user-facing copy: README `How fvTrace verifies itself`)

Lean kernel (replayed by independent kernels), Lean compiler + runtime + C compiler, `Std` (HTTP, async, file system), HACL* SHA-256 C (verified in F*; extraction + FFI shim trusted), JSON codec (tested), OS file system, receipt issuers (receipts accepted, not replayed), browser + GUI JS (display only). A claim's natural-language meaning reaches the kernel only through its entailment fact (a restating claim: through its result's receipt, which binds the claim text).
