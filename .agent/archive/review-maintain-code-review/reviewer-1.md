# C-codec · Correctness · base 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-codec | Fvtrace/Json.lean | pass | Every parser/printer function + callers read; D-json/D-canon boundary cases + 533 seeded JS-oracle cases; `json-checks.lean`: 1206/1206 checks, rc 0. |
| C-codec | Fvtrace/Decode.lean | pass | Every field decoder/default + model/wire names + CLI refusal/rc wiring read. Existing selected suites: 206/206 checks; 2100 generated shape cases show only F1/F2 schema-side discrepancies. |
| C-codec | Fvtrace/Encode.lean | pass | Every encoder field/default omission + canonical/pretty consumers read. 339 generated decoded traces round-trip through canonical + pretty (0 failures); fields/outcome-order tests pass; native pin/review writes reload. |
| C-codec | Fvtrace/Digest.lean | pass | Streaming wrappers, FFI boundary + receipt/review callers read. `digest-smoke.mjs`: 11 file sizes (SHA block + 1 MiB chunk boundaries), statement + review digests = Node SHA-256; real pin/check --strict/review rc 0. |
| C-codec | schema/trace.schema.json ↔ decoder | reviewer-1-F1, reviewer-1-F2 | Two schema-side predicate gaps: UInt32 exit bound + scalar strings. 2100 shape mutations: 60 mismatches, all those two classes; focused witnesses fail against the built base. |
| C-codec | tests (setup/teardown, harness use) | pass | Five target Lean suites + shared harness + Node schema harness read; fixtures read-only, native writes under `withTempDir`, captured streams restored by harness. Selected Lean suites 206/206, Node corpus 60/60; F1 records the corpus exemption. |

## reviewer-1-F1 · minor · schema admits replay exit-code overflow

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/schema/trace.schema.json:378` (`48bc51d`); related corpus exemption: `tests/schema/schema.test.mjs:27`.
- Contract: `kernel.md` § Model, replay `failed.reason`: decimal nonzero exit code ≤ 4294967295; C-codec schema ↔ decoder agreement.
- Defect: `exit [1-9][0-9]{0,9}` accepts every ten-digit positive decimal, including `4294967296` … `9999999999`. `Decode.validFailReason` enforces the UInt32 bound; the schema therefore validates a structurally invalid trace that `fvtrace check` refuses. The committed `decoder-only-replay-failed-exit-overflow.json` case is skipped by the schema test, but this bound is expressible by a regular expression (unlike lexical `1.0` vs `1`). Kernel law gives no exception for it.
- Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-1/schema-replay-bound.mjs`
- Base output (rc 1):

```text
exit 4294967296: schema=true, decoder=false (rc 1, invalid-replay)
AssertionError [ERR_ASSERTION]: schema must reject an exit reason above UInt32.max
true !== false
```

- Decoder proof: `check --json` emits `invalid-replay` at `/facts/0/evidence/replay/failed/reason`; script asserts that diagnostic before the red assertion.
- Fix direction: make the schema reason predicate match the UInt32 bound; grade the existing overflow case on both sides rather than exempting the schema.

## reviewer-1-F2 · minor · schema accepts non-scalar strings

- Targets: `/home/eturkes/Projects/fvtrace/.scratch/review-base/schema/trace.schema.json:436` (`$defs.text`) + `:86` (`$defs.arg`), base `48bc51d`.
- Contract: `kernel.md` D-shape: strings = Unicode scalar sequences; unpaired surrogate escapes rejected. C-codec schema ↔ decoder agreement.
- Defect: text + replay-argument predicates permit lone UTF-16 surrogates. With `analysis.title = "\ud800"` or one replay argument `"\udfff"`, Ajv validates the published schema, while the same serialized document is refused by `fvtrace check` with `syntax: unpaired surrogate in \\u escape`. This is a string-domain predicate, expressible with a Unicode-aware surrogate-range exclusion; a valid supplementary character must remain allowed.
- Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-1/schema-scalars.mjs`
- Base output (rc 1):

```text
positive control: paired supplementary character accepted by schema + decoder (rc 0)
text with lone surrogate: schema=true, decoder=false (rc 1, unpaired surrogate)
arg with lone surrogate: schema=true, decoder=false (rc 1, unpaired surrogate)
AssertionError [ERR_ASSERTION]: schema text + arg predicates must reject non-scalar strings
```

- Fix direction: constrain text + argument strings to scalar sequences; add both lone-surrogate cases + a paired-character control to the shared schema corpus.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Export.lean:231` → outside M-codec; successful bundle export can write a trace over D-json's 16 MiB cap because `pretty` expands allowed C1/bidi characters + indentation. Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-1/bundle-size.mjs` (rc 1): input 6000573 bytes/check rc 0 → export rc 0 → bundled trace 18000898 bytes → colleague check rc 1, `size: the trace has 18000898 bytes; the limit is 16777216 bytes`. Routed to MAIN for C-export; G-codec's canonical encoding itself is not this expansion.

## Checks + coverage

Scratch root = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-1`. Every native invocation sets `FVTRACE_HOME` to its `home` child. Temporary digest + bundle projects + the scalar witness's trace are removed by their scripts; no server started, target edits/builds, git commands or nested agents.

| check | command/artifact under scratch root | result |
|---|---|---|
| Existing Json + Decode cases, size boundaries; seeded parser/canonical oracle | `node generate-json-cases.mjs`; from `/tmp`: `LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run <scratch>/json-checks.lean` | rc 0; 1206/1206 checks. 533 deterministic JS-generated values include all C0 chars, supplementary characters + code-point key ordering; UTF-8/escape/depth/number/duplicate-key boundaries included. |
| Selected existing suites | Copied `tests/{fixtures,schema}` under scratch; from scratch: same `LEAN_PATH`, `lean --run <scratch>/fixture-checks.lean` | rc 0; 206/206 checks: Json, Decode (including outcome order + size), Fields, Schema. Overlaps the preceding run; counts are not additive. |
| Schema corpus | `node --test /home/eturkes/Projects/fvtrace/.scratch/review-base/tests/schema/schema.test.mjs` | rc 0; 60/60 tests. The two `decoder-only-*` files never become Node tests, so its reported skipped count 0 does not mean they were validated. |
| Shape differential + trace round trips | `node generate-shape-cases.mjs`; from `/tmp`, same `LEAN_PATH`, `lean --run <scratch>/shape-checks.lean` | rc 1: 2100 mutations over 111 field nodes; 60 mismatches = 58 scalar-string cases + 2 UInt32 overflow cases (F2 + F1); all 339 decoded traces re-decode through both canonical + pretty, 0 failures. Every mismatch inspected/classed. |
| Native SHA-256 | `node digest-smoke.mjs` | rc 0; 11 artifact lengths (0/1/55/56/63/64/65/1048575/1048576/1048577/2097159) = Node SHA-256; Unicode statement + review digests agree; real `pin`, `check --strict`, `review` rc 0. |
| Focused red witnesses | `node schema-replay-bound.mjs`; `node schema-scalars.mjs` | Each rc 1 for the named contract assertion; details above. |
| Outside-slice red witness | `node bundle-size.mjs` | rc 1; register above. |

Bounds: generated cases are a finite probe, not an exhaustive domain proof; whole-file review supplies the remaining judgment. Parser complexity inspected structurally; the native 200000-key scale suite, full native test suite (including `Tests.Digest.tests` + `Tests.Fields.nativeTests`), full gate, mutation campaigns + timing campaign were not run here (brief forbids full gate/campaigns). Native digest behavior was driven through the package's built CLI instead. Lean LSP unavailable (`No LSP server available for file type: .lean`); code navigation used bounded named-path `rg` + source reads. Logs + regenerated inputs remain beside their scripts.

reviewer-1-DONE-1

