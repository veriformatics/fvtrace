# Deferred

Off-path findings; one entry + acceptance check each.

- Live stacked what-ifs in the HTML export (export precomputes one-click what-ifs only): the engine compiled to WebAssembly (Lean C output through Emscripten; `lean.h` carries `LEAN_EMSCRIPTEN`) runs in the exported page. Acceptance: an exported page, opened from `file://` offline, evaluates a two-fact what-if and matches `fvtrace claims --whatif` for the same overrides.
- Verifier replay (user preferred content pinning for run time): `fvtrace verify` re-runs a fact's declared verifier command (e.g. `lake build`) on explicit opt-in per run. Acceptance: a pinned proof whose statement was weakened fails replay while its digest pin still matches; no command runs without the opt-in flag.
- Portability run: CI's `portability` job (macOS, Windows: `lake build` + `lake test`): macOS green; Windows: the CRLF fix (6115818) let the run finish → 574/581, the 7 FAILs = every symlink test (the link helper's `cmd /c mklink` created nothing under Lean's per-argument quoting) → the helper uses PowerShell `New-Item -ItemType SymbolicLink` + prints a failing link's stderr. Owed: the push of that fix (MAIN may push: user grant). Acceptance: both jobs green on a push.

