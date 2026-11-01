# MAINTAIN — naoto serve

> Set up an `fvtrace serve` in the `naoto` VM of `ssh -p 9993 eturkes@59.169.212.33`. It needs to be accessible by a holder of a username and password for the main hosted page for `naoto`, but not embedded directly into that page.

User rulings 2026-11-01: URL = `naoto.eturkes.com/fvtrace/` (a path on the naoto site, behind its login, over a new host name); project = the VM's assurance copy `/home/naoto/Projects/veriformatics-tau-assurance-20261002`, empty until the trace redo; credential = a token file Caddy sends (over trusting the port); the cross-site guard in fvtrace + Caddy (the `decide` case change approved); deploy all steps at once (the RSVP session on t70 had finished).

| unit | commit | CI | outcome |
|---|---|---|---|
| serve behind a login proxy (kernel: shell, security) | 0540af7 | 41286443857 (first push 41285030178 red: `secrets`, a fixed test password → random) | `serve --token-file`, page credential sequence, relative `api/answer`, JSON-only answers; consultant-1 before code, reviewer-1 closing (F1 fixed) |
| naoto deployment (outside the repo) | — | live: user saw the page after the naoto login; Caddy log: `eturkes` GET `/fvtrace/` + modules 200, POST `/fvtrace/api/answer` 409 `no-trace` | VM user `fvtrace` + runit `fvtrace-naoto` (bwrap read-only view, `chpst`), nftables + PF (jail → :8718 alone), Caddy `/fvtrace/` behind `naoto_auth`; facts → `CLAUDE.local.md` |
| closing review + full gate | this close | the closing commit's CI gate | ledger `.agent/archive/review-maintain-naoto-serve.md` |

Off-path find → `.agent/deferred.md`: `serve` answers 500 when its data-folder entry cannot take `cache.json`.
