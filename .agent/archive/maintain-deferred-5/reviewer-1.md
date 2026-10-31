# reviewer-1 verdicts — closing diff 405bf98..0c806c1 (MAINTAIN deferred sweep 5)

Fixed set = R1–R10 below; acceptance = each unit's deferred-row contract + recorded user ruling. Repository read-only; evidence artifacts only in this folder. Workflow security posture = MAIN; job graph = R2.

| row | lens × slice | verdict | finding (1 line; detail below keyed by row) |
|---|---|---|---|
| R1 | correctness: tools/release.sh (package, check, floors; bash 3.2–5, Git Bash on Windows, failure modes) | finding | F1 (minor defect): normal warm cache after the emsdk bump makes `package` refuse both installed versions. |
| R2 | correctness: .github/workflows build.yml + release.yml + gate.yml + codeql.yml (job graph, dry run vs tag, `release` input, artifacts, `installed` matrix, `$/` calls, step bounds) | pass | No additional contract-breaking defect found; evidence + coverage below. |
| R3 | correctness: tools/install-lean.sh + tools/fetch-tools.sh + tools/pin-tool.sh (bounded/retried, Windows zip/.exe, lock consistency awk) | pass | No additional contract-breaking defect found; evidence + coverage below. |
| R4 | correctness: web/app.js `requested` (every set/clear path; queued/flying; actions; reset; refusal; engine failure) vs kernel.md E-gui + the e2e tests | pass | No additional contract-breaking defect found; evidence + coverage below. |
| R5 | correctness: FvtraceWasm/Build.lean (link try/finally, licenses + blankTrimmed, download bounds), FvtraceWasm/Lock.lean parse, lakefile engine target (LICENSE input, addTrace), FvtraceEngine.lean, Fvtrace/Export.lean licensesHtml + footer insertion | pass | No additional contract-breaking defect found; evidence + coverage below. |
| R6 | correctness: tools/scale-gui.mjs (signal handlers, stop(), dangling evaluate) | finding | F2 (minor defect): signals in the home/server creation → listener-registration gap still bypass cleanup. |
| R7 | correctness: tools/gate.sh `shell` selection; tools/gate-probe.sh probes `release` + `locks` (fire for the named cause, restore) | pass | No additional contract-breaking defect found; evidence + coverage below. |
| R8 | claim soundness: commit bodies vs evidence (red witnesses, run ids, counts); spot-check ≥ 3 run ids with `gh run view` | pass | No additional contract-breaking defect found; evidence + coverage below. |
| R9 | docs consistency: .claude/rules (ops, deps, release, wasm, web), .agent/contracts (kernel.md E-gui + E-page, units.md), .agent/spec.md Artifacts, .agent/deferred.md, README.md vs the code | pass | No additional contract-breaking defect found; evidence + coverage below. |
| R10 | cleanup: dead code, duplication, reuse of existing helpers, needless complexity | pass | No additional contract-breaking defect found; evidence + coverage below. |

## Detail (per row id: file:line + the evidence that decides it)

### Review state

Initial `git status --porcelain` = empty, rc 0. Target = 17 commits, 42 files, 1156 insertions / 349 deletions. Read fixed set before target; reviewed per-unit contracts in `git log --reverse --format='%h %s%n%b' 405bf98..HEAD`.

### R1 — F1 (minor defect): select the pinned emsdk, not every cached version

- Location: `tools/release.sh:52–53`.
- Anchor bytes: `emsdk=(.lake/build/wasm/emsdk-*/install/emscripten)`; `expected one Emscripten in .lake/build/wasm`.
- Contract: `tools/release.sh package TARGET` packages the built program + its license texts; the release probe's package control must pass on a valid built tree. `FvtraceWasm.Build.emsdk` deliberately names each download/tree by version/platform/digest and keeps prior pins. The same diff upgrades 6.0.12 → 6.0.13. Thus a normal incremental build leaves both valid SDKs, not a corrupt cache.
- Red on 0c806c1, existing unmodified warm cache:
  ```text
  (cd /home/eturkes/Projects/fvtrace && DIST=/home/eturkes/Projects/fvtrace/.scratch/maint5/reviewer-1/package-current bash tools/release.sh package linux-x86_64)
  rc=1
  release: expected one Emscripten in .lake/build/wasm, found: .lake/build/wasm/emsdk-6.0.12-linux-x86_64-7b073a102b07eca5/install/emscripten .lake/build/wasm/emsdk-6.0.13-linux-x86_64-cda6801012ff3319/install/emscripten
  ```
- Consequence: `bash tools/gate-probe.sh release locks` → rc 1, `probes: 2 passed, 5 failed`; locks fired, release package control failed, its four dependent plants had no valid archive. Output: `package-current.log`, `probes.log` in this folder. `git status --porcelain` remained empty after the probes. Clean CI cache keys hide this failure; no failure of the four clean-cache CI builds is claimed.
- Positive control: a byte-identical copy of `tools/release.sh` in a fixture exposing only the current SDK (`cmp` rc 0) → `package linux-x86_64` rc 0; the original target's `check <fixture>/dist linux-x86_64 0.1.0` also rc 0, `glibc ≤ 2.17 (floor 2.17)` + synthetic strict check passed. `release-control.log` records both. This isolates the failure to the SDK selection, not the binary, floor or example.
- Fix acceptance: select the active `emsdk` line for the host from `tools/wasm.lock` (including digest/key), retain the old SDK cache, then `package` + `gate-probe.sh release locks` pass without deleting the old SDK.

### R6 — F2 (minor defect): register cleanup before creating owned resources

- Location: `tools/scale-gui.mjs:243–245, 278–283` (home/server created before signal listeners).
- Anchor bytes: `const home = mkdtempSync(join(tmpdir(), "scale-gui-"));`; `process.once(signal, () => void stop().finally(() => process.exit(code)));`.
- Contract: 2b7eee5's driver unit handles SIGINT/SIGTERM/SIGHUP sent to the driver alone, stops its server, removes its data folder and returns 128+n. Creating those resources before installing any handler leaves an interruptible gap. This is not a failure of `stop()` once its handler exists.
- Natural red on 0c806c1: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/maint5/reviewer-1/signal-smoke.py` watches `/proc` for this driver's server + own temp home, then signals the driver alone:
  ```text
  SIGINT: rc=130, expected=130, server_alive=False, homes=0
  SIGTERM: rc=143, expected=143, server_alive=False, homes=0
  SIGHUP: rc=-1, expected=129, server_alive=True, homes=1
  AssertionError
  ```
  Python's -1 = terminated by SIGHUP, not orderly handler exit. The orphan was independently observed as PID 2203072 and then stopped; a positive control found that one PID before cleanup, and `pgrep -af '[f]vtrace serve'` afterward returned rc 1 / no matches.
- Deterministic boundary witness: `signal-at-spawn.mjs` is a Node preload that preserves the real `child_process.spawn` and, immediately after the driver's actual server spawn, records handler counts + sends SIGHUP to the driver. Target code unchanged. Run:
  ```text
  cd /home/eturkes/Projects/fvtrace
  TMPDIR=$PWD/.scratch/maint5/reviewer-1/signal-spawn-tmp \
  REVIEW_BIN=$PWD/.lake/build/bin/fvtrace \
  REVIEW_OBSERVATION=$PWD/.scratch/maint5/reviewer-1/signal-spawn-observed.json \
  node --import $PWD/.scratch/maint5/reviewer-1/signal-at-spawn.mjs tools/scale-gui.mjs \
    $PWD/.lake/build/bin/fvtrace $PWD/.scratch/maint5/reviewer-1/shape \
    $PWD/.scratch/maint5/reviewer-1/shape.html
  rc=129 (shell: Hangup)
  {"driver":2207101,"server":2207283,"hupHandlers":0,"intHandlers":0,"termHandlers":0}
  residual home: signal-spawn-tmp/scale-gui-KyMw4H
  ```
  That child subsequently exited with its closed output pipe; persistent server leakage is not claimed for every timing. The unreclaimed home alone breaks cleanup.
- Positive controls: `signal-control.py` waits 0.2 s after resource creation; all three signals → 130/143/129, zero live servers + zero homes. Normal driver at `outcomes 50` → rc 0, 13 rows, all row rc 0, no temp entries. Logs: `signal-control.log`, `signal-normal.log`. These are functional cleanup checks, not reference-host timing evidence.
- Fix acceptance: own signal handling covers setup as well as steady state; the spawn-boundary witness leaves neither home nor server, and the three post-setup controls + normal driver remain green. A handler may defer cleanup while in-progress setup finishes; ensure it cannot exit and then allow that setup to create a resource afterward.

### R2 — pass: workflow graph

Read all four workflow files + `.github/actionlint.yaml` with their callers. `build.yml`'s boolean defaults false for gate portability; release passes true, suppresses the cache + uploads one named artifact per target. `publish` needs the entire reusable matrix and runs only for tags; it checks all eight versioned files before `gh release create`. `installed` permits skipped publish for branch dry runs, requires successful build, takes the release on tags / matching build artifact otherwise, and runs on each target (macOS 14 for the floor). The three install sites each set 10 min; CodeQL selects C alone. `$/` calls resolve in the observed dry run; actionlint's exemption is call-format-specific. Local `actionlint`, `fanout`, `meta`, `spec` all rc 0. Run 41193890240 demonstrates build ×4 → publish skipped → installed ×4 green. Tag publish/download has not run (release held); judgment here = inspected graph + existing dry-run execution, not a claim that a release was published. Workflow security posture stays with MAIN.

### R3 — pass: installer + fetch/pin plumbing

Read each whole script + its workflow callers. The install stages retry their bounded child, bootstrap the pinned executable (including `.exe`), select exactly `lean-toolchain`, and persist elan's path. Fetch validates the lock before consulting stamps; the one-line half-bump probe fired on the target. ZIP extraction/member naming, Windows platform selection and five-asset pin recipe agree with the committed lock. Entry counts: elan-init 5 at 4.2.4; each scanner 4 at its one version; emsdk 5 at 6.0.13. CI run 41195130073 has all seven installs green on the four OS/arch targets; 41195120095 has all seven planted hangs fail at the install step's 10 min outer bound. No fresh local install was run (would mutate HOME / tool stores outside the review allowlist). No claim that arbitrary SIGTERM-ignoring descendant processes are forcibly bounded by the polling helper; the observed outer CI timeout is the terminal bound.

### R4 — pass: pending symbol requests

Read `web/app.js`'s enclosing load/evaluation/hash/detail/action/reset flows, not just the hunk. Symbols apply the label's suppose/restore operation to `requested ?? view.whatif`, delete that fact first, and put a supposed fact first. `setWhatif` retains the pending map; superseded loads do not clear a newer map; the latest normal settlement clears it. Actions/hash reads clear it; refused specs explicitly make fallback empty. Export reset's no-request early return can retain an empty map, but the shown map is empty too, so the next operation is identical; no behavioral defect inferred from that internal lifetime. Engine-off guards prevent a retained map from invoking a dead engine. New served + exported rapid-click cases and A → B → A passed. Linked, worker failure and initial-recorded cases passed, with the pre-existing selector flake in REG1 below distinguished from product behavior. No GUI judgment was reimplemented.

### R5 — pass: build outputs, traces, text rendering

Read each changed function with callers/callees (`Build.build`, emsdk/gitTree/link/licenses; `Lock.parse/find`; Lake target + embedding; `Export.pageWith/licensesHtml`). Link-list cleanup covers subprocess and warning failures inside `try/finally`; atomic output handling stays intact. License source paths correspond to the active SDK + Lean toolchain and missing text fails. `blankTrimmed` keeps first-line indentation; HTML content escaping handles ampersand before angle brackets. The template's one footer is checked; current page/module sources introduce no competing footer literal. License generation shares the engine target, LICENSE is an input, and the extra content trace participates even if engine bytes stay equal. Lock consistency runs before platform lookup. Curl has connection + low-speed bounds, and every git call (lazy checkout fetch included) gets the low-speed settings.

Evidence: `lake build fvtrace` rc 0; `lake env lean --run /home/eturkes/Projects/fvtrace/.scratch/maint5/reviewer-1/checks.lean` rc 0, 115/115 (Assets + Export pure + Wasm pure + blank trimming + direct failed/successful link response-file cleanup). The Licenses e2e passed (collapsed, five headings, opens, axe clean, served GUI absent). The full cold toolchain/download/wasm relink probes were not repeated; their historical evidence was read, not independently regenerated. F1 concerns release packaging's selection of these otherwise valid cached outputs.

### R7 — pass: selection + probe machinery; target release run blocked by F1

`source tools/gate.sh; shell; fanout; meta; spec; .tools/bin/actionlint` → rc 0 on target. Shell selection retains `*.sh`, adds the shebang-selected `.agent/spec-lint`, and keeps its process-substitution/list handling. The release plants change the checksum, archive version, one required license and glibc floor; the locks plants change one version token and require their specific refusal. Each calls `restore`; the target tree was clean afterward. Original `gate-probe.sh release locks` → 2 lock passes / 5 release failures, attributable to F1, not hidden as green.

To isolate the probe machinery, copied gate-probe/gate/trust/release scripts into the single-current-SDK fixture (all four `cmp` rc 0), then ran that fixture's `gate-probe.sh release`: `release-package` passed; `release-digest`, `release-version`, `release-license`, `release-glibc` each fired with rc 1; summary 5 passed / 0 failed. Its mutated release script restored byte-equal (`cmp` rc 0). Log = `release-probe-control.log`. This is explicitly a fixture control, not a successful probe run on the original warm-cache target.

### R8 — pass: sampled evidence agrees; historical claims bounded

Retrieved metadata + logs with `gh run view <id> --repo veriformatics/fvtrace` for these five ids (read-only):

| run | independent check | result |
|---|---|---|
| 40326880550 | schedule / main 7e6c4ff, all five cache steps skipped, engine compilation 704 compiled / 0 reused | matches 3e01f1a |
| 41193890240 | release dry run at 4fb754a, four builds + four installed jobs green, publish skipped; logs show both glibc 2.17, macOS 14.0 and system DLLs | matches f8735ef |
| 41192970514 | four planted platform floor failures + unrelated e2e red | each named floor cause present; e2e is gui.spec.js:151 |
| 41195130073 | seven green jobs / installs; head 59f9053 has tree bb510e458338aeab6ad48b77174b99f9ba3583cc | matches 81d0ac0's tree id |
| 41195120095 | all seven install steps fail after the 10 min bound (about 10m07–13s observed) | matches 81d0ac0's plant |

The early release commit misnames the unrelated e2e location as export.spec.js:325; dad91f5 correctly identifies gui.spec.js:151 and records the actual cause + ruling, then the changed tests. This superseded attribution is not used as evidence for a current claim. Npm registry metadata independently matches the four adopted publish dates (html-validate 10-20, oxlint 10-19, tsgolint 10-22, pnpm 10-21), all outside the seven-day hold on 10-31. Each new Lean/e2e test's red witness or mutation kill is recorded in its unit body. Old-revision red commands, all 17 full-gate executions, all pin digests/release notes and every historical count were not independently replayed; this row is the required ≥3-run spot-check plus source/evidence consistency, not an audit of every historic run. A query for gate runs on final 0c806c1 returned `[]`; no final-HEAD full-gate green is claimed here.

### R9 — pass: current docs agree with implementation

Checked the named rules, kernel E-gui/E-page, units additions, spec Artifacts, deferred queue and README Install against code. Release docs distinguish the implemented archive pipeline from the user's held first tag; README stays source-first, not a dead download link. Extracted Install sections from 30a1980 + HEAD compare byte-identical (`cmp` rc 0). The deferred release row retains tag/install acceptance + Windows floor provenance; resolved holds/half-bump/engine-download/GUI/license rows are no longer open. Kernel E-gui matches the new label-directed pending map semantics; E-page names the five license sections and served-page absence. Trace law names LICENSE + the extra output hash. No Intent or user ruling was changed by this review. F1/F2 are implementation gaps reported above, not new doc findings.

### R10 — pass: cleanup lens

Checked new helpers against existing helpers (`rg` over tools/Fvtrace/FvtraceWasm), removed code, data/state ownership and test setup/teardown. Release/fetch SHA helpers intentionally remain in standalone entry scripts; the two license assemblers serve different artifacts (native archive includes toolchain/HACL*/libuv; page excludes them). `requested` is justified state, not safely derivable from the potentially unparsed linked spec. Signal cleanup's shared promise prevents duplicate close/remove work; abandoned evaluate rejection has an explicit handler. No new dead code or unnecessary shared-infrastructure special case requiring a separate block. The two correctness findings already capture the consequential cleanup gaps. Scratch fixtures used only this folder; temporary task processes were stopped.

## Register (outside this diff's acceptance contracts)

### REG1 — existing e2e status selector races with Working

- `tests/e2e/export.spec.js:118` anchor: `await expect(page.getByRole("status")).toHaveText(` (same bytes at 405bf98).
- Focused eight-test run: seven passed; linked-what-if test failed because `getByRole('status')` matched both `#scenario-text` and visible `#working` after the 1 s busy indicator appeared. Failure output: `strict mode violation: getByRole('status') resolved to 2 elements`. `e2e.log` preserves the exact output.
- Isolated rerun of `-g 'a linked what-if goes'` → 1 passed, rc 0 (`e2e-linked.log`). This does not erase the earlier failure. Inference: selector flake when startup crosses 1 s, not a wrong engine answer. Acceptance if funded: scope the assertion to the scenario line; hold startup past 1 s and show it still passes with both status regions visible. This assertion predates the reviewed changes; no finding is charged to the new units.

## Coverage + disposition

10/10 rows adjudicated; 8 pass, 2 finding (F1/F2, both minor defects). No security-posture review (MAIN-owned). Checks actually run: incremental native build; 115 focused Lean checks; eight selected e2e cases (7 pass / 1 fail), isolated failed-case rerun (1 pass); shell/fanout/meta/spec/actionlint; original release+locks probes (2 pass / 5 fail); isolated release check/probe controls (pass); natural + boundary + post-setup signal checks; normal small driver; five CI metadata/log samples; four npm publication dates; README byte comparison. Not run: full gate/full e2e/full native suite, new CI writes, tag publication, cold wasm rebuild/download plants, timing/scale assertions, mutation campaigns, old-revision red witnesses. No such skipped check is described as green.

Final handoff: validator = expected-zero pending marker query returned rc 1 / no matches (positive control expected 1 → 1, rc 0); structural validator = 10 fixed row ids, 8 pass + 2 finding. HEAD remains 0c806c1. The last status inspection showed concurrent uncommitted edits to `tools/release.sh` + `tools/scale-gui.mjs`, after this review's target checks; reviewer made neither edit. Findings/evidence bind to committed 0c806c1, not these new bytes; no re-review of the concurrent fixes is implied. All reviewer writes stayed in this folder, except the brief's explicitly allowed build/probe executions. Build-store ownership released to MAIN.

## Re-review

Acceptance-only round against fixes f93289d + 3bb85c3; original review above retained as historical evidence.

R1: closed — On the original warm cache with both SDK trees, `DIST=/home/eturkes/Projects/fvtrace/.scratch/maint5/reviewer-1/rereview-package bash tools/release.sh package linux-x86_64` rc 0 (digest, glibc 2.17, strict synthetic check passed); `TMPDIR=/home/eturkes/Projects/fvtrace/.scratch/maint5/reviewer-1/rereview-probe-tmp bash tools/gate-probe.sh release locks` rc 0, 7 passed / 0 failed. Old 6.0.12 SDK still present. Logs: `rereview-package.log`, `rereview-probes.log` in this folder.

R6: closed — Original spawn-boundary preload witness rc 129; handler counts 1/1/1, server absent, 0 TMPDIR entries. Fresh temp folders before each campaign: original `signal-smoke.py` 3/3 + `signal-control.py` 3/3 passed (130/143/129, no live server or home). Normal `outcomes 50` driver rc 0, 13 rows / 0 nonzero row rc, 0 TMPDIR entries. Logs: `rereview-signal-at-spawn.log`, `rereview-signal-spawn-observed.json`, `rereview-signal-smoke.log`, `rereview-signal-control.log`, `rereview-signal-normal.log` in this folder.

`git status --porcelain` clean after the probes and at round close. No full gate or broader review claimed. Build-store ownership released to MAIN.
