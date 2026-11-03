# reviewer-20 — C-export, base `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| C-export | Export.lean: page assembly + bundle | pass | Read assembly + bundle and Cli callers; scratch HTML + bundle export, strict copied receipts, byte-equal evidence, offline Chromium stacked what-if + native verdict parity + details passed (`smoke.mjs`, rc 0). |
| C-export | web/engine.js: WASI loader | unknown | unknown |
| C-export | web/worker.js: protocol | reviewer-20-F1 | Arrival-order chain + id replies read; real file:// page fault injection: pending worker error handled, idle worker error forgotten → later request hangs (`red-worker-idle.mjs`, rc 1). |
| C-export | c/page_engine.c + WasmMain.lean | unknown | unknown |
| C-export | FvtraceWasm/Build.lean: build pipeline | unknown | unknown |
| C-export | FvtraceWasm/{Lock,Binary}.lean + tools/wasm.lock + pin-wasm.sh | unknown | unknown |
| C-export | tests (Export, Wasm, tests/engine, e2e export + engine) | unknown | unknown |

## reviewer-20-F1 — major — an idle Worker failure is forgotten

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:212` (`failAll`), listeners at 233–235; Worker caller of this slice.
- Contract: kernel.md E-abi (`a failed or silent worker = engine failure`), E-gui (any engine failure → dead session + recorded view + notice), wasm.md link-contract bullet (failed worker → page ends engine).
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

- `Fvtrace/Export.lean`, `web/engine.js`, `web/worker.js`: security → MAIN.

## Scope

Correctness lens only. Findings bind to kernel.md E-* + envelope actions; wasm.md; Decisions Sharing, Worker + no-WebAssembly; README Sharing. Other review deliverables unread.
