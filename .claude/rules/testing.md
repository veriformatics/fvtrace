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
---

# Test form (template Engineering `Tests/verification`)

- A predicate that a `Fvtrace/Proofs*` theorem proves needs no property test: the theorem covers the whole input domain (as for mutation credit, `lean.md`). Tested code's contract predicates (`kernel.md` ids marked tested) take property form in every new or changed test: a seeded generator, the seed fixed in the suite + printed with each failure (`Tests/Differential.lean` `seed`; `tests/engine/cases.mjs` via `FVTRACE_ENGINE_SEED`, default fixed); a failing generated case joins the examples.
- Fuzz targets: none yet. The readers of other people's bytes (`Fvtrace/Json.lean` parser, `Fvtrace/Decode.lean`, the what-if + request parsing behind `/api/answer`, the page engine's snapshot load) + the C (`c/fvtrace_digest.c`, `c/page_engine.c`) owe coverage-guided targets = `.agent/deferred.md` row "Fuzz targets"; the existing suites' forms = row "Property-test audit".
