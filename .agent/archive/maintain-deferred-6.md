# MAINTAIN — deferred rows, sixth sweep

> Work every `.agent/deferred.md` row in rank order until none remains that you can fund. (request body: see the commit log)

User rulings 2026-11-01: row `serve` 500 = case change approved (the I/O-failure case plants its failure through `answerBody`'s `eval`); release = now, MAIN pushes `main` + the `v0.1.0` tag (one-time authorization).

| row | commit | CI | outcome |
|---|---|---|---|
| 1 release binaries | 0b7b18b (README Install) | ci 0b7b18b: PENDING | PENDING |
| 2 libuv headers | — | — | waits: Lean v4.35.0, v4.36.0-rc2 + master all name libuv v1.48.0 (`GIT_TAG v1.48.0`) |
| 3 fvapi client | — | — | waits: fvapi in IMPLEMENT (unit u3), no stable contract shipped |
| 4 `serve` 500 on an unwritable digest cache | c88ecfc | 41311138460 (gate shards + portability ×4) | closed (user-approved case change); the row's "CLI exits 0" was wrong: the CLI exited 2 too, fixed by the same change |
| find: e2e timeout leak | d4fed63 | ci 0b7b18b | closed: planted timed-out spec leaves 0 servers + 0 folders (was 1 + 1) |
| close | PENDING | PENDING | reviewer-1 (`maintain-deferred-6/reviewer-1.md`): PENDING |
