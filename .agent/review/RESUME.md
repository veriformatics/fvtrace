# Resume (MAIN) — MAINTAIN code review

State files: `.agent/review.md` (check set + Findings F1…), `ROSTER.md` (teammates, states, background jobs), `baseline.md` (B1–B10), `main.md` (MAIN findings + retired security pointers), `leads.md`, `BRIEF.md` + `LENSES.md` (reviewer briefs), `FIXER.md` (fixer brief), `LEAD-DIRECTIVES.txt`.

## Flow

1. Harvest each `DONE` reviewer (`bash .scratch/review/main/waitdone.sh 1500` in background = a wake-up): read its verdict table + finding headers, rerun every behavior proof (red script) / rematch every anchor (`git show 48bc51d:<file> | rg -Fn`; `.scratch/review/main/anchors.py` for cited `rg -Fn` commands), rule (match → finding row; miss → retire with reason), close its ledger row(s), `TaskStop` it, roster → harvested. Base reads via `git show 48bc51d:<file>` (reading under `.scratch/review-base/` loads that copy's CLAUDE.md + rules into context).
2. Fixers (`general-purpose-1..4`, worktrees `.scratch/worktrees/<name>`, branches `wt/<name>`, base 3957c87): on DONE read `.agent/review/<name>.md`, review each commit (`git log -p wt/<name>`), rerun its red/green, cherry-pick onto `main` in class order, fast gate per commit, then full gate per commit via `bash tools/ci-gate.sh <unit>` (parallel `ci/*` pushes allowed), finding status → `fixed <sha>`.
3. K-* cleanup fixes (F46–F52, F54, F55) after the correctness merges (same files): new fixers per area.
4. Baseline still owed: B2 `scale-pass` rerun on an idle host (`offload run --host nixbox -- bash -c '… gate-probe.sh scale-pass'` once nixbox 0/2); B7 `fast-gate.sh` + `ci-gate.sh` (first fix push); B8 `scale.sh --assert` on nixbox idle (CLAUDE.local.md command); B9 `e2e-load.sh gate` on nixbox; B10 `ci/release-*` dry run (standing ci/* permission) + `release.yml` re-check dispatch (needs the user: shared CI state).
5. V-mutation: campaigns A (Cli) + B (13 shell files) via `offload run --pool` from `.scratch/mut-a`, `.scratch/mut-b` (logs `.scratch/review/main/mut/{a,b}.log`; per-file logs come back in `.scratch/mut-*/mut-logs/`); C (`FvtraceWasm/*`) not started; survivors → a ruling teammate (non-author); Json/Decode/Snapshot = deferred row with measured cost (one Json mutant > 30 min at load 25–40).
6. User questions (one AskUserQuestion after agent-side work): F13 test-expectation change (skills refusal rc 1 → 2); page-engine Worker silence deadline (kernel.md E-abi "silent worker = failure" vs Decisions Capability first); per-command `--help` (register); B10 re-check dispatch; any `Decisions`/grading-check change a fixer flags.
7. Close: every row verdict (`rg -c '\| unknown \|' .agent/review.md` → 0), every finding fixed/deferred/routed, archive scrub (relative paths: F10) → `.agent/archive/review-maintain-code/`, deferred rows, rules upkeep, `spec.md` current, full gate green on a clean tree, final message (notify-set edits).

Lessons: run `gate-probe.sh` in a copy, never the primary tree (it plants there); the primary `.lake` needs `lake build` after probes; host load > 25 makes timing probes fail.

## Rulings given to fixers (keep consistent)

- general-purpose-1: F6 test expected-message update authorized (wording not contract-owned); F56 added to its set; `eval --json` stays accepted (no change); `claims --question … --json` → usage error rc 2; one `Store.exists` (ENOENT → false, else throw → rc 2) for presence guards in Cli + Store.ensureEntry + Session noTrace; `Receipt.resolve` unchanged (unresolvable artifact = missing ⇒ stale); per-commit gate = reached steps, engine stage skipped only when `engine.wasm` sha256 = base `5a773067…`, one full fast gate per batch.
- All fixers: fast gate runs direct (no offload slot); report in the primary `.agent/review/<name>.md`.
- general-purpose-3: grader fixes change what a check wrongly passes, never bounds/thresholds/expected values.
- Findings so far F1–F64 (+ reviewer-40-F1 Digest test chunk, reviewer-41-F1 smoke empty dir, reviewer-41-F2 circular projection oracle, reviewer-42-F1 engine panic oracle, reviewer-42-F2 palette Machado gamma, reviewer-37 G4/G8a/units leads, reviewer-46-F1 list rows click: pending harvest).
- Unassigned fix groups so far: F13 (user), F46–F55 + F63–F64 (cleanup/comments: new fixers after correctness merges), F57–F62 (README/help/docs: a docs fixer or MAIN).
