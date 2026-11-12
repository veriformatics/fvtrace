# reviewer-53 — closing diff `0ba494b..85f9870`

| row | lens × slice | files | verdict | finding ids |
|---|---|---|---|---|
| R1 | correctness: pageWith byte equality + callers | Fvtrace/Export.lean | pass | — |
| R2 | F82 performance claim + cost trap | Fvtrace/Export.lean, .claude/rules/fast.md | pass | — |
| R3 | scale run picking, failure precedence, caching, args + shell pitfalls | tools/scale.sh | finding | reviewer-53-F1 |
| R4 | probe firing + old-revision reds + oracle independence | tools/gate-probe.sh, tests/tools/scale-runs.sh | pass | — |
| R5 | docs ↔ behavior + ruling attribution | kernel.md, fast.md, spec.md, scale.sh | finding | reviewer-53-F1 |
| R6 | cleanup + altitude | every changed code file | pass | — |
| R7 | evidence + review/deferred records | commit bodies, review.md, deferred.md, spec.md | finding | reviewer-53-F2 |

## Findings

### reviewer-53-F1 — major — a run without a usable wall can grade green

- Target: `/home/eturkes/Projects/fvtrace/tools/scale.sh:189` (`session_row`) + `:299` (outer grading); bad-row origin `:79` (`fastest`). Lines = `85f9870`.
- Contract: R3 = no wall in any run fails its row; `scale.sh:70–73` explicitly classifies no wall as a failed run; `.claude/rules/fast.md` = graders fail closed, a failed run outranks faster runs. `tests/tools/scale-runs.sh` also calls an unfinished run a failure.
- Wrong behavior: `fastest` correctly selects `gui:served:select 0 - - 0 0 0.1` ahead of valid runs, but `session_row` retains rc 0 and outer grading recognizes only literal `timeout` or nonzero rc. AWK does not treat `-` as a time over 0.1. Green hides a missing measurement.
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-53/missing-wall-red.sh` (actual binary, shape wide n=3, 3 runs; stand-in GUI driver supplies no usable selection wall only on run 2).
- Output (target grader rc 0; witness rc 1):
  ```text
  wide                3      1240 gui:served:select           0         -         -        0           0 0.010,-,0.010
  scale: every graded run within its bounds
  grader rc=0; expected nonzero + FAIL for unusable run-2 wall (fail-closed / fastest comment)
  FAIL: an unfinished measured run was accepted
  ```
- Artifacts: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-53/missing-wall{.mjs,-red.sh,-output.log,-control.log}`. Positive control = same driver with all 3 numeric walls, grader rc 0; only run-2 selection wall differs in the red. Printed spread proves all 3 driver runs occurred.
- Fix direction: normalize every unusable measurement to a failed rc/timeout before grading; keep malformed + missing walls ahead of faster numeric runs; pin the end-to-end red above.

### reviewer-53-F2 — minor — the F82 evidence overstates the affected shapes

- Target: `/home/eturkes/Projects/fvtrace/.agent/review.md:309` (F82); parallel summary `/home/eturkes/Projects/fvtrace/.agent/spec.md:55`; e438659 body carries the same universal 9.3–10.3 s summary.
- Contract: R7 = numerical claims supported by cited logs; `CLAUDE.md` Evidence + Adversarial review = sufficient evidence, claim soundness, honesty over overreach.
- Exact text anchor: `every graded shape's export at the cap sits at the bound with no margin`.
- Match command: `rg -Fn "every graded shape's export at the cap sits at the bound with no margin" /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-53/tree/.agent/review.md` → line 309. The saved target copy is byte-equal to `git show 85f9870:.agent/review.md`.
- Independent source: `/home/eturkes/Projects/fvtrace/.scratch/bench/b8f1.log`; `awk '$5=="export" {print $2,$3,$7}' <log>` yields cap values wide 9.43, deep 8.98, experiments 9.96, exclusions 7.83, outcomes 10.30, prereqs 9.34, whatif 1.07 s. Whatif's cap is command-line-limited, as P-bound states. Thus neither the universal near-bound claim nor the unqualified 9.3–10.3 s range holds. The main outcomes red and the optimization remain valid.
- Fix direction: qualify the near-bound range to the cases it describes; retain the actual per-shape values and the outcomes failure instead of a universal statement.

## Register

- security → MAIN
- `/home/eturkes/Projects/fvtrace/.agent/review.md:310`: the F83 A/B's equal four-sample medians support the observed comparison, not a general no-regression guarantee. No additional finding: user selected the timing statistic; this review does not re-adjudicate it.

## Row evidence

- R1: read the complete Export module + both page callers (`Cli.exportCmd`, export tests). The only literal `</footer>` in embedded web assets is the template's at `web/index.html:145`; JSON's `<` is escaped, engine = base64, license texts escape `<` and cannot create `linked`. Both original guards remain before either replace. `export-diff.sh` → 40 cases: 37 pages byte-equal (both examples; every registered shape at 3,40,150; outcomes at cap; marker-collision summary), 3 equal refusals, 0 differences; planted extra byte → cmp rc 1. Native Export areas → 53/53 checks.
- R2: traced `pageWith` → `page` → `Cli.exportCmd` → `replaceFile` → putStr/flush/rename. No replace/splitOn/content transform after filling the template; the final replace scans template+escaped licenses, not its head argument. fast.md's cost-trap sentence describes that ordering. Saved pre-fix perf children = 52.11% replace; new profile canonical JSON 23.25%, htmlSafe 10.13%, consistent with removal of the large replace.
- R3: complete scale.sh + helper/session callers read. Focused run-picker suite rc 0; independent Python oracle seed 53083 → 200/200 generated cases agree for whole-row selection, first failure, missing steps. Own old/new replays confirm CLI run-2 failure wins, a session's run-2 exit fails every step, fastest pick + --runs 1 control; rows cached per (shape,n,kind). PIPESTATUS captured immediately; CLI whole row feeds ratios + last_rss/P-memory; session file argument order is numeric run order. Invalid --runs values 0,-1,1.5,01,xyz,empty → rc 2; missing value → unbound-variable rc 1 (no passing grade). The no-wall end-to-end case is reviewer-53-F1.
- R4: new test expectations = earliest failed/unfinished row or minimum wall with its complete metadata, missing-step failure; each follows the ruling + fail-closed law. Own commands against 70ab006 reproduce all five red witnesses; target reproduces their greens. scale-runs-fastest requires a positive check row and the absence of its exact wall-failure line, so empty output cannot pass. Own complete `bash tools/gate-probe.sh scale` → 27 passed, 0 failed, rc 0 (all five new + all 22 old controls); every expected failure matched its named cause.
- R5: diff-read P-evidence, fast.md, spec Decisions + Tasks, scale header. Default 3 + per-row minimum match the conveyed user ruling; commit 3274786 explicitly labels RSS/bytes from the same graded run as MAIN's ruling. Changed baseline comparison is explicitly labelled not like-for-like in F81/F82 + Tasks. Fail-closed wording remains overstated for a malformed wall: reviewer-53-F1.
- R6: every changed code hunk with enclosing definition + callers read. One shared picker for CLI + sessions, one shared session runner, existing session_row preserved, failure-first core reused. No behavior-blocking cleanup/altitude defect found. Changed shell files: shellcheck -x rc 0.
- R7: inspected bodies e438659,3274786,70ab006 + F81–F83/B8 rows; compared saved b8f1/b8f2 logs (same binary SHA, 6 vs 3 total failures; 5 vs 1 ratio failures; exports 10.30 then 10.24/10.11 s) and F83 raw gui.rows (4 interleaved samples each; old/new median 0.372; old spread ×1.322). F82 saved profiles + trust 12/12 + fast-gate 134.1 s; F83 saved fast gate 41.9 s + probes 27/27; byte equality independently reproduced. Receipts deferred acceptance exercised with exact command at n40/80: 6 nonzero action rows (CLI 2, serve 400, page 1), predicate rc 1; planted 6 zero-rc controls → predicate rc 0. Final B8 acceptance remains explicitly pending in target records. The universal near-bound export claim is contradicted by those same logs: reviewer-53-F2.

## Checks + limits

- Target = `85f9870`; every target/source edit forbidden. Scratch = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-53/`; report = validator input. Copy identities checked with `cmp` against git show (all four code files + the ledger = rc 0).
- Own checks: 40-case export differential (37 pages + 3 refusals), 1-byte comparator positive control, 53/53 Export tests, 200/200 generated picker oracle cases (seed 53083), run-picker focused suite, five probes' commands replayed against 70ab006 + 85f9870, actual no-wall red + numeric-wall green control, shellcheck -x, receipts acceptance at n40/80 + six zero-rc positive controls. Complete scale probes: 27/27, rc 0; log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-53/probes.log`.
- Historical evidence: saved profile data, raw timing logs, A/B rows, fast gates + trust logs read. Unconfirmed exact historical desktop timing ranges 14.2–14.5 → 8.4–9.3 s and six planted-byte comparator results: no persisted stdout for those runs found in `.scratch/f82/`; own parity + positive control independently pass. Profiles support the stated hotspot and its removal, not a reconstruction of those exact wall times. Original host exclusivity is recorded by MAIN; the timing log itself proves slot 2/2, not the other slot's ownership. Same-tree b8f1/b8f2 binary SHAs match.
- Coverage = fixed seven-row set. Native/WebAssembly engine semantics unchanged by the diff; the full engine differential, full gate, reference-host timing acceptance, and security lens not rerun here. MAIN owns them. No nested subagents or offload used.
- LSP probe on actual Export.lean → no .lean server available; source/callers inspected directly. No tracked source, proof, config, rule or Intent edit by this reviewer; only report + allowed scratch written. Background work complete; reviewer-path server search rc 1 (none). Old-revision replay copy removed; its script regenerates it.

reviewer-53-DONE-1
