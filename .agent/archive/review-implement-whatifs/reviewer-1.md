# reviewer-1 · closing review (U11) · lens R1 · target 01cf228^..f3bc87f

| id | asks (see .agent/review.md) | verdict |
|---|---|---|
| R1.1 | every output path (CLI `eval` + `--action` / `--details` / `--complete`, `POST /api/answer`, the export page + its engine, the GUI) reads the v2 envelope + details from the engine's records; the server cache (P-cache: decoded trace by bytes, last answer + envelope text by view, launch wait) and the page engine state (E-state) are transparent: every answer byte-equal to an uncached one | pass: shared record/codec paths inspected; 54 native/server/wasm requests + cache changes, 180 `cmp` passes, 29 complete-item payloads, every CLI projection + action kind; pure snapshot kept/fresh equality passes |
| R1.2 | the forest walk, presummaries + raisers (`Fvtrace/Answers/{Forest,Delta,Fast}.lean`, `Fvtrace/PTree.lean`): edge cases (duplicate ids, cycles, forward requires, records outside the trace, the dense guard, 0/1/20/21+ relevant), termination, laziness (no closure kept for all experiments) | pass: core + proof interfaces inspected; `AnswersAgree` retains unrestricted Scenario equality and only the three permitted axioms; differential 512/512 checks, 1,001,225 field comparisons across the malformed corpus + 21 prerequisite families |
| R1.3 | shell code changed in the phase (Json parser + printers, Evaluate, Session, Server, Snapshot, Export page v4, Cli flags) keeps behavior on its whole domain: refusal order + messages, the body cap (413), 409 `view`, malformed requests, byte budgets | finding: R1-F5 |
| R1.4 | the GUI (`web/`) does what U-select, U-update, U-long, U-access, U-busy, U-coalesce say and stays display-only (no verdict computed in JS): request numbers, one evaluation in flight, pairs per card on screen, the find route, page v4's engine start (message order), failure paths (engine dead, 409, a refused what-if) | finding: R1-F1, R1-F2, R1-F3, R1-F4 |
| R1.5 | the page engine's closure stays `Init`-only + total; the wasm link contract holds under mimalloc; native ↔ wasm parity covers every request kind | pass: 20-module local Snapshot closure, no non-Init imports; total semantic core, only the rule-permitted Json shell partials; actual wasm has 11 allowed imports + all 7 required exports; both fixtures' 54 request answers agree, no engine stderr |

## Evidence scope

- Target = `f3bc87fc549b140558f9a7cff25a7a31d11e6fdf`; checkout = `.scratch/worktrees/v1`. Check set fixed before diff reading. Source/build trees read-only; scripts, generated fixtures, logs + screenshots confined to this report's folder.
- Binary SHA-256: `fvtrace` = `70f9690bad7b30e5458318efb8777bfe1d165718002d0d9a129c5b28bc48bf4d`; `fvtrace-tests` = `9ba80e220b920df27f0710b3754a4f65eb3a5eaf0c53c77f997119ab50a8652d`.
- Source pass: Request/Evaluate/Session/Server/Snapshot/Export/Json, changed CLI functions + Index annotations, Answers/Delta/Forest/Fast/PTree and their call sites, agreement/closure/walk/singleton/PTree proof interfaces, C bridge + wasm link changes, app/lazy/lookups/find/circuit/panels/envelope/engine/worker. Proof interfaces + imported theorem/axioms checked; independent-kernel replay and a line-by-line re-proof of every lower tactic lemma were not run.
- `semantic-probe.lean`: target `Tests.Differential.tests`, interpreted through target oleans on an offload local slot. rc 0; 512/512 checks; 1,001,225 comparisons; seed `19798168526996293`; 21 families include chains/stars/creator self + pair cycles/lattices/forward/duplicates/dangling success/exclusions/long outcomes/strength ties/touched results/ancestor failures/deep relevance/0,1,2..20,21+/outside records/arbitrary overrides/malformed statuses. Log = `.scratch/reviewer-1/semantic-probe.log`. Runtime 682,897 ms is interpreter evidence, not a product-performance measurement.
- `codec-probe.lean`: target Json.tests + Evaluate.tests + Snapshot.pureTests/stateTests. rc 0; 125/125 checks, including escapes/Unicode/UTF-8/depth/digit/duplicate-key bounds, printers, envelope fields and fresh-versus-kept snapshot answers. Log = `.scratch/reviewer-1/codec-probe.log`.
- `node .scratch/reviewer-1/parity-probe.mjs fixture` and the same command with `synthetic`: both rc 0. 26 + 28 ordered requests; 85 + 95 `cmp` passes; 15 + 14 complete-item payloads equal independent details. Both use all 3 item kinds; synthetic asserts all 4 action kinds (fixture has no plan action). Each checks 4 JSON projections; 12 + 16 CLI text invocations via actions equal explicit expansions. Refusal order/messages, malformed requests, NUL via native snapshot hook, body exactly at cap, trace/evidence edits, whitespace-only edits, bad→restored trace and 409 view conflicts checked. Logs = `parity-fixture.log`, `parity-synthetic.log` beside this report.
- Initial combined parity run exposed the over-cap connection reset; that check remains red in its own `body-cap-probe.mjs`, rather than preventing independent cache checks. Oversize response is not counted among parity passes.
- Coverage limits: request parity = two small fixtures and representative action per kind, not every possible request; differential = stated generated corpus; no full gate, full Node/Chromium engine suite, mutation campaign, old-v1 `tools/compare.sh`, full-cap scale run or independent-kernel replay. No new universal compiled-behavior/performance claim. Lean LSP unavailable; JS LSP hover on `LazyList` worked.
- Every started server stopped; each port then refused a connection. Every screenshot inspected. No commits, installs, target edits or target builds.

## Findings

### R1-F1 — a details-engine failure leaves the exported what-if on screen

- **Severity: major.** Contract: E-gui — any engine failure → engine dead, recorded envelope + engine-failed notice; E-abi — no subsequent call.
- Anchor: `.scratch/worktrees/v1/web/app.js:588–593`, distinctive bytes `details = exported`. The catch selects only an off-line in the inspector. Evaluation failures call `engineFailure(exported)`; details failures do not. `askPairs` also swallows its exception at `:553`.
- Red command: `node .scratch/reviewer-1/gui-probe.mjs engine-details-failure` → rc 1. Real exported engine first accepts `O2=checked`; the next details request receives a planted Worker failure, the same fault boundary used by the existing export tests.
- Failing output:
  ```text
  control: real engine accepted O2=checked
  after-details-trap {"scenario":"Showing a what-if: suppose O2 is verified by a checker. Nothing has been recorded.","error":"","errorHidden":true,"active":null,"busy":null,"contacts":11,"errors":[]}
  FAIL engine-details-failure: E-gui: a details trap must reset the exported page to recorded evidence
  ```
- Evidence: `.scratch/reviewer-1/engine-details-failure.log`, `.scratch/reviewer-1/engine-details-failure.png`.
- Fix idea: one fatal-engine handler for every request kind; reset/render once + invalidate pending work. Keep recoverable what-if/action/item refusals separate.

### R1-F2 — a changed deep card discards its focused late contact

- **Severity: minor.** Contract: U-long — focused item renders first; U-access — focus stays on its item across re-renders, including one card with many needs.
- Anchors: `.scratch/worktrees/v1/web/lazy.js:274–279`, `const lazy = new LazyList(el, {` creates a fresh nested list without a kept key; `.scratch/worktrees/v1/web/app.js:811–820`, `function refocus(key)` only searches mounted controls.
- Red command: `node .scratch/reviewer-1/gui-probe.mjs nested-focus` → rc 1. Real `deep 300` server; keyboard mounts + focuses `switch:C0:F251`, then Enter applies its what-if. The replacement card no longer mounts that contact.
- Failing output:
  ```text
  before-deep-toggle ... "active":"switch:C0:F251" ... "contacts":262 ...
  after-deep-toggle ... "active":null ... "contacts":181 ...
  FAIL nested-focus: U-access: focus stays on its late contact after the what-if re-renders its card
  ```
- Evidence: `.scratch/reviewer-1/nested-focus.log`, `.scratch/reviewer-1/nested-focus.png`.
- Fix idea: pass the focused/selected key into rebuilt nested lists; mount it before refocusing and preserve the visible window.

### R1-F3 — nested long-list rows omit their position and full size

- **Severity: minor.** Contract: U-access — mounted items name `aria-posinset` + `aria-setsize`; contacts/details lists are included, not only the board.
- Anchor: `.scratch/worktrees/v1/web/lazy.js:274–278`, `const lazy = new LazyList(el, {` omits `posinset`, whose default at `:31` is false. `listOf`-rendered long contacts/details lists take this path.
- Red command: `node .scratch/reviewer-1/gui-probe.mjs nested-aria` → rc 1, real `deep 300` server.
- Failing output:
  ```text
  nested-list-aria {"position":null,"size":null}
  FAIL nested-aria: U-access: every mounted long-list item names its position
  ```
- Evidence: `.scratch/reviewer-1/nested-aria.log`.
- Fix idea: mark nested rows with positions/full counts; supply appropriate list/listitem roles for span-based reference lists too.

### R1-F4 — an old excluded-pair answer overwrites the newer view

- **Severity: major.** Contract: U-select — discard details from another view; U-coalesce — monotonic item+view requests, A→B→A must discard first A. V-details/excluded-pairs decision — each card names the engine's exclusions for the shown view.
- Anchor: `.scratch/worktrees/v1/web/app.js:543–551`, distinctive bytes `if (spec !== view.spec || decodeProblem(json)) return;`. `askPairs` keeps neither request number nor envelope generation/view; it discards the response header and accepts an old answer whenever the raw what-if string matches again.
- Red command: `node .scratch/reviewer-1/pairs-probe.mjs` → rc 1 (repeated). Holds the actual server's first recorded `claim:C` answer with `incompatible=[X1]`; edits only its scratch trace so X1 is open and X2 assumed; visits a what-if then returns to recorded. The new envelope + current pair details show X2. Releasing old A overwrites the card with X1, which is no longer asserted.
- Failing output:
  ```text
  control: first actual claim:C details captured with incompatible=[X1]
  control: newer recorded view adopted, current native details incompatible=[X2]
  after-old-pairs {"shown":["X1"],"want":["X2"],"oldView":"6741242a6a61b3af844cbd36610b0bae59774d701e86c9986faa141dfbadd7a7","title":"Replacement pair"}
  FAIL pairs-probe: U-select/U-coalesce: an older item+view answer must not overwrite current excluded pairs
  ```
- Evidence: `.scratch/reviewer-1/pairs-probe.log`, `.scratch/reviewer-1/stale-pairs.png`.
- Fix idea: share item-details request bookkeeping; capture envelope generation + view and per-item request number; accept only the still-current tuple, and route 409 through the normal view reload.

### R1-F5 — sending the full over-cap POST loses the promised 413

- **Severity: minor.** Contract: V-serve — body > 16 MiB + 1 KiB answers 413 before parsing.
- Anchor: `.scratch/worktrees/v1/Fvtrace/Server.lean:229–230`, distinctive bytes `maxBodySize := bodyCap`. This transport cap rejects the declared framing before the application `answerBody` path at `:191` can return its 413. The application test at `Tests/Server.lean:148–149` calls `answerBody … none`; it does not exercise an actual oversized POST.
- Red command: `node .scratch/reviewer-1/body-cap-probe.mjs` → rc 1 (repeated). Standard Node HTTP client, valid JSON padded with spaces, exact Content-Length, authenticated request. Controls at 13 bytes / 64 KiB / 1 MiB / cap−1 / cap return 200; a small request afterward returns 200.
- Failing output:
  ```text
  {"bytes":16778240,"status":200,...}
  {"bytes":16778241,"answer":"","error":"Error: write ECONNRESET"}
  over-cap-headers-only {"status":413,"answer":""}
  server-stderr=""
  FAIL body-cap-probe: V-serve: bodyCap+1 must answer HTTP 413
  ```
- Important limit: the headers-only oversized request does receive 413. This is a transport-delivery defect when the normal client sends its body immediately, not a missing 413 status mapping. Std.Http's early rejection/close is the inferred cause; no packet capture was performed. The fetch-based probe also sees `write ECONNRESET`.
- Evidence: `.scratch/reviewer-1/body-cap-probe.log`.
- Fix idea: test + implement the real HTTP boundary so the refusal reaches an ordinary body-sending client, preserving bounded reads and the cap. Avoid treating the pure `answerBody none` test as transport coverage.

## Register

None outside the fixed check set. No performance ruling: full-cap/idle-host timing remains unconfirmed in this review; only small correctness fixtures + the specified differential corpus ran.

reviewer-1-DONE-1

## Re-review (c930c8c)

Acceptance set = `.agent/review.md` findings rows R1-F1–R1-F5, fixed before inspecting the fixes; this round judges those acceptances alone. Target = `c930c8cca09798463db5263cf92fbdb62107df28`, same read-only checkout. Original review evidence retained.

| id | acceptance | verdict | evidence (command + output) |
|---|---|---|---|
| R1-F1 | `engine-details-failure`: recorded view + engine notice, no later call | pass | `node .scratch/reviewer-1/rereview-c930c8c/gui-probe.mjs engine-details-failure` → rc 0; `PASS engine-details-failure`; scenario = recorded, error = engine-failed notice, `errorHidden:false`; `no-later-engine-call {"callsAtFailure":2,"callsAfterClicks":2}` |
| R1-F2 | `nested-focus`: focus stays on `switch:C0:F251` after its what-if | pass | `node .scratch/reviewer-1/rereview-c930c8c/gui-probe.mjs nested-focus` → rc 0; `PASS nested-focus`; before/after `active:"switch:C0:F251"`; server stopped + port refused |
| R1-F3 | `nested-aria`: position + size on nested rows | pass | `node .scratch/reviewer-1/rereview-c930c8c/gui-probe.mjs nested-aria` → rc 0; `nested-list-aria {"position":"1","size":"301"}`; `PASS nested-aria`; server stopped + port refused |
| R1-F4 | `pairs-probe`: the card keeps the current view's pairs | pass | `node .scratch/reviewer-1/rereview-c930c8c/pairs-probe.mjs` → rc 0; `stale-pair-observer {"staleSeen":false}`; after old reply `shown:["X2"],want:["X2"]`; `PASS pairs-probe`; server stopped + port refused |
| R1-F5 | ruling or fix + test at the HTTP boundary; V-serve states the observed early-close behavior | pass | `node .scratch/reviewer-1/rereview-c930c8c/body-cap-probe.mjs` → original assertion remains rc 1: cap = 200, cap+1 full body = `write ECONNRESET`, oversized headers-only = 413. `rg -Fno 'so a client that streams a larger body may see the connection close before it reads the 413' .scratch/worktrees/v1/.agent/contracts/kernel.md` → line 126, rc 0; revised wording matches the observed behavior, not an implementation fix |

### Re-review evidence notes

- Scope = these five acceptances alone; no renewed full-diff review/gate/scale claim. All five adjudicated; R1-F1–F4 fixed under their probes; R1-F5 closed by the stated ruling, with the original stronger transport assertion explicitly still red.
- Probe copies live in `.scratch/reviewer-1/rereview-c930c8c/`, preserving the first review's scripts/logs/screenshots. GUI probe retains its original assertions and adds the F1 request counter + two post-failure clicks. Pairs probe retains its fixture + real held server answer; replaces the old wait-for-X1 with a MutationObserver, waits for the outstanding request's busy state to clear + two painted frames, then asserts X1 was never shown and current pairs remain X2. This is the corrected acceptance, not a timeout interpreted as success. Body-cap copy = original byte-for-byte (`cmp` rc 0).
- Logs: `engine-details-failure.log`, `nested-focus.log`, `nested-aria.log`, `pairs-probe.log`, `body-cap-probe.log` in that folder. Captures `engine-details-failure.png`, `nested-focus.png`, `stale-pairs.png` inspected: recorded O2 is open again, F251 retains visible focus, current exclusion X2 stays on the card.
- Target binary SHA-256: `fvtrace` = `4e756c599d874b9d8aee3e760e6fd65767e32721ae5bee9371f746bf8e583aaa`; `fvtrace-tests` = `76f9c34cf733fe32b941c3f36951eb5193f2fa8333419b74f3bc613054186173`. Target diff against c930c8c remains empty; only pre-existing untracked `node_modules`. No builds, installs, commits or target edits. All browser contexts closed; every started server stopped and its port refused.

reviewer-1-DONE-2
