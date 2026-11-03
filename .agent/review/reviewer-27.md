# reviewer-27 — K-engine + K-fast at `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| K-engine | Cleanup: Engine + Present + tests | reviewer-27-F1, reviewer-27-F7 | Full Cleanup pass: Engine, Present, Tests/Engine + Details; duplicate lexicographic recursion + shared test fixture helpers. |
| K-engine | Cleanup: unused lemmas (Proofs/Engine, Plan, Closure) + Spec/Engine | pass | 144 theorem/lemma declarations searched across all 92 `.lean` files; 17 unreferenced names directly prove Spec claims, dynamically consumed by TrustMain; no unused helper. Spec/Engine read in full. |
| K-engine | Altitude | pass | Separate Altitude pass: pure scenario + presentation mechanisms, parser shared by surfaces; no caller-specific infrastructure branch found. |
| K-fast | Cleanup: Answers + Answers/* + Lookups + Index + PTree + tests | unknown | unknown |
| K-fast | Cleanup: unused lemmas (Proofs/Answers, Walk, Forest, Agree, PTree, Index, Lookups, Positions, Singleton) | reviewer-27-F2 | 360 declarations searched across all 92 `.lean` files + non-Lean target trees; three non-simp helpers lack any external caller; registered simp lemmas have reachable explicit simp calls. |
| K-fast | Altitude | pass | Separate pass over every implementation + test: forest/dense/position guards follow full-domain + performance contracts, not one caller's quirk; Node.core's four-field delta adapter checked against its callers; generic Index/PTree remain caller-independent. |

## Scope

Target = `/home/eturkes/Projects/fvtrace/.scratch/review-base` (`48bc51d`). Check set = K Cleanup + Altitude, two separate passes per implementation slice. Proof-body review = unused-lemma pass alone. Findings preserve behavior; correctness observations outside K → Register. Read-only target; own scratch + this validator input writable.

## reviewer-27-F1 — duplicate lexicographic recursion

- Severity: minor. Target: `Fvtrace/Engine.lean:281` (`lexLt` at :275; full blocks :275–285).
- Contract: `CLAUDE.md` Engineering / Cleanup: near-duplicate blocks merged; existing helpers reused.
- Why: `idsLt` duplicates all four branches of `lexLt`; only the element type + recursive name differ. Both implement the same lexicographic mechanism, not separate reference/fast algorithms.
- Anchor command: `rg -Fn -e 'def lexLt : List Nat → List Nat → Bool' -e 'def idsLt : List String → List String → Bool' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Engine.lean` → :275 + :281, rc 0.
- Proof: normalize `Nat`/`String` → `T`, `lexLt`/`idsLt` → `LEX` in the two blocks → byte-equal (`same body after Nat/String + lexLt/idsLt substitution: True`). Callers found in `Scenario.planBetter`, `Scenario.skips`, `Answers.searchWith`; no generic project helper found by `rg -n -e 'compareLex|lexLt|idsLt|lexicograph|Lexicograph' …/Fvtrace --glob '*.lean'`.
- Fix: one element-polymorphic comparator, keeping wrappers if useful; re-establish Plan + Singleton proofs that unfold these definitions. This is a proof-affecting cleanup, not a verdict change.

## reviewer-27-F2 — three unused proof helpers

- Severity: minor. Contract: `CLAUDE.md` Engineering / Cleanup: dead code removed; K explicitly includes unused lemmas.
- Targets + exact anchors:
  - `Fvtrace/Proofs/Answers.lean:900`: `theorem coreSpec : CoreSpec s (coreOf s) :=` — declaration alone.
  - `Fvtrace/Proofs/Forest.lean:35`: `theorem reaches_le {A : Array (Option Nat)}` — declaration alone.
  - `Fvtrace/Proofs/Positions.lean:59`: `theorem mem_dedupRef : ∀ {l : List Nat}` — declaration + its two recursive self-calls (:65, :68), no external caller.
- Command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-27/unused.py` → inventory `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-27/lemmas.json`; 504 declarations, all 92 project `.lean` files (TrustMain included), 22 without an external textual reference. Nineteen directly prove Spec claims and are dynamically consumed by `TrustMain.audit` (:90–103); the three above neither prove such a claim nor register `simp` rules. Exact proof-file names + each match retained in the JSON. `unused.log` retains the command's compact output (rc 0).
- Rematch: `rg -n -w 'coreSpec|reaches_le|mem_dedupRef' /home/eturkes/Projects/fvtrace/.scratch/review-base --glob '*.lean'` → the five lines above, rc 0. Same search over non-Lean target trees (`--hidden --glob '!.git' --glob '!*.lean'`) → no match, rc 1; positive controls = one declaration per name (expected count 1 each).
- Supplemental compiled check: `(cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-27/proof-refs.lean)` rc 0 → all three fully qualified names lack incoming references in imported Fvtrace + Tests constants (types + opaque theorem values). Generated equation lemmas + simp-only references in that output are not findings.
- Simp ruling: `ctx_*` (six), `ref_*` (17), `thunk_get_mk` have explicit reachable simp uses: Answers :403/:445/:480/:499/:1445, Check's `ref_simp` :13–16 used at :207/:216/:240/:291/:300, Lookups :267 + Answers :1045/:1197. None of the three candidates has a simp attribute.
- Fix: remove the three helper declarations; retain every Spec proof + its upstream dependencies. Proof removals stale the self-trace's receipts, so follow the existing re-pin law.
