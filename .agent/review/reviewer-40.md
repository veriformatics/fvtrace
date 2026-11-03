# reviewer-40 — V-lean-kernel at 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| V-lean-kernel | codec tests (Json, Decode, Fields, Schema, Digest) | reviewer-40-F1, reviewer-40-F3 | Contract-owned JSON/schema/round-trip/NIST expectations; one-chunk file hash survives 8/8 Digest checks; SHA length ≥64 survives 108/108 Decode+Schema checks. Each independently contract-graded witness red. Known F7 schema gaps not re-reported. |
| V-lean-kernel | Tests/Check | pass | Every WF rule has a negative witness; expected rule/path pairs derive from WF-*, restating cases extend WF-entail; assigned pure baseline 488/488. Known F6/F9 concern diagnostics/wording, not new findings. |
| V-lean-kernel | Tests/Engine + Details | reviewer-40-F2 | Engine expectations follow S-*, regressions + plan rules; Details' experiment oracle reuses its graded serializer. Empty raised-values serialization: all 142 Details checks green, contract-derived E1 assertion red. Known F1 label-contract wording not re-reported. |
| V-lean-kernel | Tests/Differential (oracle independence) | pass | All 37 Answers fields compared (36 direct + 20/20 nested Lookups); reference = Scenario/list definitions, fast = indexes/Core/forest; no csimp/implemented_by substitution. 21 prerequisite families + malformed collections, outside records, arbitrary overrides; all candidates asserted kept. |
| V-lean-kernel | Tests/Scale (bounds vs P-*) | pass | Contract P-evidence separates load-tolerant regression witnesses (20 s at n=3,000/2,000; ≤4,000n what-if bytes) from idle-host N_cap acceptance (10 s, 2.5× time/RSS, 2.2× bytes, external scale.sh). c930c8c adds enforceable bounds; no relaxation. No independent cap timing claimed here. |
| V-lean-kernel | wiring + history (nothing skipped or weakened) | pass | All 19 assigned suite entry points reach pure/native → all → TestMain → Lake testDriver. Per-file log -p --follow inspected through 48bc51d: additions, equivalent API migrations, v2 payload relocation; no unreplaced removal/skip/weakening. |

## Scope

Fixed check set = assigned V lens: contract-owned expectations; independent reference; boundary/branch coverage; active Lake wiring; history integrity; planted-defect sensitivity. Target = frozen 48bc51d. Read-only target; scratch witnesses = `.scratch/review/reviewer-40/`.

## reviewer-40-F1 — minor — file hashing never crosses its read-chunk boundary

- Target: `Tests/Digest.lean:28–31` (absolute base `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Digest.lean`). Anchor: `(Array.range 300000)`.
- Contract: kernel.md Receipts (`current` compares each artifact's SHA-256) + CLAUDE.md Engineering, Verification integrity (full input domain + observable mutant kills).
- Why: only the empty file + a 300,000-byte file exercise `Digest.ofFile`; its read chunk = 1,048,576 bytes. Deleting the repeat loop (hash one chunk, return) preserves all eight Digest checks. The million-byte NIST vector calls `ofBytes`, not `ofFile`, and is below one file chunk anyway.
- Witness: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/probe.sh digest` (run with `bash`; isolated copy, incremental build only). `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/digest-probe.py` grades a 1,048,681-byte file against Python hashlib, not fvTrace output. Unmodified control rc 0 (`digest-control.log`); planted reader build rc 0; witness rc 1 (`digest-mutant.log`):

```text
existing Digest tests rc=0
8/8 checks passed (slowest: )
file bytes=1048681; expected=19d36326c2f735e2bec623bb0933ffc8128f4e7879b998e429261587a01f7963; actual=631b84027d6b9e52b539c4e8373622d23032dfadc64d60af87339c9037e4f769
FAIL: a one-chunk file digest violates the whole-file receipt contract but every existing Digest test passes
```

- Fix: file vectors at a full chunk + past it (distinct suffix); make the one-chunk mutant red through the public file-hash behavior.

## reviewer-40-F2 — minor — experiment-details oracle calls the serializer it grades

- Target: `Tests/Details.lean:33` (absolute base `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Details.lean`). Anchor: `got (Evaluate.experimentLists R e)`.
- Contract: CLAUDE.md Engineering, Verification integrity; assigned V check explicitly rejects an oracle calling its graded function. kernel.md V-details owns each experiment's `closure`, `raises`, `wins`, `losses`.
- Call chain: the actual value comes from `detailsOf` → `Evaluate.detailsWith` → `itemLists` → `experimentLists A e` (`Fvtrace/Evaluate.lean:209–211`); the expected value invokes `experimentLists R e`. Fast/reference record separation tests engine answers, but gives no independent check of this serializer. A wrong serialization therefore changes both sides equally.
- Witness: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/probe.sh details` plants `("raises", overridesJson [])` in the isolated copy's `Evaluate.experimentLists` (its reference + fast engine remain unchanged). Build rc 0; witness rc 1. Existing suite passes 142/142; explicit fixture E1 = success O2 checked, recorded O2 open ⇒ V-details must carry O2 checked, not `[]`. Unmodified control rc 0 (`details-control.log`); planted log = `details-mutant.log`:

```text
FAIL: the experiment-details oracle accepts the same wrong serializer on both sides
142/142 checks passed (slowest: )
existing Details suite rc=0
E1 raises: got=some (Fvtrace.Json.Value.arr []); contract=Fvtrace.Json.Value.arr
  [Fvtrace.Json.Value.obj [("fact", Fvtrace.Json.Value.str "O2"), ("status", Fvtrace.Json.Value.str "checked")]]
verification-integrity witness rc=1
```

- Fix: build expected wire values independently from the contract/reference fields, with distinct closure/raises/wins/losses fixtures; retain fast-vs-reference comparisons as a separate concern.

## reviewer-40-F3 — minor — D-sha's past-the-upper-bound input is absent

- Target: `Tests/Decode.lean:98` (absolute base `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Decode.lean`), shared corpus `tests/schema/cases/`. Anchor: `decode: short sha256`.
- Contract: kernel.md D-sha = exactly 64 lowercase hex; assigned boundary check = each D-* limit at and past its bound.
- Why: cases exercise 64 characters + 63 characters, case + alphabet, but no 65-character digest. All receipt/output/review digest fields share `Decode.validSha`; changing its length guard from `== 64` to `≥ 64` remains green.
- Witness: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/probe.sh sha`; the isolated copy changes that one guard, incrementally builds `Tests.Decode` + `Tests.Schema`, then runs both existing suites + an independently expected rejection. Unmodified control rc 0 (`sha-control.log`); mutant build rc 0; witness rc 1 (`sha-mutant.log`):

```text
FAIL: the SHA-256 upper-bound defect survives every Decode + Schema test
108/108 checks passed (slowest: )
existing Decode + Schema rc=0
65-digit sha256 diagnostics: got=[]; contract=[("invalid-sha256", "/review/digest")]
verification-integrity witness rc=1
```

- Fix: add an invalid 65-character lowercase-hex digest corpus case + assert its decoder diagnostic; keep 64 accepted + 63 rejected. The planted `≥ 64` guard must fail the suite.

## Checks + coverage

- Assigned pure suites, frozen base `.olean`s + copy's fixture paths: `LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/KernelPure.lean` from `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/tree` → rc 0, **488/488** (`baseline-pure.log`). Covers Json, Decode (+ size/outcome order), Schema, Check, Engine (+ witnesses/kinds/acceptance), Details, Fields.
- Assigned native suites on restored code, extra scratch-only TestMain selector (original `Tests.all` path kept; create `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/tmp` before rerunning): `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/home TMPDIR=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/tmp /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-40/tree/.lake/build/bin/fvtrace-tests --review-native` from the same tree → rc 0, **572/572** (`baseline-native-direct.log`). Covers Digest, Fields.native, Json.scale, Engine.scale, Scale.check/eval, Differential. Differential = seed 19798168526996293, **1,001,225 comparisons**, 21 prerequisite families + the matrix/malformed corpus. Slowest = differential 53,040 ms, check-scale 12,829 ms, json-scale 8,298 ms; these times are not idle-host P-bound evidence.
- All **19/19** assigned suite definitions wired into `Tests.pure`/`native`; `Tests.all` calls both; TestMain calls `Tests.all`; Lake `testDriver := "«fvtrace-tests»"`; gate `lean_test` = `lake test`.
- Boundaries read: JSON depth 64/65 for arrays + objects, integer digits 20/21 at both signs; Unicode surrogate endpoints + unpaired cases + invalid UTF-8; D-json size uses a pinned 16 MiB constant + parameterized at/past-limit mechanism checks; id 64/65; date month/day lower + upper limits; D-text empty/control/newline; SHA 64/63/alphabet (past upper bound = F3). Corpus = **61** cases. All **15/15 WF rule ids** have negative witnesses. S-bind, lowering/raising overrides, exclusion derivation + conflict scope, cannot/can/conditional/open, must-verify gaps, restating, plan branches + 20/21 boundary have contract-derived witnesses; differential extends malformed/all-domain fast agreement.
- Expected-value provenance: JSON syntax/D-canon, decoded field defaults/shapes, WF rule/path pairs, engine scenarios + plan order, wire fields, NIST digest vectors. Round-trips compare the original decoded value; file-vs-bytes hashing composes the NIST-checked primitive. Serializer self-oracle exception = F2.
- Per-file `git log -p --follow 48bc51d -- <file>` = all 12 target files (`history/*.log`); inspected edits to existing tests + original test bodies. Removed old CLI checks live at `Tests/CliStore.lean:284–301`; timed areas preserve exception failure + previous outcomes; v2 relocation retains engine assertions; Scale bounds strengthened at c930c8c. No unreplaced skipped/removed/demoted/loosened check found.
- Scripts: `bash -n probe.sh`, `shellcheck probe.sh`, Python compile-only syntax check → rc 0. All three planted builds rc 0; unmodified controls rc 0; every independent planted-defect witness rc 1. `cmp` confirms scratch Digest/Evaluate/Decode source bytes restored to base. The copy retains only its test-entry selectors + replay evidence; target/primary source untouched.
- Limits: no full gate, new mutation campaign, independent-kernel replay, browser check, cross-platform run or N_cap/idle-host performance run performed here. Those belong to other review rows. No Lean LSP server available (documentSymbol on Tests/Digest.lean returned that limitation); used source + real Lean builds/runs. Slot-queued attempts were canceled before execution; scoped native run above replaced them directly under the lead's fast/scoped-test directive. No test omission is claimed as green.

reviewer-40-DONE-1
