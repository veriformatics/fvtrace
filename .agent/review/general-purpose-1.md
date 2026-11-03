# general-purpose-1 — Lean CLI/shell fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
| --- | --- | --- | --- | --- | --- |
| F4 | de05748 | `lake test` @3957c87 + regressions → rc1, unpinned + changed-output stderr hidden (`f4-f8-red.log`) | replay 33/33; actual stderr-tail cases + closing native/pure/engine stages pass | both `runReplay` callers use their own failure predicate | fixed |
| F5 | e9be047 | focused @de05748 → looping log = empty history; trace loop = absent; init replaces loop | reached suites 335/335; actual loop rc2 + absent rc0 | all `pathExists` guards in CLI/Store + Session repaired; Receipt unavailable-evidence → stale retained | fixed |
| F6 | 9fdf8dc | focused @de05748 → failure receives success-only verified-status advice | reached 335/335 incl Check; all targets build; trust audit 26 claims/0 findings; P1+P2 replays re-pinned | one neutral outcome diagnostic; WF rules/paths/proofs unchanged | fixed |
| F7 | b736102 | new/moved corpus + original schema → rc1, five Node failures (`f7-red.log`) | Node corpus rc0; reached Schema + Assets green; embedded-schema `cmp` rc0 | 18 defs; 66,588 Unicode + 10,045 decimal boundary/sample controls pass (finite) | fixed |
| F8 | de05748 + 5f09c9c | Replay @3957c87 → 30/33 (2–4-byte cuts lost); @de05748 → 32/33 (orphan byte hidden) | refined replay suite 33/33 | retain 3 look-behind bytes; trim only a validated scalar spanning the 4 KiB cut; invalid tail keeps marker | fixed |
| F11 | 839ba01 | focused @de05748 → plan loses `[what-if, draft, if … runs]` | reached 335/335; actual prospective C3 line = claims line | one shared `claimLine` renderer, two callers | fixed |
| F12 | bfaa353 | focused @de05748 → 245-byte basename gives 258-byte entry; init rc2 | reached 335/335; actual short/long/Unicode init + scheme checks pass | sole entry constructor; ≤242-byte prefix +13-byte suffix; under-bound names unchanged | fixed |
| F14 | 1a7e8a8 | CLI smoke + removed cwd @3957c87 → rc1/uncaught exception | same smoke rc0; `fvtrace: …` + rc2 | one shared `withIOErrors` wraps both entry points, including Env.detect | fixed |
| F15 | 716a4b7 | original atomic writers leave temporaries; cleanup masks original error; original link leaves response file on ENOSPC (7/8) | final Wasm writer suite 8/8; reached CLI writer green; actual HTML-export failure leaves no temporary | both replacement writers + link response-file write guarded; shared Build cleanup preserves original error | fixed |
| F16 | 041c6a8 | focused @de05748 → `schema ARG` misnames the valid command | reached 335/335; actual schema extra-argument rc2 + named token | schema dispatch keeps valid command identity | fixed |
| F17 | 8264349 | focused @de05748 → listing rows omit reasons | reached 335/335; actual 12-row listing has `reasons: []` | single row builder; run branch unchanged | fixed |
| F18 | 041c6a8 | focused @de05748 → foreign/unresolved question + ignored JSON filter failures | reached 335/335; actual refusals + retained `eval --json` alias pass | all Args.Spec flags traced; question is claims-only; known question+JSON refused per MAIN | fixed |
| F20 | f990285 | Server @716a4b7 → 17/22; action + four item refusals lose view headers | 22/22 native server checks; actual item+action 400s keep envelope view; server stopped + port refused | one `Reply.withView`; action uses `v0`, item uses final view; T1 receipts refreshed | fixed |

## Verification

- Branch `wt/general-purpose-1`, HEAD `eea115f`; 13/13 assigned rows written + committed. Format-only closing commit wraps three lines from F14/F18/F20 + refreshes T1's test receipt. Worktree status rc0, 0 entries; positive control = HEAD names 4 changed files.
- Preflight: every requested target built (189 Lake jobs); `lake exe fvtrace-trust` → `26 claims, 0 findings`. Plain standalone trust binary lacked Lake's import path; corrected to the recorded Lake invocation. P1 + P2 replays failed before their intended message-closure re-pin (`10 of 12 replay(s) passed`, rc1); `pin --replay` + strict self-check then pass. T1 Server/test artifact hashes re-pinned.
- Live app: 25 CLI invocations + real item/action 400 responses pass; final server PID 2005519 stopped + its port refused. CLI includes prospective plan labels, every argument refusal, listing reasons, log-loop/absent distinction, long names, failed HTML export, 2–4-byte UTF-8 cuts + orphan/invalid-byte tails.
- First fast gate: rc1 = base `access.spec.js:160` lint alone; MAIN's e1fbcf7 cherry-picked as 3accd0c. First closing `--e2e` at 9fdf8dc: rc1 = three width violations alone; all functional stages + 59/59 e2e pass (`final-fast.log`). Width fixes pass `tools/lean-style.sh` + landed in eea115f.
- Closing `bash tools/fast-gate.sh --e2e` at eea115f: **rc1, not green**, one external e2e failure below; every other stage rc0. `1882/1882` native + `799/799` pure checks; Node engine `1072 answers on 21 snapshots` + `687` request answers; Chromium engine `1794` answers. Browser suite `58 passed`, 1 failed (`final-fast-2.log`, 395.5s).
- Engine sha256 `be364bd72b377b187694af90ef4f7249f06fe7feeb6387b3ca52766a6a0b5628` differs from base `5a773067…`; engine ran in both closing gates. No engine skip claim.
- Not run: full gate, independent-kernel replay, tools/c-analyze/vendor/audit/secrets/workflows stages, mutation campaigns, macOS/Windows runtime. Full fast gate intentionally skips those named stages; the separate trust audit above ran. Linker ENOSPC fixture = Linux-only; loop fixtures = POSIX-only; schema probe exhausts BMP + samples astral/decimal values, not a domain proof. LSP `.lean` unavailable → source/caller reads + compiler.

## Needs MAIN

- Assigned fixes remaining unwritten: **none**.
- Closing gate blocker outside allowlist + finish-only directive: `/home/eturkes/Projects/fvtrace/.scratch/worktrees/general-purpose-1/tests/e2e/export.spec.js:488`, test `a linked what-if paints the recorded view first` (starts at :481). `getByRole('status')` resolves both `#scenario-text` + `#working` (`Working…`), so strict-mode fails before the what-if text can settle. Same test's :485 assertion also uses the broad role. Preserve expected text; scope those assertions to the scenario status. Acceptance: the test + full e2e suite pass while the working indicator is visible.
- Evidence: export spec byte-equal to 3957c87 (`cmp` rc0); untouched isolated rerun passes 1/1 in 4.9s (`e2e-selector-rerun.log`). Selector-race classification = inference from that result + the two-element failure output; not a green full-gate claim.
- MAIN owns the full integration gate, review, current trust-auditor integration + combined statement re-pins.

## Handoff

- Worktree `/home/eturkes/Projects/fvtrace/.scratch/worktrees/general-purpose-1/` stays on `wt/general-purpose-1`; MAIN merges. No push; no Intent/instruction edits; F13 skill refusal values unchanged. No new code starts under the finish-only directive.
- Logs + rerun inputs: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-1/`. `focused` = `FIX_BASE=de05748 bash …/focused.sh`; it copies real repo suites into an isolated native driver. Replay red = `FIX_REPLAY_ONLY=1 FIX_REPLAY_BASE=3957c87|de05748`; server red = `FIX_SERVER_ONLY=1 FIX_SERVER_BASE=716a4b7`. Green omits the base override. `WasmOnly.lean`, `SchemaOnly.lean`, `schema-probe.mjs`, `app-smoke.py` retain focused probes.
- Scratch build clone + ephemeral homes/projects/exports removed; logs + probe inputs retained. Owned-process scan rc1; positive control = one recorded live-server PID line + explicit stop/port refusal. No owned background task remains.
- Report validator: seed positive control expected 1 → count 1, rc0; report seed count 0 → rc1; finding rows 13 → rc0. No unconfirmed code finding remains in the assigned rows.

general-purpose-1-DONE-1
