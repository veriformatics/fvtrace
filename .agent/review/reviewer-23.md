# reviewer-23 — C-gate at 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-gate | gate.sh (stages, shards, rc, timings) | pass | Every stage + caller read; STAGES ↔ gate.yml matched; sourced stage(rc 17) followed by stage(rc 0) retained the failure + printed both timings; fanout rc 0. |
| C-gate | fast-gate.sh + ci-gate.sh | unknown | unknown |
| C-gate | gate-probe.sh (plant, cause, restore, re-hash) | reviewer-23-F1 | Every plant/expected cause + restore path read; dispatcher ignores an unexecuted probe's rc (red-probe-selection.sh rc 1). Full probe suite reserved to MAIN. |
| C-gate | trust.sh + statement.sh + TrustMain.lean | unknown | unknown |
| C-gate | mutate.mjs | unknown | unknown |
| C-gate | fetch-tools / pin-tool / install-lean / vendor-hacl + tools.lock | unknown | unknown |
| C-gate | lean-style.sh + spec-lint + e2e-load.sh | unknown | unknown |
| C-gate | test harness (Tests.lean, Harness, TestMain, TestPure) + lakefile.lean | unknown | unknown |
| C-gate | configs | unknown | unknown |

## Findings

### reviewer-23-F1 — minor — probe dispatch can report success without running its requested probe

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/gate-probe.sh:486`.
- Contract: ops.md Probes (`[probe…]`, each requested probe plants input + demands its cause); Correctness (exit codes retained); Engineering (`green` names checks run + passed).
- Cause: `for p …; do "probe_$p"; done` discards command/function failure; only failures accumulated inside `expect`/`allow` affect the final rc. A misspelled selection runs no check, prints `0 passed, 0 failed`, returns 0.
- Red: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-23/red-probe-selection.sh` → rc 1:

```text
…/tools/gate-probe.sh: line 486: probe_definitely_not_a_probe: command not found
probes: 0 passed, 0 failed
actual rc=0; expected nonzero for an unexecuted probe
FAIL: an unrecognized probe was not run but the probe runner returned success
```

- Fix: validate selections before dispatch + propagate a selected probe's nonzero rc; preserve all-probes execution + final summary.

## Coverage

Read-only base; own scratch for planted inputs. Full gate + full probes + mutation campaigns reserved to MAIN.
