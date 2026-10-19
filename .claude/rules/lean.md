---
paths:
  - "Fvtrace/**"
  - "Tests/**"
  - "*.lean"
  - "lakefile.lean"
  - "lean-toolchain"
---

# Lean sources

- Layout: `Fvtrace/Spec*` = the human-read layer: claims as `Prop`-valued `def`s (no proofs, no `theorem`); `Fvtrace/Proofs*` = `theorem name : Spec.Claim := …`, never imported by Spec; implementation modules = the shipped code the claims mention. `fvtrace-trust` fails a claim with no proof, a proof axiom beyond `propext` · `Classical.choice` · `Quot.sound`, an escape hatch (`implemented_by` · `extern` · `unsafe` · `partial` (compiles to `opaque`) · `opaque`) in a proof's closure, or a statement that reaches no non-spec `Fvtrace.*` constant.
- `native_decide` adds a non-standard axiom ⇒ banned in proofs; `decide` / `simp` / `rfl` stay within the standard three. `decide` reduces `String.length` + `≠ ""` on literals, not `String.splitOn`.
- Kernel code is total: structural or `termination_by` recursion. `partial` stays out of every proof closure (`fvtrace-trust` fails one there); outside them it is allowed (IO shells, the JSON printers `Value.beq`/`canonical`/`pretty`).
- `import Lean` (any `Lean.*`, incl. `Lean.Data.Json`) links all of `Lean` (118 MB); shipped modules import `Init` + `Std` alone. `TrustMain.lean` (dev-only `fvtrace-trust`) is the one exception.
- Tests: `Tests/<Area>.lean` exposes `tests : TestM Unit`, wired into `Tests.all`; `Tests.capture` runs CLI code with stdout/stderr captured in-process. `lake test` builds + runs `fvtrace-tests` (rc 0 iff every check passed). CLI tests call `Cli.runIn { home := <temp>, cwd := … }`: `Cli.run` reads the real environment + data folder, and Lean cannot set an environment variable in-process (env behavior = `tests/cli/smoke.sh`). Every command that resolves a project hashes its path (SHA-256 FFI) ⇒ its tests sit in the native suite (`Tests.native`), never `TestPure`.
- Lake target names with `-` are written `«fvtrace-tests»` wherever Lake parses a name (`testDriver`, `lake build`).
- `include_str` reads are invisible to Lake: every embedded file is an `[[input_file]]` named in its library's `needs` (`lakefile.lean`), else an edit leaves the binary carrying the stale copy; `Tests/Assets.lean` holds each embed byte-equal to its file.
- Lean 4.35 `String` API: `trimAscii` (returns a `Slice`), `String.ofList` (not `String.mk`), `drop`/`take` return slices; `at`, `by`, `open`, `unless` are keywords (fields `date`, `reviewer`; constructor `«open»`).
- Mutation credit (Lean ships no mutation tool) = `node tools/mutate.mjs <file.lean> [--lines A-B]`: default operators (comparison, boolean, `+`/`-`, `!`, integer literal +1) one site at a time, `.olean` build + suite per mutant (default: interpreted `lake env lean --run TestPure.lean`; native-suite code: `--test "lake test"`), survivors listed. It rewrites the file in place ⇒ run it in a scratch copy of the tree (`rsync` to `.scratch/<dir>`, own `.lake`), from a shell whose every command names that copy by absolute path; edits to the primary tree go by absolute path too. A proved theorem pins behavior for every input: proved code needs no mutation credit, tested code does.
