# Gate-tool fixes

Base = `3957c87`; worktree = `.scratch/worktrees/general-purpose-3`, branch = `wt/general-purpose-3`. Lead lint prerequisite = `aef30e5` (cherry-pick of `e1fbcf7`). Logs = `.scratch/fix/general-purpose-3/`.

| id | commit sha | red command → output (short) | green command → result | sweep | status |
|---|---|---|---|---|---|
| F3 | unknown | `node --test tools/probes/mutate.test.mjs` → help + unknown option each rc 1, expected 0/2 | probe `mutate`; helper tests pass | `parseArgs` + usage dispatch | fixed |
| F21 | unknown | `node --test tools/probes/{compare,scale-gui}.test.mjs`; `bash tests/tools/scale-session.sh` → rc/stderr ignored by both v1 oracles; malformed JSON + failed transforms + JSON streams accepted; stale details ≈7 ms; session 3 became row 0 | all helper tests pass; previous scale 22/22 + compare 6/6; final grader rerun pending | shared stdout/status/stderr comparator; every jq transform + enumeration + form; page + GUI sessions; claim + experiment ready predicates | unknown |
| F22 | unknown | `node --test tools/probes/scale-spawn.test.mjs` → `scale-gui-*` home left | helper test passes; previous scale probe passes; final grader rerun pending | spawn/exit listeners + shared stop/finally | fixed |
| F23 | unknown | `node --test tools/probes/release-guard.test.mjs` → extra archive, unrelated, hidden + directory all rc 0 | probe `release_guard` + six guard cases pass; actionlint + zizmor (offline) pass | download → guard → attest/publish; exact eight regular files; missing-file control retained | fixed |
| F28 | unknown | probe `release_tmpdir` → valid check rc 2, quote syntax error + extraction folder left | probe `release_tmpdir`; original five release probes pass | every `trap` in tool/test shells: release alone embedded a path in shell syntax | fixed |
| F29 | unknown | probe `dispatch` → unknown name + probe rc 7 each returned 0 | probe `dispatch`: both plants fire | dispatch + result accumulation | fixed |
| F31 | unknown | probe `mutate` on base → 5 sites, expected 2; intermediate raw scanner exposed ordinary keyword-adjacent strings → 2 sites, expected 0 | probe `mutate`; raw + adjacent fixtures accepted by Lean; outside sites alone remain | zero/one/two hash delimiters, multiline + backslash raw strings, token boundary | fixed |
| F32 | unknown | `bash tests/tools/install-bound.sh` → limit 1 s, elapsed 4 s, rc 124 | probe `install`: elapsed 2 s, rc 124; exit 7 + normal-success controls pass | TERM → 1 s grace → KILL → wait | needs MAIN |
| F33 | unknown | probe `c_headers` → invalid included header build rc 0, no compiler invocation | probe `c_headers`: bad header fires; restored build passes; unchanged rerun's compiler-count delta = 0 | both C objects + all project `.h` files | fixed |
| F34 | unknown | `bash tests/tools/load-floor.sh` on base → CPUs=1, actual sample=1.20, rc 0 | probe `load`: sampled 1.20/1.50 (1 CPU), 4.49/4.50 (3 CPUs) reject/pass exactly | fractional threshold; ceiling for controller band; locale + display formats | fixed |
| F36 | unknown | `python3 -I tests/tools/load-cleanup.py` on base → measure TERM left Playwright + sampler descendants | probe `load`: measure + gate, command + warm-up, TERM + INT = eight cases, rc 143/130, live descendants `[]` | command groups, sampler, busy loops + warm-up sleeps; EXIT cleanup | fixed |

## Evidence

- `green-fast-gate-final.log`: full fast gate rc 0, 175.2 s. Native 1834/1834; pure 779/779; engine differential; CLI; examples; style/format/lint/types/JS tests; fanout/spec/shell/meta all pass. Skipped by fast gate: tools, trust, c-analyze, vendor, audit, secrets, workflows, e2e. Actionlint + zizmor checked separately; full gate = MAIN.
- `green-node-tools.log`: 23/23 helper tests pass. `red-final-tests.log`: same final suite against exact base tool bytes = rc 1, 18 regression rows fail + 5 controls pass. Source bytes = `cmp` against `git show 3957c87:<path>` for all seven target files, 7/7 equal.
- `green-probes-final-small.log`: `dispatch mutate install release_guard release_tmpdir c_headers load`, rc 0, 16/16. `green-probes-existing.log`: scale 22/22 + release 5/5 pass; compare negative-control fixture had an over-escaped newline, corrected. `green-probes-compare.log`: compare 6/6 pass. Final `scale compare` rerun pending.
- `F31-boundary-red.log`: the ordinary-string regression test fires on intermediate scanner sha256 `52fe07e7a2db69fb1e31905e734d3e3e61a88c98661e541141f5e542eae5079e`; its copy = `RawMaskNoBoundary.mjs`. The complete final raw/ordinary fixture is Lean-valid.
- First fast gate failed only `consistent-return` in the new parser wrapper; explicit never-return fixes it. JS helpers = `tools/probes/`, within the existing lint/type scope; no checker configuration changed.
- Changed shell files all pass shellcheck (the final fast gate's shell stage includes them). Actionlint + zizmor offline = rc 0. Tooling frontmatter parses. Lean LSP unavailable; JS LSP hover works.
- Full gate + idle-host acceptance timings not run here; no performance-bound claim from stub probes. No Intent, CLAUDE.md or agent-role edits.

## Needs MAIN

- F32: the requested grace-period fix passes its red test. Default `attempt_secs=180` stays the TERM cutoff; KILL follows 1 s later. Thus 180 s is a soft cutoff, while ops.md says each attempt ≤180 s. MAIN ruling requested: preserve that literal total budget or state the grace explicitly. No bound wording/constant changed here.
