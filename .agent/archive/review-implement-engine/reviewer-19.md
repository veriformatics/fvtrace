# reviewer-19 verdicts: correctness lens (closing review, IMPLEMENT — engine speed-up)

| id | asks | verdict | findings |
|---|---|---|---|
| R1.1 | every envelope, CLI text, export, snapshot + server path reads the fast records (P-shared); no unproved fast computation outside the records beyond the P-shell list (`Overrides.parse`, CLI grouping, `neededBy`, `andList`, receipt/pin/export/replay arrays, binding index wiring) | pass | - |
| R1.2 | P-shell code keeps the original behavior on its whole domain: first refusal + message order, list order, duplicates, empty + malformed inputs, ids outside the trace | pass | - |
| R1.3 | `Fvtrace.Index`, `Ctx.closures`/`closureOf`, `Delta`, memos: edge cases (empty, duplicate ids, unknown ids, cycles, positions past the end), termination, laziness (a memo shared by one scenario only) | pass | - |
| R1.4 | the page engine's closure stays `Init`-only + total; native ↔ wasm parity covers the new modules | pass | - |

## Findings

None.

## Register (defects outside the check set)

None.

## Review evidence / progress

- Fixed set = R1.1–R1.4 before diff read; target `af5a2f1..fa7f307`. Working `HEAD=4e8eefa` differs only in `.agent/review.md`; target code unchanged.
- Read: shared brief, Performance contract, F5 + closing rows; applicable fast/lean/wasm/ops rules. LSP attempted on `Fvtrace/Index.lean` → no `.lean` server; source + executable checks instead.
- Read each new runtime module + changed shell hunk; traced CLI → Session → Evaluate, server → Session, export → Session + Snapshot, Snapshot → Evaluate.
- `python -I .scratch/reviewer-19/assemble.py` regenerates `Probe.lean` from `af5a2f1`'s Check, Lint, Evaluate, pure receipt manifests, Overrides.parse, CLI wording + replay-output functions, namespace-renamed; appends `ProbeBody.lean`. `(cd /home/eturkes/Projects/fvtrace && lake env lean --run .scratch/reviewer-19/Probe.lean)` → rc 0; `shell comparisons=7505`, `shell+engine comparisons=9793`, `reviewer-19 comparisons=20716; PASS` (`probe.log`). Own scaffold's initial syntax/type errors corrected before this run.
- Probe domain = 9 traces (empty, duplicate facts/claims/subjects/experiments, self-exclusion, unknown references, cyclic creator/prerequisite graph), 820 what-if strings per trace (message precedence + normalized outputs), 72 scenarios × 3 review states, outside claims, duplicate bindings, interleaved scenario memos; all lists of length 0–5 over `['', 'a', 'β']`, index reads through `2^65`, empty/reversed bounds. Old/new envelope comparison = bytes (`pretty`), original core definitions unchanged. CLI grouping checked on unique subjects (Session's WF guard excludes duplicates before calling it); claim multiplicity + ordering kept.
- Probe positive control: `ProbeRed.lean` differs only in the private old `andList []` oracle → `planted mismatch`; `lake env lean --run .scratch/reviewer-19/ProbeRed.lean` → rc 1, `uncaught exception: FAIL andList []` (`probe-red.log`). No target mutation.
- `python -I /home/eturkes/Projects/fvtrace/.scratch/reviewer-19/io-probe.py` → rc 0; built CLI `pin --replay`, `check --json`, `verify --run --json`, `export --bundle`: fact/exclusion + failure-message order, repeated artifact paths, SHA-256 replay outputs, first receipt reasons, bundle bytes preserved (`io-probe.log`). Isolated case removed in `finally`. Initial smoke parser expected `cannot bundle`; original Cli:705 says `cannot copy`; corrected parser, no target defect.
- New-runtime totality: Index's bounds + scan use `termination_by`; closure walk + search structural. No `partial`/`unsafe`/`opaque`/`axiom` declaration in the five new runtime modules (rg rc 1; positive control Index `^def ` count 13, rc 0). Existing Json Value.beq/canonical/pretty partial declarations remain unchanged (printers, outside the new-kernel totality requirement).
- R1.4 source/build coverage confirmed: `lakefile.lean:55–76` derives C from Snapshot's transitive imports; `FvtraceWasm/Build.lean:366–383` compiles + links that set; `Fvtrace/Snapshot.lean:84` calls Evaluate.envelope. Traversal = 16 local modules, no explicit external import (implicit Init), includes Index/Lookups/Answers/Answers.Fast/Present; every closure source byte-equal to `fa7f307`. Generated `Answers/Fast.c` contains `lp_fvtrace_Fvtrace_Answers_fast` (rc 0). Existing Node + Chromium differential tests run the exported engine against native Snapshot.evaluate; fixtures/actions/stacked overrides reach the new fast records.
- Runtime rerun limit: `TMPDIR=.scratch/reviewer-19/tmp FVTRACE_HOME=.scratch/reviewer-19/home node --test tests/engine/engine.test.mjs` **interrupted**, not passed. At 519 s elapsed its worker had 7 s CPU; host load ≈31. CPU starvation = inference from those observations + runnable process state. Changed the earlier wait plan: stopped the optional rerun; parity-suite coverage adjudicated from source, full runtime result left **unconfirmed**. `engine.log`: `Interrupted while running: ⚠ tests/engine/engine.test.mjs`. TaskStop then `ps` on all four observed owned PIDs → no process (rc 1). Full gate, independent-kernel replay + Chromium not rerun. R1.4 `pass` is the fixed review question's source/wiring verdict, not a blanket tests-green claim.
- Tested binary SHA-256 `90c61be06dc083115777fc909f4d08d6e6b17d8ab31cda65c634a070624a5fa7` (= target commit body); built wasm SHA-256 `b76e3ceb6c6444ca547fced8ceb973febb0e79c698f6b155c93325a0ac27fb11`.
- Review writes = this folder only; no target edits/builds/git mutations. Final status shows concurrent edits to tools/compare.sh + tools/scale.sh, outside these verdicts' fixed revision; not this review's writes.

reviewer-19-DONE-1
