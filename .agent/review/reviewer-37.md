# reviewer-37 — S-spec

Target = `48bc51d` (`.scratch/review-base`); lens = claim soundness + guarantee-vs-claim. Fixed set: every Spec docstring/comment vs its statement; kernel proved/tested labels + theorem/test citations vs evidence; units evidence cells vs named artifacts + commits.

| row | target | verdict | basis |
|---|---|---|---|
| S-spec | Spec/WellFormed.lean docstrings vs statements | pass | Every comment/docstring + all 21 definitions read; WF references are factored between rules as stated; both closing equivalences audited (`trust` rc 0, 26 claims). |
| S-spec | Spec/Engine.lean docstrings vs statements | reviewer-37-F1, reviewer-37-F2 | Every comment/docstring + all 21 definitions read against their referenced definitions; G4a/G4b summaries omit material domains; G8a prose is symmetric but its statement proves one orientation; remaining summaries agree. |
| S-spec | Spec/Fast.lean + Spec/Version.lean | pass | All comments + 4 claims read; record fields/sort tie order/version definition matched; all four claims present in the 26-claim audit. |
| S-spec | kernel.md proved labels → theorems | reviewer-37-F1, reviewer-37-F2 | All proved labels + G citations mapped below; 26 claims audited, pruning/search/walk/raisers theorem signatures matched. Known F1/F9 wording + F30/F35 audit limits retained, not re-reported. |
| S-spec | kernel.md tested labels → tests | reviewer-37-F3 | Decode/receipts/replay/preview/shell/page/parity suites assert their advertised class; the startup non-repetition assertion named as evidence is absent. Existing behavior defects remain by known id below. |
| S-spec | units.md evidence cells | reviewer-37-F3; known F10 | All 75 evidence cells read; named artifacts/probes + 15 project revisions resolve; historical records matched. Startup-test claim exceeds the named suite; history/private/live limits below. |

## Coverage + checks

### Proved-label / citation map

| surface | backing statement / theorem | ruling |
|---|---|---|
| WF-* | `CheckAcceptsExactlyWellFormed`, `CheckViolationsSound`; all component definitions read | pass; known F9 wording |
| S-bind + recorded soundness G1/G1b | `RecordedCanIsVerified`, `RecordedCanIsExisting`; `eff1_recorded` | pass |
| G2 + cannot reasons | `BreakdownPartitions`, `CannotExplained` | pass |
| G5/G12/G13 | `RulingCeiling`, `ConditionalNeedsVerified`, `AssumedNeedsArePremises` | pass; stated WF/override domains retained |
| G6 | `SentenceVerbatim`, `CanVerdictExact` | pass; known F1 qualifier wording is separate |
| G7 | `SubjectIsolation` | reviewer-37-F1 (kernel summary's domain) |
| G8 | `ExclusionDerives`, `BothSidesCannot` + intrinsic definition | reviewer-37-F2 (G8a orientation) |
| G9/G10/G11 | `RaisingMonotone`, `CountsComplete`, `ReviewStateExact`; recorded-count filtering + supplied review digest read | pass |
| work | `WorkExact` | reviewer-37-F1 (duplicate-freedom domain) |
| G3/G3b | `MovesExact`, `CountsPartition` | pass |
| G4/pruning/search | `PlanSound`, `PlanOptimal`; `Proofs/Plan.pruning`, `search_eq`, `best_eq_ref` signatures + arguments read | reviewer-37-F1 (WF + claim membership) |
| P-claims | `LookupsAgree`, `SortMembersAgree`, `AnswersAgree`; record fields + reference definitions read | pass |
| P-delta/P-forest/P-raisers | `Proofs/Forest.closureWith_eq`, `Proofs/Walk.walk_eq`, `raisersWith_eq` + agreement theorem usage read | pass |
| version | `VersionWellFormed` + `Proofs.versionWellFormed` | pass |

Audit command (own copy):
```sh
(cd /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-37/tree && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-37/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-37/tree/.lake/build/lib/lean .lake/build/bin/fvtrace-trust)
```
rc 0, `trust: 26 claims, 0 findings`; each of the 26 claim→proof rows preserved in `.scratch/review/reviewer-37/trust.log`. Initial invocation without `LEAN_PATH` failed (`No directory 'Fvtrace' or file 'Fvtrace.olean' in the search path entries: /opt/lean/lib/lean`); corrected environment above passed. Known F30/F35 limit the audit mechanism; no repeat finding here. No `.lean` LSP server was available (hover on the real Spec file returned that error); source + Lean kernel/interpreter used instead.

### Tested-label map

| surface | assertions matched |
|---|---|
| Decode / G-codec | full `Tests/Json`, `Decode`, `Schema`; Fields round trip; corpus runners; CLI bounded-read assertions + smoke cases |
| Receipts / review / digest | full `Tests/Receipt`; Digest assertions; Fields restated/display bindings; Notices review invariance |
| Replay | full `Tests/Replay`; Notices matrix/log/write assertions + schema corpus cases |
| breaks / experiment flags | `Tests/Evaluate.lean:35–36`; Engine outcomes, conflicts + previews |
| P-shell | Engine override refusal cases; Cli grouping; CliStore projections/cache; Receipt arrays/binding order; Snapshot parity |
| V-* / parity | Details action/list oracles; Server direct native parity + trace edits/view refusal; Snapshot state/native parity |
| E-snap/request/state/build/ABI | full Snapshot + Wasm; Export assertion index; full engine differential + loader tests; cases + Chromium driver |
| E-page/GUI | Export worker/CSP/data assertions; file-offline native verdict comparison + worker/error e2e; responsive/GUI test names + relevant assertions |

This map verifies test existence + what the assertions assert, not a fresh green run. Known behavior/assurance defects met in these claims: F4/F5/F8/F17 (Replay), F19/F20 (serve), F21 (scale/compare evidence), F24–F27 + F37–F45 (GUI/export). No new restatement of them. Known F10 covers units.md's machine-bound host text.

### Units evidence (all 75 cells)

| units section | cells | basis |
|---|---:|---|
| IMPLEMENT whole product | 12 | named tests/tools exist; `archive/implement.md` + `review-implement.md` corroborate the 21-claim original stage, review/trial/QA records + mutation rulings |
| IMPLEMENT GUI | 6 | Engine/Check/Fields/Decode/Receipt/Export assertions + schema cases; `archive/implement-gui.md` + review ledger |
| MAINTAIN deferred rows | 10 | test/probe names matched; all named project SHAs resolve; archive sweep records + `27787a1` body corroborate load-run figures |
| IMPLEMENT export | 8 | Wasm/Snapshot/Export + engine/e2e sources; archive spike/export/review; reviewer-37-F3 on the snapshot attribution |
| dependency upgrade | 1 | archive upgrade inventory + code/test/probe artifacts; historical execution claims remain bounded below |
| security review | 6 | named smoke/JSON/capability artifacts + revision references; archive ledger/close records consulted for existence only |
| IMPLEMENT engine speed-up | 6 | index/agreement/closure proofs; Differential/Scale; archive engine + review records |
| IMPLEMENT what-ifs | 11 | Details/Snapshot/Server + differential/GUI sources; archive whatifs + review + acceptance log path; reviewer-37-F3 on launch-count evidence |
| MAINTAIN fvapi readiness | 7 | Notices/corpus/e2e assertions; archive readiness/review; release + GUI artifact names matched |
| MAINTAIN naoto serve | 1 | token/type/proxy/access test assertions; archive naoto + closing review |
| sixth deferred sweep | 5 | cache/teardown/release artifacts; archive sweep/review/attestation records + named SHAs |
| second dependency sweep | 2 | archive upgrade-2 + `d9dddbf`/`d6f6b16` bodies match pin/probe/driver evidence; named SHA references resolve |

Revisions: all **15 project SHAs printed in units.md** resolve under `git show <sha> --stat` (logs `git-<sha>.txt`, summary `units-evidence.log`); no missing named file/probe found. `f557259` is the **external HACL*** trial revision, not a project revision: project `git show` correctly returns rc 128; its trial is recorded in `archive/maintain-upgrade-2.md` + `d9dddbf`'s body, not claimed locally resolvable.

Limits / unconfirmed:
- Historical private migration + blind live trial, raw screenshot counts/visual-QA outcomes and the original consultant conversations: unconfirmed independently; checked their committed archive/close records + related tests, not private data, desktop or deleted scratch transcripts.
- Historical CI/run status, external HACL trial revision's remote existence + attestation verification: unconfirmed live; checked local cited objects, archive records, commit bodies + attestation transcript only. No remote/third-party action performed.
- Full gate, independent-kernel replay, mutation campaigns, purpose-built probes, browser suite + scale measurements: **not run** in this slice. Source existence/claim matching does not re-credit those executions. No test or gate was changed.
- The `worker loader` evidence was read as the tested `web/engine.js` module that the worker imports; differential suites run that module directly, while worker transport is covered by functional e2e. No broader byte-differential transport coverage is inferred.

## Findings

### reviewer-37-F1 — minor — proof summaries omit material theorem domains

- Locations at `48bc51d`: `Fvtrace/Spec/Engine.lean:158,166`; `.agent/contracts/kernel.md:95,107,178`.
- Contract: S-spec / `CLAUDE.md` Engineering adversarial review — natural-language claims say no more than their formal statements; theorem hypotheses remain visible.
- Exact anchors (each matched with `rg -Fn` against the base):
  - Spec: `a plan holds its prerequisites`; `no prerequisite-closed set of experiments`.
  - kernel: `**proved**: complete, duplicate-free, sorted`; `**Proved** G4: P closed`; `G7 subject isolation: ω or an outcome`.
- Contradiction: `Spec.PlanSound` (`Spec/Engine.lean:161`) assumes `WellFormed s.trace`; `PlanOptimal` (`:171`) also assumes `c ∈ s.trace.claims`. Neither G4 docstring states these domains. The kernel's G4 summary drops both; its work summary calls duplicate-freedom proved without `WellFormed` although `Spec.WorkExact` (`:148`) states that hypothesis; G7 drops `WellFormed` + claim membership from `Spec.SubjectIsolation` (`:100`). Other nearby summaries state their domains explicitly (G5, G13; WorkExact's own docstring).
- Materiality witness: `.scratch/review/reviewer-37/domain-witness.lean` (pure, no target edits). Command:
  ```sh
  (cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-37/domain-witness.lean)
  ```
  rc 1; output includes:
  ```text
  duplicate work ids: ["F", "F"]
  dangling prerequisite plan: Fvtrace.PlanResult.planned
  ... ["E"] ... (Fvtrace.State.can) ...
  declared closure holds missing prerequisite: false
  WF trace, external claim plan: Fvtrace.PlanResult.noImprovement ...
  external claim state: Fvtrace.State.open → Fvtrace.State.can
  uncaught exception: unqualified duplicate-free work summary fails without WF
  ```
  The external trace's `WellFormed` is itself kernel-checked in the witness via `checkAcceptsExactlyWellFormed`; the external claim is proved absent from its claims. Thus even WF alone does not supply G4b's missing membership domain.
- Scope: wording defect, **not** a claim that the CLI evaluates malformed traces. The proved statements remain sound; the summaries expand their quantification.
- Fix: name WF + claim membership where required, or declare the shared domain explicitly and preserve the exceptions that really cover arbitrary scenarios.

### reviewer-37-F2 — minor — G8a's symmetric prose exceeds its one-direction statement

- Locations at `48bc51d`: `Fvtrace/Spec/Engine.lean:69–75`; `.agent/contracts/kernel.md:69,73`.
- Contract: S-spec — a proved claim's English statement matches its Lean statement, with its whole advertised domain.
- Exact anchors: `a verified exclusion with a current receipt makes the unasserted side` in Spec (`rg -Fn` → line 69); `derivation witnesses = every such (x, a) (symmetric)` in kernel (`rg -Fn` → line 73).
- Proof: `Spec.ExclusionDerives` quantifies `b` but requires `x.between.2 = b` + verified `s.eff1 x.between.1` (`Spec/Engine.lean:74`). It establishes only first-endpoint → second-endpoint derivation. The prose states an unqualified unasserted side and the proved-status section explicitly says symmetric. `Fvtrace.Proofs.Engine.exclusionDerives` (`Proofs/Engine.lean:288–302`) has exactly that Spec type; no reverse-orientation theorem is present in `Fvtrace/Proofs/` (search `ExclusionDerives|exclusionDerives|exclusion_deriv|derives`, then the remaining derivation lemmas in Engine).
- Scope: the implementation **does** handle both orientations (`Fvtrace/Engine.lean:88–91`); this is a claimed-proof coverage gap, not a failing derivation behavior. The audit correctly lists the narrower statement proved, so its green result does not establish the omitted orientation.
- Fix: strengthen G8a to quantify both endpoint orientations and prove it (keeping the intended symmetric contract), or state the one-direction proof limit and identify the reverse direction's actual assurance.

### reviewer-37-F3 — minor — units evidence attributes assertions that the named suites lack

- Locations at `48bc51d`: `.agent/contracts/units.md:53,98`.
- Contract: S-spec — every evidence cell points to evidence that exists and asserts the stated property.
- Exact anchor: `launch evaluation awaited, not repeated` (`rg -Fn` → line 98). The cell attributes this to `Tests/Server native`.
- Source proof: the whole `Tests/Server.lean` (237 lines) has `pureTests`, `answerTests` + `nativeTests`; its native calls go directly through `answer` / `answerBody`. It does not run the CLI startup/pre-evaluation path, arrange a request during that evaluation, or count evaluations. It checks envelope/detail/action parity, view refusal, trace edits and fresh/cached receipt reads, so these other evidence claims are supported. The only native `Server.start` elsewhere (`Tests/CliStore.lean:177`) holds an IPv6 listener to test a port refusal; it sends no startup-evaluation request.
- Exhaustion: `Tests/Server.lean` read in full; `Tests/`, `tests/` + `TestMain.lean` searched for startup/instrumentation names. Positive control, expected 1: `rg -c -F 'server: details for another view = 409 view' <base>/Tests/Server.lean` → `1`, rc 0. `rg -n 'Server.start|serveCmd|serveLoopback|launch|warm|evalCount|evaluationCount' <base>/Tests/Server.lean` → no lines, rc 1. Broader startup-invariant search across both test trees → no lines, rc 1. Originals at `bc53e1c` + `d2369f6` checked too; the latter's commit body lists the actual direct-answer tests, not a launch-count test. Logs: `.scratch/review/reviewer-37/server-{test-history,u6-credit,u6b-credit}.txt` + `server-u6b-original.lean`.
- Second cell: line 53 attributes `over every action + seeded stacks` to `Tests/Snapshot`. The complete current file + the original at `0aafd59` use the exhaustive pair loop (`Tests/Snapshot.lean:64–70`), not seeded stacks; fixed literal stacks appear too. The actual seeded 1–3-entry stacks are in `tests/engine/cases.mjs:227–241,446`, a different suite. Anchor `over every action + seeded stacks` matches line 53. Attribute the seeded evidence to that suite or state the snapshot suite's actual exhaustive-pair coverage. The old `--evaluate-snapshot` hook in the same cell **did** exist in `0aafd59:TestMain.lean`; it is historical evidence rather than an invented hook (the current hook is `--answer-snapshot`).
- Scope: unsupported/misattributed test-evidence claims, **not** a demonstrated startup implementation defect. Byte parity cannot distinguish one evaluation from a repeated evaluation that returns the same bytes.
- Fix: add the described startup/overlap/count assertion, or limit its evidence cell to the tests actually present and record the uncovered startup assurance explicitly; attribute seeded-stack coverage to its real suite.

## Register

None outside the fixed check set.

## Completion

6/6 seeded rows adjudicated; 3 new minor findings; existing findings cited by id. `bash .scratch/review/reviewer-37/anchors.sh` rc 0 (10/10 literal anchors); seed-token search = 0 matches (rg rc 1; seeded positive control was 6 rows, rc 0). Pure Lean domain witness = intentional red rc 1. Own audit copy removed after its run (cleanup rc 0 + absence check rc 0); regenerate it with BRIEF.md's copy command before repeating the recorded audit invocation. Retained scratch files = evidence/scripts only. No server started; target source unchanged; deliverable unstaged; no git write.

reviewer-37-DONE-1
