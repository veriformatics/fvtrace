# operator-1 · GUI visual QA (U8) · binary .scratch/operator-1/fvtrace

Verdict = 15/15 adjudicated; 11 pass, 4 findings (Q7/Q10/Q11 low; Q14 medium). No high finding.

- Target = supplied binary SHA-256 `70f9690bad7b30e5458318efb8777bfe1d165718002d0d9a129c5b28bc48bf4d`; no builds, installs, commits or tracked-file edits.
- Browser = Playwright bundled Chromium, headless, GPU disabled; 1280×720 + 390×844; reduced motion. Find alignment checked in default system font + DejaVu Sans. 81 PNG checkpoints captured + inspected under `.scratch/operator-1/shots/`.
- Completed commands (`node .scratch/operator-1/<script>.mjs`) → `basic`, `tour-fixture`, `busy-phone`, `deep`, `export`, `coalesce`: rc 0. Raw observations + cleanup = corresponding `*-evidence.json` in the deliverable directory.
- Q3/Q4: selected summaries + details render; late C2 details leave the newer C1 panel unchanged; O2 what-if preserves C1/C3 nodes and replaces C2 only. Q6: 13 tour steps × 2 viewports, zero card/spotlight overlaps; Escape restores opener focus.
- Q8: every wide card reached (300/300); sampled growth 8→14 retains the visible anchor at y=99.578125 px. Q9: exact id first, word search, absent-match Enter, Escape, unmounted C290 all exercised. Q12: immediate body busy + progress cursor; indicator visible during held request, absent after answer; pseudo animation `none`; A→B→A sends A twice, maximum one evaluation in flight, first A does not paint. Q13: synthetic + wide exports open locally; what-if, find, details + retained keyboard focus work; engine-failure notice absent.
- Attempts retained honestly: first basic run used an exact heading selector that omitted the count → corrected selector, rerun rc 0. First wide polling run reached 221/300 before the harness's 60 s bound → frame-driven scroll-growth rerun reaches 300/300. That rerun later hit the 5 s busy-settle assertion with several pages open (`wide-evidence.json`, rc 1); isolated desktop + phone busy rerun completed after release (~0.8 s / ~1.6 s), rc 0. Cause of the multi-page timeout remains unconfirmed; no timing-bound verdict is claimed.
- Coverage limits: no full gate, cap-size/idle-host U-time benchmark, native screen-reader speech, browser-engine matrix, or pre-U8 rendered comparison. Keyboard = sampled control types + lazy boundaries, not 5,001 Tab presses. Tour = synthetic's 13 shown steps; fixture-only tour steps not walked. Selected pass rows mean the named visual/functional checkpoint passed, not all-input assurance.
- Cleanup = every started server terminated and its loopback port refused; browser instances closed; temporary projects/data/export files removed. Scripts, binary snapshot, raw evidence + proof PNGs retained only inside the allowed directory.


| id | trace · mode · size | state | check | result | severity | shot |
|---|---|---|---|---|---|---|
| Q1 | synthetic · served · 1280×720 | first view | layout, key table, question bar, board, inspector as before U8 (no regressions) | pass | none | .scratch/operator-1/shots/q01-desktop-board.png |
| Q2 | synthetic · served · 390×844 | first view | phone layout; find field + board readable | pass | none | .scratch/operator-1/shots/q02-phone-board.png |
| Q3 | synthetic · served | select a claim, then a fact, then an experiment | highlight moves; inspector fills; details arrive; focus visible | pass | none | .scratch/operator-1/shots/q03-fact-selected.png |
| Q4 | synthetic · served | press a fact's symbol (what-if) | evidence bar + changed cards; busy cursor; no flash of other cards | pass | none | .scratch/operator-1/shots/q04-whatif-card.png |
| Q5 | synthetic · served | Text layout | rows, conditions, Facts to verify | pass | none | .scratch/operator-1/shots/q05-text-facts.png |
| Q6 | synthetic · served · 1280×720 + 390×844 | guided tour | every step's card clear of its spotlight | pass | none | .scratch/operator-1/shots/q06-phone-06.png |
| Q7 | fixture (tests/fixtures/synthetic.trace.json) · served | violated facts, exclusions, waivers, What may be missing | blocker + check lists, exclusion lines on cards | finding: What may be missing repeats each claim id (C1 C1; C9 C9) | low | .scratch/operator-1/shots/q07-blockers-checks.png |
| Q8 | wide 300 · served | scroll down the board | cards keep appearing; no jump; end marker text when outrun | pass | none | .scratch/operator-1/shots/q08-wide-last.png |
| Q9 | wide 300 · served | find: id `C29`, words `fact f12`, no match, Enter, Escape | count line, rows aligned, chosen card scrolled into view + focused + selected | pass | none | .scratch/operator-1/shots/q09-unmounted-chosen.png |
| Q10 | a trace with 2+ questions · served | find a claim of the other question | row says "In another question: …"; choosing switches the board | finding: cross-question result keeps its old context label after switching | low | .scratch/operator-1/shots/q10-other-question-chosen.png |
| Q11 | deep 5000 · served | the one tall card | contacts mount as you scroll; end marker then the lamp; wire unbroken | finding: pending-end marker interrupts the vertical connector | low | .scratch/operator-1/shots/q11-deep-boundary.png |
| Q12 | wide 300 · served | a what-if whose answer takes > 1 s (route-delay /api/answer) | "Working…" pill shows past 1 s, hides at the answer; reduced motion = no spin | pass | none | .scratch/operator-1/shots/q12-desktop-working-confirmed.png |
| Q13 | synthetic + wide 300 · exported (`fvtrace export --html`) | first view, a what-if, find | same as served; engine notice absent | pass | none | .scratch/operator-1/shots/q13-wide-chosen.png |
| Q14 | all · keyboard | Tab through find results, cards, lists | focus ring visible everywhere; moving past mounted cards mounts more | finding: nested lazy rows omit position and total ARIA attributes | medium | .scratch/operator-1/shots/q14-deep-contact-focus.png |
| Q15 | all · 390×844 | find results, end markers, working pill | nothing overflows or overlaps | pass | none | .scratch/operator-1/shots/q15-phone-find.png |

## Q7

- What may be missing → id link + engine message repeat the id: `C1 C1 concerns publication…`, `C9 C9 asserts…`. Source anchor: `web/panels.js:650`. Layout stays readable; low-priority copy defect, pre-U8 behavior confirmed at `7c536ee:web/panels.js:627` (`ref("claim", l.claim, on), ` + engine message). Fix idea → make the existing leading id the link, with the rest of the engine message once.
- Fixture variant = C1 publication level + C9 requiring O4/O5, O2 violated what-if; exclusions + blocker lists render correctly. The stock fixture's C3 L-result waiver is inactive because M1 already has kind result; active waiver presentation verified on synthetic C2 in `.scratch/operator-1/shots/q03-claim-selected.png`.

## Q10

- Search C3 while Effect is active → result says `In another question: New cohort`; Enter → the question bar + board switch correctly, C3 receives focus/selection, but the result still says `In another question: New cohort`. Source anchor: `web/app.js:667–688` (`reveal` changes question without refreshing find results). Fix idea → refresh the result context after switching the question.

## Q11

- Deep5000 pending-end marker sits across the vertical diagram connector, leaving a gap between F122 and C0. Full-load terminal connects correctly. Fix idea → continue the connector through the marker and offset its text beside it. Desktop proof = table shot; phone = `.scratch/operator-1/shots/q15-phone-deep-boundary.png`.
- Boundary shots = CDP captures of the real rendered offscreen boundary, viewport unchanged; ordinary near-viewport scrolling proactively mounts more rows and moves the marker away. All 5,001 contacts reached in 50 scroll-growth steps.

## Q14

- Deep5000 first contact + first condition row both return null for `aria-posinset` and `aria-setsize`; `listOf` uses LazyList without `posinset: true` (`web/lazy.js:274`). U-access requires each mounted item to name its position + complete list size. A screen reader cannot obtain the logical list extent from these rows. Fix idea → enable the position metadata for nested lazy lists; preserve valid list semantics for inline detail lists.
- Keyboard growth + visible focus pass: wide boundary 11→31 cards; Tab proceeds C10→C11. Deep contact boundary 123→253; Tab reaches F123 with a 3px focus-visible outline. Evidence = `.scratch/operator-1/deep-evidence.json`. Native screen-reader speech was not run.

operator-1-DONE-1

## Re-check (c930c8c)

| id | check | result | shot |
|---|---|---|---|
| Q7 | Missing-check rows show each claim id once | pass; C1 + C9 appear once at both widths | .scratch/operator-1/shots/r2-q07-desktop.png |
| Q10 | Cross-question find label refreshes after selection | pass; selected question removes the old context label; C3 keeps focus | .scratch/operator-1/shots/r2-q10-refreshed-question.png |
| Q11-D | Deep5000 dashed connector through pending-end line; 1280×720 | pass; dashed connector joins both ends; text sits beside it | .scratch/operator-1/shots/r2-q11-desktop-wire.png |
| Q11-M | Deep5000 dashed connector through pending-end line; 390×844 | pass; wrapped end text stays beside the uninterrupted dashed connector | .scratch/operator-1/shots/r2-q11-phone-wire.png |
| Q14 | Nested lazy rows expose logical position + total; keyboard focus survives | pass; contact 1/5001, condition 1/2501, inline roles + positions; F401 focus survives rebuild | .scratch/operator-1/shots/r2-q14-focused-row-kept.png |
| COUNT-D | Page-level count lines; board, work, experiments, blockers, checks at 1280×720 | pass; quiet count lines above their lists, no overlap or overflow | .scratch/operator-1/shots/r2-counts-desktop-work.png |
| COUNT-M | Page-level count lines at 390×844; default + DejaVu Sans | pass; counts readable at 390px in both fonts, no horizontal overflow | .scratch/operator-1/shots/r2-counts-phone-work-dejavu.png |


Re-check verdict = 7/7 pass; Q7/Q10/Q11/Q14 resolved on this binary. No remaining finding in the fixed check set.

- Binary = `.scratch/worktrees/v1/.lake/build/bin/fvtrace`, HEAD `c930c8c`, SHA-256 `4e756c599d874b9d8aee3e760e6fd65767e32721ae5bee9371f746bf8e583aaa`.
- Run = `FVTRACE_QA_ROOT=.scratch/worktrees/v1 FVTRACE_QA_BIN=.scratch/worktrees/v1/.lake/build/bin/fvtrace node .scratch/operator-1/recheck.mjs`; rc 0; page errors = 0. Evidence = `.scratch/operator-1/recheck-evidence.json`.
- 14 new PNGs inspected. Page-level counts checked on the experiments300 shape: `300 claims`, `300 experiments`, `300 facts`; fixture: `1 fact`, `2 checks`. Desktop count lines align with their list column; phone count lines sit between explanatory text/filters and list. Default font + DejaVu Sans work-list check: document width = viewport width, 390px.
- Deep5000 boundary captures keep the viewport still, as in the initial check. Both widths show a 2px dashed connector through the end row, with its text offset 52px; the phone's two-line message stays clear of the connector. Contacts + conditions now carry position/size attributes; inline inspector rows have list/listitem roles + positions. Keyboard action on F401 returns focus to the same control after rebuilding the card, with a visible 3px ring.
- Scope = the four fixes + new count lines; other original rows, full gate, timing bounds + native screen-reader speech not rerun. All four servers stopped; each port refused; browser closed; temp projects/data removed. Worktree remained read-only.

operator-1-DONE-2
