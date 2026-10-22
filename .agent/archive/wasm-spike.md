# Wasm spike results (IMPLEMENT export-wasm, unit 1)

Route = Lean C (`lean -c`) → emcc 6.0.12 (wasm-binaries linux sha256 7b073a10…8fa7, release hash 6e9f6885…) → STANDALONE_WASM reactor, no Emscripten JS glue.
- Runtime: Lean 4.35.0 src/runtime @ eb6cafb7 (= `lean --githash`), single-thread (no LEAN_MULTI_THREAD), no GMP, no mimalloc, LEAN_EMSCRIPTEN, -fwasm-exceptions (legacy EH default), -std=c++20.
- Patches (3): thread.h single-thread branch lacks `<mutex>` (adopt_lock_t); uv/system.cpp stub `lean_uv_os_get_group()` lacks `uint64_t gid`; io.cpp getRandomBytes opens /dev/urandom (Init `IO.stdGenRef` initializer) → Emscripten: getentropy (WASI random_get) in 256-byte chunks.
- libuv: headers only (v1.48.0 include/, as Lean's CMake pins for Emscripten); io.cpp's `uv_strerror` → glue stub; no uv code linked.
- Own config.h (no LEAN_MIMALLOC), version.h, githash.h.
- Init C: all 653 modules regenerated with installed lean (`lean -R <prefix>/src/lean -c`), 365 s on 8 cores; stage0/stdlib C differs in 20+ modules ⇒ must regenerate. Deterministic (3 modules regenerated identical).
- Closure: Fvtrace.Page → Check, Decode, Evaluate, Engine, Encode, Json, Lint, Receipt.Basic (Binding + ReviewState split from Receipt: Std.Time/HashMap/Digest out), Model, Render ⇒ Init only, no Std.
- Compile: runtime 22 s, Init 61–107 s, app 13 s (8 cores, -O2); link 13 s.
- Output: 1,617,444 bytes (-O2) / 1,426,468 (-Oz link); gzip -9: 285,179 / 263,824. Imports (11): env.emscripten_notify_memory_growth + WASI proc_exit, fd_close, fd_read, fd_write, fd_seek, fd_fdstat_get, environ_sizes_get, environ_get, clock_time_get, random_get. Exports: memory, _initialize, fvtrace_init, fvtrace_alloc, fvtrace_free, fvtrace_evaluate, __trap, table.
- Determinism: relink identical; fresh objects rebuild identical (sha256 c061276c…bbff); no build path embedded.
- Parity (stable-canonical JSON vs native `fvtrace eval`): synthetic 8/8 (incl. O2=checked,EN2=proved + 3 refused what-ifs), self-trace 6/6, wide 20-experiment plan 2/2.
- Node: cold start 90–175 ms; eval 3–30 ms (self first 110 ms; wide 64–106 ms vs native 40 ms process).
- Chromium headless-shell, file://, offline, CSP `script-src 'sha256-…' 'wasm-unsafe-eval'` + TT 'none': ready 250 ms (base64+gunzip 99 ms, instantiate+init 85 ms), eval 5–30 ms, memory flat 18 MB over 200 calls, 0 non-file requests, 0 console errors. Control: CSP without 'wasm-unsafe-eval' → "WebAssembly.instantiate(): … violates … script-src".
- wasm-ld warns signature mismatch lean_io_create_tempfile/tempdir (Init C passes no world arg; runtime takes one): unreachable from the page.
