# S-comments-other — `48bc51d`

Check set fixed before target reads: scoped comments/JSDoc vs their code (behavior, bounds, order, measurements, reasons, usage, removed-code descriptions, test-coverage claims); `CLAUDE.md` Engineering comment economy. Base = `/home/eturkes/Projects/fvtrace/.scratch/review-base`, read-only. Six rows adjudicated; five new minor findings. Known findings cited, never duplicated.

| row | target | verdict | basis |
|---|---|---|---|
| S-comments-other | web/ | finding reviewer-39-F2; known F24, F25, F27, F37, F39, F40, F43, F44, F45, F50 | Every JS comment/JSDoc read with source; all 27 CSS comment blocks + their styles checked; HTML has no comments. Two stale label descriptions + one displaced label comment; existing engine/lifecycle/selection promises meet the cited findings. |
| S-comments-other | tools/ | finding reviewer-39-F1, reviewer-39-F5; known F21, F22, F29, F30, F31, F32, F34, F35 | All 22 scoped files checked (20 scripts + two lock headers). What-if helper describes the wrong status; accepted small shapes emit nonexistent actions/items (red). Existing comparison/bounds/cleanup/audit promises meet known findings. |
| S-comments-other | c/ shims | pass | Both shims read in full; FFI signatures, SHA-256 chunk bound + page ABI/ownership descriptions match implementations. External/upstream facts limited as below. |
| S-comments-other | .github/workflows/ | finding F23 (known) | Four workflows read in full; release's “archives built from another version publish … nothing” meets F23. Other in-repo ordering/cache/floor/tooling claims match the named steps; no new finding. |
| S-comments-other | tests/ + configs | finding reviewer-39-F3; known F7 | All 15 JS/shell test files + three configs checked; test-coverage prose exceeds actual case construction/assertions; one fixture comment displaced. Schema/decoder promise meets known F7. |
| S-comments-other | what-only comments (CLAUDE.md Engineering) | finding reviewer-39-F4; known F55 intersects the unused lazy accessor | Conservative census: 56 clear operation-paraphrase blocks across 21 files; per-file counts + up to three worst anchors below. Machine-consumed JSDoc types retained. |

## reviewer-39-F1 — minor — helper describes a stronger what-if than it generates

- Location: `tools/scale.mjs:350`.
- Contract: S-comments-other; a status/bound description must match the code; `CLAUDE.md` Engineering claim soundness.
- Anchor: `every fact at its route's ceiling`.
- Contradiction: `tools/scale.mjs:358` emits `F${i}=assumed,E${i}=tested`; `wide` assigns E* route `lean` (`:91`), whose ceiling is `proved` (`Fvtrace/Model.lean:280–283`, `:305–306`). The top-level shape description at `tools/scale.mjs:22–23` correctly says E* stays `tested` so it remains closable; the helper's JSDoc is stale.
- Live cross-check: generator `whatif 3`, then built `fvtrace eval --whatif <whatif.txt>` under this review's `FVTRACE_HOME` → rc 0; E0 `{route: lean, effective: tested, ceiling: proved}`.
- Fix direction: name the actual statuses + retain the below-ceiling rationale; keep the intended grading input unchanged.

## reviewer-39-F2 — minor — claim-label comments retain an earlier layout

- Locations: `web/circuit.js:96`, `web/style.css:503`, `web/style.css:829`.
- Contract: S-comments-other (layout/order/color claims + removed-code descriptions); Decisions GUI label = id first, kind on ink, verdict in its own color.
- Anchors + contradiction:
  - `its kind joined to its verdict in the verdict's color` (`web/circuit.js:96`): `claimTag` makes distinct kind + verdict chips (`:106–115`); `.tag-kind` is white on ink (`web/style.css:552–555`), not verdict-colored.
  - `the claim id at its end` (`web/style.css:503`): `claimTag` appends `.tag-id` first (`web/circuit.js:104`); the newer stylesheet comment at `web/style.css:509` also says id first.
  - `The claim id leads its label row, larger than the tag beside it.` (`web/style.css:829`): detached from the label rules (`:522–535`), now heads `.moves, .changes` (`:830–835`), neither of which styles that label. A residual comment describes code no longer at its anchor.
- Fix direction: prune the stale descriptions/displaced comment; retain only the non-obvious label-alignment rationale.

## reviewer-39-F3 — minor — test comments overstate checks + one describes the wrong helper

Contract: S-comments-other explicitly includes a test comment claiming a check its test does not make.

| `file:line` | exact anchor | contradicting source |
|---|---|---|
| `tests/engine/cases.mjs:143` | `details of every item (a few on the large cases) at the recorded view + at a what-if` | `requestsFor` (`:163–167`) asks experiment/claim details at recorded alone, fact details at a what-if alone. On synthetic: 3 recorded experiments, 3 recorded claims, 8 what-if facts; none of the reverse kind/view combinations. |
| `tests/engine/engine.test.mjs:131` | `V-action: each one-click action's envelope` | Its explicit action-envelope/expanded-spec equality loop takes `.slice(0, 4)` (`:136`); synthetic has 12 recorded actions. Other differential comparisons do not turn this particular four-action assertion into an all-action assertion. |
| `tests/e2e/responsive.spec.js:226` | `Words find too; Escape clears the field and its matches.` | The following assertions (`:227–233`) search `no such words anywhere` and require zero matches, then check Escape. No successful word search occurs there; a search implementation matching ids alone could pass this test. |
| `tests/e2e/smoke.spec.js:14` | `Six axe passes over the full page` | Exactly five `expect(await axeIds(page))` calls (`:43`, `:46`, `:48`, `:51`, `:54`). The historical six-pass runtime is not a measurement of the current five calls. |
| `tests/engine/cases.mjs:243` | `The fixture with its exclusion verified (a receipt)` | Comment immediately precedes `withNotices` (`:249–259`), which adds replay failures and never verifies an exclusion. `verifiedExclusion` begins at `:261`; this is its displaced description. |

- Proof: all anchors rematched by `check-comments.py` (below), rc 0; source inspection + a live `requestsFor`/native-envelope inspection produce the kind/view counts + 12 actions above.
- Fix direction: state actual scope (including sampling), move/prune the fixture description; where the kernel contract requires exhaustive coverage, extend the test instead of weakening that contract. Keep existing grading checks intact unless MAIN obtains the required ruling.

## reviewer-39-F4 — minor — 56 comments restate the code's what

- Contract: `CLAUDE.md` Engineering: “Comments cost tokens → spend them on the why … Code states the what on its own.”
- Census = clear paraphrases only, not every prose block. JSDoc type/parameter metadata, ABI/API constraints, units, architectural invariants + reasons stay. Count = comment blocks; mixed JSDoc blocks count their redundant prose, not their required type tags. Files outside this table: zero clear instances under that conservative definition.
- Fix direction: remove the paraphrase prose; preserve functional JSDoc + comments carrying an actual constraint/measurement/upstream reason. F55 already owns removal of the unused `LazyList.size` accessor and its comment.
- Proof: each classified block's start line + each displayed anchor checked against the base by `check-comments.py`, rc 0. The script holds the complete line inventory; this table gives the requested counts + up to three worst anchors per file.

| file | blocks | worst anchors (`rg -Fn`; prefix = line) |
|---|---:|---|
| `web/app.js` | 9 | 51: ``The view: what-if (the spec sent to the engine + the overrides it accepted), question,``<br>806: ``Draws `sel` on its card or experiment row, where one is mounted.``<br>950: `Every part of the page from the shown envelope.` |
| `web/circuit.js` | 4 | 121: `A claim's plain headline, or its exact statement when it has none.`<br>138: `The facts a claim's diagram draws: its needs, then its entailment.`<br>197: `Draws a card selected or not: its border + its id button's pressed state.` |
| `web/dom.js` | 3 | 44: `An SVG element with attributes + children.`<br>63: ``The element `#id`, checked to be a `cls`.``<br>73: ``Replaces the children of `el`.`` |
| `web/envelope.js` | 3 | 153: ``An outcome object `{fact: status}` as overrides.``<br>173: ``The optional string `key` of `r`.``<br>485: `A details answer (kernel.md V-details).` |
| `web/find.js` | 1 | 15: `Every claim, fact + experiment, with the words a search reads.` |
| `web/lazy.js` | 6 | 84: `The rows' count.`<br>138: ``The position of the row `key`.``<br>150: `The mounted node of a row, when it is mounted.` |
| `web/lookups.js` | 1 | 33: ``Appends `v` to the list at `k`.`` |
| `web/panels.js` | 9 | 565: `Draws an experiment card selected or not.`<br>571: `The line in place of an empty experiments list.`<br>574: `The line in place of an empty work list.` |
| `web/style.css` | 3 | 509: `The label row over every claim's words: id badge, then the kind + verdict chips.`<br>520: `The id in an outlined badge, then two chips: the claim's kind on ink, its verdict outlined in the`<br>570: `The verdict chip: outlined in its verdict's color on that verdict's wash.` |
| `web/tour.js` | 1 | 294: `The card's height without a height limit of its own.` |
| `web/words.js` | 2 | 12: `One-line meanings beside the verdict counts.`<br>114: `` `1 claim`, `46,081 claims`. `` |
| `tools/e2e-load.sh` | 1 | 19: `Load samples (epoch, 1-min load) every 5 s into $1 until killed.` |
| `tools/fast-gate.sh` | 1 | 17: `Each parallel stage records its own wall-clock beside its log.` |
| `tools/gate.sh` | 3 | 62: `Every shard STAGES names, once each, in first-use order.`<br>81: `The shipped binary end to end (data folder from the environment, exit codes, no write outside).`<br>283: `Sourcing exposes the stage functions without running the gate (tools/fast-gate.sh, probes).` |
| `tools/pin-wasm.sh` | 1 | 37: ``Replaces every `name ` line of the lock, keeping the header + the other lines.`` |
| `tools/release.sh` | 1 | 30: `` `a` ≤ `b` for dotted versions. `` |
| `tools/scale-gui.mjs` | 1 | 66: ``Wait `i` holds (a function in the page).`` |
| `tests/cli/smoke.sh` | 1 | 20: `Runs the binary in the project folder with a clean environment plus the given assignments.` |
| `tests/engine/cases.mjs` | 3 | 92: `A page's snapshot block: the text the page hands to its engine.`<br>97: `The page's engine block (base64 gzip).`<br>132: `One request's JSON text.` |
| `tests/renovate/renovate.test.mjs` | 1 | 16: `The regex custom managers, narrowed from the parsed JSON.` |
| `tests/e2e/responsive.spec.js` | 1 | 30: `The ids of the cards still carrying their tag, and of those that do not.` |

## reviewer-39-F5 — minor — documented generated action/items can name nothing

- Locations: `tools/scale.mjs:3–4`, `:374–377`, `:394–401`, `:453–456`.
- Contract: the generator's own usage/comments promise `action.txt` = the costliest one-click what-if and `items.txt` = the costliest item of each kind; it accepts integer n ≥ 1. A nonexistent action/item satisfies neither promise.
- Anchors: `action.txt (the costliest one-click what-if)`; `items.txt (the costliest item of each kind)`.
- Contradiction: `deep 1` has F0 + E, but emits `suppose:F1` + `fact:F1`; `prereqs 1` and `prereqs 2` have no R-1 or C-1, but emit `success:R-1`, `experiment:R-1`, `claim:C-1` (`third = floor(n/3)`). Generator rc 0; consuming the outputs returns rc 2.
- Red test on the base:

```sh
python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-39/red-generated-items.py
```

Observed rc 1 (`generated-items.log`):

```text
CONTROL deep-3: generated action + all 2 details items resolve (expected)
CONTROL prereqs-3: generated action + all 3 details items resolve (expected)
FAIL deep-1: generator rc=0, but promised action/items do not resolve
  --action suppose:F1: rc=2, fvtrace: "suppose:F1" is not a suggested what-if
  --details fact:F1: rc=2, fvtrace: "F1" is not a fact on record
FAIL prereqs-1: generator rc=0, but promised action/items do not resolve
  --action success:R-1: rc=2, fvtrace: "success:R-1" is not a suggested what-if
  --details experiment:R-1: rc=2, fvtrace: "R-1" is not an experiment on record
  --details claim:C-1: rc=2, fvtrace: "C-1" is not a claim on record
FAIL prereqs-2: generator rc=0, but promised action/items do not resolve
  --action success:R-1: rc=2, fvtrace: "success:R-1" is not a suggested what-if
  --details experiment:R-1: rc=2, fvtrace: "R-1" is not an experiment on record
  --details claim:C-1: rc=2, fvtrace: "C-1" is not a claim on record
AssertionError: accepted sizes generated nonexistent actions/items
```

- Fix direction: select existing fallback actions/items at accepted small sizes, or explicitly refuse/document unsupported sizes before creating a partial fixture. Preserve the graded cap/half-cap cases.

## Known-finding intersections

- F21: `tools/compare.sh:2–8` stdout/stderr/rc equality promise vs v1 oracles; `tools/scale.sh:19–24` all-failure grading promise vs session rc; `tools/scale-gui.mjs:58–59`, `:78–79` own-click details timing promise vs stale readiness.
- F22: `tools/scale-gui.mjs:242–243` cleanup “on every way out” vs spawn error.
- F23: `.github/workflows/release.yml:61` wrong-version archives publish/attest nothing.
- F29: `tools/gate-probe.sh:2–6` probe execution claim vs unexecuted selections.
- F30 + F35: `tools/trust.sh:2–6`, `tools/gate.sh:101–102` audit coverage; no duplicate audit finding.
- F31: `tools/mutate.mjs:7`, `:66` strings never mutated.
- F32: `tools/install-lean.sh:16–17` timeout ends the child.
- F34: `tools/e2e-load.sh:5–7` ≥ 1.5× load claim.
- F24 + F37: `web/app.js:148`, `:203–204`, `:394–395`, `:572–573`, `:660–661` any engine failure ends the session / queued requests never enter.
- F25: `web/tour.js:319`, `:339` card stays clear/under its target.
- F27: `web/app.js:488–489` record problem removes tour.
- F39: `web/app.js:501` action expands from shown view.
- F40: `web/app.js:5–6` hash holds reloadable view.
- F43: `web/app.js:698` selection moves highlight.
- F44: `web/app.js:1037–1039` one section per group.
- F45: `web/app.js:909–910` focus stays on its item.
- F50: `web/lookups.js:1–3` no row scans an envelope list.
- F7: `tests/schema/schema.test.mjs:1–3` schema/decoder agreement + expressibility boundary.

## Register / coverage limits

- `web/app.js:97`, `web/dom.js:1`, `web/engine.js:3`, `tests/e2e/access.spec.js:1`, `tests/e2e/proxy.spec.js:1`, `.github/workflows/release.yml:73` — security → MAIN. No security adjudication here.
- External/historical factual claims remain **unconfirmed**, not silently passed as empirical results: action SHA ↔ version labels (four workflows); CPython branch/revision parity (`tools/vendor-hacl.sh:11–12`); driver.js 1.10.2 implementation (`web/tour.js:2`); Lean/toolchain formatter absence + exact upstream default/runtime facts; historical timings/memory/stack-size figures (`tools/install-lean.sh:12`, `tools/scale-gui.mjs:151–154`, `web/app.js:836–837`, `web/lookups.js:2–3`, `tests/engine/cases.mjs:329–330`, `playwright.config.mjs:13–14`, `tests/e2e/smoke.spec.js:14`). Looked in the named source, scoped rule files, `.agent/contracts/units.md`, and a bounded `rg` over `.agent/archive/` + contracts (45-line output cap; six matches returned). The 9,600-frame rationale appears in kernel.md E-wasm + `archive/implement-whatifs.md`; e2e measurement provenance points to commits in units.md, not raw measurements reproduced here. No upstream fetch, historical benchmark rerun, browser/GUI run, full gate, mutation campaign or CI run performed.
- Every scoped file included: 60 files, 13,087 source lines. Comment candidate inventory = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-39/comment-index.txt` (superset: includes string/URL/glob lookalikes, rejected during reading). CSS = all 27 comment blocks, each with its corresponding styles + JS cross-reference; not a full CSS correctness review. `web/index.html` + `.oxlintrc.json` contain no comments.
- Verification run: textual anchor/census validator rc 0; actual generator/native boundary calls (F1 + F5); `requestsFor`/native-envelope inspection rc 0. F5 red rc 1 as required; n=3 positive controls pass. Every native call inherited or explicitly set `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-39/home` as `FVTRACE_HOME`. No server started; no target edits.
- Rerun text proof: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-39/check-comments.py` → rc 0, `what-only: 56 blocks in 21 files`, `all textual anchors matched`. Detailed output = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-39/anchors.log`; red output = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-39/generated-items.log`.

reviewer-39-DONE-1
