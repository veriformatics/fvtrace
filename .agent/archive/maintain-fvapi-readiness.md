# MAINTAIN — fvapi readiness (2026-10-31)

Request: "`fvapi` just finished PROTOTYPE phase, so it is in a minimally built-stage. Is this sufficient to continue work in this repo?"

## Answer

- No fvTrace queue row waits on fvapi.
- fvTrace's fvapi client: not yet (user ruling: wait for fvapi's IMPLEMENT). Blockers = fvTrace's own Product ruling (nothing shipped mentions the service until it exists) + fvapi v0's disposable contract, no caller identity, provisional bundle terms; compute endpoints (plan search, replays, sweeps) absent but no prerequisite of a library client; Lean 4.35 `Std.Http` has no HTTP client + no TLS ⇒ the client's transport = a stack decision. Row → `.agent/deferred.md` (5c959c9).
- Probe (fvapi 16bcad0): a v0 bundle becomes a receipt with no fvTrace change; fvTrace's replay checks output stability alone (a `sorry` proof pins + replays rc 0); fvapi's client replay, as the fact's replay argv, fails it on its axiom allowlist.

## Units

- [x] 5c959c9 fvapi readiness → deferred row
- [x] (this commit) replay notices + replay log (user rulings: a failed `pin --replay` keeps the pin; failed `pin --replay` | `verify --run` leave a lasting notice cleared by a pass; events stay readable in a log; GUI fact details + page line + `check`; `check --strict` fails; review unaffected)

## Teammates

| name | role | verdict |
|---|---|---|
| scientist-1 | scientist | probe claims K1–K3 supported; K5 + K0 overstated → adopted (fvapi client as argv; compute endpoints no prerequisite) |
| consultant-1 | consultant | contract: 3 sound, 4 gap, 1 contradiction, 1 testability gap → all adopted (positional updates, write guards, log without a trace read, envelope `notices`, legacy byte equality on notice-free inputs) |
| tester-1 | tester | diff-blind suite: 13 rows, 177 checks red on 5c959c9; one test called `pin --json` (no such option) → fixed by MAIN |
| reviewer-1 | reviewer | closing diff: 10 rows, 7 pass, 3 findings (concurrent appends interleave, blank log line uncounted, linked trace logged unresolved) → fixed, red tests added, probes green |

Closing review table (reviewer-1, anchors repo-relative, line numbers at its read): `review-maintain-fvapi-readiness.md`.
