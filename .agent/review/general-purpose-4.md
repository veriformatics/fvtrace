# Trust closure + claim discovery fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
| --- | --- | --- | --- | --- | --- |
| F30 | `3a613b2` | `offload run --local -- bash tools/gate-probe.sh trust` @3957c87 + new probes → `trust-ctor: DID NOT FIRE (rc=0)`, 27 claims/0 findings | Trust probes 17/17; audit 26 claims/0 findings; `trust.sh` rc=0 (6 kernels, 26 proofs, 12 statement replays); closing fast gate rc=0 (175.2 s), after MAIN's baseline lint repair | Repository-wide Lean scan → `TrustMain.lean` only; semantic closures share `meaningDeps`, claim types normalize; direct capability scan unchanged | fixed |
| F35 | `3a613b2` | same @3957c87 + new probes → `trust-alias`, `trust-alias-def`, `trust-alias-irreducible: DID NOT FIRE (rc=0)`, 26 claims/0 findings | Trust probes 17/17; audit 26 claims/0 findings; `trust.sh` rc=0 (6 kernels, 26 proofs, 12 statement replays); closing fast gate rc=0 (175.2 s), after MAIN's baseline lint repair | Repository-wide Lean scan → `TrustMain.lean` only; semantic closures share `meaningDeps`, claim types normalize; direct capability scan unchanged | fixed |
| F71 | unknown | unknown | unknown | unknown | unknown |

## Mechanism

- F30 → proof escape closure shares `meaningDeps` with statement closure/fingerprints: types + definition values + inductive constructors. Referenced recursors receive the generic type traversal; referenced `casesOn` definitions receive type/value traversal. Inference from the dependency contract: no reverse edges from an inductive to unused eliminators are needed. Its constructor signatures determine its meaning; generated recursor reduction is within Lean's trusted kernel, while unused `casesOn` code is outside the statement's dependency closure. Theorem bodies remain unwalked; `collectAxioms` remains unchanged.
- F35 → `Meta.whnf` with transparency `.all`, then `Sort 0` classification. `abbrev`, ordinary `def` + irreducible aliases cannot hide claims; declaration-kind filtering still separates claims from theorem/equation proofs.
- Live unchanged-tree audit: `lake exe fvtrace-trust` → rc=0, 26 claims/0 findings. Direct bare-binary invocation initially lacked Lake's module path (`Fvtrace` module prefix absent); the recorded `lake exe` invocation resolves it.
- Red evidence: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-4/red-probes-final.log` + `.rc` (1). Original four trust probes fired; four added probes did not fire (their underlying audits rc=0). First irreducible plant was ill-typed; explicit unfolding corrected the fixture before the credited red run.
- Completed probes: `bash tools/gate-probe.sh trust capability replay_policy trust_cache` → rc=0, 17 passed/0 failed. Includes all original trust plants, four new plants, capabilities, replay policy + cache controls.
- LSP coverage unavailable for `.lean`; actual Lean compilation validates API/type correctness. `shellcheck -x tools/gate-probe.sh` + `git diff --check` → rc=0 (plain standalone shellcheck needed source following; the gate supplies every shell file as an input).

## Verification

- `bash tools/trust.sh` → rc=0. Lean default, Lean paranoid, lean4lean, nanoda, con-leche + con-ron all accept 26 proofs; 12/12 self-trace statement replays pass.
- Second `bash tools/trust.sh` → rc=0, replay skipped for new passing key `dcd23fbbed7f3c2417bff914fcde6eca723cb46e2620e5f80c3ce59b6ab30be1`. Old/new key comparison → `cmp` rc=1 (expected difference); recomputed key vs passing record → `cmp` rc=0. `tools/trust.sh:40` still hashes `TrustMain.lean`.
- `bash tools/fast-gate.sh` → rc=1, exactly `js-lint` fails. Passed: lean-build, lean-test (1834/1834), lean-pure (779/779), cli, examples, engine, lean-style, js-format, js-types, js-test (64/64), fanout, spec, shell, meta. Wall 312.5 s. Skipped by fast gate: tools, trust (separately passed), c-analyze, vendor, audit, secrets, workflows, e2e. Full gate/CI not run; MAIN owns integration.
- Logs + on-the-spot rc files: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-4/green-{probes,trust,trust-cached,fast-gate}.{log,rc}`. Source diff whitespace rc=0. Worktree source delta = only allowed three files.

## Needs MAIN

None. Inherited fast-gate lint blocker resolved through MAIN's directive: cherry-picked `e1fbcf7` as `d7d9dc8` (the access test alone). Original failure: `tests/e2e/access.spec.js:160:14 eslint(no-await-in-loop)`; parent/worktree SHA-256 before repair both `7ecba9060f9f1f97d7c8472486c161bc357e5597cb8b9bdc1d99b5d51240af85`. The first fast gate was bundled into a heavy run; the closing rerun runs DIRECT as instructed. No grading check changed. Closing `bash tools/fast-gate.sh` → rc=0, 175.2 s, every listed stage passes (1834 native + 779 pure checks, 64 JS tests). Evidence: `green-fast-gate-final.log` + `.rc` in the evidence folder above.

## Delivery

- Branch `wt/general-purpose-4`; own fix `3a613b2c3a0adcae828f443f2590b6915b0ed9b6`; separate parent `d7d9dc8` = MAIN's baseline lint fix `e1fbcf7`.
- Own changes: `TrustMain.lean` (normalized claim types + shared constructor-aware closure); `tools/gate-probe.sh` (four regression plants); `.claude/rules/lean.md` (document normalized types + constructor dependencies + probe invocations). `tools/trust.sh` unchanged.
- Intent / `CLAUDE*.md` / `.claude/agents/` edits = none. Full gate/CI remains MAIN's integration check.

