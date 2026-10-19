# Deferred

Off-path findings; one entry + acceptance check each.

- Live stacked what-ifs in the HTML export (export precomputes one-click what-ifs only): the engine compiled to WebAssembly (Lean C output through Emscripten; `lean.h` carries `LEAN_EMSCRIPTEN`) runs in the exported page. Acceptance: an exported page, opened from `file://` offline, evaluates a two-fact what-if and matches `fvtrace claims --whatif` for the same overrides.
- Verifier replay (user preferred content pinning for run time): `fvtrace verify` re-runs a fact's declared verifier command (e.g. `lake build`) on explicit opt-in per run. Acceptance: a pinned proof whose statement was weakened fails replay while its digest pin still matches; no command runs without the opt-in flag.
- CodeQL code scanning: a private GitHub repo needs a paid Code Security license; CodeQL covers the GUI JS, the FFI C + workflows, not Lean. Acceptance: once the repo is public, `.github/workflows/codeql.yml` (javascript-typescript, c-cpp, actions; `security-extended`) runs green on `main`.
