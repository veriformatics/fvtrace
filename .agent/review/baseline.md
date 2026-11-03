# Baseline (MAIN) — rows B1–B10 at 48bc51d

| row | evidence so far | state |
|---|---|---|
| B1 | CI `gate` run 41551780111 (48bc51d): checks, lean, e2e shards + portability ×4 green; `codeql` 41551779966 green; open code-scanning alert #1 (`js/remote-property-injection`, `tests/e2e/access.spec.js:44`) → M-1 | finding M-1 |
| B2 | `offload run -- bash tools/gate-probe.sh` (local slot, primary tree) running; every probe so far `fired` | running |
| B3 | `lake build` (no-op at HEAD) + `fvtrace --help` rc 0 + `--version` = `fvtrace 0.1.0`; `lake test` = CI lean shard green | pass (pending none) |
| B4 | `.scratch/review/main/b4.sh` (log `b4.log`): every command on the synthetic copy, self-trace (`check --strict` rc 0), fresh project, bundle round trip, export refusal inside the project (rc 2) — leads L1–L3 (`leads.md`) | leads routed |
| B5 | `b5.mjs` (Playwright Chromium, base binary): served GUI loads, what-if O2, C2 details, Text view, tour 13 steps at 1280×900 + 390×844 (settled card never overlaps its spotlight; a 0.9 s sample overlapped mid-scroll at phone step 6, 3 s settled = clear), no-token page = access notice; no console error | pass |
| B6 | exported page (file://): recorded view, stacked what-if O2 → O3 → EN2 by the page engine (C2 → Conditional), details; bundle → `check --strict` rc 0 + `claims` | pass |
| B7 | `spec-lint` rc 0; `vendor-hacl.sh --verify` rc 0; `pin-tool.sh` ×4 + `pin-wasm.sh lean 4.35.0` + `emsdk 6.0.13` = no diff (control: planted actionlint digest restored); `release.sh package linux-x86_64` + `check` passed (glibc ≤ 2.17); `mutate.mjs --list` ok, `--help` crashes → M-2; `compare.sh` base vs base: 1238 runs, 0 differing, 0 timeouts, rc 0; L-T14 mechanical half: `CLAUDE.md` + 9 `.claude/agents/*.md` + `.agent/spec-lint` byte-equal to `~/.local/app/agents/claude/` template; pending: `fast-gate.sh`, `ci-gate.sh` | running |
| B8 | pending: nixbox idle (0/2) | pending |
| B9 | pending: `e2e-load.sh gate` on nixbox | pending |
| B10 | pending: `ci/release-*` dry run + `gh workflow run release.yml -f tag=v0.1.0` (confirm with user: dispatch = shared CI state? read-only re-check) | pending |
