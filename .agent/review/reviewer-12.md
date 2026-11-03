# reviewer-12 — C-eval at `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| C-eval | Evaluate.lean: envelope, actions, details | pass | Every function + Answers/Present/Encode callees and CLI/server/snapshot wiring read; V-env field/order audit; every batch payload = its details document across four studies + two views; action oracle + reference lists green. |
| C-eval | Request.lean: request form + refusals | pass | Exact-key/string-only parser + Item grammar traced into CLI/server/snapshot; focused run = 681/681, including reordered keys, duplicate keys, malformed optional fields, action/item/refusal precedence. |
| C-eval | Session.lean: read bounds, cache, view | pass | D-json prefix/pre-read-size/nonregular boundaries green; native HTTP/CLI byte parity across trace edits, evidence edits/restoration, notice-only edits, invalid/missing/restored traces, normalized views + 409 view; prepared/receipt/cache/start-up/serialized evaluation wiring read. |
| C-eval | Snapshot.lean: encode/decode, page-engine state | pass | Exact outer/binding shapes + version refusal + shared trace decoder/checker read; four-study × three-review-state round trips, malformed snapshots + state transparency green; exported snapshot → native stateful hook matches CLI for 11 request sequences. |
| C-eval | Render.lean | pass | C0/DEL/C1/bidi predicates + hex encoding and CLI say/complain/JSON-printer routes read; independent checks cover U+0000–U+00FF, all banned bidi points + adjacent boundaries. |
| C-eval | tests (setup/teardown, asserts) | pass | Evaluate/Snapshot suites + Harness + supporting Details/Cli.readTests/Server tests read; contract-derived assertions + temporary-directory ownership symmetric; focused 681/681; native integration 136/136 + port-refusal cleanup check passed. |

## Findings

None. Six target groups adjudicated; all pass for the fixed C-eval correctness check set.

## Register

- `Fvtrace/Session.lean:65` security → MAIN.

## Coverage

- Target = `/home/eturkes/Projects/fvtrace/.scratch/review-base`, revision `48bc51d`; read-only. No target edits/builds, no git operations, no nested agents. Only deliverable + owned scratch written.
- Additional callers/callees read: `Fvtrace/{Cli,Server,Export,Answers,Present,Engine,Encode,Index,Receipt}.lean`, `Fvtrace/Answers/Fast.lean`, `Fvtrace/Receipt/Basic.lean`, request/trace parsers, `Tests/{Harness,Details,Cli,Server,Check}.lean`; page-engine export symbols checked against `c/page_engine.c` + `FvtraceWasm/{Build,Binary}.lean` call sites. Source fields/order reviewed against V-env/V-action/V-details/V-request/V-cli/V-complete/V-serve, D-json, P-cache, E-snap/E-request/E-state + Decisions.
- Focused rerun: `(cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-12/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-12/focused.lean)` → rc 0, `681/681 checks passed`. Suites = Evaluate, Details, Snapshot.pureTests, Snapshot.stateTests, Check (Render regressions) + independent request grammar/Render boundaries/batch-payload/read-bound checks. Log = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-12/focused.log`.
- Native rerun: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-12/native.py` → rc 0, `136/136 native checks passed` + stopped-port refusal check passed. Uses the frozen binary + its `--answer-snapshot` test hook; private reflink copy for trace/evidence edits; script recreates the copy when absent. Log = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-12/native.log`.
- Native cases = byte parity CLI ↔ HTTP ↔ stateful snapshot over recorded/stacked/action/details sequences; identical/whitespace-only/edited/notice-only trace views; changed/restored evidence; malformed/missing/restored trace; mismatched view; exact refusal messages + precedence. Cache reuse read structurally; output transparency/reload observed. Evaluation counts/scheduler order not instrumented.
- Cleanup = owned server terminated by PID, waited, port refused. Separate `pgrep -af '[f]vtrace serve.*reviewer-12'` → rc 1 (no remaining owned server); the run log's observed PID + successful requests are its positive control. Private 4 GiB copy removed after checks; scripts/logs retained as validator inputs.
- Not run = full gate, full native suite, mutation campaign, independent-kernel replay, timing/memory/load measurements, browser/WebAssembly execution. These are MAIN/other review slices; this report makes no new timing/memory guarantee. Code-intelligence attempt: LSP on real `.lean` file returned `No LSP server available for file type: .lean`; textual caller searches + direct Lean checks used instead.
- Scratch harness initially failed to compile (`BEq (Except String Request)` / `BEq (Except String Item)` absent); comparison adapter corrected, final focused run green. No target failure inferred from that setup error.

reviewer-12-DONE-1
