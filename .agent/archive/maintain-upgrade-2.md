# MAINTAIN — dependency + toolchain upgrade, second sweep (closed)

> Upgrade every dependency + toolchain pin to its latest release: list current vs latest per entry yourself; each major bump → its changelog's breaking changes against our call sites; adapt code, refresh lockfiles, rerun the full gate with scanners + drive each runnable `Artifacts` entry by its run command; a dependency held back earns a `.agent/deferred.md` row naming the blocker.
> Met when: every dependency is at its latest release or holds a `.agent/deferred.md` row, and the full gate command passes on a clean working tree.

Inventory, 2026-11-02 (latest = newest stable release; age at that date; floor = `deps.md` release age):

| entry | pinned → latest | outcome |
|---|---|---|
| Lean (`lean-toolchain`) + `lean-runtime` | 4.35.0 = latest (4.36.0-rc2 = pre-release) | kept |
| libuv headers (`tools/wasm.lock`) | 1.48.0 → 1.53.0 | held: Lean v4.35.0, v4.36.0-rc2 + master name `GIT_TAG v1.48.0` (row text → rc2) |
| Emscripten (`tools/wasm.lock`) | 6.0.13 = latest tag | kept |
| Node (`.node-version`) | 26.12.1 → 26.13.0 (5 d; LTS start, no security notes) | held: release age (11-04) |
| pnpm (`packageManager`) | 12.15.0 → 12.16.1 (6 d); 12.16.0 (6.5 d) = security release (RUSTSEC-2026-0387 signing timing leak; zstd memory exposure, pnpm#17388) | bumped to 12.16.0 (security; SLSA provenance = `pnpm/pnpm` `release.yml` @ `refs/tags/v12.16.0`, same publisher as 12.15.0); 12.16.1 held (11-03); 12.17.0 = dist-tag `next-12`, GitHub release not Latest |
| Python (CI `python-version`) | 3.15.2 = latest | kept |
| HACL* (`tools/vendor-hacl.sh`) | 504c298 → f557259 (`main` HEAD, 4 d; no releases upstream; CPython main still pins 504c298) | held: release age (11-05); trial `--check`: 5 vendored files move |
| elan-init, actionlint, betterleaks, zizmor (`tools/tools.lock`) | 4.2.4, 1.7.12, 1.9.0, 1.31.1 = latest (betterleaks 2.0.0-rc.6 = pre-release) | kept |
| @axe-core/playwright, @playwright/test, @types/culori, ajv, culori, oxlint-tsgolint, prettier, stylelint, stylelint-config-standard, typescript | 4.14.0, 1.64.1, 4.0.1, 8.20.0, 4.0.2, 7.0.2005, 3.9.10, 17.16.0, 40.0.0, 7.0.2 = latest | kept |
| oxlint | 1.89.0 → 1.90.0 (6 d) | held: release age (11-03) |
| @types/node | 26.6.5 → 26.6.6 (4 d) | held: release age (11-04) |
| html-validate | 11.17.0 → 11.18.0 (1 d) | held: release age (11-08) |
| `pnpm-lock.yaml` transitives | floored refresh: only pnpm's own 15 packages move; without the floor postcss 8.5.32, ansi-regex 6.5.0, @csstools/css-syntax-patches-for-csstree 1.1.16 | held: release age (`pnpm audit`: no known vulnerabilities) |
| Actions: checkout, setup-python, cache, upload-artifact, download-artifact, attest-build-provenance, pnpm/action-setup, setup-node, codeql-action | v7.0.1, v7.1.0, v6.1.0, v7.0.2, v8.0.2, v4.2.2, v6.1.0, v7.1.0, v4.39.1 = latest; every pinned SHA = its tag's commit | kept |
| runners `ubuntu-26.04`(`-arm`), `macos-26`, `windows-2025` | = latest GA (runner-images README) | kept; `macos-15` in `release.yml` = the floor (user ruling) |

Breaking-change review: no major bump. pnpm 12.16.0 (minor) vs our use: `pnpm add|remove|update` now fail on a `node_modules` that mismatches the settings → no call site (`rg 'pnpm (add|remove|update)\b' tools .github .claude/rules README.md package.json` rc 1; control `rg -c 'pnpm install'` on the same tree = 4 hits).

Found: `deps.md`'s lockfile recipe (`rm pnpm-lock.yaml && pnpm install …`) refreshed nothing: pnpm restored the lock from `node_modules/.pnpm/lock.yaml` ("resolution step is skipped") → recipe = `rm -rf node_modules pnpm-lock.yaml`, positive check `Progress: resolved N`, one exclude flag per package.

Found while driving `tools/gate-probe.sh`: 3bb85c3 left `tools/scale-gui.mjs`'s server exit listener after the browser's launch → a stub server exiting during it went unheard, each early-exit scale probe waited out scale.sh's 1800 s timeout (n = 2 + 4) → fixed with a bounded probe `scale-gui-serve-exit` (red rc 124 → green rc 1 in 704 ms; the probe: DID NOT FIRE at 60 s on the old driver, fired < 1 s on the fix); all 69 probes ran as their lines expect: 40 in the full run + 28 (`scale compare release locks`) + the new probe (`scale` group 17/17).

- [x] scale GUI driver: link wait from the spawn + probe `scale-gui-serve-exit` (the commit before this one)
- [x] close: pnpm 12.16.0, lockfile, `deps.md` recipe, deferred rows (Node toolchain holds, HACL*, libuv text); closed by the commit that adds this file
