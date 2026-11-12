# reviewer-50 — L rules-b conformance

Target = `48bc51d`, frozen `.scratch/review-base`; check set = L-srv1…9, L-wasm1…9, L-web1…15, L-fast1…4 + Authoring per rule file. Read-only target; planted inputs only in `.scratch/review/reviewer-50/tree`.

| row | bullet | verdict | basis |
|---|---|---|---|
| L-srv1 | server.md Routes | F19, F20 | Server.decide/answer + Tests.Server.answerTests: routes + CLI byte equality + problem copy agree; known framing-cap + untagged item-error exceptions. |
| L-srv2 | server.md I/O | pass | lean-test Tests.Server.nativeTests + Session.closeCache; native suite green; lean-plants.py changes I/O response to 400 → same native-test predicate FAIL got (400, some io), want (500, some io). |
| L-srv3 | server.md Access order | F19 | Server.decide + Cli.tokenOf/serveCmd agree; framing-limit ordering already F19; pure/native server tests pass in native suite. |
| L-srv4 | server.md Bind | pass | Cli.serveLoopback bounded retry + fixed-port busy/unsupported branches read; lean-pure Tests.Cli.bindTests fires when IPv6 bind removed (24/26; named busy-[::1] FAIL). |
| L-srv5 | server.md Link + opener | pass | Cli.browserOpener/openBrowser/serveCmd + bindTests agree; linux display opener changed to none → lean-pure named xdg-open FAIL; native base suite green; full output modes read. |
| L-srv6 | server.md GUI token | pass | app.js takeToken/answerOf/forgetToken + proxy.spec reviewed; actual proxy baseline passed serially. Delivered removal of forgetToken in the test-created browser context makes owning e2e fail expected null storage (e2e-plants-fourth.log). |
| L-srv7 | server.md Fixed headers | F19 | Server.toResponse appends fixedHeaders; known framing response bypass = F19 (no new security analysis). |
| L-srv8 | server.md Config Ref | pass | Cli.serveCmd builds IO.mkRef hosts=[] before start, modifies afterward; lean-build compiler fires on non-Ref plant: expected IO.Ref Server.Config (lean-plants.log). |
| L-srv9 | server.md e2e harness | pass | e2e helper source + gate STAGES; planted hanging spec hits actual default 90000ms limit, rc=1; worker exit removes observed study + closes both listeners; pgrep own binary path = 0 processes. |
| L-wasm1 | wasm.md Pipeline | pass | lakefile engine closure+C/tool/lock/bridge/LICENSE/build-step traces + addTrace licenses + needs inspected; build-step plant fires owning lean-build; Tests.Assets embeds byte-equal, native suite green; selected probe rc=0. |
| L-wasm2 | wasm.md Closure | reviewer-50-F3 | Current Snapshot closure is Init + Fvtrace; unused @[extern] added to Receipt.Basic is dropped by link GC, so engine build succeeds. Parenthetical guarantee overstated; no structural closure guard (nofire-wasm.py). |
| L-wasm3 | wasm.md Pins | pass | Build.emsdk/gitTree pins, manifest ordering, githash/libuv checks + curl/git stall args + pin-wasm/renovate recipes read; wasm-manifest plant fires named mismatch rc=1; Tests.Wasm native/pure green. |
| L-wasm4 | wasm.md Runtime patch | pass | Pinned runtime git diff cmp byte-equals sole runtime patch (rc=0), all four compatibility hunks match law; engine-panic plant fires differential stderr check rc=1. Historical upstream/measurement claims not independently replayed. |
| L-wasm5 | wasm.md Allocator | reviewer-50-F4 | Build.link currently passes -sMALLOC=mimalloc, headers omit LEAN_MIMALLOC; dlmalloc plant is accepted by owning engine-build check. No firing allocator-policy assertion (nofire-wasm.py). |
| L-wasm6 | wasm.md Link contract | pass | Binary allowedImports/requiredExports + Build.unexpectedWarnings + C bridge + worker/loader lists agree; actual module ABI inspected; wasm-import + wasm-warning plants fail with named causes; native Wasm unit checks green. |
| L-wasm7 | wasm.md Determinism | reviewer-50-F5 | Source sorts app/Init and preserves runtime order; relative flags/object hash + CFGDIR + mtime=0 agree. mtime=None plant still builds; no reproducibility check compares clean folders (nofire-wasm.py). |
| L-wasm8 | wasm.md CI cache | reviewer-50-F2 | Current CI key/cache scope/weekly bypass/partial restore match rule; planted omission of FvtraceWasm/** + WasmMain.lean → workflows+fanout rc=0; no firing cache-shape check (nofire-cache.py). |
| L-wasm9 | wasm.md Probes | pass | Private-copy gate-probe wasm engine: manifest/import/warning/build-step + panic plants all fire rc=1; response-file finally removes link list; whole selected 30-probe run rc=0 (probes.log). |
| L-web1 | web.md Display only | pass | Judgment: app groups + circuit/conditions + panels inspector/work/experiments/plan consume engine final, verdict, summary, lists and rankings; display transformations only, no re-derived engine judgment. |
| L-web2 | web.md Request law | F24, F37–F41 | app.js ask/evaluation/load/loadDetails/readHash + worker reviewed; known idle error, fatal shape, action pending-view, hash question, detail-view gaps. |
| L-web3 | web.md Record problem | F27, F42 | cannotShow + .unavailable + gui.spec.js: active tour stays; history can restore old envelope before a new one (known). |
| L-web4 | web.md Responsiveness | F26, F43–F45, F50 | app.js/renderBoard/find + lazy.js + panels.js + responsive.spec.js: known eager Needed-by, text highlight, duplicate titles, focus window + find lookup gaps. |
| L-web5 | web.md DOM sinks | pass | js-lint oxlint --type-aware --deny-warnings web; .oxlintrc no-restricted-properties; planted document.body.innerHTML assignment fires HTML-string sink rc=1 (static-plants.log); CSP clause covered by F19 row. |
| L-web6 | web.md No build + types | pass | web/tsconfig strict+noUncheckedIndexedAccess+exactOptionalPropertyTypes; JS modules no bundler; un-narrowed property plant → tsc rc=1, fetched-any plant → oxlint no-unsafe-assignment rc=1. |
| L-web7 | web.md Chromium | pass | playwright.config browserName=chromium, no default executablePath; CI installs chromium-headless-shell; baseline logs launch .cache/ms-playwright/chromium_headless_shell-1248 (actual bundled Chromium), CHROME remains optional override. |
| L-web8 | web.md e2e limits | F34, F36 | Configured 90s/default + 300s/smoke + 600s/engine match law; planted hang fires actual 90000ms timeout. Known load-threshold floor + interrupted-load cleanup defects F34/F36; no loaded-host rerun here. |
| L-web9 | web.md Palette | pass | tests/palette tables + CSS pairings reviewed; gate js-test uses culori Machado + OKLab all-pairs, 4.5/3/15/8 floors; palette-contrast plant fires conductor-on-paper rc=1 in own copy. |
| L-web10 | web.md Selectors | pass | js-lint stylelint selector-max-id=0 + specificity=0,2,1 fires planted #reviewer-50-probe rc=2; existing display-setting hidden controls .working/.find*/.work/.tour-spot checked for hidden rules. |
| L-web11 | web.md Selectable text | reviewer-50-F7 | Visible claim/fact/experiment/work/text-row text + idButton/clickToOpen conform; gate selectable-text e2e stays green after a confirmed-delivered mutation that opens on an active selection (nofire-selection.py). Guard not checked. |
| L-web12 | web.md Startup | pass | app.js actual startup is last; exported render synchronous. Confirmed move (not duplicate) before pair/factKey consts makes owning export e2e fail; error-context: ReferenceError: Cannot access factKey before initialization (wrapper6/log). |
| L-web13 | web.md Verdict words | pass | Tests.Assets asserts all four words vs State.verdict, assets-verdict-words plant fires rc=1; panels.togetherWith takes engine gaps minus row fact and handles final-state wording (judgment reviewed); gui.spec work-row assertions match. |
| L-web14 | web.md Fonts | reviewer-50-F1 | CSS has cap trimming + tabular nums, but no alignment test sets ≥2 fonts; entire tests/tools/Tests source search has 0 DejaVu/fontFamily hits; text-box:none plant passes stylelint rc=0. |
| L-web15 | web.md Tour | F25 | Tour.target/place + expectTourClear walk tests read; desktop→above→beside/shrunk + phone dock implemented. Synthetic two-size walk passed; feature-fixture walk timed out at 90s under 56.43/8 load. Known tall-target overlap F25. |
| L-fast1 | fast.md Equality proofs | pass | Spec.Fast + Proofs.Agree/Lookups/Json; lean-build kernel fires on all three false-conjoined equality plants (lean-plants.py); actual native 1,001,225 differential comparisons + base suite green. |
| L-fast2 | fast.md Cost traps | F47 | Receipt.BindingIndex, ClaimMemo.needs, forest closures + plan memoAt reviewed; known Snapshot.answer rebuilds immutable binding index on cached details (F47). |
| L-fast3 | fast.md Pair projections | pass | Judgment: rewrite-sensitive pair lambdas in Spec.Fast + Proofs.Agree/Answers/Lookups/Positions + Json use projections or rewrite locally; native build proof artifacts + 1834-check suite green. |
| L-fast4 | fast.md Evidence | F21 | compare/scale code reviewed; own probes compare+scale all fire (30 selected total, rc=0), including diff/timeout/rc/wall/ratio/RSS/bytes/serve/page/GUI bounds. Known untested false-pass paths F21 remain; no idle timing run. |
| L-author-server | server.md Authoring | F19, reviewer-50-F6 | 6 quoted scope globs parse + match tracked files; dense live law + why, recipes named; known stale 413/fixed-header law F19; explicit user-rulings date remains (F6). |
| L-author-wasm | wasm.md Authoring | reviewer-50-F3 | Dense live build law + reasons; recipes are pin/probe scripts; 13 quoted scope globs parse + match tracked files. No dates/origin story finding; link-guarantee overstatement already F3. |
| L-author-web | web.md Authoring | reviewer-50-F6 | 3 quoted scope globs parse + match tracked files; direct agent law, committed tools named; explicit user-ruling date + old setup event remain (F6). |
| L-author-fast | fast.md Authoring | reviewer-50-F6 | 32 quoted scope globs parse + match tracked files; live performance/proof rules + script recipes; historical was-n² / held-40M wording retains origin story (F6). |

## Details

### reviewer-50-F1 — minor — required multi-font alignment check absent

- Target: `.claude/rules/web.md:23` → `tests/e2e/`, `web/style.css:548–550`.
- Contract: L-web14; rule explicitly requires an alignment check under the default + DejaVu Sans. `CLAUDE.md` Engineering requires a firing gate check for tool-decidable law.
- Anchor: `an alignment check measures under ≥ 2 fonts` (`rg -Fn` matches rule line 23).
- Proof: exhaustive source search over `tests/`, `Tests/`, `tools/` finds no `DejaVu` or `fontFamily`; only CSS + its comments name `text-box`. Existing `getBoundingClientRect` e2e uses measure tour overlap/headline selection, not font alignment. Red command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-50/red-font.py`; output `positive control: rule names DejaVu Sans=True` / `font-switch check files=[]; disabled cap trim stylelint rc=0` / `AssertionError: no firing check: required two-font alignment test is absent; disabled cap trimming passes stylelint`; rc 1. The script restores its `.cap-trim { text-box: none; }` plant. No multi-font alignment owner exists in the gate stage list.
- Fix direction: add a bundled-Chromium alignment test that measures both named fonts; plant misalignment and record its firing. CSS implementation currently conforms; missing check is the finding.

### reviewer-50-F2 — minor — CI engine-cache shape has no firing check

- Target: `.github/workflows/gate.yml:69`; `.claude/rules/wasm.md:27`.
- Contract: L-wasm8 + deterministic-check law. Current key includes all required inputs, but nothing checks that invariant.
- Anchor: `hashFiles('lean-toolchain', 'tools/wasm.lock', 'tools/wasm/**', 'FvtraceWasm/**', 'WasmMain.lean')` matches workflow line 69. Rule anchor: `whatever renames every object or marker`.
- Red witness: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-50/nofire-cache.py` removes `FvtraceWasm/**` + `WasmMain.lean` from the key in the private copy, runs the gate's actual `workflows` (zizmor + actionlint) + `fanout` functions, restores the file. Output: `No findings to report. Good job!` / `workflows+fanout rc=0` / `AssertionError: no firing check: the engine cache key omits both build-tool inputs, but workflows + fanout accept it`; witness rc 1.
- Fix direction: gate a parsed cache contract (key inputs + path exclusion + skip/partial-restore policy), with a failing-key probe. Current workflow is not the stale side; enforcement is missing.

### reviewer-50-F3 — minor — link success does not enforce the source-closure ban

- Target: `.claude/rules/wasm.md:21`; `FvtraceWasm/Build.lean:409–425` (compilation/link + binary contract, no source-closure assertion).
- Contract: L-wasm2: every module in Snapshot's closure stays off Std + FFI; parenthetical claims that any `@[extern]` there fails the link.
- Anchor: `an \`@[extern]\` there fails the link` matches the rule at line 21.
- Red witness: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-50/nofire-wasm.py` appends `@[extern "fvtrace_reviewer50_unprovided"] opaque reviewer50UnusedForeign (n : Nat) : Nat` to the closure's `Fvtrace/Receipt/Basic.lean`, alongside the F4/F5 plants, then runs the owning `nice -n 10 lake build FvtraceEngine`. Output: `Build completed successfully (40 jobs).` / `engine-build rc=0` / `AssertionError: no firing check: a closure module contains @[extern], the allocator is dlmalloc, and gzip uses wall-clock mtime; engine build accepted all three`; witness rc 1. Link section GC drops an unused foreign declaration; link success alone cannot decide this source invariant.
- Fix direction: check the transitive module closure for forbidden imports/foreign declarations, plant an unused foreign declaration in its probe; replace the rule's overstated link-guarantee explanation. Current source closure is compliant, not an FFI-use defect.

### reviewer-50-F4 — minor — allocator policy has no firing check

- Target: `FvtraceWasm/Build.lean:312`; `.claude/rules/wasm.md:24`.
- Contract: L-wasm5: link with Emscripten mimalloc, Lean's own mimalloc path off; deterministic-check law.
- Anchor: `"-sSTACK_SIZE=1MB", "-sMALLOC=mimalloc"` matches Build line 312.
- Red witness: same `nofire-wasm.py`; replacing `-sMALLOC=mimalloc` with valid `-sMALLOC=dlmalloc` does not fail the engine build (rc 0). `Tests/Wasm.lean` + Binary.problems check the ABI, source manifests + parsing, not the allocator flag; the gate names no allocator-policy check.
- Fix direction: expose/check compile-link policy as data and gate its allocator choice, with a dlmalloc plant. Current flag is correct; missing enforcement is the finding. Allocator timing percentages were not remeasured.

### reviewer-50-F5 — minor — reproducibility has no firing check

- Target: `FvtraceWasm/Build.lean:325`; `.claude/rules/wasm.md:26`.
- Contract: L-wasm7: two clean builds in different folders give identical bytes; deterministic-check law.
- Anchor: `gzip.compress(data, 9, mtime=0)` matches Build line 325.
- Red witness: same `nofire-wasm.py`; `mtime=0` → `mtime=None` makes gzip carry current wall-clock time, yet the engine build accepts it (rc 0). The gate's assets check checks each embed against its own current file; the differential checks answers, not build-byte identity. No gate stage compares independent builds or compressed metadata.
- Fix direction: add a reproducibility check with independent output folders (or equivalent decomposed invariants), and a timestamped-compression probe. Existing sorting + path-independent keys + mtime=0 look conformant; two clean production builds were not run in this review.

### reviewer-50-F6 — minor — rules retain provenance instead of live law

- Targets: `.claude/rules/server.md:13`, `.claude/rules/web.md:12–13`, `.claude/rules/fast.md:40`.
- Contract: Authoring: state rules/facts plainly; omit dates + origin stories; keep rules as live law + the reason a fresh reader needs.
- Exact anchors, each rematched with `rg -Fn`: server `user rulings 2026-11-01`; web `user ruling 2026-11-01`; fast `it was n² per scenario` + `the chain third of prereqs held 40 M positions`. Web also narrates a former `O(n)` setup that `put a 134,196-need claim's selection at 0.46 s`.
- These fragments identify a ruling date or an earlier failed implementation, not a current action/constraint. Scope YAML is otherwise sound: 6/13/3/32 quoted globs for server/wasm/web/fast parsed with Prettier's YAML parser; every glob matches a tracked file (scopes.mjs).
- Fix direction: remove ruling dates; express complexity/storage constraints in present terms, retaining only measurements that explain a live bound. Preserve the actual law + its why; history belongs in commits.

### reviewer-50-F7 — minor — selectable-text check does not exercise the selection guard

- Target: `tests/e2e/gui.spec.js:324–344`; guarded behavior = `web/dom.js:89`; contract = `.claude/rules/web.md:20` (L-web11).
- Anchors: `a claim's words select for copying; a plain click opens its details` matches the existing test at line 324; `if (selection && !selection.isCollapsed && selection.toString()) return;` matches the implementation at line 89.
- Red witness: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-50/nofire-selection.py`. The private-copy test routes the actual served `dom.js` and changes the active-selection branch from `return` to `{ open(); return; }`. It asserts that the replacement matched + was delivered (`reviewer50PlantApplied`), then runs the gate's existing named selectable-text e2e. Output: `1 passed (2.0s)` / `selectability guard no-firing witness rc=0` / `AssertionError: ('selectability guard no-firing witness', …)`; witness rc 1. Baseline same test passes.
- Inference: the natural drag in the test does not deliver a click that exercises the guard. The checked drag/copy property is not the checked active-selection-click property. Current implementation is correct; enforcement of this explicit clause is missing.
- Fix direction: add an active non-collapsed text selection + a click that reaches the container, asserting that details stay closed; keep a plain-click control that opens them. Confirm that this plant then fails.

## Register

## Coverage

- 41/41 rows adjudicated; seven new minor findings (F1–F7 above), existing findings cited by their ledger ids. Primary-tree writes = this validator-input deliverable alone; base `HEAD=48bc51d`, tracked-source diff empty. No instructions or Intent edited; no commits/branches/pushes in the target or primary tree.
- Passed: base native binary suite 1834/1834 (1,001,225 differential comparisons); own-copy selected probes `wasm engine palette assets compare scale` = 30 passed, 0 failed; static sink/type/selector plants fire; CLI bind/opener, I/O-status predicate, Config-Ref typing + three equality-proof plants fire; scope YAML parses + every glob matches; cached runtime patch byte-equals committed patch; all 20 tracked Snapshot-closure modules scanned (zero Std imports/foreign declarations); actual wasm import/export ABI inspected.
- Browser evidence: actual bundled Chromium; proxy + selectable-text baseline rerun = 2 passed (34.6 s). Synthetic tour two-size walk passed. First two-worker baseline = 2 passed, 2 timed out at 90 s (feature-fixture tour + proxy teardown); load sampled afterward = 56.43 on 8 CPUs. A load contribution is an inference, not a diagnosed cause; the feature-fixture timeout was not rerun. Default-timeout planted hang fires 90000 ms, rc 1; its observed study removed, both loopback listeners refused, own-process query empty. Confirmed delivered credential-forgetting plant fires null-storage expectation; confirmed single-startup relocation fires export e2e, with `ReferenceError: Cannot access 'factKey' before initialization` captured. Delivered active-selection guard plant stays green (F7).
- Preparation/negative results: a first lint attempt under an ignored ancestor found no files, corrected with the explicitly allowed private git initialization; missing Python YAML module replaced by Prettier's YAML parser. A proxy route installed in the wrong test context + a duplicated (rather than moved) startup insertion were excluded; corrected, confirmed plants decide the rows. Exploratory unused-class/new-color static plants were excluded as insufficient proof that the whole owning gate misses an applied violation.
- Scope limits: no full gate/CI, full browser suite, mutation campaign, independent-kernel replay, idle reference-host scale run or two-clean-folder production rebuild. Fast proof/cost judgments sampled rewrite-sensitive statements/call sites in Spec.Fast, Proofs.Answers/Agree/Lookups/Positions/Json + Answers.Fast/Delta/Forest; kernel correctness belongs to the dedicated C-* reviews. Historical allocator percentages, loaded-host timing measurements + upstream-version assertions not independently remeasured/researched; current code/patch shape checked. Known-finding witnesses were not re-reported or rerun merely to duplicate other reviewers' evidence.
- All hand-planted source files restored: 14 touched-source paths × both copies byte-equal to base. Scratch copies + witness scripts/logs retained for MAIN's reruns; generated test-context captures are evidence inputs, not product edits. Own-process query (`reviewer-50/(tree|static|home)`) has zero matches, rc 1.
- Validator: 41 rows = 21 pass + 20 finding rows; seven new detail sections; marker once, last. Seed-token scan = zero matches (rg rc 1); heading positive control = one match (rc 0). Seed had 41 pending rows (rc 0), so both validator outcomes observed.

reviewer-50-DONE-1
