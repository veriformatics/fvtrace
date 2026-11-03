# Roster (MAIN; survives compaction)

Base = `.scratch/review-base` (worktree, detached 48bc51d, built). Deliverable = `.agent/review/<name>.md`, marker `<name>-DONE-1`.

| name | rows | wave | state |
|---|---|---|---|
| reviewer-1 | C-codec (A) | 1 | harvested |
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
| reviewer-13 | C-cli (A) | 2 | harvested |
| reviewer-14 | C-cli (B) | 2 | harvested |
| reviewer-15 | C-server (A) | 2 | harvested |
| reviewer-16 | C-server (B) | 2 | harvested |
| reviewer-17 | C-gui-a | 2 | harvested |
| reviewer-18 | C-gui-b | 2 | harvested |
| reviewer-19 | C-scale | 2 | harvested |
| reviewer-20 | C-export (A) | 2 | harvested |
| reviewer-21 | C-export (B) | 2 | harvested |
| reviewer-22 | C-gate (A) | 2 | harvested |
| reviewer-23 | C-gate (B) | 2 | harvested |
| reviewer-24 | C-release (A) | 2 | harvested |
| reviewer-25 | C-release (B) | 2 | harvested |
| reviewer-26 | K-codec + K-check | 3 | harvested |
| reviewer-27 | K-engine + K-fast | 3 | harvested |
| reviewer-28 | K-receipt + K-eval | 3 | harvested |
| reviewer-29 | K-cli | 3 | harvested |
| reviewer-30 | K-server + K-export | 3 | harvested |
| reviewer-31 | K-gui-a | 3 | harvested |
| reviewer-32 | K-gui-b | 3 | harvested |
| reviewer-33 | K-gate | 3 | harvested |
| reviewer-34 | K-scale + K-release | 3 | harvested |
| reviewer-35 | S-readme | 4 | harvested |
| reviewer-36 | S-skill | 4 | harvested |
| reviewer-37 | S-spec | 4 | harvested |
| reviewer-38 | S-comments-lean | 4 | harvested |
| reviewer-39 | S-comments-other | 4 | harvested |
| reviewer-40 | V-lean-kernel | 4 | harvested |
| reviewer-41 | V-lean-shell | 4 | harvested |
| reviewer-42 | V-js | 4 | harvested |
| reviewer-43 | V-gate | 4 | running |
| reviewer-44 | F-model | 4 | harvested |
| reviewer-45 | F-cli | 4 | harvested |
| reviewer-46 | F-gui | 4 | running |
| general-purpose-1 | fixer: F4 F5 F6 F7 F8 F11 F12 F14 F15 F16 F17 F18 F20 F56 (wt/general-purpose-1) | fix | running |
| general-purpose-2 | fixer: F24–F27 F37–F45 (wt/general-purpose-2) | fix | running |
| general-purpose-3 | fixer: F3 F21–F23 F28 F29 F31–F34 F36 (wt/general-purpose-3) | fix | running |
| reviewer-47 | F-serve | 5 | running |
| reviewer-48 | L-template (L-T1..L-T23) | 5 | harvested |
| reviewer-49 | L-rules-a (ops lean deps renovate release examples) | 5 | running |
| reviewer-50 | L-rules-b (server wasm web fast) | 5 | running |
| general-purpose-4 | fixer: F30 F35 TrustMain (wt/general-purpose-4) | fix | running |

Row state: C-eval pass · C-fast pass · C-engine F1 · C-receipt F4 F5 F8 · C-check: reviewer-3 F6 (reviewer-4 pending) · C-codec: F7 (reviewer-1, reviewer-2 pending).

Background: mut-time-json (Json:128 timing, `.scratch/mut-time`, log `.scratch/mut-time-json.log`).
Baseline notes: `.agent/review/baseline.md`.

Background jobs (MAIN):
- B2 probes: `offload run` (local slot 2, primary tree!) → `.scratch/review/main/b2-probe.log`; keep the primary tree untouched until it ends.
- mut-time-json: `.scratch/mut-time` Json:128 timing → `.scratch/mut-time-json.log`.
- V-mutation A: `.scratch/mut-a` (own git) `offload run --pool` campaign Cli → `.scratch/review/main/mut/a.log`, per-file logs `.scratch/mut-a/mut-logs/` (host copy: fetch with `--get mut-logs` or read a.log).
- V-mutation B: `.scratch/mut-b` 13 shell files → `.scratch/review/main/mut/b.log`.
- V-mutation C (pending): `.scratch/mut-c` FvtraceWasm/{Build,Binary,Lock}.

Pending: K-* fixes (F46–F52, F54, F55) after correctness merges. Needs user: F13 test expectation; Worker silence deadline (E-abi vs Capability first); per-command --help (register).
