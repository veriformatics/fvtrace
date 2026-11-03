# reviewer-20 — C-export, base `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| C-export | Export.lean: page assembly + bundle | pass | Read assembly + bundle and Cli callers; scratch HTML + bundle export, strict copied receipts, byte-equal evidence, offline Chromium stacked what-if + native verdict parity + details passed (`smoke.mjs`, rc 0). |
| C-export | web/engine.js: WASI loader | pass | Read all imports, pointer/length transfer + fail-stop paths; loader tests 3/3 pass; focused native/wasm differential 26 byte-equal answers on exported + Unicode/memory-growth snapshots, no stderr. |
| C-export | web/worker.js: protocol | reviewer-20-F1 | Arrival-order chain + id replies read; real file:// page fault injection: pending worker error handled, idle worker error forgotten → later request hangs (`red-worker-idle.mjs`, rc 1). |
| C-export | c/page_engine.c + WasmMain.lean | pass | Read ownership/refcount transitions, byte lengths, initialization + CLI tool wrapper; loader frees 2 input buffers + output per successful call and stops after NULL; 26 byte-equal stateful answers including NUL refusal + UTF-8/memory growth. |
| C-export | FvtraceWasm/Build.lean: build pipeline | pass | Read fetch→digest→patch→generate→compile→link→check→embed + Lake trace integration; markers/atomic paths in 84/84 pure checks pass; native tool rejects planted githash mismatch before fetch. Fresh build/determinism not rerun (brief). |
| C-export | FvtraceWasm/{Lock,Binary}.lean + tools/wasm.lock + pin-wasm.sh | pass | Read parser + required imports/exports, lock + repin recipe + all runtime patch hunks; existing planted malformed wasm, kind, missing export, lock/version/platform/manifest/warning tests pass within 84/84 checks. Re-pin downloads not rerun. |
| C-export | tests (Export, Wasm, tests/engine, e2e export + engine) | pass | Read every assigned test + case generator; 84/84 focused Lean checks, loader 3/3, 26-answer focused differential + actual file:// offline smoke pass; existing e2e failure fixtures cover pending failures, not F1's idle failure. Full differential/e2e suites not rerun. |

## reviewer-20-F1 — major — an idle Worker failure is forgotten

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:212` (`failAll`), listeners at 233–235; Worker caller of this slice.
- Contract: kernel.md E-abi (`a failed or silent worker = engine failure`), E-gui (any engine failure → dead session + recorded view + notice), web.md address-hash + engine bullet (any engine failure on any request ends it for the session).
- Wrong: `failAll` rejects only entries currently in `waiting`, then clears them. It records no failure, changes no `engineDead`, and leaves the fulfilled `engineStart` reusable. An `error` / `messageerror` after load while no request waits disappears. A later call posts to the failed Worker and waits forever. This is distinct from the covered pending-call failure.
- Proof command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-20/red-worker-idle.mjs` (requires `claims.html` from `smoke.mjs`; base binary + source at `48bc51d`). rc 1:

```text
positive control: worker error with a pending request => engine failure notice
idle worker failure: {"notice":"","busy":"true","calls":1,"dead":true}
AssertionError [ERR_ASSERTION]: an idle worker error must end the engine; the next request must not enter a dead worker or hang
+ ''
- 'This browser cannot run the what-ifs on this page, so it shows the facts as recorded.'
```

- Fault injection terminates the real Worker + dispatches its browser error event after load has settled. Positive control dispatches the same event while a request waits. All page logic + its original script remain unmodified.
- Fix direction: make Worker failure persistent at the client boundary, reject future calls immediately + route the idle event through session failure; terminate/revoke the failed Worker resources.

## Register

- `Fvtrace/Export.lean:162`, `web/engine.js:46`, `web/worker.js:26`: security → MAIN.

## Scope

Correctness lens only. Findings bind to kernel.md E-* + envelope actions; wasm.md; Decisions Sharing, Worker + no-WebAssembly; README Sharing. Other review deliverables unread.

## Verification

All paths below = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-20/` unless absolute.

| command | result |
|---|---|
| `node smoke.mjs` | rc 0; HTML + bundle; strict bundled receipt; copied artifact byte equality; offline Chromium stacked what-if verdicts equal native + details; `smoke.png` rendered + inspected |
| `node refusals.mjs` | rc 0; project-local HTML refused (2), nonempty bundle refused (2), absent format refused (2), missing evidence reported (1); build runtime-hash mismatch refused (1) |
| `TMPDIR=<scratch> FVTRACE_HOME=<scratch>/home LEAN_PATH=<base>/.lake/build/lib/lean lean --run <scratch>/pure.lean` from `/tmp` | rc 0; 84/84 export/wasm pure + marker + atomic checks |
| `TMPDIR=<scratch> FVTRACE_HOME=<scratch>/home node --test tests/engine/loader.test.mjs` from `<scratch>/tree` | rc 0; 3/3 loader checks; private copy's `cases.mjs` changes only FVTRACE_HOME to the mandated scratch home |
| `TMPDIR=<scratch> FVTRACE_HOME=<scratch>/home node differential.mjs` | rc 0; 26 byte-equal native/wasm answers, 2 snapshots (exported + Unicode/memory growth), no stderr |
| `node red-worker-idle.mjs` | rc 1; F1; pending-call positive control passes |

Limits: full rebuild, clean-build determinism, re-pin downloads, full Node differential + full Playwright suites, performance gates + mutation campaigns not run. Fresh-fetch, cross-platform + two-clean-build behavior remains unconfirmed dynamically here; read build implementation + recorded `units.md` evidence instead. No server started. Base + primary code unchanged; scratch-only harness/copy/log/HTML/screenshot artifacts retained for MAIN's reruns.

## Completion

7/7 target rows adjudicated: 6 pass; 1 finding (major). Open cells = 0.

reviewer-20-DONE-1
