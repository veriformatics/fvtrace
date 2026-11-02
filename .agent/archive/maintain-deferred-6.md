# MAINTAIN — deferred rows, sixth sweep

> Work every `.agent/deferred.md` row in rank order until none remains that you can fund. (request body: see the commit log)

User rulings: 2026-11-01 row `serve` 500 = case change approved (the I/O-failure case plants its failure through `answerBody`'s `eval`); 2026-11-01 release = now, MAIN pushes `main` + the `v0.1.0` tag; 2026-11-02 macOS floor = 15 (the floor = a macOS the program runs on).

| row | commit | CI | outcome |
|---|---|---|---|
| 1 release binaries | 0b7b18b · 5cd5e3e (README Install) · tag `v0.1.0` → 958a956 · d59c16b | gate 41311597781 · 41313052479 · main 41313479163 · release 41313866322 · re-check 41317969385 | closed: v0.1.0 published (4 archives + 4 `.sha256`); `installed` ×4 green (macOS via the re-check on macos-15: the original job hit GitHub's macOS 14 brownout); `gh attestation verify` ×4 rc 0, tampered copy rc 1 |
| 2 libuv headers | — | — | waits: Lean v4.35.0, v4.36.0-rc2 + master all name libuv `GIT_TAG v1.48.0` |
| 3 fvapi client | — | — | waits: fvapi in IMPLEMENT (unit u3), no stable contract shipped |
| 4 `serve` 500 on an unwritable digest cache | c88ecfc | 41311138460 (gate shards + portability ×4) | closed (user-approved case change); the row's "CLI exits 0" was wrong: the CLI exited 2 too, fixed by the same change |
| find: e2e timeout leak | d4fed63 | 41311597781 | closed: planted timed-out spec leaves 0 servers + 0 folders (was 1 + 1) |
| find: macos-14 retired | 778a0da · 66553cc | 41316953493 + dry run 41316953453 · 41364223577 + dry run 41364223613 · plant 41364207052 | closed: `installed` on macos-15 + manual re-check (`gh workflow run release.yml -f tag=…`); floor 15.0 (user ruling), plant (target 26.0) red on the floor check |
| close | 958a956 · close commit | ci-gate on the close commit | reviewer-1 (`maintain-deferred-6/reviewer-1.md`): R1–R10 = 5 pass, 2 minor defects (R6 README commands, R8 release row) fixed in 5cd5e3e + re-review pass, 3 notes (R5/R7 wording → 958a956; R10 security → MAIN pass); delta review (`reviewer-1-delta.md`) over 958a956..66553cc + close edits: D1–D5 pass, D6 security → MAIN pass, D3 attestation evidence = `attestations.txt` |

Notes: `tools/ci-gate.sh release-…` unit names push `ci/release-*`, which also start a release dry run (useful: 778a0da's first version failed only there, its checkout naming a branch ci-gate had already deleted).
