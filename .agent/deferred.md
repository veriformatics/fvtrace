# Deferred

Off-path findings; one entry + acceptance check each.

- Live stacked what-ifs in the HTML export (export precomputes one-click what-ifs only): the engine compiled to WebAssembly (Lean C output through Emscripten; `lean.h` carries `LEAN_EMSCRIPTEN`) runs in the exported page. Acceptance: an exported page, opened from `file://` offline, evaluates a two-fact what-if and matches `fvtrace claims --whatif` for the same overrides.

