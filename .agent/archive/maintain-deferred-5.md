# MAINTAIN — deferred rows, fifth sweep

> Work every `.agent/deferred.md` row in rank order until none remains that you can fund. (request body: see the commit log)

User rulings 2026-10-31: the user pushes `main` once CI is green; MAIN comments on + closes the six Renovate PRs after that push; the first release is held (no tag yet); Bioconda + Homebrew dropped; release hardening = both (green-gate guard + provenance attestation); row 10's gate change approved (lint scripts by shebang); GUI clicks during a pending answer stack onto the newest requested what-if; exported pages end in a collapsed "Licenses" section.

| row | commit | CI | outcome |
|---|---|---|---|
| 1 Renovate PRs | 30a1980 | 41192366505 | verdicts recorded, #1's python 3.15.2 pin landed (security release); owed: the user's push, then MAIN's comment + close on #1 #2 #4 #5 #6 #7 |
| 2 release binaries | 4fb754a · f8735ef · f93289d | 41193890247 · dry run 41193890240 | `release.yml` + `build.yml` (four platforms on every CI run) + `tools/release.sh`; planted floors 41192970514 red on all four; held by the user (no tag); README Install back to build-from-source |
| 3 CI cache weekly run | 3e01f1a | evidence: scheduled run 40326880550 | closed: engine built from scratch in all five jobs, cache step skipped |
| 4 npm holds | 509b4c5 | 41194124487 | closed |
| 5 Emscripten 6.0.13 | 9ea10e7 | 41194639984 | closed (digest = trial's) |
| 6 Actions | 98e5b2d | 41194662673 | closed (acceptance count adapted: setup-python 1 in gate.yml + 1 in build.yml) |
| 7 libuv headers | — | — | waits: Lean 4.36.0 unreleased (v4.36.0-rc2, 10-27) |
| 8 wasm link list | 5cca526 | 41194826957 | closed |
| 9 scale-gui cleanup | 2b7eee5 · 3bb85c3 | 41194927606 | closed (red witness = a signal to the driver alone; the row's own commands passed unfixed) |
| 10 shell skips spec-lint | 038d605 | 41199815986 · plant 41199809490 | closed (user approval) |
| 11 CI Lean install | 81d0ac0 | 41195130073 · plant 41195120095 | closed (7/7 planted jobs cut at the 10 min step bound) |
| 12 fvapi client | — | — | waits: fvapi's IMPLEMENT has shipped no stable contract |
| find: half-bumped locks | aaa65d7 | 41195727072 | closed (probe `locks`) |
| find: Renovate engines pin | c099692 | 41195746650 | closed |
| find: GUI fast clicks | dad91f5 · 8a2e3fe | 41200137878 | closed (user ruling) |
| find: exported page licenses | 753c868 | 41201121623 | closed (user ruling) |
| find: engine-build downloads | 0c806c1 | 41202685165 | closed |
| find: release hardening | eda47dd | close commit's | user ruling "Add both": green-gate guard + SLSA provenance in `publish`; held with row 2 (first run = the first tag) |
| close | f93289d · 3bb85c3 · close commit | close commit's | reviewer-1 (`maintain-deferred-5/reviewer-1.md`): R1–R10 = 8 pass + 2 minor defects (R1 `package` vs a two-Emscripten cache → f93289d; R6 signal before the driver's handlers → 3bb85c3), both closed on re-review; MAIN's workflow security pass: no defect, two hardening gaps → the closing question; rules upkeep (ops.md origin story out; renovate.md: validator at the newest ≥ 7-day release + the local lookup recipe) |

Notes: the e2e failure on CI run 41192970514 (`gui.spec.js:151`) was the fast-click defect, fixed by 8a2e3fe (not a flake). Row 9's own acceptance commands passed on the unfixed driver (`timeout` signals the whole process group); the discriminating witness = a signal to the driver alone.
