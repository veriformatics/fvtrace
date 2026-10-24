# reviewer-21 verdicts: guarantee vs claim lens (closing review, IMPLEMENT — engine speed-up)

| id | asks | verdict | findings |
|---|---|---|---|
| R3.1 | proved vs tested boundary stated right in `kernel.md` (P-shell, Printers + IO), README, commit bodies; nothing tested is presented as proved | pass | - |
| R3.2 | P-bound evidence: graded rows at cap/2 → cap on an idle host, hub statement, supplemental shapes' "time follows output" reading, plan limit kept | finding | R3-F1, R3-F2 |
| R3.3 | quantitative statements in commit bodies + ledger match their logs (red witness, compare runs, trust, test counts, baselines) | pass | - |

## Review state

- Fixed set = R3.1–R3.3, before target read; target `af5a2f1..fa7f307`; HEAD `4e8eefa` adds only the fixed review ledger.
- Read: kernel Performance + its surrounding guarantee boundaries; README self-verification + Development; target commit bodies; F5 ledger; all eight allowed logs.
- Seed validator: expected 3 unresolved rows → unresolved-row grep = 3, rc 0.
- R3.1: proof statements quantify over all traces/scenarios/bindings; no WF precondition. P-shell + P-claims explicitly leave IO/printers tested; README distinguishes JSON decoding + wasm adapter tests. `boundaries.lean` typechecks envelope congruence, checker congruence + unchanged `maxRelevant = 20`; all three agreement theorems report only `propext`, `Classical.choice`, `Quot.sound`. Command: `(cd /home/eturkes/Projects/fvtrace && lake env lean --run /home/eturkes/Projects/fvtrace/.scratch/reviewer-21/boundaries.lean)` → rc 0; evidence `boundaries.log`. No independent-kernel replay rerun.
- Binary sha256 = `90c61be06dc083115777fc909f4d08d6e6b17d8ab31cda65c634a070624a5fa7`, identical to both scale logs.
- Validator negative control: known complete row in `validator-control.txt` → expected count 0, rc 1, observed 0/1. Lean LSP unavailable; source inspection + Lean typechecker used.
- R3.2 non-findings: all 16 graded rows + 4 hub rows match the stated cap/2 → cap counts, walls + ratios; graded max eval 8.87 s, max ratio 2.23; hub cap eval 5.93 s, ratio 2.10. Host log = 8 CPUs, load 2.96 → 2.48; wall ≈ user supports low contention, not an independent CPU-idle audit. `maxRelevant = 20` unchanged by the diff and typechecked. Supplemental time ratios 2.03–2.21 match the five named shapes; outcomes wall/output ratios 4.3835/3.9597, prereqs 4.2412/3.7533. Similar observed growth is supported; attribution limited by R3-F2. Native timing only; no wasm-speed claim accepted.
- R3.3: `/home/eturkes/Projects/fvtrace/.scratch/reviewer-21/check-evidence.py` → rc 0 (`check-evidence.log`): 30 af5a2f1 baseline rows agree with commit rounding; combined red timeout 900.006 s / user 601.603 s / rc 124; compare 798 runs, 0 differences; suite 1128/1128; seed + 66 traces (35 kept/31 malformed), 140 scenarios, 479429 comparisons all match. Current self-trace `claims --json` → 7 can, 2 open (`self-counts.json`, rc 0), matching README.
- Trust qualification: supplied `trustsh-u4.log` proves the stated 26-claim/0-finding audit + 26 independent proof replays; the overall command FAILED rc 1 because old P1/P2 fingerprints changed. The commit claims the successful proof phase, not a full green trust stage. Read-only smoke now: built `fvtrace-trust --statement` for P1, P2, P10–P12 gives rc 0 + exact pinned hashes (`pins-current.log`); built `fvtrace check --strict` on self-trace gives rc 0, every receipt current (`self-check.log`). This confirms re-pinning without running verifier scripts/builds.
- Unconfirmed (bounded evidence, not contradictory evidence): historical F5 ledger timings at 53bcecc + its inline-ensure 19.0 → 11.6 s (only af5a2f1 baseline supplied); closure-before 304 s (`prereqs-bfs.log` confirms after 9.32 s only); check-scale upper 3.6 s + eval-scale ≈ 2–3 s (only `test-u4m.log` supplied: check-scale 852 ms; eval-scale absent from its slowest-three summary); target-body n=57 generator `cmp` + planted probe runs/red checkpoint 80f0f62 (no corresponding allowed log). Full post-repin `tools/trust.sh` pass not confirmed; that supplied log ends rc 1. These limits qualify R3.3's pass: no observed quantitative mismatch, not independent recreation of each historical run.
- Checks run: boundary typecheck; log arithmetic/counter reconciliation; target-revision text rematches; current fingerprint comparison (5 facts); current self-trace strict check + verdict count. Not run: full gate, full suite, scale timing rerun, old/new comparison rerun, independent-kernel replay, mutation campaigns, probes. Eight allowed logs read completely; source audit targeted to this fixed lens, not every implementation hunk. No target edits by reviewer-21.
- Concurrent working-tree changes appeared at close in `tools/compare.sh` + `tools/scale.sh`; no adjudication of those new patches. Verdicts + anchored findings remain against immutable `fa7f307`. Final unresolved-row validator = 0, rc 1 (expected grep behavior for zero matches).

## Findings (one section per finding id: `file:line`, why it is wrong, proof — a red test (file under this folder + exact command + its failing output) for behavior, the exact bytes `rg -Fn` matches for text; severity blocker | major | minor)

### R3-F1 — performance wording drops the workload boundary

Severity: minor. Row: R3.2.

- `/home/eturkes/Projects/fvtrace/README.md:223`: `so a trace of 16 MiB takes seconds.`
- `/home/eturkes/Projects/fvtrace/Fvtrace/Spec/Fast.lean:9`: `so a 16 MiB trace takes seconds.`
- `/home/eturkes/Projects/fvtrace/README.md:271`: `of up to 16 MiB and fails when a run takes more than 60 seconds`

Why wrong: P-bound grades only `wide`, `deep`, `experiments`, `exclusions`; it explicitly says the limits do not cover every trace. The first two sentences generalize those measurements to the input-size cap. The Development sentence also describes a failure for every generated run, whereas `/home/eturkes/Projects/fvtrace/tools/scale.sh:33,54,81` intentionally grades only the four shapes. Supplemental runs may exceed 60 s without failing `--assert`.

Proof: `/home/eturkes/Projects/fvtrace/.scratch/scale-supp-1.log:26` records `outcomes 2000 740428 eval 0 141.98 141.15 1854 311235137` (whitespace normalized here): under 1 MiB input, over two minutes, same binary hash as the graded acceptance. Graded acceptance `/home/eturkes/Projects/fvtrace/.scratch/scale-assert-1.log` covers four workloads only; this is a wording defect, not a request to grade the supplemental workloads or change thresholds.

Text witness (matched in the read files; rc 0):

```sh
rg -Fn -e 'so a trace of 16 MiB takes seconds.' -e 'of up to 16 MiB and fails when a run takes more than 60 seconds' /home/eturkes/Projects/fvtrace/README.md
rg -Fn 'so a 16 MiB trace takes seconds.' /home/eturkes/Projects/fvtrace/Fvtrace/Spec/Fast.lean
```

Acceptance: name the measured workloads + native/idle-host scope, or remove the broad timing sentence; Development names the four graded shapes and says supplemental shapes are reported only. Keep the existing P-bound limits.

### R3-F2 — promised artifact/node accounting is absent

Severity: minor. Row: R3.2. `/home/eturkes/Projects/fvtrace/.agent/contracts/kernel.md:122`.

Exact bytes:

- `worst case 2^|R| leaves; nodes reported`
- `elsewhere cost is reported against input bytes, emitted bytes, artifact bytes read + plan nodes explored.`

Why wrong: the contract promises attribution beyond input/output size for workloads outside the four graded shapes. The committed measurement path and supplied supplemental logs report neither artifact bytes actually read nor plan nodes explored. Consequently the evidence does not fulfill the promised accounting; “time follows” the output describes the two measured growth factors, not a demonstration that only emission accounts for the extra work.

Proof:

- `/home/eturkes/Projects/fvtrace/tools/scale.sh:43` emits the complete header: `shape n bytes cmd rc wall user rss_mib out_bytes`. Its invocation at :64–65 collects elapsed/user/RSS + stdout bytes only. Full driver read: no other metric output.
- `/home/eturkes/Projects/fvtrace/.scratch/scale-supp-1.log:3` has the same columns; all 28 supplemental rows lack the promised counters. Graded + prerequisite logs also have no counters.
- `/home/eturkes/Projects/fvtrace/Fvtrace/Answers/Fast.lean:502–519` (`searchWith`) returns the chosen id list, without a visit counter. Searches of `Fvtrace/`, `Tests/`, `tools/` for `nodeCount|node_count|searchNodes|search_nodes|nodesExplored|nodes_explored|artifactBytes|artifact_bytes|bytesRead|bytes_read|plan_nodes` returned rc 1; positive control for the existing driver header returned expected count 1, rc 0. This bounded name search supplements, rather than replaces, the full driver + search implementation read.

Text witness (rc 0):

```sh
rg -o -Fn -e 'worst case 2^|R| leaves; nodes reported' -e 'elsewhere cost is reported against input bytes, emitted bytes, artifact bytes read + plan nodes explored.' /home/eturkes/Projects/fvtrace/.agent/contracts/kernel.md
rg -Fn 'shape n bytes cmd rc wall user rss_mib out_bytes' /home/eturkes/Projects/fvtrace/tools/scale.sh
```

Acceptance: a committed, rerunnable measurement path reports actual artifact bytes read + plan-node visits for the supplemental runs, beside the existing input/output bytes and times; classify non-emission work explicitly. The four graded limits remain unchanged. No separate accounting artifact was available in the brief's permitted evidence.

## Register (defects outside the check set)

- REG-R3-1: `/home/eturkes/Projects/fvtrace/Fvtrace/Index.lean:4`, `/home/eturkes/Projects/fvtrace/Fvtrace/Lookups.lean:10,102` say `O(log n) each` without distinguishing scalar queries from whole-list results. `Index.group` (:77–78) scans/emits k matches → O(log n + k); `Lookups.fast.idsNodup` (:138) sorts the input → O(n log n). These code-comment cost claims sit outside R3.1–R3.3's specified prose/measurement targets; record for the owner, not a merge-blocking finding here. `rg -Fn 'O(log n) each'` on those two files matches all three anchors.

reviewer-21-DONE-1

## Re-review (84da642)

Scope = R3-F1 + R3-F2 acceptance checks alone; one round; no new rows. Target `84da6426bdb9d6947357d727133f12872e70ca64`; read-only. Every deciding anchor matched both the file read and `git show 84da642:<path>` (rc 0).

| finding id | verdict | bytes that decide it |
|---|---|---|
| R3-F1 | fixed | `/home/eturkes/Projects/fvtrace/README.md:224`: `` `tools/scale.sh` grades, a trace of 16 MiB takes seconds on an idle computer. ``; :271 `It grades four trace shapes:`; :273 `shapes without a limit. Run it on an idle computer.`; `/home/eturkes/Projects/fvtrace/Fvtrace/Spec/Fast.lean:10`: `workloads alone).` |
| R3-F2 | not fixed | `/home/eturkes/Projects/fvtrace/.agent/contracts/kernel.md:122`: `artifact bytes read + plan nodes explored stay unmeasured` |

### R3-F1 ruling

The README now limits timing to the generated workloads the native program's scale driver grades, on an idle computer. Development distinguishes the four graded shapes from supplemental reporting. Spec removes the universal size-to-time claim. Identifying the graded set through its driver is sufficient; the acceptance does not require duplicating the four shape names in prose. The existing numerical limits remain unchanged. Text check only; no timing rerun needed for this wording fix.

### R3-F2 ruling

The replacement is candid about the evidence limit, but it does **not** meet the fixed acceptance: “a committed, rerunnable measurement path reports actual artifact bytes read + plan-node visits for the supplemental runs.” It removes that promise instead of providing the measurements. The fix commit body explicitly describes this choice; the deciding new bytes say the counters remain unmeasured. The narrower prose repairs the overstatement, not the unmet evidence requirement.

Keep R3-F2 open against its stated acceptance. Closing it without counters requires a separate contract/evidence-scope disposition (for example, an explicitly accepted deferral), rather than recording this acceptance as satisfied. This ruling introduces no new implementation requirement beyond the original finding.

### Completed-log addendum

- `/home/eturkes/Projects/fvtrace/.scratch/trustsh-fa7f307.log:27,34,59–60` + `/home/eturkes/Projects/fvtrace/.scratch/trustsh-review.log:27,34,59–60`: `trust: 26 claims, 0 findings`; `trust: 26 proofs replayed`; `12 of 12 replay(s) passed.`; `rc=0`. Both logs read completely. The earlier “full post-repin trust pass unconfirmed” limitation is now discharged by supplied logs; these commands were not rerun by reviewer-21.
- `/home/eturkes/Projects/fvtrace/.scratch/prereqs-fixedpoint.log:9–13`: pre-level-walk binary hash `26bd28e6fcc1f23785a1d48243be7f829a814cafa6be42fcc091b27f9f3f3a0e`; eval n=300/600/1200 = 6.32/61.49/417.08 s, each row rc 0, load 30.43 at start. At n=1200, output = 33,407,364 bytes (the same byte count as the post-fix log, not a byte-equality claim). Whole driver FAILED: :14 `unexpected EOF while looking for matching` and :15 `rc=2`; no completed green benchmark run or end-load reading claimed. The historical 304 s console observation remains unconfirmed: this rerun measures 417.08 s under different load. Historical 53bcecc figures remain unconfirmed.

Validation = two re-review rows adjudicated; no unresolved cells. Only the scoped text + three newly allowed logs read in this round; no builds, target edits, test/gate reruns or new findings.

reviewer-21-DONE-2

