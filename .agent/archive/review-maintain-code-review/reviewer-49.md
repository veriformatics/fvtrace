# reviewer-49 — L rules-a

Target = `48bc51d` frozen base; check set = assigned bullets + Authoring per file.

| row | bullet | verdict | basis |
|---|---|---|---|
| L-ops1 | Environment | pass | `lean-toolchain`, `.node-version`, `package.json`, fetch/build tools + CI provisioning read; local Lean/Node/pnpm versions agree; lock-version/digest vendor controls fire. Fresh-host install not run. |
| L-ops2 | One gate + stages | finding F30, F35, reviewer-49-F6 | All STAGES entries/functions compared with bullet; runner control fails rc 7, still runs later stage, closes gate rc 1 + timings. Existing audit gaps F30/F35 remain; js-test prints all durations, not ranked three-slowest summary (new F6). |
| L-ops3 | CI gate script | pass | Own CI controls stub every git/gh command: green rc 0 + delete; dirty rc 2 + no push; watch failure rc 1 + branch kept. Workflow gate contains all shards + portability; no remote mutation. |
| L-ops4 | Fresh bootstrap | finding reviewer-49-F4 | Tracked CI bootstrap agrees; local recipe is an inline multi-step recipe, not a committed bootstrap helper. Full fresh-host gate explicitly not run. |
| L-ops5 | Fast gate | pass | Source + STAGES comparison: cheap stages fork, build/tests incremental, all omitted stages named; --e2e included conditionally. Gate-runner failure control fires; fast gate itself not run. |
| L-ops6 | Probes | finding F29, F30, F35 | `gate-probe.sh` inventory read; own copy: 28 controls pass (probes.log); known dispatch/audit gaps retained, not re-reported. |
| L-ops7 | Timing + parity | finding F21 | `scale.sh`, `compare.sh` contracts + existing red witnesses in F21; no reference-host timing run. |
| L-ops8 | CI | finding F32, reviewer-49-F5 | All four workflows + Renovate read: triggers/platforms/SHA permissions/Python/cache agree; download hard bound gap = F32; removed Python setup + Windows build + moved installed floor runner still pass workflow/fanout checks (new F5). |
| L-lean1 | Layout + trust | finding F30, F35, reviewer-49-F1 | `TrustMain.lean` claims/proof/audit/allowlist read; constructor closure + reducible Prop alias gaps = known F30/F35; Spec imports Proofs + theorem plant also passes style/build/trust (new F1). |
| L-lean2 | native_decide ban | pass | Own valid native_decide theorem compiles; fvtrace-trust fails rc 1 with generated native_decide axiom (27 claims/1 finding). Script native-decide.log; initial fixture lacked unfold and was corrected before credit. |
| L-lean3 | Total kernel | finding F30 | `partial` direct closure probe in trust group; inductive-constructor reach gap already F30. |
| L-lean4 | Shipped imports | finding reviewer-49-F1 | `import Lean` planted in shipped Version.lean: style + Fvtrace build + trust all rc 0, 26 claims/0 findings; no firing import-boundary check. |
| L-lean5 | Test layout/harness | pass | `Tests.lean`, Harness, Cli/CliStore/Assets wiring read; harness red: false + exception → 2 FAIL rows, next area runs, slowest three + rc 1; pure-FFI probe fires. |
| L-lean6 | Lake names | pass | Tracked Lake declarations/testDriver/build calls conform to guillemet convention. The bare CLI target also builds rc 0; syntax-necessity inference withdrawn (Register). |
| L-lean7 | Embedded input tracing | pass | All include_str sites map to needs in lakefile; Assets iterates schema/web/skill/engine/license bytes; own assets-verdict-words + assets-skill-example controls fire after rebuild. |
| L-lean8 | Lean pitfalls | pass | Production IO/boolean sites Session:64, Store:128, Replay:82 + Wasm/Build reviewed: no read protected only by && existence test. Structure/String syntax enforced by Lean build; benign eager task/path probes retained. |
| L-lean9 | Mutation credit | finding F3, F31, F51 | `mutate.mjs` read: operators/timeouts/build→suite classification agree; known help/raw-string/list-write defects cited, no campaign run. |
| L-deps1 | Release age | finding reviewer-49-F2 | Publication lookup: all 199 exact npm lock entries ≥7 d now; direct npm + 15 GitHub release pins checked; pnpm adoption security exception has explicit release notes. Age/held-row automation absent; age=0 plant passes js-test. |
| L-deps2 | Lockfile refresh | finding reviewer-49-F4 | pnpm command/floor/excludes agree with supported CLI + recorded refresh; inline rm/install/exclude recipe lacks committed helper. Fresh resolve not repeated. |
| L-deps3 | Bump recipes | pass | pin-tool.sh platform selection/count/digest rewrite, pin-wasm.sh five archives + Lean/libuv manifest rewrite, vendor-hacl.sh check/verify inspected; vendor + lock half-bump controls fire. Large re-download recipes not run. |
| L-deps4 | Lock consistency | pass | Own `gate-probe.sh locks`: tools one-line 99.0.0 + wasm one-line 99.0.0 both fire rc 1 with version mismatch (probes.log). |
| L-deps5 | Runner label table | pass | `actionlint.yaml` declares only ubuntu-26.04(-arm); pinned actionlint 1.7.12 + release date read; own planted-label control fails rc 1 (actionlint-label.log). |
| L-ren1 | RE2 validator | finding reviewer-49-F2 | Manual validator command is not a gate step; gate js-test uses JS RegExp. Planted invalid option + RE2-invalid lookbehind still passes all 64 js tests (rc 0). |
| L-ren2 | Local lookup | finding reviewer-49-F4 | Rule supplies a multi-command local lookup/log-extraction recipe instead of a committed helper; live lookup not run (Renovate not project-pinned). |
| L-rel1 | Platform build | finding reviewer-49-F5 | `build.yml` all four target pairs → build/test/package (package checks at once); gate portability reusable call; release input disables cache. Missing Windows matrix entry passes static workflow checks (new F5). |
| L-rel2 | Publish + installed | finding F23 | release.yml job order/permissions/green-main gate/attest/download OS matrix/read-only dispatch/dry branch agree; archive-name guard gap = F23. |
| L-rel3 | Archive checks + floors | finding reviewer-49-F3, reviewer-49-F5 | Code floors 2.17/15.0 match README + build/installed macOS. Actual glibc/version/digest/license controls fire; README lowered to 2.16 still packages/checks rc 0; installed runner moved off the declared macOS floor is unchecked (new F5). |
| L-rel4 | Notices | pass | release.sh package copies seven named texts from pinned toolchain/HACL/Emscripten + libuv; release-license plant fires rc 1 (probes.log). |
| L-rel5 | Reusable workflow form | pass | All in-repo calls use $/; actionlint ignore regexp anchored to that call form. Own malformed-reusable plant still fails rc 1; unrelated label plant fails rc 1. |
| L-rel6 | Release probe | pass | Own release group: package control passes, digest/version/license/glibc plants fire (28/28 combined controls). macOS/Windows plants not run on Linux. |
| L-ex1 | Example strict checks | pass | Gate examples function resolves own/synthetic project roots + check --strict; stale-receipt plant fires rc 1; baseline release synthetic strict check passes. |
| L-ex2 | Re-pin changes | pass | Strict examples stage rejects appended proof line (rc 1), restores it; pin command exists and receipt artifacts agree; re-pin sequencing/commit obligation = process, not additional target behavior. |
| L-ex3 | README self-trace verdicts | finding reviewer-49-F3 | Native claims .final + acceptanceTests agree: 7 can, C2/C7 open. README count Seven→Eight leaves 6/6 acceptance checks passing; absent README relation check. |
| L-ex4 | Statement replays | pass | Live PlanSound fingerprint sha256 equals P6 output ee99af43…; own wrong-output plant makes trust statements fail rc 1: P6 failed (output changed), trace restored. Cache-key checks already fire. |
| L-ex5 | Stale receipt probe | pass | Own gate-probe.sh examples: examples-stale-receipt fires rc 1 on appended Plan.lean line, restored by checksum. |
| A-ops | Authoring: ops.md | finding reviewer-49-F4 | Repo-wide gate law stays bare; compact live stage contract + rationale; fresh-host inline install && gate recipe lacks a committed wrapper. |
| A-lean | Authoring: lean.md | pass | Quoted paths frontmatter + concise live Lean constraints/pitfalls/why; repeated command is invocation, not an origin story. |
| A-deps | Authoring: deps.md | finding reviewer-49-F4 | Quoted paths all match tracked files; live floor/why + recipes mostly scripts, but lock refresh rm/install/exclude sequence remains in prose. |
| A-renovate | Authoring: renovate.md | finding reviewer-49-F4 | Quoted paths match; RE2/Node constraints explain why; lookup + log parsing are unscripted multi-step instructions. |
| A-release | Authoring: release.md | pass | Quoted area paths; live platforms/floors/attestation + upstream quirks explain constraints; executable package/check/probe scripts own recipes. |
| A-examples | Authoring: examples.md | pass | Quoted area paths; live receipt/replay + consistency obligations, commands already committed CLI/scripts; no dated origin story. |

## Findings

### reviewer-49-F1 — minor — no firing Lean source-boundary/layout check

- Target: `tools/lean-style.sh:12`; `TrustMain.lean:82`; contract `.claude/rules/lean.md:12,15` + CLAUDE Engineering deterministic checks.
- Current sources conform; their prescribed check does not enforce either structural law. A Spec module can import Proofs and declare a theorem; a shipped implementation module can import Lean. Both plants compile and pass the audit. `lean-style.sh` checks whitespace/line layout alone, and audit checks claims/proofs/closures, not these source boundaries.
- Anchors: `claims as ` + `shipped modules import` in `.claude/rules/lean.md` (`rg -Fn` rematched at lines 12,15).
- Red commands (base-derived private copy, restored after each):
  - `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-49/red-enforcement.py lean-layout` → rc 1: `planted Spec imports Proofs + theorem: owning checks rc=0`; `trust: 26 claims, 0 findings`; `AssertionError: FAIL no firing check: Spec contains a proof + imports Proofs, but Lean layout/build/trust checks pass`.
  - Same script `shipped-import` → rc 1: `planted shipped import Lean: owning checks rc=0`; `trust: 26 claims, 0 findings`; `AssertionError: FAIL no firing check: shipped module imports Lean, but Lean style/build/trust checks pass`.
- Owning checks actually run = `lean_style && nice -n 10 lake build Fvtrace «fvtrace-trust» && lake env .lake/build/bin/fvtrace-trust`; not the full gate. Gate's other functions were read; none checks these boundaries.
- Fix direction: extend the existing Lean check/audit with source-module/constant-kind constraints; add both plants to gate-probe. This adds the missing checks; no current source boundary needs repair.

### reviewer-49-F2 — minor — no firing Renovate option/RE2 or release-age policy check

- Target: `tests/renovate/renovate.test.mjs:49`; contract `.claude/rules/renovate.md:9` + `.claude/rules/deps.md:16` + CLAUDE Engineering deterministic checks.
- Gate `js-test` executes extraction through JS `RegExp` alone. The rule itself says extraction does not validate options. No gate step calls the strict RE2 validator; no gate check holds the configured floor at seven days or validates a manual pin's age/exception/held-row policy. Current pinned values are not alleged too young.
- Red commands:
  - `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-49/red-enforcement.py renovate-options` → rc 1: `renovate-options: gate js-test rc=0`; `tests 64`, `pass 64`, `fail 0`; `AssertionError: FAIL no firing check: renovate-options violates law, but gate extraction/schema/palette suite passes`.
  - Same script `renovate-age` → rc 1 with `gate js-test rc=0`, 64/64 passed, same named assertion for age. Plant = `minimumReleaseAge: "0 days"`.
- Option plant = `plantedInvalidOption: true` + `(?<!PLANTED)` prefix on first matchString (JS supports it, RE2 does not); extraction remains unchanged. Every plant is restored.
- Fix direction: run strict option+RE2 validation under an eligible pinned Renovate/Node; wire an explicit age/exception policy check + probes. MAIN rules the publication-source/exception representation. Existing direct pins + 199 exact lock entries were checked independently; metadata = scratch `pin-dates.json`, `lock-dates.json`.

### reviewer-49-F3 — minor — no firing README synchronization check

- Target: `tools/release.sh:61,151`; contract `.claude/rules/release.md:15` (README floor table moves with code) + CLAUDE Engineering deterministic checks; `.claude/rules/examples.md:16` (README verdicts = acceptanceTests = engine).
- `release.sh` copies README and checks its presence, not its promised floors. Current README says glibc 2.17/macOS 15 and matches the code; a false lower promise still produces a passing release archive.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-49/red-enforcement.py readme-floor` → rc 1: `README glibc floor 2.16 vs script 2.17: release check rc=0`; `release: fvtrace-0.1.0-linux-x86_64.tar.gz passed`; `AssertionError: FAIL no firing check: release package/check ships a README promising a lower glibc floor`.
- Self-trace red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-49/lean-extra.py readme-verdict` → rc 1: `README says Eight vs actual Seven: acceptanceTests rc=0`; `6/6 checks passed`; `AssertionError: FAIL no firing check: self-trace acceptance tests do not check the README verdict claim`. Exact text anchor = `Seven of its claims read` (`README.md:310`); frozen native `claims --json` gives seven `.final = "can"` and C2/C7 `"open"`, matching Tests/Engine.lean:448–451.
- Control = own `gate-probe.sh release`: package passes; real lowered binary floor fails, alongside digest/version/license plants (probes.log). Thus this is the absent README relation, not a broken archive checker.
- Fix direction: one gate check ties README's floor values to release constants (and self-trace verdict counts to their evaluated rows); plant wrong floor/count text.

### reviewer-49-F4 — minor — multi-step recipes remain in rules, not committed scripts

- Targets: `.claude/rules/ops.md:6`; `.claude/rules/deps.md:17`; `.claude/rules/renovate.md:10`.
- Contract = CLAUDE Authoring: a multi-step recipe → a committed script that the rule names. These instructions still ask the caller to reconstruct a cleanup/install/exclusion sequence or a lookup/log-decoding sequence. No committed wrapper exists (`git ls-files tools tests/renovate` inventory read).
- Exact text anchors (`rg -Fn` matches in frozen base):
  - `pnpm install --frozen-lockfile && bash tools/gate.sh` (ops.md).
  - `rm -rf node_modules pnpm-lock.yaml && pnpm install --config.minimum-release-age=10080` (deps.md).
  - `LOG_LEVEL=debug LOG_FORMAT=json pnpm dlx` + `jq -R 'fromjson?'` (renovate.md).
- Fix direction: committed bootstrap/lock-refresh/local-lookup helpers accept the required version/exclusion/manager inputs; rules name one invocation + the policy/why. Judge recipe boundaries; the component commands are not alleged defective.


### reviewer-49-F5 — minor — no firing cross-workflow provisioning/platform/floor check

- Target: `tools/gate.sh:195,204`; `.github/workflows/gate.yml:49`, `build.yml:31,44`, `release.yml:105`.
- Contract = `.claude/rules/ops.md:10` (Python in every build job) + `.claude/rules/release.md:13,15` (four release platforms built in CI; installed macOS = declared floor) + CLAUDE Engineering deterministic checks.
- Current workflow values conform. Neither workflow linter nor shard fanout check enforces these cross-file relations: remove both setup-python steps, omit Windows from reusable build, move installed macOS from 15 to 26 → all owning static checks still pass. A later tagged release's missing-archive guard is not a gate on this ordinary CI edit; a preinstalled Python can also hide the omitted setup step.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-49/ci-structure-red.py` → rc 1: `baseline workflow checks rc=0`; `no Python setup + missing Windows build + installed macOS != declared floor: workflows/fanout rc=0`; `AssertionError: FAIL no firing check: Python provisioning and floor-runner invariants are absent from workflow validation`.
- Exact checks run = `workflows` (zizmor + actionlint) + `fanout`; every source file restored. Zizmor prints its default offline-mode warning; no online-only audit coverage claimed.
- Fix direction: a gate structural validator joins build jobs → Python setup, build/installed targets → required release targets, macOS installed label → `macos_min`; planted omissions/mismatch fire. Keep the existing shard check.

### reviewer-49-F6 — minor — js-test omits the promised three-slowest summary

- Target: `tools/gate.sh:144`; contract `.claude/rules/ops.md:4` exact anchor `suites add their three slowest areas` + CLAUDE Execution gate timing.
- Gate js-test prints all 64 per-test durations in test order and totals. It does not add a ranked three-slowest area/test summary. Lean's harness does produce its summary; the Node suite does not use that harness.
- Red: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-49/timing-red.py` → rc 1: `gate js-test rc=0 output lines=72`; 64 pass/0 fail; `AssertionError: FAIL js-test reports totals/duration alone, not the three slowest areas/tests required by ops.md`.
- Precision: that assertion's shorthand includes the printed per-test durations; none is lost. Full captured output (`timing-js-test-output.log`) was read for the missing ranking, not just the missing word `slowest`. No claim about the engine/e2e timing summary is based on this run.
- Fix direction: a Node reporter emits the three slowest areas/tests while retaining every test outcome + exit status; add its firing control.

## Register

- `.claude/rules/lean.md:17`: guillemets remain a tracked-code convention, but not a CLI necessity: `lake build fvtrace-tests` returned 0 and built 181 jobs. The initial compiler-rejection inference is withdrawn; no defect inferred from broader accepted CLI syntax.
- Language intelligence: LSP `documentSymbol` on TrustMain.lean returned `No LSP server available for file type: .lean`; Lean review used source reads, compiler + native audit instead.
- Publication-source limit: Python 3.15.2 has no GitHub release record (API 404); its exact publication date was not established. HACL* pinned commit metadata = 2026-04-10T15:41:24Z (not a release date). Official Node v26.12.1 release metadata says `2026-10-21T10:38:29Z` + `This is a security release.`; saved in node-release.json.
- Publication-source limit: emsdk has no GitHub release record for 6.0.13 (API 404); its tag commit `35659964…` says `Release 6.0.13 (#1811)` at 2026-10-19T19:48:59Z. Exact tag publication time remains unconfirmed; npm/GitHub release timestamps above are verbatim API values.


## Checks + limits

- Adjudicated = 41/41 rows (35 bullets + 6 Authoring files); new findings = 6, all minor; known finding links retained as named in table.
- Existing probe groups run in own copy = `fanout meta lean_style vendor replay_policy trust_cache lean_pure palette examples release locks` (28/28) + `trust capability assets` (9/9). Each named plant fired or its named control passed; logs = `probes.log`, `trust-probes.log` under scratch.
- Extra firing controls = harness false+exception/continue; native_decide axiom; actionlint label + malformed reusable call; CI script green/dirty/red with every remote command stubbed; wrong statement replay output. New-finding red commands + outputs above are the failing checks actually run.
- Scope limits: no full gate, mutation campaign, reference-host timing/parity run, fresh-host bootstrap/resolve, external Renovate validator/lookup, clean five-platform re-pin download, macOS/Windows execution, live GitHub CI/publish action or browser interaction. Workflow checks ran locally; no remote state changed.
- Source target stayed read-only. Private copy's final `git diff --exit-code --stat` = rc 0 after all plants restored. Scratch evidence/copy retained for MAIN's reruns. Instructions/Intent/CLAUDE files edited = none.

reviewer-49-DONE-1
