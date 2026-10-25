# reviewer-4 · closing review (U11) · lens R4 · target 01cf228^..f3bc87f

| id | asks (see .agent/review.md) | verdict |
|---|---|---|
| R4.1 | new tests (Tests/Scale, Tests/Differential, Tests/Export page v4, e2e responsive + export + engine) assert contract-derived values; each red witness = revision + command + output, or a planted mutant | finding: R4-F1 (claimed scale red is a green run; whatif regression absent). Assertions otherwise follow contract/reference semantics; other calibration limits under R4-F5. |
| R4.2 | no test, gate stage, probe, threshold or bound weakened, skipped or removed (the export spec's planted worker, `tools/scale.mjs` whatif E_i = tested, scale.sh grading, server tests) | finding: R4-F8 (v2 cutover silently empties action-derived explicit specs and converts synthetic fact-details coverage into refusals). Initial pass reversed by two new red witnesses; other format/ABI replacements + strengthened bounds remain accepted. |
| R4.3 | purpose-built checks (`tools/scale.sh` rows, bounds, RSS + bytes ratios, the RSS cap, GUI bounds; `tools/compare.sh` v2 modes) fire on planted inputs (probes `scale`, `compare`) and grade what the contract says | finding: R4-F2 (timed-out v1 JSON comparisons pass), R4-F3 (P-time text commands ungraded), R4-F4 (existing what-if satisfies the new-answer timer before completion), R4-F7 (whatif GUI driver omits5 required rows) |
| R4.4 | mutation credit for every tested line the phase changed (Json, Evaluate, Server, Session, Snapshot, Cli, Export): scope + command + each survivor ruled (M1, M2, M4 + new) | finding: R4-F5 (incomplete scope/command credit; 91 changed-line candidate sites beyond exact-line mappings), R4-F6 (M4 specifies behavior that lacks a killing test); M1/M2 equivalents accepted, M3 already killed |

Review posture: fixed four rows read before target; target root = `.scratch/worktrees/v1`, HEAD = `f3bc87fc549b140558f9a7cff25a7a31d11e6fdf` (source anchors below relative to that root). Laws + all commit bodies collected; target/primary read-only. Evidence files beside this validator input. Full gates, builds + mutation campaigns not run here.

## Findings (per id: claim · anchor · contract clause · severity · fix idea)

### R4-F1 · major · P-evidence's scale red witnesses remain unfulfilled

- Claim: four added numerical assertions on outcomes/prereqs were green on the old engine; no timeout/timing assertion makes them red. The required new whatif scale regression is absent. Reporting the green old run as `Tests/Scale red on v1` overstates verification.
- Target anchors: `.agent/contracts/units.md:99` exact bytes `Tests/Scale red on v1`; `Tests/Scale.lean:199,209` exact bytes `let n := 3000`; these rows assert values only. `tools/gate.sh:76`: `lean_test() { lake test; }`; no per-area timeout.
- Proof (committed text): `git show -s --format=%B 191121e` explicitly records `1321/1321 pass but the eval-scale area takes 337,566 ms`. Its command is `lake build «fvtrace-tests»` + `.lake/build/bin/fvtrace-tests` on `4f82d44`; that is green evidence, not a red witness. Full `Tests/Scale.lean` + target-range commit bodies read; no whatif case/red found. E-wasm's 12,000-claim trap *does* have a red witness (`c5e0ee5`, `7e6c4ff`, node test, rc1 + RangeError).
- Absence-query control: `rg -cF '"eval-scale: outcomes' Tests/Scale.lean` → expected2, output2, rc0; `rg -n 'withOverrides|whatif|what-if' Tests/Scale.lean` → no matches, rc1 (whole file read too).
- Contract: `kernel.md:145` P-evidence explicitly requires v1 timeout/trap witnesses for outcomes, prereqs, new whatif + call depth; `CLAUDE.md:49` + `ops.md:12` require a red command + output.
- Fix: record a genuinely failing bounded v1 invocation for all three new scale workloads, carry an effective regression check, keep the numerical reference assertions, correct the ledger. New bounds/gate changes follow the user's approval rule. No old build run here (brief forbids builds); failure is in the evidence claim, not a claimed value mismatch.

### R4-F2 · major · v1/v2 comparator accepts timed-out JSON answers

- Anchor: `tools/compare.sh:81` exact bytes `if [[ "$(<"$work/old.rc")" == rc=0 ]]; then`; `cmp_json` records rc files but never increments `timeouts` (unlike `cmp_run`). Both rc124 + empty partial stdout/stderr compare equal. The newly added v1 `oracles` also invoke binaries without `timeout`.
- Red command: `bash .scratch/reviewer-4/probe-compare.sh` → rc1. Runs the unchanged target script against two stand-ins that print the contract's respective schema forms and really sleep on `eval --whatif O9=proved`.
- Output: `positive control: timeout rc=124 (expected 124)`; `compare: 918 runs, 0 differing outputs, 0 timeouts (...)`; `target compare rc=0 (expected nonzero)`; `FAIL: compare accepted timed-out v1/v2 JSON answers`. Full output = `probe-compare.log`; inner output = `compare-timeout.log`.
- Oracle timeout red: `bash .scratch/reviewer-4/probe-compare-oracle.sh` → rc1; unchanged comparator `--timeout 0.2` reaches a sleeping `--action`, never times it out. Output: `outer timeout rc=124; per-run limit=0.2s, outer limit=10s`; `positive control: oracle action entered`; `FAIL: expansion oracle ignored the comparator per-run timeout`. Log = `probe-compare-oracle.log`.
- Contract: `kernel.md:126` V-cli comparison = timeout per run; `kernel.md:145` P-evidence; `compare.sh` own header: equal partial output proves nothing.
- Fix: one bounded runner shared by byte comparison, transformed JSON + both oracle modes; record rc124 before transforming or comparing, fail invalid transforms, include timeout plants that enter the v1/v2 JSON + action/details paths (current compare probe hits `cmp_run` alone).

### R4-F3 · major · P-time text rows never run

- Anchor: `tools/scale.sh:171` exact bytes `cmds=(check eval action "${kinds[@]/#/details:}" export serve)`; neither row construction nor its CLI dispatcher names claims, gaps, experiments or plan.
- Red command: `bash .scratch/reviewer-4/probe-scale-text.sh` → rc1. Wrapper exits73 on all four required text commands, delegates every other command to the target binary; unchanged scale.sh runs `--assert --n 20 wide`. GUI rows use its supported stand-in driver (independent of the missing CLI rows); real native/server/page-engine paths run.
- Output: `positive control: claims rc=73 (expected 73)`; `scale: every graded run within its bounds`; `target scale rc=0 (expected nonzero)`; `FAIL: P-time text commands can all fail while scale --assert passes`. Full rows = `scale-text.log`, test output = `probe-scale-text.log`.
- Contract: `kernel.md:131` exact bytes `Text commands (`claims`, `gaps`, `experiments`, `plan`) are graded on the F5 four`; `kernel.md:145` requires every P-time row.
- Fix: add the four text rows on wide/deep/experiments/exclusions, preserve documented output-growth exemptions elsewhere, plant a failure/slow invocation on each path.

### R4-F4 · major · GUI timer can time the old answer as the new one

- Anchors: `tools/scale-gui.mjs:60` exact bytes `if (w.kind === "answered")`; `:83` exact bytes `at[i] ??= performance.now() - t0;`. `holds(answered)` = any “Showing a what-if” + no body busy; it runs in click capture before the app's handler, then the queued RAF commits the timestamp without rechecking.
- Consequence: when a measured click begins from an existing what-if, a new action can remain pending beyond10s yet `whatif`/`startup` timing records the next frame of the old view. The graded whatif shape also has the earlier selector coverage failure R4-F7; this timing defect becomes reachable there once that failure is fixed. The red harness isolates timing, not an assertion that the current full whatif run falsely passes.
- Red command: `node .scratch/reviewer-4/probe-gui-timer.mjs` → rc1; executes target's unchanged `timed()` with virtual DOM event/RAF ordering, no browser/build. Positive control recorded→what-if waits for the same delayed answer.
- Output: `positive control (recorded → what-if): measured=20016 ms; premature=false`; `existing what-if → new what-if: measured=16 ms; pending body aria-busy=true; actual answer=20000 ms`; `FAIL: the old what-if satisfies the new answer timer before the request completes`. Log = `probe-gui-timer.log`.
- Contract: `kernel.md:167` U-time = input timestamp → frame containing that action's answer, ≤10s, including startup; P-evidence requires a planted breach to fire.
- Fix: correlate completion with the request/evaluation begun by this click (not generic prior view text); defer the first observation past event dispatch, recheck at the measured frame, and add the already-what-if delayed-answer plant.

### R4-F5 · major · mutation scope/command record does not cover the phase's tested changes

- Claim: U7 explicitly owes credit; U3/U4b additions also extend past the recorded campaigns. An in-flight post-target campaign is not credit for `f3bc87f`.
- Anchors: `.agent/spec.md:62` U7 open mutation row (match exact bytes `open: mutation credit`); `Fvtrace/Json.lean:288` exact bytes `if !input.validateUTF8`; `Fvtrace/Evaluate.lean:78` exact bytes `if title.any (fun t => q ==`; `Fvtrace/Server.lean:87` exact bytes `def bodyCap : Nat := maxTraceBytes + 1024`; `Fvtrace/Export.lean:28` exact bytes `def pageModules : List (String × String) := modules.filter (·.1 != "worker")`.
- Evidence: every body in `01cf228^..f3bc87f` read (`commit-bodies.txt`). `96f80ba`: `Mutation credit owed` (Json + Evaluate); `7c536ee`: `Mutation credit for the changed Json + Server lines: batched campaign (owed, U7 close)`. No phase Export campaign/red for the new worker-filter code found. `87a3640` + `28ed727` report new Tests/Export worker/v4 checks green, not a red run or Export campaign.
- Inventory command: `python3 -I .scratch/reviewer-4/inventory-mutation.py` → rc0. `node <target>/tools/mutate.mjs <scratch-copy> --list` only; no build/campaign. `mutation-inventory.json` = 8 indexed files, exact site bytes + operators, changed hunks + mapped scopes; sources/site lists in `mutation-sources/`. Counts below are **candidate sites lacking an exact unchanged-line mapping**, not live bugs or a claim every site is competent. Scope files referenced by M2–M4 are unversioned; inspected `.scratch/refs/mutate-u3.sh`, `mutate-u6.sh`, `mutate-u6b.sh` to grant the most generous mapping. Their bytes at campaign time cannot be confirmed from target history. U3/U6 commit bodies record totals, not those exact scope+test commands; persist those commands before claiming durable credit.

| file (target `Fvtrace/`) | record generously credited | changed-line default sites beyond that mapping |
|---|---|---|
| `Json.lean` | U2 `c5e0ee5`: `--lines 22-38,179-189 --timeout 900`; 15/16, M1 | 74: `103,105,107,117,161-164,288,307,312,314-317,323-324,337,358-359,361,363,373-375,377-381,385` |
| `Evaluate.lean` | U3 `7963d7c`: `83-90,130-193,242-261`, timeout900; 9/9 | 4: `78,97,148,231` |
| `Server.lean` | U6 `d2369f6`: `33-40,132-133,137-153,155-181,184-185,190,208-209,217,227-228,230`, timeout900, `--test 'lake test'`; 4/4 | 9: `87,101-102,161,172,222,230` |
| `Session.lean` | U6 `d2369f6`: `58-59,65,69-75,80-81,96-114`, timeout900, `--test 'lake test'`; 1/2, M4 | 0 beyond mapping; M4 remains R4-F6 |
| `Snapshot.lean` | U6 `bc53e1c`: `73-74,77,90-116`, timeout900; 1/1 | 0 beyond mapping |
| `Cli.lean` | U3 `7963d7c`: `159-160,400-407,420-422,438-440,649-657`, timeout900, `--test 'lake test'`; 4 killed/3 survived/4 incompetent | 0 beyond mapping; M2 ruled below |
| `Export.lean` | none for changed phase code | 4: `28,32` |
| `Request.lean` | U3 `7963d7c`: `1-90`, timeout900; 5/5 | 0 |

All changed non-comment lines outside the mapped scopes (including signatures/imports/string-only changes; operator-free lines do not demand nonexistent mutants):

| file | target lines without recorded mapped scope |
|---|---|
| `Json.lean` | `102-107,112,116-119,126,160-166,288,305-307,311-317,323-335,337,352-363,366,369-375,377-382,385` |
| `Evaluate.lean` | `4,21,25,50-51,64-68,73-81,84,92-98,113-114,119-120,122-123,128,137,144-153,158,210,230-231,233,236,241,246,251,261-263` |
| `Server.lean` | `40,70,84,87,101-105,108-109,119-120,122-124,126-128,135-137,155,161,171-174,184-188,193-196,198-200,202,206,218-223,225,230` |
| `Session.lean` | `25,27,118-121,124-126,130-134,137-138` |
| `Snapshot.lean` | `4,75-76,80-83,88-89,121-124,127-128,131-132` |
| `Cli.lean` | `63-69,88-92,615-616,880,884,886,899-900` |
| `Export.lean` | `28,31-32,138,153-154,161-162,167-168,171` |
| `Request.lean` | none |

- Precision: Server:161 preserves the U6 `v' == v` guard but changes its tuple pattern (pair→triple); :230 preserves the64 connection count, :222 lists the tool's syntactic `<$>` operators (likely incompetent, **not run**). Evaluate:97 preserves the old provisional predicate. These are candidates for explicit transferred-credit/incompetent rulings, not reasons to demand different behavior. New semantic holes still include Server body-cap/route comparisons/text cache + Export filters + U7 Json/Evaluate.
- Contract: `CLAUDE.md:49` + `.claude/rules/lean.md:20` + `ops.md:12`: tested changes require default-operator credit, commands/scopes + every survivor ruled; proof equality does not cover JSON/IO/printers.
- Fix: complete the missing campaigns or explicit credit-transfer rulings, include the native suite where it owns coverage, record exact revision/scope/command + results in the closing commit, rule every survivor. Record zero-site scopes too. No need to mutate proved `Answers`/forest/walk code.

### R4-F6 · major · M4's survivor changes a specified read bound

- Anchor: `Fvtrace/Session.lean:65` exact bytes `readPrefix t.trace (limit + 1)`; `.agent/review.md:10` exact bytes `survivor Session.lean:65`.
- Proof: target ledger + `6ef4b4a` record the `+1 → +2` mutant surviving. D-json (`kernel.md:7`) specifies `at most one byte past the limit is read`. If a regular file grows between metadata and read, the mutant reads an extra byte; eventual decode refusal does not restore the promised I/O bound. It is therefore not an equivalent/unspecified survivor.
- Ruling: **add the missing deterministic test**. The ledger itself identifies the injection point: a byte-counting reader (and controlled metadata result) makes the race deterministic. “Untestable race” is not justified when the boundary can be injected. No new race experiment/build run here; this is adjudication of the recorded surviving mutant, not a claim the target currently reads2 excess bytes.
- Fix: exercise `readRawWithin` with a reader whose available bytes grow after metadata; verify at most limit+1 consumed; demonstrate red on +2, green on target. Keep the production limit unchanged.

### R4-F7 · major · the whatif shape has no control that the GUI driver can click

- Anchors: `tools/scale-gui.mjs:32` exact bytes `const symbol = 'article.circuit button.switch[aria-label^="Suppose"]';`; `:163` exact bytes `if ((await p.locator(symbol).count()) === 0) return;`.
- The whatif generator sets every F_i/E_i override. `web/circuit.js:56-58` gives every such switch `Restore the recorded status of …`, never `Suppose`. Driver exits each mode after details; busy, whatif + page startup are unmeasured. `scale.sh` correctly flags missing rows, so the specified acceptance cannot complete for this shape; this is not a false-green overall scale run.
- Red command: `bash .scratch/reviewer-4/probe-gui-rows.sh` → rc1; actual target GUI driver + binary in bundled Chromium, n4, served + exported. Positive control = wide, expected11 rows.
- Output: `wide: driver rc=0; emitted rows=11 (expected 11)`; `whatif: driver rc=0; emitted rows=6 (expected 11)`; `whatif emitted: gui:served:first gui:served:select gui:served:details gui:page:first gui:page:select gui:page:details`; `FAIL: whatif emits no busy/result/startup measurements (all switches restore overrides)`. Log = `probe-gui-rows.log`; raw rows = `gui-rows/{wide,whatif}.rows`.
- Contract: `kernel.md:130-131,167` all P-bound shapes get served/exported U-time rows, whatif under its2n-entry override; `P-evidence` every row graded.
- Fix: pick a valid enabled what-if/action control for the shown state (including restore), require all expected rows before driver success, keep the existing full-override workload. Exercise this row-completeness check with both recorded + preexisting what-if views; fix R4-F4 before trusting the latter's durations.

### R4-F8 · major · v2 silently removes action-derived what-ifs and real fact-detail cases

- Anchors: `tests/engine/cases.mjs:174` exact bytes `records(a["overrides"])`; `:145` exact bytes `const firstWhatif = c.specs.find((x) => x !== "") ?? "";`; `:155` sends every fact's details under that firstWhatif. `actionSpecs` still reads the v1 action payload although V-env v2 actions carry references alone; each missing overrides field becomes an empty list/spec.
- Red1: `node .scratch/reviewer-4/probe-action-specs.mjs` → rc1; target's unchanged helper + actual built native engine. Output: `positive control: suppose:O2 expands to O2=checked`; `target actions=12, native nonempty expansions=12, actionSpecs nonempty=0`; `FAIL: actionSpecs(suppose:O2)="", expected "O2=checked"`.
- Red2: `node .scratch/reviewer-4/probe-fact-requests.mjs` → rc1; actual target `cases(20261022)` + `requestsFor`, synthetic case. Output: `positive control: fact:O1 at recorded → fvtrace.details/1`; `synthetic: fact requests=8, actual details=0, problems=what-if,what-if,what-if,what-if,what-if,what-if,what-if,what-if`; `generated first whatif="O1=checked\u0000"`; `FAIL: generated fact-details requests all reject the inherited malformed what-if before reading the item`.
- Why tests stay green: `requestsFor` still sends action IDs, but those comparisons do not restore the lost explicit-spec relation. `firstWhatif` now falls past all emptied action specs to the first malformed fixed case; native and wasm agree on its refusal, so the fact-detail loop records successful comparisons without exercising details. Logs = `probe-action-specs.log`, `probe-fact-requests.log`.
- Contract: `kernel.md:153` E-wasm requires every one-click expansion (+ its envelope equal to that for its explicit what-if), and details of every item kind; `CLAUDE.md:49` preserves grading cases. The new red evidence reverses R4.2's initial pass; source/ABI replacements elsewhere do not excuse this lost coverage.
- Fix: derive action specs through native action expansion's normalized overrides (legitimate no-op actions may stay empty), compare action answers with the corresponding explicit-whatif answers, select a deliberately valid nonempty view for detail sequences, and assert requested successes have the expected details schema/item rather than merely matching native refusal text. Keep separate refusal cases.

## Survivor rulings (M1–M4)

| id | ruling | target evidence |
|---|---|---|
| M1 | equivalent on D-json's input domain; close | `Json.lean:207` `< → <=` only differs when two candidate offsets tie. `Parse.members:277` supplies each key's unique consumed-input byte offset; a fold never compares one entry with itself. Arbitrary hand-built offset lists are not the parser contract. |
| M2 | all3 listed survivors equivalent; close | `Cli.lean:399-406`: `(evalSpec0).valued` and `.switches` are independent of `positional`; only the **inner** zero at:405 is equivalent (the base record's zero still matters). `:437-447,:650`: explicit `spec := evalOnlySpec` leaves the positional argument used solely by an unevaluated default. Four incompetent mutants are recorded, not treated as kills. |
| M3 | retain closed | target ledger + `d2369f6`: the cache-equality mutant killed (1/1); no survivor. Campaign not rerun. |
| M4 | finding R4-F6; keep open | specified read bound, deterministic injection available. |

## Register (outside the contract)

- No production behavior discrepancy asserted by these probes; R4-F2–F4 are false-green checks. Loaded host, n20 stand-in run ≠ P-bound performance acceptance. Full gate, full-cap/idle-host timings + mutation campaigns not run; GUI runner exercised functionally in Chromium at n4 (R4-F7), with no performance-acceptance claim. No build performed. Lean LSP unavailable (`No LSP server available for file type: .lean`); source/commit inspection used.
- Source/diff coverage: every scoped changed test/tool hunk + every target-range commit body read; seven named tested files + Request inventoried. Proof implementation review, product GUI behavior + security adjudication belong to other fixed lenses.
- E-wasm large-case sampling is explicit: `tests/engine/cases.mjs:144` limits actions/items to first3 for “a4MB”/12,000-claim cases; every item remains exercised on the small fixtures. No claim of exhaustive per-item large-trace differential coverage.
- Existing changed-helper process cleanup in `tests/e2e/fvtrace-server.js` kills without awaiting child exit; already deferred by U1, not a new R4 finding. The review's probes write inside the allowlist (TMPDIR there); their temporary trees were cleaned. Final review-owned process query: no matches, rc1.

reviewer-4-DONE-1

## Re-review (c930c8c)

Check set fixed before fix-source inspection: the eight R4 acceptances in `.agent/review.md` + J1–J10 survivor rulings. Target `.scratch/worktrees/v1` = `c930c8cca09798463db5263cf92fbdb62107df28`; read-only, no builds/campaigns. New probe outputs stay under `rereview/` to preserve the original red evidence.

| id | acceptance | verdict | evidence |
|---|---|---|---|
| R4-F1 | bounded old-revision red per scale workload; whatif row; revision + command recorded | pass | `Tests/Scale.lean`: three20s checks + whatif2,000 size≤8,000,000; red logs rc1 match commit c930c8c (outcomes/prereqs4f82d44; whatif87a3640). Revision distinction below. |
| R4-F2 | JSON-path + oracle timeout plants make compare fail | pass | Reruns rc0: comparator rc1, JSON80 timeouts; oracle16 timeouts + exact `TIMEOUT new self eval --action suppose:F (0.2 s)`. |
| R4-F3 | four text rows + planted failing text command | pass | Rerun rc0; claims/gaps/experiments/plan each `FAIL … rc73`; comparator-independent scale rc1. |
| R4-F4 | answer tied to click's change; delayed answer plant fires | pass | Corrected same harness: f3bc87f rc1 (old→new + Restore measured16ms), c930c8c rc0 (all3 transitions20,016ms). |
| R4-F5 | campaign or explicit ruling per changed tested site, recorded | pending campaign | Observed Session2/2 killed, Json7/22 done; Evaluate/Server/Export not yet reached. Scope script read; complete credit + remaining survivor rulings cannot close from this snapshot. |
| R4-F6 | injected-reader test kills limit+2 | pass | `Tests/Cli.lean:198-206` grows a4-byte file after metadata, asserts5 bytes; campaign records `Session.lean:66 1 → 2` killed (2/2 total). |
| R4-F7 | any enabled toggle; whatif emits11 rows | pass | Rerun rc0: wide11/11, whatif11/11, whatif row failures0 (real bundled Chromium, n4). |
| R4-F8 | action specs from expansion; valid-view details asserted as details | pass | Reruns rc0: actionSpecs12/12 native expansions; fact details8/8, valid `O2=checked`; target engine test asserts details schema. |
| J1 | copySlice capacity-policy mutation equivalent | agree | Installed Lean `ByteArray/Basic.lean:160` definition ignores `exact`; API doc bounds it to growth capacity. Codec output bytes unchanged. |
| J2 | disabled plain-token shortcut equivalent | agree | `plainEnd` returns at34/92/control/EOF, never35; mutation always selects stringSlow. For unescaped tokens both branches copy the same slice and return the same UTF-8 result/offset. |
| J3 | remove dead quote/backslash predicates; credit remaining line | agree | Sole needsEscape call is the fallback after quote/backslash match arms; removed disjuncts unreachable there. Observed all7 remaining line307 mutants killed. |
| J4 | lone-quote test kills quote-predicate inversion | agree; pending campaign | Gap + added test correct (`Tests/Json.lean:113-117`); target campaign had not reached line314. Kill not yet confirmed. |
| J5 | lone-backslash test kills backslash-predicate inversion | agree; pending campaign | Gap + added lone-backslash case correct; line314 kill not yet confirmed. |
| J6 | lone-backslash test kills92→93 | agree; pending campaign | Same lone-backslash case reaches the missed predicate; line314 kill not yet confirmed. |
| J7 | extra escaping-path choices equivalent | agree | `<→≤`/32→33 add space; `&&→or` only enlarges the fast detector. Full character escape path leaves all additionally flagged characters unchanged. |
| J8 | lone-DEL test kills≥→> | agree; pending campaign | Added printed lone-DEL case directly requires `\\u007f`; line314 kill not yet confirmed. |
| J9 | always choosing escaping path equivalent | agree | Only the no-special-byte base case changes; full fold produces the same quoted bytes, empty strings included. |
| J10 | unused escape helper removed | agree | Definition removed; Lean source caller search finds only escapeInto and error-message words, no remaining escape call. |

### Re-review evidence + limits

- **Disposition:** seven R4 fixes pass their acceptance; R4-F5 stays pending campaign. All ten J rulings agree as classifications/fixes; J4/J5/J6/J8 still await observed kills. This is not a phase-wide green claim.
- **F1 revision precision:** `4f82d44` already prints evaluation/2 (`Fvtrace/Evaluate.lean:235`), so its whatif shape has already received the reference fix. Requiring that row to fail there would test the wrong unfixed revision. Read `.scratch/u8/red-scale.sh` (not executed here: it checks out/builds), both build logs (rc0), both run logs (rc1), and c930c8c's committed command/output record. At4f82d44: outcomes414,777ms + prereqs37,646ms exceed20,000; at87a3640: outcomes458,649ms + prereqs42,659ms + whatif619,771,017bytes exceed their checks. Target `Tests/Scale.lean:139,220,237,248-251` carries the time/size checks. The ledger's “each row red on4f82d44” should name these two unfixed revisions instead. Old builds/runs + the whole current Lean suite were not rerun by this reviewer; their explicit records were inspected. P-bound's separate10s at N_cap remains unchanged.
- **F2 harness correction:** whole-comparator patience120s, its per-binary timeout still0.2s; each deliberately sleeping oracle remains30s. `rereview/probe-compare-oracle.sh` requires the oracle's own TIMEOUT line + final comparator rc1, not an outer deadline alone. `rereview/probe-compare.sh` rc0:918 comparisons,80 timeouts; oracle probe rc0:934 comparisons,16 timeouts. This resolves the old harness's10s whole-run ambiguity.
- **F3/F7 live reruns:** `rereview/probe-scale-text.sh` rc0, each of the four text commands fails with planted rc73 and scale exits1; `rereview/probe-gui-rows.sh` rc0 in bundled Chromium, wide + whatif each11 rows, whatif rows all rc0. Generated inputs/artifacts stay in the allowlist; no full-cap or idle-host timing claim.
- **F4 harness correction:** an actual switch changes the scenario text. The original virtual DOM erroneously gave the old and returned what-if the same text. `rereview/probe-gui-timer.mjs` models distinct texts, plus Restore→recorded, and accepts an old source file for calibration. Same harness on f3bc87f: rc1,16ms for both already-what-if transitions; on c930c8c: rc0,20,016ms for all three transitions with the answer withheld until20,000ms. Logs `probe-gui-timer-red.log` + `probe-gui-timer.log`; no generic concurrent-request proof inferred from this controlled driver check.
- **F8 harness correction:** call the now-exported actionSpecs via its actual module instead of extracting the former private function without its new dependencies. `rereview/probe-action-specs.mjs` rc0 (12 native expansions =12 specs, O2=checked included); `rereview/probe-fact-requests.mjs` rc0 (8 real details under accepted O2=checked). Source `tests/engine/engine.test.mjs` asserts the details schema after native/wasm byte equality. The additional dedicated action-vs-spec assertion samples the first4 actions per case; the original large-case item/action cap remains3. These caps are reported, not described as exhaustive relation testing.
- **Campaign snapshot:** `rereview/campaign-observed.log` preserves exactly the live log inspected: Session2/2 killed; Json7/22 reached, all7 at line307 killed; no terminal result for the remaining files. `.scratch/u8/mutate-r4f5.sh` scopes Session66; Json307,314–316; Evaluate78,148; Server88,102–103,223,231; Export28,32, all with timeout900 + `--test 'lake test'`. Earlier `.scratch/u8/mutate-u7b.log` confirms Server161/172 + Evaluate97/231 killed; Json first12 =9 killed/3 incompetent before rc137. `mutate-u7c.log` completes the remaining62 =47 killed/12 survived/3 incompetent, total74 =56/12/6. Incompetent sites are not kills. Campaign not launched, interrupted or polled by this reviewer; no pending kill promoted to verified.
- **J rulings:** J1 is codec-visible equality, not equal allocation cost; Lean's copySlice data definition omits exact and its documented effect is capacity. J2's fast and slow branches on a plain token copy the identical byte slice and use identical UTF-8 acceptance/error positions. J3 removes predicates that cannot be reached after the earlier character match. J7/J9 only add full-escape-path traversals; that path emits the same bytes for every additionally admitted character (space, non-control ASCII, raw Unicode when not shown), including an empty string. These rulings do not assert unchanged execution times or mutation-time P-bound acceptance; the target retains the optimized branches. J4/J5/J6/J8 are genuine output gaps, not equivalents: their lone-character tests target the only byte that the respective mutant misses. J10 removes an unused helper; caller search over Fvtrace/Tests/FvtraceWasm finds only quoted “escape” diagnostics/comments (positive control: exactly1 escapeInto definition).
- **Posture:** target + primary remain read-only. No builds, installs, full gate, full-cap run or new mutation campaign. Existing acceptance probes rerun; only the harness corrections above were made, in reviewer scratch. New probe logs = `.scratch/reviewer-4/rereview/`. Original f3bc87f evidence remains intact.

reviewer-4-DONE-2
