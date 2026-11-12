# reviewer-27 — K-engine + K-fast at `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| K-engine | Cleanup: Engine + Present + tests | reviewer-27-F1, reviewer-27-F7 | Full Cleanup pass: Engine, Present, Tests/Engine + Details; duplicate lexicographic recursion + shared test fixture helpers. |
| K-engine | Cleanup: unused lemmas (Proofs/Engine, Plan, Closure) + Spec/Engine | pass | 144 theorem/lemma declarations searched across all 92 `.lean` files; 17 unreferenced names directly prove Spec claims, dynamically consumed by TrustMain; no unused helper. Spec/Engine read in full. |
| K-engine | Altitude | pass | Separate Altitude pass: pure scenario + presentation mechanisms, parser shared by surfaces; no caller-specific infrastructure branch found. |
| K-fast | Cleanup: Answers + Answers/* + Lookups + Index + PTree + tests | reviewer-27-F3, reviewer-27-F4, reviewer-27-F5, reviewer-27-F6 | Full Cleanup pass + caller inventory: duplicate delta queries, redundant memo verdict computation, per-subject rescans, duplicated StepOut state; caches/indexes preserved per fast.md. |
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

## reviewer-27-F3 — delta helpers reimplemented in the forest layer

- Severity: minor. Targets: `Fvtrace/Answers/Delta.lean:447–448`, `:562–563`; counterparts `Fvtrace/Answers/Forest.lean:217–218`, `:276–278`.
- Contract: `CLAUDE.md` Engineering / Cleanup: existing helpers reused; near-duplicate blocks merged.
- Why: `movesUnder` builds `subjects` with the exact body of `touchedSubjects`; `planOf` computes `relPos` with the exact body of `relevantPositions` after renaming `needsAll` → `needs`, `c.subject` → `subject`. The helper implementations sit in the importer rather than the shared lower module, so the two consumers maintain separate copies of each query.
- Anchors: Delta `let subjects := Index.eraseDups compare (δ.touched.filterMap fun p =>` (:447), `let relPos := (raisingPositions cx core needsAll).filter fun p =>` (:562); Forest `def touchedSubjects (cx : Ctx) (δ : Delta)` (:217), `def relevantPositions (cx : Ctx) (core : Core)` (:276). `rg -Fn` matches each once in its named base file.
- Proof command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-27/duplicates.py` rc 0 → `touchedSubjects: same body in Delta.movesUnder and Forest helper`; `relevantPositions: same body in Delta.planOf after needsAll/subject substitutions`.
- Fix: put both helpers in Delta before their first consumer, call them from both layers; update proofs that unfold the former let blocks. Preserve the distinct validity predicates in `movesUnder` versus forest `movable` (a node adapter's `activeCount` is not its base `conflicts`).

## reviewer-27-F4 — memo initialization repeats its already-computed verdict inputs

- Severity: minor. Target: `Fvtrace/Answers/Delta.lean:366–371`; consumer: Fast :43.
- Contract: `CLAUDE.md` Engineering / Cleanup: startup + hot paths lean; helpers reused. `fast.md` Cost traps: a claim's needs computed once.
- Why: `ClaimMemo.of` computes `needs`, `Counts.of … needs`, and `incompatible`, then calls `Core.final … c` to obtain `final`. That call runs `Core.intrinsic` (:204–209): another needs/status scan + another incompatibility query, although `Counts.state` already decides that intrinsic state from the memo fields. This is repeated computation, not a request to remove the measured needs/count caches.
- Anchors: `counts := Counts.of core.eff (Core.restsOn cx core) needs` (:369), `final := Core.final cx s core c` (:371); both match by `rg -Fn` in base Delta. `Core.intrinsic`'s body is at :204–209; `Counts.state` at :230–234.
- Proof: `(cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-27/memo-final.lean)` rc 0. Its first theorem proves, for arbitrary `cx`, `s`, `core`, `c`, that the current memo's final = `if core.valid c.subject then m.counts.state m.incompatible else .cannot`, via existing `counts_state`.
- Fix: let-bind the counts + incompatibility once; derive final through `Counts.state` + the validity guard. Adapt `memo_base_final`/related agreement proofs; preserve outputs. No timing gain measured or claimed.

## reviewer-27-F5 — shifts scan the full touched set once per subject

- Severity: minor. Target: `Fvtrace/Answers/Delta.lean:297–302`; caller: Delta.build :317.
- Contract: `CLAUDE.md` Engineering / Cleanup: startup + hot paths lean; existing helpers reused.
- Why: `Shifts.of` finds distinct subjects, then `subjects.map` runs `xs.filter (·.subject == sub)` per subject. For `n` touched exclusions on `n` distinct subjects it performs `n²` subject comparisons to emit `n` count pairs. Those exclusions can be grouped once by their existing indexed-position mechanism (`Index.ofKeys` + `group`), as the surrounding fast engine already does. The current value is correct; the redundant full scans are the K defect (no universal response-time breach claimed).
- Anchors: `let subjects := Index.eraseDups compare (xs.map (·.subject))` (:298), `let ys := xs.filter (·.subject == sub)` (:301). `rg -Fn` matches each once in base Delta. The enclosing :297–302 shows the filter nested under `subjects.map`; Index :28/:78 provides the grouping mechanism; Core uses it at Delta :169–171.
- Fix: group/accumulate per-subject before/after counts once; retain first-subject order + Shifts.at's `(0, 0)` default, and re-establish the Shifts agreement proof. No benchmark run or speedup claimed.

## reviewer-27-F6 — StepOut stores a second copy of its node's row

- Severity: minor. Target: `Fvtrace/Answers/Forest.lean:181–188`, construction :261–272, sole implementation consumer :346–348.
- Contract: `CLAUDE.md` Engineering / Cleanup: derivable state computed, never duplicated.
- Why: StepOut stores lights/clears/lowers/contingent and `applied`, while its `node` stores those same four values + `bad`, from which `applied = (bad == 0)`. Node.step fills both copies from the same lets; walkStep reads the redundant top-level copy. This adds five representational invariants to the result record without distinct semantics.
- Anchors: `structure StepOut where` (:181), `lights, clears, lowers, bad := merge.2, contingent` (:272); `rg -Fn` matches each once in base Forest. `rg -n -e '\bStepOut\b' -e 'out\.(lights|clears|lowers|applied|contingent)' …/review-base --glob '*.lean'` finds the type, Node.step + walkStep alone; Walk proofs also unfold Node.step.
- Proof: the second theorem in `memo-final.lean` proves all five equalities by `rfl` for arbitrary Node.step arguments; command above rc 0. Bounded inspection of generated Forest C (:3778–3951) also confirms that Node.step eagerly builds both node + StepOut; the copied scalars do not currently defer node construction.
- Fix: StepOut keeps answers + node; derive row fields from node (including `bad == 0`); update walk proof projections. Preserve any future leaf-node allocation optimization as a separate, measured change.

## reviewer-27-F7 — identical test fixture helpers spread across suites

- Severity: minor. Target: `Tests/Engine.lean:7–13`; counterparts Check :7–10/:18–19, Receipt :7–13, CliStore :11–14.
- Contract: `CLAUDE.md` Engineering / Cleanup: helpers reused; near-duplicate blocks merged.
- Why: Engine.fixture's four-line body = Check.fixture = Receipt.fixture = CliStore.decoded byte for byte; Engine.mapFact's body = Check.mapFact = Receipt.mapFact. These are shared fixture-loading/mutation mechanisms, not independent oracles; each suite currently carries its own copy.
- Anchors: `def fixture : IO Trace := do` (:7), `def mapFact (t : Trace) (id : String) (f : Fact → Fact) : Trace :=` (:12); `rg -Fn` matches each once in base Tests/Engine. `rg -n -F 'fixture does not decode:' …/review-base/Tests --glob '*.lean'` identifies all four loaders.
- Proof command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-27/duplicates.py` rc 0 → each loader + mapFact body comparison equal (five comparisons). Existing test utilities searched in Tests/Harness + all Tests files; Snapshot.traceOf is related but has a different failure message, so substituting it directly is not behavior-preserving.
- Fix: one test-fixture module owns this loader + mapFact; share it across suites while keeping exact success/error behavior (especially the decode diagnostic).

## Coverage + checks

- All implementation + test files named in the brief read in full; `Spec/Engine` + `Spec/Fast` read in full. Two implementation passes, Cleanup then Altitude. Proof bodies: unused-lemma pass alone, as scoped; 504 named declarations (Engine slice 144, Fast slice 360), all 92 project `.lean` files indexed, TrustMain included. Generated Lean dependency trees under `.lake` are outside that source search; compiled proof-reference scan is supplemental, not the source deadness oracle.
- `defs.py` → 263 implementation/test definitions searched, no zero-reference candidate after exact Lean-identifier handling; recursive helpers' consumers checked in the full read. `duplicates.py` rc 0; `memo-final.lean` rc 0 (two all-input equivalences); `proof-refs.lean` rc 0. No source edit, binary rebuild, full gate, mutation campaign or performance benchmark run. No timing-improvement claim. No fvtrace/server process started.
- Lean LSP probe on Engine → `No LSP server available for file type: .lean`; manual source/caller search + compiled Lean checks used instead. No unconfirmed finding remains.
- Register: none. Security analysis excluded.

reviewer-27-DONE-1
