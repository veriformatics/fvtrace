# Review ledger (MAINTAIN — code review, whole product)

Definitive code review of the implementation at `48bc51d` (code, tests, gates, config, docs). Check set fixed + committed before the first read of the target. Reviewers = `reviewer` teammates over lens × module (kernel modules: two independent reviewers on Correctness); security stays out of their briefs (a security defect met on any lens = MAIN alone). MAIN runs the baseline, adjudicates every row, fixes every finding. Teammate deliverables: `.agent/review/<name>.md` (→ `.agent/archive/review-maintain-code/` at close).

- Contract a finding binds to: `.agent/contracts/kernel.md`, `.agent/spec.md` `Intent` + `Decisions`, `.claude/rules/*`, `CLAUDE.md`, the claims the implementation makes (README, `--help`, SECURITY, skill, comments, `Artifacts`, `units.md` evidence). Anything outside = register entry → `.agent/deferred.md` row + acceptance check.
- Finding = severity (`blocker` · `major` · `minor`) + `file:line` at `48bc51d` + proof: behavior → red test (command + failing output at `48bc51d`); text → anchor bytes `rg -Fn` matches at `48bc51d`. MAIN reruns the proof before ruling (rematch against `git show 48bc51d:<file>`): match → rule; miss → retire.
- Row verdict: `pass` (adjudicated, no finding) · finding ids · `n/a <reason>`; `unknown` = not yet adjudicated (validator: `rg -c '\| unknown \|' .agent/review.md` → 0 at close).
- Finding status: `open` · `fixed <sha>` (acceptance green) · `deferred` (`.agent/deferred.md` row, blocked on the user) · `ruled <reason>` (retired or equivalent) · `routed` (`route.md`).
- Fix law: root cause, then a sweep for the defect class (scripted search, else a teammate) + every instance fixed; one scoped commit per class, gate green at each; law ↔ code mismatch → fix the stale side; a fix touching `Intent`, `Decisions` or a grading check → user ruling first.

## Modules (slice = code + its tests; tier per `units.md`)

| id | tier | code | tests |
|---|---|---|---|
| M-codec | kernel (tested) | `Fvtrace/{Json,Decode,Encode,Digest}.lean`, `schema/trace.schema.json`, `Fvtrace/Proofs/Json.lean` | `Tests/{Json,Decode,Fields,Schema,Digest}.lean`, `tests/schema/` |
| M-check | kernel (proved) | `Fvtrace/{Model,Check,Lint}.lean`, `Fvtrace/Spec/WellFormed.lean`, `Fvtrace/Proofs/Check.lean` | `Tests/Check.lean` |
| M-engine | kernel (proved) | `Fvtrace/{Engine,Present}.lean`, `Fvtrace/Spec/Engine.lean`, `Fvtrace/Proofs/{Engine,Plan,Closure}.lean` | `Tests/{Engine,Details}.lean` |
| M-fast | kernel (proved) | `Fvtrace/{Answers,Lookups,Index,PTree}.lean`, `Fvtrace/Answers/*`, `Fvtrace/Spec/Fast.lean`, `Fvtrace/Proofs/{Answers,Walk,Forest,Agree,PTree,Index,Lookups,Positions,Singleton}.lean` | `Tests/{Differential,Scale}.lean` |
| M-receipt | kernel (shell) | `Fvtrace/{Receipt,Replay}.lean`, `Fvtrace/Receipt/Basic.lean`, `c/fvtrace_digest.c` | `Tests/{Receipt,Replay,Notices}.lean` |
| M-eval | kernel (shell) | `Fvtrace/{Evaluate,Request,Session,Snapshot,Render}.lean` | `Tests/{Evaluate,Snapshot}.lean` |
| M-cli | kernel (shell) | `Fvtrace/{Cli,Args,Store,Assets,Version}.lean`, `Main.lean`, `FvtraceSkill.lean`, `FvtraceWeb.lean`, `Fvtrace/{Spec,Proofs}/Version.lean` | `Tests/{Cli,CliStore,Args,Assets}.lean`, `tests/cli/smoke.sh` |
| M-server | kernel (shell) | `Fvtrace/Server.lean` | `Tests/Server.lean`, `tests/e2e/{access,proxy}.spec.js`, `tests/e2e/fvtrace-server.js` |
| M-export | kernel (build + shell) | `Fvtrace/Export.lean`, `FvtraceEngine.lean`, `FvtraceWasm.lean`, `WasmMain.lean`, `FvtraceWasm/*`, `c/page_engine.c`, `web/{engine,worker}.js`, `tools/{wasm.lock,pin-wasm.sh}`, `tools/wasm/*` | `Tests/{Export,Wasm}.lean`, `tests/engine/`, `tests/e2e/{export,engine}.spec.js` |
| M-gui-a | data | `web/{app,envelope,lookups,find,words,dom}.js` | `tests/e2e/{gui,responsive,smoke}.spec.js` |
| M-gui-b | data | `web/{panels,circuit,lazy,tour}.js`, `web/{index.html,style.css}` | `tests/palette/`, the e2e specs that drive them |
| M-gate | kernel (gate) | `tools/{gate,fast-gate,ci-gate,gate-probe,trust,statement,lean-style,fetch-tools,pin-tool,install-lean,vendor-hacl,e2e-load}.sh`, `tools/{mutate.mjs,tools.lock}`, `TrustMain.lean`, `TestMain.lean`, `TestPure.lean`, `Tests.lean`, `Tests/Harness.lean`, `lakefile.lean`, `.agent/spec-lint`, configs (`package.json`, `.oxlintrc.json`, `tsconfig.json`, `web/tsconfig.json`, `tests/e2e/tsconfig.json`, `stylelint.config.mjs`, `.htmlvalidate.json`, `.prettierrc.json`, `playwright.config.mjs`, `.gitattributes`, `.gitignore`, `.node-version`, `lean-toolchain`) | `tools/gate-probe.sh` (probes) |
| M-scale | gate tool (outside the gate) | `tools/{scale.mjs,scale.sh,scale-gui.mjs,scale-page.mjs,compare.sh}` | gate-probe `scale`, `compare` |
| M-release | kernel (gate + CI) | `tools/release.sh`, `tools/release/*`, `.github/workflows/*`, `.github/actionlint.yaml`, `renovate.json` | `tests/renovate/`, gate-probe `release` |
| M-docs | docs | `README.md`, `SECURITY.md`, `skill/fvtrace/*`, `examples/*`, `tests/fixtures/*`, `.agent/contracts/{kernel,units}.md`, `.agent/spec.md` `Artifacts`, every command's `--help` | — |

## Check set

### B — baseline (MAIN): a red step or failed run = a finding

| id | asks | verdict |
|---|---|---|
| B1 | full gate at `48bc51d`: `main` CI `gate` run (every shard) + `portability` + `codeql` green | unknown |
| B2 | `bash tools/gate-probe.sh` (every probe) fires its named cause | unknown |
| B3 | `lake build fvtrace && .lake/build/bin/fvtrace --help` + `lake test` (Artifacts run + tests) | unknown |
| B4 | every `fvtrace` command driven by its documented invocation on both examples + a fresh project: `init`, `path`, `check`, `pin`, `verify` (`--run`, `--log`), `review`, `claims`, `gaps`, `experiments`, `plan`, `eval` (`--action`, `--details`, `--complete`), `schema`, `skills install\|show`, `export --html\|--bundle`; exit codes + output vs README | unknown |
| B5 | `fvtrace serve` (+ `--token-file`, `--no-browser`): GUI loaded, a what-if, details, tour, Diagrams \| Text; screenshot inspected | unknown |
| B6 | exported page in a browser (file://): recorded view, a stacked what-if run by the page engine, details; a bundle served by a colleague's `serve` | unknown |
| B7 | dev tools driven: `tools/fast-gate.sh`, `tools/ci-gate.sh` (on the first fix), `tools/compare.sh` (HEAD vs HEAD), `tools/release.sh package\|check` (this host), `node tools/mutate.mjs --list`, `tools/vendor-hacl.sh --verify`, `tools/pin-wasm.sh` + `tools/pin-tool.sh` re-pin at the pinned versions = no diff, `.agent/spec-lint` | unknown |
| B8 | `bash tools/scale.sh --assert` on the reference host (kernel.md P-bound + U-time) | unknown |
| B9 | `bash tools/e2e-load.sh gate <runs>` on a host loaded ≥ 1.5× its CPUs (the pool host `CLAUDE.local.md` names): the e2e limits hold | unknown |
| B10 | release workflow driven without a publish: a `ci/release-*` dry run (`build` → `installed` on the four platforms) + the `release.yml` re-check of `v0.1.0` (`gh workflow run release.yml -f tag=v0.1.0`) | unknown |

### C — Correctness (`Engineering` code diff lens): each function read with its callers + callees; each invariant holds on the whole input domain; classic pitfalls (off-by-one, overflow, encoding, ordering, error paths, resource cleanup) ruled out; wrappers route to the wrapped instance; config defaults intended; test setup + teardown symmetric

| id | module | reviewers | verdict |
|---|---|---|---|
| C-codec | M-codec | 2 | unknown |
| C-check | M-check: definitions vs kernel.md WF-* + Lints; wiring = the function the binary runs (`Main` → `Cli` → …) is the constant the theorem names (`@[csimp]` or a direct call) | 2 | F6, F9 (reviewer-3, reviewer-4) |
| C-engine | M-engine: definitions vs kernel.md S-*, sentences, ranking, experiments, plans, review; wiring as C-check | 2 | F1 (reviewer-5, reviewer-6) |
| C-fast | M-fast: code paths the binary + page engine run; wiring as C-check (every output path reaches `Answers.fast` / `Lookups.fast` / `Json.sortMembers` through the proved equalities); code outside the proved equalities | 2 | pass (reviewer-7 6/6, reviewer-8 6/6) |
| C-receipt | M-receipt | 2 | F4, F5, F8 (reviewer-9, reviewer-10) |
| C-eval | M-eval | 2 | pass (reviewer-11 6/6, reviewer-12 6/6) |
| C-cli | M-cli | 2 | F4, F11–F18 (reviewer-13, reviewer-14) |
| C-server | M-server (security aside) | 2 | F19, F20 (reviewer-15, reviewer-16) |
| C-export | M-export | 2 | unknown |
| C-gui-a | M-gui-a | 1 | unknown |
| C-gui-b | M-gui-b | 1 | F25, F26, F27 (reviewer-18) |
| C-gate | M-gate | 2 | unknown |
| C-scale | M-scale | 1 | F21, F22 (reviewer-19) |
| C-release | M-release | 2 | unknown |

### K — Cleanup + Altitude (`Engineering` code diff lenses): helpers reused (grep before writing one); derivable state computed, never duplicated; near-duplicate blocks merged; dead code (incl. unused lemmas, exports, CSS, config) removed; independent steps parallel; startup + hot paths lean; closures capture only what they use; a special case on shared infrastructure = a mechanism fix due

| id | module | verdict |
|---|---|---|
| K-codec | M-codec | unknown |
| K-check | M-check | unknown |
| K-engine | M-engine | unknown |
| K-fast | M-fast | unknown |
| K-receipt | M-receipt | unknown |
| K-eval | M-eval | unknown |
| K-cli | M-cli | unknown |
| K-server | M-server | unknown |
| K-export | M-export | unknown |
| K-gui-a | M-gui-a | unknown |
| K-gui-b | M-gui-b | unknown |
| K-gate | M-gate | unknown |
| K-scale | M-scale | unknown |
| K-release | M-release | unknown |

### S — claim soundness + guarantee-vs-claim gaps: each statement says what the code, proofs + tests establish, no more; proved vs tested stated right

| id | surface | verdict |
|---|---|---|
| S-readme | `README.md`, `SECURITY.md`, every command's `--help`, `.agent/spec.md` `Artifacts` vs behavior | unknown |
| S-skill | `skill/fvtrace/*` + `fvtrace skills show`, `examples/fvtrace/trace.json` texts (claims, facts, receipts' statements) vs the theorems + code they name | unknown |
| S-spec | `Fvtrace/Spec/*` docstrings + `kernel.md` proved/tested labels + `units.md` evidence vs the Lean statements, `fvtrace-trust` coverage + tests | unknown |
| S-comments-lean | comments + docstrings in `Fvtrace/` (shipped), `FvtraceWasm/`, `Tests/`, `TrustMain.lean`, `lakefile.lean` vs the code they describe | unknown |
| S-comments-other | comments in `web/`, `tools/`, `c/` (not `c/hacl/`), `.github/workflows/`, `tests/` (JS + shell) vs the code they describe | unknown |

### V — verification integrity (`Engineering`): tests assert contract-derived values (no fixture value returned, no expected-output table the contract does not own); no case skipped, xfailed, deleted or tier-demoted without a deferred row + user approval; thresholds + gates unweakened; each purpose-built check can fail + fires on its planted input; tested (unproved) code carries mutation credit, every survivor ruled; `green` claims name checks run

| id | slice | verdict |
|---|---|---|
| V-lean-kernel | tests of M-codec, M-check, M-engine, M-fast | unknown |
| V-lean-shell | tests of M-receipt, M-eval, M-cli, M-server, M-export (Lean) + `tests/cli/smoke.sh` | unknown |
| V-js | `tests/e2e/`, `tests/engine/`, `tests/schema/`, `tests/palette/`, `tests/renovate/` | unknown |
| V-gate | gate stages + probes (`tools/gate.sh`, `tools/gate-probe.sh`, `tools/trust.sh`, `TrustMain.lean`, `tools/mutate.mjs`, `tools/scale.sh` grading, `tools/compare.sh`): each check can fail, each probe plants what its check grades | unknown |
| V-mutation | fresh mutation campaign at `48bc51d` (`node tools/mutate.mjs <file>`, scratch copies, pool + local heavy slots) over the tested files above the page-engine closure: `Fvtrace/{Cli,Args,Store,Server,Export,Replay,Receipt,Session,Evaluate,Request,Render,Digest,Encode,Lint}.lean`, `FvtraceWasm/{Build,Binary,Lock}.lean` (≈ 590 mutants; Session measured 41 s/mutant under TestPure); each survivor ruled by a non-author (specified → test; open → recorded; equivalent → reason). Tested files inside the page-engine closure (`Json` 327, `Decode` 71, `Snapshot` 5 mutants, each rebuilding the page engine): credit = the archived campaigns cited per file; their uncredited remainder → a `.agent/deferred.md` row carrying the measured per-mutant cost. Proved files (`Model`, `Check`, `Engine`, `Present`, `Answers*`, `Index`, `Lookups`, `PTree`) need none (`lean.md`) except lines outside every proof closure, which S-spec names | unknown |

### F — spec fit: behavior vs `Intent` + `Decisions`

| id | Decisions scope | verdict |
|---|---|---|
| F-model | trace model, FV stance, must-verify kinds, claim state + verdict words, Conditional, entailment, exclusions, subjects, results + lints, where FV pays, experiments + outcome honesty, plans | unknown |
| F-cli | Product (data folder, no writes into the project, export refusal), Evidence binding + replay + notices + log, Review, Headline + exact statement, Agent instructions, Examples, Trace format, Batch path, What-if refusals | unknown |
| F-gui | GUI rulings (claim diagrams, labels, copy, key table, review line, evidence bar, claim layout, tour, plain reasons, lists, exclusions note, suppose wording), Exported page in a Worker, without WebAssembly, Envelope lists on request | unknown |
| F-serve | GUI access + login proxy, Sharing (export + bundle), Engine speed, Capability first, Response time, GUI responsiveness, Prerequisite chains, Memory | unknown |

### L — `CLAUDE.md` conformance (lens × clause, each clause that binds a tracked file): a tool-decidable clause → its gate check named + run on a planted bad input (fires = pass; none or silent = finding, fixed by wiring the check); a judgment clause → adjudicated over the files it binds

#### `CLAUDE.md` (template) + `CLAUDE.local.md`

| id | clause | verdict |
|---|---|---|
| L-T1 | Execution: install/configure project-local (scanners `.tools/`, Node `node_modules`, Lake `.lake`); env needs = `ops.md` Env | unknown |
| L-T2 | Execution: the gate prints each step's wall-clock (suites: their slowest tests); fast gate recorded beside it | unknown |
| L-T3 | Execution: CI gate workflow + commands live in `.claude/rules/` and match `tools/ci-gate.sh` + `gate.yml` | unknown |
| L-T4 | Execution: `.gitignore` current: a full gate + every Artifacts command leaves no untracked unignored file; nothing worth tracking ignored | unknown |
| L-T5 | Execution: task close leaves no temporary or stale artifact or dangling symlink in the work tree (`.scratch/`, `test-results/`, data left by tests) | unknown |
| L-T6 | Execution: UI quality floor (responsive to mobile, visible keyboard focus, reduced motion honored, accessible contrast, flat CSS specificity), each with a firing check | unknown |
| L-T7 | Execution: palette safety = a computed gate check (Machado protan + deutan, OKLab ΔE×100 ≥ 8 adjacent + ≥ 15 unsimulated, marks ≥ 3:1) | unknown |
| L-T8 | Authoring: agent-optimized text for every non-human-facing artifact (comments, internal docs, rules, contracts, scripts' messages to agents); unhelpful, obsolete + redundant content pruned | unknown |
| L-T9 | Authoring: rules, facts + warnings stated plainly; provenance omitted (dates, verification/discovery events, origin stories) in rules, contracts, comments | unknown |
| L-T10 | Authoring: future-facing text states the desired action positively; a prohibition names the thing to avoid | unknown |
| L-T11 | Authoring: human-facing surfaces (README, SECURITY, `--help`, CLI messages, GUI copy, skill text a user reads) in ASD-STE100 register; filler (`simply`, `robust`, `seamlessly`, `leverage`) absent; UI copy: user-world names, control = outcome, kept through the flow, error = what happened + the fix, no apology, empty state invites the next action | unknown |
| L-T12 | Authoring: project files portable: repo-relative paths; machine-bound facts (home paths, host names, IPs) in `CLAUDE.local.md` alone | unknown |
| L-T13 | Authoring: `.claude/rules/` = live law + why; area-bound law under `paths:`; bare tier small; origin stories out; multi-step recipes = committed scripts; frontmatter quoted where required + parses; every `paths:` glob matches a tracked file | unknown |
| L-T14 | Authoring + Session flow: one scope per durable guidance (no rule duplicated across `CLAUDE.md`, rules, `spec.md`, contracts); `CLAUDE.md` + `.claude/agents/` = byte copies of the shared template, repo law in `.claude/rules/` alone | unknown |
| L-T15 | Engineering: comments spend tokens on the why (constraint, measurement, upstream quirk), never the what | unknown |
| L-T16 | Engineering: deterministic checks own every tool-decidable rule; each purpose-built check ships its planted failing input (probe) + its firing recorded in a `paths:` rule on the check's files; no check that cannot fail | unknown |
| L-T17 | Engineering: assurance tier declared per unit (`units.md`), evidence fits the tier | unknown |
| L-T18 | Engineering: a gate backing a durable claim reruns from committed state (no scratch-local validator behind a claim without its `paths:` rule + deferred row) | unknown |
| L-T19 | Engineering: repairs to generated artifacts (locks, vendored HACL*, re-pins, self-trace pins) = idempotent committed scripts | unknown |
| L-T20 | Session flow: `.agent/spec.md` shape (five sections; `Artifacts` paths + run commands current; every line binds; `Tasks` pointer last; `Phase` state alone); `spec-lint` fires on a planted bad shape | unknown |
| L-T21 | Session flow: `.agent/deferred.md` = one entry + acceptance check each, none stale; `.agent/archive/` = finished work | unknown |
| L-T22 | Session flow: retired prototype structures stay retired (no prototype tree; tags `Artifacts` names exist) | unknown |
| L-T23 | `CLAUDE.local.md` clauses that bind tracked files (bundled Chromium for browser checks; reference host for timings) agree with tracked law | unknown |

#### `.claude/rules/` (one row per bullet)

| id | clause | verdict |
|---|---|---|
| L-ops1 | `ops.md` Env | unknown |
| L-ops2 | `ops.md` Gate (stage list = `tools/gate.sh` `STAGES`; each stage does what the bullet says) | unknown |
| L-ops3 | `ops.md` CI gate (`tools/ci-gate.sh`) | unknown |
| L-ops4 | `ops.md` Fresh host bootstrap | unknown |
| L-ops5 | `ops.md` Fast gate | unknown |
| L-ops6 | `ops.md` Probes (every purpose-built check has a probe; upstream config changes prove firing) | unknown |
| L-ops7 | `ops.md` timing + parity tools | unknown |
| L-ops8 | `ops.md` CI (triggers, jobs, SHA pins, permissions, `persist-credentials`, Renovate managers, Lean install bounds, Python + engine cache) | unknown |
| L-lean1 | `lean.md` layout + `fvtrace-trust` (claims, axioms, escape hatches, capabilities) | unknown |
| L-lean2 | `lean.md` `native_decide` banned | unknown |
| L-lean3 | `lean.md` kernel code total; `partial` out of proof closures | unknown |
| L-lean4 | `lean.md` shipped modules import `Init` + `Std` alone | unknown |
| L-lean5 | `lean.md` Tests layout + harness + native vs pure placement | unknown |
| L-lean6 | `lean.md` Lake target names | unknown |
| L-lean7 | `lean.md` embedded files under `needs` + `Tests/Assets` byte equality | unknown |
| L-lean8 | `lean.md` Lean 4.35 API pitfalls (nested `(← …)` in `&&`/`||`, structure-instance alignment) held in the code | unknown |
| L-lean9 | `lean.md` mutation credit tool (operators, scratch copy, incompetent/killed semantics) | unknown |
| L-deps1 | `deps.md` release age (every pin ≥ 7 days or a security release; held bumps = deferred rows) | unknown |
| L-deps2 | `deps.md` lockfile refresh recipe | unknown |
| L-deps3 | `deps.md` bump recipes | unknown |
| L-deps4 | `deps.md` lock consistency + probe `locks` | unknown |
| L-deps5 | `deps.md` runner labels vs actionlint | unknown |
| L-ex1 | `examples.md` both examples `check --strict` | unknown |
| L-ex2 | `examples.md` re-pin on edits | unknown |
| L-ex3 | `examples.md` README self-trace verdicts = `Tests/Engine.lean` `acceptanceTests` = the engine's | unknown |
| L-ex4 | `examples.md` statement replays | unknown |
| L-ex5 | `examples.md` probe `examples-stale-receipt` | unknown |
| L-fast1 | `fast.md` fast paths proved equal (`AnswersAgree`, `LookupsAgree`, `SortMembersAgree`) | unknown |
| L-fast2 | `fast.md` cost traps held in the code | unknown |
| L-fast3 | `fast.md` projection-form pair lambdas in rewritten statements | unknown |
| L-fast4 | `fast.md` evidence tools (`compare.sh`, `scale.sh --assert`, probes `compare` + `scale`) | unknown |
| L-rel1 | `release.md` `build.yml` platforms + `portability` + `release.yml` from scratch | unknown |
| L-rel2 | `release.md` `release.yml` job order + refusals + attestation + `installed`; dry run + re-check | unknown |
| L-rel3 | `release.md` `release.sh check` + floors (README Install table = `glibc_max`, `macos_min`) | unknown |
| L-rel4 | `release.md` notices (`package` copies every license text) | unknown |
| L-rel5 | `release.md` `$/` reusable calls + actionlint ignore scoped to `$/` | unknown |
| L-rel6 | `release.md` probe `release` | unknown |
| L-ren1 | `renovate.md` validator recipe (RE2) | unknown |
| L-ren2 | `renovate.md` local lookup recipe | unknown |
| L-srv1 | `server.md` routes + `api/answer` + problems wording | unknown |
| L-srv2 | `server.md` I/O (best-effort cache, 500 `io`) | unknown |
| L-srv3 | `server.md` access order (non-security reading: order + codes as specified) | unknown |
| L-srv4 | `server.md` bind | unknown |
| L-srv5 | `server.md` link + opener + output lines | unknown |
| L-srv6 | `server.md` GUI token + credential sequence | unknown |
| L-srv7 | `server.md` fixed headers | unknown |
| L-srv8 | `server.md` `Server.Config` in an `IO.Ref` | unknown |
| L-srv9 | `server.md` e2e harness + teardown probe | unknown |
| L-wasm1 | `wasm.md` pipeline + traces + `addTrace` | unknown |
| L-wasm2 | `wasm.md` closure `Init` + engine modules | unknown |
| L-wasm3 | `wasm.md` pins + stall bounds + bump recipes | unknown |
| L-wasm4 | `wasm.md` runtime patch hunks | unknown |
| L-wasm5 | `wasm.md` allocator | unknown |
| L-wasm6 | `wasm.md` link contract | unknown |
| L-wasm7 | `wasm.md` determinism | unknown |
| L-wasm8 | `wasm.md` CI cache key + scope | unknown |
| L-wasm9 | `wasm.md` probes | unknown |
| L-web1 | `web.md` display only | unknown |
| L-web2 | `web.md` address hash + engine + request law | unknown |
| L-web3 | `web.md` record problem view | unknown |
| L-web4 | `web.md` responsiveness (lookups, lazy lists, busy, find) | unknown |
| L-web5 | `web.md` DOM sinks banned (oxlint + Trusted Types) | unknown |
| L-web6 | `web.md` no build step; `tsc -p web` strict; untyped JSON until decoded | unknown |
| L-web7 | `web.md` bundled Chromium | unknown |
| L-web8 | `web.md` e2e limits | unknown |
| L-web9 | `web.md` palette + `tests/palette` | unknown |
| L-web10 | `web.md` selectors = classes; `[hidden]` rule | unknown |
| L-web11 | `web.md` selectable text; `idButton` + `clickToOpen` | unknown |
| L-web12 | `web.md` `app.js` starts last (TDZ) | unknown |
| L-web13 | `web.md` `words.js` verdicts = engine; work-row wording = engine lists | unknown |
| L-web14 | `web.md` fonts + alignment checks | unknown |
| L-web15 | `web.md` tour placement | unknown |

Clauses outside this lens (bind process, not a tracked file): `CLAUDE.md` Collaboration, Teammates, Git commit form, Evidence, Delivery; `ops.md` commit-body red witnesses (commit bodies: checked under V-* where a test's credit rests on them).

## Findings

| id | row | sev | `file:line` | finding | proof | status | acceptance |
|---|---|---|---|---|---|---|---|
| F1 | C-engine | minor | `.agent/contracts/kernel.md:89` | Label qualifier `what-if` is defined as `(hypothetical)`; `hypothetical` (kernel.md:82) includes every prospective claim, yet the code gives `what-if` only for a claim an actual what-if changed (`Fvtrace/Present.lean:81` `changedByWhatif`), pinned by `Tests/Engine.lean:89` + the GUI Decisions (qualifiers what-if / if E runs) ⇒ the contract is the stale side | reviewer-5-F1 = reviewer-6-F1: `bash .scratch/review/reviewer-5/prospective-label.sh` rc 1 (`C3` `hypothetical: true`, qualifiers `[draft, if-creator-runs]`); anchor `` what-if` (hypothetical) `` | open | kernel.md:89 names the code's predicate (changed by ω) |
| F2 | B1 | minor | `tests/e2e/access.spec.js:44` | Code-scanning alert #1 `js/remote-property-injection` open since 2026-10-23: `seen[k] = v` over request query keys (a `__proto__` key writes the prototype) | `gh api repos/{owner}/{repo}/code-scanning/alerts?state=open` → `1 js/remote-property-injection warning tests/e2e/access.spec.js:44` | open | the record held in a `Map`; CodeQL `js/remote-property-injection` on `tests/e2e/` = 0 results |
| F3 | B7 | minor | `tools/mutate.mjs:12` | `node tools/mutate.mjs --help` throws `ERR_PARSE_ARGS_UNKNOWN_OPTION` with a stack trace, rc 1, no usage | `node tools/mutate.mjs --help` → `TypeError [ERR_PARSE_ARGS_UNKNOWN_OPTION]: Unknown option '--help'` | open | `--help` prints the usage, rc 0; an unknown option prints the usage, rc 2 |
| F4 | C-receipt, C-cli | minor | `Fvtrace/Cli.lean:287` | `runReplay` shows stderr's tail only when the exit code ≠ 0, so a `verify --run` failure with exit 0 (`output changed`, `output not pinned`) hides it; kernel.md § Replay: "A fail shows stderr's tail" | reviewer-9-F1 = reviewer-10-F1 = reviewer-14-F4 = reviewer-13-F2: `python3 -I .scratch/review/reviewer-9/red-stderr.py` → `AssertionError: FAIL: exit 0 + output changed is a replay failure, but its stderr tail is hidden` (MAIN rerun) | open | the red test passes; tail shown on every failing reason |
| F5 | C-receipt | minor | `Fvtrace/Cli.lean:417` | `showLog` tests `pathExists`, which is false when an ancestor denies traversal ⇒ an existing, unreadable replay log reads "No replay has run for this project yet." rc 0 (`--json`: `runs: []` rc 0); kernel.md § Replay Log: an unreadable log ⇒ rc 2 | reviewer-9-F2 = reviewer-10-F3: `python3 -I .scratch/review/reviewer-9/red-log-permission.py` → `FAIL: an existing log below an unreadable data entry is reported absent (rc 0), not unreadable (rc 2)` (MAIN rerun) | open | the red test passes (rc 2); a genuinely absent log still reads as no history |
| F6 | C-check | minor | `Fvtrace/Check.lean:203` | `outcomeRoutes` merges success + failure entries, so a failure entry that assumes a must-verify fact gets the success-side WF-route message ("a success cannot assume F … set a verified status"), whose advice WF-outcome forbids (a failure sets `violated` alone); CLAUDE.md Authoring: an error states what happened + the fix | reviewer-3-F1: `python3 -I .scratch/review/reviewer-3/failure-diagnostic.py` → `AssertionError: the failure-side WF-route diagnostic must describe the failure …` (MAIN rerun); anchor `a success cannot assume` | open | the red test passes; Check suite + proofs unchanged green |
| F7 | C-codec | minor | `schema/trace.schema.json:378`, `:436`, `:86` | The schema accepts what the decoder refuses where JSON Schema can express the rule, against the corpus' own definition (`tests/schema/schema.test.mjs:3`: `decoder-only-*` = "rules JSON Schema cannot express"): `replay.failed.reason` `exit 4294967296…9999999999` (kernel.md § Model: N ≤ 4294967295; a bounded decimal regex expresses it); `text` + `arg` admit lone surrogates (kernel.md D-shape: Unicode scalars; a Unicode-mode pattern expresses it) | reviewer-2-F1: `node .scratch/review/reviewer-2/red-schema-exit.mjs` rc 1 (`exit 4294967296: schema=true, decoder=false`); reviewer-2-F2: `node .scratch/review/reviewer-2/red-schema-scalars.mjs` rc 1 (HIGH/LOW/ARG `schema=true, decoder=false`); MAIN rerun: both rc 1 | open | both red tests pass; the overflow + lone-surrogate cases join the corpus as `invalid-*` (schema + decoder reject), an astral pair stays valid |
| F8 | C-receipt | minor | `Fvtrace/Replay.lean:95` | The kept stderr tail = the last 4 KiB cut by bytes, decoded with `String.fromUTF8? … getD "(not UTF-8)"` ⇒ a cut inside one UTF-8 character discards the whole tail of a valid UTF-8 stream; kernel.md § Replay: a fail shows stderr's tail (the log keeps it) | reviewer-10-F2: `python3 -I .scratch/review/reviewer-10/red-utf8-tail.py` → `O1: its error output ends with: (not UTF-8)` / `FAIL: valid UTF-8 verifier stderr lost its complete diagnostic suffix` (MAIN rerun) | open | the red test passes (tail ends `END`); a truly non-UTF-8 tail keeps its marker |
| F9 | C-check | minor | `.agent/contracts/kernel.md:33` | WF-entail reads "an entailment fact has kind `entailment`, ∉ the claim's needs, used by exactly one claim" — as if every entailment-kind fact needs exactly one owner; `Spec/WellFormed.lean:47` + `Check.lean:184-185` scope the rule to the fact a claim names (an unnamed entailment fact is valid), as Decisions (Entailment: each non-restating claim names one) do ⇒ contract wording stale | reviewer-4 register: `python3 -I .scratch/review/reviewer-4/orphan-entailment.py` (an unnamed entailment fact + a restating claim → `check --strict` rc 0); anchor `used by exactly one claim` | open | kernel.md:33 scopes the rule to a named entailment fact |
| F10 | L-T12 | minor | `.agent/contracts/units.md:44`; `.agent/archive/**` (10 files) | Machine-bound facts in tracked files, against `CLAUDE.md` Authoring (project files portable: repo-relative paths; machine-bound facts → `CLAUDE.local.md`): `units.md:44` names the pool host (`… on nixbox, 3 green runs`); 10 archived reports carry absolute home paths; no gate check decides the clause (tool-decidable) | `git grep -c -I -E '/home/[a-z]\|/Users/[A-Za-z]' -- .agent/archive` → 10 files; anchor `` `tools/e2e-load.sh gate 3` on nixbox `` | open | a gate check fails on an absolute home path or a `CLAUDE.local.md` host name in a tracked file (probe plants one), the tree passes it |
| F11 | C-cli | major | `Fvtrace/Cli.lean:764` | `plan` prints `{id} {verdict}: {sentence}` without the engine's qualifiers (`claimsCmd` :648–650 prints them): under `--whatif M1=checked`, `plan C3` reads `C3 Fully supported: …` with no `if Collect a new cohort runs`; Decisions Review: every surface shows the engine's label incl. the prospective qualifier — an unconditional-looking verdict = an overstatement | reviewer-14-F1 = reviewer-13-F1 (lead L1 from reviewer-5 + reviewer-6): `python3 -I .scratch/review/reviewer-14/plan-label-red.py` → `FAIL: plan drops the prospective creator qualifier` (MAIN rerun) | open | the red test passes; `plan` + `claims` print one label form |
| F12 | C-cli | minor | `Fvtrace/Store.lean:57` | `entryName` = whole project basename + `-` + 12 digest chars ⇒ a legal basename within 13 bytes of the filesystem's component bound gives an illegal entry name: `init` fails (`name too long`, rc 2) on a writable project + data folder | reviewer-14-F2: `python3 -I .scratch/review/reviewer-14/edge-red.py long-project` → `FAIL: a valid project folder cannot be initialized` (MAIN rerun) | open | the red test passes; entry names of basenames under the bound unchanged |
| F13 | C-cli | minor | `Fvtrace/Cli.lean:860` (+ `Tests/Cli.lean:110`, `:125` pin it) | `skills install` refusing a destination it did not write exits 1 ("invalid or failing trace") though no trace is involved; `init` + `export` refusals exit 2; README + kernel.md: 1 = invalid trace, 2 = usage or I/O | reviewer-14-F3: `python3 -I .scratch/review/reviewer-14/edge-red.py skill-exit` → `skills install rc = 1` (MAIN rerun) | open | rc 2 on both refusals; the two test expectations follow the contract (test correction: user ruling) |
| F14 | C-cli | minor | `Fvtrace/Cli.lean:1130` | `Store.Env.detect` (`IO.currentDir`) runs before `runIn`'s `try`, so a removed working folder ends in Lean's `uncaught exception`, rc 1; README: a read error = rc 2 | reviewer-14-F5 = reviewer-13-F4: `python3 -I .scratch/review/reviewer-14/failure-red.py cwd-exit` → `path in deleted cwd rc = 1` (MAIN rerun) | open | rc 2 + `fvtrace: …` message |
| F15 | C-cli, C-export | minor | `Fvtrace/Cli.lean:115-122`; `FvtraceWasm/Build.lean:109` | `replaceFile` leaves its `<dest>.fvtrace-tmp` sibling when the write, flush or rename fails (`export --html` onto a folder: rc 2 + a 739,063-byte temporary left beside it) | reviewer-14-F6 = reviewer-13-F6: `python3 -I .scratch/review/reviewer-14/failure-red.py export-cleanup` → `temporary body left after failure = True` (MAIN rerun) | open | the red test passes; the original error + rc kept |
| F16 | C-cli | minor | `Fvtrace/Cli.lean:1102`, `:1118` | `fvtrace schema <anything>` reports `unknown command 'schema'` (dispatch matches `["schema"]` exactly); an error states what happened + the fix (`CLAUDE.md` Authoring) | reviewer-14-F7 = reviewer-13-F5 (lead L2): `python3 -I .scratch/review/reviewer-14/edge-red.py schema-error` → `fvtrace: unknown command 'schema'` (MAIN rerun) | open | the extra argument named, rc 2 |
| F17 | C-cli | minor | `Fvtrace/Cli.lean:485` (`reasons` added only under `if runs`, :503) | `verify --json` listing rows (no `--run`) lack `reasons`; kernel.md § Replay: rows = `{id, command, pinned, ran, passed?, reasons, failed?}` (`reasons` required) | reviewer-13-F3: `python3 -I .scratch/review/reviewer-13/red.py verify-reasons` → `AssertionError: verify listing omitted the required reasons array` (MAIN rerun) | open | listing rows carry `reasons: []`; run rows unchanged |
| F18 | C-cli | minor | `Fvtrace/Cli.lean:546` | `--question` sits in the spec shared by `gaps`, `experiments`, `plan`, `eval`, whose handlers ignore it (only `claims [--question Q]` is documented): `gaps --question NOPE` rc 0, unfiltered; `claims --question NOPE` prints no claim, rc 0, where an unknown claim id is an error (`plan C99` → `no claim "C99"`, rc 2) | reviewer-13 register, MAIN repro on the synthetic copy: `fvtrace gaps --trace ../trace.json --question NOPE` → rc 0; `fvtrace claims --trace ../trace.json --question NOPE` → footer only, rc 0 | open | `--question` refused as an unknown option outside `claims` (rc 2); an id naming no question → `fvtrace: no question "NOPE"`, rc 2 |
| F19 | C-server | minor | `.claude/rules/server.md` (Routes, Access, fixed headers); `.agent/contracts/kernel.md` V-serve (access order) | Law stale vs the ruled design: a declared `Content-Length` over `bodyCap` is refused by Std.Http's framing limit (`Fvtrace/Server.lean:256` `maxBodySize`; `Std/Http/Protocol/H1.lean` `exceedsBodyLimitForMode`, before the handler) = an empty 413 + close before method/Host/path/token/type and without `fixedHeaders`; the law orders the 413 last + puts `fixedHeaders` on every response. Code kept (MAIN ruling): a handler-side cap would let the framing layer accept + drain larger bodies before `decide`, the DoS exposure the cap exists to stop (security review S.1: eight 60 MiB unauthenticated bodies, nothing buffered); the 413 carries no body to protect | reviewer-16-F1 = reviewer-15-F1: `python3 -I .scratch/review/reviewer-16/probe.py --red-body` → `POST /` / `GET /missing` / text/plain API: `got=413`, headers `server, connection, content-length` alone (MAIN rerun) | open | server.md + kernel.md V-serve state the framing-limit 413 (first, empty, undecorated, connection closed) + `fixedHeaders` on every response the handler makes; a Tests/Server row or e2e pins the order as stated |
| F20 | C-server | minor | `Fvtrace/Server.lean:205` | An item refusal (`details` naming no record) after the view is computed returns `problemReply` untagged ⇒ no `X-Fvtrace-View`; kernel.md V-serve: each answer carries it | reviewer-16-F2 = reviewer-15-F2: `python3 -I .scratch/review/reviewer-16/probe.py --red-view` → `FAIL item problem carries evaluated view: got=None` (MAIN rerun) | open | the red test passes; a Tests/Server row pins it |
| F21 | C-scale | major | `tools/scale.sh:150`; `tools/scale-gui.mjs:102-104`; `tools/compare.sh:105-108`, `:112-114`; `tools/compare.sh:83-84`, `:149` | Graders read a failure as a pass (kernel.md P-evidence: `--assert` fails on a nonzero exit or timeout; V-cli: exit codes + stderr kept; README: compare fails when outputs differ): (a) `session_row` returns a session's measured rows before reading its rc ⇒ a GUI driver that prints every row, then exits 3 (or 124) → `scale: every graded run within its bounds`, rc 0; (b) the details timer checks `holds(ready)` before the app's click handler clears the old answer ⇒ on `deep` (one claim, reselected) a 1.5 s new answer reports ≈ 5–8 ms; (c) the v1 expansion + details oracles compare stdout alone ⇒ NEW rc 7 + changed stderr = 0 differences; (d) `cmp_json` ignores `jq`'s exit ⇒ two different malformed outputs both normalize to empty files = equal (form detection also routes invalid JSON to the v1 branch) | reviewer-19-F1..F4, MAIN rerun: `python3 -I .scratch/review/reviewer-19/red-session-exit.py` (`scale.sh rc=0; driver … exits 3`), `node .scratch/review/reviewer-19/red-gui-details.mjs` (`reported 8.3 ms; new details ready 1502.9 ms`), `python3 -I .scratch/review/reviewer-19/red-compare-oracle.py` (`compare.sh rc=0; … rc=7`), `python3 -I .scratch/review/reviewer-19/red-compare-json.py` (`compare.sh rc=0; OLD eval prints '{'; NEW eval prints '['`) | open | each red test passes; each fix ships its gate-probe probe (planted failure fires) |
| F22 | C-scale | minor | `tools/scale-gui.mjs:295` | The link promise listens for the server's `exit`, not its spawn `error` ⇒ a missing or non-executable `--bin` aborts Node (`Unhandled 'error' event`) past `finally`, leaving the run's `scale-gui-*` temporary home | reviewer-19-F5: `python3 -I .scratch/review/reviewer-19/red-gui-spawn.py` → `task-created temp folders left=1 (expected 0)` (MAIN rerun) | open | the red test passes |
| F23 | C-release | minor | `.github/workflows/release.yml:67-69` (globs :78-80, :88) | The publish job's refusal checks that the eight expected archive + `.sha256` names are present, not that every downloaded archive is named for the tag: an extra `fvtrace-9.9.9-…` passes under `v0.1.0` and the attest + publish globs then take it; `release.md`: refuses unless every archive is named for the tag's version | reviewer-24-F1: `python3 -I .scratch/review/reviewer-24/release-archive-guard.py` → `extra mismatched archive: guard rc=0` (MAIN rerun) | open | the guard refuses any file outside the expected set (red test passes; controls kept) |
| F24 | C-export, C-gui-a | major | `web/app.js:211-235` | The page engine's Worker `error`/`messageerror` listeners only reject requests already waiting (`failAll`); an error while idle is forgotten, so the next request posts to a dead Worker and never settles (`aria-busy` stays `true`, "Working…", no engine notice); kernel.md E-abi/E-gui: a failed or silent worker = engine failure ⇒ engine dead for the session + recorded view + notice | reviewer-20-F1 = reviewer-17-F4 = reviewer-21-F1: `node .scratch/review/reviewer-20/red-worker-idle.mjs` → `idle worker failure: {"notice":"","busy":"true","calls":1,"dead":true}` / `AssertionError … must end the engine` (MAIN rerun; control: an error while a request waits → notice) | open | the red test passes; an idle error marks the engine dead before the next request (e2e case) |
| F25 | C-gui-b | minor | `web/tour.js:86` (+ `:289`, `:342`) | The tour step "The facts it needs" spotlights the whole `.contacts` with no `compact` part, and phone placement floors the card at 200 px ⇒ on a 12-fact claim at 390×844 the docked card covers the spotlight's bottom contacts; `web.md` Tour: a card never covers its spotlight; a target too tall to share the screen spotlights its compact part | reviewer-18-F1: `node .scratch/review/reviewer-18/tour-deep.mjs` → `"overlap":true` (spot bottom 872, card top 632; reduced motion, sampled after 2.1 s) (MAIN rerun) | open | the red test passes; the e2e tour walk adds the 12-fact claim at both sizes |
| F26 | C-gui-b | minor | `web/panels.js:639-665` | A work row's "Needed by …" text maps every gated claim eagerly (no `listOf`), so a fact gating 300 claims mounts all 300 references while offscreen; kernel.md U-long + `web.md`: every long list = `LazyList`, nested lists mount their first 40 | reviewer-18-F2: `node .scratch/review/reviewer-18/work-long.mjs` → `{"engineGates":300,"neededBy":300,"endLines":0,"parentOffscreen":true}` (MAIN rerun) | open | the red test passes (≤ 40 mounted + an end line); wording unchanged |
| F27 | C-gui-b | minor | `web/style.css:1629` (`web/app.js:490`, `web/tour.js:220-238`) | A record problem (`cannotShow`) hides the tour's start buttons but leaves an active tour card on screen; `web.md` record problem: the loading lines, board, lists + tour leave | reviewer-18-F3: `node .scratch/review/reviewer-18/tour-invalid.mjs` → `"visibleTourCards":1` after the record-problem view (MAIN rerun) | open | the red test passes; the tour ends on a record problem |
