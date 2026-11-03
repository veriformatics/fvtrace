| row | target | verdict | basis |
|---|---|---|---|
| C-gui-b | lazy.js | unknown | unknown |
| C-gui-b | circuit.js (diagrams, symbols, contacts) | unknown | unknown |
| C-gui-b | panels.js (key, lists, inspector, experiments, work rows) | unknown | unknown |
| C-gui-b | tour.js (steps, placement, keyboard, focus) | finding reviewer-18-F1 | Full module + callers/CSS read; 390×844 deep-12 settled placement fails the no-overlap contract. |
| C-gui-b | index.html + style.css (ids, hidden rules, layout the JS relies on) | unknown | unknown |
| C-gui-b | tests (palette + driving e2e specs) | unknown | unknown |

## reviewer-18-F1 — minor — tall diagram spotlight overlaps its tour card

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/tour.js:86` (+ `:289`, `:342`), revision `48bc51d`.
- Contract: `.claude/rules/web.md` Tour — card never covers its spotlight; a target too tall to share the screen uses its compact part. Decisions Guided tour — phone cards dock at the bottom.
- Defect: “The facts it needs” targets the entire `.contacts` without `compact`. `target` returns it unchanged; phone placement floors the remaining card space at 200 px even when the target already occupies the viewport. A valid 12-fact deep trace therefore has a spotlight extending below the viewport, with the docked card covering its bottom contacts.
- Red command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/tour-deep.mjs` (`rc=1`, reduced motion, placement sampled after 2.1 s).
- Output: `{"title":"The facts it needs","count":"6 of 14","spot":{"top":15.578125,"left":13,"bottom":872.765625,"right":377,"height":857.1875,"width":364},"card":{"top":632,"left":12,"bottom":832,"right":378,"height":200,"width":366},"overlap":true}`; `AssertionError [ERR_ASSERTION]: tour card must not cover its spotlight (web.md Tour)` / `true !== false`.
- Screenshot inspected: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/tour-deep-overlap.png`; log `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-18/tour-deep.log`. Server killed by PID; port refused afterward.
- Fix direction: give the diagram step a representative compact contact target (and apply the same tall-target fallback to every step).
