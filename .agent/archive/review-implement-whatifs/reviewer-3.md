# reviewer-3 · closing review (U11) · lens R3 · target 01cf228^..f3bc87f

Target checkout = `.scratch/worktrees/v1`, HEAD `f3bc87fc549b140558f9a7cff25a7a31d11e6fdf`. Anchors below refer to that revision; `COMMIT:body:N` = line N of `git show -s --format=%B COMMIT`. Read-only target; no builds, installs, commits, acceptance timing or browser mutations.

| id | asks (see .agent/review.md) | verdict |
|---|---|---|
| R3.1 | Proved vs tested boundary: kernel P-*/E-*/U-*, README + commit bodies | pass: kernel.md:3,136,139,153 explicitly excludes printers/IO/compiled wasm from the agreement proofs; README:238–239,260–272 names decoding + compiled-engine parity as tests and names the trusted base; all 31 bodies retain that boundary. |
| R3.2 | P-bound/P-memory/U-time evidence; loaded vs idle; routed acceptance met or stated open | finding: G1, G2. Internal status is honest: U9 remains open; loaded-host measurements are labelled. README expands the idle-performance claim and overstates byte-for-byte comparison. |
| R3.3 | Quantitative commit/ledger statements match logs: witnesses, comparisons, mutation/test/CI counts | finding: G3, G4, G5. Other matched counters agree; coverage limits below distinguish unavailable raw measurements from contradicted claims. |

## Findings

### G1 · minor · README's idle-performance claim reaches the new, unaccepted workload set

- Claim/anchor: `README.md:243`, exact bytes `a trace of 16 MiB takes seconds on an idle computer` (preceded by `On the generated traces that` / `` `tools/scale.sh` grades ``).
- Evidence: the statement's referent grew from the F5 four to seven graded shapes (`tools/scale.mjs:8–23`; `5dc7c4c`). The current phase's idle-host acceptance has not run: `.agent/spec.md:64` explicitly leaves U9 open. The available idle figures are v1/F5-only (`.scratch/refs/wasmtime.log`: native eval 6.03–9.31 s; `.scratch/refs/servetime.log`: 5.87–9.05 s). New-shape/cap figures in `4c5da70`, `96f80ba`, `7c536ee`, `28ed727` are explicitly loaded-host diagnostics, not an idle acceptance result. No false timing number found; the problem is the broader, present-tense claim without the corresponding measurement.
- Contract: P-bound/P-evidence + R3.2; evidence of four workloads cannot silently become evidence of seven after the graded set changes.
- Fix: scope the sentence to the measured F5 baseline, or describe the current target as a target until U9 supplies the host/binary/command/result. Keep the already-correct open U9 status.

### G2 · minor · README promises raw byte equality where the tool deliberately compares transformed JSON

- Claim/anchor: `README.md:296`, exact bytes `their output differs by one byte`.
- Evidence: `tools/compare.sh:69–92` deliberately normalizes v1→v2 through `jq -S`; line 82 = `jq -S "$v1_to_v2 | $creatorless"`. The transform drops/moves versioned members and normalizes qualifiers. Lines 36 + 78 remove usage-text tails even in otherwise byte-equal comparisons. `21148b8` correctly calls the v1→v2 comparison structural; `.scratch/refs/u5b-compare3.log:1` records 1198 runs with 0 differences despite the deliberate envelope-byte changes.
- Contract: V-cli/P-evidence: unchanged output forms byte-equal; changed forms compared after the specified transform, refusals' usage text checked separately. README promises a stronger detector than the established one.
- Fix: state both modes and the usage-text exclusion. No grading-check change needed.

### G3 · minor · U4 body overcounts browser tests

- Claim/anchor: `511281b:body:5`, exact bytes `Green: Playwright 34/34 (32 before + the 2 new)`; local anchor copy = `commit-511281b.txt:5` beside this report.
- Evidence: `.scratch/refs/u4-fastgate.log:141` = `33 passed (3.8m)`; its run enumerates `[1/33]`…`[33/33]`. Committed `511281b` has 33 `test(...)` declarations across `tests/e2e/*.spec.js`, with no generated test loop. The evidence-change test is new; the engine-off details assertion extends an existing test (`git show 511281b -- tests/e2e/gui.spec.js tests/e2e/export.spec.js`). `87a3640` adds the 34th test. This is a count error, not a missing test or a failed suite.
- Contract: R3.3 + evidence-reporting law: describe the checks actually run.
- Fix: record an explicit correction in the closing ledger/commit: U4 = 33/33, one added case + one strengthened existing case. Avoid rewriting landed history merely for this correction.

### G4 · minor · U7's purported red witness is a successful slow run

- Claim/anchor: `191121e:body:3`, exact bytes `Red witness: the new Tests/Scale.lean on 4f82d44`; local anchor copy = `commit-191121e.txt:3` beside this report.
- Evidence: `.scratch/u7/red-run.log:2–3` = `1321/1321 checks passed (slowest: eval-scale 337566 ms, replay 2762 ms, differential 1731 ms)` / `run rc=0`. The body accurately reports the duration and the passing count, but labels them a red witness. `Tests/Scale.lean:184–212` checks outcomes/prereqs values; this run neither failed an assertion nor timed out/trapped. A slow measurement proves slowness, not that the regression check rejected the unfixed revision.
- Contract: P-evidence (`kernel.md:145`) explicitly requires the v1 timeout/trap witness + revision/command; test-credit law requires an observed failing check. `.agent/spec.md:62` still leaves the v1 red rows open, so do not read this as a phase-completion claim.
- Fix: call this run a performance baseline; retain the open item until a recorded failing invocation on the unfixed revision supplies the required witness. The correction + actual witness can land in the closing evidence commit.

### G5 · minor · U1's serve RSS range uses the wrong conversion to MiB

- Claim/anchor: `01cf228:body:5`, exact bytes `peak 457–660 MiB`; local anchor copy = `commit-01cf228.txt:5` beside this report.
- Evidence: `.scratch/refs/servetime.log` records Linux VmHWM values in kB (= KiB): 585760, 581220, 659592, 457288. Correct range = 457288/1024 → 659592/1024 = 446.57–644.13 MiB, approximately 447–644 MiB. The quoted 457–660 divides by 1000 while retaining a binary-unit label. The request-time range matches; only the RSS conversion is wrong.
- Contract: R3.3 + P-memory/P-evidence: memory comparisons require consistent units. This concerns the historical baseline, not a claim that U9 passed.
- Fix: correct the range to 447–644 MiB in the closing evidence correction; retain raw KiB in any derived measurements.

## Evidence checked

- Read every body in `git log --format='%H%n%B' 01cf228^..f3bc87f` (31 commits), target README/contracts/spec/review M1–M4; fast/wasm/lean rules + the relevant comparison/scale/test definitions. Commit-body input copy = `commits.txt` beside this report.
- M1–M4 match `.scratch/refs/mutate-json.log`, `mutate-u3.log`, `mutate-u6.log`, `mutate-u6b.log`: Json 15 killed/1 survivor; Request 5/5; Evaluate 9/9; Cli 4 killed/3 survivors/4 incompetent; Snapshot 1/1; Server 4/4; Session 1 killed/1 survivor. Survivor rulings are outside R3; counts alone checked.
- All cited CI ids/durations match `.scratch/refs/ci-u{3,4,4b,5,5b,6,7walk,7speed}.log` + `.scratch/u8/ci-u8a.log`. These are local CI receipts, not a fresh GitHub query. No final-target full-gate claim inferred from earlier CI green.
- Compare logs match 798 (`refs/u2-compare.log`), 1198 (`refs/u5b-compare3.log`), 1240 (`u7/compare-{s1,s2,w1,w4,r1,v1}.log`) and 1238 (`u8/compare-speed2.log`), all 0 differences/0 timeouts. Positive control `u7/compare-pc.log` recomputed: 158 DIFF = 40 complete + 118 fact-details, other = 0.
- Differential counts recomputed from `tester-1/green.stdout.log`: 21 new families / 146 traces / 340 scenarios / 452384 comparisons; with the original corpus = 212 traces / 511 scenarios / 1001225 comparisons. `repeat.stdout.log` agrees. `red.stdout.log` gives 1515/8251; difference = 6736. `u7/tester1-merge-test.log` = 1519/1519, 29354 ms differential. Earlier walk count 489073 appears in `u7/fast4.log:33`.
- Saved test/probe summaries match the other cited totals: U2 927/19; U3 1312 and 927+604; U5 1315; U5b 1314 and 923+604; U6 1315→1317; U7 1317→1321→1519; U8 1523, 40 cases then 42, responsive 8; scale probes 5→8→13→14. `test-summaries.txt` contains the bounded extraction. U2 wasm stack error, U3 CLI refusals, U4 evidence/engine-off errors, U4b no-worker failure, U8 identity/coalescing/indicator failures and 35→1479 mounting witness matched their saved red logs; G4 is the exception.
- U1 F5 idle/native/serve times + 2000-card timings + 5000-card crash match `refs/wasmtime.log`, `servetime.log`, `check-*.txt`, `uitime2.log`, `uitime4.log` (2222 MiB heap); RSS unit correction = G5. U2 cap parity matches `refs/wasmtime2.log` (`equal true` on the four F5 shapes), explicitly not acceptance timing. U7 wide-cap diagnostic `u7/scale-wide-cap.log` prints binary SHA, host `t25-480`, load 15.58→15.83; no idle acceptance inferred.
- Instruction arithmetic rechecked from `u8/perf-{page,page-mi,page-a,skip,a-act}.txt`: net load 30.328→25.506→21.779 G instructions; action 24.729 G; reduction 28.19%. These agree with `7c536ee`'s rounded figures.
- Fresh target smoke: absolute target `fvtrace eval --project <target> --trace <target>/examples/fvtrace/trace.json`, cwd = target, `FVTRACE_HOME` + `TMPDIR` under this reviewer directory → rc=0, schema v2, counts can=7/open=2, draft, all 19 fact receipts current. Output = `self-eval.json`. `wc -c <target>/.lake/build/wasm/engine.b64` = 484764, matching `f3bc87f`.

## Register / coverage limits

- Idle-host acceptance remains open, as requested: no P-time/P-memory/U-time pass issued. Normative bounds in kernel/spec are requirements, not evidence of completion. M1/M2/M4 stay open; U7/U8/U9's outstanding work is not itself an R3 finding.
- Unconfirmed raw transient measurements: U7 step timings/RSS/instruction arrays beyond the saved receipts named above; U8 loaded GUI ranges + server before/after figures + allocator RSS/profile percentages. Searched top-level logs/text in `.scratch/refs`, `.scratch/u7`, `.scratch/u8`, their evidence indexes, and the named measurement scripts. The scripts + commit descriptions identify methods; matching raw numeric outputs were not found for those figures. No acceptance timing rerun on this loaded host. Treat these as recorded author measurements, not independently reproduced results.
- No full suite, browser suite, CI, mutation campaign or historical binary comparison rerun; review uses saved raw logs + committed-source cross-checks, with the target self-evaluation/size check as fresh spot-checks. No theorem-body adjudication (R2) or survivor-equivalence ruling (R4).

reviewer-3-DONE-1

## Re-review (c930c8c)

Check set = the five acceptance checks fixed in `.agent/review.md:50–55`; G2 = R2-F1, G4 = R4-F1. Target = `c930c8cca09798463db5263cf92fbdb62107df28`; G3/G5 corrections = MAIN's current ledger, not rewritten history. Original review above retained. Read-only; acceptance checks alone.

| id | acceptance | verdict | evidence |
|---|---|---|---|
| G1 | README scoped to measured evidence, or U9 measured | pass | `README.md:242–243` now says the tool `times it on generated traces` / `of up to 16 MiB against fixed limits`; no idle-result claim. `.agent/spec.md:64` still leaves U9 open. |
| G2 / R2-F1 | README names both comparison modes | pass | `README.md:295–299`: same-format byte equality; older evaluation format translated to the current format, then compared structurally. |
| G3 | U4 test-count correction recorded in ledger | pass | `.agent/review.md:52` explicitly corrects `511281b` to `33/33 (one new test, one strengthened)`; row present in both MAIN's ledger and committed `c930c8c`. |
| G4 / R4-F1 | Bounded outcomes/prereqs red witnesses; whatif row added; revision + command recorded | pass | `Tests/Scale.lean:139,143,220,237,248,251`: 20000 ms bounds + whatif scenario/action/byte checks. `red-4f82d44-run.log:1–5`: outcomes 414777 ms, prereqs 37646 ms → two FAIL, rc=1. `red-87a3640-run.log:1–6`: those time bounds fail + whatif 619771017 bytes > 8000000 → three FAIL, rc=1. Both builds rc=0; `c930c8c:body:7` records revisions, `lake build «fvtrace-tests» && .lake/build/bin/fvtrace-tests` with the new test file, and the matching figures. |
| G5 | U1 RSS unit correction recorded in ledger | pass | `.agent/review.md:54` explicitly corrects 457288–659592 kB to 447–644 MiB; row present in both MAIN's ledger and committed `c930c8c`. |

Re-review evidence root = `.scratch/u8/` for the four historical `red-{4f82d44,87a3640}-{build,run}.log` files. Fix-body input = `.scratch/reviewer-3/commit-c930c8c.txt`. All five acceptance checks adjudicated; no outstanding R3 finding at this target. Historical findings above retained as the original record, superseded by this table.

Verification = target README + ledger anchors, bounded `Tests/Scale.lean` diff, both run logs in full, both build-success tails, fix commit body. No historical/current full suite rerun, no build, no acceptance timing. G4's pass credits the observed failing checks, not an idle-host performance result; U9 remains open.

reviewer-3-DONE-2
