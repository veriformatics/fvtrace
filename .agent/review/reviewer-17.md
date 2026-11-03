# reviewer-17 — C-gui-a · Correctness · 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-gui-a | app.js: request sequencing + engine failure | reviewer-17-F1, reviewer-17-F3, reviewer-17-F4 | Read app.js whole + engine/worker callers; native served pending-action witness + exported invalid-details/pairs + idle-worker witnesses red. |
| C-gui-a | app.js: hash, history, linked what-if, legacy action | reviewer-17-F2, reviewer-17-F6 | Read readHash/writeHash/load/legacy/popstate + export tests; cross-question reload + damaged-data startup witnesses red. |
| C-gui-a | app.js: token + credential sequence (served) | pass | Read takeToken/storedToken/keepToken/forgetToken + ask/answerOf vs server.md GUI law; real server accepts offered credential + stores it, junk offered retries valid stored, expired stored retries none + is forgotten; token removed before view history (`served-token-sequence`, green). Proxy 401/Basic/path cases source-read, not rerun. |
| C-gui-a | app.js: render, selection, details, cannotShow | reviewer-17-F5 | Read render/adopt/selection/details + panels/circuit/lazy callees; mismatched details header + overrides accepted (red). Native served + exported smoke green; screenshots inspected. |
| C-gui-a | envelope.js decoder | pass | Read whole decoder against every consumed field in app/panels/circuit; native envelope + three details kinds decode, 24 targeted wrong-type payloads refused; schema/problem/export-wrapper refusals green (`decoder-checks.mjs`). Response identity adoption defect = F5 in app, not decoder. |
| C-gui-a | lookups.js + find.js | pass | Read both whole + all consumers; one lookup build in adopt, first-id semantics + need/question maps checked; search exact → prefix → words, stable order, empty query + 20-match cap green (`decoder-checks.mjs`). Cross-question routing bug = F2 in app. |
| C-gui-a | words.js + dom.js | pass | Read both whole + consumed call sites; status/verdict/kind/level words vs contract; count/list/replay-ending/qualifier helper checks green; real DOM selection suppresses open, plain click selects + focuses inspector, readable claim text outside buttons (`dom-selection`, green). |
| C-gui-a | tests (gui, responsive, smoke specs) | unknown | unknown |

## Scope + evidence

Frozen target: `/home/eturkes/Projects/fvtrace/.scratch/review-base` at `48bc51d`; target read-only. Test program: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/gui-checks.mjs`; built binary + Playwright bundled Chromium. Every native invocation sets `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/home`; projects, exports, browser tmp + planted inputs stay in reviewer scratch. All started native servers stopped by PID; each closed port refused afterward.

Run prefix for commands below:

```sh
TMPDIR=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/tmp FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/gui-checks.mjs
```

Initial evidence: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/gui-checks.log` (8 cases, 2 pass, 6 red); `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/action-pending.log` (1 case, red). A pending row remains unadjudicated.

## reviewer-17-F1 — major · an action expands from a pending what-if rather than the shown view

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:525` (`spec = view.spec`), `:529`; `setWhatif` changes `view.spec` immediately at `:678`, before its answer paints.
- Contract: kernel.md E-gui + web.md address/request law: action sends its id + the **shown** what-if; a pending symbol request is a different base.
- Red command: run prefix + `action-while-pending`; rc 1.
- Proof: real served synthetic study; select E3, hold O2's evaluation, press E3's success while the page still says recorded, release O2. Output:

```text
{"requests":[{"whatif":"O2=checked"},{"whatif":"O2=checked","action":"success:E3"}],"shownAfterAction":"Showing a what-if: suppose M1 is verified by a checker, O2 is verified by a checker. Nothing has been recorded."}
FAIL action-while-pending: an action must expand from the shown recorded view, not a pending what-if
'O2=checked' !== ''
```

- Fix direction: separate the shown normalized spec from the requested spec; actions + shown-view details read the former, symbol stacking the latter.

## reviewer-17-F2 — minor · cross-question selection writes the old question into history

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:746` (`writeHash()` precedes `view.question = q` in `reveal`); same order at `:691` in `on.select`.
- Contract: web.md address-hash law (hash holds the view), kernel.md U-access (find selects + reaches the requested claim).
- Red command: run prefix + `cross-question-history`; rc 1.
- Proof: move synthetic C3 to Q2; find C3 + Enter visibly shows Q2/C3; reload hides C3 and returns to Q1 because the persisted question is Q1:

```text
{"qInHash":"Q1","currentQuestionAfterReload":"Effect2 claims","selectedClaimCardsAfterReload":0}
FAIL cross-question-history: cross-question selection must persist the question it shows
'Q1' !== 'Q2'
```

- Fix direction: set the claim's question before writing the selection hash in both selection routes.

## reviewer-17-F3 — major · invalid problems from detail/pair requests leave the exported engine reusable

- Locations: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:615` (any pair problem silently returned), `:652` (an exported details `invalid` problem routes to served-record `cannotShow`).
- Contract: kernel.md E-gui + web.md address/request law: an `invalid` problem from **any** request ends the engine for the session, restores recorded + engine-off notice, permits no later call.
- Red commands: run prefix + `invalid-details-engine`; run prefix + `invalid-pairs-engine`; each rc 1.
- Proof: fault injection at the existing Worker boundary, preserving real startup/load and every other request; replace the named details reply with `{problem:{kind:"invalid",message:…}}`. Details case starts from O2 checked, then asks C2's details; another linked what-if still enters the engine. Pair case starts on a claim needing both excluded facts; its auto-details failure is ignored, then a symbol still evaluates:

```text
{"error":"planted invalid details","title":"This analysis cannot be shown","callsAfterInvalidAndAnotherWhatif":3}
FAIL invalid-details-engine: invalid details must end the page engine
{"error":"","requestsAfterInvalidPairs":2}
FAIL invalid-pairs-engine: invalid excluded-pairs answer must end the page engine
```

- Fix direction: classify every exported response centrally before stale-answer dropping; only what-if/action/item problems remain recoverable, and every other failure takes the one terminal-engine path.

## reviewer-17-F4 — major · a Worker error while idle is forgotten; the next evaluation hangs

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:212`–`:235` (`failAll` rejects current waiters alone; settled startup + no waiting requests retain no failed state).
- Contract: kernel.md E-abi/E-gui + web.md engine-failure law: a failed Worker ends the engine; later requests show the notice and never call it.
- Red command: run prefix + `idle-worker-error`; rc 1.
- Proof: real exported page loads its Worker; terminate the idle Worker + dispatch its error event, then press O2. The listener ran with no waiters; the click posts into the dead Worker and stays busy, with no engine notice:

```text
{"engineFailureNotice":false,"bodyBusy":"true","calls":1}
FAIL idle-worker-error: idle worker error must persist a terminal failure for the next request
false !== true
```

- Fix direction: persist terminal worker failure independently of waiting requests; all later `call`s reject immediately and the page takes its engine-failure path.

## reviewer-17-F5 — major · details for a different view are accepted as ready

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:644`–`:658`: returned header discarded; decoded `overrides` never compared with the shown envelope.
- Contract: kernel.md U-select: a details answer for another view (overrides, or served view header, differ) is dropped.
- Red command: run prefix + `details-view-mismatch`; rc 1.
- Proof: real served C2 details reply intercepted; replace `X-Fvtrace-View` with `different-view` and overrides with O2 checked while recorded remains shown. The page marks the inspector ready and renders the foreign details:

```text
{"supplied":"different view header + O2=checked details","actualDetailsState":"ready","shown":"Showing the facts as recorded. Press a fact's symbol to see what would change if it were verified."}
FAIL details-view-mismatch: a details answer for another view must be dropped
```

- Fix direction: bind the request to generation + shown view + item; compare returned view identity and normalized overrides before adopting its details (pair replies need the same check).

## reviewer-17-F6 — minor · malformed exported data JSON aborts before the damaged-page handler

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:272`–`:273`: top-level `JSON.parse` + `decodeExported` run outside `load`'s damaged-page catch.
- Contract: kernel.md E-gui: a recorded envelope that does not decode shows “This page is damaged”.
- Red command: run prefix + `damaged-data-block`; rc 1.
- Proof: export a real page; replace exactly its `fvtrace-data` text with `!` (positive control asserts bytes changed); open from file://. Error box stays empty; loading title remains; an uncaught SyntaxError aborts module startup:

```text
{"errorBox":"","title":"Loading the analysis…","pageErrors":["Unexpected token '!', \"!\" is not valid JSON"]}
FAIL damaged-data-block: an undecodable recorded data block must show the damaged-page notice
```

- Fix direction: include data JSON parsing + export-wrapper decoding in the damaged-page boundary, while preserving Worker-start ordering.

## Register

None yet.
