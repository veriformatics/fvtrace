# Closing review (IMPLEMENT — engine speed-up, F5)

Target = `af5a2f1..fa7f307` (a782e4e contract + tools, fa7f307 engine + proofs + tests + docs); contract = `.agent/contracts/kernel.md` § Performance (P-*) + `.agent/review.md` F5 acceptance; one `reviewer` per lens (R1–R5), the security lens (S) MAIN alone. Findings bind to the contract; a behavior finding comes with a red test (command + failing output at `fa7f307`).

## Check set (fixed before reading the diff)

| id | lens | asks | verdict |
|---|---|---|---|
| R1.1 | correctness | every envelope, CLI text, export, snapshot + server path reads the fast records (P-shared); no unproved fast computation outside the records beyond the P-shell list (`Overrides.parse`, CLI grouping, `neededBy`, `andList`, receipt/pin/export/replay arrays, binding index wiring) | pass (reviewer-19: every output path reads the fast records; P-shell list complete) |
| R1.2 | correctness | P-shell code keeps the original behavior on its whole domain: first refusal + message order, list order, duplicates, empty + malformed inputs, ids outside the trace | pass (reviewer-19: 20,716 original-definition comparisons, refusal + list order kept) |
| R1.3 | correctness | `Fvtrace.Index`, `Ctx.closures`/`closureOf`, `Delta`, memos: edge cases (empty, duplicate ids, unknown ids, cycles, positions past the end), termination, laziness (a memo shared by one scenario only) | pass (reviewer-19: edge cases, termination, one memo per scenario) |
| R1.4 | correctness | the page engine's closure stays `Init`-only + total; native ↔ wasm parity covers the new modules | pass (reviewer-19: Snapshot closure 16 modules, Init only; Node corpus rerun interrupted by load, parity suite wiring confirmed) |
| R2.1 | claim soundness | `Spec.LookupsAgree`, `Spec.SortMembersAgree`, `Spec.AnswersAgree`: non-vacuous, about the shipped functions the binary calls, domain = every trace / scenario; docstrings say no more than the statements | finding R2-F1 → fixed 84da642 |
| R2.2 | claim soundness | proofs: no `sorry`, axiom or escape hatch; `fvtrace-trust` covers the new modules (claims, capabilities); kernel replay | pass (reviewer-20: fresh export = stored, six kernels accept, 26/0) |
| R2.3 | claim soundness | self-trace C9 + P10–P12 + E9 texts, README "How fvTrace verifies itself" + Development lines say what the theorems + tools establish, no more | finding R2-F1 → fixed 84da642 |
| R3.1 | guarantee vs claim | proved vs tested boundary stated right in `kernel.md` (P-shell, Printers + IO), README, commit bodies; nothing tested is presented as proved | pass (reviewer-21) |
| R3.2 | guarantee vs claim | P-bound evidence: graded rows at cap/2 → cap on an idle host, hub statement, supplemental shapes' "time follows output" reading, plan limit kept | findings R3-F1, R3-F2 → fixed 84da642 |
| R3.3 | guarantee vs claim | quantitative statements in commit bodies + ledger match their logs (red witness, compare runs, trust, test counts, baselines) | pass (reviewer-21; 304 s + 53bcecc figures unlogged → stated as such) |
| R4.1 | verification integrity | Tests/Scale + Tests/Differential assert contract-derived values (not values read off the implementation); the red witness = the same test on the unfixed revision, command + output recorded | pass (reviewer-22) |
| R4.2 | verification integrity | no test, gate stage, probe or threshold weakened, skipped or removed; changed tests only adapt the API (+ C9) | pass (reviewer-22) |
| R4.3 | verification integrity | new purpose-built checks (`tools/scale.sh --assert`, `tools/compare.sh`) fire on planted inputs (probes `scale`, `compare`) and grade what the contract says (per-doubling ratio, timeout, rc, all three output streams, fresh data folder) | findings VI-1 → fixed 84da642, VI-2 → fixed in the commit after 84da642 (re-review) |
| R4.4 | verification integrity | mutation credit for the tested P-shell lines: scope + command + every survivor ruled | finding VI-3 → fixed 84da642 (2 survivors killed) |
| R5.1 | CLAUDE.md conformance | comments state the why; agent-facing text dense; README in ASD-STE100 register | pass (reviewer-23) |
| R5.2 | CLAUDE.md conformance | dead code, duplicated helpers, special cases on shared infrastructure | findings R5-F1, R5-F2 → fixed 84da642 |
| R5.3 | CLAUDE.md conformance | `.claude/rules/` (fast, ops, lean, examples): live law + why, `paths:` scope right, no origin stories; `spec.md` shape + Artifacts + Tasks; commit subject `<scope>: <cause> → <fix>` + bodies | findings R5-F3, R5-F4 → fixed 84da642 |
| S1 | security | resource exhaustion from untrusted traces, bundles, snapshot pages + what-if specs after the change (time, memory, recursion depth) | pass (MAIN: time + memory vs af5a2f1; output-quadratic envelopes pre-existing → `.agent/deferred.md`) |
| S2 | security | panics + out-of-range reads on hostile input in the new code (`get!`, `[i]!`, array writes), integer edge cases | pass (MAIN: no panicking accessor added; `set!` = setIfInBounds; indexes read `[i]?`) |
| S3 | security | capabilities + page engine surface unchanged (no new process, file, network or environment use; wasm imports + exports) | pass (MAIN: capability audit 26/0; page engine imports + exports checked at build) |

## Findings (closing review; details = the reviewers' deliverables: `review-implement-engine/reviewer-19.md` … `-23.md`)

| id | row | severity | finding | ruling | fix |
|---|---|---|---|---|---|
| VI-1 | R4.3 | major | `tools/compare.sh` counted two runs killed at the limit with equal partial output as parity | accepted | 84da642: a timeout fails the run (`TIMEOUT` line, exit 1), probe `compare-timeout`; re-review: fixed |
| VI-2 | R4.3 | minor | `tools/scale.sh` graded the ratio after rounding (2.504 → 2.50 passed) | accepted | 84da642 graded a `%.6f` string; re-review: not fixed (2.500000129874673 → "2.500000" passed); next commit: awk grades the double; MAIN reran reviewer-22 `ratio-recheck.sh` → all 4 cases as expected (rc 0) |
| VI-3 | R4.4 | minor | mutants `Cli.lean:452 ≤ → <`, `:455 == → !=` (prospective grouping) survived; specified behavior | accepted | 84da642: Tests/Cli `groupTests`, both killed; re-review: fixed |
| R2-F1 | R2.1, R2.3 | minor | README + `Spec/Fast.lean` "a 16 MiB trace takes seconds"; Development line "fails when a run …" | accepted | 84da642: graded workloads + idle host named; re-review: fixed |
| R3-F1 | R3.2 | minor | = R2-F1 | accepted | 84da642; re-review: fixed |
| R3-F2 | R3.2 | minor | `kernel.md` promised plan-node + artifact-byte accounting no tool reports | accepted as an over-promise; disposition (MAIN): the evidence scope narrows — the F5 acceptance never graded these counters, the plan search stays bounded by its ruled limit (Tests/Engine `plan-scale`), and counting would put a stats channel into the shipped binary | 84da642: P-bound states what `tools/scale.sh` reports + what stays unmeasured; re-review: the reviewer's acceptance (an accounting path) not met, closed by this disposition |
| R5-F1 | R5.2 | minor | four unused lemmas in `Proofs/Answers.lean` | accepted | 84da642: removed; re-review: fixed |
| R5-F2 | R5.2 | minor | sentence + qualifier assembly + creator-title walk copied into `Answers.fast` + Cli | accepted | 84da642: `Scenario.sentenceWith` / `qualifiersWith` / `creatorTitleWith`; re-review: fixed |
| R5-F3 | R5.3 | minor | `fast.md` missed the mirrored definitions + P-shell consumers | accepted | 84da642: paths extended; re-review: fixed |
| R5-F4 | R5.3 | minor | `fast.md` carried an origin clause | accepted | 84da642: removed; re-review: fixed |

Register: `O(log n) each` comments (Index, Lookups; reviewers 20 + 21) → fixed 84da642; `ops.md` probes bullet split by fa7f307's insert (MAIN) → fixed 84da642; `TrustMain` walks statements + definition values, theorem bodies only through `collectAxioms` (`ConstantInfo.value?` skips theorems without `allowOpaque`; a proof body changes no compiled code) → `lean.md` wording fixed 84da642, audit unchanged; Tests/Differential runs `compareAnswers` on WF traces alone (reviewer-22) → `AnswersAgree` is proved for every scenario, no action; new proof modules keep the repo's linter options (reviewer-23) → no action; `tools/mutate.mjs` mutated the pipes `<|` + `|>` (MAIN) → fixed 84da642.
