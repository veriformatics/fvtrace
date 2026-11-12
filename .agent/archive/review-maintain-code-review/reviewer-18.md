| row | target | verdict | basis |
|---|---|---|---|
| C-gui-b | lazy.js | pass | Full module + callers read; wide-300 positions/find/keyboard growth + deep-300 late-contact focus across rebuild pass; GC probe retains no detached observed targets. |
| C-gui-b | circuit.js (diagrams, symbols, contacts) | pass | Full module + helpers/callers read; real served/exported engine verdicts, headlines, conditions, restating claim, selection identity, what-if controls + two-font capital alignment pass. |
| C-gui-b | panels.js (key, lists, inspector, experiments, work rows) | finding reviewer-18-F2 | Full module + callers/types read; hub-300 mounts every gated-claim reference offscreen without a lazy end. |
| C-gui-b | tour.js (steps, placement, keyboard, focus) | finding reviewer-18-F1 | Full module + callers/CSS read; 390×844 deep-12 settled placement fails the no-overlap contract. |
| C-gui-b | index.html + style.css (ids, hidden rules, layout the JS relies on) | finding reviewer-18-F3 | Full files + JS selectors read; an active tour survives the `.unavailable` record-problem view. |
| C-gui-b | tests (palette + driving e2e specs) | pass | Palette 3/3 pass; gui/responsive/smoke/export specs + harness read: assertions + setup/teardown consistent. Full e2e suite not run by this reviewer. |

## reviewer-18-F1 — minor — tall diagram spotlight overlaps its tour card

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/tour.js:86` (+ `:289`, `:342`), revision `48bc51d`.
- Contract: `.claude/rules/web.md` Tour — card never covers its spotlight; a target too tall to share the screen uses its compact part. Decisions Guided tour — phone cards dock at the bottom.
- Defect: “The facts it needs” targets the entire `.contacts` without `compact`. `target` returns it unchanged; phone placement floors the remaining card space at 200 px even when the target already occupies the viewport. A valid 12-fact deep trace therefore has a spotlight extending below the viewport, with the docked card covering its bottom contacts.
- Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/tour-deep.mjs` (`rc=1`, reduced motion, placement sampled after 2.1 s).
- Output: `{"title":"The facts it needs","count":"6 of 14","spot":{"top":15.578125,"left":13,"bottom":872.765625,"right":377,"height":857.1875,"width":364},"card":{"top":632,"left":12,"bottom":832,"right":378,"height":200,"width":366},"overlap":true}`; `AssertionError [ERR_ASSERTION]: tour card must not cover its spotlight (web.md Tour)` / `true !== false`.
- Screenshot inspected: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/tour-deep-overlap.png`; log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/tour-deep.log`. Server killed by PID; port refused afterward.
- Fix direction: give the diagram step a representative compact contact target (and apply the same tall-target fallback to every step).

## reviewer-18-F2 — minor — the gated-claim list in a work row bypasses lazy mounting

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/panels.js:639-665`, revision `48bc51d`.
- Contract: kernel.md U-long; `.claude/rules/web.md` Responsiveness — every long list uses `LazyList`; nested lists start with 40 rows, mount later rows near the viewport, and say what remains.
- Defect: `togetherWith` eagerly maps all `w.gates` into one work-row paragraph. Its per-claim “Needed by …” list has no `listOf` boundary; only each claim's *other facts* gets one. A shared fact needed by many claims therefore builds every claim reference even while its row is offscreen. The outer work list does not bound a single row's work.
- Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/work-long.mjs` (`rc=1`). Positive control: the native engine reports 300 gated claims for H in a valid generated hub trace.
- Output: `{"engineGates":300,"neededBy":300,"endLines":0,"parentOffscreen":true,"textLength":13184}`; `AssertionError [ERR_ASSERTION]: a long per-claim Needed by list must mount on demand, not every entry offscreen (U-long; web.md nested first 40)`.
- Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/work-long.log`. Server killed by PID; port refused afterward. No response-time or cap-scale claim: this witness grades mounting behavior alone.
- Fix direction: make each gated-claim explanation a keyed lazy row, retaining the existing engine-derived wording and laziness of its fact references.

## reviewer-18-F3 — minor — a record-problem view leaves an active tour visible

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/style.css:1629` (caller `web/app.js:490`; lifecycle `web/tour.js:220-238`), revision `48bc51d`.
- Contract: `.claude/rules/web.md` record problem — invalid/unreadable/missing record replaces the view; loading lines, board, lists **and tour** leave.
- Defect: `.unavailable` hides tour-start controls but does not hide/end the already-appended `.tour-card` / `.tour-room`. Start the tour, invalidate a must-verify fact in the served record, then press its spotlighted what-if symbol: the analysis changes to the record-problem view while the now-inapplicable tour dialog remains visible.
- Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/tour-invalid.mjs` (`rc=1`).
- Output: `{"unavailable":true,"error":"The claims and facts on record have errors. To see them, run fvtrace check in the project folder.","visibleTourCards":1,"visibleSpotlights":0}`; `AssertionError [ERR_ASSERTION]: a record problem must remove the active tour along with the board (web.md record problem)` / `1 !== 0`.
- Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/tour-invalid.log`. Server killed by PID; port refused afterward.
- Fix direction: end the active tour when adopting a record problem (remove its card, room and handlers), rather than hiding only its launch controls.

## Checks + limits

- `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/functional.mjs` → `rc=0`, `PASS 186 functional assertions`; real binary `serve --port 0 --no-browser`, private scratch `FVTRACE_HOME`; Playwright bundled Chromium. Covers native-envelope counts/verdicts/headlines, claim details + waived check + plan, selectable headline + plain click, unchanged-card identity, Diagrams/Text, exported engine what-if + details, key-symbol alignment under default + DejaVu Sans, every settled tour step on synthetic (13 steps) + fixture with blocker/missing check (15 steps) at 1280×720 + 390×844, arrows/Escape/focus return/phone docking, wide-300 positions + keyboard growth + find, deep-300 late contact + preserved focus after what-if.
- Screenshots inspected: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/synthetic-desktop.png`, `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/synthetic-export-phone.png`, F1 screenshot above. Functional log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/functional.log`.
- `node --test /home/eturkes/Projects/fvtrace/.scratch/review-base/tests/palette/palette.test.mjs` → `rc=0`, 3 passed / 0 failed / 0 skipped (contrast, state marks, unsimulated/protan/deutan separation); log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/palette.log`.
- `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/lazy-leak.mjs` → `rc=0`: after 12 layout changes, 124 observers created / 28 live / 0 observing detached targets after Chromium GC. Observer-leak doubt set aside on this witness, not reported as a defect. Log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/lazy-leak.log`.
- First functional attempt failed only at a full-page screenshot (`Timeout 30000ms exceeded`), under host load ~38 on 8 CPUs. Re-run uses viewport screenshots, passes every assertion, and produces the inspected captures. This is not evidence of a product timeout.
- Not run here: original full e2e specs, full gate, cap-scale/U-time/reference-host timings, browser engines other than bundled Chromium. Source review covers every assigned file + the named helper/caller modules; runtime sampling covers the fixtures/shapes named above, not every legal trace.
- Read-only target; writes = this validator-input deliverable + reviewer scratch. Every owned server stopped by PID; each closed port refused afterward.

## Register

- C-gui-a caller leads owned by reviewer-17: `web/app.js:1095` group-title key collisions → reviewer-17-F9; `web/app.js:1122` selected/focused card leaves a preserved lazy window after verdict reordering → reviewer-17-F10. Peer reports both red; proof + ruling in `/home/eturkes/Projects/fvtrace/.agent/review/reviewer-17.md`, log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-17/caller-leads.log`. Not rerun in this slice; MAIN adjudicates that report.

reviewer-18-DONE-1
