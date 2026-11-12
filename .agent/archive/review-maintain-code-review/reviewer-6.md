# reviewer-6 — C-engine / Correctness

Target: `48bc51d` · frozen base `/home/eturkes/Projects/fvtrace/.scratch/review-base`.

| row | target | verdict | basis |
|---|---|---|---|
| C-engine | effective status + claim state vs contract | pass | Read `Engine.lean:12–152`, Model status/kind rules + Spec G1/G2/G5/G8/G12/G13; independent status/state truth table 2304/2304; selected engine regressions pass. |
| C-engine | sentences + qualifiers vs contract | reviewer-6-F1 | Sentences preserve texts + verdict words; prospective `hypothetical=true` lacks the `what-if` qualifier required by kernel.md:89 (native red witness). |
| C-engine | ranking, blockers, latent | pass | `Engine.lean:164–186` matches closable/gates/unlocks/order + violated blockers; `Spec.WorkExact` endpoints checked; CLI preserves `latent` as Overlooked directions; selected work/blocker regressions + native gaps projection pass. |
| C-engine | experiments (lights/clears/breaks, closure, ranking) | pass | `Engine.lean:198–264`, `Present.lean:88–96` + `Answers.reference/rowOf`: fixed-point creator/requires closure, strength join, failure-alone replay, exact move counts + order match contract; selected closure/isolation/join/count regressions + native experiments projection pass. |
| C-engine | plans (search, limit, tooLarge, coverage) | pass | `Engine.lean:270–388` matches relevant/closure candidates, tagged precedence, months→hours cost + ids tie-break, pruning bound and coverage; theorem statements `search_eq/best_eq_ref/PlanSound/PlanOptimal` fit; 20/21-limit, ties, inconsistent + coverage regressions and native planned C2 → E1/conditional pass. |
| C-engine | review state | pass | `Receipt.Basic.reviewStateOf`, `Receipt.reviewDigest`, `Trace.withoutNotices`, `Session.prepare/bindPrepared` + G11 statement: absent/match/different states + fact/exclusion notice-free review content 4/4; overrides never feed the digest/review input. |
| C-engine | wiring: binary → proved constants | pass | `Main → Cli.run/dispatch → claims/gaps/experiments/plan/eval → Session/Evaluate → Answers.fast`; Spec.AnswersAgree = record equality with Answers.reference (Scenario.*), theorem `Proofs/Agree.lean:218`; no engine replacement attributes; native 10-command/projection smoke rc 0. |
| C-engine | unproved code (Present, details) | reviewer-6-F1 | Read all Present + Evaluate assembly (label tokens/creator id, plan coverage/tags, experiment lists, item refusal/order, complete reverse raisers); no additional defect; F1 is outside every qualifier proof. Details/reference oracles + native projections pass. |
| C-engine | Tests/Engine.lean + Tests/Details.lean | reviewer-6-F1 | Both files read end-to-end; all six selected entrypoints run: 236/236 checks pass (engine, details, 20-plan scale). `Tests/Engine.lean:89–90` pins F1's contract-opposed prospective expectation; no other test-logic defect found. |

## Findings

### reviewer-6-F1 — minor — prospective qualifier law ≠ implementation

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Present.lean:81`; contract `/home/eturkes/Projects/fvtrace/.scratch/review-base/.agent/contracts/kernel.md:82,89`.
- Contract: `hypothetical` includes every prospective subject; label includes `what-if` for `hypothetical`. Implementation uses `changedByWhatif` instead; a recorded prospective claim is hypothetical but has no `what-if` qualifier. `Tests/Engine.lean:89` explicitly pins the opposite of the contract, so this is a law ↔ behavior mismatch, not a request to add a redundant qualifier by taste.
- Text anchor: ``rg -Fn 'what-if` (hypothetical)' /home/eturkes/Projects/fvtrace/.scratch/review-base/.agent/contracts/kernel.md`` → line 89, rc 0.
- Red command: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-6/prospective-label.py` (native binary at `48bc51d`), rc 1:

```text
C3: mode=recorded, hypothetical=True, qualifiers=['draft', 'if-creator-runs']
AssertionError: kernel.md:89: hypothetical claim must carry the what-if qualifier
```

- Fix direction: reconcile the qualifier rule + its pinned behavior; existing test indicates narrowing the contract's trigger to an actual changed what-if rather than changing recorded prospective display. MAIN rules the stale side; a Decisions/grading change requires the user's ruling.


## Executed checks + limits

- FFI-free Lean command pattern (all against base oleans, target untouched):

```sh
cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-6/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-6/NAME.lean
```

  - `selected.lean`: rc 0, `236/236 checks passed` (Engine tests/witnessTests/kindTests/acceptanceTests/scaleTests + Details.tests; plan-limit 6559 ms, details 1567 ms, engine 368 ms).
  - `domain.lean`: rc 0, `2304/2304 checks passed` (6×6 recorded statuses × two receipt flags each × premise/must-verify kinds each; status, final state + partition size).
  - `review.lean`: rc 0, `4/4 checks passed` (absent/matching/different review digest; canonical review input equality after fact + exclusion notices). Probe-only initial structure alignment error corrected before this run.
- `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-6/native.py`: rc 0; ten invocations (`eval`, claim details, `claims/gaps/experiments/plan` JSON + text), projections equal envelope, C2 plan = E1 → Conditional. Logs = same scratch dir, `native.log` + per-command `.out/.err`.
- F1 red = `prospective-label.py`, rc 1; `prospective-label.log` contains the output above.
- Read-only source + theorem-statement audit; proof bodies not re-reviewed. No target edits/build, gate, full native suite, mutation campaign, server or browser run. Full baseline + independent kernel replay belong to MAIN's B rows. Performance bounds not remeasured; 20-plan entrypoint is a behavioral limit test, not a P-bound claim.
- Lean LSP unavailable (`No LSP server available for file type: .lean`); direct source/caller searches + compiled-olean probes used instead. No unresolved C-engine claim beyond F1.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:764`: plan's sentence header omits `A.qualifiers` (claimsCmd includes them); prospective qualifier coverage → C-cli/F-cli lead sent to MAIN, not adjudicated in this slice. Inspected `planCmd`, footer + Decisions Review; no red test for this cross-slice lead.

reviewer-6-DONE-1
