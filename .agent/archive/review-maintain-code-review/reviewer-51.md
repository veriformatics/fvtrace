# reviewer-51 — closing diff a43d1c0..27158e4

Scope = seeded R1–R10; code + tests + tools, docs consistency. Target = `27158e4`; security = MAIN. Primary read-only; execution = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-51/copy/`. Findings = 2 (`minor`); register = superseded contract wording. Verdicts = 10/10; changed probes = 41/41 pass.

| row | lens × slice | files | verdict | finding ids |
|---|---|---|---|---|
| R1 | correctness: CLI help, usage errors, skills rc | `Fvtrace/Cli.lean` (`Command`, `commands`, `usage`, `commandUsage`, `helpOf`, `usageError`, `helpPointer`, `command`, `dispatch`, `run`, `skillsCmd`) | finding | reviewer-51-F1 |
| R2 | correctness: exported page Stop control | `web/app.js` (`engineNotice`, `haltEngine`, `busy`, `wire`, `engineFailure`, details state), `web/panels.js`, `web/index.html`, `web/style.css` | pass | none |
| R3 | correctness: page engine build seams + allocator check | `FvtraceWasm/Build.lean` (`pythonFrom`, `appOrder`, link check), `FvtraceWasm/Binary.lean` (`occurs`, `allocatorProblems`) | pass | none |
| R4 | correctness: CI gate driver | `tools/ci-gate.sh` (`summary`, `rows`, `wait_run`, `main`) | pass | none |
| R5 | correctness: gate stages | `tools/gate.sh` (`tools_local`, `leftovers`, `filler`, `provision`, `readme_verdicts`, `meta`, `node_tests`, `spec`), `tools/meta-lint.mjs` | pass | none |
| R6 | correctness: helper scripts | `tools/renovate.sh`, `tools/refresh-lock.sh`, `tools/bootstrap.sh`, `tools/wasm-repro.sh` | pass | none |
| R7 | tests assert the contract (no vacuous or implementation-restating check; each would fail on a plausible defect) | `Tests/Wasm.lean`, `Tests/Cli.lean`, `Tests/CliStore.lean`, `tests/e2e/{gui,export,responsive}.spec.js`, `tests/renovate/renovate.test.mjs`, `tests/palette/palette.test.mjs`, `tests/engine/loader.test.mjs` | finding | reviewer-51-F1, reviewer-51-F2 |
| R8 | probes fire on their named cause + restore every target | `tools/gate-probe.sh` (probes added or changed in the range) | pass | none |
| R9 | cleanup + altitude (reuse, dead code, duplication, special cases on shared infrastructure) | every code file in the range | pass | none |
| R10 | docs ↔ behavior consistency | `.agent/contracts/kernel.md`, `.agent/spec.md` Decisions, `README.md`, `.claude/rules/*.md` lines changed in the range | finding | reviewer-51-F1, reviewer-51-F2 |

## Findings

### reviewer-51-F1 — minor — init/path help advertises the refused --trace option

- Target: `/home/eturkes/Projects/fvtrace/Fvtrace/Cli.lean:159`; command entries `:38–46`, shared paragraph `:124–130`; actual parsers `:306–327`. Regression tests `Tests/Cli.lean:29–50` sample claims/schema/skills but never compare init/path's advertised options with their parsers.
- Contract (`.agent/spec.md:51`, Decisions, CLI help): "`fvtrace <command> --help` (or `-h`) = that command's usage + the shared paragraphs that apply, rc 0". README `:145`: "To see the options of one command, run `fvtrace COMMAND --help`."
- Why wrong: `project := true` selects both `--project` and `--trace`; init/path accept only `--project`. Their new command-specific help therefore tells the reader to use an unsupported option. Trying it returns rc 2 and directs the reader back to the same inaccurate help. The global-help refactor preserves old global text, but the new command-specific surface must filter it by applicability.
- Independent expected value: each command's parser accepts `valued := ["--project"]` (`initCmd`, `pathCmd`), not `located`. Command-specific help must not advertise an option that command refuses. This finding does not request broadening either parser.
- Red command (target scope in copy byte-matches `27158e4`):

  ```sh
  python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-51/help-red.py /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-51/copy
  ```

  Output excerpt, rc 1 (full stderr + refusal diagnostics in `help-red.log`):

  ```text
  init --help: rc=0; advertises --trace FILE=True
  path --help: rc=0; advertises --trace FILE=True
  AssertionError: command-specific help advertises a refused option: ['init', 'path']
  ```

- Fix direction: separate project-location text from trace-override text/capability; render `--trace` only for commands that read that option. Pin init/path help independently of the `commands` data it tests; preserve the ruled exit/error behavior.

### reviewer-51-F2 — minor — RE2 syntax gate accepts RE2-invalid counted repetitions

- Target: `/home/eturkes/Projects/fvtrace/tests/renovate/renovate.test.mjs:77–107`, especially `:100` ("every regex compiles under RE2's syntax"); claim in `.claude/rules/renovate.md:9`.
- Contract (`.claude/rules/renovate.md:9`): "every regex avoids the syntax RE2 refuses". Test's own claim `:4–5`: "so a pattern passing here + failing in the app fails here."
- Why wrong: `re2Rejects` checks selected escape/group/possessive forms, while JS `RegExp` accepts repetition counts above RE2's limit. Adding `matchPackageNames: ["/x{1001}/"]` leaves all four committed tests green, although real `re2@1.27.0` refuses it. The present config remains valid; this is a false-green validator, not evidence that today's Renovate config fails.
- Independent oracle: actual node-re2 native compiler, installed cached copy (no package installation or network). Positive control `x{1000}` succeeds; `x{1001}` throws `invalid repetition size: {1001}`. Its vendored RE2 source `/home/eturkes/.cache/pnpm/dlx/0f5942a90c3cff4351200bd50a3dfb68/mw2rjlq6-1h85n/node_modules/.pnpm/re2@1.27.0/node_modules/re2/vendor/re2/doc/syntax.txt:39–41` states: "Implementation restriction: The counting forms «x{n,m}», «x{n,}», and «x{n}» reject forms that create a minimum or maximum repetition count above 1000. Unlimited repetitions are not subject to this restriction."
- Red command:

  ```sh
  node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-51/re2-red.mjs /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-51/copy /home/eturkes/.cache/pnpm/dlx/0f5942a90c3cff4351200bd50a3dfb68/mw2rjlq6-1h85n/node_modules/.pnpm/re2@1.27.0/node_modules/re2
  ```

  Output, rc 1 (`re2-red.log`):

  ```text
  RE2 positive control x{1000}: accepted; x{1001}: invalid repetition size: {1001}
  ✔ every regex compiles under RE2's syntax
  ℹ tests 4
  ℹ pass 4
  ℹ fail 0
  target RE2 gate rc=0
  AssertionError [ERR_ASSERTION]: the RE2 syntax gate must reject a pattern the real RE2 rejects
  ```

- Fix direction: use a real RE2 parser/compiler, or narrow the static check's stated guarantee to its actual subset and retain the separately required real Renovate validator as the authority. If retaining a complete-syntax claim, add a counted-repetition plant + its boundary positive control; a longer denylist alone does not prove completeness.

## Register

- `/home/eturkes/Projects/fvtrace/.agent/contracts/kernel.md:124` still says "`fvtrace: <message>` + the usage text on stderr" (exact `rg -Fn` anchor). New Decisions + user ruling supersede this with the two-line help pointer. That unchanged V-cli line lies outside R10's changed-line slice; update at close to keep the contract internally consistent. New behavior + its tests correctly follow the newer user ruling.
- No security finding investigated; MAIN owns that lens.

## Checks + limits

- Read every implementation/test/tool hunk with its enclosing function, all range commit bodies, kernel contract + spec Intent/Decisions + README + every `.claude/rules/*.md`; read cross-workflow provisioning targets and caller/callee seams. Scope query `git diff --name-only 27158e4 -- Fvtrace FvtraceWasm Tests tests tools web README.md .claude/rules .agent/contracts/kernel.md .agent/spec.md` in the copy = empty, rc 0; positive control = the same copy's git status names copied roster/report changes. Only report + owned scratch written by this reviewer.
- Isolated `lake build fvtrace «fvtrace-tests»`: rc 0. First build overlapped fast text-only probes (including lakefile metadata), so it was not trusted alone; second build ran after probes finished, target scope rechecked, rc 0.
- `FVTRACE_TEST_AREAS=cli,cli-store,wasm,wasm-native .lake/build/bin/fvtrace-tests`: 298/298 pass (`focused.log`). `node --test tests/engine/loader.test.mjs`: 4/4 pass. `node --test tests/renovate/ tests/palette/`: 7/7 pass (`node-tests.log`). These green baseline checks do not erase either red witness.
- Focused Playwright = changed focus/layout/font/selection tests + Stop/Worker/stacking tests: 7/7 pass, 12.0 s (`e2e.log`; exact command in its task transcript). Specific tests, not a full browser suite; no browser/render timing benchmark claimed.
- Changed lightweight probes: `bash tools/gate-probe.sh provision meta palette renovate install_dir leftovers filler ci_gate meta_lint ledger`: 33/33 pass (`probes.log`). Each expected cause matched; `keep`/`restore` re-hashed targets. Build-dependent `bash tools/gate-probe.sh examples wasm`: 8/8 pass (`build-probes.log`), including the real dlmalloc link refusal. Combined changed probes = 41/41.
- LSP real-file call on `Fvtrace/Cli.lean`: no server for `.lean`; source reads + compiler/test checks used instead.
- Not run: full gate, full `lake test`, complete e2e/engine differential suites, mutation campaign, two-clean-build wasm-repro campaign, dependency reinstall/lock refresh, live Renovate lookup/validator, live CI push/watch, loaded-host/scale benchmarks. Script/CI review is static + focused probe execution; no remote action, branch/tag creation, commit or push.
- Private copy + logs + red scripts retained for lead's acceptance reruns; cached build occupies ~4 GiB. Completion validation = 10 verdict rows, no unfilled cells (grep count 0; rc 1 is its normal no-match result). Exact source anchors rematched at `27158e4`.

reviewer-51-DONE-1
