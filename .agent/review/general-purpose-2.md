# general-purpose-2 — GUI/page engine fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
|---|---|---|---|---|---|
| F24 | 353de5d | `playwright test export.spec.js --grep 'idle Worker'` → 2 failures, empty notice | same → 2 pass; fast gate + e2e rc 0 (235.5s, 65 pass) | both Worker failure events + idle/pending call guards | fixed |
| F37 | 353de5d | `playwright test export.spec.js --grep 'fatal .*engine answer'` → 3 failures (superseded shape/invalid, invalid details) | same → 3 pass; fast gate + e2e rc 0 | evaluation/details/pairs decoded before queue release; no post-failure calls | fixed |
| F38 | 353de5d | `playwright test export.spec.js --grep 'invalid JSON in the recorded'` → no damage notice | same → pass; fast gate + e2e rc 0 | data-block parse + export decode in damage handler | fixed |
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

None. MAIN approved harness synchronization fixes + reached-stage batching; selectors + startup synchronization each get their own commit, lazy work-row synchronization joins F26. Every exported-module change runs export.spec.js + engine.spec.js. No assertion, case or limit edits.

## Gate evidence

- Sequencing full fast gate: rc 1 (`sequence-fast.log`, 1040.4s); mechanical/native/engine stages passed, 67 e2e passed + 2 existing synchronization checks failed. New sequencing cases = 5 pass; deterministic Back = 5 consecutive pass (`back-five.log`).
- Synchronization red witnesses: `gui.spec.js:254` O2 lazy row absent before scrolling; `export.spec.js:462` busy assertion expected false, received true after start-ready + fixed 100ms. Corresponding harness changes are authorized above.
- Wasm = `5a773067b06079a2566eacd1e4eb1e2e6110fc6089d10c4f7aaf66bb5dd6255e`; unchanged-engine stage took 789.4s of latest 1040.4s gate. Approved reached gates skip that stage while its hash matches; final full fast gate remains required.
- Startup/navigation timeouts occurred. Host load at those events was not captured; cause remains unconfirmed. No limit changed.

## State

Worktree = `/home/eturkes/Projects/fvtrace/.scratch/worktrees/general-purpose-2`; branch = `wt/general-purpose-2`; base = `3957c87`.

- Page-engine class committed `353de5d`: 6 new regressions red → green; `engine-red.log`, `engine-green.log`. First fast gate rc 1: own helper lint + ambiguous status selectors fixed; MAIN baseline `e1fbcf7` cherry-picked as `e341b7b`. Second fast gate rc 0 (`engine-fast-2.log`, 235.5s, 65 e2e pass).
- Sequencing class integrated: 5 regressions red (`sequence-red.log`) → 5 pass (`sequence-wt-green.log`). First scratch green run = 3 pass + navigation/recovery timeouts; Back isolation pass (`back-green.log`); tests now scroll the initial board + await the released envelope before restoration checks. Back five-repeat passed; full fast gate ended with the existing-check failures above. Assigned tree holds this class uncommitted.
- Board class: 3 regressions red → green (`board-red.log`, `board-green.log`). Saved code = `board-{app,circuit,style}`, suite = `board-spec.js`.
- Tour class: 2 regressions red → green (`tour-red.log`, `tour-green.log`); 12-fact fixture walked at 1280×720 + 390×844. `facts-tour-phone.png` inspected: first contact spotlit, card clear of it, controls visible.
- Work class: 300 gated claims positive control; red mounts 300, green ≤40 offscreen + end line, keyboard reaches all 300; exact first/last sentences unchanged (`work-red.log`, `work-green.log`).
- Visual QA: `text.png` + `hub.png` inspected; Text selected border visible, long work text retains its form. Explicit-context harness: `visual-qa-3.log` rc 0, axe `[]` in both states. Prior harness failures: navigation timeout; axe requires `browser.newContext()` instead of owned `browser.newPage()`. Navigation-timeout cause unconfirmed; looked in Playwright output only; no app/gate limit changed.
- Logs + saved source files above = `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-2/`.
