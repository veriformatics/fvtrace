# MAINTAIN — dependency + toolchain upgrade (closed)

> Upgrade every dependency + toolchain pin to its latest release: list current vs latest per entry yourself; each major bump → its changelog's breaking changes against our call sites; adapt code, refresh lockfiles, rerun the full gate with scanners + drive each runnable `Artifacts` entry by its run command; a dependency held back earns a `.agent/deferred.md` row naming the blocker.
> Met when: every dependency is at its latest release or holds a `.agent/deferred.md` row, and the full gate command passes on a clean working tree.

User ruling (asked: 8 releases younger than `renovate.json`'s `minimumReleaseAge`): a release enters ≥ 7 days after publication, a security release at once → `.claude/rules/deps.md`.

Inventory, 2026-10-23 (latest = newest stable release; age at that date):

| entry | pinned → latest | outcome |
|---|---|---|
| Lean (`lean-toolchain`) + `lean-runtime` | 4.35.0 = latest (4.36.0-rc1 = pre-release) | kept |
| Node (`.node-version`) | 26.11.1 → 26.12.1 (2 d, security release: 8 CVEs) | bumped (security) |
| pnpm (`packageManager`) | 12.14.0 → 12.15.0 (2 d) | held: release age |
| Python (CI `python-version`) | 3.13 → 3.15 (3.15.0 14 d) | bumped |
| Emscripten (`tools/wasm.lock`) | 6.0.12 → 6.0.13 (4 d) | held: release age |
| libuv headers (`tools/wasm.lock`) | 1.48.0 → 1.53.0 | held: Lean's CMake pins v1.48.0 |
| HACL* (`tools/vendor-hacl.sh`) | 8ba599b → 504c298 (upstream HEAD = CPython main's pin; vendored bytes identical) | bumped |
| actionlint, betterleaks, zizmor (`tools/tools.lock`) | 1.7.12, 1.9.0, 1.31.1 = latest (betterleaks 2.0.0-rc.4 = pre-release) | kept |
| @axe-core/playwright, @playwright/test, @types/culori, @types/node, ajv, culori, prettier, stylelint, stylelint-config-standard, typescript | 4.14.0, 1.64.1, 4.0.1, 26.6.5, 8.20.0, 4.0.2, 3.9.10, 17.16.0, 40.0.0, 7.0.2 = latest | kept |
| html-validate | 11.16.4 → 11.17.0 (3 d) | held: release age |
| oxlint | 1.88.0 → 1.89.0 (4 d) | held: release age |
| oxlint-tsgolint | 7.0.2004 → 7.0.2005 (< 1 d) | held: release age |
| `pnpm-lock.yaml` transitives | refreshed under the 7-day floor: byte-identical; fast-uri 3.1.9, ignore 7.0.13, postcss 8.5.31, postcss-selector-parser 7.1.7 younger | held: release age (`audit`: none fixes an advisory against us) |
| actions/checkout, leanprover/lean-action, actions/cache, pnpm/action-setup, actions/setup-node | v7.0.1, v1.6.2, v6.1.0, v6.1.0, v7.1.0 = latest | kept |
| actions/setup-python | v7.0.0 → v7.1.0 (1 d) | held: release age |
| github/codeql-action | v4.38.3 → v4.39.1 (2 d) | bumped to v4.39.0 (8 d); v4.39.1 held: release age |
| runner `ubuntu-24.04` (gate + codeql) | → `ubuntu-26.04` (GA 2026-09-17) | bumped; actionlint 1.7.12 lacks the label → `.github/actionlint.yaml` |
| runner `macos-15` (portability) | → `macos-26` (GA 2026-02-26) | bumped |
| runner `windows-2025` | = latest | kept |

Breaking-change review (major or major-like bumps): Ubuntu 26.04 image (gcc 15.2 default `cc`, clang 20–22, Python 3.14; `/tmp` = RAM tmpfs with a per-user quota, actions/runner-images#14777) vs our steps: CodeQL's C step compiles clean under gcc 16.2 + clang 23 locally, Playwright 1.64.1 ships ubuntu26.04 dependency lists, setup-python ships 3.15.1 for 26.04; macOS 26 (Apple clang) → portability jobs; Python 3.15 drives Emscripten, but CI's engine-cache key (OS + arch + pins + toolchain + build tool) stays unchanged here, so CI restores cached objects → a local rebuild of every object + the link under Python 3.15.1 carries that check: Lake's logged `fvtrace-wasm` command on a scratch copy of `.lake/build/wasm` minus `obj/` + outputs, `python3` = 3.15.1 → 699 compiled, 0 reused, rc 0, `engine.wasm` sha256 `1ca0e35b…` = the Python 3.14 build's (the gzip around it differs: each Python's zlib); the weekly uncached run repeats it.

- [x] close: pins, rows, `deps.md`, `.github/actionlint.yaml`, self-trace re-pin (I2: `tools/vendor-hacl.sh` digest); found while driving `export --html`: a reviewed trace's exported page runs no what-if (pre-existing) → `.agent/deferred.md` row 1; closed by the commit that adds this file
