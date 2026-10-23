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
| CodeQL code scanning | kernel (CI) | `.claude/rules/ops.md` CI | local CodeQL 2.27.2 pre-scan 0 results; first run on `main` (a948e45, run 39707898418) green, code scanning 0 open alerts (103 JS / 23 actions / 95 C rules) |
| plan search (branch and bound) | kernel | `kernel.md` § Plans (search, bound, skip rule, closure early exit) | `search_eq` + `best_eq_ref` (search = the exhaustive fold) ⇒ G4a + G4b unchanged; `fvtrace-trust` + independent replay; consultant-3 before code; Tests/Engine `scaleTests` (red: the old engine times out) |
| portability (CRLF checkout) | kernel (gate) | `.gitattributes`; `.claude/rules/lean.md` Tests | Windows CI log (bundler + `Tests/Assets` on CRLF); local `core.autocrlf=true` clone: 20 FAIL before, LF after; Tests/Harness keeps every area's record past an exception; parts 2–3: test links through PowerShell, `Store.isLink`/`removeTree`, dangling = missing; both portability jobs green: run 39715363621 (a95c3c8) |
| plan notes for violated needs | kernel (shell: CLI text) + data (GUI) | `kernel.md` § Plans coverage (uncovered needs); `.claude/rules/web.md` (display of engine fields) | CLI test + e2e case on the fixture under `#whatif=O1=violated`, both red on the unfixed code; screenshot of C1's details |
| trust replay cache | kernel (gate) | `.claude/rules/ops.md` trust stage | probes `trust_cache` (a key one export byte off, or no record, replays; same key skips) + the 7 trust/replay probes fire; trust.sh 47.9 s → 5.9 s on an unchanged tree |
| tour card placement | data (GUI) | `.claude/rules/web.md` tour law | e2e walks every step at 1280×720 + 390×844 on the synthetic study + the fixture with violated facts and a missing check (red: 5–6 desktop + 3 phone overlaps); screenshots of all 15 steps at both widths |
| mutation tool: `!·` sites | kernel (gate tool) | `.claude/rules/lean.md` mutation credit | `--list` shows Evaluate.lean:178 (absent before); campaigns over the 5 sites: 5/5 killed, 0 survivors |
| verifier replay | kernel (shell, security) | `kernel.md` § Replay; Decisions Evidence binding (user rulings) | consultant-4 before code (V4 build dependency + V6 sequencing adopted; V2 security ruled by MAIN); schema corpus 7 cases (Node + Lean halves); Tests/Replay 18 checks (fixture verifier = the test binary); self-trace acceptance (`maxRelevant` 20 → 0: receipts current, P6 + P7 replays fail); mutation credit on Replay.lean + the CLI |
| CI engine-build cache | kernel (gate) | `.claude/rules/ops.md` CI; `.claude/rules/wasm.md` CI cache | commit body: zizmor `cache-poisoning` fires on both cache steps under a planted release trigger, none under the real triggers; `gate-probe.sh wasm` on a cache-hit tree; probe `wasm-build-step` (red before `lakefile.lean` was traced); CI miss run + its rerun on a hit + a hit at another commit (`lean-build`, portability); reviewer-1 (R1–R7: F1–F4 fixed) |
| e2e limits | kernel (gate: thresholds, user ruling) | `.claude/rules/web.md` e2e limits | 752ee38 (durations at load ≈ 2.6× + ≈ 3×); 27787a1 body: `tools/e2e-load.sh gate 3` on nixbox, 3 green runs, 1-min load ≥ 12 (1.5 × 8 CPUs) through each e2e stage |

# Units → tier → contract → evidence (IMPLEMENT — export: live what-ifs)

| unit | tier | contract | evidence |
|---|---|---|---|
| U1 spike | — | `.agent/route.md` first unit: build route decided before design | `.agent/archive/wasm-spike.md` (parity, size, timing, determinism, CSP control, Chromium + Firefox + WebKit) |
| U2 contract | kernel | `kernel.md` § Page engine, envelope actions, trusted base | consultant before code |
| U3 receipt split | kernel (refactor) | behavior unchanged: `Binding` + `ReviewState` → `Fvtrace/Receipt/Basic.lean` (Std-free) | unchanged suites green; self-trace re-pinned |
| U4 snapshot | kernel | E-snap, E-eval | Tests/Snapshot: round trip on both examples + fixtures, `evaluate` = native envelope `.pretty` over every action + seeded stacks, problem kinds, damaged + misshapen input; test-binary hook `--evaluate-snapshot`; red first; mutation credit on `Fvtrace/Snapshot.lean` |
| U5 wasm build | kernel (build) | E-build, E-wasm (closure) | Tests/Wasm (lock, platform, manifest, wasm parser, link contract, warnings); probes (archive + manifest digest mismatch, unexpected import, missing or wrong-kind export, new link warning); two clean builds in different folders `cmp`; incremental witness (engine change ⇒ new embedded bytes; rerun reuses); gate timings cold + warm; Renovate extraction test; macOS + Windows = CI run (user push) |
| U6 export page + GUI engine | kernel (shell, security: Export, E-abi bridge + `web/engine.js`) + data (GUI rendering) | E-page, E-abi, E-gui, E-sec; `.claude/rules/web.md` | Tests/Export; differential test (E-wasm classes; Node + Chromium); e2e file:// offline (two-fact stack, linked spec, refused spec, legacy action, engine failure, latest request wins); axe; mutation credit on Export; L-SEC (MAIN) |
| U7 docs + rules | docs | README, skill, SECURITY, rules (web.md exported flow), Decisions | consistency pass (L-CLAIM): proofs of definitions vs tests of the compiled adapter vs export-time receipts |
| U8 closing review | — | lenses fixed before reading | `.agent/review.md` |

# Units → tier → contract → evidence (MAINTAIN — dependency upgrade)

| unit | tier | contract | evidence |
|---|---|---|---|
| pins at latest eligible release | data (pins: the gate runs every tool they feed) | `.claude/rules/deps.md` (release age, user ruling) | CI gate on the commit (run in its body); fast gate + e2e under Node 26.12.1 (signed SHASUMS checked); HACL* `--check` at the new rev rc 0, planted digest rc 1; actionlint planted label rc 1; every `fvtrace` command driven |

# Units → tier → contract → evidence (MAINTAIN — security review)

| unit | tier | contract | evidence |
|---|---|---|---|
| review ledger | — | check set fixed before reading (`.agent/review.md`) | 15 rows adjudicated; scanners at 53bcecc; probes (cookie, HTTP edge cases, slots, bodies, /dev/zero, parser + checker scale) |
| F6 skill ground rule | docs | `skill/fvtrace/SKILL.md` ground rules | `rg` acceptance (53bcecc: rc 1); CI run 39946476496 |
| F3 bounded trace read | kernel (shell) | `kernel.md` D-json (regular file, refused by size before a read, ≤ limit + 1 bytes) | smoke FIFO / device / 64 GiB red on 53bcecc (rc 124 / 1 / 124); Tests/Cli `readTests`; mutation credit (Session.lean) |
| F4 parser bounds | kernel (codec, tested) | `kernel.md` D-json (integers ≤ 20 digits, O(n log n) parse) | Tests/Json 21-digit red on 53bcecc (554/556), `json-scale` red (native rc 124 at 180 s); mutation credit (Json.lean); engine differential (wasm) |
