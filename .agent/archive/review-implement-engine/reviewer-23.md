# reviewer-23 — CLAUDE.md conformance

Target = `af5a2f1..fa7f307`; commit text also `4e8eefa`. Check set R5.1–R5.3 fixed before target read. Repository read-only; evidence files confined to this folder.

| id | asks | verdict | findings |
|---|---|---|---|
| R5.1 | comments state the why; agent-facing text dense; README in ASD-STE100 register | pass | - |
| R5.2 | dead code, duplicated helpers, special cases on shared infrastructure | finding | R5-F1, R5-F2 |
| R5.3 | changed rules: live law + why, correct `paths:`, no origin stories; spec shape + Artifacts + Tasks; commit subjects + bodies | finding | R5-F3, R5-F4 |

## R5-F1 — unused proof scaffolding

Severity = minor. `/home/eturkes/Projects/fvtrace/Fvtrace/Proofs/Answers.lean:226`, `:244`, `:983`, `:1321`.

Four new auxiliary lemmas have no consumer: `experimentIx_group`, `mem_zipIdx_pos`, `memo_at`, `applySuccess_after`. They are neither Spec claim proofs nor registered simp/other attributes. `memo_at` is also only a wrapper around `memo_get`. Keeping them adds proof elaboration + review surface without supporting a claim. Contract = R5.2 + CLAUDE.md Engineering: dead code removed, existing helpers reused.

Exact anchor bytes (`rg -Fn` matches the file + target revision):

```text
theorem experimentIx_group (id : String) :
theorem mem_zipIdx_pos {α : Type} {l : List α} {p : Nat} :
theorem memo_at (p : Nat) (hp : p < s.trace.claims.length) :
theorem applySuccess_after (ids : List String) :
```

Evidence: textual search across all tracked Lean files finds each name once, at its declaration. Positive control `delta_final` = 3 lines (declaration + `memo_final` + `node_final` uses). Compiled proof dependencies confirm this; command:

```sh
(cd /home/eturkes/Projects/fvtrace && lake env lean --run .scratch/reviewer-23/proof-users.lean)
```

rc 0; `/home/eturkes/Projects/fvtrace/.scratch/reviewer-23/proof-users.log`:

```text
Fvtrace.Proofs.Answers.delta_final: 2 users = [Fvtrace.Proofs.Answers.memo_final, Fvtrace.Proofs.Answers.node_final]
Fvtrace.Proofs.Answers.experimentIx_group: 0 users = []
Fvtrace.Proofs.Answers.mem_zipIdx_pos: 0 users = []
Fvtrace.Proofs.Answers.memo_at: 0 users = []
Fvtrace.Proofs.Answers.applySuccess_after: 0 users = []
```

Acceptance: remove these unused helpers; the agreement proof still kernel-checks. Structural finding, not a claimed runtime defect.

## R5-F2 — copied presentation assembly

Severity = minor. `/home/eturkes/Projects/fvtrace/Fvtrace/Answers/Fast.lean:629`, `:645–656`; `/home/eturkes/Projects/fvtrace/Fvtrace/Cli.lean:460`; counterpart `/home/eturkes/Projects/fvtrace/Fvtrace/Present.lean:32–68`.

The diff moves the reference presentation into `Present` but copies sentence/qualifier assembly into `Answers.fast`; creator-title traversal exists in `Scenario.creatorTitle`, `Cli.creatorTitle`, and the fast record's local closure. The indexed-vs-list computations must differ; these formatting rules and the two indexed creator-title traversals need not. A wording change now requires editing duplicated bodies + repairing the agreement proof instead of changing one presentation function. Contract = R5.2 + P-shared's presentation below both records + Engineering's helper reuse/deduplication.

Exact anchors:

```text
let creatorTitle := fun sub => do
def creatorTitle (L : Lookups) (subject : String) : Option String := do
sentence := fun c =>
qualifiers := fun c review =>
(match review with | .draft => ["draft"] | .stale => ["stale review"] | .reviewed => []) ++
```

The last line matches both `Present.lean:65` and `Answers/Fast.lean:652` (rc 0). `rg -n 'creatorTitle|sentenceParts|def qualifiers|sentence :=|qualifiers :=' Fvtrace Tests` identifies all callers + duplicated bodies; enclosing functions read. Current equality is proved; no output mismatch asserted.

Acceptance: one formatter for each sentence/qualifier rule + one creator-title helper over lookups, used by reference/fast/CLI as applicable; agreement proof + output parity unchanged.

## R5-F3 — fast-path law misses files it governs

Severity = minor. `/home/eturkes/Projects/fvtrace/.claude/rules/fast.md:2–16`.

`paths:` covers the new index/answer/proof modules + benchmark scripts, but excludes the fast-path shell and mirrored definitions. The same rule explicitly governs `Receipt.BindingIndex` and changes to `Scenario`/`Check`; opening only their files does not load it. A future shell-only edit can miss the index-lifetime constraint and required parity/timing evidence. Contract = R5.3 + Authoring: area-bound law reaches the files that need it.

Exact anchors:

```text
  - "Fvtrace/Answers/**"
  - "tools/compare.sh"
```

Rule-body anchors:

```text
A change to a fast path or to a `Scenario` / `Check` definition it mirrors keeps those proofs
carry the index in a structure (`Receipt.BindingIndex`) or pass it in
```

Scope inspection: all 14 frontmatter entries read; all quoted. Node `path.matchesGlob` positive control `Fvtrace/Answers/Fast.lean` = true; each of `Fvtrace/Receipt/Basic.lean`, `Fvtrace/Engine.lean`, `Fvtrace/Check.lean`, `Fvtrace/Json.lean`, `Fvtrace/Cli.lean`, `Fvtrace/Receipt.lean`, `Fvtrace/Replay.lean`, `Fvtrace/Session.lean`, `Fvtrace/Snapshot.lean`, `Fvtrace/Evaluate.lean`, `Fvtrace/Lint.lean`, `Fvtrace/Export.lean` = false; rc 0. These patterns are exact names / `/**`, so no advanced glob interpretation is involved.

Acceptance: scope this law to its mirrored definitions and P-shell consumers, at minimum the explicitly named `Engine`, `Check`, and `Receipt/Basic` files; keep unrelated files outside it.

## R5-F4 — implementation history in live law

Severity = minor. `/home/eturkes/Projects/fvtrace/.claude/rules/fast.md:24`.

Exact bytes:

```text
as the fixed-point closure was on prerequisite chains
```

`rg -Fn` = line 24, rc 0. This describes a superseded implementation, not a current rule or its remaining reason; the same history + measurements already live in `fa7f307`'s body. R5.3 expressly requires no origin stories; CLAUDE.md Authoring routes them to the commit body. The preceding output-vs-scan rule carries the actionable constraint without this clause.

Acceptance: remove the historical clause; preserve the output-growth rule + why it matters.

## Coverage + checks

- Read every named target text: new implementation/Spec/proof modules; Tests/Scale + Differential; scale/compare scripts; README; spec + units; all nine `.claude/rules/` files; commit subjects + bodies of a782e4e, fa7f307, 4e8eefa. Read the remaining source/tool diffs for R5.2. Dead-declaration heuristic = 383 plain `def`/`abbrev`/`theorem` declarations in added Lean files, references searched across all tracked Lean sources, no result cap. Attributed declarations were read, not included in that single-occurrence heuristic. Compiled dependency scan = the prebuilt `Fvtrace.Proofs` import closure; every queried name checked present, theorem bodies read explicitly; tests covered by source search, not compiled dependency scanning.
- `cmp` against `git show fa7f307:<path>` passed (rc 0) for all finding files + spec, README, Spec/Fast; proof/rule anchors also rematched directly in fa7f307. HEAD remained 4e8eefa; tracked tree clean.
- R5.1: comments explain constraints, ordering, caching, proof structure, and fixture rationale; API docstrings state useful contracts. Agent-facing additions are dense; README additions use direct sentences + ordinary terms. Numerical/semantic overclaims belong to Register, not this style verdict.
- R5.2: no benchmark-shape branch or fixture-specific production shortcut found. Reference-vs-fast algorithms are intentional, not duplication findings. R5-F2 concerns reusable presentation only.
- R5.3: spec shape validator passed: `sh /home/eturkes/Projects/fvtrace/.agent/spec-lint /home/eturkes/Projects/fvtrace/.agent/spec.md`, rc 0. Artifacts names the new tools; Phase + suspended scope remain correct. Commit subjects follow `<scope>: <cause> → <fix>`; implementation bodies name measurements, revisions, consultant/tester + verdicts. `4e8eefa` is the check-set checkpoint, not a completed review claim.
- Unconfirmed: whether the unchecked U2–U5 row at `.agent/spec.md:45` deliberately owns pending mutation/gate evidence. The implementation is committed as fa7f307, but the row names no remaining assurance work. MAIN asked; inspected spec + all three commit bodies. If assurance remains, name it; otherwise tick the row with fa7f307. No separate finding pending that clarification.
- Lean LSP unavailable: `documentSymbol` on `Fvtrace/Index.lean` → `No LSP server available for file type: .lean`; source search + elaborated proof dependency scan used instead.
- The first proof-dependency scanner used `ConstantInfo.value?` and failed its positive control (delta_final incorrectly had zero users); discarded. Corrected scanner reads `.thmInfo.value`; only the corrected log supports R5-F1.
- Full gate, build, test suite, timing sweeps, mutation campaigns, and byte-parity suite not run by this reviewer: shared-tree read-only brief forbids rebuilding; those checks belong to the other fixed lenses/MAIN. No claim here that they passed.

## Register — outside R5

- R5-X1 → R2.3/R3.2: `/home/eturkes/Projects/fvtrace/README.md:223`, exact `so a trace of 16 MiB takes seconds`; `/home/eturkes/Projects/fvtrace/Fvtrace/Spec/Fast.lean:9`, exact `so a 16 MiB trace takes seconds` (both `rg -Fn` rc 0). P-bound explicitly grades selected workloads, not every trace. Global speed wording exceeds that domain. MAIN notified; no duplicate R5 finding.
- R5-X2 → MAIN/R2.2: `/home/eturkes/Projects/fvtrace/TrustMain.lean:109`, exact `(ci.value?.map Expr.getUsedConstants).getD #[]`. The first scanner's identical API omitted theorem bodies; explicit `.thmInfo.value` restored the known delta_final edges. Impact on the existing proof-closure audit unconfirmed; looked at TrustMain:32–116 + scanner outputs, then handed to MAIN rather than expanding this lens.
- R5-X3 → R4.2, lead only: new proof modules set `linter.unusedSimpArgs false` + `linter.unusedSectionVars false`. Existing `Proofs/Check.lean` already disables the former; no changed existing linter setting found. No conformance defect asserted from following that convention.

reviewer-23-DONE-1

## Re-review (84da642)

Scope = R5-F1–F4 acceptance checks alone; no new rows. Target = `84da6426bdb9d6947357d727133f12872e70ca64`, tracked tree clean.

| id | verdict | deciding evidence |
|---|---|---|
| R5-F1 | fixed | Four named helpers absent: `rg` rc 1, zero matches; positive control `theorem answers_agree (s : Scenario)` = one match at `Proofs/Answers.lean:1712`, rc 0. The complete modified proof source re-elaborated: `answers-recheck: full agreement proof kernel-checked`, rc 0. |
| R5-F2 | fixed | `Present.lean:28/36/44` owns `sentenceWith`, `qualifiersWith`, `creatorTitleWith`; reference calls at `:56/78/81`, fast calls at `Answers/Fast.lean:640/642/644`, CLI call at `Cli.lean:479`. `presentation-parity: 4 pre-fix bodies definitionally equal`, rc 0; agreement proof also passes. |
| R5-F3 | fixed | Scope check: `fast.md scope: 27 quoted entries; 12/12 prior misses covered; 2/2 unrelated controls excluded`, rc 0. The previous misses include `Engine`, `Check`, `Receipt/Basic`, and all named P-shell consumers; unrelated controls = `Fvtrace/Server.lean`, `web/app.js`. |
| R5-F4 | fixed | `as the fixed-point closure was on prerequisite chains` absent: zero matches, rc 1. Positive control preserved at `fast.md:37`: `time that grows faster than the output is a scan beside it (P-bound).`, one match, rc 0. |

Re-review commands + evidence:

```sh
(cd /home/eturkes/Projects/fvtrace && lake env lean --run .scratch/reviewer-23/answers-recheck.lean)
# answers-recheck: full agreement proof kernel-checked
# rc 0
(cd /home/eturkes/Projects/fvtrace && lake env lean --run .scratch/reviewer-23/presentation-parity.lean)
# presentation-parity: 4 pre-fix bodies definitionally equal
# rc 0
```

- R5-F1 input = a byte-equal private copy of `/home/eturkes/Projects/fvtrace/Fvtrace/Proofs/Answers.lean` (`cmp` rc 0), plus an inert `main` printing the pass marker. Every proof in the modified module elaborated/kernel-checked; prebuilt imported dependencies reused. Log: `/home/eturkes/Projects/fvtrace/.scratch/reviewer-23/answers-recheck.log`.
- R5-F2 parity = kernel-checked `rfl` equalities against the four pre-fix bodies: scenario sentence pieces, scenario qualifiers, scenario creator-title lookup, indexed/CLI creator-title lookup. Quantified over arbitrary inputs, not sampled expected strings. Input/log: `/home/eturkes/Projects/fvtrace/.scratch/reviewer-23/presentation-parity.lean`, `/home/eturkes/Projects/fvtrace/.scratch/reviewer-23/presentation-parity.log`.
- Exact new shared-call bytes rematched by `rg -Fn`: `String.join (Scenario.sentenceWith`, `Scenario.qualifiersWith`, `Scenario.creatorTitleWith`. The old inline copies are removed in the fix diff.
- `cmp` against `git show 84da642:<path>` passed (rc 0) for all five relevant source/rule files: `Proofs/Answers`, `Present`, `Answers/Fast`, `Cli`, `fast.md`. Target source stayed unchanged; final status showed MAIN's edits to `.agent/deferred.md` + `.agent/review.md`, outside this re-review's targets, left untouched.
- Full gate + native two-binary parity not rerun. This round verifies the fixed acceptance checks through source/rule checks, full affected agreement-proof re-elaboration, and all-input definitional parity of the extracted presentation bodies. No new finding rows or register investigations.

reviewer-23-DONE-2
