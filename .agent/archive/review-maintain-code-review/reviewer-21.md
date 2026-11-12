# reviewer-21 — C-export at 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-export | Export.lean: page assembly + bundle | reviewer-21-F4 | assembly/bundle/caller checks pass; base CLI + offline page driven; damaged recorded JSON aborts page startup instead of its required notice |
| C-export | web/engine.js: WASI loader | pass | full file + C/caller read; byte lengths/unsigned pointers/memory-growth views/imports/terminal guard fit; loader tests 3/3 passed (ownership, NULL terminality, stderr routing) |
| C-export | web/worker.js: protocol | reviewer-21-F1, reviewer-21-F3 | start/load order preserved; silence/idle-error never settles; stale malformed answers + invalid detail problems fail terminal-state contract (Chromium red probes) |
| C-export | c/page_engine.c + WasmMain.lean | pass | full functions + Snapshot export ABI read; Lean refs/state replacement + byte lengths/OOM paths fit loader; Node 1,759 parity answers + 3 loader checks passed |
| C-export | FvtraceWasm/Build.lean: build pipeline | reviewer-21-F2 | full pipeline + lakefile caller read; rename failure leaks atomic temporary (red Lean probe) |
| C-export | FvtraceWasm/{Lock,Binary}.lean + tools/wasm.lock + pin-wasm.sh | pass | full files + patch read; lock/platform/manifests/link descriptors/warnings/marker/write units passed (84 total); live re-pin + malformed invalid-Wasm semantics not rerun, see limits |
| C-export | tests (Export, Wasm, tests/engine, e2e export + engine) | reviewer-21-F1, reviewer-21-F3, reviewer-21-F4 | full target tests read; 84 Lean units + 5 Node tests green (1,759 parity answers); focused Chromium passes normal/fallback but red probes expose untested terminal/damage paths |

## Checks

Fixed before target read: Correctness lens only; E-snap/E-eval/E-state/E-abi/E-page/E-gui/E-wasm/E-build + envelope actions; wasm.md every bullet; Sharing/Worker/no-WebAssembly Decisions + README Sharing. Caller/callee fit, assembly + module resolution, loader widths/encoding/imports/error paths, worker order/failure, C ownership, build lifecycle/cache/determinism, lock/link validation, bundle boundaries/copies/refusals, tests. Security → MAIN, register only.

## reviewer-21-F1 — major — a silent/idle-failed worker leaves every later request pending

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:212` (`failAll`), `:233` (worker-error handler), `:239` (`call`); worker caller of `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/worker.js:20`.
- Contract: kernel.md E-abi = “a failed or silent worker = engine failure”; E-gui = recorded view + engine-off notice; `web.md` request failure ends engine.
- Wrong: `failAll` rejects only current waiters, keeping no failed flag. An error while idle is forgotten. `call` has no silence deadline, so a request posted to the dead/silent worker stays in `waiting` forever. The page stays busy with “Working…” and no failure notice; later work queues behind it.
- Red command (base-generated HTML; source unchanged): `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/drive-browser.mjs silent`; rc=1. Independent idle-error variant: same command ending `idle-error`; rc=1.
- Failing output (both variants, observed 12 s): `{"busy":"true","error":"","status":"Showing the facts as recorded. Press a fact's symbol to see what would change if it were verified.","working":true}` followed by `AssertionError [ERR_ASSERTION]: E-abi/E-gui: failed or silent worker must end the engine, show recorded-view notice and stop waiting (observed for 12 s)`.
- Probe: subclass the real Worker; let real start/load finish; silence only its request reply. Idle-error variant terminates the real idle worker + dispatches its error event before dropping the next request. Screenshots `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/page-{silent,idle-error}.png`; logs `browser-{silent,idle-error}.log` in the same folder.
- Fix direction: one terminal RPC failure state + bounded silence detection; reject/clear existing + future calls, terminate worker, reset page via its engine-failure path.

## reviewer-21-F2 — minor — atomic writer leaves its temporary after rename fails

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/FvtraceWasm/Build.lean:109` (`IO.FS.rename tmp path`, outside the cleanup `try`).
- Contract: Correctness lens error paths/resource cleanup; `writeAtomic`'s own guarantee “a failed write … leaves no temporary either”; build-pipeline failure cleanup in the fixed brief.
- Wrong: callback exceptions remove the temporary; committing that temporary with `rename` happens outside the handler. A destination that cannot be replaced makes the build fail while leaving `engine.tmp.wasm` beside its cache output.
- Red command: `(cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/atomic-rename.lean)`; rc=1.
- Failing output: `rename failed as planted: inappropriate type (error code: 21, illegal operation on a directory)`; `temporary remains: true`; `FAIL writeAtomic: failed commit leaves engine.tmp.wasm`. Probe creates a nonempty destination directory, writes a successful candidate via the real base helper, then checks cleanup after the expected rename refusal. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/atomic-rename.log`.
- Fix direction: include final rename in the protected region; remove its temporary on either write or rename failure.

## reviewer-21-F3 — major — fatal engine answers bypass terminal handling on stale/detail paths

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:401` (JSON parsing alone before the engine queue advances), `:530` (superseded answer discarded before shape validation), `:652` (record-problem branch shared with served details).
- Contract: kernel.md E-gui = an `invalid` problem or an output that is not an envelope/details/problem ends the engine for the session; recorded envelope + engine-off notice; no further call into that instance. `web.md` = any engine failure on any request ends it.
- Wrong: worker responses get only JSON.parse in `answerOf`, and shape/fatal-problem checks occur after request-specific early returns. A superseded response `{}` is ignored, then another request enters that same engine. An `invalid` detail problem takes `cannotShow`, hiding the good recorded view instead of ending the exported engine and showing its fallback.
- Red commands: `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/drive-fatal-answer.mjs superseded` and the same ending `details-invalid`; both rc=1 against base-generated HTML. Real Worker start/load/engine kept; first request's reply alone replaced. Superseded variant synchronously clicks O2 + O3, returning `{}` for the older request.
- Failing superseded output: `{"calls":2,"title":"Synthetic study","error":"","status":"Showing a what-if: suppose O2 is verified by a checker, O3 is verified by a checker. Nothing has been recorded.","unavailable":false}`.
- Failing details output: `{"calls":1,"title":"This analysis cannot be shown","error":"planted invalid problem","status":"Showing the facts as recorded. Press a fact's symbol to see what would change if it were verified.","unavailable":true}`.
- Both fail `AssertionError [ERR_ASSERTION]: E-gui: an invalid answer ends the engine and shows its recorded-view fallback notice, even when the answer is old or for details`. Logs: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/fatal-{superseded,details-invalid}.log`.
- Fix direction: validate/classify every response within the serialized exported-engine request path before releasing the next request, independently of stale-view suppression; route every fatal response through one terminal engine-failure path.

## reviewer-21-F4 — minor — malformed recorded JSON aborts the page before its damage notice

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:272` (`JSON.parse` at module top level).
- Contract: kernel.md E-gui = “A recorded envelope that does not decode = ‘This page is damaged’.”
- Wrong: JSON shape errors reach `load`'s damage handler, but JSON syntax errors throw earlier, before wiring/rendering. A damaged export remains at “Loading the analysis…” with no visible error.
- Red command: `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/drive-damaged-json.mjs`; rc=1. Positive control asserts one exact data-block anchor, then replaces only its opening `{` with `!`; script/CSP/snapshot/engine remain unchanged.
- Failing output: `{"title":"Loading the analysis…","error":"","errorHidden":true,"pageErrors":["Unexpected token '!', \\\"!\\\"recorded\\\"... is not valid JSON"]}`; `AssertionError [ERR_ASSERTION]: E-gui: invalid recorded JSON must show This page is damaged instead of aborting the page module`. Log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/damaged-json.log`.
- Fix direction: catch recorded-block JSON syntax errors in the same startup boundary as schema/shape errors and show the damage notice.

## Evidence

- `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/drive-cli.sh` rc=0: base binary pin/check; HTML/bundle export rc=0; bundle check --strict rc=0; copied evidence `cmp` rc=0; nonempty + in-project destinations refused rc=2. Full output `drive-cli.log`.
- Browser normal + no-WebAssembly fallback rc=0. Offline file page stacked O2=checked + EN2=proved, showed claim details and five license sections; no page errors. Initial normal probe looked for the card-only text “Show the exact statement” inside the inspector; inspector uses “Exact statement:”. Corrected probe matches the intended surface; no product finding. Logs: `browser-{normal,no-wasm}.log` under the scratch folder.
- `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/unit-checks.lean`: base `.olean` Export.pureTests + Wasm.pureTests/markerTests/writeTests, rc=0, `84/84 checks passed (slowest: export-pure 73 ms, wasm-pure 10 ms, wasm-markers 1 ms)`.
- Pin script `bash -n` rc=0. LSP documentSymbol on base `web/engine.js` confirmed JavaScript language coverage.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Export.lean:170` + `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:161`: CSP, Trusted Types, HTML escaping → security → MAIN.
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/tests/engine/engine.test.mjs:65`: Node's stderr assertion runs in request branches, so final refused-load cases have no final assertion; Chromium checks the accumulated errors at the end.
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/pin-wasm.sh:50`: re-pin curl/git calls omit the build tool's stall bounds; build-time fetches do carry them.

## Limits

- No full gate, full page-engine rebuild, mutation campaign or clean-build determinism comparison (brief). Build/cache/determinism review = source + targeted unit checks; two-host/folder determinism + all-platform downloads not independently confirmed.
- `tools/pin-wasm.sh` live repin not run (would download five archives / upstream trees); syntax + full source + current pins + parser/platform/manifest tests checked.
- Binary parser reviewed as the link-contract reader for linker-produced modules, not a general WebAssembly validity checker.
- Engine Node suite ran under local offload, rc=0, 5/5 tests: 1,072 differential comparisons over 21 snapshots + 687 request comparisons, seed 20261022, duration 103.343 s; log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/node-engine.log`. Ordinary cases include 40 seeded random stacks; 4 MB/12,000-claim cases sample a few actions/details/specs (the suite's existing bounds), not every large-case item.
- Playwright full e2e suite not rerun; full target e2e sources read + focused real Chromium file-page checks run. Normal/silent/idle-error screenshots inspected.
- Target + primary files unchanged except this deliverable; probes/logs only under assigned scratch. Isolated test-tree copy + transient rename probe removed after the runs; red probes + base-generated page + logs retained for MAIN's rerun. No server started.

reviewer-21-DONE-1
