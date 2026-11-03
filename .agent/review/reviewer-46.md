# reviewer-46 — F-gui @ 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| F-gui | header, top columns, How this works + key table + counts, exclusions note | pass | Live synthetic desktop 1280×900 + phone 390×844: two-column → stacked intro; one four-row key, exact lead/meanings/exclusions note, symbols + engine counts, no separate counts panel. Screenshots inspected: `screenshots/{desktop,phone}-intro.png`. Count scope = existing-subject claims (kernel.md G10), not all prospective claims. |
| F-gui | review line + evidence bar + what-if line + refusal suffix + notices lines | pass | Exact draft/reviewed/stale lines, recorded/amber what-if bar + reset, all four refusal forms + GUI suffix, multi-notice line + all four failure endings verified live. `sweep.mjs`: synthetic + custom feature fixture; `screenshots/{desktop,phone}-whatif.png` inspected. |
| F-gui | claim card: label row, chips, headline/exact statement, condition lines, plain reasons, diagram end | pass | Synthetic desktop/phone: 15px/700 id badge, regular-weight ink kind, verdict symbol + outlined state wash, both gaps 8px, no separate head symbol; headline/exact statement + each reason verbatim; Holds only if/Also assumes/Still open/Cannot stand because + diagram end verified. Default + DejaVu Sans tag crops inspected. |
| F-gui | kind + level words; no metaphor words; no "trace" | reviewer-46-F2 | All 12 fact-kind + 5 claim-level labels verified live; synthetic rendered copy contains no prohibited metaphor/trace words (authored study text excluded). Missing-check prose still exposes `estimand` + `release` rather than the approved Measurement/Publication words. |
| F-gui | Text view, details panel, experiments + work list + Lists rulings | reviewer-46-F1; known F26, F43 | Live synthetic + feature fixture: labels, condition lines, exact statements, waiver relocation, plan, experiment success/failure, nonzero-only work count + companion facts pass. Violated-fact + missing-check rows lack plain-click selection (red at both sizes); Text highlight + eager nested work list already F43/F26. |
| F-gui | guided tour (steps, keyboard, phone dock) | known F25, F27 | Custom fixture with violations + missing check: all 15 prescribed steps, real symbol target, non-modal dialog, ArrowRight/ArrowLeft/Escape, restored opener focus; phone cards all dock 12px above bottom; desktop/phone spotlight measurements + four screenshots inspected. Long-contact overlap + record-problem active tour remain existing F25/F27, not re-reported. |
| F-gui | exported page: export note, Worker, without WebAssembly sentence, envelope lists on request | known F24, F37, F38 | `file://`, offline: export note exact; one real Worker, stacked what-ifs, creator title + excluded pairs after details; held startup/evaluation still permits selection at both sizes; WebAssembly removed → zero Workers, recorded lists, exact overall + fact/claim/experiment detail notices at both sizes. Existing failure-handling findings retained. Numerical 0.1s bound not remeasured here (reference-host timing = F-serve). |
| F-gui | board grouping + verdict order | reviewer-46-F3; known F44 | Existing claims sort by verdict; Overlooked directions + On new data groups retain input order. A live fixture puts Pending verification before Fully supported in both titled groups. Duplicate subject-title collapse remains existing F44. |

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

## reviewer-46-F2 — minor — missing-check prose keeps superseded kind words

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Lint.lean:34–35`, displayed unchanged by `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/panels.js:678–683`.
- Contract: Decisions GUI: `kind + level words plain` + fact-kind labels `Measurement (estimand)` / `Publication (release)`; reason stated in that ruling: `"Estimand", "Entailment" unreadable`.
- Live output: `{"badges":["Publication","Measurement"],"checks":"C1 concerns publication but needs no release fact C2 defines an estimand but needs no estimand fact"}`. Badge positive control uses approved words; What may be missing reintroduces the discarded terms for those same kinds.
- Red command: `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/red-lint-words.mjs` → rc 1 at `48bc51d`: `The GUI must name estimand/release kinds Measurement/Publication in its missing-check copy too.`; offending tokens = `release`, `estimand`, `estimand`.
- Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/red-lint-words.log`; inspected screenshot `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/screenshots/lint-words.png`.
- Anchors: `rg -Fn 'defines an estimand but needs no estimand fact' …/Fvtrace/Lint.lean` → 35; `rg -Fn 'concerns publication but needs no release fact' …/Fvtrace/Lint.lean` → 34.
- Fix direction: give lint prose the same approved names as its GUI kind labels; keep rule ids + engine meaning unchanged.

## reviewer-46-F3 — minor — titled claim groups bypass verdict ordering

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js:823–849` (`groups`).
- Contract: Decisions GUI: `claims per question in verdict order, no verdict headings` + `new-data + overlooked groups keep theirs`. The latter keeps group headings; it supplies no order exception.
- Cause: only the untitled existing/non-latent group passes through `["can", "conditional", "open", "cannot"]`; overlooked and prospective groups use raw filtered input order.
- Red command: `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/home node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/red-group-order.mjs` → rc 1 at `48bc51d`.
- Output: `Overlooked directions`: ids `[C5,C6]`, states `[Pending verification,Fully supported]`; `On new data: New cohort`: ids `[C3,C4]`, same states. Native `eval --whatif MR=checked` independently prints C5/open, C6/can, C3/open, C4/can; the renderer is not waiting for a verdict. Assertion: `Every claim group must follow verdict order, including new-data and overlooked groups.`
- Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/red-group-order.log`; inspected screenshot `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/screenshots/group-order.png` (1280×900).
- Anchors: `rg -Fn 'out.push(["Overlooked directions"' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js` → 835; `rg -Fn 'bySubject.get(s.id) ?? []' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js` → 846.
- Fix direction: use the same verdict-order projection inside every claim group, preserving distinct subject ids/headings.

## Verification + limits

Scratch prefix for every script/log/result below = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/`; each binary invocation sets its `home/` as `FVTRACE_HOME`.

| command (absolute scratch script) | result |
|---|---|
| `FVTRACE_HOME=…/home REVIEW_SKIP_SHOTS=1 node …/sweep.mjs` | rc 0; 171 checks pass; `sweep-results.json` failures `[]`. Real base `serve --port 0 --no-browser`; synthetic + feature trace (violations, exclusions, prospective subject, latent claim, notices, waivers), desktop + phone; reviewed/stale; offline exports + WebAssembly removed. |
| `FVTRACE_HOME=…/home node …/extra.mjs` | rc 0; 32 checks pass; `extra-results.json` errors `[]`. All 12 fact kinds + 5 claim levels; single replay notice; real Worker held at startup/evaluation still permits a selected summary at both sizes; exact no-engine lines on phone. |
| `FVTRACE_HOME=…/home node …/gestures.mjs` | rc 0; 8 gesture cases × 3 assertions. Card headline, experiment title, work text, Text row at both sizes: real drag selects ≥15 characters without opening details; subsequent plain click opens the correct details. `gesture-results.json`. |
| `FVTRACE_HOME=…/home node …/red-list-click.mjs` | rc 1; F1 red at both sizes; id-button controls pass. |
| `FVTRACE_HOME=…/home node …/red-lint-words.mjs` | rc 1; F2 red; kind-badge controls pass. |
| `FVTRACE_HOME=…/home node …/red-group-order.mjs` | rc 1; F3 red; native verdicts match the displayed states. |

- Screenshots: all 24 PNGs under `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-46/screenshots/` opened + inspected. Includes desktop/phone intro, claim, details, what-if, Text, tour key + contacts, exclusion conflict, exported pairs, no-engine view/detail, list rows, terminology, group order; font crops = default + DejaVu Sans.
- Known findings: cited table rows retain F24–27/F37–38/F43–44; existing interaction findings F39–42/F45 not re-reported. No claim that their failure paths pass.
- Unconfirmed: numerical 0.1s/1s/10s bounds, reference-host scale envelope, non-Chromium browsers + fonts beyond the two above. This slice exercised behavior in bundled Chromium, not a new U-time measurement. Full gate + existing e2e suite not run (brief forbids full gate; review uses direct real-program witnesses).
- Harness corrections, not product findings: initial key-count expectation incorrectly included prospective claims → kernel.md G10 scopes counts to existing subjects; corrected scratch expectation → 171 pass. Initial extra fixture omitted cross-subject `instantiates`; initial group-order fixture recorded a prospective verified fact → corrected to a valid open fact + what-if. Lazy claim selection uses the find route. Initial work drag began on its id button → corrected to the readable text node; final gesture cases pass.
- Cleanup: every started server killed by its owned PID; `server-stopped.json` records refused ports; final `pgrep -af '[r]eviewer-46'` rc 1 (no remaining driver/server). Base/primary product files untouched; only allowed report + scratch written; no Git operations.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/tour.js:36`: `counts the claims in the whole analysis.` overstates key scope (kernel.md G10 = existing-subject claims). Synthetic has three cards but key sums to two. S-comments-other lead sent to reviewer-39 + MAIN; outside F's prescribed count semantics, no duplicate F-gui finding.

reviewer-46-DONE-1
