# reviewer-21 — C-export at 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-export | Export.lean: page assembly + bundle | unknown | unknown |
| C-export | web/engine.js: WASI loader | unknown | unknown |
| C-export | web/worker.js: protocol | reviewer-21-F1 | worker order preserves start/load; page RPC never settles on silence or an idle-worker error (two Chromium red probes) |
| C-export | c/page_engine.c + WasmMain.lean | unknown | unknown |
| C-export | FvtraceWasm/Build.lean: build pipeline | unknown | unknown |
| C-export | FvtraceWasm/{Lock,Binary}.lean + tools/wasm.lock + pin-wasm.sh | unknown | unknown |
| C-export | tests (Export, Wasm, tests/engine, e2e export + engine) | unknown | unknown |

## Checks

Fixed before target read: Correctness lens only; E-snap/E-eval/E-state/E-abi/E-page/E-gui/E-wasm/E-build + envelope actions; wasm.md every bullet; Sharing/Worker/no-WebAssembly Decisions + README Sharing. Caller/callee fit, assembly + module resolution, loader widths/encoding/imports/error paths, worker order/failure, C ownership, build lifecycle/cache/determinism, lock/link validation, bundle boundaries/copies/refusals, tests. Security → MAIN, register only.

## reviewer-21-F1 — major — a silent/idle-failed worker leaves every later request pending

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:211` (`failAll`), `:233` (worker-error handler), `:239` (`call`); worker caller of `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/worker.js:20`.
- Contract: kernel.md E-abi = “a failed or silent worker = engine failure”; E-gui = recorded view + engine-off notice; `web.md` request failure ends engine.
- Wrong: `failAll` rejects only current waiters, keeping no failed flag. An error while idle is forgotten. `call` has no silence deadline, so a request posted to the dead/silent worker stays in `waiting` forever. The page stays busy with “Working…” and no failure notice; later work queues behind it.
- Red command (base-generated HTML; source unchanged): `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/drive-browser.mjs silent`; rc=1. Independent idle-error variant: same command ending `idle-error`; rc=1.
- Failing output (both variants, observed 12 s): `{"busy":"true","error":"","status":"Showing the facts as recorded. Press a fact's symbol to see what would change if it were verified.","working":true}` followed by `AssertionError [ERR_ASSERTION]: E-abi/E-gui: failed or silent worker must end the engine, show recorded-view notice and stop waiting (observed for 12 s)`.
- Probe: subclass the real Worker; let real start/load finish; silence only its request reply. Idle-error variant terminates the real idle worker + dispatches its error event before dropping the next request. Screenshots `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/page-{silent,idle-error}.png`; logs `browser-{silent,idle-error}.log` in the same folder.
- Fix direction: one terminal RPC failure state + bounded silence detection; reject/clear existing + future calls, terminate worker, reset page via its engine-failure path.

## Evidence

- `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-21/drive-cli.sh` rc=0: base binary pin/check; HTML/bundle export rc=0; bundle check --strict rc=0; copied evidence `cmp` rc=0; nonempty + in-project destinations refused rc=2. Full output `drive-cli.log`.
- Browser no-WebAssembly fallback rc=0; normal browser drive reached both stacked what-ifs, then its details text assertion timed out (probe assertion under inspection; not yet a finding).

## Register

Pending.
