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
- Probe `examples-stale-receipt` (a line planted in `Fvtrace/Proofs/Plan.lean`) fires.
