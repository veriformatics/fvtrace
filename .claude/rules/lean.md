---
paths:
  - "Fvtrace/**"
  - "Tests/**"
  - "*.lean"
  - "lakefile.toml"
  - "lean-toolchain"
---

# Lean sources

- Layout: `Fvtrace/Spec*` = the human-read layer: claims as `Prop`-valued `def`s (no proofs, no `theorem`); `Fvtrace/Proofs*` = `theorem name : Spec.Claim := …`, never imported by Spec; implementation modules = the shipped code the claims mention. `fvtrace-trust` fails a claim with no proof, a proof axiom beyond `propext` · `Classical.choice` · `Quot.sound`, an escape hatch (`implemented_by` · `extern` · `unsafe` · `partial` (compiles to `opaque`) · `opaque`) in a proof's closure, or a statement that reaches no non-spec `Fvtrace.*` constant.
- `native_decide` adds a non-standard axiom ⇒ banned in proofs; `decide` / `simp` / `rfl` stay within the standard three. `decide` reduces `String.length` + `≠ ""` on literals, not `String.splitOn`.
- Kernel code is total: structural or `termination_by` recursion; `partial` only in IO shells outside every proof closure.
- `import Lean` (any `Lean.*`, incl. `Lean.Data.Json`) links all of `Lean` (118 MB); shipped modules import `Init` + `Std` alone. `TrustMain.lean` (dev-only `fvtrace-trust`) is the one exception.
- Tests: `Tests/<Area>.lean` exposes `tests : TestM Unit`, wired into `Tests.all`; `Tests.capture` runs CLI code with stdout/stderr captured in-process. `lake test` builds + runs `fvtrace-tests` (rc 0 iff every check passed).
- Lake target names with `-` are written `«fvtrace-tests»` wherever Lake parses a name (`testDriver`, `lake build`).
