# reviewer-46 — F-gui @ 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| F-gui | header, top columns, How this works + key table + counts, exclusions note | pass | Live synthetic desktop 1280×900 + phone 390×844: two-column → stacked intro; one four-row key, exact lead/meanings/exclusions note, symbols + engine counts, no separate counts panel. Screenshots inspected: `screenshots/{desktop,phone}-intro.png`. Count scope = existing-subject claims (kernel.md G10), not all prospective claims. |
| F-gui | review line + evidence bar + what-if line + refusal suffix + notices lines | pass | Exact draft/reviewed/stale lines, recorded/amber what-if bar + reset, all four refusal forms + GUI suffix, multi-notice line + all four failure endings verified live. `sweep.mjs`: synthetic + custom feature fixture; `screenshots/{desktop,phone}-whatif.png` inspected. |
| F-gui | claim card: label row, chips, headline/exact statement, condition lines, plain reasons, diagram end | unknown | unknown |
| F-gui | kind + level words; no metaphor words; no "trace" | reviewer-46-F2 | All 12 fact-kind + 5 claim-level labels verified live; synthetic rendered copy contains no prohibited metaphor/trace words (authored study text excluded). Missing-check prose still exposes `estimand` + `release` rather than the approved Measurement/Publication words. |
| F-gui | Text view, details panel, experiments + work list + Lists rulings | reviewer-46-F1; known F26, F43 | Live synthetic + feature fixture: labels, condition lines, exact statements, waiver relocation, plan, experiment success/failure, nonzero-only work count + companion facts pass. Violated-fact + missing-check rows lack plain-click selection (red at both sizes); Text highlight + eager nested work list already F43/F26. |
| F-gui | guided tour (steps, keyboard, phone dock) | known F25, F27 | Custom fixture with violations + missing check: all 15 prescribed steps, real symbol target, non-modal dialog, ArrowRight/ArrowLeft/Escape, restored opener focus; phone cards all dock 12px above bottom; desktop/phone spotlight measurements + four screenshots inspected. Long-contact overlap + record-problem active tour remain existing F25/F27, not re-reported. |
| F-gui | exported page: export note, Worker, without WebAssembly sentence, envelope lists on request | unknown | unknown |

## Scope

Frozen target: `/home/eturkes/Projects/fvtrace/.scratch/review-base` (`48bc51d`). Read-only; live checks + fixtures under `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/`. Fixed check set = table above × scoped Decisions in the assignment. Known findings cited, never re-reported.

## reviewer-46-F1 — minor — plain list rows do not open details

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/panels.js:667–683` (`blockerRow` + `checkRow`).
- Contract: Decisions GUI, selectable text: `card heads, experiment cards, list rows + text-view lines open their details on a plain click, never on a drag, through their id button + a click that ignores text selections`.
- Cause: both `plain-row` constructors supply no `onclick`; their id buttons work, but clicking the adjacent readable fact/check text does nothing. Work/experiment/Text rows already use `clickToOpen`.
- Red command: `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/red-list-click.mjs` → rc 1 at `48bc51d`; log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/red-list-click.log`.
- Output (both 1280×900 + 390×844): `#blocker-list .plain-row` plain click leaves `Select a claim, a fact or an experiment`; expected `The marker rises in treated samples.`; `#check-list .plain-row` same initial panel; expected `The contrast is the treatment effect.`. Positive controls: each id-button click selects the expected item. Final assertion: `List rows must open their details on a plain click; id-button controls already work.`
- Anchors: `rg -Fn 'export function blockerRow' …/web/panels.js` → 667; `rg -Fn 'return h("li", { class: "plain-row" }, ref("claim", l.claim, on), rest);' …/web/panels.js` → 683.
- Fix direction: route both row containers through `clickToOpen` + the same item selector as their id buttons; preserve selection/drag guard.
