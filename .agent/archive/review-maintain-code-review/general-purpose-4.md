# Trust audit + replay-cache fixes

| id | commit sha | red command → output (short) | green command → result | sweep | status |
| --- | --- | --- | --- | --- | --- |
| F30 | `3a613b2` | `offload run --local -- bash tools/gate-probe.sh trust` @3957c87 + new probes → `trust-ctor: DID NOT FIRE (rc=0)`, 27 claims/0 findings | Trust probes 17/17; audit 26 claims/0 findings; `trust.sh` rc=0 (6 kernels, 26 proofs, 12 statement replays); closing fast gate rc=0 (175.2 s), after MAIN's baseline lint repair | Repository-wide Lean scan → `TrustMain.lean` only; semantic closures share `meaningDeps`, claim types normalize; direct capability scan unchanged | fixed |
| F35 | `3a613b2` | same @3957c87 + new probes → `trust-alias`, `trust-alias-def`, `trust-alias-irreducible: DID NOT FIRE (rc=0)`, 26 claims/0 findings | Trust probes 17/17; audit 26 claims/0 findings; `trust.sh` rc=0 (6 kernels, 26 proofs, 12 statement replays); closing fast gate rc=0 (175.2 s), after MAIN's baseline lint repair | Repository-wide Lean scan → `TrustMain.lean` only; semantic closures share `meaningDeps`, claim types normalize; direct capability scan unchanged | fixed |
| F71 | `cef23ac` | `trust_cache` @3a613b2 + new probes → rc=1, 3 pass/2 fail (changed + missing consumer both helper rc=0); reviewer-43 live witness adapted to own worktree → trust skips rc=0, forced statements fail 0/12 | Same live witness rc=0; closing probes 13/13; DIRECT fast gate rc=0 (234.7 s); full trust rc=0 (6 kernels/26 proofs, 12 statements), then cache-hit rc=0 | Single `replay_key` + main caller; native path matches `statements`; key law in ops.md | fixed |

## F30/F35 mechanism

- F30 → proof escape closure shares `meaningDeps` with statement closure/fingerprints: types + definition values + inductive constructors. Referenced recursors receive the generic type traversal; referenced `casesOn` definitions receive type/value traversal. Inference from the dependency contract: no reverse edges from an inductive to unused eliminators are needed. Its constructor signatures determine its meaning; generated recursor reduction is within Lean's trusted kernel, while unused `casesOn` code is outside the statement's dependency closure. Theorem bodies remain unwalked; `collectAxioms` remains unchanged.
- F35 → `Meta.whnf` with transparency `.all`, then `Sort 0` classification. `abbrev`, ordinary `def` + irreducible aliases cannot hide claims; declaration-kind filtering still separates claims from theorem/equation proofs.
- Live unchanged-tree audit: `lake exe fvtrace-trust` → rc=0, 26 claims/0 findings. Direct bare-binary invocation initially lacked Lake's module path (`Fvtrace` module prefix absent); the recorded `lake exe` invocation resolves it.
- Red evidence: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-4/red-probes-final.log` + `.rc` (1). Original four trust probes fired; four added probes did not fire (their underlying audits rc=0). First irreducible plant was ill-typed; explicit unfolding corrected the fixture before the credited red run.
- Completed probes: `bash tools/gate-probe.sh trust capability replay_policy trust_cache` → rc=0, 17 passed/0 failed. Includes all original trust plants, four new plants, capabilities, replay policy + cache controls.
- LSP coverage unavailable for `.lean`; actual Lean compilation validates API/type correctness. `shellcheck -x tools/gate-probe.sh` + `git diff --check` → rc=0 (plain standalone shellcheck needed source following; the gate supplies every shell file as an input).

## F30/F35 verification

- `bash tools/trust.sh` → rc=0. Lean default, Lean paranoid, lean4lean, nanoda, con-leche + con-ron all accept 26 proofs; 12/12 self-trace statement replays pass.
- Second `bash tools/trust.sh` → rc=0, replay skipped for new passing key `dcd23fbbed7f3c2417bff914fcde6eca723cb46e2620e5f80c3ce59b6ab30be1`. Old/new key comparison → `cmp` rc=1 (expected difference); recomputed key vs passing record → `cmp` rc=0. `tools/trust.sh:40` still hashes `TrustMain.lean`.
- `bash tools/fast-gate.sh` → rc=1, exactly `js-lint` fails. Passed: lean-build, lean-test (1834/1834), lean-pure (779/779), cli, examples, engine, lean-style, js-format, js-types, js-test (64/64), fanout, spec, shell, meta. Wall 312.5 s. Skipped by fast gate: tools, trust (separately passed), c-analyze, vendor, audit, secrets, workflows, e2e. Full gate/CI not run; MAIN owns integration.
- Logs + on-the-spot rc files: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-4/green-{probes,trust,trust-cached,fast-gate}.{log,rc}`. Source diff whitespace rc=0. Worktree source delta = only allowed three files.

## Needs MAIN

None. Inherited fast-gate lint blocker resolved through MAIN's directive: cherry-picked `e1fbcf7` as `d7d9dc8` (the access test alone). Original failure: `tests/e2e/access.spec.js:160:14 eslint(no-await-in-loop)`; parent/worktree SHA-256 before repair both `7ecba9060f9f1f97d7c8472486c161bc357e5597cb8b9bdc1d99b5d51240af85`. The first fast gate was bundled into a heavy run; the closing rerun runs DIRECT as instructed. No grading check changed. Closing `bash tools/fast-gate.sh` → rc=0, 175.2 s, every listed stage passes (1834 native + 779 pure checks, 64 JS tests). Evidence: `green-fast-gate-final.log` + `.rc` in the evidence folder above.

## F30/F35 delivery

- Branch `wt/general-purpose-4`; own fix `3a613b2c3a0adcae828f443f2590b6915b0ed9b6`; separate parent `d7d9dc8` = MAIN's baseline lint fix `e1fbcf7`.
- Own changes: `TrustMain.lean` (normalized claim types + shared constructor-aware closure); `tools/gate-probe.sh` (four regression plants); `.claude/rules/lean.md` (document normalized types + constructor dependencies + probe invocations). `tools/trust.sh` unchanged.
- Intent / `CLAUDE*.md` / `.claude/agents/` edits = none. Full gate/CI remains MAIN's integration check.

## F71 mechanism + evidence

- Key adds SHA-256 of `.lake/build/bin/fvtrace`, exactly the program `statements` runs. Full binary = all CLI/Replay/receipt/codec modules without an error-prone module list. Main returns nonzero when a required key input cannot be hashed.
- Regression targets = `trust_cache`: mutate consumer bytes → prior key must miss; remove consumer → key generation must fail. Existing hit/export-change/no-record controls remain unchanged. Target files restored + re-hashed by the probe harness.
- Red live witness = reviewer-43's `red-trust-key.py`, with only scratch/tree bindings redirected to owned paths; `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-4/f71-live-red.py`. Unfixed `Replay.reasons` plant (`d == r.digest` → `d != r.digest`) yields trust rc=0 + `skipped`; forced statements rc=1, 0/12 pass. Source + native binary restored byte-identically; library restore build passed.
- Red logs: `f71-red-live.log`, `f71-red-probes-final.log` + corresponding `.rc` in the evidence folder. Green targeted controls: `bash tools/gate-probe.sh trust_cache replay_policy` → rc=0, 8 passed/0 failed; `shellcheck -x tools/trust.sh tools/gate-probe.sh` → rc=0. Prime full `tools/trust.sh` → rc=0: all six kernels accept 26 proofs, 12/12 statements pass under the new key. Same live witness on fixed code → oracle rc=0: trust replays all 26 proofs (six kernels accept), then fails 0/12 receipts (trust rc=1, expected), rather than skipping; direct statements fail 0/12 as before. No passing cache record remains after that refusal; source/native bytes restore exactly. Closing verification → all rc=0: `bash tools/gate-probe.sh trust_cache trust` (13 passed/0 failed), DIRECT `bash tools/fast-gate.sh` (234.7 s; 1834 native + 779 pure checks), full `bash tools/trust.sh` (all six kernels accept 26 proofs; 12/12 statements pass), second `bash tools/trust.sh` (cache hit). Current key `5b3643f93c2d78ebd3b38397671baf0812dbd0950c534c068b30d158a6704a4e` equals the passing record (`cmp` rc=0). Driver + every stage have on-the-spot rc files. Fast skipped tools, trust (separately passed), c-analyze, vendor, audit, secrets, workflows + e2e. Full gate/CI remains MAIN's integration check.

## F71 delivery

- Commit `cef23ac1fe5f45579776d69e01f853b7cb98c104` on `wt/general-purpose-4`; worktree clean. Own patch = `tools/trust.sh`, `tools/gate-probe.sh`, `.claude/rules/ops.md` (add native-consumer SHA to the documented key inputs).
- Evidence prefix: `/home/eturkes/Projects/fvtrace/.scratch/fix/general-purpose-4/f71-`; closing logs `closing-probes`, `fast-gate`, `trust-replay`, `trust-cached`, `finish` (`.log` + `.rc`). All background verification jobs ended.
- Needs MAIN = none; unwritten scope = none. Intent / `CLAUDE*.md` / `.claude/agents/` edits = none.

general-purpose-4-DONE-2
