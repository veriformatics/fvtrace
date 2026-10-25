# reviewer-5 · U11 · R5 · target 01cf228^..f3bc87f

Target = `7e6c4ff05ebc1cf51801315c00977119eab43e6e..f3bc87fc549b140558f9a7cff25a7a31d11e6fdf`. Read-only checkout = `.scratch/worktrees/v1`; HEAD + tracked bytes verified against f3bc87f. Check set fixed from `.agent/review.md` before diff access.

| id | asks | verdict |
|---|---|---|
| R5.1 | why-comments; dense agent text; README + GUI register + Decisions copy rulings | finding: F5.2, F5.5 |
| R5.2 | dead code; duplicated helpers; infrastructure special cases | finding: F5.1, F5.3 |
| R5.3 | rules live law + why/scope; spec shape + state; cause → fix commit subjects | finding: F5.4 |

3/3 rows adjudicated; 5 findings, all minor. No blocker/major finding under R5.

## Findings

### F5.1 · R5.2 · minor · dead proof scaffold

- Target: `.scratch/worktrees/v1/Fvtrace/Proofs/Forest.lean:162–165`.
- Anchor: `have keep : ∀ (A : Array (Option Nat)) (G : Array Bool), A = st.1.push (A.back?.getD none) →`; next lines = `True := fun _ _ _ => trivial` + `clear keep`.
- Defect: `link_inv` manufactures a universally true local proposition, then clears it without use. The comment says it establishes preservation of old links, but the proposition establishes none. Actual preservation uses `push_get` later. Dead proof scaffolding, not an auxiliary invariant.
- Clause: `CLAUDE.md` Engineering / Cleanup = “dead code removed”; comments explain a constraint rather than misdescribe a proof step.
- Fix / acceptance: remove these four lines; retain the live `push_get` arguments. No theorem statement changes. MAIN rechecks the proof.
- Proof: exact bytes matched at the checkout + `git show f3bc87f:Fvtrace/Proofs/Forest.lean`; static finding, no behavior test.

### F5.2 · R5.1 · minor · new GUI error uses ruled-out jargon

- Target: `.scratch/worktrees/v1/Fvtrace/Server.lean:195`.
- Anchor: `The request is larger than any what-if on the largest trace.`
- Defect: the new body-cap error says “trace”, explicitly excluded from GUI copy. It also gives no corrective action. This is presentation text, not the machine code `invalid`: `.scratch/worktrees/v1/web/app.js:489` renders it via `else showError(problem.message);`.
- Clauses: `.agent/spec.md` Decisions / GUI = `GUI copy never says "trace"`; `CLAUDE.md` Authoring / Human-facing = an error states what happened + the fix, using the user's vocabulary.
- Fix / acceptance: phrase the error in what-if / facts language + name a corrective action; retain status 413 and problem kind `invalid`.
- Proof: exact message matched at the checkout + `git show f3bc87f:Fvtrace/Server.lean`; emission + display sites read. No oversized request or browser run performed: text finding.

### F5.3 · R5.2 · minor · second copy of the server fixture lifecycle

- Target: `.scratch/worktrees/v1/tests/e2e/fvtrace-server.js:118–135`; existing counterpart `:70–87`.
- Anchor (matches at :70 + :118): `const url = await new Promise(`.
- Defect: new `serveScale` duplicates `serveFvtrace`'s complete stdout/link/exit promise + close callback. Their preparation + argv differ; their readiness/lifetime protocol does not. Future readiness or teardown changes must now land twice within one helper module.
- Clause: `CLAUDE.md` Engineering / Cleanup = “near-duplicate blocks merged”; modular components + deduplicate.
- Fix / acceptance: one shared launch/readiness/close helper parameterized by argv + environment/cwd + owned directory; both entry points keep their current return shapes. Existing tests remain unchanged.
- Proof: `cmp <(awk 'NR >= 70 && NR <= 80' FILE) <(awk 'NR >= 118 && NR <= 128' FILE)` with FILE = the absolute target above → rc=0; both 11-line promise blocks byte-identical. Close callbacks also read. No claim that this duplication itself demonstrates a process leak.

### F5.4 · R5.3 · minor · resume state still calls the landed differential open

- Target: `.scratch/worktrees/v1/.agent/spec.md:62`.
- Anchor: `open: mutation credit (Json + Evaluate lines), tester differential, Tests/Scale rows red on v1`.
- Defect: `tester differential` remains explicitly open although target history includes `1d65c23`, which lands the requested families in `Tests/Differential.lean`, records MAIN's passing rerun, and records tester-1's finished verdict. The sole attached resume state thus directs a fresh session to repeat landed work.
- Clause: `CLAUDE.md` Session flow / Checkpointing = `spec.md` current at every commit; Tasks distinguishes landed pieces from open work.
- Fix / acceptance: move the differential to the landed portion with `1d65c23`; name only remaining work as open. U7 may remain unticked. This finding does **not** rule mutation credit or the Tests/Scale red witness satisfied; those belong to R4.
- Proof: anchor matched at checkout + committed f3bc87f spec. `git show --no-patch --format=full 1d65c23` states `MAIN rerun on the merge ... rc=0, 1519/1519 checks passed` + tester-1's result; the corresponding suite is present in the target diff. Its measurements were not rerun by this reviewer.

### F5.5 · R5.1 · minor · comments still describe the retired transport + per-call snapshot path

- Targets / exact anchors:
  - `.scratch/worktrees/v1/Fvtrace/Server.lean:12`: `Access: every request must use GET`.
  - `.scratch/worktrees/v1/tests/engine/cases.mjs:3`: `fvtrace-tests --evaluate-snapshot`.
  - `.scratch/worktrees/v1/tests/engine/engine.test.mjs:4`: `--evaluate-snapshot`.
  - `.scratch/worktrees/v1/tests/engine/cases.mjs:396`: `Each call decodes the snapshot again (both sides): the 4 MB case keeps to a few.`
- Defect: the phase makes these previously accurate comments false. The answer route now requires POST (`Server.lean:102`); `TestMain.lean:8` recognizes `--answer-snapshot`; both differential engines load once per snapshot, then answer a sequence. The sampling comment gives an obsolete cost model, which can misdirect later coverage decisions.
- Clause: `CLAUDE.md` Authoring = prune obsolete text; Engineering = comments carry the why fresh agents otherwise re-derive. An obsolete why is not harmless metadata.
- Fix / acceptance: describe GET GUI files / POST answers, name the live hook, and state the present reason for the large-case sampling (or leave only the deliberate coverage limit). Preserve test cases + thresholds.
- Proof: exact anchors matched by `rg -Fn`; live replacements read in Server, TestMain, Snapshot + both differential runners. Static text finding; no re-execution of differential tests.

## Register · outside R5 adjudication

- X1 → R4 (lead sent to reviewer-4): `.scratch/worktrees/v1/tests/engine/cases.mjs:174` still reads `records(a["overrides"])` in `actionSpecs`, but v2 actions carry references only. Inference: the old action-derived spec list now consists of empty strings. `requestsFor` separately sends action IDs; the net coverage ruling belongs to R4. Runtime effect unconfirmed; source + v2 contract inspected, no red witness run here.
- X2 → MAIN/R3/S (lead sent to MAIN): `.scratch/worktrees/v1/SECURITY.md:22` says `refuses a body larger than 16 MiB.`; `Server.lean:87` + V-serve name 16 MiB + 1 KiB. Text discrepancy only; no transport or security adjudication here.
- X3 baseline copy, outside phase-introduced text: `.scratch/worktrees/v1/Fvtrace/Server.lean:121` retains `No trace for the project {p} yet. Run fvtrace init.` from the old evaluation function. The same GUI jargon concern as F5.2 predates this phase; kept separate from the new message finding.

## Coverage + checks

- Read the full 80-file / 13,518-line target diff, all 31 commit subjects, all nine target rule files, whole target README + words map, and relevant enclosing functions/callers. No diff sampling or truncation left unread.
- R5.1 otherwise: why-comments explain stack depth, persistent overlays, delta invariants, memory/copy costs, first paint, request ordering + viewport behavior; internal docs stay dense; README additions use direct instructions. GUI verdict + kind/level words match Decisions; internal identifier/comment metaphors are not GUI copy.
- R5.2 otherwise: Delta/Forest/record split removes the old closure memo + its helpers; old HTTP/wasm entry points retired; retained reference definitions + complete-action oracle have test/spec consumers, not dead production alternatives. Fast paths branch on general domain properties, not benchmark identities. Cached/derived state has the phase's explicit performance contract.
- R5.3 otherwise: all 31 subjects follow scope/cause/→/fix (manual read + format check: 31, zero misses, rc=0). Eight rules have quoted `paths:` lists; ops is appropriately repo-wide. Existing Prettier YAML parser accepted all eight frontmatters, rc=0 (standalone yaml/js-yaml + PyYAML unavailable; no install). Rule measurements explain present constraints; no additional origin-story finding.
- `.agent/spec-lint TARGET_SPEC` → rc=0. Positive control in reviewer scratch: rename Intent heading → exactly one diagnostic `section \`Wrong\`, expected \`Intent\``, rc=1. Initial delete-Phase probe produced six cascading diagnostics; replaced with the single-defect control. Spec five-section shape, Artifacts + Decisions reviewed; stale Tasks finding above.
- JavaScript LSP document symbols confirmed on `web/lazy.js`. An initial reference lookup at a nonsymbol location returned no references and was not used as absence evidence.
- Target HEAD + tracked diff rechecked after reading: f3bc87f, `git diff --quiet f3bc87f --` rc=0. The pre-existing untracked `node_modules` entry was left untouched.
- Not run: full/fast gates, build, proof replay, mutation campaign, differential tests, timing or browser rendering. No behavior finding asserted; all five findings are anchored text/structural conformance. No target edits, installs, commits or pushes.
- Deliverable validator: seed = 3 pending rows, rc=0; close = 0, grep rc=1 (zero matches), exact final marker verified. Temporary diff/subject captures + mutated spec control removed; probe output retained.

reviewer-5-DONE-1

## Re-review (c930c8c)

Fixed scope = the six acceptances in `.agent/review.md` Findings; target = `c930c8cca09798463db5263cf92fbdb62107df28`. Same read-only posture; no new review rows.

| id | acceptance | verdict | evidence |
|---|---|---|---|
| F5.1 | scaffold removed; proofs + trust replay green | pass | `.scratch/worktrees/v1/Fvtrace/Proofs/Forest.lean:154–162`: only the four scaffold lines removed; theorem + live arguments unchanged. Read-only compiled auditor rerun rc=0, `26 claims, 0 findings`; raw trust log confirms 26 kernel replays + 12/12 statements, captured fast gate rc=0 (evidence below). |
| F5.2 | reworded; 413 + problem kind kept | pass | `.scratch/worktrees/v1/Fvtrace/Server.lean:195–196`: `The what-if is too long to evaluate. Suppose fewer facts, then try again.`; enclosing `.payloadTooLarge "invalid"` unchanged. |
| F5.3 | one shared fixture launcher | pass | `.scratch/worktrees/v1/tests/e2e/fvtrace-server.js:70` = sole `launch`; :103 + :119 = both callers. One spawn/readiness/close protocol; prior return fields retained. `node --check` rc=0. |
| F5.4 | U7 Tasks row current | pass | `.scratch/worktrees/v1/.agent/spec.md:62` puts `1d65c23 (diff-blind differential)` under landed; open = mutation campaign + survivor rulings. Spec-lint rc=0. No independent R4 credit ruling. |
| F5.5 | named stale comments rewritten | pass | `.scratch/worktrees/v1/Fvtrace/Server.lean:12–13` distinguishes GET files / POST answers; `.scratch/worktrees/v1/tests/engine/cases.mjs:3` + `.scratch/worktrees/v1/tests/engine/engine.test.mjs:4` name `--answer-snapshot`; cases :416–417 explains full-evaluation cost, `one load answers them all`. |
| X2 | body-cap documentation = implemented cap | pass | `.scratch/worktrees/v1/SECURITY.md:22`: `16 MiB and 1 KiB`; equals `maxTraceBytes + 1024` at `.scratch/worktrees/v1/Fvtrace/Server.lean:88`, with `maxTraceBytes := 16 * 1024 * 1024` in `.scratch/worktrees/v1/Fvtrace/Decode.lean:366`. |

Re-review = **6/6 pass**; F5.1–F5.5 + X2 close at c930c8c. Acceptance checks alone; other lenses + register entries not reopened.

- F5.1 independent command: `LEAN_PATH=.scratch/worktrees/v1/.lake/build/lib/lean .scratch/worktrees/v1/.lake/build/bin/fvtrace-trust` → rc=0, `trust: 26 claims, 0 findings`. Output = `.scratch/reviewer-5/proof-audit-c930c8c.log`. Entry point inspected: no arguments = read-only, no proof export or build.
- Replay evidence read in full: `.scratch/u8/trust-fix.log:27–59` = 26 claims / 0 findings, Lean paranoid + lean4lean + nanoda + con-leche + con-ron + Lean default accept, 26 proofs replayed, 12/12 statement replays passed. The c930c8c body records `trust.sh rc 0`; MAIN identifies this log as its pre-commit fix-tree run, with no later Lean change before c930c8c.
- Captured checks: `/tmp/claude-1000/-home-eturkes-Projects-fvtrace/2155a5e3-3163-4893-90dd-21b671e7edac/tasks/bjybwu3me.output` = `fast-gate rc=0 179.3s`; `.scratch/u8/tests-fix2.log` = `1534/1534 checks passed`. Full `lake build` / 133-job output was not saved separately and was not independently rerun here; no claim of a fresh full build or fresh independent-kernel replay by this reviewer.
- Other checks actually run: fixture `node --check` rc=0; target spec-lint rc=0; exact replacement anchors matched. Negative controls: old scaffold found once at f3bc87f, absent at c930c8c (rc=1); retired hook comments found once in each baseline file, absent from the target's three named comment files (rc=1).
- Target HEAD verified c930c8c; tracked diff rc=0. No target writes, builds, installs, commits, pushes, browser run or broad re-review. Temporary scoped diff removed; deciding audit output retained.
- Deliverable seed = 6 pending rows (rc=0); close requires count 0 + the marker below.

reviewer-5-DONE-2
