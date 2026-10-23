---
paths:
  - "examples/**"
  - "Fvtrace/Spec/**"
  - "Fvtrace/Proofs/**"
  - "Fvtrace/Server.lean"
  - "Tests/Server.lean"
  - "tools/vendor-hacl.sh"
  - "c/fvtrace_digest.c"
---

# Examples

- `examples/fvtrace/trace.json` = fvTrace's own claims, each fact pinned to the Spec + Proofs files (or code + tests) that back it; `examples/synthetic/` = the synthetic study with its tiny project folder. Gate stage `examples` runs `fvtrace check --strict` on both: valid, every warning waived, every receipt current.
- Editing a file the self-trace names stales its receipt (the stage fails, by design: the trace claims what the current proofs say). After the gate's `trust` stage passes on the edit, re-pin: `.lake/build/bin/fvtrace pin --trace examples/fvtrace/trace.json --project .` and commit the trace with the edit. A new or renamed Spec claim the self-trace cites → update its fact + `statement`, then re-pin.
- The README's self-trace section states its verdicts; `Tests/Engine.lean` `acceptanceTests` pins them (C1, C3–C6, C8, C9 Fully supported; C2 + C7 Pending verification): a change to the self-trace that moves one updates both.
- Each proof fact (P*) replays its statement fingerprint (`bash tools/statement.sh <Spec claim>`). A change to a definition a statement reads (engine, model) changes it: the `trust` stage fails until the replay outputs are re-pinned with `.lake/build/bin/fvtrace pin --replay --trace examples/fvtrace/trace.json --project .` (≈ 1 min), committed with the edit once the change is intended.
- Probe `examples-stale-receipt` (a line planted in `Fvtrace/Proofs/Plan.lean`) fires.
