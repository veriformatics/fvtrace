# reviewer-9 — C-receipt / Correctness @ 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-receipt | Receipt.lean: digests + binding + stale | pass | Full module + Lookups/Check/Encode/Model callers read; 23 independent CLI checks cover exact manifests (Python SHA256 oracle), source/claim rewording, display-only exclusion, stale + review state; native slice 312/312. |
| C-receipt | Receipt.lean: digest cache | pass | Cache serialization/load/save + Session.openCache/closeCache and CLI/server flags read; independent preserved-size/mtime witness confirms opt-in reuse vs default rehash; size/sec/nsec + pin controls in native suite pass. |
| C-receipt | Receipt/Basic.lean | pass | Full module + Session/Snapshot/Evaluate consumers read; index lookup correspondence is Proofs.Lookups.bindingIndex_find; reviewStateOf branch structure matches draft/stale/reviewed contract and receipt checks. |
| C-receipt | Replay.lean: run, pass/fail, time limit | reviewer-9-F1 | Replay.run/reasons + CLI wrappers read; native domain/raw-byte/deadline/descendant controls pass; SIGTERM-handler verifier killed at 1.04 s; output-mismatch diagnostic red. |
| C-receipt | Replay.lean: notices + log | reviewer-9-F2 | updateAt/withResults + CLI check/pin/verify/log/write guards and Model.withoutNotices read; native matrix/order/duplicate/review/write-refusal/concurrent-log controls pass; unreadable-parent log red. |
| C-receipt | c/fvtrace_digest.c | pass | Full shim + Digest FFI signatures/callers read; ownership, chunk arithmetic + error returns checked; clang --analyze (gate flags) rc 0; NIST/stream/file vectors pass. Security observation routed separately. |
| C-receipt | tests (setup/teardown, asserts) | pass | Every line of Tests/{Receipt,Replay,Notices}.lean + Harness/runner read; temporary directories/links/children + assert scope checked; private unchanged-source run (Digest added): 312/312, rc 0. |

## Checks + limits

- Read-only target: four assigned implementation files + three test files, with relevant callers/callees in Cli, Session, Evaluate, Server, Store, Model, Encode, Lookups, Index, Snapshot, Digest, Harness. Copied target/test bytes matched the base (`cmp` rc 0 for all eight files, Digest tests included); only private `TestMain.lean` changed to select the suites.
- Private native suites: `(cd /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/tree && nice -n 10 lake build fvtrace-tests)` → rc 0; `(cd /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/tree && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/home .lake/build/bin/fvtrace-tests)` → rc 0, **312/312**. Selector retained at `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/TargetMain.lean`; logs `targeted-build.log`, `targeted-tests.log` beside it. Recreate the private tree by BRIEF's copy command, then copy `TargetMain.lean` to its `TestMain.lean` and run those commands.
- Independent receipt oracle: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/receipt-checks.py` → rc 0, **23/23** (exact manifest SHA256, artifact SHA256, binding dependencies, display fields, review, cache opt-in/default, missing files).
- Deadline control: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/timeout-check.py` → rc 0; both ordinary and SIGTERM-handler verifiers terminated before their final marker; handler case returned in 1.04 s at `--timeout 1`. Rejected hypothesis: Lean's IO.lean docstring says SIGTERM, but its pinned runtime `process.cpp` uses SIGKILL; runtime + native behavior decide.
- C: clang `--analyze -Xclang -analyzer-werror -I"$(lean --print-prefix)/include" -Ic/hacl -Ic/hacl/include -DKRML_VERIFIED_UINT128 c/fvtrace_digest.c -o /dev/null` from the private tree → rc 0. Vendored HACL* internals stayed out of scope.
- Limits: Linux native only; Windows/macOS branches read, not executed. >1 GiB single-update slicing, SHA256-length exhaustion, allocation failure and pipe I/O fault injection not exercised; arithmetic/error paths read. Full gate, mutation campaigns + independent-kernel replay not run (MAIN owns them). LSP attempted on Receipt.lean: no Lean server configured, so references traced with `rg`.
- Cleanup: private build copy + isolated data home removed after the checks; selector, red tests + logs retained. No server launched.

## reviewer-9-F1 — minor — output-mismatch replay hides stderr

- At `48bc51d`: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:287` (`runReplay`, caller of `Replay.run`).
- Contract: `kernel.md` § Replay, Run: “A fail shows stderr's tail.” `verify --run` fails on exit 0 + changed stdout; `runReplay` suppresses stderr whenever exit = 0, before output agreement is tested. The retained diagnostic reaches the log but not the failing command's display.
- Proof: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/red-stderr.py` → rc 1 on base binary. Positive control: exit 7 displays the tail. Target output:

```text
PASS positive control: exit 7 fails and displays stderr tail
Target rc=1
  F: running /home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/bin/fvtrace-tests --replay-fixture hex:61 err:mismatch-tail exit:0
  F: failed (output changed)
0 of 1 replay(s) passed.
AssertionError: FAIL: exit 0 + output changed is a replay failure, but its stderr tail is hidden
```

- Full failing output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/red-stderr.log`.
- Fix direction: print the retained tail against the command-specific failure predicate (`verify`: `Replay.reasons`; `pin`: `Replay.pinReasons`), rather than exit status alone.

## reviewer-9-F2 — minor — unreadable log is reported as no history

- At `48bc51d`: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:417` (`showLog`).
- Contract: `kernel.md` § Replay, Log: “an unreadable log ⇒ rc 2.” `FilePath.pathExists` also returns false when an ancestor denies traversal. That branch treats an existing but inaccessible replay log as absent, returns rc 0, and says no replay has run.
- Proof: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/red-log-permission.py` → rc 1 on the base binary as normal user. The fixture restores permissions in `finally` and removes its entry. Output:

```text
PASS positive control: existing replay log yields one readable event
Target rc=0
No replay has run for this project yet.
AssertionError: FAIL: an existing log below an unreadable data entry is reported absent (rc 0), not unreadable (rc 2)
```

- Full failing output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-9/red-log-permission.log`.
- Fix direction: open/stat with typed error handling; treat only a genuinely absent file/entry as empty history, and propagate access/read failures to rc 2.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/c/fvtrace_digest.c:20` — security → MAIN.

reviewer-9-DONE-1
