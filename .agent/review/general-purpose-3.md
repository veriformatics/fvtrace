# Gate-tool fixes

Base = `3957c87`; worktree = `.scratch/worktrees/general-purpose-3`, branch = `wt/general-purpose-3`. Lead lint prerequisite = `aef30e5` (cherry-pick of `e1fbcf7`). Logs = `.scratch/fix/general-purpose-3/`.

| id | commit sha | red command → output (short) | green command → result | sweep | status |
|---|---|---|---|---|---|
| F3 | unknown | `node --test tests/tools/mutate.test.mjs` → help rc 1, expected 0 | probe `mutate` passes | `parseArgs`, usage dispatch | unknown |
| F21 | unknown | `node --test tests/tools/{compare,scale-gui}.test.mjs`; `bash tests/tools/scale-session.sh` → rc/stderr false equality, malformed JSON false equality, stale details ≈7 ms, session 3 became row 0 | unknown | JSON transforms + enumeration + form; shared output comparator; page + GUI sessions; claim + experiment ready predicates | unknown |
| F22 | unknown | `node --test tests/tools/scale-spawn.test.mjs` → `scale-gui-*` home left | unknown | spawn/exit listeners + shared stop/finally | unknown |
| F23 | unknown | `node --test tests/tools/release-guard.test.mjs` → extra archive, unrelated, hidden + directory all rc 0 | probe `release_guard` passes; actionlint + zizmor pass | publish download → guard → attest/publish globs | unknown |
| F28 | unknown | probe `release_tmpdir` → valid archive check rc 2, quote syntax error + extraction folder left | probe `release_tmpdir` passes | every `trap` in `tools/**/*.sh` + `tests/**/*.sh`: release alone embedded a path in shell syntax | unknown |
| F29 | unknown | probe `dispatch` → unknown name + probe rc 7 each returned 0 | probe `dispatch`: 2 plants fire | dispatch + result accumulation | unknown |
| F31 | unknown | `node --test tests/tools/mutate.test.mjs` → 5 sites, expected 2; raw interiors exposed | probe `mutate` passes | comment/string/char masker; zero, one + two hash raw delimiters; multiline + backslash raw cases | unknown |
| F32 | unknown | `bash tests/tools/install-bound.sh` → limit 1 s, elapsed 4 s, rc 124 | probe `install` passes (elapsed 2 s; rc 124); rc 7 + normal-success controls | `bounded` TERM → grace → KILL → wait | unknown |
| F33 | unknown | probe `c_headers` → invalid included header build rc 0; no compiler invocation | probe `c_headers`: bad header fires; restored build compiles; unchanged rerun invokes no compiler | both C objects + all project `.h` files | unknown |
| F34 | unknown | `bash tests/tools/load-floor.sh` → CPUs=1, actual sample=1.20, rc 0 | sampled boundaries: 1.20/1.50 on 1 CPU, 4.49/4.50 on 3 CPUs pass; probe rerun pending | threshold calculation, band ceiling + display formats | unknown |
| F36 | unknown | `python3 -I tests/tools/load-cleanup.py` → measure TERM left Playwright + sampler descendants | measure + gate TERM/INT: rc 143/130, live descendants `[]`; probe rerun pending | command groups, sampler, busy loops + warm-up sleeps; EXIT cleanup | unknown |

## Evidence

- Final Node regressions copied unchanged beside target sources from `3957c87`: `red-final-tests.log`, rc 1 = 14 failing regression rows, 4 passing controls (v1 same-action/details + expected release set + missing archive).
- `green-probes-fast.log`: `dispatch mutate install release_guard release_tmpdir c_headers load`, rc 0, 16 passed. Subsequent sampled-boundary fixture strengthened to demand actual load samples; missing samples never count as its witness.
- Shellcheck = `shellcheck -x` on all six changed tool shells + the three shell tests, rc 0. Lean LSP unavailable; JS LSP hover works on `tools/mutate.mjs`.
- Workflow guard = 10 named steps before/after, 6,328 bytes; actionlint + zizmor rc 0.
- Existing `scale compare release` probes running; fast gate not run yet. Full gate + idle-host acceptance timings = MAIN; no performance-bound claim from these stub probes.

## Needs MAIN

None.
