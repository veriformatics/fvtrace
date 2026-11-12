# reviewer-15 — C-server, Correctness

Target = `48bc51d`; frozen base `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Functional lens only; security observations → Register.

| row | target | verdict | basis |
|---|---|---|---|
| C-server | routes, methods, status codes, order | reviewer-15-F1 | Pure route suite 40/40; raw oversized declared bodies return 413 before specified 405/421/403/415. |
| C-server | /api/answer: answers = CLI bytes, view header, 409, 413, 415 | reviewer-15-F1, reviewer-15-F2 | Native parity: 6 request forms `cmp=0`; inclusive body cap + 409 view passed; oversized transport order + missing item-error view fail. |
| C-server | problem replies + 500 io | pass | Exact no-trace/unreadable/invalid wording + 400 refusal order driven; planted `answerBody` I/O exception → exact 500 `io` JSON. |
| C-server | session cache + invalidation + launch evaluation | pass | `answer`/`Session`/launch task read; trace/evidence/notice-only edits + error recovery preserve CLI bytes; 30 interleaved requests/12 clients passed. Launch scheduling coverage limit below. |
| C-server | fixed headers, config ref, start/stop | reviewer-15-F1 | Normal 200/400/403/404/405/409/415/421 carry fixed headers; transport 413 carries 0/7; config-ref transition + listener/keep-alive shutdown passed. |
| C-server | serveCmd ↔ Server wiring | pass | `serveCmd`/bind/opener/config/answer callers read; real loopback dual bind, default target, concrete IPv4/IPv6 + token-file output/request paths passed. |
| C-server | tests (Tests/Server, e2e access/proxy, harness teardown) | pass | Entire named test files read; pure route suite + seam checks 40/40; setup/normal-exit cleanup symmetric by inspection. Browser/timeout-harness reruns excluded below. |

Adjudicated = 7/7; findings = 2 (major 1, minor 1). No target edits, builds, git mutations or nested agents.

## reviewer-15-F1 — major — HTTP size rejection precedes the specified decisions + drops fixed headers

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean:256` (`httpConfig`), with `handler` at line 241.
- Contract: `.agent/contracts/kernel.md` V-serve: method → Host → path → credential → Content-Type → body; `.claude/rules/server.md` Access + “Every response carries `fixedHeaders`”.
- Defect: setting Std.Http's protocol-level `maxBodySize` to `bodyCap` makes a declared length of `bodyCap + 1` fail before `handler`/`decide`/`toResponse`. A GET to `/api/answer` consequently answers 413 instead of 405; foreign Host, absent credential + wrong media type likewise answer 413 instead of their specified 421/403/415. The transport's 413 contains none of the seven fixed headers. Its empty body is an observation, not a separate asserted contract violation.
- Source anchor: `rg -Fn 'maxBodySize := bodyCap' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean` → line 256. Std implementation read: `/opt/lean/src/lean/Std/Http/Protocol/H1.lean` `handleReaderFailed` emits its own error response.
- Red witness (base native binary):

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/red-http.py transport
```

Observed rc=1; full output `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/red-transport.log`:

```text
PASS method control (small body): 405
FAIL method before body cap: expected=405 got=413
FAIL Host before body cap: expected=421 got=413
FAIL credential before body cap: expected=403 got=413
FAIL Content-Type before body cap: expected=415 got=413
PASS oversized admitted request: 413
PASS fixedHeaders positive control count: 7
FAIL fixedHeaders on 413 count: expected=7 got=0
413 body=b''
CLEANUP server PID terminated; listener refuses
5 failing contract assertions
```

- Fix direction: make oversized declared-length refusal follow the specified header-only decisions + common response-header path; preserve pre-read rejection + streamed-body cap.

## reviewer-15-F2 — minor — item problems discard the known answer view

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean:205`.
- Contract: `.agent/contracts/kernel.md` V-serve “each answer carries header `X-Fvtrace-View`”; `.claude/rules/server.md` Routes: header = the view the answer read. This witness uses a valid request + loaded trace + known normalized what-if, not an undecodable request or absent record.
- Defect: the successful details branch applies `tagged`; its error sibling returns `problemReply (.badItem m)` without it. A same-view request for `claim:C9` therefore returns the correct 400 `item` problem but loses `X-Fvtrace-View`, although `v` was already computed and checked.
- Source anchor: `rg -Fn '| .error m => problemReply (.badItem m)' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean` → line 205.
- Red witness (base native binary):

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/red-http.py item-view
```

Observed rc=1; full output `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/red-item-view.log`:

```text
PASS envelope view positive control: (200, 64)
PASS missing item refusal: (400, 'item')
FAIL item problem keeps the view it read: expected='407ead4899f126b9d54a5202469b35e7dce3ecbfbc6e041b2abb1b3a21334a31' got=None
CLEANUP server PID terminated; listener refuses
1 failing contract assertions
```

- Fix direction: apply `tagged` to the known-view item-problem branch as well.

## Checks run

All scripts + logs below = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/`. Every native fvtrace child used `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/home`, `serve --port 0 --no-browser`; server PIDs terminated + listeners checked closed.

| command | result | scope |
|---|---|---|
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/probe.py` | rc=0; `probe.log` | 9 ordinary route/order cases; same-port IPv4/IPv6; 14 GUI asset SHA-256 equalities; inclusive 16,778,240-byte body; 6 envelope/detail/action CLI parity forms (`cmp=0`); correct/stale view; trace/evidence/notice-only invalidation; 30 concurrent answers/12 clients = uncached CLI; missing explicit trace, bad JSON + bad WF wording; recovery. Oversize observations here are asserted by F1's separate red witness. |
| `(cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/pure-and-io.lean)` | rc=0, 40/40; `pure-and-io.log` | Existing `Tests.Server.pureTests`; planted I/O failure → exact 500 `io` JSON; invalid UTF-8 rejected before evaluation. |
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/start-stop.py` | rc=0; `start-stop.log` | Base module via Lean interpreter: bind with empty Config hosts → 421; same `IO.Ref` filled → 200; `Server.stop` closes existing keep-alive + listener. |
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-15/wiring.py` | rc=0; `wiring.log` | Native default target → exact 409 `no-trace`; concrete IPv4/IPv6 hosts + trimmed token-file → 200; expected address/filename output; invalid token-file → rc=2 with filename. |

Native binary SHA-256 = `2f4f08ea11ee24cb1a06cfa77b1dba132197b87de6851dca4941a48923cb768a` (`/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/bin/fvtrace`).

## Coverage + limits

- Read entire `Server.lean`, `Session.lean`, `Evaluate.lean`, `Request.lean`, `FvtraceWeb.lean`, named server/e2e test files; enclosing `Cli.lean` serve/bind/opener functions + evaluation callers. Also read served `web/app.js` request/view consumer, relevant GUI evidence/notice cases, Std.Http body/parser/shutdown callees + compiled envelope-cache branch.
- Cache transparency exercised on the synthetic example + changed variants, not all traces. The 30-request concurrency run samples scheduling; it is not an exhaustive interleaving proof.
- Launch warm-up: source confirms one `IO.asTask (Server.answer … recorded)` + shared mutex/Kept state. A runtime assertion that every racing request waits for that task and never triggers a second evaluation is **unconfirmed**; inspected `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:1064` + `Server.lean:154`, exercised normal launch only.
- Browser `access.spec.js`/`proxy.spec.js`, existing `Tests.Server.nativeTests`/`answerTests`, timed-out-worker teardown probe, full gate, mutation campaign + opener GUI were **not run** by this reviewer. Named e2e/harness files were fully read; timeout cleanup is source-inspected, **not runtime-confirmed**. Native route/session behavior was driven independently as above. No browser/account state touched.
- Lean LSP probe on real `Server.lean` returned `No LSP server available for file type: .lean`; compiler/interpreter + source/callee inspection used instead.
- Positive and red artifacts persist for MAIN's validator/rerun. No source or guidance edit.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean:256` — security → MAIN.

reviewer-15-DONE-1
