# Gate-tool fixes

Commit = `b86c6ed6586aa851197134c48eddab568e9c49db` on `wt/general-purpose-3`; worktree = `.scratch/worktrees/general-purpose-3`. Base = `3957c87`; prerequisite `aef30e5` = lead lint fix `e1fbcf7` cherry-picked. Logs + red fixtures = `.scratch/fix/general-purpose-3/`. MAIN owns every remaining code change.

| id | commit sha | red command → output (short) | green command → result | sweep | status |
|---|---|---|---|---|---|
| F3 | b86c6ed | `node --test tools/probes/mutate.test.mjs` → help + unrecognized option each rc 1, expected 0/2 | probe `mutate`; helper tests pass | `parseArgs` + usage dispatch | fixed |
| F21 | b86c6ed | `node --test tools/probes/{compare,scale-gui}.test.mjs`; `bash tests/tools/scale-session.sh` → rc/stderr ignored by both v1 oracles; malformed JSON + failed transforms + JSON streams accepted; stale details ≈7 ms; session 3 became row 0 | 23/23 helper tests; every final planted breach fires; native self-comparison 1238 runs, 0 differences/timeouts; real-GUI control limit below | shared stdout/status/stderr comparator; every jq transform + enumeration + form; page + GUI sessions; claim + experiment ready predicates | fixed |
| F22 | b86c6ed | `node --test tools/probes/scale-spawn.test.mjs` → `scale-gui-*` home left | helper test + final `scale-spawn-cleanup` pass | spawn/exit listeners + shared stop/finally | fixed |
| F23 | b86c6ed | `node --test tools/probes/release-guard.test.mjs` → extra archive, unrelated, hidden + directory all rc 0 | probe `release_guard` + six guard cases pass; actionlint + zizmor offline pass | download → guard → attest/publish; exact eight regular files; missing-file control retained | fixed |
| F28 | b86c6ed | probe `release_tmpdir` → valid check rc 2, quote syntax error + extraction folder left | probe `release_tmpdir`; final release probes 5/5 | every `trap` in tool/test shells: release alone embedded a path in shell syntax | fixed |
| F29 | b86c6ed | probe `dispatch` → missing name + probe rc 7 each returned 0 | probe `dispatch`: both plants fire | dispatch + result accumulation | fixed |
| F31 | b86c6ed | probe `mutate` on base → 5 sites, expected 2; intermediate raw scanner exposed ordinary keyword-adjacent strings → 2 sites, expected 0 | probe `mutate`; raw + adjacent fixtures accepted by Lean; outside sites alone remain | zero/one/two hash delimiters, multiline + backslash raw strings, token boundary | fixed |
| F32 | b86c6ed | `bash tests/tools/install-bound.sh` → limit 1 s, elapsed 4 s, rc 124 | partial patch: regression helper passes (2 s, rc 124); exit-7 + normal-success controls pass; required hard deadline remains unwritten | TERM → grace → KILL → wait; required TERM179/KILL180 = MAIN | needs MAIN |
| F33 | b86c6ed | probe `c_headers` → invalid included header build rc 0, no compiler invocation | probe `c_headers`: bad header fires; restored build passes; unchanged rerun's compiler-count delta = 0 | both C objects + all project `.h` files | fixed |
| F34 | b86c6ed | `bash tests/tools/load-floor.sh` on base → CPUs=1, actual sample=1.20, rc 0 | probe `load`: sampled 1.20/1.50 (1 CPU), 4.49/4.50 (3 CPUs) reject/pass exactly | fractional threshold; ceiling for controller band; locale + display formats | fixed |
| F36 | b86c6ed | `python3 -I tests/tools/load-cleanup.py` on base → measure TERM left Playwright + sampler descendants | probe `load`: measure + gate, command + warm-up, TERM + INT = eight cases, rc 143/130, live descendants `[]` | command groups, sampler, busy loops + warm-up sleeps; EXIT cleanup | fixed |

## Evidence

- `green-fast-gate-final.log`: full fast gate rc 0, 175.2 s. Native 1834/1834; pure 779/779; engine differential; CLI; examples; style/format/lint/types/JS tests; fanout/spec/shell/meta all pass. Fast-gate skips: tools, trust, c-analyze, vendor, audit, secrets, workflows, e2e. Workflows checked separately. Full gate = MAIN.
- `green-node-tools.log`: 23/23 helper tests pass. `red-final-tests.log`: same final suite against exact base tool bytes = rc 1, 18 regression rows fail + 5 controls pass. All seven source files = `cmp` against `git show 3957c87:<path>`, 7/7 equal.
- `green-probes-final-small.log`: `dispatch mutate install release_guard release_tmpdir c_headers load`, rc 0, 16/16. `green-probes-final-release.log`: release, rc 0, 5/5. `green-probes-final-graders.log`: scale + compare, rc 1, 27 passed + `scale-pass` failed. Every planted breach fires; the one failure is the real-GUI negative control.
- `green-probes-existing.log`: earlier scale 22/22 + release 5/5 pass; compare's negative-control fixture had an over-escaped newline, corrected. `green-probes-compare.log`: compare 6/6 pass. The final comparison probes also all pass. The original `/bin/true` negative control emitted no JSON; its replacement emits a valid v2 envelope.
- `scale-control-detail.log`: focused unchanged control = rc 1: `FAIL wide gui:served:select n=4: wall 0.147 s > 0.1 s`; host = 8 CPUs, load 21.33 at start, 20.37 at end. The full probe's control reported four breaches, but retains only its last five output lines, so those four row names were not captured. Idle-host precondition absent; exact cause unconfirmed. No bound/control input changed.
- `green-compare-native.log`: real native self-comparison, rc 0, 1238 runs, 0 differing outputs, 0 timeouts. This is not old/new binary parity. Engine wasm sha256 = base `5a773067b06079a2566eacd1e4eb1e2e6110fc6089d10c4f7aaf66bb5dd6255e`.
- `F31-boundary-red.log`: ordinary-string regression fires on intermediate scanner sha256 `52fe07e7a2db69fb1e31905e734d3e3e61a88c98661e541141f5e542eae5079e`; copy = `RawMaskNoBoundary.mjs`. Both complete raw/ordinary fixtures are Lean-valid.
- First fast gate failed only `consistent-return` in the parser wrapper; explicit never-return fixes it. JS helpers = `tools/probes/`, inside the existing lint/type scope. No checker configuration changed.
- Changed shells pass shellcheck (final fast-gate shell stage). Actionlint + zizmor offline = rc 0. Tooling frontmatter parses. Lean LSP unavailable; JS LSP hover works.
- No full gate or idle-host cap acceptance run here; no performance-bound claim from stub probes. No Intent, CLAUDE.md or agent-role edits. Worktree clean; every owned verification shell ended. Process search positive control matched one PID; after killing it, the isolated fixer/browser search returns rc 1 (no matches).

## Needs MAIN

- F32: hard deadline ruling = TERM at `attempt_secs-1`, KILL at `attempt_secs`; keep the literal 180 s bound + ops.md unchanged. Current partial code instead sends TERM at 180, KILL at 181. Remaining adjustment is unwritten under MAIN's ownership directive. The artificial 1 s fixture also uses that budget for its quick success/exit-7 controls; those controls may need a larger budget when TERM moves to budget−1.
- `scale-pass`: recheck the unchanged negative control on a suitably idle host. This host's timed rows exceed the limit under load; the pool was 2/2 occupied. Earlier pass retained; final failing runs retained. No grading check weakened.

general-purpose-3-DONE-1
