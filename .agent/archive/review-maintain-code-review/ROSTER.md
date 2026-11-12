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
| reviewer-43 | V-gate | 4 | harvested |
| reviewer-44 | F-model | 4 | harvested |
| reviewer-45 | F-cli | 4 | harvested |
| reviewer-46 | F-gui | 4 | harvested |
| general-purpose-1 | fixer: F4 F5 F6 F7 F8 F11 F12 F14 F15 F16 F17 F18 F20 F56 F72(lint) (wt/general-purpose-1) | fix | done (12 commits, merge pending) |
| general-purpose-2 | fixer: F24–F27 F37–F45 F72(gui) (wt/general-purpose-2) | fix | done (8 commits, merge pending) |
| general-purpose-3 | fixer: F3 F21–F23 F28 F29 F31–F34 F36 (wt/general-purpose-3) | fix | done (b86c6ed, review + split pending) |
| reviewer-47 | F-serve | 5 | harvested |
| reviewer-48 | L-template (L-T1..L-T23) | 5 | harvested |
| reviewer-49 | L-rules-a (ops lean deps renovate release examples) | 5 | harvested |
| reviewer-50 | L-rules-b (server wasm web fast) | 5 | harvested |
| general-purpose-4 | fixer: F30 F35 F71 TrustMain + trust.sh key (wt/general-purpose-4) | fix | done (merged) |

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

Session 2026-11-04 (resume after template refresh):
- consultant-1 (consultant, sol): rules V-mutation survivors A + B (M1–M37) → `.agent/review/consultant-1.md`, validator `rg -c '^\| M[0-9]+ \|.*\bunknown\b'` → 0, marker `consultant-1-DONE-1`. State: running.
- Campaign C: local heavy slot, `.scratch/mut-c` (48bc51d copy) `FvtraceWasm/{Build,Binary,Lock}` (43 + 59 + 25 mutants), FULLTEST `lake test` → `.scratch/review/main/mut/c.log`, per-file `.scratch/mut-c/mut-logs/`. State: running (bg shell).
- Update (late session): consultant-1 = rulings M1–M37 harvested (MAIN ruled; specified tests c5e08f3, 18/18 kills); asked (SendMessage) to rule M38–M60 (campaign C, FvtraceWasm/*) → marker `consultant-1-DONE-2`; its table has no `unknown` rows, its final message not yet received. Campaign C done (`.scratch/review/main/mut/c.log`). Focused mutation copy `.scratch/mut-d` (keep until close). CI: run for 0eb58ba (`.scratch/review/main/ci/wave-tools.log`, bg shell) then 5a42317 needs its own CI (`bash tools/ci-gate.sh <unit>` from `.scratch/ci-wt` after `git -C .scratch/ci-wt checkout --detach <sha>`). nixbox: B8 rerun + one counted B9 run still owed when `offload status` shows it idle; run from `.scratch/ci-wt` (CLAUDE.local.md: sync-back).
- CI 41874415356 (58b4c51): gate shards + linux ×2 + windows green, macOS no-runner flake (classified) → `gh run rerun --failed` watched into `.scratch/review/main/ci/wave-ci-rerun.log`; on green: append its macOS row to the ledger (`tools/gate-ledger.sh append`), `git push origin --delete ci/wave-ci`, ledger F52 → CI 41874415356; then CI for 428d789..HEAD from `.scratch/ci-wt`.
- CI run for 5a5b828 (F70 + checkpoints): `.scratch/review/main/ci/wave-f70.log` (started in background); on green → ledger F70 + F52 CI ids, delete ci/wave-ci after its macOS rerun.
| reviewer-51 | reviewer: closing diff a43d1c0..27158e4, every lens but security (`.agent/review/reviewer-51.md`, marker reviewer-51-DONE-1) | review | done (harvested: F78 F79 fixed a03414d; stopped) |

| reviewer-52 | reviewer: F81 fix diff 7ebf099..0ba494b, every lens but security (`.agent/review/reviewer-52.md`, marker reviewer-52-DONE-1) | review | harvested: 8/8 pass, 0 findings; register ruled (T1 hash = kernel.md § Receipts hashes recorded-verified records alone; R4 + R8 = scope notes) |
| reviewer-53 | reviewer: closing diff 0ba494b..85f9870 (F82 e438659, F83 3274786 + record commits), every lens but security (`.agent/review/reviewer-53.md`, marker reviewer-53-DONE-1; copy `.scratch/review/reviewer-53/tree` at 85f9870) | review | harvested: 7/7 rows; R1 R2 R4 R6 pass; F1 (R3 + R5) = F84 (MAIN: minor), F2 (R7) = F85; register: F83 A/B wording scoped |
| scientist-1 | scientist (opus lane): F86 diagnosis (`.scratch/b8g/diag-1.log`) + the first-view measurement options (`.agent/review/scientist-1.md`, marker scientist-1-DONE-1) | review | harvested: S1–S7; F86's cause = plausible, not identified (row narrowed); (b) recommended over warm-only (a) → the user's ruling (b) |
| scientist-1 (2) | scientist (opus lane, revived): F87 appraisal = B8 red at fb7490b (`experiments gui:page:whatif` 2.51, host-state lead) + fix options interleave / thermal settle / host record (`.agent/review/scientist-1-f87.md`, marker scientist-1-DONE-2) | review | harvested: T1 overstated (cause open; F87 row narrowed), T2 open, T3 + T5 supported, T4 unsupported, T6 = (a) + (c) telemetry-only, T7 no discard rule; stopped |
| scientist-2 | scientist (opus lane; scientist-1 unreachable after the session restart): F88 appraisal = B8 red at 1738cbf (`deep gui:served:details` 2.70, fast half-size outlier) + growth-check options (interleave, medians, more runs, paired ratios, GUI rows on absolute bounds) (`.agent/review/scientist-2-f88.md`, marker scientist-2-DONE-1) | review | harvested: T1–T6; T1 overstated (F88 row qualified), T2 unsupported, T3 overstated, T4 open, T5 supported = paired growth (median of 3 pair ratios) + fastest of 3 for absolute times, T6 open (lead: mismatched host windows); interim corrections taken (3 completed runs + 1 partial; host-log wording); numbers rematched by MAIN (F88 ratios, medians' displaced reds, per-session foreign load) |

Running: none. scientist-2 revived for F89 + the next-step options → `.agent/review/scientist-2-f89.md` (marker `scientist-2-DONE-2`; 7/7 ruled), harvested + stopped; helpers `.scratch/b8g/{sess,pooled}.py`. Background: none (B8 at a15ddfc done: `.scratch/bench/b8l/b8g-1.log` rc 1 = F89; B8 at 1738cbf: `.scratch/bench/b8k/b8g-1.log` rc 1 = F88; b8i stopped by the low-memory reaper, b8j never held a slot; the session now runs with `CLAUDE_CODE_DISABLE_BG_SHELL_PRESSURE_REAP=1`). B8 = `B8G_OUT=.scratch/bench/<new dir> bash .scratch/bench/b8g.sh <sha>` → `<dir>/b8g.txt`, `<dir>/b8g-<n>.log` (ends `b8g rc=N`; served first-view phases, host log, the F86 confirmation after `scale.sh`); red witnesses: `.scratch/bench/b8g-1.log` (F86), `b8h/b8g-1.log` (F87), `b8k/b8g-1.log` (F88); earlier runs `b8f1*`, `b8f2*`, `b8r*`, `b8.log`; GUI ratio table `python3 .scratch/b8g/ratios.py <logs>`.
