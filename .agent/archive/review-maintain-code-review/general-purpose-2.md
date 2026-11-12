# general-purpose-2 — GUI/page engine fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
|---|---|---|---|---|---|
| F24 | d009e38 | `playwright test export.spec.js --grep 'idle Worker'` → 2 failures, empty notice | same → 2 pass; reached gate rc 0 (244.0s, 38 browser pass); prior full fast gate rc 0 (235.5s, 65 pass) | both Worker failure events + idle/pending call guards | fixed |
| F37 | d009e38 | `playwright test export.spec.js --grep 'fatal .*engine answer'` → 3 failures (superseded shape/invalid, invalid details) | same → 3 pass; fast gate + e2e rc 0 | evaluation/details/pairs decoded before queue release; no post-failure calls | fixed |
| F38 | d009e38 | `playwright test export.spec.js --grep 'invalid JSON in the recorded'` → no damage notice | same → pass; fast gate + e2e rc 0 | data-block parse + export decode in damage handler | fixed |
| F39 | 3c3de98 | `playwright test responsive.spec.js -g 'action while'` → action sent pending O2 instead of shown empty view | same → pass; reached rc 0 (366.6s, 42 browser cases) | action payload captures normalized shown overrides | fixed |
| F40 | 3c3de98 | `playwright test responsive.spec.js -g 'chosen match'` → history q stayed Q1, expected Q2 | same → pass, reload keeps C3 selected | both `on.select` + `reveal` persist target q before history | fixed |
| F41 | 3c3de98 | `playwright test responsive.spec.js -g 'details for another'` → foreign overrides/header accepted ready | both cases pass; reached rc 0 | selected details + pairs compare generation/header/overrides; selected item matches | fixed |
| F42 | 3c3de98 | `playwright test responsive.spec.js -g 'Back retains'` → stale title restored before later envelope | pass + 5 consecutive runs (24.2s); reached rc 0 | render/popstate retain unavailable view until envelope | fixed |
| F43 | b191e25 | `playwright test responsive.spec.js -g 'Text-layout'` → selected class absent | pass; reached rc 0 (147.4s, 45 browser cases) | shared claim marking in both layouts + pressed state + Text ink border | fixed |
| F44 | b191e25 | `playwright test responsive.spec.js -g 'equal titles'` → one same-title subject's claim absent | pass; both distinct groups + claims present | role/subject-id keys, display titles kept separate | fixed |
| F45 | b191e25 | `playwright test responsive.spec.js -g 'reordered outside'` → selected C290 unmounted | pass; selected card + focused switch kept; reached rc 0 | keep focused/selected claim in lazy window; linked scroll + refocus preserved | fixed |
| F25 | 25ff71b | `playwright test gui.spec.js -g 'twelve-fact'` → phone card overlaps spotlight | pass; every step at 1280×720 + 390×844; reached rc 0 (159.6s, 50 browser cases) | facts-step compact first contact; placement unchanged | fixed |
| F27 | 25ff71b | `playwright test gui.spec.js -g 'ends the active tour'` → 1 tour card remains | pass; card/spot/room removed; reached rc 0 | shared tour end removes listeners; cannotShow ends active tour | fixed |
| F26 | b2d45e4 | `playwright test responsive.spec.js -g 'work row mounts'` → expected ≤40, received 300 (engine gates=300) | pass; keyboard reaches all 300; reached rc 0 (187.2s, 71 browser cases) | listOf wraps gated-claim sentences; old offscreen assertion scrolls first; wording unchanged | fixed |
| F72-a (row clicks) | d742331 | `playwright test gui.spec.js -g 'rows open from their text'` → four independent click failures | all 4 pass + id-button keyboard controls; reached rc 0 (167.9s, 77 browser cases) | blocker/check rows both use clickToOpen; text selectable, control clicks keep own targets | fixed |
| F72-b (group order) | d742331 | `playwright test gui.spec.js -g 'groups keep the engine'` → both groups show open before can (native control states correct) | both cases pass; reached rc 0 | verdict order applied once before all group partitions; subject-id keys retained | fixed |
| F72-c (tour counts) | d742331 | source witness `counts the claims in the whole analysis` conflicts with kernel.md Counts | copy matches existing-analysis scope; key 0/1/1/0 + phone screenshot inspected; three tour walks pass | new-data claims counted apart; no copy-word lint | fixed |

## Needs MAIN

All assigned confirmed fixes committed + verified on `wt/general-purpose-2`, HEAD `d742331`. Final full fast gate rc 0 (201.1s; 81 e2e pass). F72 Lean lint wording is general-purpose-1's; Worker silence deadline remains outside this assignment. No application fix started after the code-ownership cutoff.

Unconfirmed follow-on → MAIN: `load(action)` captures shown payload but leaves pending `view.spec` until success. A recoverable action problem may leave a superseded symbol what-if in the address while the old envelope stays shown. Looked at action-spec + problem branches of `web/app.js`; no runtime witness/new test. Normal F39 payload case passes. No new application code added after cutoff.

MAIN approved harness synchronization fixes + reached-stage batching; selector commit = `46df169`, startup-sync commit = `0c45309`, lazy work-row synchronization joins F26. Every exported-module change runs export.spec.js + engine.spec.js. No assertion, case or limit edits.

## Gate evidence

- Sequencing full fast gate: rc 1 (`sequence-fast.log`, 1040.4s); mechanical/native/engine stages passed, 67 e2e passed + 2 existing synchronization checks failed. New sequencing cases = 5 pass; deterministic Back = 5 consecutive pass (`back-five.log`).
- Synchronization red witnesses: `gui.spec.js:254` O2 lazy row absent before scrolling; `export.spec.js:462` busy assertion expected false, received true after start-ready + fixed 100ms. Corresponding harness changes are authorized above.
- Wasm = `5a773067b06079a2566eacd1e4eb1e2e6110fc6089d10c4f7aaf66bb5dd6255e`; unchanged-engine stage took 789.4s of latest 1040.4s gate. Approved reached gates skip that stage while its hash matches; final full fast gate remains required.
- Startup/navigation timeouts occurred. Host load at those events was not captured; cause remains unconfirmed. No limit changed.

## Final verification

- `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-2/home nice -n 10 bash tools/fast-gate.sh --e2e` on committed HEAD `d742331`, tree `50ccfc148b0980cb26ed8ce14d6a25651a00310f`: rc 0, 201.1s (`final-fast.log`). Native 1834/1834; pure 779/779; e2e 81/81 (axe included); JS tests 64/64; Node engine differential passed (51.1s). All fast-gate stages passed.
- Fast-gate skipped stages, unchanged: `tools`, `trust`, `c-analyze`, `vendor`, `audit`, `secrets`, `workflows`. Full CI/full gate, reference-host scale/timing/memory assertions + mutation campaigns not run by this fixer. New functional cases have red witnesses; no existing case/assertion/limit removed or weakened.
- Four screenshots inspected: `facts-tour-phone.png`, `text.png`, `hub.png`, `tour-counts-phone.png`; Text + hub additional axe checks = `[]`. Finite synthetic/fixture/scale samples; no N_cap or repeated-what-if heap-soak claim.
- Cleanup: scratch source/build copy + 26 superseded integration/helper snapshots removed; evidence logs/images + QA/reached drivers retained. Working tree clean (`git status --porcelain` rc 0, 0 bytes; HEAD positive control present). Owned server pattern control = 1 match, rc 0; final owned-server listing = 0, rc 1 (`final-servers.txt`). No owned fvTrace server remains.
- No Intent/instruction files edited by this fixer.

## State

Worktree = `/home/eturkes/Projects/fvtrace/.scratch/worktrees/general-purpose-2`; branch = `wt/general-purpose-2`; base = `3957c87`.

- Harness commits: `46df169` selectors (reached rc 0, 405.0s, 43 browser cases); `0c45309` startup sync (mechanical/native pass + serial 17/17 browser pass). MAIN baseline `e1fbcf7` cherry-picked as `e341b7b`. Original combined commit `353de5d` is superseded; its full fast gate passed (`engine-fast-2.log`, 235.5s, 65 e2e). Engine app source rematches `d009e38` byte-for-byte.
- Engine = `d009e38`, reached rc 0 (244.0s, 38 browser cases). Sequencing = `3c3de98`, reached rc 0 (366.6s, 42 browser cases); deterministic Back also passed five consecutive runs. No assertion/limit changed; fixed synchronization observes mounted rows/replies.
- Board = `b191e25`, reached rc 0 (147.4s, 45 browser cases). Tour = `25ff71b`, reached rc 0 (159.6s, 50 browser cases); 12-fact fixture walked at 1280×720 + 390×844. `facts-tour-phone.png` inspected: first contact spotlit, card clear of it, controls visible. Work = `b2d45e4`, reached rc 0 (187.2s, 71 browser cases). F72 GUI = `d742331`, reached rc 0 (167.9s, 77 browser cases).
- Work class: 300 gated claims positive control; red mounts 300, green ≤40 offscreen + end line, keyboard reaches all 300; exact first/last sentences unchanged (`work-red.log`, `work-green.log`).
- Visual QA: `text.png` + `hub.png` inspected; Text selected border visible, long work text retains its form. Explicit-context harness: `visual-qa-3.log` rc 0, axe `[]` in both states. Prior harness failures: navigation timeout; axe requires `browser.newContext()` instead of owned `browser.newPage()`. Navigation-timeout cause unconfirmed; looked in Playwright output only; no app/gate limit changed.
- F72 GUI class: six repo regressions red (`f72-red-2.log`: blocker/check plain clicks independently at desktop + phone; overlooked/new-data order independently; native state positive control passed) → 6 pass; three existing tour walks also pass (`f72-green.log`, 9 total). Committed in `d742331`; integration snapshots removed after verification. Tour copy states existing-analysis coverage + new-data counts apart; no copy-word lint added. Lean lint wording remains general-purpose-1's.
- Startup-sync reached run rc 1 (`startup-sync-reached.log`, 706.0s): build/Assets + all JS stages pass; browser 15 pass, two unrelated export timeouts (90s click + 5s linked what-if). Same assertions/limits passed serially (17/17, 5.4m; `startup-sync-browser-serial.log`). Host sampled after failure: 8 CPUs; load 19.74/30.36/29.77; failure-time load not captured. No timeout changed.
- Final code = assigned worktree, HEAD `d742331`; working tree clean. Final full fast gate passed from committed state (`final-fast.log`).
- Evidence logs + inspected images + replayable QA/reached drivers retained at `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-2/`; temporary source/build copies + integration snapshots removed.

general-purpose-2-DONE-1
