# reviewer-22 — C-gate @ 48bc51d

Check set = Correctness × M-gate; contract + evidence bar = BRIEF.md + lead brief. Read-only frozen base; probes/copies only under reviewer-22 scratch. No full gate, full gate-probe or mutation campaigns.

| row | target | verdict | basis |
|---|---|---|---|
| C-gate | gate.sh (stages, shards, rc, timings) | pass | Read every stage + gate.yml; ran fanout/spec/meta + stage-controls rc 0 (failure retained, later stage runs, rc/timing lines emitted). Full gate reserved to MAIN. |
| C-gate | fast-gate.sh + ci-gate.sh | pass | Read both; wrapper-controls.py rc 0: fast parallel/build failure propagation + completion + --e2e/skips; CI watcher success/failure + branch delete iff green using local command stand-ins, no remote calls. |
| C-gate | gate-probe.sh (plant, cause, restore, re-hash) | reviewer-22-F4 | Read every plant + helper; 18 selected lightweight controls passed + copy clean after restore. Invalid requested name gives zero-check green. Full probe set reserved to MAIN. |
| C-gate | trust.sh + statement.sh + TrustMain.lean | reviewer-22-F1, reviewer-22-F2 | Read dependency walks, axioms, fingerprint, replay policy/key; cache + replay-policy controls passed; two planted claim/closure holes accepted by audit (both red witnesses carry positive controls). |
| C-gate | mutate.mjs | reviewer-22-F5 | Read all operators/ranges/masking/restore/child classifications; --list on valid Lean raw-string fixture misclassifies data as code; no campaign ran. |
| C-gate | fetch-tools / pin-tool / install-lean / vendor-hacl + tools.lock | reviewer-22-F3 | Read all scripts + 17 lock entries; cached fetch/vendor + planted half bump/extra file controls passed. Extracted exact bounded function fails enforced-deadline test; no download/install. |
| C-gate | lean-style.sh + spec-lint + e2e-load.sh | reviewer-22-F6 | Style/spec baselines + planted violations passed; e2e-load measure 0 with stand-in leaks sampler/child on TERM. No load generated. |
| C-gate | test harness (Tests.lean, Harness, TestMain, TestPure) + lakefile.lean | reviewer-22-F7 | Harness smoke rc 0 (exception/continuation/timings/rc); embed needs fit. Later Lake buildO callee inspection + red C-header witness reverses the initial pass: incremental native objects omit header dependencies. |
| C-gate | configs | pass | Read every named config: strict checkJs scopes, lint/format roots, Playwright timeout + bundled Chromium default, pins, LF checkout + ignored output paths fit callers. |

## Findings

### reviewer-22-F1 — major — Prop aliases hide unproved claims

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/TrustMain.lean:84`.
- Contract: `.claude/rules/lean.md` Layout — every Prop-valued Spec definition is a claim; an unproved claim fails `fvtrace-trust`.
- Defect: syntactic `d.type == .sort .zero` omits a definition whose type is a reducible alias of `Prop`. The alias does not change the claim's meaning, but the claim disappears from the audited set + exported proof list.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-22/red-trust-alias.py` → rc 1. Output: `positive control: direct Prop claim rejected (rc=1)`; `audit rc=0`; `trust: 26 claims, 0 findings`; `AssertionError: FAIL: Prop-valued unproved definition hidden by a reducible Prop alias passes the claim audit`.
- Plant (copy only): `abbrev PlantedProp := Prop`; `def PlantedUnproved : PlantedProp := Fvtrace.version = "planted"`. Same definition with literal `Prop` fails as required. Both inputs build; script restores + rebuilds the original copy.
- Fix direction: classify declaration types after definitional reduction to `Prop`; add a planted alias probe.

### reviewer-22-F2 — minor — proof closure omits inductive constructors

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/TrustMain.lean:109`.
- Contract: `.claude/rules/lean.md` Layout — an `opaque` in a proof's statement closure fails the audit.
- Defect: the escape-hatch walk uses `type + value?` for every declaration. An inductive's constructors live in `.inductInfo.ctors`, not its type/value. The separate `meaningDeps` walk includes those constructors, but the escape-hatch walk does not.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-22/red-trust-constructors.py` → rc 1. Output: `audit rc=0`; `claim Fvtrace.Spec.PlantedCtorEscape: Fvtrace.Proofs.plantedCtorEscape`; `trust: 27 claims, 0 findings`; `AssertionError: FAIL: opaque type reachable through an inductive constructor is omitted from the audited proof closure`.
- Plant (copy only): opaque `PlantedHidden : Type`; inductive `PlantedBox.wrap : PlantedHidden → PlantedBox`; claim quantifies over `PlantedBox` + mentions `Fvtrace.version`. Constructor → opaque type is a statement dependency; audit accepts. Both new files build; script restores + rebuilds the original copy.
- Fix direction: use one semantic dependency function that includes inductive constructors in both walks.

### reviewer-22-F3 — minor — installer bound waits forever after TERM

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/install-lean.sh:24-25`.
- Contract: `.claude/rules/ops.md` CI — each Lean-install attempt ≤ 180 s; Correctness error paths + resource cleanup.
- Defect: `bounded` sends TERM to one PID, then waits without a deadline or kill escalation. An installer that ignores TERM never returns; retry/bounded semantics stop working. The workflow's separate 10-minute timeout remains, so the entire CI job is still externally bounded.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-22/red-install-bound.py` → rc 1. Exact base function, `attempt_secs=1`: `positive control: child exit 7 propagates`; `positive control: TERM-responsive child returns 124 at 1 s bound`; `FAIL: bounded(attempt_secs=1) remains blocked after 4 s when the installer ignores TERM`; assertion `per-attempt bound is not enforced; wait has no deadline or SIGKILL escalation`.
- Scope: simulated stalled process only; no download/install. Test kills its whole process group in `finally`.
- Fix direction: own + reap the command's process tree; bound TERM grace + escalate to KILL.

### reviewer-22-F4 — minor — misspelled probe reports zero-check green

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/gate-probe.sh:486`.
- Contract: `.claude/rules/ops.md` Probes — requested probes run their owning checks; CLAUDE.md Engineering — a check that runs nothing is not verification.
- Defect: dispatch discards the `probe_$p` exit status. A nonexistent name prints `command not found`, but never enters `failures`; the final empty-failure test returns 0. A typo therefore appears to verify a positive control without running one.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-22/red-probe-name.py` → rc 1: `probe wrapper rc=0`; `probes: 0 passed, 0 failed`; `tools/gate-probe.sh: line 486: probe_definitely_not_a_probe: command not found`; `AssertionError: FAIL: a misspelled requested probe runs zero checks and reports success`.
- No real probe/full gate runs in this test.
- Fix direction: validate names before dispatch; record unexpected dispatch failure.

### reviewer-22-F5 — minor — mutation masker treats raw-string text as code

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/mutate.mjs:90` (`protectedMask`).
- Contract: mutation tool's own operator contract, `tools/mutate.mjs:7`: `Comments, strings + chars are never mutated.`; `.claude/rules/lean.md` Mutation credit — operators act on Lean code sites.
- Defect: every `"` toggles ordinary-string state; Lean raw strings (`r#"…"#`) may contain unescaped quotes. Text between those quotes becomes comparison/boolean/integer mutants. This changes data literals outside the documented operators and produces spurious campaign sites/credit.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-22/red-mutate-strings.py` → rc 1. Lean accepts the fixture; real code `true` is listed; source bytes are restored. Raw-string text also lists `true → false`, `false → true`, `101 → 102`, `< → <=`; `mutants: 5` rather than the single code boolean. Assertion: `FAIL: raw-string contents are reported as comparison/boolean/integer mutation sites`.
- Only `--list` ran; no mutation campaign. Nested string literals inside interpolation also occur in the shipped `FvtraceWasm/Build.lean:230-231`; tokenizer review must cover that syntax too.
- Fix direction: tokenize Lean string forms + interpolation accurately before assigning operator sites.

### reviewer-22-F6 — minor — interrupted load harness leaves its work alive

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/e2e-load.sh:29-39` (same ownership gap in `gate`).
- Contract: CLAUDE.md Engineering Correctness — test setup/teardown symmetric + resource cleanup; tool launches busy loops + a sampler it must own until completion.
- Defect: normal completion kills the sampler/busy-loop PIDs, but `measure`/`gate` has no EXIT/TERM cleanup. An interrupted run leaves background work alive; a real nonzero-hog run can continue loading the host after its parent exits.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-22/red-load-cleanup.py` → rc 1: `positive control: measure reached Playwright + started its sampler with zero busy loops`; `measure parent rc=-15; Playwright descendant alive=True; sampler alive=True`; `AssertionError: FAIL: interrupting e2e-load measure leaves its background work running; no EXIT/TERM cleanup owns the sampler or busy loops`.
- Actual base script in own copy, `measure 0`, blocked Playwright stand-in; no CPU load generated. The test observes its child PIDs, then kills its whole process group in `finally`.
- Fix direction: one signal-safe cleanup owner + traps for all child processes in both modes.

### reviewer-22-F7 — minor — native C objects do not trace their headers

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/lakefile.lean:105-110`.
- Contract: CLAUDE.md Engineering Correctness — builds run current code; Execution — the incremental fast gate reaches changed inputs. Native HACL* + shim compile with the vendored headers, not only their `.c` files.
- Defect: both `buildO` jobs trace their source alone; the includes are weak arguments + no header `extraDepTrace`. Lake's `buildO` does not discover headers automatically (`/opt/lean/src/lean/lake/Lake/Build/Common.lean:843`). A header-only vendor update reuses stale native objects. Fresh CI builds are unaffected; this is an incremental/local-build defect.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-22/red-c-header.py` → rc 1: `positive control: direct C compile rejects the included header with REVIEWER_22_HEADER_MUST_REBUILD`; `lake build fvtracec rc=0`; `Build completed successfully (2 jobs).`; `AssertionError: FAIL: lake build reuses the C objects after an included vendored header changes; headers are absent from buildO dependency traces`.
- Plant: `#error REVIEWER_22_HEADER_MUST_REBUILD` appended to own copy's `c/hacl/Hacl_Hash_SHA2.h`; direct shim compilation sees it, Lake does not. Script restores the header + rebuilds. This witness tests the build target, not vendor verification (which correctly refuses the unpinned plant).
- Fix direction: trace the vendored header tree + Lean FFI-header/toolchain dependency for both native object jobs.

## Register

None.

## Coverage + limits

- Read every named M-gate target + binding rules; additional callees: gate.yml, Lake buildO/compileO, FvtraceWasm/Build string site. Security-specific review remains MAIN's scope.
- Ran: 18 selected probes (`lean_style`, `fanout`, `meta`, `replay_policy`, `trust_cache`, `vendor`) → 18 pass / 0 fail; mechanical-controls.py → rc 0; wrapper-controls.py → rc 0; FFI-free harness smoke → rc 0; cached tool fetch + offline vendor verification → rc 0; 7 red witnesses → rc 1 each with the named failing assertion. All plants restore their owned copy.
- Not run here: full gate, full probe set, real fast-gate build/suite chain, live CI wrapper, independent-kernel replay, self-trace replays, mutation campaigns, fresh network fetch/re-pin/install, loaded-host run. These integrations remain MAIN baseline work; conclusions outside the listed read/controls are unconfirmed.
- Mutation build/test timeout classification + signal restoration were read, not executed (campaign boundary). Configs adjudicated by source/caller consistency, not fresh whole-tool runs.
- Shared base + primary source/config/law remain untouched; only this deliverable + reviewer-22 scratch written. No server started. Own-copy `git status --porcelain` = empty (rc 0) after restoration.

reviewer-22-DONE-1
