# reviewer-42 — V-js

Target = `48bc51d` in `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Check set = verification integrity in BRIEF.md + LENSES.md § V + V-js brief. Target read-only; experiments only in owned scratch. Findings already in `.agent/review.md` cited, not duplicated.

| row | target | verdict | basis |
|---|---|---|---|
| V-js | e2e specs + harness + playwright.config | unknown | unknown |
| V-js | tests/engine (differential, loader) | finding reviewer-42-F1 | Both Node differential tests pass a planted panic at the final refused snapshot; earlier-load control fails; byte comparisons + native oracle + loader boundaries inspected. |
| V-js | tests/schema + cases | finding F7 (existing) | 61 cases = 15 valid + 44 invalid + 2 decoder-only; overflow case misclassified as decoder-only = F7. Node corpus passes; extra-field schema defect fires. |
| V-js | tests/palette | finding reviewer-42-F2 | Floors + text surface table read; contrast/hue plants fire, but Culori applies Machado matrices to nonlinear RGB; independent linear calculation + ColorAide show a base pair below 8. |
| V-js | tests/renovate | pass | File/dependency expectations follow actual pinned inputs; intentionally extraction-only (renovate.md). Broken scanner manager fires on missing actionlint. |
| V-js | wiring (runners, globs, gate stages) + history | pass | Playwright lists 58 tests/7 specs; 5 Node test modules match directory discovery; gate :99/:144/:146 runs all. Current + history suppression searches clean; 41 relevant commit bodies + removed-test/limit inventory read: format/API rewrites preserve checks, 27787a1 records the user's timeout ruling + original firing. |

## reviewer-42-F1 — minor — final refused loads bypass the Node stderr oracle

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tests/engine/engine.test.mjs:54–58,106–110`; stderr assertions only at :79 + :117, inside successful-load request loops.
- Contract: kernel.md E-wasm = byte equality **and no engine output on standard error**; wasm.md runtime-patch bullet + ops.md `engine` promise the same. A panic can return the correct native bytes, so equality alone is insufficient.
- Proof: both `continue` branches compare refusal bytes then leave the snapshot without checking `said`; the corpus ends in four refused loads. `plant-panic.mjs` proxies the real wasm `fvtrace_load`, writes one panic only for final `2026-13-01`, then returns the real answer unchanged. Unchanged Node differential: `1072 answers on 21 snapshots equal`; request sequence: `687 answers equal`; `tests 2`, `pass 2`, `fail 0`, rc 0; witness file = 2 executed late writes. The identical plant at the initial load fails (`AssertionError … actual ['fvTrace engine: PANIC reviewer-42 planted'] … expected []`), rc 1.
- Red witness: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-42/red-engine-panic.py` (runs only the first differential for a cheap rematch; both full tests already demonstrated above). Plant + full-test logs: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-42/{plant-panic.mjs,final-panic.log,final-panic-witness.txt,initial-panic.log}`.
- Fix direction: assert captured stderr after every load (success/refusal) + once after the complete sequence, before restoring `console.error`; extend `engine-panic` to the final refusal.

## reviewer-42-F2 — minor — palette's Machado transform uses nonlinear RGB

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tests/palette/palette.test.mjs:66–67` (Culori `filterDeficiencyProt(1)` + `filterDeficiencyDeuter(1)`), `/home/eturkes/Projects/fvtrace/.scratch/review-base/web/style.css:9–10` (verified + assumption).
- Contract: web.md Palette = OKLab ΔE×100 ≥8 under Machado protan + deutan; CLAUDE.md palette-safety floor. Both state hues are compared by the gate, but its simulator applies the matrix in the wrong color space.
- Source: installed Culori `src/deficiency.js:173–182` takes `rgb(c)` (gamma-coded sRGB), multiplies the matrix, tags the result `mode: 'rgb'`. Independent ColorAide 8.14 `filters/cvd.py:218` states `ALLOWED_SPACES = ('srgb-linear',)`; its Machado method at :173–210 applies the same matrix there. Direct linear-RGB calculation in `palette-linear.mjs` agrees with ColorAide.
- Base bytes: verified `#005e32`, assumption `#8a6000`. Gate's nonlinear protan separation = 8.245 (passes). Correct linear-RGB Machado separation = **6.933609** (<8); base palette is below its declared floor. Text-contrast + unsimulated floors are unaffected.
- Red witness: `(cd /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-42 && UV_CACHE_DIR=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-42/uv-cache UV_PYTHON_DOWNLOADS=never uv run --no-project --with coloraide==8.14 python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-42/check-coloraide.py /home/eturkes/Projects/fvtrace/.scratch/review-base/web/style.css)` → rc 1: `AssertionError: palette separation 6.933609 < 8 under Machado protan`. Script reads the base CSS; positive control = all 11 color properties found. `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-42/coloraide.log` records it. Current `node --test tests/schema/ tests/palette/ tests/renovate/` passes 64/64 (rc 0).
- Fix direction: use a verified linear-RGB Machado transformation (or ColorAide), pin its reference-vector behavior, then retune colors without lowering floors.
