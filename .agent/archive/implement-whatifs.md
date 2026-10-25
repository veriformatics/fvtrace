# IMPLEMENT — what-ifs by reference (deferred row 8), closed

Routed request (user): v1 envelopes were output-quadratic (one experiment with n outcomes gave every claim's plan action the complete n-entry what-if: `tools/scale.mjs outcomes` 2,000 → 311 MB, 1.8 GiB RSS; prerequisite chains the same through closures). Ruling: references, linear at any size, its own IMPLEMENT session. Acceptance as amended by the user's rulings (Response time, Memory, Prerequisite chains, GUI responsiveness, Capability first): kernel.md P-bound (P-time ≤ 10 s at N_cap per row, ≤ 2.5× per doubling; P-memory; P-bytes ≤ 2.2×), U-time, compare.sh byte equality, every v1 one-click what-if + experiment detail still shown served + exported.

| unit | commits | what landed |
|---|---|---|
| U1 contract | 01cf228 | kernel.md V-*, P-*, E-*, U-*; units table; consultant-7 |
| U2 call depth | c5e0ee5 | the page engine past 9,600 claims (no `List.zip` recursion) |
| U3 reference paths | 7963d7c | `--action`, `--details`, `eval --complete`, `POST /api/answer`, page engine `load` + `answer` |
| U4 GUI on references | 511281b, 87a3640 | details on selection, actions by reference; exported engine in a Worker |
| U5 cutover | c3ab522, a80a229, b55c7d6, 21148b8 | envelope v2, export v3; v1 entries retired; compare.sh v1 → v2 transform + oracles |
| U6 cache + state | bc53e1c, d2369f6, 6ef4b4a | server cache (trace by bytes, answers by view), page engine keeps the last answer |
| U7 compute | 4f82d44, e95e7fa, 6d4090c, 4c5da70, f2b5bb5, 96f80ba, 191121e, 1d65c23, 7c536ee | proved forest walk (rows, plan summaries, raisers: `Spec.AnswersAgree`), shared-path speed, diff-blind differential (tester-1: 1,001,225 comparisons), page engine + serve speed (Json bulk copy, mimalloc, kept envelope text) |
| U8 GUI responsiveness | 28ed727, 7bdd7e4 | lookups once per envelope, keyed lazy lists, selection without rebuild, one evaluation in flight, busy sign past 1 s, find route, page v4 (snapshot block, engine starts first), `tools/scale-gui.mjs` |
| U9 scale tools | fd3f928, 5dc7c4c, 21ca742, 3078b46, ba50695 (+ review fixes) | `tools/scale.sh` rows: CLI, text commands, serve, page engine (`tools/scale-page.mjs`), GUI; RSS + bytes ratios, the RSS cap; probes |
| U10 docs | b394f17, f3bc87f, 60a917d | README, skill, SECURITY.md, rules (fast, ops, web), Decisions |
| U11 closing review | 174c7a2, 3bd3495, c930c8c, 5884f91 | 22 check rows (R1–R5 reviewer-1..5, S MAIN), 28 findings, 15 survivor rulings (J1–J10, K1–K5), one re-review round: `review-implement-whatifs.md` |

Measurements (author's; loaded host unless named): wide 2,000 GUI v1 = 3.3 s load, 3.2 s per what-if, 2.85 s per selection, 5,000 = 2.2 GiB heap + tab crash → 0.24 s, 0.21 s, 0.027 s; wide cap 46,081: served first view 8.5 s, select 0.03 s, details 0.5 s, what-if 4.5 s; exported first view 1.9 s, start-up click 7.5 s (11.6 s before page v4). Page engine load at the wide cap: 30.3 G → 21.8 G instructions (Json bulk copy + mimalloc).

Idle acceptance on the reference host (U9, `tools/scale.sh --assert`): see the closing commit's body.
