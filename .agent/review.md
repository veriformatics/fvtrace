# Review ledger — MAINTAIN naoto serve (closing diff 41eca44..f032dd0 + fixes)

reviewer-1 (reviewer, every lens L1–L8) + MAIN (security lens L9). Rulings by MAIN.

| id | lens | reviewer verdict | ruling |
|---|---|---|---|
| L1 | Correctness: CLI token file | pass | accepted |
| L2 | Correctness: Server JSON type | pass | accepted |
| L3 | Correctness: GUI credentials | finding F1 (minor) | accepted → fixed: `forgetToken(token)` retires the refused token alone; e2e `access.spec.js` "a late refusal…" red before (`:112` Received: null), green after; reviewer witness `token-race.mjs` rc 1 → 0 |
| L4 | Contract ↔ code | finding F1 | as L3; `server.md` names the compare |
| L5 | Cleanup | pass | accepted |
| L6 | Altitude | pass | accepted |
| L7 | Tests | pass | accepted (F1 coverage added) |
| L8 | Docs | pass | accepted |
| L9 | Security (MAIN): token never printed/opened; type check after token; cross-origin preflight → Caddy 401 / fvtrace 405; same-origin trust documented | pass | — |
| S1 | secrets stage (CI run 41285030178): `generic-password` at `tests/e2e/proxy.spec.js:12` (fixed test password) | — | fixed: random per run; working-file scan 1 → 0 findings; commit amended (history) |
