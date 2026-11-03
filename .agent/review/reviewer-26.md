# reviewer-26 — K-codec + K-check

Target = `48bc51d`, frozen `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Checks = Cleanup + Altitude; one pass per lens × slice. Behavior-preserving findings only; out-of-scope defects → Register.

| row | target | verdict | basis |
|---|---|---|---|
| K-codec | Cleanup: Json + Decode + Encode + Digest | reviewer-26-F1, reviewer-26-F2 | All four modules read; exact hex-digit duplicate + six copies of string-validation protocol; declaration/reference sweep found no dead shipped definition. |
| K-codec | Cleanup: schema + tests | reviewer-26-F3, reviewer-26-F4 | Schema + all five test modules + Node runner read; 61 fixtures structurally scanned (15 valid, 44 invalid, 2 decoder-only), both runners enumerate their applicable corpus. Date constraint + test harness helpers duplicated. |
| K-codec | Cleanup: Proofs/Json (unused lemmas) | pass | Every lemma traced to its callers; sortMembersAgree is the Spec.SortMembersAgree proof that TrustMain discovers by theorem type. No unused lemma. |
| K-codec | Altitude | pass | Separate pass: Json's shown flag selects digest/display contracts; syntax limits remain in parser, trace-version/field rules in Decode; decodeTraceWithin serves native readers + reduced-limit tests. No caller-specific workaround in shared codec infrastructure. |
| K-check | Cleanup: Model + Check + Lint | pass | All three modules read + declaration/reference census. Shared receiptOk/onSubject, Fact.allows/ceiling + Lookups reused; rule/lint tables drive dispatch. No dead shipped definition, redundant stored state, unused closure capture or unjustified serial IO found. |
| K-check | Cleanup: Spec/WellFormed + Proofs/Check (unused lemmas) + tests | reviewer-26-F4, reviewer-26-F5 | Spec + entire proof/test files read; one unused, unregistered lemma; test fixture loader duplicated. Every other proof lemma has a caller or proves a TrustMain-discovered Spec claim. |
| K-check | Altitude | pass | Separate pass: must-verify policy centralized in Fact.allows/ceiling + Kind.mustVerify; rule dispatch/lints parameterized over Lookups; fact/exclusion receipt paths share receiptOk; replay-notice digest exception sits in Trace.withoutNotices. No misplaced caller quirk found. |

## Findings

### reviewer-26-F1 — minor — duplicate hex-digit helper

- Location: `Fvtrace/Json.lean:298`, `Fvtrace/Digest.lean:28` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering, Cleanup: existing helpers reused; near-duplicate blocks merged.
- Both modules define the same total `Nat → Char` operation with identical bytes. JSON escaping + SHA formatting maintain two copies of one primitive; their domain + modulo behavior are identical.
- Anchor + proof (expected 2 matches; observed 2, rc 0):
  ```sh
  rg -Fn 'def hexDigit (n : Nat) : Char := "0123456789abcdef".toList[n % 16]!' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace
  ```
  ```text
  Fvtrace/Digest.lean:28:def hexDigit (n : Nat) : Char := "0123456789abcdef".toList[n % 16]!
  Fvtrace/Json.lean:298:def hexDigit (n : Nat) : Char := "0123456789abcdef".toList[n % 16]!
  ```
- Behavior-preserving witness: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-26/cleanup-equalities.lean` kernel-checks `Json.hexDigit = Digest.hexDigit` by `rfl`; command below, rc 0.
- Fix: one Init-only hex-digit primitive shared by both modules; preserve the current modulo-16 result. No proof/Spec definition names either helper.

### reviewer-26-F2 — minor — string-validator protocol copied six times

- Location: `Fvtrace/Decode.lean:73–104`, `:208–224` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering, Cleanup: near-duplicate blocks merged; deduplicate.
- `text`, `ident`, `sha`, `date`, `arg`, `failReason` each: decode `string`; propagate `none`; check a string predicate; on success return the unchanged string; otherwise report its code + message and return `none`. Only predicate/code/message differ. Six copies of the shared field-decoder protocol can be one helper with those parameters; the separate enum decoder has a distinct value lookup and is not included.
- Anchor: `rg -Fn 'match ← string path v with' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Decode.lean` → lines 74, 83, 92, 99, 111, 209, 216, rc 0; line 111 is the excluded enum decoder. Enclosing six definitions + branches read in full.
- Existing-helper search: `rg -n '(def .*([Vv]alid|[Vv]alidate|[Pp]redicate|[Cc]hecked[Ss]tring)|match ← string path v)'` over `Fvtrace/{Decode,Snapshot,Request}.lean` found these copies + the Boolean predicates, no factoring helper.
- Behavior-preserving witness: six `rfl` equalities in `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-26/cleanup-equalities.lean` prove each current decoder definition equal to one parameterized helper on its entire `Field` domain (values, paths + diagnostic state), not sampled inputs. Run:
  ```sh
  (cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-26/cleanup-equalities.lean)
  ```
  Observed: no diagnostics, rc 0 (7 equality examples, including F1).
- Fix: shared validated-string `Field String`, parameterized by predicate, diagnostic code + `String → String` message; preserve each predicate, exact diagnostic bytes + report order. No proved definition needs changing.

### reviewer-26-F3 — minor — schema date constraint duplicated

- Location: `schema/trace.schema.json:372–375`, `:392–395` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering, Cleanup: existing helpers reused; near-duplicate blocks merged.
- Replay notice dates + review dates carry identical `{type, pattern}` objects inline, while the schema already centralizes shared id/text/sha validators in `$defs`. The decoder already shares `Decode.date` between these fields; the schema copies its rule instead of sharing it.
- Anchor + proof (expected 2 matches; observed 2, rc 0):
  ```sh
  rg -Fn '"pattern": "^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$"' /home/eturkes/Projects/fvtrace/.scratch/review-base/schema/trace.schema.json
  ```
  Matches lines 374 + 394. Python `json.loads` structural comparison of `$defs.replay.properties.failed.properties.date` and `$defs.review.properties.date` → `True`; `$defs.date` absent.
- Fix: one `$defs.date`, referenced by both properties; preserve its current pattern exactly. No Lean definition/proof change.

### reviewer-26-F4 — minor — shared test helpers copied across suites

- Location: `Tests/Fields.lean:12`, `Tests/Check.lean:7–10` at `48bc51d` (in-scope instances).
- Contract: `CLAUDE.md` Engineering, Cleanup: existing helpers reused; near-duplicate blocks merged.
- Seven suites carry the same substring counter; four carry the same synthetic-fixture decode + exception protocol. All use the shared `Tests/Harness.lean`, which currently has neither helper. `Tests/Fields.lean` already reuses `Tests.Engine.fixture`, demonstrating that these readers do not need suite-specific semantics.
- Substring-counter anchor:
  ```sh
  rg -Fn 'def count (s sub : String) : Nat := (s.splitOn sub).length - 1' /home/eturkes/Projects/fvtrace/.scratch/review-base/Tests
  ```
  Expected/observed 6 exact matches, rc 0: `Fields:12`, `Snapshot:7`, `Export:7`, `CliStore:7`, `Replay:39`, `Assets:8`. Seventh = alpha-renamed `Tests/Notices.lean:45`: `def count (text sub : String) : Nat := (text.splitOn sub).length - 1`.
- Fixture-reader anchor:
  ```sh
  rg -Fn '| .error ds => throw (IO.userError s!"fixture does not decode: {repr ds}")' /home/eturkes/Projects/fvtrace/.scratch/review-base/Tests
  ```
  Expected/observed 4 matches, rc 0: `Check:10`, `Engine:10`, `Receipt:10`, `CliStore:14`. Full four-line readers inspected; `fixture` in the first three + `decoded` in CliStore all read `tests/fixtures/synthetic.trace.json`, return the decoded trace or throw exactly this error.
- Behavior-preserving witness: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-26/test-helper-equalities.lean` proves by `rfl` all 6 other counters equal to `Tests.Fields.count` + all 3 other readers equal to `Tests.Check.fixture`. Command:
  ```sh
  (cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-26/test-helper-equalities.lean)
  ```
  Observed: no diagnostics, rc 0 (9 equality examples).
- Fix: one common substring counter + one common fixture reader in neutral test support; use them in every suite. Keep names of checks, file path, exceptions + substring semantics unchanged. No shipped/proved definition needs changing.

### reviewer-26-F5 — minor — unused proof lemma

- Location: `Fvtrace/Proofs/Check.lean:21–29` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering, Cleanup: dead code removed; K proof-body allowance = unused lemmas only.
- `forall_zipIdx` is never named after its declaration. It has no `[simp]` or other registration attribute and proves a parameterized list equivalence, not a Spec claim; `TrustMain.lean:87–91` discovers only theorems whose type is a claim constant, so it does not consume this lemma implicitly. `flatMap_zipIdx_eq_nil:32–41` separately proves the same element/zipIdx quantifier conversion instead of using it.
- Anchor + complete source-reference proof (positive control: expect its one declaration; observed exactly 1 match, rc 0):
  ```sh
  rg -n --hidden '\bforall_zipIdx\b' /home/eturkes/Projects/fvtrace/.scratch/review-base
  ```
  ```text
  Fvtrace/Proofs/Check.lean:21:theorem forall_zipIdx {α : Type} {l : List α} {P : α → Prop} :
  ```
  Search includes all non-ignored source trees, `Fvtrace/Spec`, `Fvtrace/Proofs`, `Tests`, `tests`, `tools`, `web`, `TrustMain.lean`, Lakefile + hidden workflows. Build/dependency outputs excluded; 342 UTF-8 files in the declaration-reference census. Header + preceding lines inspected: no attribute; repository search has no `attribute`/simp registration naming it.
- Fix: delete this unused lemma, or use it to replace the duplicated quantifier-conversion argument. Deletion changes no proved implementation/Spec definition and no used proof.

## Register

None. The three pre-briefed findings (failure-side WF-route wording, schema exit-code bound + lone surrogates) excluded from re-reporting.

## Coverage + checks

- 7/7 table rows adjudicated; 5 unique findings, all minor; both Altitude passes clean. Every assigned implementation/spec/proof/test source read in full. Proof bodies reviewed for lemma liveness alone.
- All 61 schema fixtures structurally scanned; cleanup review did not re-grade each fixture's behavioral expectation. Their independent JSON documents are test inputs, not duplicate executable logic.
- Reference census: 342 non-ignored UTF-8 files via `rg --files --hidden`; generated build/dependency trees excluded. Exact `rg` anchors above rerun on the frozen base. The three final Spec-proving theorems excluded from the dead-code candidate list after checking TrustMain's theorem-type matching.
- Passed: 7 codec/helper + 9 test-helper kernel-checked `rfl` equalities; schema date structural-equality check; corpus JSON parsing (61/61); deliverable validator (seed 6 unresolved rows → final 0).
- Not run: production suites, gate, mutation campaigns, new native/GUI behavior probes (none required for these text/structural findings; target remains read-only). LSP unavailable for `.lean`; fallback = source reads + repo-wide lexical references + kernel-checked equalities.
- No unconfirmed finding; no target implementation/Spec definition changed. Writes = this deliverable + its 2 equality-proof inputs under the assigned scratch path. Git untouched; no server/process started.

reviewer-26-DONE-1
