# Units → tier → contract → evidence (IMPLEMENT — whole product)

Tier law = `CLAUDE.md` Engineering (`kernel` = full adversarial battery; `data` = structural validator + live spot-check; `docs` = consistency pass). Closing review (U13) = every lens of `.agent/review.md` over the whole diff; mutation credit = `node tools/mutate.mjs` per tested Lean file (proved code needs none).

| unit | tier | contract | evidence |
|---|---|---|---|
| U1 foundation | kernel (gate) | `.claude/rules/ops.md` | `tools/gate.sh` + `tools/gate-probe.sh` (each purpose-built check fires) |
| U2 kernel contract | kernel | `kernel.md` | consultant-1 (2 rounds) before code |
| U3 codec + decoder + schema | kernel | `kernel.md` § Decode | Tests Json/Decode/Schema + schema corpus; mutation Json, Decode, Encode |
| U4 checker, lints, receipts, review | kernel | § Well-formedness (proved), Lints, Receipts, Review | proofs `CheckAcceptsExactlyWellFormed`, `CheckViolationsSound`; Tests Check/Receipt/Digest; mutation Check, Lint, Receipt, Digest |
| U5 engine | kernel | § Effective status → Plans, Outcome guarantees | 21 Spec claims proved + replayed; Tests Engine (witnesses); mutation Engine (unproved parts), Evaluate, Model |
| U6 CLI + data folder + text | kernel (shell) | § Decode exit codes, CLI projections; `README.md` Commands | Tests Cli/CliStore/Args + `tests/cli/smoke.sh`; mutation Cli, Store, Args, Render, Session |
| U7 server | kernel (shell, security) | § Envelope; Decisions GUI access; `.claude/rules/server.md` | Tests Server (decide + native) + e2e; L-SEC; mutation Server, Session |
| U8 GUI | data | Decisions GUI; `.claude/rules/web.md` (display-only) | `web/envelope.js` decoder (structural validator); e2e + axe + reduced motion + palette; operator-1 visual QA |
| U9 export | kernel (shell, security) | Decisions sharing; § actions | Tests Export + e2e export; L-SEC; mutation Export |
| U10 skill + installer | docs (skill) + kernel (installer) | Decisions agent instructions | Tests Cli skillTests + Assets; trial-1 blind live trial |
| U11 examples | data | `.claude/rules/examples.md` | gate `examples` stage + probe; private migration `check --strict` |
| U12 README | docs | `CLAUDE.md` Authoring (human-facing) | L-CLAIM consistency pass |
