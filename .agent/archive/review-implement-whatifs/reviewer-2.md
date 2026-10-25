# reviewer-2 · U11 · R2 claim soundness · 01cf228^..f3bc87f

Target = `.scratch/worktrees/v1`, HEAD `f3bc87fc549b140558f9a7cff25a7a31d11e6fdf`. Check set fixed before target read. 3/3 rows adjudicated; 1 minor text finding; proof claims pass. Source anchors below = target-relative paths.

| id | check | verdict |
|---|---|---|
| R2.1 | `Spec.AnswersAgree`: extended fields, non-vacuity, shipped call paths, whole domain, docstrings | pass: `Fvtrace/Spec/Fast.lean:37` = unconditional equality of all 37 `Answers` fields for every `Scenario`; reference fields read `Scenario.*`; target-compiled `Coverage.lean` derives envelope/details/action/complete congruence; CLI + server + snapshot consume this fast instance. |
| R2.2 | Proof axioms/escape hatches; new-module + capability coverage; independent replay | pass: target audit = 26 claims / 0 findings; statement closure reaches Forest/Delta/PTree, proof closure reaches Forest/PTree/Walk/Agree/Singleton; 26-root export accepted by all six kernels, axioms exactly `propext`, `Quot.sound`, `Classical.choice`. |
| R2.3 | C9/P10–P12/E9/T1; README verification + Development; kernel guarantees/trusted base | finding: R2-F1. Other checked claims fit: C9/E9 join the three unconditional agreement propositions; T1 remains `tested`; P10–P12 statement hashes match pins; self-trace strict check rc 0, recorded verdicts 7 `can` / 2 `open`; IO/codec/compiled-adapter boundaries remain explicit. |

## Findings

### R2-F1 · minor · README advertises raw byte equality for the format-migration comparison

- Claim/anchor: `README.md:295–296`, exact bytes: `their output differs by one byte, or when a run does not finish in time.`
- Wrong because: with a v1 OLD binary, JSON comparison intentionally removes moved members, changes schema/action/plan shapes, normalizes creator qualifiers, then sorts + reprints JSON. Different raw outputs can pass. Same-v2 comparisons remain byte-level; the unconditional README wording collapses these two guarantees.
- Proof: `tools/compare.sh:68` exact bytes: `# A run whose output form changed: v1 transformed = v2, structurally (jq -S); refusals byte-equal.` Implementation at `:80–83` applies `jq -S "$v1_to_v2 | $creatorless"` to OLD and `jq -S "$creatorless"` to NEW. `:141–144` selects raw comparison only when OLD already emits v2. Both anchors matched the target; README anchor also rematched with `git show f3bc87f:README.md` (rc 0).
- Contract: `kernel.md` V-cli explicitly defines transformed JSON equality **structurally**, unchanged text byte-for-byte; R2.3 requires Development's description to say what the tool establishes.
- Fix: name both modes: unchanged-format output byte-equal; v1→v2 JSON compared after the declared transform, with moved lists checked through details/action oracles. Keep the timeout promise only after the R2-X1 gate defect is addressed.
- Acceptance: README comparison sentence distinguishes raw equality from v1→v2 structural comparison; no theorem or grading change required for this wording fix.

## Register · outside R2's behavioral check set

### R2-X1 · R4 lead · v1 JSON comparison accepts matching timeouts

- Target: `tools/compare.sh:69–94` (`cmp_json`); contract P-evidence requires every timeout to fail. Unlike `cmp_run`, `cmp_json` never increments `timeouts` for rc 124. Two timed-out processes with matching partial stdout/stderr/rc therefore contribute zero differences + zero timeouts to the final success predicate.
- Red test = `.scratch/reviewer-2/compare-timeout.sh`; sources the exact target `cmp_run`/`cmp_json` functions, points them at a 1 s sleeper under a 0.05 s deadline. No target edits. Command:
  `bash .scratch/reviewer-2/compare-timeout.sh .scratch/worktrees/v1 .scratch/reviewer-2`
- Observed rc 1 (`compare-timeout.log`):
  ```text
  CONTROL PASS: cmp_run counted 2 timed-out processes
  cmp_json: runs=1 diffs=0 timeouts=0 old=rc=124 new=rc=124
  FAIL: matching timeouts satisfy compare.sh final success predicate
  ```
- Scope: function-level witness, not a full `compare.sh` campaign. MAIN notified for the R4 ruling. Also static/unconfirmed: v1 `oracles` at `:97–113` invokes binaries without the runner's deadline; no hanging full-script witness run.
- Acceptance: the v1 runner counts/rejects each rc 124, and action/details oracles use the same deadline + exit-status discipline; planted matching-timeout case fails the comparator.

## Verification + limits

- Diff read in full for every brief-named path; Spec/Fast + Spec/Engine, contract P-* / Outcome guarantees / Trusted base, owning rules, reference/fast records, proof dependency graph + affected consumer call sites read. No behavior finding against the proved functions.
- `Coverage.lean` + `coverage.log`: `lake env lean .scratch/reviewer-2/Coverage.lean` from target, rc 0. Unconditional port equalities kernel-checked; closure coverage positive in each named module.
- `trust-audit.log`: from target, `LEAN_PATH=<target>/.lake/build/lib/lean .lake/build/bin/fvtrace-trust --proofs <review>/proofs.txt`, rc 0. Bare binary first failed to find `Fvtrace`; setting its import path corrected invocation, not target code.
- `replay-run.log` + `kernel-replay.log`: `lake env leanexport Fvtrace -- <26 proof roots>` → `lake check --from-export=<review>/export.ndjson --paranoid` through `offload run --local`; export rc 0, kernel rc 0, target `replay_policy` rc 0. Lean default/paranoid, lean4lean, nanoda, con-leche, con-ron all accepted; none declined/skipped.
- Source escape scan over all Proofs + Answers + PTree: positive control expected 1 / actual 1 / rc 0; target 0 matches / rc 1. Runtime audit, not this lexical scan, decides axiom + escape-hatch acceptance.
- P10/P11/P12 fingerprints: `fvtrace-trust --statement` on target build, each rc 0; sha256 exactly equals its self-trace replay pin. `self-check.log`: native `check --strict`, rc 0. `self-claims.json`: native `claims --json`, rc 0; C9 `can`, C2/C7 `open`, six other claims `can`.
- Limits: target's supplied prebuilt `.olean`/binaries used; no rebuild (read-only brief). Full gate, scale, browser/wasm differential + complete comparison campaigns not rerun; their separate lenses own them. `tools/trust.sh`/`tools/statement.sh` not invoked wholesale because they build/write in target; their read-only audit/export/replay/fingerprint operations ran separately. Lean LSP unavailable; source + compiled checks used. T1 assessed for claim/status boundary, not a duplicate server security audit.
- Target tracked files unchanged; initial/final untracked entry remains `node_modules`. No commits, pushes, installs, contract or instruction edits.

reviewer-2-DONE-1

## Re-review (c930c8c)

Target = `c930c8cca09798463db5263cf92fbdb62107df28`, same read-only worktree. Fixed scope = R2-F1's ledger acceptance (`README names both modes`) + the requested R2-X1 `cmp_json` timeout witness; other rows not reopened.

| id | acceptance | verdict | evidence |
|---|---|---|---|
| R2-F1 | README names same-format byte equality + earlier-format translated structural comparison | pass: fixed c930c8c | `README.md:297–299`: `format must be equal byte for byte. When the older program prints the earlier evaluation` + `format, the tool first translates that output to the current format and then compares the` + `structure.`; both distinctive anchors match working bytes and `git show c930c8c:README.md`, rc 0. |
| R2-X1 | Matching rc-124 processes in the v1 `cmp_json` path invalidate comparison success | pass: requested witness fixed c930c8c | Same deadline + assertions: control detects 2 timeouts; `cmp_json: runs=1 diffs=0 timeouts=2 old=rc=124 new=rc=124`; `PASS: comparison rejects matching timeouts`, witness rc 0. Adapted witness remains red on f3bc87f (timeouts=0, rc 1). |

- Command: `bash .scratch/reviewer-2/compare-timeout.sh .scratch/worktrees/v1 .scratch/reviewer-2`.
- Harness adjustment only: source the target's new `run_one` helper before its exact `cmp_run`/`cmp_json` functions. Initial unchanged harness returned rc 2 (`run_one: command not found`, control failure), not a product failure. No assertion/threshold changed. Corrected rerun rc 0; same corrected harness against f3bc87f's extracted script rc 1.
- Logs: `.scratch/reviewer-2/compare-timeout-c930c8c.log`, `.scratch/reviewer-2/compare-timeout-f3bc87f-control.log`; initial harness failure retained in `compare-timeout-c930c8c-harness.log` beside them.
- Coverage limit: exact-function timeout witness + README anchors only; full comparison campaigns, oracle-path runtime checks, proofs + gates not rerun. Target tracked files unchanged (`node_modules` remains the pre-existing untracked entry); baseline extraction removed; no commits, builds or installs.

reviewer-2-DONE-2
