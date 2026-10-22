# Next session: IMPLEMENT — export: live what-ifs (WebAssembly)

Paste this as the next session's body.

Build live, stacked what-ifs into the exported page (`fvtrace export --html`): the fvTrace engine, compiled to WebAssembly from Lean's C output through Emscripten, runs inside the page opened from `file://` offline, so any combination of what-ifs evaluates in the page, not only the precomputed one-click actions. The engine stays the source of every verdict; the page keeps displaying its envelope.

Context: `.agent/archive/wasm-research.md` (sourced). Lean 4.35 ships no WebAssembly build (the v4.35.0 CI job is commented out, the release has no wasm asset) and its runtime has two known stub defects a minimal build must patch; a compiled Lean 4.34 test ran in Chromium and Firefox without shared memory. First unit = a bounded spike before any design lock: compile the engine's pure evaluation entry (scenario → envelope JSON) for wasm32 with a pinned Emscripten + the 4.35 runtime sources, embed it in one HTML file, open it from `file://` offline, evaluate a two-fact what-if and compare the envelope byte for byte with the native engine; record page size, cold start and repeated-call memory. The spike decides the build route.

Met when: an exported page opened from `file://` offline evaluates a stacked two-fact what-if and its envelope equals `fvtrace eval --whatif` for the same overrides, checked in the gate (headless Chromium); the toolchain (Emscripten + runtime sources) is pinned by version + sha256 and tracked by Renovate; the page's CSP admits only what the wasm needs (`'wasm-unsafe-eval'`); README + skill describe it; the closing review ledger is clear; the full gate passes on a clean tree at the closing commit.
