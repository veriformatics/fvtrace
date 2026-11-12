# reviewer-2 — C-codec @ 48bc51d

Check set fixed before target read: Correctness × M-codec; kernel.md Decode (D-*) + Model shapes; Decisions Trace format + Trace model; malformed/boundary/huge/Unicode/escapes/duplicates/numbers/nesting; refusal order/messages + CLI-derived exit codes; schema↔decoder; encode↔decode; callers/callees; test setup/teardown.

| row | target | verdict | basis |
|---|---|---|---|
| C-codec | Fvtrace/Json.lean | pass | Every parser/printer/equality helper + consumers read; proof statements only; seeded Python differential: 984 cases (943 accepted), 0 acceptance/canonical/round-trip mismatches; digits/depth/UTF-8/escapes/duplicate boundaries covered. |
| C-codec | Fvtrace/Decode.lean | pass | Every field/helper + enum/model + Session/Cli/Snapshot/Request consumers read; 124 scoped unit checks pass; native smoke 26 assertions covers ordered errors, pointers, syntax/shape/16 MiB boundary + CLI rc 0/1/2. |
| C-codec | Fvtrace/Encode.lean | pass | Every model field/option/default + receipt/evaluation/snapshot/CLI consumers compared; corpus 61 cases (15 decoded) canonical + pretty typed round trips pass; native pin/review output decodes + matches independent canonical digest. |
| C-codec | Fvtrace/Digest.lean | pass | Lean wrappers + FFI/HACL finish callees + receipt/replay/store/export consumers read; native pin/review/check: 26 assertions vs Python hashlib, 11 file sizes through 3 MiB+17, 2 MiB streaming replay + canonical statement/review digests, rc 0. |
| C-codec | schema/trace.schema.json ↔ decoder | reviewer-2-F1, reviewer-2-F2 | All 18 schema definitions ↔ field decoders compared; 5,079 variants → 60 mismatches: 2 UInt32 overflows + 58 unpaired-surrogate strings; focused native red witnesses reproduce both classes. |
| C-codec | tests (setup/teardown, harness use) | pass | Every assigned Lean/Node test + harness use/wiring read; fixtures read-only, native writes scoped by withTempDir, capture restores streams; scoped Lean 124/124 + existing Node schema corpus rc 0; the two schema misses are attributed above. |

## Findings

### reviewer-2-F1 — minor — schema accepts replay exit codes outside UInt32

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/schema/trace.schema.json:378`; decoder bound: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Decode.lean:66`.
- Contract: kernel.md § Model `replay.failed.reason`: `exit N`, N = 1…4294967295; C-codec schema↔decoder agreement (exceptions must sit in kernel.md). The schema's 1–10-digit regex also accepts 4294967296…9999999999. The existing corpus marks overflow `decoder-only`; kernel.md states no corresponding schema exception. This is a shape constraint expressible by a bounded decimal regex, unlike lexical `1.0` versus `1`.
- Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-2/red-schema-exit.mjs` (base 48bc51d; rc 1).

```text
CONTROL exit 4294967295: schema=true, decoder=true, check rc=0, errors=[]
BOUNDARY exit 4294967296: schema=true, decoder=false, check rc=1, errors=[["invalid-replay","/facts/0/evidence/replay/failed/reason"]]
FAIL schema/decoder agreement: reason "exit 4294967296" is schema-valid but D-shape invalid-replay
```

- Fix direction: enforce the same UInt32 upper bound in the schema; make the overflow corpus case schema-invalid instead of exempt.

### reviewer-2-F2 — minor — schema accepts unpaired-surrogate strings

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/schema/trace.schema.json:436` (`text`), also `:86` (`arg`). Both patterns admit a standalone surrogate. Every unrestricted display-text field + replay argument inherits this gap; 58 generated mismatches cover 29 field positions × high/low surrogate.
- Contract: kernel.md D-shape: strings = Unicode scalar sequences; unpaired `\\uD800`–`\\uDFFF` escapes rejected. C-codec requires schema↔decoder agreement. This differs from a raw-byte size/duplicate-key restriction: the parsed string still exposes the unpaired surrogate to an ECMAScript Unicode regexp. A scalar-value pattern can reject it while retaining valid astral pairs.
- Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-2/red-schema-scalars.mjs` (base 48bc51d; rc 1).

```text
CONTROL title: schema=true, decoder=true, check rc=0, errors=[]
HIGH title: schema=true, decoder=false, check rc=1, errors=[["syntax",""]]
FAIL schema/decoder agreement: HIGH title contains an unpaired surrogate accepted by the schema
LOW title: schema=true, decoder=false, check rc=1, errors=[["syntax",""]]
FAIL schema/decoder agreement: LOW title contains an unpaired surrogate accepted by the schema
ARG arg: schema=true, decoder=false, check rc=1, errors=[["syntax",""]]
FAIL schema/decoder agreement: ARG arg contains an unpaired surrogate accepted by the schema
```

- Fix direction: make `text` + `arg` scalar-only (Unicode-aware surrogate exclusion); add shared corpus cases for lone high/low surrogates + a valid astral control.

## Register

None outside the fixed check set.

## Checks + coverage limits

- Target read-only; no build, mutation campaign, full gate, server, Git mutation, external-service action or instruction edit. Only this validator input + reviewer scratch written. Proofs/Json: theorem statements inspected, proof bodies not reviewed (brief).
- Parser/printer differential: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-2/json-differential.py` → rc 0; seed 204219; 984 cases, 943 accepted; Python canonical oracle + canonical/pretty round trips; malformed UTF-8, controls, Unicode boundaries, surrogates, escaped duplicate keys, digit/depth bounds, long plain/escaped strings. Initial harness failed on Python splitlines treating C1/Unicode separators as record boundaries; literal LF framing fixed it; rerun above passed.
- Decoder/encoder corpus: `codec-probe.lean decode schema.paths` through the brief's `/tmp` + base LEAN_PATH invocation → rc 0; all 61 corpus files; 15 decoded; 0 typed canonical/pretty round-trip failures.
- Structural/scalar differential: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-2/schema-differential.mjs` → rc 1 (expected findings); 5,079 cases; 1,251 decoded; 0 typed canonical/pretty round-trip failures; all 60 disagreements = F1 (2) + F2 (58). Node applies the base's Ajv2020 config; `shape-mismatches.json` retains each mismatch. The surrounding shell captured rc then printed output, so its background completion rc was 0; the test's captured rc = 1. No generated variants omitted from comparison.
- Existing scoped unit checks: `(cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-2/unit-probe.lean)` → rc 0, 124/124 (Tests.Json.tests, Tests.Decode.tests, Tests.Decode.sizeTests).
- Existing Node corpus: `node --test --test-reporter=dot /home/eturkes/Projects/fvtrace/.scratch/review-base/tests/schema/schema.test.mjs` → rc 0 (60 tests: corpus guard + 59 non-exempt cases; its two decoder-only inputs stay exempt there).
- Native decoder smoke: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-2/decode-smoke.py` → rc 0, 26 assertions; ordered shape errors, RFC6901 pointer escaping, syntax refusals, exact 16 MiB boundary, oversize-before-parse behavior, CLI valid/invalid/I/O/usage rc 0/1/2.
- Native digest smoke: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-2/digest-smoke.py` → rc 0, 26 assertions; all artifact/statement/review/replay digests = independent Python hashlib. Every fvtrace run has reviewer-local FVTRACE_HOME.
- Finite dynamic probes complement the function/caller/callee pass; no claim of exhaustive testing. Existing Fields pure/native, Digest native + Json.scaleTests were source-reviewed, not individually rerun; MAIN owns the baseline/full suite. Hash FFI's >1 GiB array splitting + >SHA-256 maximum input failure not exercised; loop/callee read. Timing/O(n log n) checked structurally, not newly benchmarked.
- Lean LSP hover attempted on Decode.lean: no server for `.lean`; navigation = explicit source/caller searches + executed Lean checks.

reviewer-2-DONE-1
