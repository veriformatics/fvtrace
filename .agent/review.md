# Review ledger (IMPLEMENT — GUI)

Closing review of `19277b4..HEAD` (this phase's diff). Rows needing a ruling by someone other than the author (L-SEC rows: MAIN alone, per the IMPLEMENT body); a row closes with its ruling + evidence. Status: `open` · `accepted` (fix required, named) · `rejected` (with reason) · `register` (outside the contract, recorded) · `closed` (fix landed + re-reviewed). The whole-product ledger: `.agent/archive/review-implement.md`.

## Lenses (fixed before reading the diff)

| id | lens | asks |
|---|---|---|
| L-CORR | correctness / spec | does the code meet `.agent/contracts/kernel.md` (as amended in 03fe522) on every input it admits? (+ `CLAUDE.md` Correctness diff lens) |
| L-CLAIM | claim soundness | is every sentence fvTrace ships (CLI, GUI, README, skill, self-trace, synthetic study) true at its stated strength? |
| L-GAP | guarantee vs claim | does a shipped guarantee (proof, test, check, doc) outrun the mechanism backing it? |
| L-HARD | verification integrity | red witnesses + mutation credit recorded per unit; survivors ruled; no fixture-shaped special case; grading checks unchanged |
| L-LAW | `CLAUDE.md` conformance | tiers + contracts per unit, gate identity, authoring registers, rules upkeep, every `Decisions` entry implemented or deferred with its reason |
| L-UI | GUI against Decisions | operator-2's visual QA rows (`.scratch/operator-2/verdicts.md`): a failing row → a row here |
| L-SEC | security (MAIN alone) | untrusted trace text, project files, HTTP input → every sink (GUI DOM, terminal, export page, server) |

## Rows

| id | unit | lens | finding | status | acceptance check |
|---|---|---|---|---|---|
| HARD-1 | U2 | L-HARD | Mutation survivor `Fvtrace/Engine.lean:371` `Overrides.normalize`: `a.1 ≤ b.1` → `a.1 < b.1`. Claimed equivalent: every list normalized has distinct keys (`Overrides.parse` rejects duplicates; `withOverrides` keeps the extra keys + filters the old ones), and a strict order sorts distinct keys the same way. | open | A reviewer rules equivalent (cites each caller of `normalize` + why its keys are distinct) or names an input whose result differs. |
| SEC-1 | U2–U5 | L-SEC | Untrusted input → sink trace for this diff (MAIN): new trace texts `why` + `headline` are D-text at decode (no C0 but `\n`), reach the terminal only through `Render.safe` (`check`/`claims` print no new field), the GUI only through `textContent` (`conditions`, `exactStatement`, inspector, waiver reasons), the export page only inside the `htmlSafe` data island; `restatedBy` feeds a digest alone; new CLI text = constants + D-id ids; `Overrides.parse`'s new refusal names a resolved fact id; the bundler parses the binary's own modules (no user input); the tour writes CSSOM numbers + static selectors; the server's routes, `decide` + headers are unchanged. No HTML-string sink in web/ (oxlint ban + Trusted Types CSP). | register (no finding) | — |
| SEC-2 | U5 | L-SEC | GUI word tables read `table[code]` (`word`, `symbols`, `lintNeeds`): an own-property miss on a code like `constructor` would print an inherited member. Unreachable: every code is an engine enum (decoder-checked) and waiver rules are lint ids (WF-waiver); a tampered exported page controls its own script anyway. | register (unreachable) | — |
