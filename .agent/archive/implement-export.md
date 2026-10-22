# IMPLEMENT — export: live what-ifs (WebAssembly) (closed)

> Live stacked what-ifs in the HTML export (export precomputes one-click what-ifs only): the engine compiled to WebAssembly (Lean C output through Emscripten; `lean.h` carries `LEAN_EMSCRIPTEN`) runs in the exported page. Acceptance: an exported page, opened from `file://` offline, evaluates a two-fact what-if and matches `fvtrace claims --whatif` for the same overrides.

- [x] 3f7a0f0 U1 spike: Lean C → Emscripten 6.0.12 standalone wasm (parity, CSP control, Chromium + Firefox + WebKit) → `wasm-spike.md`; user rulings: engine built in `lake build`, page = recorded view + engine, note + notice wording
- [x] 916c71f U2 contract `kernel.md` § Page engine; consultant-5 (12 rows: K5 error src/util, 8 gaps) before code
- [x] 74105ff U3 `Receipt.Basic` split (engine closure = Init only)
- [x] 0aafd59 U4 `Fvtrace.Snapshot` (codec + evaluate); mutation 5/5
- [x] a72f198 U5 wasm build in `lake build` (`fvtrace-wasm`, pins `tools/wasm.lock`, probes, Renovate); mutation Binary 43/60 (+15 incompetent), Lock 21/22, Build helpers 12/12
- [x] cfbfaf8 U6 export page v2 + GUI engine (`web/engine.js`), differential Node 700 + Chromium 699, e2e offline two-fact = `fvtrace claims --whatif`; Export mutation 12/12
- [x] a700644 U7 docs: README, SECURITY, skill, spec
- [x] b9a9f6b … 1aa3005 U8 closing review: reviewer-14 L-CORR, reviewer-15 L-CLAIM, reviewer-16 L-GAP, reviewer-17 L-HARD, reviewer-18 L-LAW, operator-3 L-UI, MAIN L-SEC; fixes c8de182; re-review closed every row
- [x] close: Tasks cleared, Phase → MAINTAIN, route note removed (the commit that adds this file)

## Closing review (ledger `.agent/review.md`)

Lenses fixed before reading 9060fd0..b9a9f6b. Findings: 2 major (CORR-3 = GAP-4 queued call into a failed engine; HARD-3 = CORR-1 = GAP-2 frees after a NULL answer + untested ownership/panic paths) + 9 minor + 1 MAIN self-review row (BUILD-1 Windows zip), deduplicated across lenses; every row closed by a fix + one re-review round (c8de182), registered (UI-1 → deferred, SEC-1/3/4) or ruled equivalent (HARD-1, HARD-2). Gates: full `tools/gate.sh` rc=0 at c8de182 (63.3 s). Not run here: macOS + Windows builds of the engine (deferred row).
