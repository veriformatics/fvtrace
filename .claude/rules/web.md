---
paths:
  - "web/**"
  - "tests/e2e/**"
  - "playwright.config.mjs"
---

# GUI

- Display only: every verdict, ranking, plan + sentence on screen comes from the engine's JSON; the GUI computes none (a re-derived judgment would sit outside the proofs).
- The address hash holds the view. Served: a linked `whatif` spec goes to the engine unparsed (its problem is shown; the GUI then adopts the engine's normalized overrides), never repaired client-side. Exported: one-click actions apply alone; a hash naming an action or what-if the page does not hold shows a notice over the recorded view.
- DOM built with `createElement` / `textContent` / `append`; HTML-string sinks (`innerHTML`, `outerHTML`, `insertAdjacentHTML`, `srcdoc`, `createContextualFragment`, `document.write`) fail `oxlint` (`no-restricted-properties`), and the server's CSP enforces Trusted Types so a missed sink throws at runtime.
- No build step: ES modules typed by JSDoc, checked by `tsc -p web` (strict, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`); fetched JSON stays untyped until a decoder narrows it (oxlint `no-unsafe-*`).
- Browser checks run in Playwright's bundled Chromium (honors reduced-motion emulation; chromiumfish ignores it); `CHROME=<path>` overrides locally.
- Palette = the custom properties atop `web/style.css` (paper, panel, ink, conductor, verified, assumption + their washes); a state shows as shape + word (lamp symbol, switch drawing, verdict text), color repeats it. `tests/palette/` (gate `js-test`) computes it: text ≥ 4.5:1 on each surface it sits on, state marks ≥ 3:1 on the panel, state hues OKLab ΔE×100 ≥ 15 unsimulated and ≥ 8 under protan + deutan (Machado); a new color or surface pairing joins its tables.
- Selectors are classes (stylelint: no IDs, specificity ≤ 0,2,1): IDs exist for JS lookups + ARIA references alone; a `hidden` section needs `.x[hidden] { display: none }` when its class sets `display`.
- Readable text stays selectable: no sentence, title or fact text inside a `<button>` (a drag there presses it, so nothing can be copied). A container that opens details = plain text + its id as the button (`idButton`, the keyboard + screen-reader route) + `clickToOpen` on the container (`prototype/gui/web/dom.js`, ported to `web/dom.js` in IMPLEMENT), which ignores a click that ends a text selection.
- Fonts vary by browser (the stack ends in `system-ui`; here it resolves to Noto Sans CJK, whose tall line box sits below its letters): an alignment check measures under ≥ 2 fonts (the default + `DejaVu Sans`, set through `document.body.style.fontFamily`). A symbol beside words centers on the words' capitals (`text-box: trim-both cap alphabetic` on the words inside a flex row), never on the line box; numbers that must line up use `tabular-nums`. Verdict marks (✓ ≈ ○ ×) = SVG paths centered on a 20-unit grid (`marks` in `circuit.js`), never font glyphs: a glyph sits off-center by an amount set by the browser's fallback symbol font (here ≈ low, ○ high at 1.25× scale).
