# reviewer-8 — C-fast @ 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-fast | wiring: CLI paths → proved fast constants | pass | `Main.main → Cli.run/runIn/dispatch → withLoaded/Session.load/expand → claimsCmd/gapsCmd/experimentsCmd/planCmd/evalCmd → Answers.fast`; JSON = `Session.envelope/details/complete → Evaluate.*With`. Both examples: recorded + suppose + success, text/projections/plan/details/complete agree (`wiring.py`, rc 0). |
| C-fast | wiring: server path | pass | `Cli.serveCmd → Server.start/handler/answerBody/answer → Session.checked/bindPrepared → Answers.fast → Evaluate.expandWith/detailsWith/envelopeWith`; kept Answers keyed by full view. 12 POST answers byte-equal to CLI; PID stopped + port refused (`wiring.py`, rc 0). |
| C-fast | wiring: page engine (Snapshot, WasmMain) | pass | `lakefile engine → WasmMain.main → Build.build` compiles Snapshot's transitive C; bridge `fvtrace_load/answer → fvtrace_snapshot_load/answer → Snapshot.loadExport/answerExport → Engine.load/answer → Answers.fast → Evaluate.*With`. Stateful wasm/native smoke: 12 byte-equal answers, no stderr (`page.mjs`, rc 0). |
| C-fast | agreement statements: domain + hypotheses | pass | `Spec/Fast.lean:23–37`: unrestricted ∀ Trace / ∀ Scenario / ∀ member-list + binding-list; `Proofs/Agree.lean:107,218`, `Lookups.lean:266,337,342`, `Json.lean:153`; audited statement dumps rc 0. |
| C-fast | unproved code in the slice | pass | 119/120 handwritten defs occur in audited agreement statement closures; sole remainder `Lookups.factSubject?` = `(L.fact? id).map (·.subject)`; read all implementation files, guarded forest fallback + total recursion. No source `csimp` / `implemented_by`. |
| C-fast | Tests/Differential.lean + Tests/Scale.lean | pass | Both files read: differential compares every Answers/Lookups field + envelope against independent reference records across malformed/duplicate/outside/cyclic cases; scale assertions derive from each generated shape. Full suites not rerun here; optional interpreted differential run stopped (rc 143), not counted as a pass. |

## Findings

None.

## Wiring + proof boundary

All source references below = `/home/eturkes/Projects/fvtrace/.scratch/review-base/` at `48bc51d`.

- Native entry = `Main.lean:3` → `Fvtrace/Cli.lean:1129` `run` → `runIn :1122` → `dispatch :1098`. `withLoaded :583` → `load :558` → `Session.load` (`Session.lean:126`); `--action` → `Session.expand :138` → `Evaluate.expandWith` with `Answers.fast`.
- Text = `claimsCmd :622`, `gapsCmd :687`, `experimentsCmd :720`, `planCmd :745` in `Cli.lean`: direct `Answers.fast` records; JSON projections = `envelopeOf :573` → `Session.envelope :135` → `Evaluate.envelope :276` → `envelopeWith (Answers.fast sc)`. `evalCmd :795` routes `--details` → `Session.details :144`, `--complete` → `Session.complete :162`, plain → same envelope. Each of those constructs `Answers.fast` directly, without compiler substitutions.
- Server = `Cli.serveCmd :1016` → `Server.start :260` → `handler :241` → `answerBody :215` → `answer :153`; `Session.checked` calls `Check.violationsWith (Lookups.fast tr)`, `bindPrepared` uses `Lookups.fast` + `Receipt.BindingIndex.of`; cache miss at `Server.lean:182–183` constructs `Answers.fast l.scenario`. Action/details/envelope consumers receive that same record. Cache hit = equality of `Session.viewOf` (digest/review + binding current/reasons + notices + normalized overrides), not merely equality of override keys. Concurrency stays serialized by `Std.Mutex`.
- Page build ≠ page runtime: `WasmMain.main` is the build tool. `lakefile.lean:56–73` gathers `Fvtrace.Snapshot`'s transitive imports' C → `WasmMain.main` → `FvtraceWasm.Build.build`; bridge `c/page_engine.c:44,65` calls exported `fvtrace_snapshot_load` / `fvtrace_snapshot_answer` = `Snapshot.loadExport` / `answerExport` (`Snapshot.lean:128,132`). `Engine.answer :88` constructs/reuses the actual `Answers.fast` record (`:95–96`) and passes it to `Evaluate.expandWith/detailsWith/envelopeWith`. Snapshot decoding → `Check.violations` → `Lookups.fast`; receipt status lookup = `Receipt.BindingIndex.of/find`.
- Shared lookup/digest path: `Session.bindPrepared :98`, `Ctx.build` (`Answers/Delta.lean:84`) and `Overrides.parse` (`Engine.lean:449`) use `Lookups.fast`; `Check.violations :342` + `Lint.warnings :47` use that same constant. Receipt manifest digests (`Receipt.lean:63`) + review digest (`:188`) → `Value.canonical` → `canonicalInto` → `Json.sortMembers` (`Json.lean:345,359`). `Snapshot.encode` + `Session.viewOf` take the same canonical path. The sort theorem covers the sorter, not the printer/FFI. Generated C call-site spot-checks confirm `lp_fvtrace_Fvtrace_Answers_fast` in Cli/Server/Session/Snapshot and `lp_fvtrace_Fvtrace_Json_sortMembers` in canonical printing.
- Agreement roots = `Fvtrace.Proofs.Answers.answersAgree` (`Proofs/Agree.lean:218`), `Fvtrace.Proofs.Lookups.lookupsAgree` (`Proofs/Lookups.lean:342`), `Fvtrace.Proofs.Json.sortMembersAgree` (`Proofs/Json.lean:153`). None assumes WF, id uniqueness, allowed override statuses, acyclicity or record membership. Index comparison laws + forest density/membership/position bounds are internal obligations; unconditional root statements discharge them for every actual fast invocation. `Spec/Fast.lean` docstrings stay within those equalities + the explicitly measured timing boundary.
- Runtime implementation coverage inventory: 120 handwritten `def`s in Answers/Lookups/Index/PTree + Answers/{Delta,Fast,Forest}; 119 present in the union of audited agreement statement closures. Remainder = `Lookups.factSubject?` (`Lookups.lean:64`), a direct field lookup + `Option.map`. All seven files read. No `partial`, `unsafe`, `opaque`, `extern`, `implemented_by` or `csimp` there. Fuel/decreasing recursion bounds cycles/undeclared prerequisite ids; duplicate experiment ids disable forest use; the dense guard controls persistent overlays; out-of-trace claims fall back to their own fields. Printers, transport, cache key construction and compiled-adapter parity remain tested, not proved.

## Checks + limits

Scratch = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-8/`.

| check | command / artifact | result |
|---|---|---|
| Agreement closures + audit | `FVTRACE_HOME=<scratch>/home LEAN_PATH=<base>/.lake/build/lib/lean <base>/.lake/build/bin/fvtrace-trust --statement Fvtrace.Spec.AnswersAgree Fvtrace.Spec.LookupsAgree Fvtrace.Spec.SortMembersAgree` → `closures.txt`, `trust.err` | rc 0; three statement headers; stderr 0 bytes |
| Unconditional theorem application | `(cd /tmp && FVTRACE_HOME=<scratch>/home LEAN_PATH=<base>/.lake/build/lib/lean lean <scratch>/selected.lean)` → `universal-types.log` | rc 0; the four examples use unrestricted Scenario / Trace / binding-list / member-list domains |
| Native + server wiring | `python -I <scratch>/wiring.py` → `wiring.log` | rc 0; 111 successful binary/request calls; both examples, text/projections, action/direct what-if, details of each kind, complete; 12 server replies byte-equal; server PID 892746 stopped, port refused; subsequent anchored pgrep rc 1 |
| Page runtime | `node <scratch>/page.mjs` (after wiring script creates `claims.html`) → `page.log` | rc 0; 12 stateful wasm/native request answers byte-equal, including action, details, refusals, repeated recorded view; stderr empty |
| Differential-only interpreter rerun | `(cd /tmp && FVTRACE_HOME=<scratch>/home LEAN_PATH=<base>/.lake/build/lib/lean lean --run <scratch>/selected.lean)` → `differential.log` | Stopped after outgrowing a quick targeted check; child rc 143, no completed test summary. Not a pass; no timing conclusion. Process absence confirmed by anchored pgrep rc 1. |
| Tool coverage | LSP `documentSymbol` on `Answers/Fast.lean` | No `.lean` server available; used source reads, theorem applications + compiled constants instead. |

Full `Tests/Differential`, native `Tests/Scale`, full gate, independent-kernel replay, mutation campaigns + idle-host `tools/scale.sh --assert` not rerun in this slice. P-bound/P-memory/U-time unconfirmed by this review's smoke runs; baseline/performance rows belong to MAIN. Proof bodies deliberately not reviewed; statement headers + agreement closures read. No target edits/builds; no browser/server left running.

## Register

None.

reviewer-8-DONE-1
