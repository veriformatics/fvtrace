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

## Needs MAIN

None.

## State

Worktree = `/home/eturkes/Projects/fvtrace/.scratch/worktrees/general-purpose-2`; branch = `wt/general-purpose-2`; base = `3957c87`.

- Page-engine class: 6 new regressions red → green; `engine-red.log`, `engine-green.log`. First fast gate rc 1: own helper lint + ambiguous status selectors fixed; MAIN baseline `e1fbcf7` cherry-picked. Second fast gate running (`b5pphusxf`).
- Sequencing class: scratch `next/` (private .lake, tooling read-only symlink). 5 regressions red (`sequence-red.log`); initial green = 3 pass + 2 load-sensitive failures, Back isolation pass (`back-green.log`). Tests now scroll the initial board + await the released envelope before restoration checks. Saved code/spec = `sequence-app.js`, `sequence-spec.js`; rerun pending.
- Board class: 3 regressions red → green (`board-red.log`, `board-green.log`). Scratch `next/` holds class 1 + sequencing + board fixes; assigned worktree stays frozen for class-1 gate.
- Logs + saved source files above = `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-2/`.
