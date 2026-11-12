# reviewer-13 — C-cli / Correctness — base `48bc51d`

Target root = `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Fixed check set = assigned C-cli asks + L1/L2. Source untouched; all mutable inputs + outputs under `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/`.

| row | target | verdict | basis |
|---|---|---|---|
| C-cli | Args.lean + Cli.lean argument parsing + exit codes | reviewer-13-F4 | Full Args/Cli read; unrecognized/repeated flags, missing values, positional counts, incompatible options driven. Startup I/O exception escapes exit-2 boundary. |
| C-cli | Store.lean: data folder + entries + writes | pass | Full file + Session callers read; default/explicit trace mapping, real-project keying, no project writes checked. A 250-byte basename works on this host. Platform branches inspected; Linux runtime alone. Shared replacement separately below. |
| C-cli | init / path / check / pin / review | pass | Fresh project + copied synthetic trace driven; create/refuse overwrite, pin, strict checks, review, receipt bindings, project mapping, absent/invalid target paths inspected. Shared replacement separately below. |
| C-cli | verify (list, --run, --log) | reviewer-13-F2, reviewer-13-F3 | Full CLI/Replay paths read; 12 replay CLI invocations pass (pin, run, notices, review invariance, log, concurrent-edit refusal); exit-zero failure hides stderr; listing JSON omits required member. |
| C-cli | claims / gaps / experiments / plan / eval text + --json (L1) | reviewer-13-F1 | Text driven + JSON projections equal envelope, plan JSON equals full details, action + batch agree. L1 confirmed: plan drops engine qualifiers. Remaining-premise hypothesis retired: synthetic plan lists R1/R2 under its settled needs. |
| C-cli | export --html / --bundle | reviewer-13-F6 | HTML + bundle created; bundle strict-checks; nonempty bundle + destinations in project refused. Failed HTML replacement leaves sibling temporary. |
| C-cli | skills install / show, schema, --help, --version (L2) | reviewer-13-F5 | Explicit scratch installer + reinstall, embedded skill/schema equality, help/version pass. L2: unsupported subcommand help = register; data-error usage dump = required V-cli transport; schema's false command diagnostic = F5. |
| C-cli | serve: bind, link, opener, token file | pass | Full functions + Server.start/stop callers inspected; `--port 0 --no-browser` driven normally + token-file mode; IPv4/IPv6 same-port answers equal eval; private token stays out of token-file output. Both PIDs stopped + ports refuse. Opener, fixed-port collision, retry exhaustion, non-Linux paths source-only per brief hard line. |
| C-cli | Assets + Version + embedded files | pass | Full assigned files + Lake tracing declarations read; schema/skill + four installed skill files byte-equal; all 14 served GUI assets byte-equal; CLI version equals source/Lake 0.1.0. Version proof directly checks the closed constant. |
| C-cli | tests (setup/teardown, asserts) | pass | All assigned test files read + Harness capture/cleanup helpers inspected: temp scopes, explicit link cleanup, injected Store.Env, isolated smoke environment, held listener stopped. No C-cli setup/teardown defect found; separate assertion-strength lead in Register. Existing suites not rerun. |
| C-cli | shared replaceFile / writeTrace partial-failure cleanup | reviewer-13-F6 | Full helper + callers read; sibling temporary remains when rename fails. |

## Findings

### reviewer-13-F1 — major — plan omits the engine's claim qualifiers

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:764`.
- Contract: `.agent/spec.md` Decisions, Review: every surface shows the engine label, including prospective qualifier; `kernel.md:89`, label = verdict + qualifiers.
- Why: `claims` prints `A.qualifiers`; `plan` prints the verdict and sentence alone. A new-data claim reads `Fully supported` without saying that its cohort must first be collected. The footer names the overall what-if/review state, but never supplies the missing prospective qualifier.
- Red command:

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/red.py qualifiers
```

Observed rc 1; positive control + failure:

```text
positive control (claims): C3 Fully supported [what-if, draft, if Collect a new cohort runs]: In the new cohort's data table, the treated samples' average marker level is higher than the controls'.
fvtrace rc=0
C3 Fully supported: In the new cohort's data table, the treated samples' average marker level is higher than the controls'.
AssertionError: plan dropped the engine qualifiers from the claim label
```

Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/qualifiers.log`.
Fix direction: share the claim-label renderer with `claimsCmd`; keep creator titles + all engine qualifiers.

### reviewer-13-F2 — minor — exit-zero replay failures hide captured stderr

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:287`.
- Contract: `kernel.md:61`, replay failure includes output mismatch/unpinned output; “A fail shows stderr's tail.”
- Why: `runReplay` displays the tail only when process exit differs from zero. `verify --run` can fail with exit zero (`output changed`, `output not pinned`); its failure line then omits the already-captured diagnostic. The append-only log retains it, proving capture succeeded.
- Red command:

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/red.py replay-stderr
```

Observed rc 1:

```text
positive control: fixture check rc=0
positive control (log tail): replay-tail-marker
fvtrace rc=1
  F: running /bin/sh replay.sh
  F: failed (output changed)
0 of 1 replay(s) passed.
AssertionError: failed replay hid its captured stderr tail
```

Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/replay-stderr.log`.
Fix direction: display the tail once the command-specific pass/fail decision is known, including exit-zero verification failures.

### reviewer-13-F3 — minor — verify listing JSON omits required reasons array

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:485` (member added only inside `if runs`, line 500).
- Contract: `kernel.md:65`: `fvtrace.verify/1` replay rows = `{id, command, pinned, ran, passed?, reasons, failed?}`; `reasons` is required, unlike `passed?`.
- Why: `verify --json` succeeds but listing rows have no `reasons` member. A consumer implementing the declared shape cannot consume the non-running form with the same decoder.
- Red command:

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/red.py verify-reasons
```

Observed rc 1:

```text
positive control: replay rows=1
listing replay: {"command": ["/bin/sh", "replay.sh"], "id": "F", "pinned": true, "ran": false}
AssertionError: verify listing omitted the required reasons array
```

Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/verify-reasons.log`.
Fix direction: emit `reasons: []` in listing rows; preserve populated reasons for attempted runs.

### reviewer-13-F4 — minor — environment detection bypasses I/O error boundary

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:1130`; callee `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Store.lean:47`.
- Contract: `kernel.md:10` + `README.md:166`, usage/I/O errors exit 2. `runIn` promises that boundary, but `Store.Env.detect` runs before it.
- Why: a process started in a folder removed before exec fails `IO.currentDir` outside the handler. The native binary exits 1 with an uncaught exception, classifying a cwd read failure as a failing trace. Even `--version` fails although no project is needed.
- Red command (Linux/POSIX witness):

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/red.py vanished-cwd
```

Observed rc 1:

```text
positive control: existing cwd --version rc=0
fvtrace rc=1
uncaught exception: failed to retrieve current working directory
AssertionError: cwd I/O error bypassed the CLI exit-2 boundary
```

Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/vanished-cwd.log`.
Fix direction: include detection in the top-level exception boundary; project-independent commands may bypass detection entirely.

### reviewer-13-F5 — minor — invalid schema arguments misdiagnose a valid command

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:1102` + `:1118`.
- Contract: `CLAUDE.md:37`, human-facing error states what happened + the fix; README Commands names `schema` as a command.
- Why: only the exact singleton argument list dispatches schema. `schema --help` falls through to the absent-command diagnostic, although `schema` exists. Lack of subcommand help is not itself a contract violation; the false diagnostic is.
- Red command:

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/red.py schema-diagnostic
```

Observed rc 1 (the full stderr, including the false diagnostic, is in the log):

```text
positive control: schema prints JSON, rc=0
fvtrace rc=2
AssertionError: valid command misdiagnosed as absent
```

Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/schema-diagnostic.log`.
Fix direction: dispatch `schema :: rest` through its argument parser, or support its help request; diagnose unsupported arguments rather than an absent command.

### reviewer-13-F6 — minor — failed atomic replacement leaves its temporary file

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:116–122`; HTML caller `:901`.
- Contract: fixed C-cli check set, writes → partial-failure cleanup; `CLAUDE.md` Engineering Correctness → error paths/resource cleanup.
- Why: `replaceFile` removes an earlier sibling temporary, writes a new one, then renames without failure cleanup. `export --html` given an existing directory returns the correct error, but leaves the whole generated page in `<dest>.fvtrace-tmp`.
- Red command:

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/red.py replace-cleanup
```

Observed rc 1:

```text
positive control: destination is a directory; sibling temporary count=0
fvtrace rc=2
after failure: destination directory=True, sibling temporary bytes=739063
AssertionError: failed atomic replacement left its sibling temporary file
```

Full output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/replace-cleanup.log` (includes rename error code 21).
Fix direction: remove this invocation's temporary on put/flush/rename failure; preserve the destination. The helper serves trace writes + redirects as well as HTML export.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:1100` — L2: per-command help is unsupported; no promise requires it. Usage exit 2 is conforming. Potential CLI ergonomics change, separate from F5's false diagnosis.
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:546` — source-only CLI-surface lead: shared eval spec accepts `--question` on gaps/experiments/plan/eval, whose handlers ignore it. Contract defines unfiltered projections; not a C-cli finding.
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/tests/cli/smoke.sh:25` + `:175–176` — V-* lead, runtime unconfirmed: before/after hash comparison ignores empty directories (directory hashing errors discarded), so its project-unchanged assertion may miss an added empty directory. Source inspected; faulty-binary probe not run.
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:116` — security → MAIN.

## Coverage + checks

- All assigned source + test files read in full. Callee context: Session, Replay, Receipt, Export, Present, Harness; Lake embedded-input declarations + Server start/stop routing inspected.
- Passed: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/check.py` → rc 0, `ALL 388 isolated checks passed`. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/check.log`.
- Passed: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/replay.py` → rc 0, `ALL 12 replay CLI invocations passed (pin/run/notices/review/log/CAS)`. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/replay.log`.
- Failed as intended: six finding-specific `red.py` commands above, each rc 1 on the frozen base. Native command rc distinguished inside each witness.
- L2 data errors appending the full usage are **pass**, not a defect: kernel.md V-cli explicitly requires this transport.
- Retired hypotheses: long project basename works on this host; plan's synthetic remaining-premise ids are present. Their witness logs = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/long-name.log` + `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-13/plan-premises.log`.
- Server ownership: PIDs 971854 + 971871 terminated by PID; `wait` completed + both IPv4 ports refused. Final `pgrep -af '[f]vtrace serve'` → rc 1, no matches; positive control = both recorded starts in check.log.
- Not run: full gate, existing Lean/CLI smoke suites, mutation campaigns, browser GUI/export-page execution, real opener, macOS/Windows runtime checks. These are coverage limits, not green claims. No builds or target mutations. LSP call on Args.lean returned “No LSP server available for file type: .lean”; source/caller reads used instead.

reviewer-13-DONE-1
