# general-purpose-1 — Lean CLI/shell fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
| --- | --- | --- | --- | --- | --- |
| F4 | de05748 | `lake test` @3957c87 + regressions → rc1, unpinned + changed-output stderr hidden (`f4-f8-red.log`) | fast gate: Lean/native/pure/CLI/engine rc0; overall rc1 = baseline e2e lint | both `runReplay` callers use their own failure predicate | fixed |
| F5 | unknown | unknown | unknown | unknown | unknown |
| F6 | unknown | unknown | unknown | unknown | unknown |
| F7 | unknown | unknown | unknown | unknown | unknown |
| F8 | de05748 | same red → valid UTF-8 tail = `(not UTF-8)` | same gate: regression + invalid-byte control pass | one tail decoder; discard ≤3 leading continuation bytes only after a byte cut | fixed |
| F11 | unknown | unknown | unknown | unknown | unknown |
| F12 | unknown | unknown | unknown | unknown | unknown |
| F14 | unknown | unknown | unknown | unknown | unknown |
| F15 | unknown | unknown | unknown | unknown | unknown |
| F16 | unknown | unknown | unknown | unknown | unknown |
| F17 | unknown | unknown | unknown | unknown | unknown |
| F18 | unknown | unknown | unknown | unknown | unknown |
| F20 | unknown | unknown | unknown | unknown | unknown |

## Needs MAIN

- Fast gate baseline blocker: `tests/e2e/access.spec.js:160:14` → `eslint(no-await-in-loop)`; file outside allowlist. `f4-f8-green.log`: all other stages pass; engine 676.7s, total 802.8s. Gate skipped tools, trust, c-analyze, vendor, audit, secrets, workflows, e2e.
- F6: existing `Tests/Check.lean` exact success-message expectation must change for the requested shared neutral message; awaiting MAIN's authorization under FIXER law.
- F18 sweep: `eval --json` = undocumented no-op; `claims --question Q --json` = ignored filter (V-cli projection contract). Awaiting MAIN's ruling on refusing the combination.

Logs + focused-runner input: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-1/`.
LSP: `.lean` unavailable; direct source/caller reads + compiler used.
