# reviewer-1: closing diff review — replay notices + log

Target = `5c959c9` → working tree; fixed L1–L10 before target read. Tracked target read-only; evidence writes confined to `.scratch/notices/reviewer-1/`. Scope excludes `.agent/deferred.md` + mutation results. Verdict = **10/10 adjudicated; 3 findings (1 major, 2 minor)**.

| id | lens × slice | verdict | anchors + failure scenario | severity |
|---|---|---|---|---|
| L1 | Correctness: Replay outcomes → NoticeChange, positional updateAt/withResults, pinReasons | pass | `Fvtrace/Replay.lean:112–183`: failure precedence, unpinned keep, pass clear, per-position fact-then-exclusion application checked with enclosing definitions + callers. Lifecycle smoke passed. | — |
| L2 | Correctness: CLI pin/verify/check/showLog/writeOver/writeTrace/appendLog/stamp | finding: L2.1, L2.2, L2.3 | `Fvtrace/Cli.lean:183`: concurrent successful appends corrupt events; `:409`: blank malformed log line silently ignored; `:169`: symlink trace logged unresolved. | major + minor |
| L3 | Correctness: Model/Decode/Encode/schema, reviewDigest, viewOf, envelope notices, ensureEntry | pass | `Fvtrace/Model.lean:205`, `Fvtrace/Decode.lean:62`, `Fvtrace/Receipt.lean:189`, `Fvtrace/Session.lean:149`: notices excluded from review digest but included in served view; codec + strict examples + lifecycle smoke passed. UInt32-overflow corpus is explicitly decoder-only; no schema-parity claim added here. | — |
| L4 | Correctness: GUI decoder/rendering/words vs web.md | pass | `web/envelope.js:178`, `web/panels.js:157`, `web/app.js:827`: display-only mapping, selectable words + id references, notice below review, same recorded notices across modes. All 3 new replay-notice e2e tests passed. | — |
| L5 | Contract: every changed kernel clause ↔ code | finding: L2.1, L2.2, L2.3 | `.agent/contracts/kernel.md:64`: one line/event, malformed-line reporting + resolved-path clauses fail the three red probes. Other changed Model/Notice/Review/V-env/V-serve/P-cache/compare clauses traced to their implementations; no further finding. | major + minor |
| L6 | Cleanup: helper reuse, duplication, dead code, state, naming/comments | pass | Full diff + helper search read. No independent contract-breaking cleanup defect. Notice serializers repeat the same three fields across layers, but agree; preference alone omitted. | — |
| L7 | Altitude: shared mechanism vs call-site special cases | finding: L2.1 | `Fvtrace/Cli.lean:179–187`: shared append mechanism lacks event serialization; both pin + verify inherit it. Repair belongs in that mechanism, not replay-loop special cases. | major |
| L8 | Tests: Notices/Replay/e2e/engine/schema coverage, behavior assertions, timing | finding: L2.1, L2.2, L2.3 | `Tests/Notices.lean:391`: substantial outcome × prior-state, digest, persistence, refusal + log coverage; new tests miss parallel appends, blank physical lines + aliased trace paths. The three independent boundary probes expose those gaps. Existing test edit adds notice assertions rather than removing the old replay failure expectation. | major + minor |
| L9 | Docs: README, skill, CLI help, spec Decisions ↔ behavior | pass | `README.md:166`, `skill/fvtrace/references/trace-format.md:25`, `Fvtrace/Cli.lean:38`, `.agent/spec.md:39`: optional runs, lasting notices, clear-on-pass, strict check, review neutrality + history command agree with the implemented main paths. No public-surface change outside the request found. | — |
| L10 | Gate + examples: trust copy strength; re-pin digest-only | pass | `tools/trust.sh:49–57`: same verifier invocation/project on exact copied trace; original safe from notice writes; nonzero rc propagated. Structural base/current JSON comparison = exactly 14 changed digest leaves, no model/text/status change. Both strict example checks rc 0. | — |

## Detail

### L2.1 — major: concurrent successful appends corrupt replay history

- Anchor: `Fvtrace/Cli.lean:183`; exact bytes matched with `rg -Fn`: `h.putStrLn entry.canonical`.
- Contract: `.agent/contracts/kernel.md:64`: each attempted replay appends **one line** immediately; events remain readable; failed append reports rc 2.
- Scenario: two or more `verify --run` processes share one project's log. Valid trace = 120 KB argv (`/bin/true`, 120000-byte argument), pinned empty-output digest; all replays pass. The append operation emits a record through writes that can interleave with another handle. A long merged JSON line + a detached fragment replace two readable events. Every command nevertheless returns rc 0; no append error is reported.
- Red command: `python -I .scratch/notices/reviewer-1/probe-concurrent.py` → **rc 1**, twice.
- First failing output:
  ```text
  processes=72; nonzero=0; lines=72; invalid=4
  bad_head=[(1, 240122, "Expecting ',' delimiter"), (2, 506, 'Expecting value'), (46, 240122, "Expecting ',' delimiter"), (47, 506, 'Expecting value')]
  AssertionError: parallel appends corrupted replay log events
  ```
- Repeat: `processes=72; nonzero=0; lines=72; invalid=2`; same assertion, rc 1. Witness is schedule-sensitive; both executed attempts fired.
- Evidence: `.scratch/notices/reviewer-1/concurrent.log`, `.scratch/notices/reviewer-1/concurrent-repeat.log`.
- Acceptance: serialize complete event appends across processes; parallel successful runs leave exactly one independently parseable event each, no omitted events. Keep both pin + verify on the same append mechanism.

### L2.2 — minor: blank malformed log lines bypass the corruption status

- Anchor: `Fvtrace/Cli.lean:409`; exact bytes matched with `rg -Fn`: `if line.isEmpty then continue`.
- Contract: `.agent/contracts/kernel.md:64`: a line that is no entry is skipped, counted on stderr, rc 1.
- Scenario: `replays.log` contains one valid JSON entry followed by an empty physical line (`valid-entry\n\n`). Reader accepts the real entry, silently drops the blank line, returns rc 0 + empty stderr. A blank line is not the required object entry. Same bypass covers whitespace-only lines after `trimAsciiEnd`.
- Red command: `python -I .scratch/notices/reviewer-1/probe-log.py blank` → **rc 1**.
- Failing output:
  ```text
  positive_control=one valid entry retained + one malformed line counted, rc=1
  command_rc=0
  stderr=''
  AssertionError: blank non-entry line must be counted and return rc 1
  ```
- Positive control writes one valid entry + `not JSON`: expected accepted count = 1 + malformed count = 1; both asserted before the blank-line witness.
- Evidence: `.scratch/notices/reviewer-1/blank.log`.
- Acceptance: an empty/whitespace physical line counts as one malformed entry (EOF itself remains clean); valid neighbors remain readable.

### L2.3 — minor: history records an alias instead of the resolved trace path

- Anchor: `Fvtrace/Cli.lean:169`; exact bytes matched with `rg -Fn`: `[("at", .str at_), ("run", .str run), ("trace", .str tg.trace.toString)`.
- Producer context: `Fvtrace/Store.lean:102–119` resolves the project through `IO.FS.realPath`, but an explicit trace uses `absolute` alone. New `logEntry` copies that unresolved path.
- Contract: `.agent/contracts/kernel.md:64`: log `trace` + `project` are the resolved paths.
- Scenario: `alias.json` → `draft.json`; `verify --run --trace alias.json` passes, but its event names `alias.json`, not the trace it resolved/read (`draft.json`). History identity depends on the spelling/alias used; a later retargeted alias no longer identifies the original draft.
- Red command: `python -I .scratch/notices/reviewer-1/probe-log.py resolved` → **rc 1**.
- Failing output:
  ```text
  command_rc=0; trace=.scratch/notices/reviewer-1/probes/alias.json; resolved=.scratch/notices/reviewer-1/probes/draft.json
  AssertionError: logged trace path is not resolved
  ```
- Evidence: `.scratch/notices/reviewer-1/resolved.log`.
- Acceptance: capture the trace's resolved identity for the run's log event; aliases + normalized spellings of the same existing trace record the same path. `verify --log` must retain its no-trace-read behavior.

## Checks + limits

Passed (actually run):
- `python -I .scratch/notices/reviewer-1/smoke.py` → rc 0: reviewed pin failure, receipt/current + all judgments unchanged, strict notice failure, repeated failure no rewrite (mtime), verify pass clears + restores exact clean bytes; four canonical log events retain argv + stderr.
- `(cd  && node --test --test-reporter=dot tests/schema/schema.test.mjs)` → rc 0.
- `(cd  && TMPDIR=.scratch/notices/reviewer-1/tmp pnpm exec playwright test tests/e2e/gui.spec.js -g 'replay notices' --workers 1 --reporter dot --output .scratch/notices/reviewer-1/playwright)` → rc 0, **3 passed (1.4 s)**.
- `.lake/build/bin/fvtrace check --strict` on self-trace (`--project` repo) + synthetic (`--project examples/synthetic/project`), isolated scratch FVTRACE_HOME → both rc 0.
- `git -C  diff --check 5c959c9` → rc 0.
- Base/current self-trace JSON walk → rc 0, exactly 14 changed leaves: 11 replay-output digests + 3 tested-fact artifact digests.

Failed as intended: L2.1 twice, L2.2 + L2.3 red probes above. No target edit made.

Not run by this reviewer: full gate; full native suite; independent-kernel replay; statement replays; native/Wasm differential suite; exported-page UI test; mutation campaigns (explicitly outside scope). Source/caller consistency checked for these integration paths, not claimed runtime-green. Existing build used, no rebuild initiated. Built fvtrace SHA-256 = `e50a0399d2dec78d605dd527e44df260b97f3dd3dc3937b79b2bc7651290175c`; reviewed `Fvtrace/Cli.lean` SHA-256 = `0bb03024c63703578d5b7d56aa5ec98b42b3cdf255fd61a4bd756073b1c1b063`.

LSP coverage probe on `Fvtrace/Cli.lean` returned `No LSP server available for file type: .lean`; review used source + runtime evidence instead. No independent all-clear of formal proof/mutation results claimed.

Register outside fixed scope: none.

reviewer-1-DONE-1
