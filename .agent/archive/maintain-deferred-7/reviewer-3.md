# Closing review — MAINTAIN deferred rows, seventh sweep (reviewer-3)

Base 77bf045 → head 36349ab (`git -C /home/developer/Projects/fvtrace diff 77bf045 36349ab`). Out of scope: `c/hacl/**` (vendored, gate `vendor` re-checks), `pnpm-lock.yaml`, `tests/fuzz/**`, `FvtraceFuzz.lean`, `FuzzMain.lean`, `tools/fuzz.sh`, `.github/workflows/fuzz.yml` (MAIN reviews these).

Verdict values: `pass` | `defect` (a behavior or text the slice's contract contradicts: give file:line + the exact anchor bytes + the contract text it breaks + a concrete input or reading that shows it) | `note` (no contract breach; worth a look). Contract = `.agent/contracts/kernel.md`, `.agent/spec.md` Decisions, `.claude/rules/*.md`, the deferred row each commit closes (its text in `git show 77bf045:.agent/deferred.md`).

## Verdict table

| id | lens · slice | verdict | evidence (file:line + anchor, or the check you ran) |
|---|---|---|---|
| R1 | correctness · 36349ab reused facts: Model `mustVerifyWith`/`Trace.mustVerify`, `Fact.allows`/`ceiling`, Lookups field, Check route + messages, Engine `mustVerify`/`closable`/`unlocks`/`Overrides.valid`/`parseWith`, Evaluate, Answers/Delta + Fast — vs kernel.md § Model, WF-route, S-override + the Decisions ruling ("Only background conditions may be assumed") | pass | R1n: 36 independent CLI cases: kind × source status × depth × route, with ceiling, closability, actions, and acceptance/refusal. Generated C confirms the walk is tail-recursive. |
| R2 | statement faithfulness · 36349ab Spec/WellFormed `RoutesRespected` + Spec/Engine claims that read `mustVerify` — does each Lean statement say what kernel.md now says (no weaker, no stronger)? | pass | `Fvtrace/Spec/WellFormed.lean:64` + `Fvtrace/Spec/Engine.lean:58,64`: checked their definition closures vs WF-route, S-state, G12 and G13. `lake build Fvtrace` + `examples` rc 0. |
| R3 | tests · 36349ab: Tests/Check `reuseTests`, Tests/Engine reuse block, Tests/Differential generator changes, `tests/engine/cases.mjs` reused-facts case — each expected value traceable to the contract, not to the code; are the changed Differential cases a faithful replacement of what they covered before? | pass | `lake test` 1969/1969, pure 858/858, 1,011,465 differential comparisons (35 kept/31 malformed main traces + named families); `node --test tests/engine/` 6/6. Valid formerly assumed reuses now use a background source; the must-verify source stays in the generated matrix. |
| R4 | correctness · f03c3c7 moving link: `Store.keyOf`, `logicalCwd`, `Env.logical`, `Target.key`, `resolve`, `recordedProject` — vs the Decisions Product ruling + README data-folder text | defect | R4a: a plain root child gets a new entry keyed on `//name` (`Fvtrace/Store.lean:135`). |
| R5 | correctness · eb07121 proxied problem text + 13eb794 serve bind hint: `Server.nextStep`/`problemReply`/`Config.shared`, `Cli.bindHint` — vs Decisions GUI access + `.claude/rules/server.md` | pass | 9 live HTTP cases (local, `--host`, `--token-file` × three record problems); exact required 409 text. `lake test` covers the refused address and a held port. |
| R6 | tests · f03c3c7, eb07121, 13eb794, 79e0637 (`linkTests`, smoke link block, `problemTextTests`, proxy e2e cases, `serveTests`, Tests/Decode `commandProperty`) — each expected value traceable to the contract | pass | `lake test` + CLI smoke rc 0. Replayed the expected values against Product/GUI access/Bind and D-shape; R4a is an uncovered root case (not an incorrect existing expectation). |
| R7 | correctness · tools: 13ba7a1 (`tools/scale*.{mjs,sh}` receipts), 6c2c0d9 (`tools/meta-lint.mjs` sections + probe), bf87c94 (gate.yml Lake cache, `tools/gate.sh` provision checks, probes) — vs `.claude/rules/ops.md`, `ci.md`, `fast.md` | defect | R7a/R7b: the new guard accepts a missing commit-SHA key and a weekly cache restore. `provision` + `meta_lint` positive controls 18/18 (worktree obstacle below). R7n: stale `action.txt` only for a reused generator directory. |
| R8 | docs · 3a1e32c human-facing pass (README, SECURITY.md, skill, CLI help in Fvtrace/Cli.lean) + 36349ab text edits: did any split change a fact, drop a condition or sever a cause? Do README/help/skill still match the code? | defect | R8a: the README rewrite extends its self-trace guarantee to two unproved claims. R8b: README describes more paths as link-keyed than the ruling does. |
| R9 | claims vs evidence · every commit body in 77bf045..36349ab: numbers + named checks match what the repo shows (e.g. `.agent/contracts/units.md` § Mutation credit counts, test names, file paths) | note | R9n: local records corroborate named totals and CI wall times; the durable mutation-record scope parenthetical now overstates namespace equality. |
| R10 | cleanup + altitude · the whole in-scope diff: dead code, duplicated logic, helpers not reused, a special case where the mechanism should change | defect | R10a: stale audit pointer in `testing.md`; R10n: two separable cleanup candidates. |

## Findings (one section per defect or note, keyed by row id)

### R1n · contract note · a source-free cycle is allowed by the kernel clause

`Fvtrace/Model.lean:314` anchor: `f.instantiates.any (mustVerifyWith fact? n)`. The decision “a reuse of a fact that must be verified must be verified too” gives a reachability rule; lookup of a missing id, and a cycle not reaching V, both return false. Check's WF-refs separately rejects missing ids. A cross-subject cycle of only instantiations may be assumed in WF per kernel.md § Model (“a cycle of reuses reaching no kind in V = false”), and `Tests/Check` pins it. The `.agent/spec.md` Decisions shorthand “Assumable kinds = statistical, provenance, interpretation, release, spec-review, instantiation of one of these” could instead be read as requiring a terminal background condition; harmonize wording if intent is the kernel clause. No implementation breach against the explicit cycle clause. The recorded source's status does not propagate (checked `open` and `violated` sources). The new chain cost is already deferred, outside the seven graded P-bound shapes; generated `Model.c` has a loop, not one C frame per reuse.

R2 limits: G12/G13 quantify over `s.mustVerify` (unrestricted scenario for G12, WF + valid overrides for G13), whose unfolded body is the fuel-bounded transitive lookup. `RoutesRespected` applies the same predicate to recorded ids and every resolved success/failure key; missing outcome keys are WF-refs, not silently accepted by whole `WF`. `LookupsAgree`/`AnswersAgree` quantify over every trace/scenario, not just WF. These statements do not separately prove equivalence to an independent graph-closure definition; the contract uses the count as fuel and the endpoint/bound tests pin it. Checked the changed C8/P9 wording against G12 by reading; `examples` verified unchanged verdict counts and current receipts, not the independent-kernel replay (recorded replay checked only in R9).

### R4a · major · real projects directly below `/` get a different key

`Fvtrace/Store.lean:135` anchor: `let named := (← IO.FS.realPath parent) / name`. Lean's `FilePath.join` inserts a separator even for parent `/`; `normalize` leaves the resulting `//usr` unchanged. `keyOf` mistakes that spelling for a link. Existing `/usr` entries become unreachable by the normal `--project /usr` or `PWD=/usr` route; `--project /usr/.` still selects the old key.

Contract: `.agent/spec.md` Decisions/Product: “a project's entry is keyed by its real path, except a project folder named through a link that is itself the folder”. Here `/usr` is not a link; `realpath /usr` and `realpath /usr/.` both give `/usr`.

Red on 36349ab (built `lake build fvtrace` in the private copy): `test ! -L /usr && direct=$(fvtrace path --project /usr) && dot=$(fvtrace path --project /usr/.) && test "$direct" = "$dot"` with both invocations using the same scratch `FVTRACE_HOME`. Both path commands returned 0. Output before the comparison: `direct: …/usr-7c2742d3fd0f/trace.json`, `dot: …/usr-894d731f69bb/trace.json`; equality rc 1.


### R7a · minor · the new CI validator does not check the commit part of the cache key

`tools/gate.sh:425` anchor: `Lake cache key lacks shard + OS + arch + lean-toolchain`. The prefix test can pass for a fixed key. `.claude/rules/ops.md` requires that `provision` check “the Lake build cache's key parts”; `.claude/rules/ci.md` specifies `lake-<shard>-<OS>-<arch>-<lean-toolchain hash>-<sha>`. A constant suffix stops future exact-key saves once that name exists, even though CI still looks green. The workflow at head has the right key; it is the *new validator* that fails open.

Red on 36349ab (isolated copy): `sed -i 's/-\${{ github.sha }}$/-no-commit-key/' .github/workflows/gate.yml; source tools/gate.sh; provision; actual=$?; test "$actual" -eq 1`. Confirmed changed line 68 ends `}}-no-commit-key`. Unchanged `provision` rc 0; planted `no_sha_provision_rc=0 (wanted 1)`; contract-test rc 1. The existing positive-control plant which removes lean-toolchain still fires.

### R7b · minor · the new CI validator accepts a weekly cache restore

`tools/gate.sh:427` anchor: `grep -qF "github.event_name != 'schedule'"`. The new validator checks substring presence rather than a mandatory conjunction. `.claude/rules/ops.md` requires a `provision` check of the “weekly skip”; `.claude/rules/ci.md`: “the weekly run builds + replays from scratch”. Replacing `&&` with `||` makes a weekly lean/e2e job restore the cache (left disjunct true) while the right disjunct's text remains.

Red on 36349ab (isolated copy): `sed -i "s/matrix.shard != 'checks' \&\& github.event_name != 'schedule'/matrix.shard != 'checks' || github.event_name != 'schedule'/" .github/workflows/gate.yml; source tools/gate.sh; provision; actual=$?; test "$actual" -eq 1`. Confirmed changed line 61 includes the `||`. `weekly_allowed_provision_rc=0 (wanted 1)`; contract-test rc 1. The existing positive-control plant which removes the `github.event_name` clause still fires. Both plants restored.

### R7n · note · receipt generator assumes a fresh output directory

`tools/scale.mjs:478` anchor: `if (action) writeFileSync(join(dir, "action.txt"),`. `node tools/scale.mjs receipts 40 <fresh-dir>` writes no `action.txt`; `fvtrace eval` found 0 actions on its 160 facts/80 claims. Generating `wide 40` then `receipts 40` into the same directory leaves `suppose:E0` in the old `action.txt`; `test ! -e` rc 1. `tools/scale.sh` always makes a new scratch directory, so the deferred row's acceptance is unaffected. No full receipts timing rerun here; existing run logs + fresh generator, CLI, and source path inspected. The pre-existing GUI rows are already deferred.

### R8a · minor · the README self-trace split broadens the theorem claim

`README.md:329` anchor: `Each claim says what one, two or three Lean theorems prove. Its entailment fact`. At base the colon tightly binds this explanation to the seven “Fully supported” claims; at head “Each claim” follows a full stop and reads as all nine self-trace claims. `.agent/spec.md` Decisions/Examples: “C2 + C7 need tested code, so E2 + E7 stay open”. `jq` rematch at head: `[{"id":"E2","status":"open"},{"id":"E7","status":"open"}]`. Those entailments are not the proofs the new wording says they are. “Each of those seven claims” restores the scope without joining ideas.

### R8b · minor · the README overstates which link spellings get a stable key

`README.md:246` anchor: ``you open through a link, for example `current`, is named after the link.`` Contract `.agent/spec.md` Decisions/Product: “a project folder named through a link that is itself the folder … keyed by the link's own path, its parent resolved.” E.g., `current/analysis` where `current → r1` and `r1/analysis` is an ordinary directory keys on `r1/analysis`, not on `current`; repointing `current → r2` changes its key. Tested both spellings with the head binary: each alias equaled its real target’s entry, but the before/after entries differed (`analysis-234d333f9eda` vs `analysis-defca1c5cec7`, comparison rc 0). The current README rule covers such an ancestor link. State that the project folder itself must be the link.

### R9n · evidence note · narrow the mutation provenance parenthetical

`.agent/contracts/units.md:293` anchor: ``Fvtrace/ identical through the sweep's later commits``. E.g., `git diff --name-only 72da483 36349ab -- Fvtrace/` also lists `Store.lean`, `Server.lean`, and `Model.lean` as well. The five campaign source files (Json, Decode, Encode, Lint, Snapshot) remain byte-identical in Git across those revisions, so this does not invalidate the attributed mutant totals. Say the five campaign source files are unchanged instead of the whole namespace.

Reviewed all 15 bodies; checked the five file names + mutation arithmetic and reviewer-2's rulings against units.md/the local mutation record; local comparison log `1253 / 0 differing / 0 timeouts`, final trust log `26 claims / 0 findings` and `12 of 12 replay(s) passed`; current native/pure test names and e2e names in source; 21 tracked fuzz seeds and five targets named (source/count only; campaign implementation excluded); Node/package pins and refresh log; two CI trees and the 282/153 s, 207/142 s jobs in `.scratch/ci-wt/.gate/ledger.tsv` (the main ledger does not hold those runs). Exact external upstream timestamps, signing verification, historical build-stage sub-timings and remote cache-hit logs not independently re-fetched; the review used the commit records and available local logs. No performance-bound verdict offered: build-side review at 36349ab is separate from the in-flight reference-host scale run.

### R10a · minor · the testing rules point at a deleted deferred row

`.claude/rules/testing.md:23` anchor: ``Property-test audit = `.agent/deferred.md` row "Property-test audit".`` At head the deferred file has no such row; 79e0637 closed it. The actual audit is `.agent/contracts/units.md:257`. `CLAUDE.md` Session flow / Rules upkeep requires dead guidance to leave at the MAINTAIN close. Point agents to the actual table.

### R10n · cleanup and altitude

`Fvtrace/Evaluate.lean:50,151,191` repeats `f.ceiling (A.lookups.mustVerify f.id)` for the same envelope/action contract; lowering it to a fact-ceiling operation at the lookup/answer boundary would make future changes less likely to miss one surface. It is correct now. `Fvtrace/Store.lean:114,125,159` has two different real-parent comparisons (`isLink`/`keyOf`) and resolves the candidate twice in `resolve`; a shared project-identity helper could keep root/key logic together (see R4a), while preserving `isLink`'s existing dangling-link and error behavior. No unrelated refactors required for the verdict.

## Obstacles and coverage

- `meta_lint` probe `meta-lint-prototype` printed `cp: cannot stat '.git/index': Not a directory` in the linked worktree, although it fired and the combined probes reported 18/18. Other meta/provision plants fired normally. `git status --short` afterward was empty. The `.git/index` hard-coded assumption predates this diff; do not read that probe result as proof that its backup branch worked in a linked worktree.
- First HTTP harness tried to parse the first stdout line and got `TypeError` (that line is `Serving the project …`, not the URL). Corrected the harness to find the URL line; all 9 live checks passed. No browsers or nonlocal servers used for these probes.
- No local Chromium/proxy-GUI run, reference-host scale rerun, external CI replay, independent-kernel replay rerun, mutation campaign rerun, or Windows/macOS execution. Reviewed source and available local evidence instead; CLI HTTP tests cover API wording only, and Node parity does not cover Chromium. No all-gate claim. Full `git diff --check` flagged intentional whitespace inside the excluded JSON fuzz seed; with `tests/fuzz/**` excluded it returned 0.

reviewer-3-DONE-1

## Re-review of the fixes (73706f5; each against its acceptance alone)

| id | acceptance | verdict | evidence |
|---|---|---|---|
| RR4a | `fvtrace path --project /usr` = `--project /usr/.` (both the real-path entry, as before f03c3c7); `Store.isLink "/usr"` = false; a real link under the root still keys on the link | pass | Fixed binary: `/usr` and `/usr/.` both `usr-894d731f69bb/trace.json` (expected from sha256 of `/usr`), rc 0; Lean `#eval Store.isLink "/usr"` = `false`; `FVTRACE_TEST_AREAS=cli-store lake test` 133/133. In a transient root, `/review-root-link → /usr` instead keyed `review-root-link-ef908b4cd415/trace.json` (sha256 of the link spelling), rc 0. |
| RR7a | `provision` fails (rc 1, "Lake cache key lacks … + commit") on a key without `${{ github.sha }}`; passes on the committed gate.yml | pass | `bash tools/gate-probe.sh provision`: `provision-lake-sha` fired (rc 1, required diagnostic); 13/13 overall. `source tools/gate.sh; provision` on committed workflow rc 0. |
| RR7b | `provision` fails (rc 1, "restores the Lake build on the weekly run") on the `||` skip; passes on the committed gate.yml | pass | Same run: `provision-lake-weekly-or` fired (rc 1, required diagnostic). Committed workflow rc 0. |
| RR8a | README self-trace paragraph scopes "says what … Lean theorems prove" to the seven Fully supported claims | pass | `README.md:330`: `Each of these seven says what one, two or three Lean theorems prove.` The antecedent is the seven Fully supported claims. |
| RR8b | README data-folder sentence names the link key for a project folder that is itself a link alone | pass | `README.md:246`: ``folder itself is a link, for example `current`, its data folder is named after the link.`` Ancestor-only links are not covered. |
| RR10a | `.claude/rules/testing.md` points at a section that exists | pass | `.claude/rules/testing.md:23` now points to `.agent/contracts/units.md`; both cited headings exist at lines 257 and 291. |

Re-review limit: acceptance checks above only. The first transient-root attempt lacked `/dev/urandom` (rc 1); added a private `/dev` and reran successfully. No host root writes, full gate rerun, or non-Linux runtime claim.

reviewer-3-DONE-2
