---
paths:
  - "FvtraceWasm/**"
  - "FvtraceWasm.lean"
  - "WasmMain.lean"
  - "FvtraceEngine.lean"
  - "Fvtrace/Snapshot.lean"
  - "Fvtrace/Receipt/Basic.lean"
  - "c/page_engine.c"
  - "tools/wasm.lock"
  - "tools/wasm/**"
  - "tools/pin-wasm.sh"
---

# Page engine build (`kernel.md` § Page engine)

- Pipeline: `lake build` → target `engine` (`lakefile.lean`) runs `fvtrace-wasm` (`WasmMain.lean` + `FvtraceWasm/`) on Lake's C for `Fvtrace.Snapshot`'s import closure → `.lake/build/wasm/engine.b64` = base64(gzip(wasm)) → `FvtraceEngine` embeds it through `needs`. Never committed (user ruling): every machine that builds fvtrace builds it.
- Closure = `Init` + engine modules: `Fvtrace.Snapshot` + everything it imports stay off `Std` + FFI, since the build compiles `Init`'s C alone beside the closure (a `Std` import or an `@[extern]` there fails the link). `Fvtrace.Receipt.Basic` exists for this.
- Pins = `tools/wasm.lock`, each verified before use: Emscripten archive per platform (sha256), Lean runtime sources at `lean --githash` + libuv headers (commit + sha256 of the `sha256sum` manifest sorted by path; libuv = the tag Lean's CMake builds for Emscripten, checked against it). Bumps: Renovate groups `lean-toolchain` + the `lean-runtime` line → `bash tools/pin-wasm.sh lean <version>`; Emscripten → `bash tools/pin-wasm.sh emsdk <version>` (downloads all five archives). Init C = the installed toolchain's own `lean -c` (the source's stage0 C differs from the release compiler's).
- Runtime patches = `tools/wasm/lean-runtime.patch` alone (`git diff` against the pinned tree, applied by `git apply`): single-thread `<mutex>`, `lean_uv_os_get_group` stub signature, `getRandomBytes` through `getentropy` (WASI `random_get`: Init's `IO.stdGenRef` reads entropy at start-up). A runtime bump re-checks each hunk.
- Link contract (`FvtraceWasm/Binary.lean`): imports ⊆ the loader's WASI functions, exports ⊇ memory + `_initialize` + `fvtrace_init|alloc|free|evaluate`; linker warnings ⊆ the two temporary-file signature mismatches. A new import or warning = a loader change (`web/engine.js`) + this list, never a silenced check.
- Determinism: link order = runtime (CMake order) + sorted Init C + sorted app C + bridge; objects keyed by sha256(source + flags + toolchain) with include paths relative to the cache, so caches move between folders + hosts; two clean builds in different folders give the same bytes.
- Probes `wasm-manifest` (a planted libuv digest), `wasm-import` (a declared `env.probe` import in the bridge), `wasm-warning` (a mis-declared initializer) fire: `bash tools/gate-probe.sh wasm` (each relinks, ≈ 1 min). Unit checks = `Tests/Wasm.lean`.
