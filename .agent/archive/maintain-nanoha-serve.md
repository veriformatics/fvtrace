# MAINTAIN — nanoha serve

> Similar to how we brought a version of this to the `naoto` VM in `ssh -p 9993 eturkes@192.168.40.50`, I'd like you to bring a version to the `nanoha` VM.

User rulings 2026-11-02: project = the dashboard's live report (`apex_ps`, a link the dashboard moves to a new worktree at every saved version), over a fixed copy; "actually it would be good if naoto worked like that too" → naoto moves from its assurance copy to its live report (`tau-mutant-integration-ng`); deploy all at once (t70 Caddy + PF, VM firewall, user, service, binary).

| unit | commit | CI | outcome |
|---|---|---|---|
| nanoha deployment (outside the repo) | — | jail `nc` POST: snippet token → 409 `no-trace`, wrong → 403; Caddy: every nanoha `/fvtrace` route → 401 without a login, public sites 200; t70 → VM :8718 refused | release v0.1.0 (attested, `release.sh check`), VM user `fvtrace`, `/usr/local/sbin/fvtrace-nanoha` (bwrap: current worktree bound at `apex_ps` → entry `apex_ps-0d865250a086` for any worktree), runit `fvtrace-nanoha` following the link (stand-in link under a scratch runsv: a → b rebound, `sv restart` + `sv down` clean), nftables (file ≡ live via `unshare -n`, egress table byte-equal), Caddy `/fvtrace/` behind `nanoha_auth` |
| naoto → live report (outside the repo) | — | jail: 409 `no-trace` / 403 | same wrapper over `tau-mutant-integration-ng` (entry `tau-mutant-integration-ng-f6bc9808bb92`), binary 0540af7 → v0.1.0, stale assurance-copy entry + empty `~naoto/.local/share/fvtrace` + old binary removed |
| t70 PF persisted | — | `pfctl -nvf /etc/pf.conf` ≡ `pfctl -sr` (66 rules) + nat/rdr | naoto's 8718 rule was loaded but missing from `/etc/pf.conf` (a reboot would have dropped the naoto page): written as is (file ≡ loaded), then `{ naoto, nanoha }` loaded under a 180 s rollback, cancelled after a fresh SSH login |
| close | this commit | the closing commit's CI gate | facts → `CLAUDE.local.md` (Served VM pages); two finds → `.agent/deferred.md` |

Not run: a logged-in page view through Caddy (no nanoha credential here) → the user's browser check.
