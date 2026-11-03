# reviewer-32 — K-gui-b

Base: `48bc51d`; frozen tree `/home/eturkes/Projects/fvtrace/.scratch/review-base`.
Check set fixed before target read: Cleanup + Altitude; two passes; M-gui-b + `tests/palette/`.

| row | target | verdict | basis |
|---|---|---|---|
| K-gui-b | Cleanup: panels.js + circuit.js | reviewer-32-F1 | Full files + DOM helper/caller search: two button factories repeat imported `idButton`; headline, conditions + labels already shared. |
| K-gui-b | Cleanup: lazy.js + tour.js | reviewer-32-F2 | Full files + all JS size/read/reflection sites: unused `LazyList.size` getter; tour steps/state/helpers used. |
| K-gui-b | Cleanup: style.css + index.html (unused rules, ids, properties) | reviewer-32-F3, reviewer-32-F4 | Full stylesheet + HTML; parser inventory of 259 rules, 138 class tokens, 11 properties; producer searches over all web modules + Export.lean. Dead/overridden rules + eight copied vertical-layout blocks; every custom property read; IDs referenced. |
| K-gui-b | Cleanup: tests/palette | pass | Full test file: each helper/table used; contrast vs mark visibility vs hue-distance loops grade distinct invariants; runner/probe paths live. Direct palette test run rc 0, 3 passed / 0 skipped. |
| K-gui-b | Altitude | unknown | unknown |

## Findings

### reviewer-32-F1 — minor — repeated reference-button factory

- Locations: `web/panels.js:40–51`; `web/circuit.js:242–252`; existing helper = `web/dom.js:97–108`.
- Contract: `CLAUDE.md` Engineering Cleanup → existing helpers reused; near-duplicate blocks merged.
- Defect: `ref` + `factRef` build the same `.ref` button that both files already import as `idButton`: id text, key, `type="button"`, select listener. Only the key + select callback vary, exactly the helper's parameters. `idButton`'s absent `pressed` argument omits `aria-pressed` (`h` omits undefined), preserving these factories' behavior.
- Anchor commands (absolute base = `/home/eturkes/Projects/fvtrace/.scratch/review-base`; each rc 0):
  - `rg -Fn 'function ref(/** @type' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/panels.js` → line 40.
  - `rg -Fn 'const factRef = (id) =>' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/circuit.js` → line 242.
  - `rg -Fn 'export const idButton = (id, key, open, pressed) =>' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/dom.js` → line 97.
- Proof: compare the complete factories at the ranges above; `dom.js:34–35` omits undefined attributes. Repository search for `idButton|function ref\\b|const factRef\\b` confirms the existing helper + these copies; both renderers import it on line 4.
- Fix: retain semantic wrappers if useful, implement each through `idButton` with its existing key + callback.


### reviewer-32-F2 — minor — unused lazy-list accessor

- Location: `web/lazy.js:84–87`.
- Contract: `CLAUDE.md` Engineering Cleanup → dead code removed.
- Defect: `LazyList.size` returns `count`, but no reader uses it. The only JS consumers of the class = `web/app.js` + `web/lazy.js` itself; all counts use the input arrays or `this.count`. This is internal GUI code, not a published package interface.
- Anchor: `rg -Fn 'get size() {' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/lazy.js` → `85:  get size() {`, rc 0.
- Proof command: `rg -n '\\.size\\b|\\["size"\\]|get size\\(' /home/eturkes/Projects/fvtrace/.scratch/review-base --glob '*.js' --glob '*.mjs'`, rc 0. Complete output = getter at `lazy.js:85`; `app.js:673` (`w` = what-if Map); `tests/e2e/export.spec.js:97` (`native` = Map); `tests/engine/loader.test.mjs:79` (`r.allocated` = Set). `rg -l '\\bLazyList\\b' …/web` positive control → exactly `app.js`, `lazy.js` (2 files), rc 0. `Reflect.*` sites in the consumers operate on Trusted Types, Worker + messages, never a list.
- Fix: remove the getter + its comment; retain `count` used by the list mechanism.

### reviewer-32-F3 — minor — stale / ineffective stylesheet rules

- Locations: `web/style.css:976–981` (dead group), `:43` + `:305–307` (unreachable disabled state), `:1456–1458` (inapplicable grid property).
- Contract: `CLAUDE.md` Engineering Cleanup → dead code removed; derivable / duplicate definitions pruned.
- Defects:
  - `.work-meta` has no producer. Its grouped `.list-meta` declarations at 978–980 are all superseded by the same selector at 994–998 (`display: block`, `margin-top: 3px`, `color: var(--conductor)`). The entire 976–981 block has no effect.
  - No shipped control has native `disabled`, and no code sets it; only `aria-disabled` is present (`circuit.js:70`, read by `tour.js:100`). Therefore `button:disabled` + `.reset:disabled` never match. ARIA-disabled is not the native disabled state.
  - `.how-key` is a div with block layout (`index.html:40`; its base rule at 1272–1275 sets only container type + margin). Nothing makes it a grid; its phone-only `grid-template-columns: 1fr` cannot affect layout.
- Anchors (base path below): `rg -Fn -e '.work-meta,' -e '.list-meta {' -e '.reset:disabled {' -e 'button:disabled,' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/style.css` → lines 43, 305, 976, 977, 994; rc 0. `rg -n -A 4 -B 1 '^\\s*\\.how-key\\s*\\{' …/web/style.css` → both rules at 1272 + 1456, rc 0.
- Proof:
  - Positive control (expected 2 files): `rg -l -F 'list-meta' …/web …/Fvtrace/Export.lean` → `panels.js`, `style.css`, rc 0. `rg -n --hidden --glob '!.git' -F 'work-meta' /home/eturkes/Projects/fvtrace/.scratch/review-base` → only `web/style.css:976`, rc 0. Producer-only scan (`…/web --glob '!style.css' …/Fvtrace/Export.lean`) → zero matches, rc 1.
  - `rg -n 'disabled|fieldset' …/web --glob '!style.css' …/Fvtrace/Export.lean` → only the two `aria-disabled` sites above, rc 0; full web files read. Export inlines the same stylesheet + modules (`Fvtrace/Export.lean:169–201`), adds license HTML only, no hidden producer.
  - `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-32/css-inventory.mjs /home/eturkes/Projects/fvtrace/.scratch/review-base` → repeated `.list-meta` properties (978→995, 979→996, 980→997), one source-absent class `work-meta`; rc 0. The parser scans all rules, all 13 JS/HTML sources + Export.lean; every one of the 11 custom properties has ≥ 1 `var` read. Log = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-32/css-inventory.log`.
- Fix: remove the dead group, native-disabled-only selector branches + non-grid declaration; keep `button[aria-disabled="true"]` and the surviving `.list-meta` rule.

### reviewer-32-F4 — minor — vertical diagrams defined twice

- Locations: `web/style.css:1064–1112`, `:1129–1134`; byte-equivalent declaration bodies under the phone media query at `:1520–1575`.
- Contract: `CLAUDE.md` Engineering Cleanup → near-duplicate blocks merged; modular components deduplicated.
- Defect: the same vertical diagram layout has two independent definitions: `.tall …` at any width, and every diagram on phones. Eight pairs contain exactly the same 33 declarations; the only difference = the selector / media condition. Changes to wire geometry, contact size or end layout must stay synchronized across both.
- Anchors: `rg -Fn -e '.tall .contacts {' -e '.tall .contact {' -e '.contacts {' /home/eturkes/Projects/fvtrace/.scratch/review-base/web/style.css` → 595, 1064, 1069, 1520; rc 0.
- Proof command: `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-32/css-inventory.mjs /home/eturkes/Projects/fvtrace/.scratch/review-base`, rc 0. The parser compares full ordered `(property, value, important)` lists, not a substring. Exact pairs:
  - contacts 1064–1067 = 1520–1523;
  - contact 1069–1077 = 1525–1533;
  - contact wire 1079–1085 = 1535–1541;
  - switch 1087–1095 = 1543–1551;
  - switch svg 1097–1100 = 1553–1556;
  - contact-label 1102–1105 = 1558–1561;
  - terminal 1107–1112 = 1563–1568;
  - terminal wire 1129–1134 = 1570–1575.
- Fix direction: one vertical layout definition; apply horizontal geometry only to non-tall diagrams above the phone breakpoint (low-specificity selectors, e.g. `:where`, preserve the existing cascade). Keep `.tall .wire-end` behavior, capital trimming, tabular digits + the terminal `.unavailable` block intact; verify rendered geometry after refactoring.

## Register

None yet.
