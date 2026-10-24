# reviewer-22 — verification integrity

Target = `af5a2f1..fa7f307`; read state = `4e8eefa` (review ledger only beyond target; tested sources unchanged). Fixed rows read before target. Write scope = `.scratch/reviewer-22/` alone.

| id | asks | verdict | findings |
|---|---|---|---|
| R4.1 | Tests/Scale + Tests/Differential assert contract-derived values; same-test red witness, revision + command + output recorded | pass | - |
| R4.2 | No test, gate stage, probe or threshold weakened/skipped/removed; changed tests adapt API (+ C9) | pass | - |
| R4.3 | scale + compare fire on planted inputs; grade ratio, timeout, rc, stdout/stderr/rc, fresh data folder | finding | VI-1, VI-2 |
| R4.4 | Tested P-shell mutation credit: scope + command + every survivor ruled | finding | VI-3 |

## VI-1 — equal timeouts certify incomplete parity

Severity = major. Anchor = `/home/eturkes/Projects/fvtrace/tools/compare.sh:22-27`.

Exact bytes (`rg -Fn`):
- `FVTRACE_HOME="$work/home" timeout 600 "$bin" "$@" --trace "$trace"`
- `for out in out err rc; do`
- `if ! cmp -s "$work/old.$out" "$work/new.$out"; then`

P-evidence requires completed old/new output equality. `cmp_run` compares timeout exit codes as ordinary program results: two processes killed at the limit with the same partial output produce `diffs=0`; final `[[ $diffs -eq 0 ]]` accepts. Identical unfinished prefixes ≠ identical eventual results. Keep legitimate equal application errors (invalid inputs/refusals), but make any timeout an inconclusive/failed comparison.

Red test = `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/compare-timeout.sh`.
Command: `bash /home/eturkes/Projects/fvtrace/.scratch/reviewer-22/compare-timeout.sh` → rc 1.
Target's verbatim `cmp_run` sourced directly; timeout wrapper shortens 600 s → 0.5 s. Control `/usr/bin/true` vs `/usr/bin/false` detected; two scripts sleep 2 s before different outputs, both time out:

```text
control: runs=1 diffs=1 old=rc=0 new=rc=1
timeout: runs=1 diffs=0 old=rc=124 new=rc=124
FAIL P-evidence: both binaries timed out; compare.sh reports no difference
```

Evidence = `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/compare-timeout.log`. Coverage: exact comparison function + final acceptance condition, not the 798-case outer loop. No target edits.

## VI-2 — display rounding weakens the ratio bound

Severity = minor. Anchor = `/home/eturkes/Projects/fvtrace/tools/scale.sh:77,88`.

Exact bytes (`rg -Fn`):
- `'BEGIN { if (a > 0 && nb > na) printf "%.2f", exp(log(b / a) * log(2) / log(nb / na)) }')"`
- `if [[ -n "$ratio" ]] && awk -v r="$ratio" -v m="$max_ratio" 'BEGIN { exit !(r > m) }'; then`

P-bound/P-evidence require failure above 2.5×. The checker rounds to two decimals before comparison; measured 5.00 → 12.52 s at n=2 → 4 = 2.504× becomes `2.50`, accepted. Compare the unrounded ratio; round only its display. This is a narrow numerical boundary defect, not evidence that the recorded ~2.1× measurements violate the bound.

Red test = `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/ratio-threshold.sh`.
Command: `bash /home/eturkes/Projects/fvtrace/.scratch/reviewer-22/ratio-threshold.sh` → rc 1.
Measurement shim supplies valid GNU-time-format rows to the unchanged complete target script (not actual sleeps). Controls = equality passes, clear breach fails:

```text
wall 5.00 -> 12.50, raw ratio=2.5000: scale rc=0
wall 5.00 -> 12.60, raw ratio=2.5200: scale rc=1
wall 5.00 -> 12.52, raw ratio=2.5040: scale rc=0
             ratio 2.50 per doubling
             ratio 2.50 per doubling
scale: every graded run within its bounds
FAIL P-evidence: ratio 2.504 > 2.5 accepted after display rounding
```

Evidence = `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/ratio-threshold.log`; per-case target output = `ratio-12.50.log`, `ratio-12.60.log`, `ratio-12.52.log` in that folder.

## VI-3 — specified CLI grouping mutants survive

Severity = major (verification gap; target helper correct on the witness). Anchors = `/home/eturkes/Projects/fvtrace/Fvtrace/Cli.lean:452,455`.

Exact bytes (`rg -Fn`):
- `let sorted := pairs.mergeSort fun a b => a.1 ≤ b.1`
- `| some (q, cs) => if q == p then acc.pop.push (q, cs.push c) else acc.push (p, #[c])`

Allowed campaign log `/home/eturkes/Projects/fvtrace/.scratch/mut-f5.log` reports survivors `Cli.lean:452 ≤ → <` + `Cli.lean:455 == → !=`. P-shell preserves CLI question/subject grouping + trace claim order; neither mutant is equivalent or unspecified. Add a regression with ≥2 prospective subjects and ≥2 claims per subject on one question, interleaved in the trace; kill both through observable grouping/CLI output.

Independent witness = `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/GroupSurvivors.lean`; fixture passes `Check.violations = []`. Calls target helper + exact one-operator copies (target read-only).
Commands, from `/home/eturkes/Projects/fvtrace`:
- `lake env lean --run .scratch/reviewer-22/GroupSurvivors.lean target` → 2/2 pass, rc 0.
- `lake env lean --run .scratch/reviewer-22/GroupSurvivors.lean 452` → 1/2 pass, rc 1.
- `lake env lean --run .scratch/reviewer-22/GroupSurvivors.lean 455` → 1/2 pass, rc 1.

```text
452: got [("P", ["P2", "P1"]), ("T", ["T2", "T1"])], want [("P", ["P1", "P2"]), ("T", ["T1", "T2"])]
455: got [("P", ["P1"]), ("P", ["P2", "T1", "T2"])], want [("P", ["P1", "P2"]), ("T", ["T1", "T2"])]
```

Evidence = `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/group-survivors.log`. These are red *mutant* witnesses, not a claimed functional failure of the target implementation. Missing kills = the finding.

## Pass evidence + limits

- R4.1: Scale's verdict/count/plan expectations follow each generated shape + kernel rules; no observed implementation-output table. Differential's `want` = `Lookups.reference`/`Answers.reference`, with direct reference engine calls; generated matrix checks its own allowed-kind/route/status coverage. `same` compares and records failures; positive comparison counter prevents an empty comparison pass. `fa7f307` body records old `af5a2f1` + Scale (receipt API adapted), both areas under `timeout 900 .lake/build/bin/red-scale`; authorized red log records old SHA, real 15m0.006s + rc 124. Authorized green log = 1128/1128; seed 19798168526996293; 66 traces, 140 scenarios, 479429 comparisons. Historical red invocation not re-run; adapted historical source not independently byte-compared (only commit + permitted red log available). No contrary evidence.
- R4.2: all changed test hunks read; `Tests/Engine.lean` = new `Answers.fast`/receipt callback arguments + added C9 expectation; `Tests/Fields.lean` = `Lookups.fast` adapter. `Tests.lean` adds three native areas; removes none. `gate-probe.sh` adds scale/compare; removes no existing probe. `mutate.mjs` adds comma-separated line ranges without changing operators. Gate, fast gate, CI workflow identical git blobs at base/target: `acfca4f…`, `6123482…`, `5ee0b2a…` respectively. Acceptance limits remain 60 s / 2.5×; new timing/parity tools explicitly outside routine gate because they need an idle host / prior binary.
- R4.3 static pass parts: scale captures binary pipeline rc, times out, checks wall, normalizes ratios for non-exact doubling, and prints binary/host/load/bytes. compare removes its home before *each* old/new invocation, compares full stdout/stderr/rc files (display truncation affects diagnostics only), traverses both examples + two fixtures + 12×3 generated traces. Committed scale controls plant rc/ratio/wall/timeout; compare control plants exit mismatch. Rerun with `TMPDIR=/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/tmp bash tools/gate-probe.sh scale compare`: 7/7 controls pass, rc 0 (`probes.log`); target git status remains clean. These controls omit the two identified boundaries.
- R4.4 scope + command confirmed by read-only `.scratch/mut-run.sh` + `.scratch/ranges.sh`: Engine, Lint, Evaluate, Receipt, Export, Cli; ranges = added/changed lines since af5a2f1 (`git diff -U0` → A-B,C-D); in the fa7f307 scratch copy: `node "$copy/tools/mutate.mjs" "$copy/$f" --lines "$r" --test "lake test" --timeout 900`. Observed headers independently match fixed `af5a2f1..fa7f307` hunks. Exclusions: Check proved; Present moved unchanged; Replay/Session/Snapshot's changed lines have **0 default mutation sites each**, independently confirmed by `--list` on copies of their fa7f307 contents under this review folder (`omitted-scopes.log`, each rc 0). BindingIndex is within LookupsAgree. Logged complete batches = Engine 1 killed; Lint 3 killed; Evaluate 4 killed; Receipt 2 killed + 1 incompetent; Export 1 incompetent. Cli = 11/15 sites reported, 9 killed + the 2 survivors ruled VI-3; its last 4 sites remain **unconfirmed** until `campaign done`. This is not a complete mutation-credit sign-off. Receipt:40 `> → >=` hits pipeline `|>`; Export:184 `< → <=` hits application `<|`; reported incompetent outcomes fit non-operator syntax sites, not evidence of missed behavior.
- LSP: `.lean` server unavailable; source/diff/manual tracing used. Full gate, historical old binary, idle-host caps and native mutation campaign not rerun by reviewer (read-only/shared-build constraints). No target writes.

## Register (outside fixed rows)

- Differential coverage bound: malformed traces in `Tests/Differential.lean` run `compareLookups` only; `compareAnswers` runs on the 35 WF candidates (arbitrary overrides + external records included). Thus the logged 31 malformed traces do not establish compiled `Answers.fast` parity on malformed *trace collections*. Universal `AnswersAgree` proof still covers that mathematical domain. Report this scope exactly; a future runtime extension can include malformed Answers cases if bounded plan/closure runtime permits. No finding under R4.1's oracle/value-source check.

reviewer-22-DONE-1

## Re-review (84da642)

Scope fixed = VI-1/VI-2/VI-3 acceptance alone; no new rows. Target = `84da6426bdb9d6947357d727133f12872e70ca64`.

| finding | verdict | evidence |
|---|---|---|
| VI-1 | fixed | `bash .scratch/reviewer-22/compare-timeout.sh` → rc 0: completed equality passes; exit mismatch + old/new/both timeout fail. `TMPDIR=.scratch/reviewer-22/tmp bash tools/gate-probe.sh compare` (absolute TMPDIR in actual run) → 3/3 controls pass, rc 0. |
| VI-2 | not fixed | `bash .scratch/reviewer-22/ratio-recheck.sh` → rc 1. Original 2.504× witness rejected; a valid two-decimal timing pair at n=2→3 gives 2.500000129874673×, becomes 2.500000, still accepted. Same premature-rounding defect; six decimals merely narrows it. |
| VI-3 | fixed | `lake env lean --run .scratch/reviewer-22/RunGroupTests.lean` → `3/3 checks passed`, rc 0. Complete F5 campaign + follow-up log read: the two specified survivors are both killed by `--lines 452-452,455-455 --test "lake test" --timeout 900`. |

### VI-1 acceptance evidence

Harness updated only for `cmp_run`'s `limit`/`timeouts` variables and to execute the target's final predicate verbatim. Log = `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/compare-timeout-84da642.log`:

```text
differ: runs=1 diffs=1 timeouts=0 old=rc=0 new=rc=1 grade_rc=1 expected=1
same: runs=1 diffs=0 timeouts=0 old=rc=0 new=rc=0 grade_rc=0 expected=0
both-timeout: runs=1 diffs=0 timeouts=2 old=rc=124 new=rc=124 grade_rc=1 expected=1
old-timeout: runs=1 diffs=1 timeouts=1 old=rc=124 new=rc=0 grade_rc=1 expected=1
new-timeout: runs=1 diffs=1 timeouts=1 old=rc=0 new=rc=124 grade_rc=1 expected=1
```

Full committed compare probes rerun; `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/compare-probes-84da642.log`:

```text
probe compare-differ: fired (rc=1)
probe compare-same: passed as expected
probe compare-timeout: fired (rc=1)
probes: 3 passed, 0 failed
```

### VI-2 acceptance still fails at 84da642

Anchor = `/home/eturkes/Projects/fvtrace/tools/scale.sh:78` **at 84da642**; exact bytes matched before the subsequent correction:
`printf "%.6f", exp(log(b / a) * log(2) / log(nb / na))`.

The saved `ratio` remains formatted before the comparison. All fixture wall values below are ≤60 s and have GNU time `%e`'s two-decimal precision; `--n "2 3"` is a supported non-exact doubling, normalized by the target's own formula. This is VI-2's original acceptance (grade before formatting), not a new row or a different check.

Command: `bash /home/eturkes/Projects/fvtrace/.scratch/reviewer-22/ratio-recheck.sh` → rc 1.
Log = `/home/eturkes/Projects/fvtrace/.scratch/reviewer-22/ratio-recheck-84da642.log`:

```text
equal: n=2->4 wall=5.00->12.50 raw_ratio=2.500000000000000 grade_rc=0 expected=0
clear-breach: n=2->4 wall=5.00->12.60 raw_ratio=2.520000000000000 grade_rc=1 expected=1
original-witness: n=2->4 wall=5.00->12.52 raw_ratio=2.504000000000000 grade_rc=1 expected=1
six-decimal-boundary: n=2->3 wall=31.15->53.24 raw_ratio=2.500000129874673 grade_rc=0 expected=1
             ratio 2.50 per doubling
             ratio 2.50 per doubling
scale: every graded run within its bounds
FAIL VI-2: a ratio above 2.5 was rounded before grading
```

Acceptance unchanged: compare within the numerical calculation before display formatting (or carry full floating-point precision). Residual error is narrow (<0.5×10⁻⁶); no claim that the recorded F5 ~2.1× measurements fail.

### VI-3 acceptance evidence + complete campaign

`/home/eturkes/Projects/fvtrace/Tests/Cli.lean:193-212` = committed `groupTests`; well-formed fixture; original `subjects.filter prospective` × `claims.filter subject` oracle; explicit expected subject/claim order. `Tests.lean` wires it into the pure CLI area. Import-and-call on the built module:

```text
(cd /home/eturkes/Projects/fvtrace && lake env lean --run .scratch/reviewer-22/RunGroupTests.lean)
3/3 checks passed (slowest: )
rc=0
```

Original `/home/eturkes/Projects/fvtrace/.scratch/mut-f5.log` ends `campaign done`: 27 reported sites = 23 killed + 2 specified survivors + 2 incompetent pipe-syntax sites. No further survivors. `/home/eturkes/Projects/fvtrace/.scratch/mut-vi3.log` + commit command close both specified survivors:

```text
node tools/mutate.mjs Fvtrace/Cli.lean --lines 452-452,455-455 --test "lake test" --timeout 900
[1/2] killed …/Fvtrace/Cli.lean:452 ≤ → <
[2/2] killed …/Fvtrace/Cli.lean:455 == → !=
mutants: 2 · killed 2 · survived 0 · incompetent 0
rc=0
```

Native mutation rerun evidence read, not independently repeated (shared-build/read-only posture); the committed regression itself independently executed. Earlier campaign-scope/command uncertainty is resolved.

Re-review limits: no full gate or original native mutation campaign rerun; checks above only. Target writes = none. During the final source check HEAD advanced to `2835138`, with a further `tools/scale.sh` correction; that correction is **outside this requested 84da642 re-review**. The VI-2 verdict names 84da642, not the newer code. Compare/probe/group-test sources remained unchanged from 84da642.

reviewer-22-DONE-2
