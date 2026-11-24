# MAINTAIN — deferred rows, seventh sweep

> Work every `.agent/deferred.md` row in rank order until none remains that you can fund. (request body: see the commit log; resumed once after the session host was killed: "Resume the work of the last session based off of the Claude transcript.")

User rulings (one AskUserQuestion, 2026-11-24): moving link = key on the link; proxied record problems = name the person who acts, no command (`--token-file` or `--host`); reused facts = the check rule (a reuse of a fact that must be verified must be verified too, through reuses of reuses; engine + ceiling read the same test).

| row | commit | CI | outcome |
|---|---|---|---|
| Node holds | a98a699 | 45196113395 | closed: newest eligible Node 26.13.1, pnpm 12.21.0, oxlint 1.94.0, @types/node, html-validate |
| HACL* rev | 77c0fce | 45198620546 | closed: f557259, 5 files re-vendored, I2 re-pinned |
| moving link | f03c3c7 | 45412433098 | closed (user ruling): `Store.keyOf` + PWD; README |
| proxied wording | eb07121 | 45414702056 | closed (user ruling): `Server.nextStep`; e2e both flags |
| fuzz targets | 39f6756 | 45208133076 + fuzz 45208133133 | closed: FvtraceFuzz ×5, `tools/fuzz.sh`, gate `fuzz` + probe, CI daily |
| property-test audit | 72da483 · 79e0637 | 45211087927 · (2301ba0's) | closed: table + seeded properties; kills + 15 survivor rulings (reviewer-2), `commandProperty` |
| CI speedup | bf87c94 · 0cb792a | 45308773423 · 45317170491 (measured on 13eb794: 45312646508) | closed: Lake cache restored; jobs 207 + 142 s |
| mutation credit | 2301ba0 | 45334807851 | closed: Json 326, Decode 71, Snapshot 5 (`units.md` § Mutation credit) |
| scale receipts | 13ba7a1 | 45310668144 | closed: no action rows without an action |
| meta-lint fences | 6c2c0d9 | 45311488877 | closed: sections as spec-lint reads them + probe |
| human-facing text | 3a1e32c | 45321613215 | closed: 140 splits, 28 kept, F1 + F2 fixed |
| serve bind hint | 13eb794 | 45312646508 | closed: `Cli.bindHint` |
| instantiation (reused facts) | 36349ab · 73706f5 (review fixes) | 45424388289 (macOS no-runner flake → rerun green) | closed (user ruling): trace-level `mustVerify`; chain cost measured → owed to the user (deferred) |
| libuv headers | — | — | waits: Lean v4.36.0 names v1.48.0 |
| fvapi client | — | — | waits: fvapi in IMPLEMENT |
| close | 73706f5 (review fixes) · close commit | 45428147840 (attempt 3: attempts 1 + 2 = macOS no-runner, class `flake`) · ci-gate on the close commit | reviewer-3 (`maintain-deferred-7/reviewer-3.md`): R1–R10 over 77bf045..36349ab = 6 pass, 3 defects (R4a `//usr` key, R7a/b Lake-cache provision checks, R10a stale testing.md pointer) + R8a/b README wording fixed in 73706f5 (probes `provision-lake-sha`, `provision-lake-weekly-or`), notes R1n → Decisions wording, R9n → units.md wording; re-review 6/6 pass; security S1–S6 = MAIN (`main-security.md`: 5 pass, S4 reuse-chain cost owed); macOS no-runner flakes: 36349ab ×1, 73706f5 ×2 (rerun `--failed`, ledger classed) |

Finds → `.agent/deferred.md` rows: scale GUI what-if rows on receipts; faithfulness.md "cannot state it" overstatement; skill frontmatter YAML check; `Json.parse` fuel diagnostics on nested arrays; reuse-chain cost (the user's choice: proved linear index | "source listed earlier" WF rule | accept); reference-host timing of 36349ab (host clock); `meta-lint-prototype` `.git/index` in a linked worktree.
Reference-host timing (fast.md, 36349ab): not graded, owed (deferred row; the user's choice: restore the host | another reference host | accept these reds). Run 1 (load 9.19 at start, after the build): 75 bounds; run 2 (built tree, load 4.57): 91 bounds; one row's walls 3.01–7.54 s, then 10.01–12.58 s, same binary. Host observations, cause not identified: cores 400–685 MHz with a core busy (governor `performance`), clock ≤ 500 MHz in 52 % of host-log samples in both runs, package 63–87 °C, Dell SMM fan 0 RPM under load, throttle counters +0 over a 10 s busy loop, throttle events in ≈ 10 % of samples, background jobs ≈ 2–3 CPUs (recorded: 1–1.7). Code evidence: desktop A/B eb07121 vs 36349ab (idle, wide n = 46,081 alone, ×3 each: `eval` 2.95–3.01 vs 3.11–3.14 s, `gaps` 2.20–2.25 vs 2.31–2.41 s, `details fact` equal) + `compare.sh` 0 diffs.
