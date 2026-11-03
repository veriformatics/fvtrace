# reviewer-40 — V-lean-kernel at 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| V-lean-kernel | codec tests (Json, Decode, Fields, Schema, Digest) | reviewer-40-F1 | Contract-owned JSON/schema/round-trip/NIST expectations; Digest's only nonempty file = 300,000 bytes, below its 1 MiB read chunk. Planted one-chunk reader: 8/8 Digest tests green, independent whole-file oracle red. SHA upper-bound probe pending. |
| V-lean-kernel | Tests/Check | pass | Every WF rule has a negative witness; expected rule/path pairs derive from WF-*, restating cases extend WF-entail; assigned pure baseline 488/488. Known F6/F9 concern diagnostics/wording, not new findings. |
| V-lean-kernel | Tests/Engine + Details | reviewer-40-F2 | Engine expectations follow S-*, regressions + plan rules; Details' experiment oracle reuses its graded serializer. Empty raised-values serialization: all 142 Details checks green, contract-derived E1 assertion red. Known F1 label-contract wording not re-reported. |
| V-lean-kernel | Tests/Differential (oracle independence) | unknown | unknown |
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
