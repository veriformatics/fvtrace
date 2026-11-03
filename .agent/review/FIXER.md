# Fixer brief (shared) — fixes for the MAINTAIN code review of fvTrace

Intent: fix confirmed review findings at their root cause, sweep each defect class, prove each fix red → green. MAIN (the lead) reviews every commit, runs the full gate, merges. Findings = `/home/eturkes/Projects/fvtrace/.agent/review.md` § Findings (id, `file:line` at `48bc51d`, proof command, acceptance); reviewer details = `/home/eturkes/Projects/fvtrace/.agent/review/reviewer-<n>.md` (the proof scripts sit under `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-<n>/`).

## Law (read first)

`CLAUDE.md` (Engineering: code diff lenses, verification integrity, comments = why), `.claude/rules/*.md` (the ones matching your files), `.agent/spec.md` (`Decisions` bind), `.agent/contracts/kernel.md`. A fix that would change `Intent`, `Decisions`, a test's expected value or any grading check (threshold, bound, gate stage, probe) → stop on that item, write it under "Needs MAIN" in your report, continue with the rest.

## Workspace

- Your worktree: `git -C /home/eturkes/Projects/fvtrace worktree add -b wt/<name> /home/eturkes/Projects/fvtrace/.scratch/worktrees/<name> <base sha MAIN gives>`; then inside it: `cp -a --reflink=auto /home/eturkes/Projects/fvtrace/.lake /home/eturkes/Projects/fvtrace/.tools .` and `pnpm install --frozen-lockfile`. Build incrementally there (`nice -n 10 lake build`); run commands by absolute path or `(cd <worktree> && …)`.
- Write only inside your worktree, `/home/eturkes/Projects/fvtrace/.scratch/fix/<name>/` (logs, red outputs) + your report `/home/eturkes/Projects/fvtrace/.agent/review/<name>.md` (primary tree, unstaged; never inside the worktree, where it would enter a commit). The primary tree, the frozen base `.scratch/review-base` and other worktrees stay untouched. No push, no branch other than yours, no stash.
- Every `fvtrace` run sets `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/fix/<name>/home`; `serve` with `--port 0 --no-browser`, each server killed by PID.

## Per defect class (one commit each, on `wt/<name>`)

1. Red: a test in the repo's own suites (`Tests/*.lean` wired into `Tests.pure`/`Tests.native`, `tests/cli/smoke.sh`, `tests/e2e/*.spec.js`, `tests/engine/`, `tests/schema/`, or a `tools/gate-probe.sh` probe for a gate tool) that fails on the unfixed code: run it, keep its failing output.
2. Fix at the root cause; then sweep the repo for the same defect class (`rg`) and fix every instance.
3. Green: the red test passes; the fast gate passes (`bash tools/fast-gate.sh`, plus `--e2e` when you touched `web/` or the server); for a gate tool, `bash tools/gate-probe.sh <its probes>`.
4. Commit: subject `<scope>: <cause> → <fix>`; body = finding ids, the red command + its failing output (revision = your branch's parent), the green command + result, the sweep (`rg` command + what it found). A test that pins behavior already passing records why it cannot be red. Code comments = the why alone; match the surrounding code's style.
5. A Lean file that a proof names: keep every proof + `fvtrace-trust` green (`lake build` + `.lake/build/bin/fvtrace-trust`).
6. Self-trace receipts (`examples/fvtrace/trace.json`) go stale when you edit a file it pins: re-pin per `.claude/rules/examples.md` (`.lake/build/bin/fvtrace pin --trace examples/fvtrace/trace.json --project .`, and `pin --replay` when a Spec statement's closure changed) in the same commit.

## Report

`/home/eturkes/Projects/fvtrace/.agent/review/<name>.md`: one row per finding id given to you: `| id | commit sha | red command → output (short) | green command → result | sweep | status |` (status = fixed · needs MAIN · retired-with-reason). Seed every row `unknown` first. Last line: your marker `<name>-DONE-1`. Mid-run directives: `/home/eturkes/Projects/fvtrace/.agent/review/LEAD-DIRECTIVES.txt` (re-read after each commit).
