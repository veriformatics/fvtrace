---
paths:
  - "Tests/**"
  - "tests/**"
  - "TestMain.lean"
  - "TestPure.lean"
  - "Fvtrace/Json.lean"
  - "Fvtrace/Decode.lean"
  - "Fvtrace/Request.lean"
  - "Fvtrace/Server.lean"
  - "Fvtrace/Snapshot.lean"
  - "c/**"
  - "FvtraceFuzz.lean"
  - "FuzzMain.lean"
  - "tools/fuzz.sh"
  - "tools/fuzz/**"
---

# Test form (template Engineering `Tests/verification`)

- A predicate that a `Fvtrace/Proofs*` theorem proves needs no property test: the theorem covers the whole input domain (as for mutation credit, `lean.md`). Tested code's contract predicates (`kernel.md` ids marked tested) take property form in every new or changed test: a seeded generator, the seed fixed in the suite + printed with each failure (`Tests/Differential.lean` `seed`; `tests/engine/cases.mjs` via `FVTRACE_ENGINE_SEED`, default fixed); a failing generated case joins the examples.
- Fuzz targets = `FvtraceFuzz.lean` (dev-only lib; never in `fvtrace`): `json` (`Json.parse`: parse → canonical → parse, the input's own characters as a string + key round-trip, its leading hex digits as a `\u` escape against a code point computed apart from the parser), `decode` (G-codec + WF check), `request` (V-request + item round-trip), `page` (`c/page_engine.c`'s load + answer; the replay calls the Lean entries it wraps), `digest` (`c/fvtrace_digest.c`: sliced updates = one update). Each returns 0 or the broken property's code; crash-only parts rely on `LEAN_ABORT_ON_PANIC` + the sanitizers. Campaign = `bash tools/fuzz.sh run TARGET SECONDS` (libFuzzer, system clang, ASan + UBSan, linked as `leanc` links; leaks off: the runtime keeps GMP limbs) = CI `fuzz.yml` (daily, 600 s per target; crash input → job artifact). Per commit = gate `fuzz` (`fvtrace-fuzz replay tests/fuzz`: every file under `tests/fuzz/<target>/`, unsanitized, same Lean code; probe `fuzz`: a planted `\n` decode bug + its crash input → FAIL naming target + file). A crash found → fix its cause, then pin the input as `tests/fuzz/<target>/<name>` (with `json.dict` = the json + decode dictionary). Detection: a `\n` decoded off by one → found on input 2 from an empty corpus; surrogate-pair arithmetic off by one → 329 370 inputs (120 s); the parse → print → parse check alone missed the `\n` plant in 4.1 M inputs.
- Property-test audit = `.agent/deferred.md` row "Property-test audit".
