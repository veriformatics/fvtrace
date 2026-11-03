# reviewer-5 — C-engine at 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-engine | effective status + claim state vs contract | pass | Engine `eff0/eff1/derivations/eff/active/intrinsic/final`, breakdown + `mustVerify/restsOn` match S-bind/override/exclude/conflict/state + Decisions; Model route/kind ceilings checked; focused suite 232/232. |
| C-engine | sentences + qualifiers vs contract | reviewer-5-F1 | Sentence pieces + verdict words match § Sentences/G6; qualifier contract conflates prospective `hypothetical` with changed-by-what-if; built C3 witness rc=1. |
| C-engine | ranking, blockers, latent | pass | `closable/gates/unlocks/work/workBefore/blockerFacts` match § Ranking + blockers; ties desc-unlocks/desc-gates/asc-id; `latent` preserved in envelope + isolated in CLI group; focused tests cover ties, conditional≠unlock, mixed/blocked rows. |
| C-engine | experiments (lights/clears/breaks, closure, ranking) | pass | Closure reaches creator + requires to fixed point; success strength-join preserves stronger facts; failure applies violated alone; moves/count partition + effort/id ordering match contract; `rowOf` applied/contingent read closure; focused creator/isolation/merge/lowering witnesses pass. |
| C-engine | plans (search, limit, tooLarge, coverage) | pass | `relevant/coverage/costOf/planBetter/optimistic/skips/search/plan` match § Plans + Decisions; rank→cost→ids, strict cost pruning preserves ties, `maxRelevant=20`, branch order correct; G4 + search-equality statements checked; 20-limit suite 4/4 + focused 21→tooLarge/coverage witnesses pass. |
| C-engine | review state | pass | `Receipt.Basic.reviewStateOf` exactly implements draft/stale/reviewed; `Receipt.reviewDigest` strips review + replay notices; `Session.prepare` + load carry that recorded digest/state independently of overrides; G11 statement matches. |
| C-engine | wiring: binary → proved constants | pass | Main→Cli.run/dispatch→Session.load→Answers.fast; eval/details/projections + text paths traced. `Spec.AnswersAgree` + `Proofs/Agree.answersAgree` equate full record to Scenario references; no csimp/implemented_by found. Native recorded + what-if vs interpreted reference + all projections/plans: 50/50. |
| C-engine | unproved code (Present, details) | pass | Present whole file + direct callers read: verbatim joins, baseline comparison, creator selection, sort keys. Evaluate item/details/action/full-plan assembly read: first-match lookups, error order, normalized expansions, list order + multiplicity retained; focused + native/reference checks pass. Qualifier documentation mismatch isolated in F1. |
| C-engine | Tests/Engine.lean + Tests/Details.lean | pass | Both files read in full, harness + callees inspected; pure scenarios/read-only fixtures, no setup/teardown asymmetry. All their suites run interpreted against base oleans: focused 232/232 + scale 4/4; expectations match contracts except the contract-side F1 predicate. |

## Findings

### reviewer-5-F1 — minor — qualifier contract conflates `hypothetical` with an actual what-if

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/.agent/contracts/kernel.md:89`; implementation `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Present.lean:81`, envelope `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Evaluate.lean:85`.
- Contract: § Claim state line 82 defines `hypothetical c` as prospective **or** changed by overrides. § Sentences line 89 promises `what-if` for hypothetical claims. Code instead passes `changedByWhatif` to `qualifiersWith`; a prospective recorded claim has `hypothetical=true`, its creator qualifier, and no `what-if` qualifier. No state/verdict error established; the documented predicate is wrong relative to the implemented + explicitly tested label policy.
- Text anchor (matches line 89):

```sh
rg -Fn 'what-if` (hypothetical)' /home/eturkes/Projects/fvtrace/.scratch/review-base/.agent/contracts/kernel.md
```
- Behavior witness: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-5/prospective-label.sh`; rc=1 on 48bc51d:

```text
FAIL kernel.md:89: hypothetical claim lacks the promised what-if qualifier
{"id":"C3","hypothetical":true,"label":{"verdict":"Pending verification","qualifiers":["draft","if-creator-runs"],"creator":"E3"}}
```

- Existing explicit expectation: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Engine.lean:89`, anchor `without a what-if, a new-data claim carries no what-if qualifier`; passes in the focused suite.
- Fix direction: reconcile § Sentences with the intended label policy; if retaining the current test/behavior, tie `what-if` to changed-by-what-if rather than to the broader `hypothetical` flag. MAIN rules the stale side; no code change recommended without that ruling.

## Checks run

All commands use the frozen base's build; no target writes or rebuilds.

```sh
(cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-5/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-5/focused.lean)
```

rc=0; `232/232 checks passed` (Engine tests/witnessTests/kindTests/acceptanceTests + Details.tests).

```sh
(cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-5/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-5/plan-scale.lean)
```

rc=0; `4/4 checks passed` (Engine.scaleTests, 20 relevant experiments). Interpreted duration ≠ a P-bound timing measurement.

```sh
python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-5/native-wiring.py
```

rc=0:

```text
PASS recorded: native eval = Answers.reference; claims/gaps/experiments projections + every plan/details agree; text commands rc=0
PASS whatif: native eval = Answers.reference; claims/gaps/experiments projections + every plan/details agree; text commands rc=0
50/50 wiring checks passed
```

Native/reference comparison = synthetic example, actual current receipts, recorded + `EN2=proved,O2=checked,O3=checked`. Reference interpreter uses `Answers.reference`, `current=true`, draft; comparison excludes the shell-owned trace digest/review member + receipt display members. Native receipt-current flags independently asserted true. CLI JSON projections compare complete exact key sets; all 3 claims' plan JSON equals their details plan. Text invocations check rc + empty stderr, not a full text-output oracle.

Red witness F1 rc=1, recorded above. Logs + scripts: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-5/`.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:764`: outside owned code slice; plan text prints verdict + sentence without `A.qualifiers`, unlike claims text. Decisions Review says every surface shows the label, prospective qualifier included. Forwarded to MAIN for C-cli adjudication; that ruling remains unconfirmed. Captured native plan outputs under the scratch path above.

## Coverage limits

- Whole Engine, Present, Spec/Engine + assigned tests read; relevant theorem statements inspected, not proof bodies. This pass does not rerun kernel replay/trust, the full gate, mutation campaigns, GUI or timing gates; MAIN owns baseline rows + other slices.
- Wiring source walk reaches Main, Cli dispatch + command functions, Session, Evaluate, Answers.reference/fast + the full-record agreement claim/theorem. Fast implementation internals belong to C-fast; this pass confirms their substitution is covered by the equality, not an independent re-audit of each fast algorithm.
- Lean LSP unavailable (`No LSP server available for file type: .lean`); source + compiler/interpreter used instead.
- No servers started; no process teardown needed. Writes limited to this report + owned scratch. Notify-set edits: none.

reviewer-5-DONE-1
