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

# Units → tier → contract → evidence (IMPLEMENT — GUI)

| unit | tier | contract | evidence |
|---|---|---|---|
| U1 contract delta | kernel | `kernel.md` (must-verify kinds, gate, restates, fields, verdict words, G12, G13) | consultant-2 before code |
| U2 must-verify kinds + verdict words | kernel | § Model `allows` + `ceiling f`, WF-route, S-override, S-state gate, G5, G6, G12, G13 | Spec claims proved + replayed (`fvtrace-trust`); Tests Engine/Check/Cli + CLI smoke red on the unfixed engine; mutation credit for tested changes (`Overrides.parse`, CLI text) |
| U3 `why` / `headline` / `restates` | kernel | § Model shapes, WF-entail, Receipts (`restatedBy`), envelope | WF proofs (`CheckAcceptsExactlyWellFormed`, `CheckViolationsSound`) + schema corpus (Node + Lean halves) + Tests Decode/Receipt/Evaluate; mutation credit (Decode, Encode, Receipt, Evaluate) |
| U4 export bundler | kernel (shell, security) | export page = the GUI's modules bundled, imports resolved, nothing else | Tests/Export red on the ported `app.js`; mutation credit (Export) |
| U5 GUI | data | Decisions GUI; `.claude/rules/web.md` | `web/envelope.js` decoder; e2e + axe + reduced motion + palette; operator visual QA |
| U6 examples + docs | data (examples) + docs | `.claude/rules/examples.md`; `CLAUDE.md` Authoring | gate `examples`; consistency pass (L-CLAIM) |

# Units → tier → contract → evidence (MAINTAIN — deferred rows)

| unit | tier | contract | evidence |
|---|---|---|---|
| plan search (branch and bound) | kernel | `kernel.md` § Plans (search, bound, skip rule, closure early exit) | `search_eq` + `best_eq_ref` (search = the exhaustive fold) ⇒ G4a + G4b unchanged; `fvtrace-trust` + independent replay; consultant-3 before code; Tests/Engine `scaleTests` (red: the old engine times out) |
| portability (CRLF checkout) | kernel (gate) | `.gitattributes`; `.claude/rules/lean.md` Tests | Windows CI log (bundler + `Tests/Assets` on CRLF); local `core.autocrlf=true` clone: 20 FAIL before, LF after; Tests/Harness keeps every area's record past an exception; owed: both portability jobs green on the push |
| plan notes for violated needs | kernel (shell: CLI text) + data (GUI) | `kernel.md` § Plans coverage (uncovered needs); `.claude/rules/web.md` (display of engine fields) | CLI test + e2e case on the fixture under `#whatif=O1=violated`, both red on the unfixed code; screenshot of C1's details |
