# reviewer-14 — C-cli / Correctness

Target = frozen `48bc51d`, `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Check set = assigned C-cli brief, fixed before target reads. All assigned sources + tests read in full; callees inspected for target resolution, receipt writes, replay results, evaluation projections, bundle writes + server lifecycle.

| row | target | verdict | basis |
|---|---|---|---|
| C-cli | Args.lean + Cli.lean argument parsing + exit codes | reviewer-14-F3, reviewer-14-F5, reviewer-14-F7 | Argument schemas + dispatch read; native matrix covers positional counts, foreign/repeated flags, missing values, invalid timeouts/ports + trace/read errors. Three non-trace error-path discrepancies below. |
| C-cli | Store.lean: data folder + entries + writes | reviewer-14-F2 | Env/platform/keying/mapping/link logic read; native project mapping, explicit override, symlink identity + same-basename separation pass. Valid near-NAME_MAX project produces an invalid data-entry component. |
| C-cli | init / path / check / pin / review | reviewer-14-F2 | Fresh init/path/check, duplicate-init preservation, pin decode-only behavior, strict failures, sign-off + display-field review invalidation pass. Long-project init fails at entry creation. |
| C-cli | verify (list, --run, --log) | reviewer-14-F4 | Opt-in, pin output, changed output, notices, clear-on-pass, append-only runs, corrupt-log skipping + log-without-trace pass; exit-0 verifier failure hides stderr tail. |
| C-cli | claims / gaps / experiments / plan / eval text + --json (L1) | reviewer-14-F1 | Native projections equal eval; full plans equal details; complete item order/lists equal direct details; exact sentences + action/refusal transport pass. Plan omits engine qualifiers. |
| C-cli | export --html / --bundle | reviewer-14-F6 | Native in-project refusal, HTML payload, bundle evidence byte equality, colleague check + nonempty refusal pass. Failed HTML replacement leaves its temporary file. |
| C-cli | skills install / show, schema, --help, --version (L2) | reviewer-14-F3, reviewer-14-F7 | Native skill install/reinstall/show + byte equality, schema bytes, version + top-level help pass. L2: global-only help is not prohibited; V-cli explicitly requires usage after data refusals. Schema extra-argument diagnostic is false. |
| C-cli | serve: bind, link, opener, token file | pass | Read serveCmd + Server.start/stop boundary; helper suite covers opener selection + busy-port retry; 15 native assertions cover dual-loopback equality, launch readiness, no-browser/token-file output, invalid token files, PID reaping + refused ports. |
| C-cli | Assets + Version + embedded files | pass | All embeds + version/spec/proof + Main→Cli wiring + Lake `needs` read; assigned FFI-free suite 115/115, schema/skill bytes + version also checked through native binary. |
| C-cli | tests (setup/teardown, asserts) | reviewer-14-F3 | Assigned tests read; temp scopes + subprocess environment isolation otherwise symmetric. Tests/Cli:110 pins the wrong non-trace refusal code. FFI-free assigned subset 115/115; black-box suite 304 assertions; serve suite 15 assertions. |

## Findings

### reviewer-14-F1 — major — `plan` drops the prospective qualifier (L1)

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:764`.
- Contract: Decisions **Review**: every surface shows the engine label, including prospective qualifier; kernel.md **Sentences**: `if <creator title> runs` belongs to a prospective claim's label.
- Defect: `plan` prints final verdict + sentence directly; unlike `claimsCmd`, it never reads `A.qualifiers`. Supposing the new cohort's result verified prints `C3 Fully supported` with no condition that its creator must run. Its footer identifies the what-if + draft but never identifies the creator. JSON + `claims` preserve that qualifier.
- Anchor: `say s!"{c.id} {(A.final c).verdict}: {A.sentence c}"` → line 764.
- Red command:
  ```sh
  python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/plan-label-red.py
  ```
  Output, rc **1**:
  ```text
  positive control: claims carries the engine creator qualifier (expected count 1): 1
  plan first line: C3 Fully supported: In the new cohort's data table, the treated samples' average marker level is higher than the controls'.
  FAIL: plan drops the prospective creator qualifier; expected [if Collect a new cohort runs]
  ```
- Fix direction: share the claim-label printer with `claimsCmd`; preserve every engine qualifier in plan's claim line.

### reviewer-14-F2 — minor — a valid long project name makes its data-entry name invalid

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Store.lean:54–57`.
- Contract: Decisions **Product** + README **Where fvTrace keeps its files**: one usable data-folder entry per project folder; Correctness: whole input domain + platform boundaries.
- Defect: `entryName` retains the complete project basename, then appends `-` + 12 digest characters. A legal project basename near the filesystem component bound yields an illegal entry component. A readable/writable project cannot run `init` even though its data folder is also writable. The witness derives `PC_NAME_MAX`; this host's bound is 512, so a valid 502-byte basename becomes a 515-byte key. On a 255-byte filesystem the same construction uses 245 → 258.
- Anchor: `return s!"{name}-{String.ofList (digest.toList.take 12)}"` → line 57.
- Red command:
  ```sh
  python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/edge-red.py long-project
  ```
  Relevant output, rc **1** (full error path in `logs/long-project-red.log`):
  ```text
  positive control: valid project folder accepts a file; basename bytes = 502
  init rc = 2
  fvtrace: invalid argument (error code: 36, name too long) ...
  FAIL: a valid project folder cannot be initialized; entry appends 13 bytes to basename
  ```
- Fix direction: keep a bounded readable prefix that leaves room for the digest, with a portable component bound; the digest continues to key the real project path.

### reviewer-14-F3 — minor — skill destination refusal returns invalid-trace status

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:860`; test pins it at `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Cli.lean:110` (linked-folder refusal likewise pins 1 at line 125).
- Contract: kernel.md **Decode / CLI exit codes**: 1 = invalid trace, 2 = usage or I/O; README **Commands / exit status**: 1 = invalid or failing trace. No trace participates in a skill installation.
- Defect: refusing `--dir` because its `fvtrace` child belongs to the user sets rc 1. Equivalent destination refusals in `init` + `export` use 2. A caller cannot use the promised code classification; the test preserves the mismatch.
- Anchor: `| .error m => complain s!"fvtrace: {m}"; rc := 1` → line 860.
- Red command:
  ```sh
  python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/edge-red.py skill-exit
  ```
  Output, rc **1**:
  ```text
  positive control: user-owned SKILL.md is preserved = True
  skills install rc = 1
  fvtrace: /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/skills-unowned/fvtrace exists and was not written by fvtrace; remove it or give --dir
  FAIL: non-trace destination refusal must be usage/I/O rc 2, not invalid-trace rc 1
  ```
- Fix direction: classify these destination refusals consistently as 2; adjust their tests against the unchanged exit-code contract.

### reviewer-14-F4 — minor — an output-changed replay hides its stderr tail

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:287`.
- Contract: kernel.md **Replay**: `A fail shows stderr's tail.` Failure includes `output changed` + `output not pinned`, not just a nonzero process exit.
- Defect: `runReplay` displays stderr only when `run.exit != some 0`. A verifier can exit 0 yet fail verification because stdout differs; its diagnostic is retained in the log but omitted from the command's output. The same guard drops the tail on `output not pinned`.
- Anchor: `unless run.exit == some 0 || run.stderrTail.isEmpty do` → line 287.
- Red command:
  ```sh
  python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/replay-stderr-red.py
  ```
  Output, rc **1**:
  ```text
  positive control: failed replay log retains stderr diagnostic = True
  verify --run --json rc = 1
  stderr:
    F: running /usr/bin/python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/stderr-verifier.py
    F: failed (output changed)
  0 of 1 replay(s) passed.
  FAIL: an output-changed replay fails, but its nonempty stderr tail is not displayed
  ```
- Fix direction: decide failure first in the caller, then display a retained tail for every failing result; pin's exit-0 result remains a success.

### reviewer-14-F5 — minor — startup I/O exceptions bypass the exit-2 handler

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:1129–1130` (`Store.Env.detect` calls `IO.currentDir` at Store.lean:47).
- Contract: kernel.md **Decode / CLI exit codes** + README **Commands / exit status**: read/I/O error → 2; Cli.runIn's own contract says unanticipated I/O failures return 2 with their message.
- Defect: environment detection executes before `runIn`'s `try`. If the working directory was removed, `IO.currentDir` throws; Lean's process wrapper prints an uncaught exception + returns 1, although no trace was read.
- Anchor: `match ← Store.Env.detect with` → line 1130.
- Red command:
  ```sh
  python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/failure-red.py cwd-exit
  ```
  Output, rc **1**:
  ```text
  positive control: path in an existing cwd returns 0 = True
  path in deleted cwd rc = 1
  uncaught exception: failed to retrieve current working directory
  FAIL: startup I/O error escapes runIn and becomes invalid-trace rc 1, expected 2
  ```
- Fix direction: put environment detection inside the same exception-to-rc-2 boundary as dispatch.

### reviewer-14-F6 — minor — failed HTML replacement leaves the full temporary file

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:115–122` (`replaceFile`, reached by exportCmd:901).
- Contract: assigned Correctness check: error paths, resource cleanup + partial-failure cleanup; `replaceFile` owns a sibling temporary file whose useful lifetime ends with that replacement attempt.
- Defect: the temporary write/flush/rename has no failure cleanup. `export --html` naming an existing directory fails correctly with 2 but leaves `<destination>.fvtrace-tmp` containing the complete 739,063-byte export. Other replacement failures share the same leak.
- Anchor: `IO.FS.rename tmp file` → line 122.
- Red command:
  ```sh
  python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/failure-red.py export-cleanup
  ```
  Relevant output, rc **1**:
  ```text
  positive control: destination remains an empty directory = True
  export rc = 2
  fvtrace: inappropriate type (error code: 21, illegal operation on a directory) ...
  temporary body left after failure = True
  temporary body bytes = 739063
  FAIL: failed replaceFile leaves its sibling temporary file; test cleaned it
  ```
- Fix direction: bracket the temporary file's lifetime; remove it after every failed write/flush/rename while preserving the destination + original exception.

### reviewer-14-F7 — minor — `schema` with an extra argument falsely reports an unrecognized command (L2)

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:1102,1118`.
- Contract: CLAUDE.md **Authoring / human-facing errors**: an error states what happened + the fix. README + help list `schema` as a command.
- Defect: dispatch recognizes only exactly `["schema"]`; `["schema", "--help"]` falls through to the unrecognized-command branch. This is not a request to add command-specific help: rejecting the extra argument is allowed, but blaming the known command is false. Every extra argument follows this path.
- Anchor: `| ["schema"] => IO.print Assets.traceSchema; pure 0` → line 1102.
- Red command:
  ```sh
  python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/edge-red.py schema-error
  ```
  Relevant output, rc **1** (full diagnostic in `logs/schema-error-red.log`):
  ```text
  positive control: schema command succeeds = True
  schema --help rc = 2
  FAIL: error calls the known schema command unrecognized instead of naming the invalid argument
  ```
- Fix direction: route `schema :: rest` through its zero-argument parser; name the unexpected flag/argument, keeping rc 2.

## Register / lead dispositions

- L2 — `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:1099–1118`: command-specific `--help` is not promised; `claims --help` returns 2 + a refusal naming `--help` as an unrecognized option. Top-level `--help`/`-h` work. Per-command help = optional CLI-surface improvement, not a finding.
- L2 — `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:105–108`: whole usage after a refused what-if or absent plan claim is explicitly required by kernel.md V-cli (`message + usage`, rc 2); **pass**, not a defect. Measured `claims --help` stderr = 4,523 bytes including its message.
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:566`: shared evaluation schemas also accept `--question` on commands that never use it; projections ignore it, matching V-cli's explicit projection keys. Undocumented/no-op option acceptance = surface-consistency register entry, no contract-backed finding here.

## Checks + limits

- `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/cli-correctness.py` → **rc 0, 304 assertions passed**. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/logs/cli-correctness.log`.
- Assigned FFI-free tests (`Tests.Cli.tests/skillTests/writeTests/bindTests/readTests/groupTests`, `Tests.Args.tests`, `Tests.Assets.tests`) through `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/assigned-pure.lean` → **rc 0, 115/115**. Run from `/tmp`, base LEAN_PATH; snippet sets cwd to private copy; FVTRACE_HOME + TMPDIR isolated under own scratch. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/logs/assigned-pure.log`.
- `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/serve-checks.py` → **rc 0, 15 assertions passed**. Owned server PIDs **994521, 994530** terminated + reaped; both ports refused after stop. Final `pgrep -af '[f]vtrace.*reviewer-14.*'` → **rc 1**, no owned server remains. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-14/logs/serve-checks.log`.
- Seven red witnesses above → **rc 1 each**, native base binary. The long-name probe first tried 245 bytes and passed; `PC_NAME_MAX = 512` explained it, so the final witness derives its boundary from the actual filesystem.
- Read-only on frozen base + primary code. No build, mutation campaign, full gate, commit or browser launch. Full native `Tests.CliStore`/smoke suites were read, not run wholesale; their relevant behaviors were driven by the black-box suite. The live opener is unconfirmed by policy (`serve` always `--no-browser`); its pure selection logic + existing tests were inspected/run. macOS/Windows platform branches read, not executed. Environment-dependent defaults read; hard-line FVTRACE_HOME isolation prevents exercising the real user's default folder. Lean LSP probe → no configured `.lean` server; code intelligence was textual.
- Fixtures use the shipped synthetic example + a minimal replay trace; they are not exhaustive trace generation. Native trace/error/projection checks are sampled across the argument matrix above. No claim of whole-repo gate green.

reviewer-14-DONE-1
