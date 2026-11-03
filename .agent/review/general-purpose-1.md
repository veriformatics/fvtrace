# general-purpose-1 — Lean CLI/shell fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
| --- | --- | --- | --- | --- | --- |
| F4 | de05748 | `lake test` @3957c87 + regressions → rc1, unpinned + changed-output stderr hidden (`f4-f8-red.log`) | fast gate: Lean/native/pure/CLI/engine rc0; overall rc1 = baseline e2e lint | both `runReplay` callers use their own failure predicate | fixed |
| F5 | e9be047 | focused @de05748 → looping log = empty history; trace loop = absent; init replaces loop | reached suites 335/335; actual loop rc2 + absent rc0 | all `pathExists` guards in CLI/Store + Session repaired; Receipt unavailable-evidence → stale retained | fixed |
| F6 | unknown | unknown | unknown | unknown | unknown |
| F7 | b736102 | new/moved corpus + original schema → rc1, five Node failures (`f7-red.log`) | Node corpus rc0; reached Schema + Assets green; embedded-schema `cmp` rc0 | 18 defs; 66,588 Unicode + 10,045 decimal boundary/sample controls pass (finite) | fixed |
| F8 | de05748 + 5f09c9c | Replay @3957c87 → 30/33 (2–4-byte cuts lost); @de05748 → 32/33 (orphan byte hidden) | refined replay suite 33/33 | retain 3 look-behind bytes; trim only a validated scalar spanning the 4 KiB cut; invalid tail keeps marker | fixed |
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
- F6 ruling applied: neutral message + exact expectation update; WF rule/path/violation structure unchanged. Trust audit = 26 claims, 0 findings; P1 + P2 fingerprints changed and re-pinned.
- F18 ruling applied: refuse `claims --question Q --json`; retain `eval --json` as an accepted alias.
- F20 sweep pending MAIN: unknown action refusal follows computed `v0` but carries no view; recommend the same tagging rule as item refusals.
- Batch final fast gate `--e2e` pending; baseline lint repair e1fbcf7 cherry-picked as 3accd0c. Engine changes from `5a773067…` to `be364bd7…` through F6: no engine skip claim.

Logs + focused-runner input: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-1/`.
LSP: `.lean` unavailable; direct source/caller reads + compiler used.
