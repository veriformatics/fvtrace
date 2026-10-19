# IMPLEMENT — whole product (closed)

- [x] e85e50c U1 Foundation: Lake package `fvtrace` + `fvtrace --version` + one passing test; dev manifests; `tools/gate.sh` (every stage + scanners) + fast gate; CI + update automation; `.claude/rules/` gate law
- [x] 649f492 U2 Kernel contract: `.agent/contracts/kernel.md` + `Fvtrace/Spec` statements (consultant-1, two rounds, before code)
- [x] 2467416 U3 JSON codec + trace decoder (all errors, paths) + JSON Schema; mutation credit (Decode, Encode, Json) in U13
- [x] 2467416 U4 Trace checker (proved) + lints/waivers + evidence binding (HACL* SHA-256, digest cache, `pin`) + review digest; mutation credit (Check, Lint, Receipt, Digest) in U13
- [x] 139ae12 U5 Engine + proofs (a185db9 … 2545acf: 21 claims proved, six kernels replay): states, entailment, subjects, exclusions, what-if, ranking + blockers, experiments, plans; mutation credit (Engine, Evaluate, Model) in U13
- [x] a20feab U6 CLI + data folder + text rendering (+ d9370d9 interpreted-suite guard)
- [x] 87c479a U7 Server: `Std.Http`, token + Host allowlist + CSP/Trusted Types, evaluation API (no file-serving route)
- [x] 1a63833 U8 GUI: claim circuits on the engine's output, e2e + axe + reduced motion + palette, visual QA (operator-1: fixes 5353708 + 9884777)
- [x] 5353708 U9 Export: HTML + bundle
- [x] 3d885af U10 Agent skill + installer (5353708); blind live trial on veriformatics `studies/naoto` (trial-1)
- [x] 3d885af U11 Examples: self-trace + synthetic study (5353708); private tau × amyloid migration (migrator-1), outside the repo
- [x] 9884777 U12 README + docs; prototype retired (tag `prototype-gui`)
- [x] 3d885af U13 Closing review: lenses L-CORR (reviewer-1, 13 findings), L-CLAIM (reviewer-2, 11), L-GAP (reviewer-3, 9), L-LAW (reviewer-4, 8), L-SEC (MAIN, 7); fixes 3d885af + 38bb2e9; re-review reviewer-5 (36 closed); mutation campaigns on the final code + survivor tests (0668c2b … 07d29f0); L-HARD reviewer-6 + reviewer-7
- [x] U14 Close: Artifacts, Decisions (each implemented; deferrals in `.agent/deferred.md`), Tasks, Phase → MAINTAIN (the commit that adds this file)

## Closing review (ledger `.agent/review.md`)

Lenses fixed before reading the 9884777 diff; every finding row closed against its acceptance check (re-review round) or registered; L-SEC by MAIN alone. Mutation credit: every tested Lean file on bytes identical to the closing code, survivors ruled by L-HARD.
