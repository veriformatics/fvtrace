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
  - "lakefile.lean"
  - ".github/workflows/gate.yml"
  - "tests/engine/**"
---

# Page engine build (`kernel.md` § Page engine)

- Pipeline: `lake build` → target `engine` (`lakefile.lean`) runs `fvtrace-wasm` (`WasmMain.lean` + `FvtraceWasm/`) on Lake's C for `Fvtrace.Snapshot`'s import closure → `.lake/build/wasm/engine.b64` = base64(gzip(wasm)) → `FvtraceEngine` embeds it through `needs`. The target traces `lakefile.lean` too: Lake traces no target's own build step, so a changed step would replay the cached engine. Never committed (user ruling): every machine that builds fvtrace builds it.
- Closure = `Init` + engine modules: `Fvtrace.Snapshot` + everything it imports stay off `Std` + FFI, since the build compiles `Init`'s C alone beside the closure (a `Std` import or an `@[extern]` there fails the link). `Fvtrace.Receipt.Basic` exists for this.
- Pins = `tools/wasm.lock`, each verified before use: Emscripten archive per platform (sha256), Lean runtime sources at `lean --githash` + libuv headers (commit + sha256 of the `sha256sum` manifest sorted by path; libuv = the tag Lean's CMake builds for Emscripten, checked against it). Bumps: Renovate groups `lean-toolchain` + the `lean-runtime` line → `bash tools/pin-wasm.sh lean <version>`; Emscripten → `bash tools/pin-wasm.sh emsdk <version>` (downloads all five archives). Init C = the installed toolchain's own `lean -c` (the source's stage0 C differs from the release compiler's).
- Runtime patches = `tools/wasm/lean-runtime.patch` alone (`git diff` against the pinned tree, applied by `git apply`): single-thread `<mutex>`, `lean_uv_os_get_group` stub signature, `getRandomBytes` through `getentropy` (WASI `random_get`: Init's `IO.stdGenRef` reads entropy at start-up), `String.toList`'s end = `lean_box(0)` (4.35's `string_to_list_core` ends lists in `lean_box_uint32(0)`, a heap object on 32-bit, which `String.ofList` reads past; Lean 4.36 moves `String.toList` into Lean, lean4#15533, so that bump drops the hunk). A runtime bump re-checks each hunk. Lean's CI runs no wasm job (v4.35.0 `ci.yml`), so a 64-bit-only runtime assumption shows first here: the differential test also fails on any engine output to standard error (a panic returns a default value that may still match native).
- Link contract (`FvtraceWasm/Binary.lean`): imports ⊆ the loader's WASI functions, exports ⊇ memory + `_initialize` + `fvtrace_init|alloc|free|load|answer` (`load` + `answer` = the stateful engine, kernel.md E-state; the C bridge keeps the engine between calls; in the exported page the loader runs in a Worker: `web/worker.js`, bundled apart into the page's `fvtrace-worker` block, the page's one Trusted Types policy accepting that block's blob URL alone); linker warnings ⊆ the two temporary-file signature mismatches. A new import or warning = a loader change (`web/engine.js`) + this list, never a silenced check.
- Determinism: link order = runtime (CMake order) + sorted Init C + sorted app C + bridge; objects keyed by sha256(source + flags + toolchain) with include paths relative to the cache, so caches move between folders + hosts (Emscripten's `.emscripten` names `$CFGDIR`, written every build); two clean builds in different folders give the same bytes.
- CI cache (`ops.md` CI): the entries of `.lake/build/wasm` minus `download/` (listed through `wasm/*`: a folder entry takes every child along), keyed by OS + arch + pins + toolchain + the runtime patch (`tools/wasm/**`) + this build tool (`FvtraceWasm/**`, `WasmMain.lean`). An entry never changes under its key, so whatever renames every object or marker (flags, the toolchain string, marker format) stays in the key; else every run recompiles all ≈ 700 objects under a stale entry. A restore that fails midway sets no `cache-hit`, and the next step empties the folder. The weekly scheduled run skips the cache (downloads + pin checks every week). A run restores its own branch's entries (by name: a re-created `ci/<unit>` hits) + `main`'s, so a new `ci/<unit>` hits once `main`'s run has saved the key.
- Probes `wasm-manifest` (a planted libuv digest), `wasm-import` (a declared `env.probe` import in the bridge), `wasm-warning` (a mis-declared initializer), `wasm-build-step` (a dropped `--githash` pair in `lakefile.lean`) fire: `bash tools/gate-probe.sh wasm` (each relinks, ≈ 1 min); probe `engine-panic` (a panic line beside a correct answer) fires the differential's standard-error check: `bash tools/gate-probe.sh engine`. Unit checks = `Tests/Wasm.lean`.
