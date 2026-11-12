| row | target | verdict | basis |
|---|---|---|---|
| C-scale | scale.mjs: shapes, sizes, N_cap | pass | Shapes + generated targets read against P-bound; all seven graded shapes + receipts generated at n=3, native `check` rc=0; cap bracketing/bisection + compact-byte/argument bounds inspected (cap-sized runs reserved for MAIN). |
| C-scale | scale.sh: rows, ratios, thresholds, RSS cap, exit codes | reviewer-19-F1 | Thresholds + doubling math + F5 RSS baseline inspected; red session-exit witness: complete GUI rows + driver exit 3 → `scale.sh` rc=0. |
| C-scale | scale-gui.mjs: U-time measurement points | reviewer-19-F2 | Exact base `timed` function exercised in bundled Chromium: pre-click ready inspector → reported 5.4 ms although the clicked request's details took 1601.7 ms (deep reselects its sole claim). First/busy/what-if/startup predicates + memory collection inspected. |
| C-scale | scale-page.mjs | pass | Startup/load/request/error sequencing + problem rc detection + wall/user/RSS/byte fields inspected; real exported wide n=3: page, claim/fact details, action rows all rc=0 (script rc=0). |
| C-scale | compare.sh: equality, transform, oracles, timeouts | reviewer-19-F3, reviewer-19-F4 | Byte comparisons + v1 transform + timeout counter read; v1 oracle accepts NEW rc=7 + differing stderr (934 runs, rc=0); distinct truncated JSON also passes (918 runs, rc=0). Same-binary full run unconfirmed: outer limits 60 s and 180 s reached (per-run limit 2 s), no reported difference before interruption. |
| C-scale | cleanup (children, temp folders) | reviewer-19-F5 | Normal n=3 GUI run + scale run removed owned temp folders and servers; spawn ENOENT leaves a temp home (red witness, then removed by witness). Final `pgrep -af '[r]eviewer-19'` rc=1; scratch tmp + spawn-tmp empty. |

## reviewer-19-F1 — major — failed session exit ignored after its rows exist

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/scale.sh:150` (`session_row`; session rc written at lines 134, 142).
- Contract: kernel.md P-evidence: `--assert` fails on a nonzero exit or timeout. A driver's completed measurement rows are insufficient when the session then fails (cleanup exceptions, crashes, timeout after printing rows).
- Defect: `session_row` returns an existing measurement before inspecting `page.rc` / `gui.rc`; those status files affect only absent rows. A GUI driver emitting every required row and then exiting 3 gets `scale: every graded run within its bounds`, rc=0. The same precedence masks rc=124 after all rows were emitted.
- Red witness (base script + binary copied unchanged; generated n=2,4 only): `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-session-exit.py` → rc=1:

```text
scale.sh rc=0; driver emits complete rows then exits 3
scale: every graded run within its bounds
AssertionError: FAIL: nonzero GUI session exit is accepted as within bounds
```

- Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/session-exit.log`.
- Fix direction: grade each session's exit status independently of its per-step rows; retain measured rows for diagnostics, fail on rc≠0 (including 124).

## reviewer-19-F2 — major — claim-details timer accepts the pre-click answer

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/scale-gui.mjs:102–104`; reachable at lines 184–194 on `deep`, whose board has one claim (`b = a`).
- Contract: kernel.md U-time: details shown ≤1 s from this input event's timestamp once the source holds the view. `web/app.js:627–676` re-requests the selected item's details on every selection (`on.select` at lines 688–702).
- Defect: the capture listener checks `holds(ready)` before the application's click handler clears the old answer. If the same claim was already ready, it schedules a success callback immediately; that callback records the time without rechecking the predicate. On deep, the details step always reselects the claim just timed for selection. A slow new details response can pass against the old ready state.
- Red witness: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-gui-details.mjs` → rc=1. It extracts the exact `timed` function from the base, runs it in bundled Chromium, and models that one-card reselect (ready before click; pending at the handler; ready after 1.5 s):

```text
same claim reselected (deep's one-card path): reported 5.4 ms; new details ready 1601.7 ms
AssertionError [ERR_ASSERTION]: FAIL: details timing accepted the pre-click ready state; the new request takes >1 s
```

- Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-gui-details.log`.
- Fix direction: require the click's new request/answer transition, not the pre-click predicate; at least start observing after the handler and recheck at the measured frame.

## reviewer-19-F3 — major — v1 oracles ignore exit code + stderr

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/compare.sh:105–108` (expansion); same omission at lines 112–114 (details).
- Contract: kernel.md V-cli: `exit codes + stderr kept`; README Development: outputs in the same format byte-equal; `compare.sh` header: stdout + stderr + exit code compared. Timeouts are separately counted correctly by `run_one`.
- Defect: the v1 expansion/detail oracle compares parsed stdout alone. Correct JSON followed by a new failure exit or changed stderr is accepted; unlike `cmp_run` / `cmp_json`, it never compares `.rc` / `.err`.
- Red witness: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-compare-oracle.py` → rc=1. OLD returns a small v1 envelope; NEW returns its correct v2 transform but every `--action` run prints `new expansion failed after writing valid JSON` to stderr and exits 7:

```text
compare.sh rc=0; NEW action output is correct JSON but stderr differs and rc=7
compare: 934 runs, 0 differing outputs, 0 timeouts (.../old-compare-stub vs .../new-compare-stub)
AssertionError: FAIL: v1 expansion oracle ignores the new binary's stderr + exit code
```

- Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-compare-oracle.log`; payload = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/compare-stub.sh`.
- Fix direction: enforce expected successful rc + stderr on oracle requests (compare expansion's old/new status + stderr; compare details against the successful envelope oracle's status + stderr).

## reviewer-19-F4 — major — failed JSON normalization becomes false equality

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/compare.sh:83–84` (`cmp_json`; form detection at line 149 also treats invalid JSON as the v1 branch).
- Contract: kernel.md V-cli: transformed output compared structurally; README Development: fails when outputs differ. Distinct partial JSON is neither structural equality nor valid transform input.
- Defect: `jq` exits nonzero on malformed/truncated output, leaving empty `.json` files; `cmp_json` ignores both exit codes and compares those empty files as equal. An invalid form probe also silently selects the transform path. The raw outputs can differ while the final comparison says 0 differences.
- Red witness: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-compare-json.py` → rc=1. OLD emits `{` on eval/JSON projections, NEW emits `[`, both exit 0; all same-format commands stay byte-equal:

```text
compare.sh rc=0; OLD eval prints '{'; NEW eval prints '['
jq: parse error: Unfinished JSON term at EOF at line 2, column 0
compare: 918 runs, 0 differing outputs, 0 timeouts (.../old-bad-json vs .../new-bad-json)
AssertionError: FAIL: distinct malformed JSON is compared as equal empty jq output
```

- Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-compare-json.log`.
- Fix direction: count failed form detection/JSON transforms as comparison failures; compare only successful, nonempty normalized documents.

## reviewer-19-F5 — minor — failed server spawn bypasses GUI-driver cleanup

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/scale-gui.mjs:295` (link promise subscribes to `exit`, not spawn `error`; temp home created at line 270).
- Contract: C-scale cleanup check + CLAUDE.md Execution task close (temporary artifacts removed); driver line 242 promises cleanup on every way out.
- Defect: `spawn` ENOENT/EACCES emits an unhandled ChildProcess `error`; Node aborts instead of rejecting `linked` into the outer `finally`. Its task-created `scale-gui-*` home survives. The driver accepts a binary path, so a missing/non-executable `--bin` reaches this path.
- Red witness: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-gui-spawn.py` → rc=1. It uses a missing binary and a missing Playwright browser directory (no browser child), counts new temp homes, then removes them:

```text
scale-gui rc=1; task-created temp folders left=1 (expected 0)
.../spawn-tmp/scale-gui-GXAqVp
AssertionError: FAIL: server spawn ENOENT bypasses stop() and leaves its temporary FVTRACE_HOME
```

- Driver stderr: `Unhandled 'error' event` / `Error: spawn .../absent-binary ENOENT` in `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/gui-spawn.log`; test output `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-19/red-gui-spawn.log`.
- Fix direction: reject the link promise on spawn `error`, route it through `finally`; in `stop`, wait only for a process that spawned successfully.

## Coverage + limits

- Fixed six-row C-scale set adjudicated. All five target source copies `cmp`-equal to the frozen base (rc=0 each). Base read-only; deliverable + scratch alone written; git untouched.
- Read all five target scripts + scale/compare probe bodies, kernel.md Performance + U-time/V-cli clauses, fast.md evidence bullet, README Development + relevant Decisions. LSP coverage confirmed on scale.mjs (`documentSymbol`). Probe breaches reasoned from source; `gate-probe.sh` not run.
- Real runs: every graded shape + receipts at n=3 (`check` rc=0); real export n=3 rc=0; scale-page n=3 all four rows rc=0; scale-gui n=3 all 11 expected rows rc=0 and normal cleanup completed. This host was loaded, not the idle reference host: several GUI wall values exceed their bounds; these are functional smoke results, not P-bound/U-time acceptance evidence. No cap generation or full `--assert` run; MAIN owns reference-host acceptance.
- Two same-binary comparison attempts used per-run timeout 2 s; outer bounds 60 s and 180 s interrupted both (rc=124, no DIFF output). Complete real-binary parity remains unconfirmed; stub comparisons above did finish. The spawn-cleanup witness's initial 15 s outer bound expired before spawn; its 90 s retry reached the proved ENOENT path.
- Red witnesses retained as validator inputs; all started review processes exited, scratch runtime tmp folders empty. No security observation or off-contract register entry.

reviewer-19-DONE-1
