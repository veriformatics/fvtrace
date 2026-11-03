# Roster (MAIN; survives compaction)

Base = `.scratch/review-base` (worktree, detached 48bc51d, built). Deliverable = `.agent/review/<name>.md`, marker `<name>-DONE-1`.

| name | rows | wave | state |
|---|---|---|---|
| reviewer-1 | C-codec (A) | 1 | running |
| reviewer-2 | C-codec (B) | 1 | harvested |
| reviewer-3 | C-check (A) | 1 | harvested |
| reviewer-4 | C-check (B) | 1 | harvested |
| reviewer-5 | C-engine (A) | 1 | harvested |
| reviewer-6 | C-engine (B) | 1 | harvested |
| reviewer-7 | C-fast (A) | 1 | harvested |
| reviewer-8 | C-fast (B) | 1 | harvested |
| reviewer-9 | C-receipt (A) | 1 | harvested |
| reviewer-10 | C-receipt (B) | 1 | harvested |
| reviewer-11 | C-eval (A) | 1 | harvested |
| reviewer-12 | C-eval (B) | 1 | harvested |
| reviewer-13 | C-cli (A) | 2 | running |
| reviewer-14 | C-cli (B) | 2 | running |
| reviewer-15 | C-server (A) | 2 | running |
| reviewer-16 | C-server (B) | 2 | running |
| reviewer-17 | C-gui-a | 2 | running |
| reviewer-18 | C-gui-b | 2 | running |
| reviewer-19 | C-scale | 2 | running |
| reviewer-20 | C-export (A) | 2 | running |
| reviewer-21 | C-export (B) | 2 | running |
| reviewer-22 | C-gate (A) | 2 | running |
| reviewer-23 | C-gate (B) | 2 | running |
| reviewer-24 | C-release (A) | 2 | running |
| reviewer-25 | C-release (B) | 2 | running |

Row state: C-eval pass · C-fast pass · C-engine F1 · C-receipt F4 F5 F8 · C-check: reviewer-3 F6 (reviewer-4 pending) · C-codec: F7 (reviewer-1, reviewer-2 pending).

Background: mut-time-json (Json:128 timing, `.scratch/mut-time`, log `.scratch/mut-time-json.log`).
Baseline notes: `.agent/review/baseline.md`.

Background jobs (MAIN):
- B2 probes: `offload run` (local slot 2, primary tree!) → `.scratch/review/main/b2-probe.log`; keep the primary tree untouched until it ends.
- mut-time-json: `.scratch/mut-time` Json:128 timing → `.scratch/mut-time-json.log`.
- V-mutation A: `.scratch/mut-a` (own git) `offload run --pool` campaign Cli → `.scratch/review/main/mut/a.log`, per-file logs `.scratch/mut-a/mut-logs/` (host copy: fetch with `--get mut-logs` or read a.log).
- V-mutation B: `.scratch/mut-b` 13 shell files → `.scratch/review/main/mut/b.log`.
- V-mutation C (pending): `.scratch/mut-c` FvtraceWasm/{Build,Binary,Lock}.
