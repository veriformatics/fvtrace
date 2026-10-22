# Deferred

Off-path findings; one entry + acceptance check each.

- Live stacked what-ifs in the HTML export (export precomputes one-click what-ifs only): the engine compiled to WebAssembly (Lean C output through Emscripten; `lean.h` carries `LEAN_EMSCRIPTEN`) runs in the exported page. Acceptance: an exported page, opened from `file://` offline, evaluates a two-fact what-if and matches `fvtrace claims --whatif` for the same overrides.
- Verifier replay (user preferred content pinning for run time): `fvtrace verify` re-runs a fact's declared verifier command (e.g. `lake build`) on explicit opt-in per run. Acceptance: a pinned proof whose statement was weakened fails replay while its digest pin still matches; no command runs without the opt-in flag.
- Portability run: CI's `portability` job (macOS, Windows: `lake build` + `lake test`): macOS green; Windows after parts 1–2 (CRLF, test links): 575/579, the 4 FAILs = Lean 4.35's Windows `symlinkMetadata` = `metadata` (follows links): `skills install --dir` through a linked folder deleted the link target's files, `Receipt.resolve` threw on a dangling link, temp cleanups entered links → part 3: `Store.isLink` (real-path test) + `Store.removeTree` (never enters a link), a dangling artifact reads `missing`, tests remove their links. Owed: the push of part 3 (MAIN may push: user grant). Acceptance: both jobs green on a push.

