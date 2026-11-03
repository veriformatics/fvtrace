# general-purpose-1 — Lean CLI/shell fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
| --- | --- | --- | --- | --- | --- |
| F4 | de05748 | `lake test` @3957c87 + regressions → rc1, unpinned + changed-output stderr hidden (`f4-f8-red.log`) | fast gate: Lean/native/pure/CLI/engine rc0; overall rc1 = baseline e2e lint | both `runReplay` callers use their own failure predicate | fixed |
| F5 | e9be047 | focused @de05748 → looping log = empty history; trace loop = absent; init replaces loop | reached suites 335/335; actual loop rc2 + absent rc0 | all `pathExists` guards in CLI/Store + Session repaired; Receipt unavailable-evidence → stale retained | fixed |
| F6 | 9fdf8dc | focused @de05748 → failure receives success-only verified-status advice | reached 335/335 incl Check; all targets build; trust audit 26 claims/0 findings; P1+P2 replays re-pinned | one neutral outcome diagnostic; WF rules/paths/proofs unchanged | fixed |
| F7 | b736102 | new/moved corpus + original schema → rc1, five Node failures (`f7-red.log`) | Node corpus rc0; reached Schema + Assets green; embedded-schema `cmp` rc0 | 18 defs; 66,588 Unicode + 10,045 decimal boundary/sample controls pass (finite) | fixed |
| F8 | de05748 + 5f09c9c | Replay @3957c87 → 30/33 (2–4-byte cuts lost); @de05748 → 32/33 (orphan byte hidden) | refined replay suite 33/33 | retain 3 look-behind bytes; trim only a validated scalar spanning the 4 KiB cut; invalid tail keeps marker | fixed |
| F11 | 839ba01 | focused @de05748 → plan loses `[what-if, draft, if … runs]` | reached 335/335; actual prospective C3 line = claims line | one shared `claimLine` renderer, two callers | fixed |
| F12 | bfaa353 | focused @de05748 → 245-byte basename gives 258-byte entry; init rc2 | reached 335/335; actual short/long/Unicode init + scheme checks pass | sole entry constructor; ≤242-byte prefix +13-byte suffix; old names unchanged | fixed |
| F14 | 1a7e8a8 | CLI smoke + removed cwd @3957c87 → rc1/uncaught exception | same smoke rc0; `fvtrace: …` + rc2 | one shared `withIOErrors` wraps both entry points, including Env.detect | fixed |
| F15 | 716a4b7 | original atomic writers leave temporaries; cleanup masks original error; original link leaves response file on ENOSPC (7/8) | final Wasm writer suite 8/8; reached CLI writer green; actual HTML-export failure leaves no temporary | both replacement writers + link response-file write guarded; shared Build cleanup preserves original error | fixed |
| F16 | 041c6a8 | focused @de05748 → `schema ARG` misnames the valid command | reached 335/335; actual schema extra-argument rc2 + named token | schema dispatch keeps valid command identity | fixed |
| F17 | 8264349 | focused @de05748 → listing rows omit reasons | reached 335/335; actual 12-row listing has `reasons: []` | single row builder; run branch unchanged | fixed |
| F18 | 041c6a8 | focused @de05748 → foreign/unresolved question + ignored JSON filter failures | reached 335/335; actual refusals + retained `eval --json` alias pass | all Args.Spec flags traced; question is claims-only; known question+JSON refused per MAIN | fixed |
| F20 | f990285 | Server @716a4b7 → 17/22; action + four item refusals lose view headers | 22/22 native server checks; actual item+action 400s keep envelope view; server stopped + port refused | one `Reply.withView`; action uses `v0`, item uses final view; T1 receipts refreshed | fixed |

## Needs MAIN

- Fast gate baseline blocker: `tests/e2e/access.spec.js:160:14` → `eslint(no-await-in-loop)`; file outside allowlist. `f4-f8-green.log`: all other stages pass; engine 676.7s, total 802.8s. Gate skipped tools, trust, c-analyze, vendor, audit, secrets, workflows, e2e.
- F6 ruling applied: neutral message + exact expectation update; WF rule/path/violation structure unchanged. Trust audit = 26 claims, 0 findings; P1 + P2 fingerprints changed and re-pinned.
- F18 ruling applied: refuse `claims --question Q --json`; retain `eval --json` as an accepted alias.
- F20 ruling applied: invalid-action refusal tagged with `v0`, item refusal with the final view, one shared `Reply.withView`; dedicated native case added.
- All 13 assigned rows committed; worktree HEAD `9fdf8dc`. Full fast gate `--e2e` runs on that committed state (background `bjruoxtp3`); baseline lint repair e1fbcf7 cherry-picked as 3accd0c. Engine changes from `5a773067…` to `be364bd7…` through F6: no engine skip claim.
- Final preflight: 189 build jobs/targets pass; trust audit 26 claims/0 findings; actual app smoke 25 CLI invocations + live item/action refusals pass; PID 2005519 stopped and port refused. Independent-kernel replay + full gate remain MAIN's integration check.

Logs + focused-runner input: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-1/`.
LSP: `.lean` unavailable; direct source/caller reads + compiler used.
