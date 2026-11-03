# Trust closure + claim discovery fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
| --- | --- | --- | --- | --- | --- |
| F30 | unknown | `offload run --local -- bash tools/gate-probe.sh trust` @3957c87 + new probes → `trust-ctor: DID NOT FIRE (rc=0)`, 27 claims/0 findings | unknown | Repository-wide Lean scan → `TrustMain.lean` only; semantic closures share `meaningDeps`, claim types normalize; direct capability scan unchanged | unknown |
| F35 | unknown | same @3957c87 + new probes → `trust-alias`, `trust-alias-def`, `trust-alias-irreducible: DID NOT FIRE (rc=0)`, 26 claims/0 findings | unknown | Repository-wide Lean scan → `TrustMain.lean` only; semantic closures share `meaningDeps`, claim types normalize; direct capability scan unchanged | unknown |

## Mechanism

- F30 → proof escape closure shares `meaningDeps` with statement closure/fingerprints: types + definition values + inductive constructors. Referenced recursors receive the generic type traversal; referenced `casesOn` definitions receive type/value traversal. Inference from the dependency contract: no reverse edges from an inductive to unused eliminators are needed. Its constructor signatures determine its meaning; generated recursor reduction is within Lean's trusted kernel, while unused `casesOn` code is outside the statement's dependency closure. Theorem bodies remain unwalked; `collectAxioms` remains unchanged.
- F35 → `Meta.whnf` with transparency `.all`, then `Sort 0` classification. `abbrev`, ordinary `def` + irreducible aliases cannot hide claims; declaration-kind filtering still separates claims from theorem/equation proofs.
- Live unchanged-tree audit: `lake exe fvtrace-trust` → rc=0, 26 claims/0 findings. Direct bare-binary invocation initially lacked Lake's module path (`unknown module prefix Fvtrace`); the recorded `lake exe` invocation resolves it.
- Red evidence: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-4/red-probes-final.log` + `.rc` (1). Original four trust probes fired; four added probes did not fire (their underlying audits rc=0). First irreducible plant was ill-typed; explicit unfolding corrected the fixture before the credited red run.
- Completed probes: `bash tools/gate-probe.sh trust capability replay_policy trust_cache` → rc=0, 17 passed/0 failed. Includes all original trust plants, four new plants, capabilities, replay policy + cache controls.
- LSP coverage unavailable for `.lean`; actual Lean compilation validates API/type correctness. `shellcheck -x tools/gate-probe.sh` + `git diff --check` → rc=0 (plain standalone shellcheck needed source following; the gate supplies every shell file as an input).

## Needs MAIN

None.
