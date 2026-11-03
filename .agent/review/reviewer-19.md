| row | target | verdict | basis |
|---|---|---|---|
| C-scale | scale.mjs: shapes, sizes, N_cap | pass | Shapes + generated targets read against P-bound; all seven graded shapes + receipts generated at n=3, native `check` rc=0; cap bracketing/bisection + compact-byte/argument bounds inspected (cap-sized runs reserved for MAIN). |
| C-scale | scale.sh: rows, ratios, thresholds, RSS cap, exit codes | reviewer-19-F1 | Thresholds + doubling math + F5 RSS baseline inspected; red session-exit witness: complete GUI rows + driver exit 3 → `scale.sh` rc=0. |
| C-scale | scale-gui.mjs: U-time measurement points | reviewer-19-F2 | Exact base `timed` function exercised in bundled Chromium: pre-click ready inspector → reported 5.4 ms although the clicked request's details took 1601.7 ms (deep reselects its sole claim). First/busy/what-if/startup predicates + memory collection inspected. |
| C-scale | scale-page.mjs | unknown | unknown |
| C-scale | compare.sh: equality, transform, oracles, timeouts | reviewer-19-F3 | Byte comparisons + v1 transform + timeout counter read; v1 expansion oracle accepts NEW rc=7 + differing stderr: 934 runs, 0 differing outputs, 0 timeouts, rc=0. Same-binary full run unconfirmed: outer limits 60 s and 180 s reached (per-run limit 2 s), no reported difference before interruption. |
| C-scale | cleanup (children, temp folders) | unknown | unknown |

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
