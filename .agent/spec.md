## Intent

fvTrace is a tool to help analyzers of scientific data understand what claims they can and cannot make. In this context, "fv" is short for "formal verification". We take the stance that a claim can only be made if it is formally verified. In any existing analysis, where no formal verification work has been performed yet, this tool can identify where such work can be applied, and if verified, what resultant claims can be made. This is the basic premise but it can be extended. In general, the tool should help users navigate what their scientific questions are, what gaps that need filling in order to answer those questions, and help ensure nothing is overstated. It can also be used to help identify directions and associated relationships that a user might have overlooked or understated, which become relevant if certain facts about the current analysis are true (or can be verified to be true).

Users will interact with fvTrace through a CLI and web-accessible GUI. If fvTrace will use LLM-inference to help accomplish its goals, it should come with instructions so that it can be used from within a user's existing coding agent session.

## Artifacts

- `lakefile.toml` = Lake package `fvtrace` (Lean 4.35, `lean-toolchain`): library `Fvtrace` (`Fvtrace/Spec*` = human-read claims, `Fvtrace/Proofs*` = their proofs), shipped binary `fvtrace` (`Main.lean`), tests `fvtrace-tests` (`TestMain.lean` + `Tests/`), dev-only audit `fvtrace-trust` (`TrustMain.lean`). Run: `lake build fvtrace && .lake/build/bin/fvtrace --version`; tests: `lake test`.
- `tools/gate.sh` = the one gate (local + CI); `tools/fast-gate.sh` = iteration; `tools/gate-probe.sh` = positive controls; law = `.claude/rules/ops.md`.
- `web/` = GUI sources (no-build ES modules), embedded into the binary; dev-only JS toolchain = `package.json` + `pnpm-lock.yaml`.
- `prototype/gui/` = PROTOTYPE GUI (retires at IMPLEMENT close → tag `prototype-gui`): stdlib server + engine + fixture + claim circuits. Run: `uv run prototype/gui/serve.py` → http://127.0.0.1:8642/.

## Decisions

- Product = local OSS tool over one project folder (user ruling): reads the analysis (code, data, microscopy, manuscripts) and never writes into it; fvTrace's own files (trace, review record, digest cache) live in its data dir (`FVTRACE_HOME`, else the platform data dir `/fvtrace/<project>/`), `--trace` overrides. Hosted multi-user service = separate paid product, other repo.
- Stack (user ruling: fvTrace must itself exemplify FV) = Lean 4.35 throughout: one native binary (engine, trace checker, CLI, local HTTP server on `Std.Http`). Kernel semantics proved in Lean against a human-readable spec module; gate = axiom audit + independent-kernel replay of every proof. Own JSON codec on `Std` (`Lean.Data.Json` links all of `Lean`: 118 MB binary, measured). SHA-256 = vendored HACL* verified C over FFI (pure Lean measured 13 MB/s vs coreutils 276 MB/s). GUI = no-build ES modules typed by JSDoc, display only: every verdict, ranking + plan it shows comes from the engine. Dev-only Node toolchain (TypeScript 7 checkJs, oxlint, Prettier, stylelint, html-validate, Playwright + axe).
- GUI access: `fvtrace serve` binds loopback with a per-run token (cookie after first load) + Host allowlist; `--host` opts into LAN with the same token. Sharing (user ruling: both): `fvtrace export --html` = one self-contained page, verdicts + every one-click what-if precomputed by the engine; `--bundle` = trace + copies of its pinned evidence for a colleague's own `fvtrace serve`.
- Trace format = JSON (`"fvtrace": 1`) + JSON Schema printed by `fvtrace schema` (MAIN ruling: a YAML parser would enlarge the verified binary's trusted base).
- Trace model = questions → claims → obligations (facts) + subjects + experiments + exclusions + waivers + review. Obligation = one fact + `kind` + `status` + `route` (`lean`, `runtime-checker`, `refinement`, `human-ruling`, `empirical`) + evidence + trusted base + subject.
- FV stance: verified = `proved` | `checked` (proved checker accepted the actual object). `assumed` = declared premise ⇒ claim only in conditional form. `tested` | `open` = gaps. `violated` ⇒ claim cannot be made as written.
- Claim state = `cannot` (a need violated, incl. derived; needs both sides of an exclusion; or a conflicting scenario) > `can` (every need verified) > `conditional` (rest assumed) > `open`. Verdict words unchanged: Can claim / On assumption / Not yet / Cannot claim.
- Entailment (user ruling: strict): every claim names one entailment fact ("these needs entail the sentence as worded"), counted as a need ⇒ human-ruled entailment = assumed ⇒ at most On assumption unless proved.
- Evidence binding (user ruling): `proved` | `checked` require artifacts (project-relative path + sha256) + verifier/statement identity; a changed or missing artifact ⇒ effective status `stale` (unverified, shown beside the recorded status); `fvtrace pin` records digests; nothing is executed.
- Review: trace-level record (reviewer, date, digest of all content but the record) ⇒ `draft` (none) | `stale` (digest differs) | `reviewed`; every verdict of a draft or stale trace reads provisional.
- Subjects (user ruling): every fact + claim binds to a subject (the existing analysis or a dataset/analysis an experiment would create); an experiment's outcomes touch only its subject's facts ⇒ a new-data experiment lights sibling claims, never existing ones; cross-subject reuse = an explicit instantiation fact.
- Exclusions (user ruling): `excludes` = two facts that cannot both hold on one subject + justification; a verified side derives the other's violation; both sides asserted (verified | assumed, recorded or what-if) ⇒ scenario conflict, flagged; a claim needing both ⇒ cannot.
- Results + lints (user ruling): kind `result` = the observed value/pattern a claim asserts; `fvtrace check` warns per claim level (estimand, descriptive, inferential, causal, release) on missing roles, suppressed only by a recorded waiver with reason.
- Where FV pays = per closable fact (not violated): claims it gates + claims verifying it alone unlocks, ranked by unlocks; violated facts list apart as blockers (reword or new data). `latent` claims = overlooked directions.
- Experiments: `kind` `dry` | `wet`, `effort` hours < days < weeks < months, `success` + `failure` = fact → status maps replayed as what-ifs on the experiment's subject; per experiment `lights` (claims raised into can | conditional), `clears` (cannot → open), `breaks` (failure → cannot); ranked lights > clears > cheaper. A success touching a `result` fact reads "if this result is observed".
- Experiment outcome honesty (scientist-1 rulings): `checked` only via a proved checker on the actual data, `proved` only via a completed proof; empirical support → `assumed` at most; failure = established counterexample, inconclusive → `{}`.
- Plans (user ruling): per claim, a coherent experiment set (one subject, compatible outcomes) reaching the highest state the suggestions allow, cheapest by ordinal effort among those; alternatives per fact + remaining premises listed; labelled coverage, never scientific priority.
- Agent instructions (user ruling): portable Agent Skill embedded in the binary; `fvtrace skills install --agent claude|agents` writes the user-level skills dir by default; the host agent drafts the trace, `fvtrace check` validates, the user's review gates final verdicts; fvTrace never calls an LLM.
- Examples (user ruling): public = fvTrace's own trace (claims about fvTrace backed by its Lean proofs) + a synthetic study; the tau × amyloid trace lives outside the repo as a private local check against the veriformatics `studies/naoto` folder, carrying scientist-2's fixes (O11 split, O20, C6, result facts).
- GUI = claim circuits (ITERATE approval): verdict grouping per question, "Assuming …" text view, experiments + plans, what-if. Manuscript check shelved (user ruling, round 3; possible separate project): tag `prototype-lint` (`.agent/archive/manuscript-check.md`).

## Tasks

- [ ] U1 Foundation: Lake package `fvtrace` + `fvtrace --version` + one passing test; dev manifests; `tools/gate.sh` (every stage + scanners) + fast gate; CI + update automation; `.claude/rules/` gate law
- [ ] U2 Kernel contract: `.agent/contracts/kernel.md` + `Fvtrace/Spec` statements (consultant before code)
- [ ] U3 JSON codec + trace decoder (all errors, paths) + JSON Schema
- [ ] U4 Trace checker (proved) + lints/waivers + evidence binding (HACL* SHA-256, digest cache, `pin`) + review digest
- [ ] U5 Engine + proofs: states, entailment, subjects, exclusions, what-if, ranking + blockers, experiments, plans
- [ ] U6 CLI + data dir + text rendering (phrasing proof)
- [ ] U7 Server: `Std.Http`, token + Host allowlist + CSP/Trusted Types, API, evidence preview
- [ ] U8 GUI: claim circuits on the engine's output, e2e + axe + reduced motion + palette, visual QA
- [ ] U9 Export: HTML + bundle
- [ ] U10 Agent skill + installer; live trial on veriformatics `studies/naoto`
- [ ] U11 Examples: self-trace + synthetic study; private tau × amyloid migration + local check
- [ ] U12 README + docs; prototype retired (tag `prototype-gui`)
- [ ] U13 Closing review (per lens + security) → `.agent/review.md`; fixes
- [ ] U14 Close: Artifacts, Decisions, Tasks, Phase → MAINTAIN
- Deferred queue → `.agent/deferred.md`; PROTOTYPE + ITERATE history → `.agent/archive/`

## Phase

IMPLEMENT — whole product
