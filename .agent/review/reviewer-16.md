| row | target | verdict | basis |
|---|---|---|---|
| C-server | routes, methods, status codes, order | reviewer-16-F1 | Live built-binary probe: ordinary route decisions pass; declared oversize intercepts method/path/type decisions with empty 413. |
| C-server | /api/answer: answers = CLI bytes, view header, 409, 413, 415 | reviewer-16-F1, reviewer-16-F2 | Live probe: envelope/details/action parity + 56 concurrent interleavings pass; oversize transport and evaluated item-problem header fail. |
| C-server | problem replies + 500 io | pass | Exact no-record/unreadable/record-error wording + refusal ordering driven; `pure.lean` 39/39 includes an injected I/O exception → 500 `io`. |
| C-server | session cache + invalidation + launch evaluation | pass | Session + mutex wiring read; 56 interleaved requests match CLI; trace/evidence/notice-only edits invalidate; notice-only preserves trace member; launch reads trace + evidence before HTTP. |
| C-server | fixed headers, config ref, start/stop | reviewer-16-F1 | Normal 200/400/403/404/405/409/415/421 paths decorated; transport 413 not. `lifecycle.lean`: empty config 421 → filled config 200; stop closes incomplete body + listener. |
| C-server | serveCmd ↔ Server wiring | pass | Full `serveCmd`, bind/open helpers + dispatch read; built CLI serves the same ephemeral port on IPv4 + IPv6, `--no-browser`; startup read observed. |
| C-server | tests (Tests/Server, e2e access/proxy, harness teardown) | pass | All four target test files read; pure routing suite + I/O seam 39/39. Native/e2e bodies reviewed for setup/teardown symmetry; browser suites not rerun. |

## reviewer-16-F1 — major: transport body cap precedes the route's decision

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean:256` (`httpConfig.maxBodySize := bodyCap`).
- Contract: `kernel.md` V-serve access decision order = method → host → path → token → type → body; `.claude/rules/server.md` access + fixed-response-header bullets.
- Why: Std.Http rejects the declared length before invoking `handler`; `Server.decide` and `toResponse` never run. A POST to `/` must be 405, a GET of `/missing` must be 404, an admitted API POST of `text/plain` must be 415; each becomes an empty 413. The valid API oversize response also bypasses the fixed-header path.
- Red command at `48bc51d`: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/probe.py --red-body` (rc 1).

```text
positive control: POST / => 405 (expected 405)
FAIL oversized framing preserves POST / decision order: got=413 expected=405; headers={'server': 'fvtrace', 'connection': 'close', 'content-length': '0'}; body=b''
FAIL oversized framing preserves GET /missing decision order: got=413 expected=404; headers={'server': 'fvtrace', 'connection': 'close', 'content-length': '0'}; body=b''
FAIL oversized framing preserves POST /api/answer decision order: got=413 expected=415; headers={'server': 'fvtrace', 'connection': 'close', 'content-length': '0'}; body=b''
```

- Evidence: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/red-body.log`.
- Fix direction: retain an upstream framing guard while routing the declared-length refusal through the server's required decision + response decoration paths; preserve pre-read 413 on an admitted API request.

## reviewer-16-F2 — minor: an evaluated item refusal drops its view header

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean:205`.
- Contract: `kernel.md` V-serve: “each answer carries header `X-Fvtrace-View`”; `.claude/rules/server.md` routes: header = the view the answer read.
- Why: after successfully loading, binding, expanding + computing `v`, the error branch of `Evaluate.detailsWith` returns `problemReply` without `tagged`. A valid same-snapshot envelope carries the view; the item problem from that evaluated view does not.
- Red command at `48bc51d`: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/probe.py --red-view` (rc 1).

```text
positive control: success view=26e2e789cfcd6c72eb16d83160b8b7521b86eb92f1a7172425be2dc51f48bb90
valid scenario, invalid item: 400 … {"problem":{"kind":"item","message":"\"missing\" is not a claim on record"}}
FAIL item problem carries evaluated view: got=None expected=26e2e789cfcd6c72eb16d83160b8b7521b86eb92f1a7172425be2dc51f48bb90
```

- Evidence: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/red-view.log` (unabridged headers + pretty body).
- Fix direction: tag this refusal with the already-computed view, as the success + view-conflict branches do.

## Runs + limits

| command (absolute scratch paths) | result |
|---|---|
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/probe.py` | rc 1; 131/132; only F1's missing fixed headers fail. 7 request forms byte-compared with CLI + 56 concurrent interleavings; exact view hash independently recomputed; trace/evidence/notice-only edits, recovery, IPv4/IPv6, problem order exercised. |
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/probe.py --red-body` | rc 1; 3/7; F1, positive control POST `/` = 405. |
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/probe.py --red-view` | rc 1; 2/3; F2, positive control success has its view. |
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/probe.py --no-record` | rc 0; 4/4; exact no-record message + response decoration + stop. |
| `(cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/pure.lean)` | rc 0; 39/39: existing `Server.pureTests` + 500 `io` seam. |
| `(cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean timeout 25 lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/lifecycle.lean)` | rc 0; config ref 421 → 200; `Server.stop` returns, incomplete-body connection reset, listener refuses (connect rc 111). Initial probe counted the expected reset as an error; corrected probe accepts reset + EOF, rejects timeout. |
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/launch.py` | rc 0; trace + evidence opened at launch before any HTTP request. This is a read/binding witness; mutex + evaluation sequencing adjudicated from code. |

- Logs beside each probe: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-16/{probe,red-body,red-view,no-record,pure,lifecycle,launch}.log`.
- Read: complete Server + Session + Evaluate + Request + FvtraceWeb; `Cli.serveCmd`, helpers + dispatch, CLI load/eval wiring; complete assigned test files; relevant upstream Std.Http framing/body/start/stop code.
- Coverage limit: synthetic trace + its scratch mutations, 56 deterministic mixed concurrent requests; no exhaustive schedule exploration. Native Server test bodies + access/proxy browser suites inspected, not rerun. Full gate, mutation campaigns, bind-error OS simulation, automatic browser opening + proxy browser flows not run in this review. MAIN owns baseline + security.
- Unconfirmed: platform-specific IPv6-unsupported + fixed-port-busy behavior outside the code reading (`Cli.serveLoopback` + its planted-start test inspected); only Linux IPv4/IPv6 success exercised. E2e worker-timeout cleanup assessed from the exit handler + test `finally` code, not re-probed dynamically.
- LSP coverage probe: `.lean` has no configured server; direct source + runtime probes used.
- Every spawned server terminated by its PID + waited; built-binary probes confirm its port refuses. Final `pgrep -af '[/]home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/bin/fvtrace serve.*reviewer-16'`: rc 1, no owned server remains. Target unchanged; only deliverable + scratch written.

reviewer-16-DONE-1
