---
paths:
  - "package.json"
  - "pnpm-lock.yaml"
  - ".node-version"
  - "lean-toolchain"
  - "tools/tools.lock"
  - "tools/wasm.lock"
  - "tools/vendor-hacl.sh"
  - "renovate.json"
  - ".github/workflows/**"
---

# Dependency + toolchain pins

- Release age (user ruling): a release enters ≥ 7 days after its publication — Renovate's `minimumReleaseAge` + every manual bump alike (supply-chain quarantine: a hijacked publish is typically caught + pulled within days); a security release (its notes say so, or it fixes an advisory against the pinned version) enters at once. An age-held bump = a `.agent/deferred.md` row with its eligibility date; so is a release held by a blocker (row names it).
- Lockfile refresh under the same floor: `rm pnpm-lock.yaml && pnpm install --config.minimum-release-age=10080`. An adopted pin still inside the window fails it (`NO_MATURE_MATCHING_VERSION`) → add `--config.minimum-release-age-exclude=<pkg>@<version>`. `pnpm audit` (gate `audit`) decides whether a held transitive release fixes an advisory that reaches us.
- Bump recipes: scanners `bash tools/pin-tool.sh <name> <version>` (all four platform lines + digests); Emscripten + Lean runtime `bash tools/pin-wasm.sh emsdk|lean <version>` (law: `wasm.md`); an Action = the tag's commit SHA (annotated tag → `gh api repos/<repo>/git/tags/<sha>` → `.object.sha`) + `# vX.Y.Z`; HACL* = `rev` in `tools/vendor-hacl.sh`, then `--check` (byte-equal to the pinned digests) before `--verify`.
- A GitHub-hosted runner label newer than actionlint's table → `.github/actionlint.yaml` `self-hosted-runner.labels`, dropped once an actionlint release knows it.
