# reviewer-11 — C-eval

Target = `48bc51d`; fixed check set = C-eval Correctness × M-eval, bounded by the assigned Evaluation/Decode/Performance/Page-engine contract + Decisions.

| row | target | verdict | basis |
|---|---|---|---|
| C-eval | Evaluate.lean: envelope, actions, details | pass | Full module + Answers/Present/Index and CLI/server/Snapshot call sites; V-env member/order mapping inspected; action-reference/expansion oracles + complete/per-item payload and order checks passed across both examples + both fixtures, current/stale and valid what-ifs. |
| C-eval | Request.lean: request form + refusals | pass | Full module + Json.parse, Overrides.parseWith, Item callers (CLI/server/Snapshot); exact key/type/duplicate/Unicode and item-shape checks passed in semantic-checks.lean. |
| C-eval | Session.lean: read bounds, cache, view | pass | Full module + Server.answer/Kept, CLI load/warm-up, Receipt.BindingIndex; 25 bounded-read checks passed; live cached server matched uncached CLI bytes after interleaving, trace edits/invalidity, evidence changes/missing/restoration, format-only edit and old-view refusal. |
| C-eval | Snapshot.lean: encode/decode, page-engine state | pass | Full module + Encode/Export.snapshot, Request/Answers wiring and C bridge call sites; round trips for four traces × three review states, version refusals, request/error sequencing and kept-vs-fresh state checks passed; native snapshot hook byte-equal to CLI for live pinned inputs. |
| C-eval | Render.lean | pass | Full module + Cli.say/complain and all CLI print sites; byte-range controls, bidi boundaries, astral/max scalar checks passed; JSON outputs use JSON escaping, static help/schema/skill bypasses contain no trace text. |
| C-eval | tests (setup/teardown, asserts) | pass | Full Tests/Evaluate + Tests/Snapshot, Harness and registration; relevant Details/read/Server assertions inspected. Pure tests do not mutate fixtures; native temp project/home stays scoped; capture and withTempDir cleanup symmetric; comparisons check observable contract fields/bytes. |

## Findings

None.

## Evidence

All commands below run the frozen `48bc51d` artifacts; target sources/builds untouched.

1. `cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-11/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-11/semantic-checks.lean`
   - rc 0; `1019/1019 checks passed (slowest: snapshots 28972 ms, evaluation 3765 ms, requests 6 ms)`.
   - Four inputs = both examples + synthetic/restates fixtures. Static field/order walk complements dynamic action/detail/complete oracles; snapshots cover draft/stale/reviewed + kept/fresh request sequences.
2. `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-11/transport-checks.py`
   - rc 0; `144/144 transport/cache/batch/snapshot checks passed; server PID 886508`.
   - Real `serve --port 0 --no-browser`, isolated home/project/trace; cached HTTP answers vs uncached CLI bytes; native stateful snapshot hook vs CLI; request refusals; changed trace/evidence; old view; complete payloads.
   - `server PID 886508 stopped: rc=-15`; `port 38503 refuses after shutdown`; `pgrep -af '[f]vtrace serve.*reviewer-11'` rc 1, no match. Positive control = own log's exact stop line, 1 match (rc 0).
3. `cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-11/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-11/read-checks.lean`
   - rc 0; `25/25 checks passed (slowest: )`.
   - Oversize reader-spy count 0; exact limit; implicit/explicit missing; directory refusal; growth ≤ limit+1; prefix bytes/sizes around the 1 MiB chunk boundary.

Logs = corresponding `.log` files beside each scratch script. Initial harness-only failures: transport readiness consumed the informational preamble; read runner lacked `do`. Corrected harnesses produced the passing runs above.

Coverage limits: full gate/suite, mutation campaigns, browser/WebAssembly differential and idle-host performance gates not run by this reviewer. Shared engine/proof/transport internals inspected for M-eval wiring, not independently re-audited. LSP unavailable for `.lean` (documentSymbol request); source reads + bounded `rg` used instead. Dynamic inputs named above are finite samples; whole-domain adjudication also uses the source walk and the existing agreement boundary.

## Register

None.

reviewer-11-DONE-1
