# Review ledger (IMPLEMENT — export: live what-ifs)

Closing review of this phase's diff (`9060fd0..HEAD`). A row needing a ruling gets it from someone other than its author (L-SEC rows: MAIN alone, per the IMPLEMENT body); a row closes with its ruling + evidence. Status: `open` · `accepted` (fix required, named) · `rejected` (with reason) · `register` (outside the contract, recorded) · `closed` (fix landed + re-reviewed). Earlier ledgers: `.agent/archive/review-implement.md`, `.agent/archive/review-implement-gui.md`.

## Lenses (fixed before reading the diff)

| id | lens | asks |
|---|---|---|
| L-CORR | correctness / spec | does the code meet `.agent/contracts/kernel.md` § Page engine (E-snap … E-sec) + the amended envelope `actions` clause on every input it admits? (+ `CLAUDE.md` Correctness diff lens) |
| L-CLAIM | claim soundness | is every sentence fvTrace ships (CLI, GUI, README, skill, SECURITY, rules, commit bodies) true at its stated strength — proofs of definitions vs tests of the compiled engine vs export-time receipts? |
| L-GAP | guarantee vs claim | does a shipped guarantee (differential test, link checks, pins, determinism, CSP, probes) outrun the mechanism backing it? |
| L-HARD | verification integrity | red witnesses + mutation credit recorded per unit; survivors ruled; no fixture-shaped special case; grading checks unchanged |
| L-LAW | `CLAUDE.md` conformance | tiers + contracts per unit, gate identity, authoring registers, rules upkeep, every `Decisions` entry implemented or deferred with its reason |
| L-UI | GUI against Decisions | operator visual QA of the exported page's changed states (note, engine notice, stacked what-ifs) |
| L-SEC | security (MAIN alone) | untrusted what-if spec (address hash), snapshot + engine block, WASI host, CSP, the build's downloads → every sink |

## Rows

| id | unit | lens | finding | status | acceptance check |
|---|---|---|---|---|---|
| HARD-1 | U5 | L-HARD | Mutation survivors `FvtraceWasm/Binary.lean:52` (`name`'s bound): `p + n ≤ b.size` → `p - n ≤ b.size` and → `<`. Author's claim (MAIN): equivalent in outcome — a name is never the last item of an import or export entry, so a name running past (or ending at) the end makes the next read fail; `parse` refuses either way, only the message differs. | open | A reviewer rules equivalent (each caller of `name` + why a later read always follows) or names an input whose `parse` outcome (ok vs error) differs. |
| HARD-2 | U5 | L-HARD | Mutation survivor `FvtraceWasm/Lock.lean:61` (`manifest`'s sort): `a.1 ≤ b.1` → `<`. Author's claim (MAIN): equivalent on the admitted domain — `files` lists each path once (one directory walk per fetched path), and a strict order sorts distinct keys as ≤ does. | open | A reviewer rules equivalent (cites `Build.files` + why paths are distinct) or names a manifest input whose output differs. |
| UI-1 | U6 | L-UI | operator-3 visual QA (`.scratch/operator-3/verdicts.md`, 7 rows): V1–V6 pass (export note exact, stacked status exact, keyboard focus ring + Enter toggles, phone 390×844 no horizontal scroll, broken-engine page keeps the recorded view + the exact notice on desktop + phone); V7 fail = pre-existing copy outside this diff: the experiments explanation says "The engine ranks each by the claims its success makes available alone." (a system internal in UI copy). | register → `.agent/deferred.md` (copy change = a user ruling) | Deferred row's acceptance. |
