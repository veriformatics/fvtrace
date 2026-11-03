# reviewer-41 — V-lean-shell @ 48bc51d

Check set fixed: verification integrity per BRIEF.md + LENSES.md § V; target tests vs kernel.md Receipts / Replay / V-* / E-*, README Commands / exit codes, server.md. Target read-only; probes + copies under `.scratch/review/reviewer-41/`.

| row | target | verdict | basis |
|---|---|---|---|
| V-lean-shell | Receipt + Replay + Notices tests | pass (known F4/F5/F8/F17 gaps) | Contract-derived file/receipt metamorphisms, raw stdout hash, opt-in marker, notice outcome × prior-notice matrix, concurrent/log/write-refusal boundaries; existing F4/F5/F8/F17 remain uncaught. Native baseline 1834/1834. |
| V-lean-shell | Evaluate + Snapshot tests | pass | Counts/flags/ordering expected from S-state + V-env; snapshot same-definition parity legitimately checks E-request transport + state transparency, supplemented by fixed expected counts/labels + malformed shapes. Native baseline 1834/1834. |
| V-lean-shell | Cli + CliStore + Args + Assets tests | reviewer-41-F2; known F13/F18 | CLI projection expectations call the production projector + key list; deleting contract-required `trace` leaves native suite 1834/1834. Skill refusal rc 1 + nonexistent-question silent filtering meet already-recorded F13/F18. Args and Assets fixed vectors/embed equality otherwise hold. |
| V-lean-shell | Server tests | pass (known F19/F20 gaps) | Fixed status/body-cap/request-shape/rehash/view expectations + CLI-byte parity; injected I/O fault runs on root/Windows too. Native baseline 1834/1834. Base tests do not pin F19 framing or F20 refused-item view header. |
| V-lean-shell | Export + Wasm tests | reviewer-41-F3 | Export RFC base64 vectors, independent text expectations, snapshot/session byte parity + bundle round trip hold. Wasm good fixtures + expected lengths reuse production contract lists; deleting required `fvtrace_load` leaves pure Wasm suite 56/56 green while a missing-load module passes the checker. |
| V-lean-shell | tests/cli/smoke.sh (incl. the empty-folder lead) | reviewer-41-F1 | Exact source predicate tested: added file → rc 1; added empty directory → rc 0. Full smoke not rerun; the exact unchanged-folder predicate is sufficient for this witness and needs no server. |
| V-lean-shell | wiring + history | pass | All target entry points under Tests.pure/native, TestMain → Tests.all, Lake testDriver, gate lean-test/lean-pure + cli. Every 13-file `git log 48bc51d -p --follow -- FILE` captured (7,203 lines); all 66 deletion hunks adjudicated. Retired v1/ABI cases replaced per V-*/E-state. Guard coverage + history rulings below. |

## reviewer-41-F1 — project write check ignores empty directories

- Severity: minor. Target: `tests/cli/smoke.sh:25`, `:175-176` @ `48bc51d`.
- Contract: Decisions Product (no write into the project except explicitly directed) + ops.md `cli` stage (“nothing written outside the data folder”) + CLAUDE.md Engineering Verification integrity (a purpose-built check fires on its planted bad input).
- Fault: inventory consists only of `sha256sum` stdout. Directory names print errors on suppressed stderr, contribute no stdout and so disappear from both inventories. Adding an empty directory passes `project folder unchanged`.
- Anchor: `find . -print0 | sort -z | xargs -0 sha256sum 2>/dev/null` (both snapshots).
- Red command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-41/red-smoke-folders.py` → rc 1. The driver executes the exact `before`, `after`, `expect` lines + `expect()` from the base, in private temporary folders.

```text
positive control: added file detected, rc=1 (expected 1)
added empty directory: unchanged-folder check rc=0 (expected 1)
AssertionError: FAIL: smoke project-integrity predicate accepts an added empty directory
```

- Fix direction: inventory entry paths + types as well as file digests; ship an empty-directory planted-write probe beside the existing file-write control.

## reviewer-41-F2 — CLI projection oracle reuses the implementation

- Severity: minor. Target: `Tests/CliStore.lean:137-145` @ `48bc51d`.
- Contract: kernel.md V-cli lists each projection's exact mandatory members (`schema`, `mode`, `overrides`, `trace`, then its command's members); CLAUDE.md Engineering Verification integrity: expected values come from the contract, not the code being graded.
- Fault: production handlers use `Cli.project … Cli.projectionKeys`; the expected side calls the same projector with the same production `Cli.projectionKeys`. A shared omitted key is graded correct. Later review-digest equality (:222) compares two absent values when `trace` disappears, so it also passes.
- Anchors: `(Cli.projectionKeys ++ keys))) out` (:138); `some (fields (Cli.project envelope Cli.projectionKeys) ++` (:144).
- Red command (private copy; restores source in `finally`): `(cd /home/eturkes/Projects/fvtrace && offload run --local -- python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-41/red-projection.py)` → rc 1. Plant: remove only `"trace"` from `Fvtrace/Cli.lean:581`'s `projectionKeys`; incremental `lake build fvtrace fvtrace-tests`; run every native test; drive mutant `claims --json`.

```text
positive control: base claims --json has required trace object
incremental build rc=0
planted implementation: full native suite rc=0; 1834/1834 checks passed
planted claims --json keys=['claims', 'counts', 'mode', 'overrides', 'schema', 'subjects']; trace present=False
AssertionError: FAIL: contract-required trace removed from every CLI projection, yet all native checks pass
```

- Logs: `projection-red.log`, `projection-build.log`, `projection-suite.log`, `projection-output.json` under the scratch directory.
- Fix direction: independently spell V-cli's complete per-command member sets in the tests, derive expected projections independently, assert metadata presence before any equality; the plant must kill the suite.

## reviewer-41-F3 — Wasm link-check fixtures mirror the checker's contract list

- Severity: minor. Target: `Tests/Wasm.lean:31-45` @ `48bc51d`.
- Contract: kernel.md E-build explicitly requires memory + `_initialize`, `fvtrace_init`, `fvtrace_alloc`, `fvtrace_free`, `fvtrace_load`, `fvtrace_answer`; CLAUDE.md Engineering Verification integrity requires a contract-derived oracle.
- Fault: `goodExports` comes from `Binary.requiredExports`, then the expected parsed count comes from that same production list. Positive fixtures shrink with an accidental omission. Negative cases independently remove `fvtrace_answer` and wrong-kind `memory` alone; no contract-owned complete set or per-export negative covers the other required exports.
- Anchors: `def goodExports : List (List UInt8) := Binary.requiredExports.map fun (n, k) => exportOf n k` (:32); `(Binary.allowedImports.length, Binary.requiredExports.length)` (:45).
- Red command (private copy; restores source in `finally`): `(cd /home/eturkes/Projects/fvtrace && offload run --local -- python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-41/red-wasm-oracle.py)` → rc 1. Plant: drop `fvtrace_load` only from `FvtraceWasm/Binary.lean:139`'s `requiredExports`; incremental `lake build Tests.Wasm`; run unmodified `Tests.Wasm.pureTests` interpreted. Probe independently constructs E-build's fixed export set minus `fvtrace_load`.

```text
positive control: unmodified missing-load module
56/56 checks passed (slowest: )
wasm suite rc=0; missing-fvtrace_load problems=["exports no fvtrace_load of kind 0"]
incremental module build rc=0
56/56 checks passed (slowest: )
wasm suite rc=0; missing-fvtrace_load problems=[]
AssertionError: FAIL: checker accepts a missing E-build export while Tests.Wasm.pureTests stays green
```

- Logs / inputs: `wasm-oracle-red.log`, `wasm-oracle-build.log`, `wasm-contract.lean` under the scratch directory.
- Fix direction: independent E-build export fixture + one omitted/wrong-kind case per required export; the plant must kill the suite.

## Evidence / coverage

- Native baseline: `(cd /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-41/tree && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-41/home .lake/build/bin/fvtrace-tests)` through `offload run --local` → rc 0, `1834/1834 checks passed` (`baseline-native.log`).
- Wiring: `Tests.lean:30-69` calls every target test entry; `TestMain.lean:11` → `Tests.all`; `lakefile.lean:13,88` sets/builds testDriver; `tools/gate.sh:79-82` runs `lake test`, interpreted `TestPure.lean`, shell smoke. Baseline native execution proves all target areas ran (no FAIL / no IPv6-skip message).
- History: 13 complete per-file `git log 48bc51d -p --follow -- FILE` logs → 66 deletion hunks in `history-deletions.txt`, all read; wiring history checked separately. Changes = helper centralization, named verdict / must-verify rulings, new default port/token protocol, v1 route retirement, snapshot + Worker schema cutover, obsolete `fvtrace_evaluate` / stateless snapshot hook retirement under E-state, clock-boundary allowance. No dropped target test or time-limit increase found. `c88ecfc` body explicitly records approval for the I/O-plant change + its old firing and new catch-removal witness; the new injected fault runs on every uid/OS.
- Guards: `Replay.lean:142` skips process-group kill on Windows because § Replay explicitly supports process-alone there; single-process timeout still runs. `Cli.lean:193` skips `/dev/null` on Windows; regular-file + exact-size + growing-prefix tests remain; Linux smoke adds FIFO/device/64-GiB binary cases. `Notices.lean:595` POSIX linked-log path test: general path/link behavior remains in cross-platform helper-backed CliStore/Receipt/Export tests (Windows execution not rerun here). `CliStore.lean:178-190` can skip a real `[::1]` refusal when binding fails; pure `Cli.bindTests` uses an injected busy-v6 binder to exercise retry/stop logic, baseline emitted no skip. Smoke's GNU-stat/FIFO/opener block = Linux-only; pure platform opener mapping covers macOS/Windows names, but no Windows/macOS runtime run performed here.
- No nested agents, target mutation, full gate or mutation campaign. Additional probes pending.
