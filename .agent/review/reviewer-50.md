# reviewer-50 — L rules-b conformance

Target = `48bc51d`, frozen `.scratch/review-base`; check set = L-srv1…9, L-wasm1…9, L-web1…15, L-fast1…4 + Authoring per rule file. Read-only target; planted inputs only in `.scratch/review/reviewer-50/tree`.

| row | bullet | verdict | basis |
|---|---|---|---|
| L-srv1 | server.md Routes | F19, F20 | Server.decide/answer + Tests.Server.answerTests: routes + CLI byte equality + problem copy agree; known framing-cap + untagged item-error exceptions. |
| L-srv2 | server.md I/O | pass | lean-test Tests.Server.nativeTests + Session.closeCache; native suite green; lean-plants.py changes I/O response to 400 → same native-test predicate FAIL got (400, some io), want (500, some io). |
| L-srv3 | server.md Access order | F19 | Server.decide + Cli.tokenOf/serveCmd agree; framing-limit ordering already F19; pure/native server tests pass in native suite. |
| L-srv4 | server.md Bind | pass | Cli.serveLoopback bounded retry + fixed-port busy/unsupported branches read; lean-pure Tests.Cli.bindTests fires when IPv6 bind removed (24/26; named busy-[::1] FAIL). |
| L-srv5 | server.md Link + opener | pass | Cli.browserOpener/openBrowser/serveCmd + bindTests agree; linux display opener changed to none → lean-pure named xdg-open FAIL; native base suite green; full output modes read. |
| L-srv6 | server.md GUI token | unknown | unknown |
| L-srv7 | server.md Fixed headers | F19 | Server.toResponse appends fixedHeaders; known framing response bypass = F19 (no new security analysis). |
| L-srv8 | server.md Config Ref | pass | Cli.serveCmd builds IO.mkRef hosts=[] before start, modifies afterward; lean-build compiler fires on non-Ref plant: expected IO.Ref Server.Config (lean-plants.log). |
| L-srv9 | server.md e2e harness | pass | e2e helper source + gate STAGES; planted hanging spec hits actual default 90000ms limit, rc=1; worker exit removes observed study + closes both listeners; pgrep own binary path = 0 processes. |
| L-wasm1 | wasm.md Pipeline | unknown | unknown |
| L-wasm2 | wasm.md Closure | reviewer-50-F3 | Current Snapshot closure is Init + Fvtrace; unused @[extern] added to Receipt.Basic is dropped by link GC, so engine build succeeds. Parenthetical guarantee overstated; no structural closure guard (nofire-wasm.py). |
| L-wasm3 | wasm.md Pins | unknown | unknown |
| L-wasm4 | wasm.md Runtime patch | unknown | unknown |
| L-wasm5 | wasm.md Allocator | reviewer-50-F4 | Build.link currently passes -sMALLOC=mimalloc, headers omit LEAN_MIMALLOC; dlmalloc plant is accepted by owning engine-build check. No firing allocator-policy assertion (nofire-wasm.py). |
| L-wasm6 | wasm.md Link contract | unknown | unknown |
| L-wasm7 | wasm.md Determinism | reviewer-50-F5 | Source sorts app/Init and preserves runtime order; relative flags/object hash + CFGDIR + mtime=0 agree. mtime=None plant still builds; no reproducibility check compares clean folders (nofire-wasm.py). |
| L-wasm8 | wasm.md CI cache | reviewer-50-F2 | Current CI key/cache scope/weekly bypass/partial restore match rule; planted omission of FvtraceWasm/** + WasmMain.lean → workflows+fanout rc=0; no firing cache-shape check (nofire-cache.py). |
| L-wasm9 | wasm.md Probes | unknown | unknown |
| L-web1 | web.md Display only | pass | Judgment: app groups + circuit/conditions + panels inspector/work/experiments/plan consume engine final, verdict, summary, lists and rankings; display transformations only, no re-derived engine judgment. |
| L-web2 | web.md Request law | F24, F37–F41 | app.js ask/evaluation/load/loadDetails/readHash + worker reviewed; known idle error, fatal shape, action pending-view, hash question, detail-view gaps. |
| L-web3 | web.md Record problem | F27, F42 | cannotShow + .unavailable + gui.spec.js: active tour stays; history can restore old envelope before a new one (known). |
| L-web4 | web.md Responsiveness | F26, F43–F45, F50 | app.js/renderBoard/find + lazy.js + panels.js + responsive.spec.js: known eager Needed-by, text highlight, duplicate titles, focus window + find lookup gaps. |
| L-web5 | web.md DOM sinks | pass | js-lint oxlint --type-aware --deny-warnings web; .oxlintrc no-restricted-properties; planted document.body.innerHTML assignment fires HTML-string sink rc=1 (static-plants.log); CSP clause covered by F19 row. |
| L-web6 | web.md No build + types | pass | web/tsconfig strict+noUncheckedIndexedAccess+exactOptionalPropertyTypes; JS modules no bundler; unknown-property plant → tsc rc=1, fetched-any plant → oxlint no-unsafe-assignment rc=1. |
| L-web7 | web.md Chromium | unknown | unknown |
| L-web8 | web.md e2e limits | F34, F36 | Configured 90s/default + 300s/smoke + 600s/engine match law; planted hang fires actual 90000ms timeout. Known load-threshold floor + interrupted-load cleanup defects F34/F36; no loaded-host rerun here. |
| L-web9 | web.md Palette | unknown | unknown |
| L-web10 | web.md Selectors | pass | js-lint stylelint selector-max-id=0 + specificity=0,2,1 fires planted #reviewer-50-probe rc=2; existing display-setting hidden controls .working/.find*/.work/.tour-spot checked for hidden rules. |
| L-web11 | web.md Selectable text | unknown | unknown |
| L-web12 | web.md Startup | unknown | unknown |
| L-web13 | web.md Verdict words | unknown | unknown |
| L-web14 | web.md Fonts | reviewer-50-F1 | CSS has cap trimming + tabular nums, but no alignment test sets ≥2 fonts; entire tests/tools/Tests source search has 0 DejaVu/fontFamily hits; text-box:none plant passes stylelint rc=0. |
| L-web15 | web.md Tour | unknown | unknown |
| L-fast1 | fast.md Equality proofs | pass | Spec.Fast + Proofs.Agree/Lookups/Json; lean-build kernel fires on all three false-conjoined equality plants (lean-plants.py); actual native 1,001,225 differential comparisons + base suite green. |
| L-fast2 | fast.md Cost traps | F47 | Receipt.BindingIndex, ClaimMemo.needs, forest closures + plan memoAt reviewed; known Snapshot.answer rebuilds immutable binding index on cached details (F47). |
| L-fast3 | fast.md Pair projections | pass | Judgment: rewrite-sensitive pair lambdas in Spec.Fast + Proofs.Agree/Answers/Lookups/Positions + Json use projections or rewrite locally; native build proof artifacts + 1834-check suite green. |
| L-fast4 | fast.md Evidence | unknown | unknown |
| L-author-server | server.md Authoring | unknown | unknown |
| L-author-wasm | wasm.md Authoring | reviewer-50-F3 | Dense live build law + reasons; recipes are pin/probe scripts; 13 quoted scope globs parse + match tracked files. No dates/origin story finding; link-guarantee overstatement already F3. |
| L-author-web | web.md Authoring | unknown | unknown |
| L-author-fast | fast.md Authoring | unknown | unknown |

## Details

### reviewer-50-F1 — minor — required multi-font alignment check absent

- Target: `.claude/rules/web.md:23` → `tests/e2e/`, `web/style.css:548–550`.
- Contract: L-web14; rule explicitly requires an alignment check under the default + DejaVu Sans. `CLAUDE.md` Engineering requires a firing gate check for tool-decidable law.
- Anchor: `an alignment check measures under ≥ 2 fonts` (`rg -Fn` matches rule line 23).
- Proof: exhaustive source search over `tests/`, `Tests/`, `tools/` finds no `DejaVu` or `fontFamily`; only CSS + its comments name `text-box`. Existing `getBoundingClientRect` e2e uses measure tour overlap/headline selection, not font alignment. Positive control = the rule's single `DejaVu Sans` hit, rc 0. `python3 -I .scratch/review/reviewer-50/static-plants.py` plants `.cap-trim { text-box: none; }`; `pnpm exec stylelint web/style.css` returns 0. No multi-font alignment owner exists in the gate stage list.
- Fix direction: add a bundled-Chromium alignment test that measures both named fonts; plant misalignment and record its firing. CSS implementation currently conforms; missing check is the finding.

### reviewer-50-F2 — minor — CI engine-cache shape has no firing check

- Target: `.github/workflows/gate.yml:69`; `.claude/rules/wasm.md:25`.
- Contract: L-wasm8 + deterministic-check law. Current key includes all required inputs, but nothing checks that invariant.
- Anchor: `hashFiles('lean-toolchain', 'tools/wasm.lock', 'tools/wasm/**', 'FvtraceWasm/**', 'WasmMain.lean')` matches workflow line 69. Rule anchor: `whatever renames every object or marker`.
- Red witness: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-50/nofire-cache.py` removes `FvtraceWasm/**` + `WasmMain.lean` from the key in the private copy, runs the gate's actual `workflows` (zizmor + actionlint) + `fanout` functions, restores the file. Output: `No findings to report. Good job!` / `workflows+fanout rc=0` / `AssertionError: no firing check: the engine cache key omits both build-tool inputs, but workflows + fanout accept it`; witness rc 1.
- Fix direction: gate a parsed cache contract (key inputs + path exclusion + skip/partial-restore policy), with a failing-key probe. Current workflow is not the stale side; enforcement is missing.

## Register

## Coverage

Pending rows retain their seed values. Commands + planted-input witnesses will be recorded below.
