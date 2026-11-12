# reviewer-17 — C-gui-a · Correctness · 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-gui-a | app.js: request sequencing + engine failure | reviewer-17-F1, reviewer-17-F3, reviewer-17-F4 | Read app.js whole + engine/worker callers; native pending-action witness + exported invalid-details/pairs + idle-worker witnesses red. Coalescing, busy indicator + stacked symbol clicks green. |
| C-gui-a | app.js: hash, history, linked what-if, legacy action | reviewer-17-F2, reviewer-17-F6, reviewer-17-F7 | Read readHash/writeHash/load/legacy/popstate; cross-question reload, damaged-data startup + unavailable-view history witnesses red. Linked duplicate refusal + legacy expansion green. |
| C-gui-a | app.js: token + credential sequence (served) | pass | Read takeToken/storage/forgetToken/answerOf vs server.md GUI law; real server accepts + stores offered token, junk offered retries valid stored, expired stored retries none + is forgotten; address token removed before view history. Proxy 401/Basic/path cases source-read, not rerun. |
| C-gui-a | app.js: render, selection, details, cannotShow | reviewer-17-F5, reviewer-17-F7, reviewer-17-F8, reviewer-17-F9, reviewer-17-F10 | Read render/adopt/selection/details + panels/circuit/lazy callees; foreign-view details accepted, unavailable title lost on Back, text selection unmarked, equal subject titles hide claims, reordered selection leaves mounted window (red). Served/exported smoke + inspected screenshots green; record failure → later valid envelope restores the page. |
| C-gui-a | envelope.js decoder | pass | Read whole vs consumed app/panels/circuit fields; native envelope + three details kinds decode; 24 targeted wrong-type payloads refused; schema/problem/export-wrapper refusals green. Response identity adoption defect = F5 in app. |
| C-gui-a | lookups.js + find.js | pass | Read both whole + consumers; one lookup build per adopt; first-id semantics + need/question maps checked; exact → prefix → words, stable order, empty query + 20-match cap green. Cross-question routing defect = F2 in app. |
| C-gui-a | words.js + dom.js | pass | Read both whole + consumers; words vs contract; count/list/replay-ending/qualifier helpers green. Real DOM selection suppresses open; plain click selects + focuses inspector; readable claim text outside buttons. |
| C-gui-a | tests (gui, responsive, smoke specs) | pass | Read all three specs + fixture lifecycle; assertions fit their tested contract paths, setup/teardown symmetric. Representative scratch-local behavior probes run; original specs/full e2e/axe/timing suites not rerun. Implementation coverage gaps = F1–F10. |

## Scope + evidence

- Frozen target: `/home/eturkes/Projects/fvtrace/.scratch/review-base` at `48bc51d`; read-only throughout. No Git operation, target edit, build, mutation campaign or full gate.
- Live source = target's built binary + Playwright bundled Chromium (`createRequire` from target package). Every native call sets `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/home`; projects, exports, planted inputs + browser tmp stay in reviewer scratch.
- Red/green program: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/gui-checks.mjs`; exact runner: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh`. Individual red commands below return rc 1 because their contract assertion fails; no target source is changed.
- Green: `served-smoke`, `export-smoke`, `served-token-sequence`, `coalesce-busy-selection`, `record-problem-restore`, `dom-selection`, `export-no-wasm-links`. Helpers/structural validation: `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/decoder-checks.mjs` → rc 0; native envelope + all three details kinds, 24 targeted wrong-type refusals, index/search/word checks.
- Inspected screenshots: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/served.png` (recorded text view + C2 inspector), `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/exported.png` (stacked what-if + inspector). Both show the intended content, not a blank launch.
- Logs: `gui-checks.log`, `action-pending.log`, `details-mismatch.log`, `remaining-checks.log`, `remaining-retry.log`, `record-history.log`, `text-highlight.log`, `caller-leads.log`, `decoder-checks.log`, all under `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/`.
- Failed attempt disclosed: three extra probes initially exceeded scratch's 7 s launch/navigation allowance; host load observed 30.94/33.72/30.11. Their rerun with scratch-local 30 s element/90 s navigation allowances passed (`remaining-retry.log`); no grading check changed. Host load as the cause is an inference, not a timing result.
- Coverage limits: structural adversaries sampled (24 payloads), not exhaustive; original e2e/axe/font/tour-placement/full scale suites not run; no performance-bound claim. Proxy 401/Basic/path behavior inspected in `proxy.spec.js`, not rerun. Every source in the assigned slice + all three assigned specs read whole; selected callees read as needed. No finding depends on a search cap or truncated target read.
- Native servers: every launched PID stopped; every closed port probed and refused. Scratch-only unused tree copy removed; red tests + evidence retained for MAIN.

## reviewer-17-F1 — major · an action expands from a pending what-if, not the shown view

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:525` (`spec = view.spec`), `:529`; `setWhatif` changes `view.spec` at `:678`, before its answer paints.
- Contract: kernel.md E-gui + web.md address/request law: action sends its id + the **shown** what-if; pending symbol requests are a different base.
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh action-while-pending` → rc 1.
- Proof: real served synthetic study; select E3, hold O2's evaluation, press E3's success while the page still says recorded, release O2. E3 incorrectly retains the unshown O2 assumption:

```text
{"requests":[{"whatif":"O2=checked"},{"whatif":"O2=checked","action":"success:E3"}],"shownAfterAction":"Showing a what-if: suppose M1 is verified by a checker, O2 is verified by a checker. Nothing has been recorded."}
FAIL action-while-pending: an action must expand from the shown recorded view, not a pending what-if
'O2=checked' !== ''
```

- Fix direction: separate shown normalized spec from requested spec; actions + shown-view details read the former, symbol stacking the latter.

## reviewer-17-F2 — minor · cross-question selection writes the old question into history

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:746` (`writeHash()` before `view.question = q` in `reveal`); same order at `:691` in `on.select`.
- Contract: web.md address-hash law (hash holds the view), kernel.md U-access (find selects + reaches the chosen claim).
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh cross-question-history` → rc 1.
- Proof: move synthetic C3 to Q2; find C3 + Enter visibly shows Q2/C3; reload hides C3 and returns to Q1 because persisted `q` is Q1:

```text
{"qInHash":"Q1","currentQuestionAfterReload":"Effect2 claims","selectedClaimCardsAfterReload":0}
FAIL cross-question-history: cross-question selection must persist the question it shows
'Q1' !== 'Q2'
```

- Fix direction: set the claim's question before writing its selection hash in both routes.

## reviewer-17-F3 — major · invalid detail/pair problems leave the exported engine reusable

- Locations: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:615` (any pair problem silently returned), `:652` (exported details `invalid` routes to served-record `cannotShow`).
- Contract: kernel.md E-gui + web.md address/request law: an `invalid` problem from **any** request ends the engine for the session, restores recorded + engine-off notice, permits no later call.
- Red commands: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh invalid-details-engine invalid-pairs-engine` → rc 1; each case's assertion fails.
- Proof: existing Worker-boundary fault injection; real startup/load + every other request preserved; named details reply replaced with `{problem:{kind:"invalid",message:…}}`. Details case starts from O2 checked then selects C2; another linked what-if still enters the engine. Pair case starts with a claim needing both excluded facts; its auto-details failure is ignored, then a symbol still evaluates:

```text
{"error":"planted invalid details","title":"This analysis cannot be shown","callsAfterInvalidAndAnotherWhatif":3}
FAIL invalid-details-engine: invalid details must end the page engine
{"error":"","requestsAfterInvalidPairs":2}
FAIL invalid-pairs-engine: invalid excluded-pairs answer must end the page engine
```

- Fix direction: classify every exported response centrally before stale-answer dropping; only what-if/action/item problems remain recoverable; every other failure takes the terminal-engine path.

## reviewer-17-F4 — major · an idle Worker error is forgotten; the next evaluation hangs

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:212`–`:235`: `failAll` rejects current waiters alone; settled startup + no waiting request retain no failure state.
- Contract: kernel.md E-abi/E-gui + web.md engine-failure law: a failed Worker ends the engine; later requests show the notice and never call it.
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh idle-worker-error` → rc 1.
- Proof: real exported page loads its Worker; terminate idle Worker + dispatch its error event, then press O2. Listener runs with no waiters; click posts into the dead Worker and remains busy without an engine notice:

```text
{"engineFailureNotice":false,"bodyBusy":"true","calls":1}
FAIL idle-worker-error: idle worker error must persist a terminal failure for the next request
false !== true
```

- Fix direction: persist terminal Worker failure independently of waiters; later `call`s reject immediately + take the page's engine-failure path.

## reviewer-17-F5 — major · foreign-view details are accepted as ready

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:644`–`:658`: returned header discarded; decoded `overrides` never compared with shown envelope.
- Contract: kernel.md U-select: drop a details answer for another view (overrides, or served view header, differ).
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh details-view-mismatch` → rc 1.
- Proof: intercept real served C2 details response; substitute the native engine's actual details under `O2=checked,O3=checked,EN2=proved` + header `different-view`, while recorded stays shown. GUI adopts those details; recorded C2 now falsely says no suggested experiment raises it, instead of its recorded E1+E4 plan:

```text
{"supplied":"different view header + all C2 needs verified details","actualDetailsState":"ready","shown":"Showing the facts as recorded. Press a fact's symbol to see what would change if it were verified.","contradictoryPlan":true}
FAIL details-view-mismatch: a details answer for another view must be dropped
```

- Fix direction: bind requests to generation + shown view + item; compare returned identity + normalized overrides before adopting details (pair replies need the same binding).

## reviewer-17-F6 — minor · malformed export data aborts before the damaged-page handler

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:272`–`:273`: top-level `JSON.parse` + `decodeExported` run outside `load`'s damaged-page catch.
- Contract: kernel.md E-gui: recorded envelope that does not decode shows “This page is damaged”.
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh damaged-data-block` → rc 1.
- Proof: export a real page; replace its `fvtrace-data` text with `!` (positive control asserts changed bytes); open file://. Error box stays empty, loading title remains; uncaught SyntaxError aborts startup:

```text
{"errorBox":"","title":"Loading the analysis…","pageErrors":["Unexpected token '!', \"!\" is not valid JSON"]}
FAIL damaged-data-block: an undecodable recorded data block must show the damaged-page notice
```

- Fix direction: include data parsing + export-wrapper decoding in the damaged-page boundary, preserving Worker-start ordering.

## reviewer-17-F7 — minor · browser Back overwrites the record-problem title from a stale envelope

- Locations: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:956` (unconditional title from `env`), `:1232`–`:1233` (same-spec history renders it without a new answer).
- Contract: web.md record-problem bullet: record failure replaces the view, title = “This analysis cannot be shown”; a **later envelope** restores the page.
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh record-problem-history` → rc 1.
- Proof: select C1; make the real trace ill-formed; select C2 so its details produce record `invalid`; cannotShow title is correct. Browser Back changes only selection, so stale `env` restores title “Synthetic study” while the error + `.unavailable` remain; record still invalid, no later envelope:

```text
{"titleAfterBack":"Synthetic study","stillUnavailable":true,"recordError":"The claims and facts on record have errors. To see them, run fvtrace check in the project folder."}
FAIL record-problem-history: history-only render must retain the record-problem title until a later envelope
+ 'Synthetic study'
- 'This analysis cannot be shown'
```

- Fix direction: represent record unavailability in render state; retain its title across local/history renders until a successful adoption clears it.

## reviewer-17-F8 — minor · a text-view selection has no highlight or selected id state

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:812`: `mark` only marks a claim node when it is `.circuit`; text rows never marked. Callee: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/panels.js:696` (`textRow` id button has no pressed state); `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/style.css:1009` has no text-row selection style.
- Contract: kernel.md U-select + web.md responsiveness: selection moves the highlight + fills details, served + exported; Text is a supported layout.
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh text-selection-highlight` → rc 1.
- Proof: real served page → Text → select C2. Inspector correctly shows C2 + takes focus; text row's appearance/class stays identical to unselected, no selected rows, id lacks pressed state:

```text
{"before":{"background":"rgba(0, 0, 0, 0)","border":"","outline":"rgb(35, 53, 74) none 3px","shadow":"none","className":"text-row"},"after":{"background":"rgba(0, 0, 0, 0)","border":"","outline":"rgb(35, 53, 74) none 3px","shadow":"none","className":"text-row"},"selectedRows":0,"pressed":null}
FAIL text-selection-highlight: a text-view claim selection must show its highlight, not only the inspector
```

- Fix direction: draw/clear claim selection for both layouts (style + id pressed state), keeping marking outside signatures + preserving row identity.

## reviewer-17-F9 — major · equal prospective-subject titles collapse distinct claim groups

- Locations: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:846` (prospective group label from subject title), `:1095`–`:1110` (label used as group identity). Different subject ids may have the same title; `boardGroups` then reuses one section/list and the later subject overwrites the earlier one's rows.
- Contract: Decisions GUI (new-data groups + claims per question); kernel.md U-long/U-access (whole list remains reachable). Model WF-ids makes **ids**, not titles, unique. This silently omits valid claims from both layouts.
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh duplicate-subject-titles` → rc 1.
- Proof: real synthetic copy + second prospective subject N2, same title “New cohort”, its own creator/result/restating C4; native `check` passes. The GUI shows C4 but omits original N/C3:

```text
{"nativeTraceClaims":4,"prospectiveSubjects":["N","N2"],"sameTitle":"New cohort","shown":{"C3":0,"C4":1,"newDataSections":1}}
FAIL duplicate-subject-titles: distinct subjects with the same title must keep both claim groups
+ C3: 0
- C3: 1
+ newDataSections: 1
- newDataSections: 2
```

- Fix direction: give each group a stable semantic key (group kind + subject id), separate from its display title.

## reviewer-17-F10 — minor · a selected card reordered outside its old lazy window disappears + loses focus

- Locations: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:1122` (`g.list.set(rows)` omits `keep`), `:913` (`refocus` only looks for an already-mounted card). `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/lazy.js:108` already supports the keep key.
- Contract: kernel.md U-long (selected/focused item renders first), U-access (focus stays on its item across re-renders); web.md responsiveness + focus law.
- Red command: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/run-gui-checks.sh selected-reorder-window` → rc 1.
- Proof: real generated wide/300; find C290 + Enter (selected + mounted), focus `switch:C290:E290`, Enter proves E290. C290 moves open → Conditional, hence to index 0, outside the old mounted window near 270–300. Hash still selects C290, but no C290 card remains mounted and its focused control vanishes:

```text
{"selectedCardCount":0,"focusedKey":null,"hashSelection":"claim:C290"}
FAIL selected-reorder-window: a selected card reordered outside the old lazy window must stay mounted
0 !== 1
```

- Fix direction: preserve the selected/focused claim key when setting each group's rows (including moves across groups); mount its new position before restoring the exact focused control.

## Register

None.

reviewer-17-DONE-1
