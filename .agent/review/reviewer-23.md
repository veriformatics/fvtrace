# reviewer-23 — C-gate at 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-gate | gate.sh (stages, shards, rc, timings) | pass | Every stage + caller read; STAGES ↔ gate.yml matched; sourced stage(rc 17) followed by stage(rc 0) retained the failure + printed both timings; fanout rc 0. |
| C-gate | fast-gate.sh + ci-gate.sh | unknown | unknown |
| C-gate | gate-probe.sh (plant, cause, restore, re-hash) | reviewer-23-F1 | Every plant/expected cause + restore path read; dispatcher ignores an unexecuted probe's rc (red-probe-selection.sh rc 1). Full probe suite reserved to MAIN. |
| C-gate | trust.sh + statement.sh + TrustMain.lean | reviewer-23-F2 | Audit/replay/cache/fingerprints read; full escape-hatch closure omits inductive constructors (red-trust-ctor.sh rc 1; direct-opaque positive control fires). |
| C-gate | mutate.mjs | reviewer-23-F3 | Operators/ranges/protection/build+suite rc/restore/timeouts read; --list-only raw-string witness rc 1. No mutation campaign run. |
| C-gate | fetch-tools / pin-tool / install-lean / vendor-hacl + tools.lock | reviewer-23-F4 | Digest-before-extract, stamp keys, lock versions/URLs, platform assets + vendored manifest read; installer timeout can wait past its bound (red-install-bound.sh rc 1). Live repin/download not repeated. |
| C-gate | lean-style.sh + spec-lint + e2e-load.sh | unknown | unknown |
| C-gate | test harness (Tests.lean, Harness, TestMain, TestPure) + lakefile.lean | reviewer-23-F5 | Suite wiring/native split + embeds read; harness exception/continuation/report witness passes; C build omits included-header dependencies (red-c-header.sh rc 1). |
| C-gate | configs | unknown | unknown |

## Findings

### reviewer-23-F1 — minor — probe dispatch can report success without running its requested probe

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/gate-probe.sh:486`.
- Contract: ops.md Probes (`[probe…]`, each requested probe plants input + demands its cause); Correctness (exit codes retained); Engineering (`green` names checks run + passed).
- Cause: `for p …; do "probe_$p"; done` discards command/function failure; only failures accumulated inside `expect`/`allow` affect the final rc. A misspelled selection runs no check, prints `0 passed, 0 failed`, returns 0.
- Red: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-23/red-probe-selection.sh` → rc 1:

```text
…/tools/gate-probe.sh: line 486: probe_definitely_not_a_probe: command not found
probes: 0 passed, 0 failed
actual rc=0; expected nonzero for an unexecuted probe
FAIL: an unrecognized probe was not run but the probe runner returned success
```

- Fix: validate selections before dispatch + propagate a selected probe's nonzero rc; preserve all-probes execution + final summary.

### reviewer-23-F2 — major — escape-hatch closure skips inductive constructors

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/TrustMain.lean:107-109`.
- Contract: lean.md Layout (`fvtrace-trust` fails an opaque/partial/extern/unsafe/implemented_by in the proof's statement closure); ops.md Gate trust audit.
- Cause: statement/fingerprint closure uses `meaningDeps` (inductive → constructor names), but escape-hatch `full` closure uses only the constant's type + optional value. An inductive has no value, so its constructor types are unwalked.
- Plant: shipped `opaque reviewCtorBound : Nat := 3`; inductive `ReviewCtorBox.box : Fin reviewCtorBound → ReviewCtorBox`; Spec claim `∀ x : ReviewCtorBox, x = x`, proof `intro x; rfl`. The statement fingerprint reaches the opaque bound, but audit returns no finding for that claim. A direct `reviewCtorBound = reviewCtorBound` control returns exactly one finding.
- Red: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-23/red-trust-ctor.sh` → rc 1:

```text
claims include fixture: true
statement closure includes opaque bound: true
positive control: expected 1 direct-opaque finding, got 1
FAIL Fvtrace.Spec.ReviewDirectOpaque: Fvtrace.Proofs.reviewDirectOpaque reaches opaque Fvtrace.reviewCtorBound
ReviewCtorAudit.lean:23:0: error: FAIL: audited statement reaches opaque constructor bound but audit returns no finding
```

- Witness modules + driver: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-23/tree/{Fvtrace/ReviewCtor.lean,Fvtrace/Spec/ReviewCtor.lean,Fvtrace/Proofs/ReviewCtor.lean,ReviewCtorAudit.lean}`. The driver imports the unchanged base audit `.olean`; it calls `audit` on the base + fixture environment, with no target edits.
- Fix: use constructor-aware meaning dependencies for escape-hatch closure too; keep theorem proof bodies unwalked + separate axiom collection.

### reviewer-23-F3 — minor — raw-string contents are treated as mutation sites

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/mutate.mjs:90-96`.
- Contract: tool's operator contract (`Comments, strings + chars are never mutated.`), lean.md Mutation credit.
- Cause: quoted-string mask ends at the first unescaped `"`; Lean `r#"…"#` strings may contain bare quotes. The mask re-enters code inside the literal and mutates its words/numerals.
- Valid Lean fixture (`lean ReviewMutationStrings.lean` rc 0): `def raw : String := r#"a " true 9 " tail"#`.
- Red: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-23/red-mutation-strings.sh` → rc 1:

```text
ReviewMutationStrings.lean:1 7 → 8
ReviewMutationStrings.lean:2 true → false
ReviewMutationStrings.lean:2 9 → 10
ReviewMutationStrings.lean:3 == → !=
mutants: 4
positive control: expected ordinary numeral site at line 1
ReviewMutationStrings.lean:1 7 → 8
FAIL: mutation sites include the interior of a valid Lean raw string
```

- Fix: recognize Lean raw-string delimiters + protect through their matching terminators; preserve ordinary operator sites.

### reviewer-23-F4 — minor — the installer timeout waits indefinitely after TERM

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/install-lean.sh:24-25`.
- Contract: ops.md CI (`every download bounded + retried, each attempt ≤ 180 s`); `bounded`'s own contract (process exits or bound passes, then rc 124).
- Cause: timeout sends TERM, then `wait`s without a second bound or KILL. A process that ignores/delays TERM keeps the attempt inside that wait past the advertised bound.
- Red: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-23/red-install-bound.sh` → rc 1. Sources only the unchanged `bounded` helper, sets its existing `attempt_secs` knob to 1, runs a child that ignores TERM + exits at 4 s; no install/download:

```text
attempt limit=1s; actual=4s; rc=124
FAIL: the attempt waits for a TERM-resistant process past its limit
```

- Fix: bounded termination escalation + descendant cleanup; `wait` only after guaranteed termination. Keep outer workflow timeout as the last bound, not the per-attempt implementation.

### reviewer-23-F5 — minor — C object builds do not trace their included project headers

- Base: `/home/eturkes/Projects/fvtrace/.scratch/review-base/lakefile.lean:105-108`.
- Contract: CLAUDE.md Engineering Correctness (build/config dependencies keep their invariants); this target's claim that the pinned HACL* + FFI shim are compiled verbatim. Incremental `lake build` must reflect current inputs.
- Cause: each `buildO` receives only its `.c` source job. Its `includes` argument is weak compiler flags, not header jobs. Lake 4.35 `buildO` (installed `/opt/lean/src/lean/lake/Lake/Build/Common.lean:843`) traces the source + explicit flags + `extraDepTrace`; it discovers no included headers itself.
- Red: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-23/red-c-header.sh` → rc 1. Baseline `lake build fvtracec` passes; append a distinctive `#error` to a header the C source includes; direct compiler positive control rejects it, but cached Lake build returns success. The script restores the header; `cmp` with the base rc 0.

```text
positive control: expected compiler rc nonzero + planted diagnostic; actual rc=1
c/hacl/internal/../Hacl_Hash_SHA2.h:204:2: error: #error REVIEW_C_HEADER_MUST_REBUILD
Build completed successfully (2 jobs).
lake build after invalid included header rc=0; expected nonzero
FAIL: the cached C objects ignore changes to their project headers
```

- Limit: the full gate's separate vendor check rejects this unpinned plant; this proves stale incremental C builds, not a full-gate pass on an edited vendor header. A legitimate pin update that changes only headers has the same dependency gap.
- Fix: include relevant project headers (and the Lean header/toolchain trace for the shim) in each C object's dependency trace.

## Coverage

Read-only base; own scratch for planted inputs. Full gate + full probes + mutation campaigns reserved to MAIN.
