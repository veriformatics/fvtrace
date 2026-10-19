---
paths:
  - "web/**"
  - "tests/e2e/**"
  - "playwright.config.mjs"
---

# GUI

- Display only: every verdict, ranking, plan + sentence on screen comes from the engine's JSON; the GUI computes none (a re-derived judgment would sit outside the proofs).
- DOM built with `createElement` / `textContent` / `append`; HTML-string sinks (`innerHTML`, `outerHTML`, `insertAdjacentHTML`, `srcdoc`, `createContextualFragment`, `document.write`) fail `oxlint` (`no-restricted-properties`), and the server's CSP enforces Trusted Types so a missed sink throws at runtime.
- No build step: ES modules typed by JSDoc, checked by `tsc -p web` (strict, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`); fetched JSON stays untyped until a decoder narrows it (oxlint `no-unsafe-*`).
- Browser checks run in Playwright's bundled Chromium (honors reduced-motion emulation; chromiumfish ignores it); `CHROME=<path>` overrides locally.
