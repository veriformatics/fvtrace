# reviewer-10 — C-receipt × Correctness, base `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| C-receipt | Receipt.lean: digests + binding + stale | pass | All manifests/bind/pin/review functions + caller/callee contexts read; independent canonical-SHA oracle + exact stale sets + headline/why exclusions in `smoke-receipts.py` (55 checks overall, rc 0). |
| C-receipt | Receipt.lean: digest cache | pass | Cache serializers/load/save/fileDigest + Session.openCache/closeCache and CLI/server rehash wiring read; smoke confirms opt-in metadata reuse, default rehash, malformed-cache fallback + failed-save answer parity (rc 0). |
| C-receipt | Receipt/Basic.lean | pass | All definitions + Session/Evaluate/Snapshot callers read; `bindingIndex_find` proves first-match lookup for every list (duplicates included); `reviewStateExact` proves review-state iff digest match. |
| C-receipt | Replay.lean: run, pass/fail, time limit | finding reviewer-10-F1, reviewer-10-F2 | All run/reason/CLI contexts read; native exit/missing-program/raw-byte/relative-argv + process/group timeout smoke passed (1.038 s / 1.022 s); two diagnostic-tail red witnesses. |
| C-receipt | Replay.lean: notices + log | finding reviewer-10-F3 | Every result/notice-update + log/writeOver/showLog context read; pure positional matrix (26 checks overall) + native persistence/review/draft-conflict/log/domain smoke (35 checks overall) passed; unreadable-parent red witness. |
| C-receipt | c/fvtrace_digest.c | pass | Shim allocation/finalizer/borrowed objects/slice lengths/error returns + Digest callers read; clang analyzer rc 0; native pin SHA equals hashlib for 11 lengths (0, block/padding boundaries, 1 MiB boundaries, 2 MiB+7). Security ownership routed separately. |
| C-receipt | tests (setup/teardown, asserts) | pass | Tests/{Receipt,Replay,Notices}.lean + Harness + suite wiring read in full: project/home/temp ownership, link cleanup, fixture child behavior, positional assertions, exceptions + platform branches fit their stated contracts. Existing suites not rerun wholesale; focused probes below run against base. |

## Findings

### reviewer-10-F1 — minor — exit-0 replay failures hide stderr

- At `48bc51d`: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:287` (`runReplay`, caller of `Replay.run`).
- Contract: `kernel.md` § Replay, Pass: “A fail shows stderr's tail.” Both `output changed` + `output not pinned` are failures even when the process exited 0.
- Wrong: `unless run.exit == some 0 || run.stderrTail.isEmpty` suppresses the tail before the caller compares the output. A verifier's failed output-agreement check loses its immediate diagnostic; the log still holds the tail.
- Red command: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/red-stderr.py` → rc 1 on the base. Positive control: each attempted replay appends `stderr = REPLAY_DIAGNOSTIC_TAIL` once. Failing output:

```text
positive control: output changed log stderr = REPLAY_DIAGNOSTIC_TAIL (1 event)
FAIL: output changed must display its stderr tail; verify rc=1
  O1: failed (output changed)
0 of 1 replay(s) passed.
positive control: output not pinned log stderr = REPLAY_DIAGNOSTIC_TAIL (1 event)
FAIL: output not pinned must display its stderr tail; verify rc=1
  O1: failed (output not pinned)
0 of 1 replay(s) passed.
```

- Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/red-stderr.log`.
- Fix direction: decide pass/fail first (`Replay.reasons` for verify; `Replay.pinReasons` for pin), then print every failed result's non-empty tail.

### reviewer-10-F2 — minor — byte-cut stderr discards a valid Unicode suffix

- At `48bc51d`: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Replay.lean:95` (`run`'s final stderr conversion).
- Contract: `kernel.md` § Replay, Run + Pass: stderr's last 4 KiB are kept for display; a fail shows its stderr tail. § Replay, Log: the kept non-empty tail is logged.
- Wrong: an arbitrary 4096-byte cut can start inside one UTF-8 character. `String.fromUTF8? bytes |>.getD "(not UTF-8)"` then drops every complete character after it. A fully valid UTF-8 stream of 4097 bytes (`é` + 4092 `x` + `END`) displays/logs only `(not UTF-8)` rather than its diagnostic suffix.
- Red command: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/red-utf8-tail.py` → rc 1 on the base. Output:

```text
positive control: verifier stderr = 4097 valid UTF-8 bytes, ends END
verify rc=1
  O1: its error output ends with: (not UTF-8)
FAIL: valid UTF-8 verifier stderr lost its complete diagnostic suffix at the 4096-byte cut
```

- Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/red-utf8-tail.log`.
- Fix direction: decode the byte tail lossily, or discard only an incomplete leading code point, preserving the complete suffix.

### reviewer-10-F3 — minor — an inaccessible log is reported as empty history

- At `48bc51d`: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:417` (`showLog`).
- Contract: `kernel.md` § Replay, Log: “an unreadable log ⇒ rc 2”; no log alone earns `runs: []`, rc 0.
- Wrong: `file.pathExists` collapses a parent-directory permission failure into false. A resolvable project with one recorded replay then gets a successful empty history when its data-folder entry cannot be traversed. This hides an I/O failure as “no replay has run.”
- Red command: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/red-unreadable-log.py` → rc 1 on the base (unprivileged uid; the script returns 2 if the platform bypasses mode 000). It first reads exactly one log event, then removes directory traversal permission inside this review's scratch path; Python's read raises `PermissionError`, but fvtrace returns:

```text
positive control: readable log contains exactly 1 successful replay
verify --log --json rc=0
{
  "schema": "fvtrace.replays/1",
  "log": "…/replays.log",
  "runs": []
}
FAIL: an existing but unreadable replay log must return rc 2, not an empty success
```

- Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/red-unreadable-log.log`.
- Fix direction: attempt the open directly; treat only a genuine missing-file error as absent, propagate permission/other I/O errors to rc 2.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/c/fvtrace_digest.c:19` — security → MAIN.

## Executed checks + coverage

- `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/smoke-receipts.py` → rc 0, **55 checks**. Independent canonical manifests + native SHA vs hashlib (11 file sizes), all defined binding variants, exact stale sets, review digest, display-field exclusions, missing/directory artifacts, cache opt-in/default behavior + best-effort failure.
- `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/smoke-replay.py` → rc 0, **35 checks**. Pass/fail modes, raw output hashing, relative executable resolution, process/group deadlines (1.038 s / 1.022 s), notice persistence/clearing + review invariance, repeated-failure no-write, log events/order/malformed-line handling, duplicate-id decode-only pin + concurrent-draft write refusal.
- `(cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-10/pure-receipts.lean)` → rc 0, **26 checks**. Binding lookup, every replay reason/notice branch, positional result application + review states. The scratch probe's first attempts had syntax/equality-instance errors; corrected before this passing run (not target failures).
- `clang --analyze -Xclang -analyzer-werror -I"$(lean --print-prefix)/include" -I/home/eturkes/Projects/fvtrace/.scratch/review-base/c/hacl -I/home/eturkes/Projects/fvtrace/.scratch/review-base/c/hacl/include -DKRML_VERIFIED_UINT128 /home/eturkes/Projects/fvtrace/.scratch/review-base/c/fvtrace_digest.c -o /dev/null` → rc 0.
- Three red witnesses above → rc 1 each on the frozen base; each has its positive control. The permission probe restores its directory mode in `finally`.
- `pgrep -af '[f]vtrace-tests --replay-fixture'` → rc 1, no fixture processes. No server started. Temporary projects removed by the probes; generated `home/` entries removed at close; scripts + captured outputs retained for MAIN.
- Not run: full gate, mutation campaigns, existing suites wholesale, non-Linux platforms. Unconfirmed: forced C allocation failure + SHA-256 cumulative-length overflow (shim's guards/returns read; not fault-injected). LSP `.lean` coverage unavailable (`documentSymbol` returned “No LSP server available for file type: .lean”); source search + Lean execution used instead.

reviewer-10-DONE-1
