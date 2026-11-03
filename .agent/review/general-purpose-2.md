# general-purpose-2 — GUI/page engine fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
|---|---|---|---|---|---|
| F24 | d009e38 | `playwright test export.spec.js --grep 'idle Worker'` → 2 failures, empty notice | same → 2 pass; fast gate + e2e rc 0 (235.5s, 65 pass) | both Worker failure events + idle/pending call guards | fixed |
| F37 | d009e38 | `playwright test export.spec.js --grep 'fatal .*engine answer'` → 3 failures (superseded shape/invalid, invalid details) | same → 3 pass; fast gate + e2e rc 0 | evaluation/details/pairs decoded before queue release; no post-failure calls | fixed |
| F38 | d009e38 | `playwright test export.spec.js --grep 'invalid JSON in the recorded'` → no damage notice | same → pass; fast gate + e2e rc 0 | data-block parse + export decode in damage handler | fixed |
| F39 | unknown | unknown | unknown | unknown | unknown |
| F40 | unknown | unknown | unknown | unknown | unknown |
| F41 | unknown | unknown | unknown | unknown | unknown |
| F42 | unknown | unknown | unknown | unknown | unknown |
| F43 | unknown | unknown | unknown | unknown | unknown |
| F44 | unknown | unknown | unknown | unknown | unknown |
| F45 | unknown | unknown | unknown | unknown | unknown |
| F25 | unknown | unknown | unknown | unknown | unknown |
| F27 | unknown | unknown | unknown | unknown | unknown |
| F26 | unknown | unknown | unknown | unknown | unknown |
| F72-a (row clicks) | unknown | unknown | unknown | unknown | unknown |
| F72-b (group order) | unknown | unknown | unknown | unknown | unknown |
| F72-c (tour counts) | unknown | unknown | unknown | unknown | unknown |

## Needs MAIN

No unwritten application fix in the assigned set: all original classes + F72 GUI were implemented before the code-ownership cutoff. Work left = verification + integration/commits. F72 Lean lint wording is general-purpose-1's; Worker silence deadline remains outside this assignment.

MAIN approved harness synchronization fixes + reached-stage batching; selector commit = `46df169`, startup-sync commit = `0c45309`, lazy work-row synchronization joins F26. Every exported-module change runs export.spec.js + engine.spec.js. No assertion, case or limit edits.

## Gate evidence

- Sequencing full fast gate: rc 1 (`sequence-fast.log`, 1040.4s); mechanical/native/engine stages passed, 67 e2e passed + 2 existing synchronization checks failed. New sequencing cases = 5 pass; deterministic Back = 5 consecutive pass (`back-five.log`).
- Synchronization red witnesses: `gui.spec.js:254` O2 lazy row absent before scrolling; `export.spec.js:462` busy assertion expected false, received true after start-ready + fixed 100ms. Corresponding harness changes are authorized above.
- Wasm = `5a773067b06079a2566eacd1e4eb1e2e6110fc6089d10c4f7aaf66bb5dd6255e`; unchanged-engine stage took 789.4s of latest 1040.4s gate. Approved reached gates skip that stage while its hash matches; final full fast gate remains required.
- Startup/navigation timeouts occurred. Host load at those events was not captured; cause remains unconfirmed. No limit changed.

## State

Worktree = `/home/eturkes/Projects/fvtrace/.scratch/worktrees/general-purpose-2`; branch = `wt/general-purpose-2`; base = `3957c87`.

- Original combined commit `353de5d` is being split per MAIN: selector = `46df169` (reached rc 0, 405.0s, 43 browser cases); startup sync = `0c45309` (mechanical/native pass + serial 17/17 browser pass). Engine source/spec restored to assigned worktree; reached gate running (`b7nutjxn1`, export + engine + responsive + smoke, serial). Original six regressions already red → green; original combined tree passed full fast gate (`engine-fast-2.log`, 235.5s, 65 e2e pass). MAIN baseline `e1fbcf7` is cherry-picked as `e341b7b`. Finding commit cells update when the split engine commit lands.
- Sequencing class integrated: 5 regressions red (`sequence-red.log`) → 5 pass (`sequence-wt-green.log`). First scratch green run = 3 pass + navigation/recovery timeouts; Back isolation pass (`back-green.log`); tests now scroll the initial board + await the released envelope before restoration checks. Back five-repeat passed; full fast gate ended with the existing-check failures above. Assigned tree holds this class uncommitted.
- Board class: 3 regressions red → green (`board-red.log`, `board-green.log`). Saved code = `board-{app,circuit,style}`, suite = `board-spec.js`.
- Tour class: 2 regressions red → green (`tour-red.log`, `tour-green.log`); 12-fact fixture walked at 1280×720 + 390×844. `facts-tour-phone.png` inspected: first contact spotlit, card clear of it, controls visible.
- Work class: 300 gated claims positive control; red mounts 300, green ≤40 offscreen + end line, keyboard reaches all 300; exact first/last sentences unchanged (`work-red.log`, `work-green.log`).
- Visual QA: `text.png` + `hub.png` inspected; Text selected border visible, long work text retains its form. Explicit-context harness: `visual-qa-3.log` rc 0, axe `[]` in both states. Prior harness failures: navigation timeout; axe requires `browser.newContext()` instead of owned `browser.newPage()`. Navigation-timeout cause unconfirmed; looked in Playwright output only; no app/gate limit changed.
- F72 GUI class: six repo regressions red (`f72-red-2.log`: blocker/check plain clicks independently at desktop + phone; overlooked/new-data order independently; native state positive control passed) → 6 pass; three existing tour walks also pass (`f72-green.log`, 9 total). Snapshots = `f72-{app,panels,tour,style}`, `f72-gui-spec.js`. Tour copy states existing-analysis coverage + new-data counts apart; no copy-word lint added. Lean lint wording remains general-purpose-1's.
- Startup-sync reached run rc 1 (`startup-sync-reached.log`, 706.0s): build/Assets + all JS stages pass; browser 15 pass, two unrelated export timeouts (90s click + 5s linked what-if). Same assertions/limits rerun serially (`bnkg23yqs`, `startup-sync-browser-serial.log`). Host sampled after failure: 8 CPUs; load 19.74/30.36/29.77; failure-time load not captured. No timeout changed.
- Logs + saved source files above = `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-2/`.
