---
paths:
  - ".github/**"
  - "tools/install-lean.sh"
  - "tools/ci-gate.sh"
  - "renovate.json"
---

# CI workflows

- Triggers = `main` + `ci/**` pushes, PRs, weekly; `gate` job (ubuntu) = one matrix entry per shard, each `tools/gate.sh --shard`; `portability` job = `build.yml` on the four release platforms (linux x86_64 + arm64, macOS arm64, Windows x86_64: `lake build` + `lake test` + the checked release archive); `release.yml` = a `v*` tag → GitHub Release (law: `release.md`); `codeql.yml` = GitHub code scanning alone (`security-extended`: javascript-typescript, actions, c-cpp = the FFI shim + the page engine bridge, compiled as `c-analyze` sees them). Every external `uses:` pinned by full SHA (in-repo calls: `$/…`), `contents: read` (CodeQL's job adds `security-events: write` for its upload, release `publish` `contents: write`), `persist-credentials: false`. Update automation = Renovate (`renovate.json`): npm, Actions digests, `lean-toolchain` + the `tools/wasm.lock` runtime line (one group), Emscripten (`tools/wasm.lock`), `tools/tools.lock` versions (digests via `tools/pin-tool.sh` | `tools/pin-wasm.sh`); release age + bump recipes = `deps.md`. Lean in CI = `tools/install-lean.sh` (elan-init pinned by sha256 in `tools/tools.lock`; every download bounded + retried, each attempt ≤ 180 s (TERM at 179 s, KILL at 180 s: a download that ignores TERM still ends; probe `install`); the step's `timeout-minutes: 10` = the outer bound, so a stalled install ends the job within minutes, not at its 60 min limit). Every job that runs `lake build` provisions Python (`actions/setup-python`) + restores the page engine's build folder from the Actions cache (law: `wasm.md` CI cache), except on the weekly scheduled run + a release build, which build it from scratch.
