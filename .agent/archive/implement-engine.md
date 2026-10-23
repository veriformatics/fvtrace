# IMPLEMENT — engine speed-up (security review F5) (closed)

> Full fast engine, but let's end this session, and begin it in an IMPLEMENT session next session

Routed from MAINTAIN — whole product (security review F5: valid traces cost super-linear time). Acceptance = the F5 ledger row, fixed before code. Contract = `.agent/contracts/kernel.md` § Performance (P-*); units = `.agent/contracts/units.md` (IMPLEMENT — engine speed-up).

| unit | commit | outcome |
|---|---|---|
| U1 contract + tools | a782e4e | P-bound … P-evidence; `tools/scale.mjs` (5 graded/hub + 7 supplemental shapes), `tools/scale.sh --assert`, `tools/compare.sh`, probes `scale` + `compare`; consultant-6 on the contract before code |
| U2–U5 index, lookups, answers, scale tests, docs, self-trace | fa7f307 | `Fvtrace.Index`, `Fvtrace.Lookups` + `Fvtrace.Answers` (reference + fast), proved: `LookupsAgree`, `SortMembersAgree`, `AnswersAgree` (every scenario); closures by a level walk over one array of marks (`Proofs/Closure`); Tests/Scale red at af5a2f1 (rc 124 at 900 s); tester-1 differential suite; self-trace C9 (P10–P12) |
| U6 closing review | 4e8eefa (check set) · 84da642 (fixes) · 2835138 (re-review fix) | R1–R5 one reviewer each + S (MAIN); 10 findings: 9 fixed, R3-F2 disposed (evidence scope narrowed); `.agent/review.md` § Closing review |

F5 acceptance (`tools/scale.sh --assert`, binary 90c61be0…, idle host, load 2.5–3.0), check / eval wall s at cap/2 → cap, ratio per doubling: wide 0.83 → 1.85 (2.23) · 3.83 → 7.88 (2.06); deep 0.82 → 1.69 (2.06) · 3.83 → 7.89 (2.06); experiments 0.80 → 1.64 (2.05) · 4.24 → 8.87 (2.09); exclusions 0.90 → 1.86 (2.07) · 2.89 → 6.10 (2.11); hub 0.92 → 1.91 (2.08) · 2.83 → 5.93 (2.10). Baselines (af5a2f1, 1k/2k/4k): wide eval 4.04/14.9/101 s, experiments + exclusions + hub eval past 900 s from 1k. Final binary 4d55e0ed (presentation dedupe after the review) A/B against 90c61be0 under load, eval at cap, 3 rounds: wide 16.40 vs 16.37 s user, experiments 18.53 vs 18.52 s user. `tools/compare.sh` af5a2f1 vs final: 798 runs, 0 differing outputs, 0 timeouts.

Found on the way: the fixed-point closure cost O(L² log L) per call on a prerequisite chain of L (supplemental shape `prereqs`, 1,200: 304–417 s) → per-experiment memo of level walks (9.3 s); output-quadratic envelopes (one experiment with n outcomes) stay as before → `.agent/deferred.md`.
