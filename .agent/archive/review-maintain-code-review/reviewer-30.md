# reviewer-30 — K-server + K-export at `48bc51d`

Scope = Cleanup + Altitude; separate pass per lens × slice. Target = `/home/eturkes/Projects/fvtrace/.scratch/review-base`; read-only. Security → MAIN. Known framing-413 / item-header refusal / idle Worker-error observations excluded.

| row | target | verdict | basis |
|---|---|---|---|
| K-server | Cleanup: Server.lean + tests | reviewer-30-F1, reviewer-30-F2 | Complete slice read; query-field readers + duplicated reply-problem decoder searched across source/test/tool/proof/CI trees. |
| K-server | Altitude | pass | Separate pass: decide → answerBody → Session/Evaluate; pure decide, late Config reference + injected I/O-failure seam match server.md; no caller-specific workaround to move. |
| K-export | Cleanup: Export + WasmMain + FvtraceWasm/* + c bridge | reviewer-30-F3, reviewer-30-F4, reviewer-30-F6 | Complete code + Lean-test read; ABI-list derivation, fetch dependency graph + local parser branches inspected; utility callers searched repo-wide. |
| K-export | Cleanup: engine.js + worker.js + tools/pin-wasm.sh + tests | reviewer-30-F5, reviewer-30-F7 | Complete loader/worker/pinner + JS-test read; existing counter helper cloned twice; six fixture helpers exported without an importing consumer. |
| K-export | Altitude | pass | Separate pass: bundle blocks/dependency ordering, ABI host/bridge, pin/manifest/cache + runtime patch; build-specific adapters stay at their boundaries. No mechanism-level special case found beyond the contract's explicit platform/runtime allowances. |

## reviewer-30-F1 — dead query callback in the pure request record

- Severity = minor. `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean:69` + `:230`; `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Server.lean:13–16`.
- Contract = CLAUDE.md Engineering → Cleanup: dead code removed.
- `Req.query` is constructed by `reqOf` + the test constructor, never read. Complete `*.lean` search for `query` finds only those constructors, the field + a test's description. The callback serves neither `decide` nor the POST answer; the API still makes callers provide it.
- Anchors: `query : String → Option String`; `query := fun k => r.line.uri.query.get k`; `query := fun k => query.lookup k`.
- Evidence command: `rg -n --hidden -g '*.lean' '\bquery\b' /home/eturkes/Projects/fvtrace/.scratch/review-base` → exactly 5 source lines (2 field initializers, the field, test constructor parameter, test description), rc 0. Positive control `rg -Fn 'query : String → Option String' …/Fvtrace/Server.lean` → expected 1 match (`69`), rc 0. `rg -n --hidden -g '*.lean' 'Req\.query|req\.query' /home/eturkes/Projects/fvtrace/.scratch/review-base` → 0 matches, rc 1. No first-class/projected use elsewhere; `Req`-reference sweep resolves only Server + its tests.
- Fix → remove the unused field + constructors' callbacks; retain query-ignored behavior coverage at the transport boundary rather than carrying unused state into `decide`.

## reviewer-30-F2 — duplicated reply-problem decoder in server tests

- Severity = minor. `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Server.lean:30–38,115–120`.
- Contract = CLAUDE.md Engineering → Cleanup: existing helpers reused, near-duplicate blocks merged.
- `decidedKind` reimplements `problemKind`'s `Json.parse` / exact problem-object shape / `kind` string extraction. The sole extra operation is unpacking `Action.reply`; both decode the same `Reply.body`. This is the same parser maintained twice within one test module, not two different oracles.
- Anchors: `def decidedKind (a : Action) : Option String :=`; `def problemKind (r : Reply) : Option String :=`; `some (.obj [("problem", .obj ps)]) => match ps.lookup "kind" with` (matches lines 33 + 117).
- Proof = the enclosing bodies at the cited ranges; `rg -Fn` matches both repeated nested matches. `body` at line 113 already owns reply-body JSON parsing for `problemKind`.
- Fix → move `body` + `problemKind` before `decidedKind`; implement the `.reply r` arm with `problemKind r`, retaining every test case.

## reviewer-30-F3 — the linker export list duplicates its own ABI contract

- Severity = minor. `/home/eturkes/Projects/fvtrace/.scratch/review-base/FvtraceWasm/Build.lean:282–285`; `/home/eturkes/Projects/fvtrace/.scratch/review-base/FvtraceWasm/Binary.lean:137–139`.
- Contract = CLAUDE.md Engineering → Cleanup: derivable state computed, never duplicated.
- `Build.exportedFunctions` manually repeats the five `fvtrace_*` functions already named by `Binary.requiredExports`. `Build` imports `Binary`; the linker list is exactly the ABI list's function entries except the automatically exported `_initialize`, with Emscripten's `_` prefix. Nothing here needs an independently maintained second list. A function addition/rename currently requires coordinated edits or fails the post-link check.
- Anchors: `def exportedFunctions : String :=`; `def requiredExports : List (String × Nat) :=`; `s!"-sEXPORTED_FUNCTIONS={exportedFunctions}"`.
- Proof = both complete list bodies at the cited ranges + the link use at Build:312. Structural witness: `(cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-30/abi-list.lean)` → rc 0, `derived=_fvtrace_init,_fvtrace_alloc,_fvtrace_free,_fvtrace_load,_fvtrace_answer`, identical `listed=…`, `equal=true` (log = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-30/abi-list.log`). The exact current order is derivable too. No behavior defect claimed.
- Fix → define the bridge ABI function list once; derive `requiredExports` + `exportedFunctions` from it (memory + `_initialize` remain the generated exports).

## reviewer-30-F4 — independent engine-build inputs are acquired serially

- Severity = minor. `/home/eturkes/Projects/fvtrace/.scratch/review-base/FvtraceWasm/Build.lean:380–390`.
- Contract = CLAUDE.md Engineering → Cleanup: independent steps parallel; startup paths lean.
- `emsdk cfg sdkPin`, `gitTree cfg rtPin …`, `gitTree cfg uvPin …` + `initC cfg` are awaited serially. Their inputs are already known from `cfg` + the parsed pins; none consumes another's result. Their cache namespaces differ (`emsdk-{…}`, `lean-runtime-{key}`, `libuv-{key}`, `init-c-{githash}`). The first join actually required is libuv-tag validation (runtime + libuv), then compile (all inputs). `parallel` already exists for the compile/generate batches.
- Anchors: `let install ← emsdk cfg sdkPin`; `let rt ← gitTree cfg rtPin`; `let uv ← gitTree cfg uvPin`; `let initFiles ← initC cfg`.
- Proof = Build:136–202 (acquisition arguments + distinct paths), :239–257 (`initC` uses `cfg` alone), :380–390 (serial calls), :397–419 (actual consumers). Cold-path wall-clock effect unmeasured; no numerical speedup claim.
- Fix → start independent acquisitions + Init-C generation with bounded tasks, join before each true consumer; keep deterministic source/link ordering + collect every failure.

## reviewer-30-F5 — existing evaluation-counter helper is cloned by two export tests

- Severity = minor. `/home/eturkes/Projects/fvtrace/.scratch/review-base/tests/e2e/export.spec.js:389–396,413–421,441–449`.
- Contract = CLAUDE.md Engineering → Cleanup: existing helpers reused; near-duplicate blocks merged.
- `evaluations(page)` already reads `fvtraceCalls`, calls the recorded function when present, narrows the result to a number + returns -1 otherwise. The details-failure + mid-session-failure tests each inline that same whole `page.evaluate` callback. They need the helper's exact result, not a distinct browser-side operation.
- Anchors: `const evaluations = (page) =>`; `const count = Reflect.get(globalThis, "fvtraceCalls");` (3 matches: 391, 415, 445).
- Proof = all three complete callbacks at the cited ranges; the second uses an early return instead of the helper's ternary, with the same result for every value/type of `fvtraceCalls` + its return. `evaluations` is initialized before Playwright runs the registered test callbacks.
- Fix → both tests call `await evaluations(page)`; retain their count assertions + all cases.

## reviewer-30-F6 — unreachable parser-failure arm in the wasm entry point

- Severity = minor. `/home/eturkes/Projects/fvtrace/.scratch/review-base/WasmMain.lean:6–11`.
- Contract = CLAUDE.md Engineering → Cleanup: dead branches removed; KISS.
- Local `opts` returns `Except String …`, but every terminal clause returns `.ok` and its only recursive call returns the same parser result. It cannot construct `.error`; `(opts args []).toOption` is always `some`. The `let some … | return 2` failure arm is unreachable, and the Except layer carries no information. Actual missing-required-option handling remains the next match + usage message.
- Anchors: `if k.startsWith "--" then opts rest ((k, v) :: acc) else .ok (acc, k :: v :: rest)`; `| rest, acc => .ok (acc, rest)`; `let some (kv, cFiles) := (opts args []).toOption | return 2`.
- Proof = exhaustive three-clause local parser body at WasmMain:6–10; no failure constructor or exception in any clause.
- Fix → return the option-pair + C-file list directly and bind the pair; preserve the subsequent required-key validation.

## reviewer-30-F7 — six fixture-internal helpers expose unused exports

- Severity = minor. `/home/eturkes/Projects/fvtrace/.scratch/review-base/tests/engine/cases.mjs:38,41,56,67,74,189`.
- Contract = CLAUDE.md Engineering → Cleanup: unused exports removed (LENSES.md K).
- `statuses`, `random`, `traceAt`, `factIds`, `snapshotOf` + `actionSpecs` are used inside `cases.mjs` only. No importing consumer uses any of these six exports. Their implementations are live; the `export` modifiers are the dead surface.
- Anchors: `export const statuses =`; `export function random(seed)`; `export function traceAt(path)`; `export const factIds =`; `export function snapshotOf(trace,`; `export function actionSpecs(snapshot)`.
- Proof: complete importer sweep `rg -n --hidden 'cases\.mjs' /home/eturkes/Projects/fvtrace/.scratch/review-base` + all four source import lists: `tests/engine/engine.test.mjs:8–17`, `tests/engine/loader.test.mjs:7`, `tests/e2e/engine.spec.js:6–14`, `tools/scale-page.mjs:12`. None imports those names; all import named bindings, no namespace consumer. Repo-wide identifier sweep finds these six bindings' uses only within their defining module (other modules' unrelated `statuses` / `random` / Lean `factIds` are different bindings).
- Fix → keep the six helpers module-local, retaining the externally consumed fixture API + every test case.

## Coverage + limits

- Read every assigned source + test in full; Cleanup and Altitude adjudicated separately. Source reference searches cover implementation, tests, tools, web, proofs, Lakefile + workflows. Generated engine/tool caches inspected only for the server's compiled cached-body branch.
- `Server.answer`'s `text.getD` initially merited a check for eager envelope work: compiled `Server.c:2148–2186` calls `Evaluate.envelopeWith` only in the `none` branch; the cached-byte path does not print a new envelope. No finding.
- LSP: JavaScript `web/engine.js` document-symbol query succeeded. Lean query on `Fvtrace/Server.lean` returned `No LSP server available for file type: .lean`; references checked with complete source searches instead.
- Ran = anchor/reference searches (`bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-30/anchors.sh` → rc 0; `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-30/anchors.log`) + the F3 pure ABI-list witness (rc 0). Table validator = 5 adjudicated rows, 0 remaining seed cells; marker exactly once. Runtime suites / full gate / mutation / timing / browser QA = not run; this is the fixed structural Cleanup + Altitude review, not a correctness or baseline all-clear. No server started, no fvtrace command invoked, target untouched.
- Unconfirmed = cold-build speedup magnitude (F4); no measurement performed. No unconfirmed behavior finding.

## Register

- security → MAIN
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/tests/e2e/export.spec.js:438` — `engineStarted` uses a fixed 100 ms delay for queued answers; sufficiency under host load unconfirmed (read only, no timing run). Correctness/test-readiness question → MAIN/C-export, outside K.

reviewer-30-DONE-1
