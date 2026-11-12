# K-gui-a — Cleanup + Altitude

Target: `48bc51d`; frozen base `/home/eturkes/Projects/fvtrace/.scratch/review-base`.

| row | target | verdict | basis |
|---|---|---|---|
| K-gui-a | Cleanup: app.js | reviewer-31-F1, reviewer-31-F2, reviewer-31-F6 | All 1,319 lines read; duplicated selection workflow, inert `feed` class, per-find-row question scans. Intentional request/index/lazy-list structures retained. |
| K-gui-a | Cleanup: envelope.js + lookups.js + find.js + words.js + dom.js | reviewer-31-F3, reviewer-31-F6 | All five modules read; six retained decoder fields have no consumer; find misses the common index. All 31 runtime exports have web importers. |
| K-gui-a | Cleanup: e2e specs (duplicated helpers, dead fixtures) | reviewer-31-F4, reviewer-31-F5 | All 1,077 lines read; claim/verdict selectors duplicated across specs; `Box` is definition-only. Every fixture/helper other than that alias has callers. |
| K-gui-a | Altitude | reviewer-31-F7 | Independent pass over shared DOM/word/decoder/index helpers + app adapters: `load` embeds one legacy caller's hash-migration policy through a boolean flag; other deliberate structures fit their mechanism. |

## reviewer-31-F1 — duplicated selection workflow

- Severity: **minor**.
- Target: `web/app.js:688–702`, `web/app.js:743–758` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: near-duplicate blocks merged; helpers reused. `.claude/rules/web.md` keeps the find route's distinct mounting/focus behavior.
- Defect: both entry points set the selection, resolve a claim's question, push the hash, switch/repaint the question/board, draw selection, render the inspector and request details. Only mounting + focus differ. A selection-state change therefore has two independently maintained paths.
- Text proof: `rg -Fn 'view.selection = { kind, id };' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js` matches **689 + 744**; both enclosing functions contain `const q = kind === "claim" ? ix?.claims.get(id)?.question : undefined;` and the same question-switch block (690–697 / 745–751).
- Fix direction: share the selection/question/hash/render operation; keep click focus and find mounting/scroll/focus in their entry-point adapters. This finding does not re-report the known cross-question history defect.

## reviewer-31-F2 — inert class on the board feed

- Severity: **minor**.
- Target: `web/app.js:1102` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: dead code removed; K-gui-a explicitly includes classes the JS sets that no stylesheet rule reads.
- Defect: `class: "feed"` has no stylesheet rule, DOM query or class-list consumer. The independent `role: "feed"` is used for accessibility and must stay.
- Text anchor: `rg -Fn 'class: "feed"' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js` → **1102**, rc **0**, one match (positive control).
- Consumer proof: `rg -n '\.feed\b|classList\.[A-Za-z]+\("feed"'` over `/home/eturkes/Projects/fvtrace/.scratch/review-base/{web,tests,tools}` + `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Export.lean` → **0 matches, rc 1**. The wider `\bfeed\b` search finds only this setter, local variable/comment vocabulary + unrelated prose, no dynamic selector.
- Fix direction: remove the inert class attribute; keep the role + label.

## reviewer-31-F3 — retained decoder fields with no consumer

- Severity: **minor**.
- Target: `web/envelope.js:209,215,274–275,398,499` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: dead code removed; startup/hot paths lean. K-gui-a explicitly includes decoder fields no consumer reads.
- Defect: the decoder retains `Artifact.sha256`, `Evidence.statementDigest`, `Plan.premises`, `Plan.gaps`, `Subject.valid` and `Details.sentence`, but the GUI never reads them. This is surplus retained projection, not a claim that validating the input types is wrong. The plan's consumed post-plan lists are `planPremises` + `planGaps`, not the unused pair.
- Text anchors (`rg -Fn`, same target): `...(sha256 === undefined ? {} : { sha256 }),` → **209**; `...(statementDigest === undefined ? {} : { statementDigest }),` → **215**; `valid: bool(x["valid"],` → **398**; `d.sentence = str(r["sentence"], "/sentence");` → **499**.
- Proof: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-31/member-audit.mjs` → rc **0**. TypeScript resolves member declarations in `envelope.js` + scans every other `web/*.js`; positive controls `Artifact.path` = **1** read, `Fact.text` = **10** reads; all six named fields = **0** reads. Output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-31/member-audit.log`. Whole-tree token searches across `web/`, `tests/`, `tools/`, `Fvtrace/Export.lean` confirm that non-web digest occurrences are raw trace fixtures/generators, not consumers of this decoded projection. Generic serialization sites were read: only whole claims + experiments are signed; none consumes the six named fields.
- Fix direction: retain the boundary checks where required, narrow the returned GUI projection to the fields its consumers read.

## reviewer-31-F4 — duplicated e2e selectors

- Severity: **minor**.
- Target: `tests/e2e/gui.spec.js:16–23`, `tests/e2e/responsive.spec.js:17–20`; identical companion in `tests/e2e/export.spec.js:31–37` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: helpers reused; near-duplicate blocks merged.
- Defect: three specs implement the same claim-card lookup. Two also duplicate the verdict lookup byte for byte. Responsive adds `.claim-head` to the nested id selector; every rendered claim tag on an `article.circuit` is in that head, so it is the same lookup with a slightly narrower spelling. A markup change requires synchronized edits across the specs.
- Text proof: `rg -n '^(function card|const card|const verdict)' /home/eturkes/Projects/fvtrace/.scratch/review-base/tests/e2e` → `gui:16,23`, `responsive:17`, `export:31,37`. Distinctive anchors: `.filter({ has: page.locator(".tag-id").getByText(id, { exact: true }) });` → gui **19** + export **34**; `const verdict = (c) => c.locator(".tag-soft .cap-trim");` → gui **23** + export **37**. The three complete helper bodies were read; the server fixture exports no DOM-selector helper.
- Fix direction: one shared e2e selector module for claim cards + verdicts, imported by the specs; preserve each test's assertions.

## reviewer-31-F5 — unused test type alias

- Severity: **minor**.
- Target: `tests/e2e/gui.spec.js:36` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: dead definitions removed.
- Defect: `Box` is declared but never referenced, including by the adjacent tour helpers, whose bounding boxes are inferred.
- Text anchor: `rg -Fn '}} Box */' /home/eturkes/Projects/fvtrace/.scratch/review-base/tests/e2e/gui.spec.js` → **36**, rc **0**, one expected declaration (positive control).
- Consumer proof: `rg -n --hidden '\bBox\b' /home/eturkes/Projects/fvtrace/.scratch/review-base` → **one total match**, that declaration, rc **0**. This covers source, tests, tools, proofs, Lakefile + workflows; ignored generated/dependency paths are outside the source-reference domain. Output: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-31/box-refs.log`.
- Fix direction: remove the unused typedef.

## reviewer-31-F6 — find rows bypass per-envelope lookups

- Severity: **minor**.
- Target: `web/app.js:781–785`, `web/find.js:68–69`, `web/lookups.js:62–74` at `48bc51d`.
- Contract: `.claude/rules/web.md` Responsiveness / kernel.md U-lookups: one lookup index per envelope; no card, contact or row scans a whole envelope list. Cleanup → hot paths lean; existing helper reused.
- Defect: each find result for another question asks `e.questions.find(...)` for its title. `results` invokes this callback from its per-match map, so these rows rescan an envelope list instead of using the shared id index. The envelope already has a common `byId` mechanism, but questions are omitted from `Lookups`.
- Text proof: `rg -Fn 'e.questions.find((x) => x.id === q)?.title' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js` → **785**. In `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/find.js`, `found.matches.map((e) => {` → **68**, `otherQuestion(e.question)` → **69**. `lookups.js:62–74` is the complete returned index; no questions map. No response-time breach is claimed or measured.
- Fix direction: index questions by id once in `lookupsOf`, then resolve find-row titles through that map (the page-level selected-question lookup can reuse it).

## reviewer-31-F7 — legacy caller's history policy inside the shared loader

- Severity: **minor**.
- Target: `web/app.js:501–504,558–564,591–601` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Altitude; LENSES.md K: one caller's quirk / one-call-site flag in shared infrastructure ⇒ mechanism fix. The legacy-link migration itself is required by `.claude/rules/web.md` and stays.
- Defect: the shared evaluation loader accepts `link = false` solely so the legacy adapter can select a different URL-history policy. `load` then parses/removes the older `action` parameter + replaces history; normal actions push through `writeHash`. This is migration-specific behavior embedded in the common evaluation path despite an existing `legacy` adapter.
- Text proof: `rg -Fn 'async function load(action, link = false)' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/app.js` → **504**; `if (link)` → **558**. `rg -n '\bload\([^)]*,'` on that file → **only the declaration (504) + `await load(id, true);` (597)**. Every `load` call was traced.
- Fix direction: make the loader return/adopt the evaluated action result through one common path; put normal-action history writing in its adapter and the old-link replacement/preservation policy in `legacy`. Preserve the engine's normalized overrides, latest-request guards + the link's other hash parameters.

## Coverage + limits

- Cleanup pass: all six source files + all three assigned specs; references through `circuit.js`, `panels.js`, `find.js`, `lookups.js`, `Fvtrace/Export.lean`, e2e server fixture + the matching export-spec helpers. Altitude pass: shared helper boundaries + core/source/legacy/select/find adapters, separately from cleanup.
- Runtime-export inventory: **31/31** exports across `envelope/lookups/find/words/dom` have named web importers. Literal class inventory: **18** distinct per-file entries checked against the stylesheet; `feed` alone has no rule, then full consumer search above. Dynamic status classes + `.hypothetical` / `.unavailable` were traced to their stylesheet rules.
- Code intelligence: LSP `documentSymbol` works on `web/app.js`. Two JSDoc-property `findReferences` queries returned no references and one hit the wrong token; those results are not evidence. The independent TypeScript program + source searches decide F3.
- Checks run: source anchors/reference searches; TypeScript member audit (**rc 0**, controls + zeros above); seeded-table validator (**4** unresolved rows before review). Functional suites, full/fast gates, browser runs + timing measurements: **not run** (static K review; target unchanged). Servers started: **none**.
- Explicitly excluded: the request-sequencing, invalid engine-details/data and cross-question-history findings already listed in the brief. No new behavioral finding is claimed.
- Write-path correction: the first field-reference log briefly landed at `.scratch/review/reviewer-31-field-refs.tmp`; moved into the owned `.scratch/review/reviewer-31/field-refs.log`. No residual sibling artifact; target untouched.
- Register: none.

reviewer-31-DONE-1
