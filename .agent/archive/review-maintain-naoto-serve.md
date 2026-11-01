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

## reviewer-1 table

| id | lens × slice | verdict | anchors + failure scenario | severity |
|---|---|---|---|---|
| L1 | Correctness: `Fvtrace/Cli.lean` `tokenOf`, `serveCmd` token-file path (read, refusal messages, opener off, output lines), usage text | pass | `Fvtrace/Cli.lean:945–947,1032–1045,1072–1092`; CLI smoke rc=0; built Lean suite 1831/1831 | — |
| L2 | Correctness: `Fvtrace/Server.lean` `Req.contentType`, `isJson`, `decide` order, `reqOf` | pass | `Fvtrace/Server.lean:73,88–89,118–125,224–230`; built Lean suite 1831/1831 + HTTP probe 9/9 (JSON 200; other types 415; token before type 403; OPTIONS 405; foreign Host 421) | — |
| L3 | Correctness: `web/app.js` `ask` credential sequence, `forgetToken`, `offered` lifetime under concurrent requests, relative `api/answer` | finding: F1 | `web/app.js:444,126–130`; delayed refusal of old stored token erases another tab's accepted current token → reload loses access | minor |
| L4 | Contract ↔ code: `.agent/spec.md` Decisions GUI access ("Behind a login proxy"), `.claude/rules/server.md`, `.agent/contracts/kernel.md` V-serve — every changed clause holds in code, and no code behavior lacks its clause | finding: F1 | Accepted address-token persistence fails across delayed rejection of a different stored token; remaining changed clauses match their owners + HTTP behavior | minor |
| L5 | Cleanup: helper reuse, duplication, dead code (e.g. unused `link` under `--token-file`), comments = why not what, repo idiom | pass | Existing token helper reused; credential loop deduplicates candidates; unconditional `link` construction harmless; no merge-blocking cleanup defect | — |
| L6 | Altitude: special cases on shared mechanisms vs a fix in the mechanism | pass | CLI owns token-file I/O; server owns access/type gate; page's common request path owns credentials + relative URL; no proxy-specific caller bypass | — |
| L7 | Tests: `tests/e2e/proxy.spec.js`, `tests/e2e/fvtrace-server.js`, `tests/cli/smoke.sh`, `Tests/Cli.lean`, `Tests/Server.lean` — each asserts observable behavior, would fail on the defect it names (commit body red claims plausible), no flakiness (ordering, shared tabs, timing), setup/teardown symmetric | pass | Target tests read with helpers/callers; proxy e2e 1/1, CLI smoke rc=0, Lean 1831/1831. Assertions observe board/header/storage/output/status, setup uses distinct temp roots + free ports, normal teardown closes context/proxy/binary; no source-level ordering flaw found. F1 lacks coverage, rather than invalidating the claims these cases make | — |
| L8 | Docs: `README.md` Sharing text + `serve` help text accurate vs behavior; human-facing register (short sentences, imperative, no filler) | pass | `README.md:221–246`, `Fvtrace/Cli.lean:77–85`; token generation, read-once/restart, no opener/link, upstream headers, slash redirect + origin trust fit implementation | — |

## F1 re-review

Verdict = **accepted**. F1 closed for the uncommitted fix; original target verdict table above remains the review of `41eca44..f032dd0`.

Fixed check set = F1 acceptance alone, three rows below; no other scope re-opened.

| acceptance check | verdict | evidence |
|---|---|---|
| Original two-tab witness preserves current token + fresh-tab reload | accepted | `token-race.mjs` against rebuilt binary → rc=0; current token remains after older tab's 403; reload → `board rendered` |
| Same-value refusal still removes stale stored token | accepted | `proxy.spec.js` stale-stored phase → stored token null, next reload sends no Bearer; focused e2e rc=0 |
| New committed-test candidate + proxy e2e pass | accepted | `access.spec.js:75` late-refusal case + `proxy.spec.js:68` login-proxy case → 2/2, rc=0 |

Anchors: `web/app.js:128` = `function forgetToken(token) {`; `:129` = `if (kept === token) kept = undefined;`; `:131` = `if (localStorage.getItem(tokenKey) === token) localStorage.removeItem(tokenKey);`; `:446` passes the refused token into that helper. The changed helper now preserves a different current in-memory or stored value.

Commands (repo cwd `/home/eturkes/Projects/fvtrace`; temporary outputs remain under reviewer scratch):

```sh
TMPDIR=/home/eturkes/Projects/fvtrace/.scratch/reviewer-1/tmp node /home/eturkes/Projects/fvtrace/.scratch/reviewer-1/token-race.mjs
TMPDIR=/home/eturkes/Projects/fvtrace/.scratch/reviewer-1/tmp pnpm exec playwright test tests/e2e/access.spec.js tests/e2e/proxy.spec.js --grep 'a late refusal|behind a login proxy' --workers=1 --output=/home/eturkes/Projects/fvtrace/.scratch/reviewer-1/playwright-rereview-results
```

## consultant-1 table (contract before code)

| id | question | verdict | evidence | recommended change |
|---|---|---|---|---|
| C1 | token-file format rule (text trimmed, ≥ 32 of `[A-Za-z0-9_-]`, else exit 2) sound + sufficient? | risk | `/home/eturkes/Projects/fvtrace/Fvtrace/Cli.lean:945-947` trims ASCII whitespace + checks length/alphabet; `/opt/lean/src/lean/Init/Data/Char/Basic.lean:146-147` confirms `isAlphanum` is ASCII letters/digits. The predicate also accepts 32 identical letters: format alone establishes no randomness or file protection. | Keep parser rule; add operator requirement: “Generate a secret with at least 128 bits of randomness. Restrict access to authorized operators and the service. Restart fvtrace after changing the file.” Name ASCII trimming in the precise contract. |
| C2 | `--token-file` ⇒ no opener + no link printed (address alone) — sound? anything lost? | sound | `/home/eturkes/Projects/fvtrace/Fvtrace/Cli.lean:1072` disables opener; `:1083-1085` prints address + file path, not secret. The proxy's public URL differs from this backend address; the latter is diagnostic, not an authenticated entry link. | none. Document that the operator supplies the public proxy URL; direct browsing with this option needs a separately supplied token. |
| C3 | page holding no token sends no `Authorization` ⇒ the browser's cached HTTP Basic credentials reach the proxy on same-origin `fetch` — correct per Fetch spec + Chromium/Firefox/Safari? | risk | Standards-backed when a matching authentication entry exists: Fetch §4.6 says “If httpRequest’s header list does not contain `Authorization`, then:” and uses its authentication entry; MDN says “same-origin (the default): only send and include credentials for same-origin requests.” Historical WebKit179422 + Mozilla1812003 document divergent behavior; current Chromium/Firefox/Safari remain unconfirmed. Exact quotes/URLs → C3. | Keep header omission. State its preconditions: same-origin canonical endpoint + matching browser-managed Basic credentials. Verify actual Basic-auth navigation → JSON POST on the supported browser versions; describe standards support separately from measured compatibility. Do not promise that JS always receives a 401 before any browser login UI. |
| C4 | keep an address token only on status ∉ {401, 403}; on refusal ask again with stored token or none — any failure scenario (junk token kept, request loop, repeated login prompts, a token leaking to the proxy or logs)? | defect | `/home/eturkes/Projects/fvtrace/.claude/rules/server.md:17` retries only a refused address token with stored token/none. `/home/eturkes/Projects/fvtrace/web/app.js:100-119` stores one origin-wide token; `:415-423` conditions recovery on `offered`. An existing stored token with no fragment keeps suppressing cached Basic and has no contract-level recovery. Also, statuses 405/421/404 precede successful token admission (`/home/eturkes/Projects/fvtrace/Fvtrace/Server.lean:103-119`): “anything except 401/403” is not proof of acceptance. Fetch can handle 401 before JS; details → C4. | Specify a finite candidate sequence that includes a headerless attempt after a rejected stored token, with that rejection remembered for subsequent page requests. Persist only after a valid fvtrace envelope or an authenticated fvtrace problem, not arbitrary proxy/routing statuses. Test stored-token-only and junk-fragment + stale-stored cases; bound retries and stop on unresolved access failure. |
| C5 | relative `api/answer` — any reachable page URL where it resolves wrong (`/fvtrace` without slash, `/index.html`, hash routes, the exported page)? | risk | `/home/eturkes/Projects/fvtrace/web/index.html:7-8` already resolves assets relative to the page; `/home/eturkes/Projects/fvtrace/FvtraceWeb.lean:10-12` serves `/`, not `/index.html`; `/home/eturkes/Projects/fvtrace/web/app.js:381` takes the exported-engine branch before HTTP fetch. Node URL check rc=0: `/fvtrace/` + `api/answer` → `/fvtrace/api/answer`; slashless `/fvtrace` → `/api/answer`; `index.html` + hash forms resolve correctly. Caddy source → C5. | State proxy requirement: redirect exact `/fvtrace` to `/fvtrace/`, then strip `/fvtrace` from forwarded paths. With `handle_path /fvtrace/*`, slashless `/fvtrace` is outside that route; do not claim it already serves the GUI correctly. |
| C6 | `Host` allowlist behind a proxy that rewrites `Host` to `ADDR:PORT` — any gap the contract should state? | sound | `/home/eturkes/Projects/fvtrace/Fvtrace/Cli.lean:1060` allows exactly the bound address + actual port; `/home/eturkes/Projects/fvtrace/Fvtrace/Server.lean:109-112` checks Host before Bearer. Rewriting to that exact value preserves the native check; it does not validate the original public Host. | Add deployment preconditions: proxy admits only its intended public host, authenticates the fvtrace route, replaces upstream Host with fvtrace's allowed address/port, replaces rather than appends Authorization, and restricts backend reachability. Public-to-proxy TLS + a trusted/restricted backend link remain operator responsibilities. |
| C7 | GUI under a path on an origin shared with another authenticated app (`/` = another app, `/fvtrace/` = fvtrace) — any exposure the contract should name? | risk | `/home/eturkes/Projects/fvtrace/web/app.js:100-119` uses an origin-wide `fvtrace-token`; `/home/eturkes/Projects/fvtrace/Fvtrace/Server.lean:53-64` permits `'self'` and same-origin resources. MDN: “Two URLs have the same origin if the protocol, port (if specified), and host are the same for both”; storage “are separated by origin.” Paths provide no isolation; quote/URL → C7. | State: “All applications on the public origin are trusted with these claims and facts and any browser-stored token. Use a distinct origin when that trust is not intended.” Scope token storage by canonical fvtrace base path to prevent sibling-instance collisions; that is namespacing, not isolation. |
| C8 | anything else the contract misses or states wrongly (Decisions ↔ server.md ↔ kernel.md consistency) | risk | File-token exception agrees across `/home/eturkes/Projects/fvtrace/.agent/spec.md:20`, `/home/eturkes/Projects/fvtrace/.claude/rules/server.md:14-17`, `/home/eturkes/Projects/fvtrace/.agent/contracts/kernel.md:128`. User-facing inconsistencies remain: `/home/eturkes/Projects/fvtrace/README.md:221` says every run makes a new token; `/home/eturkes/Projects/fvtrace/Fvtrace/Server.lean:115-116` tells a refused user to use a printed link or restart, although file mode prints none. Proxy ambient-auth qualification → C8. | Update README's per-run claim with the file-token exception. Extend access recovery to cover the proxy operator checking its token. Clarify that no-CORS prevents cross-origin response reads, not every cross-origin request after a proxy injects the token; MAIN rules that deployment assumption. |

