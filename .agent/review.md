# Review ledger (IMPLEMENT — whole product)

Rows needing a ruling by someone other than the author; a row closes with its ruling + evidence. Status: `open` · `accepted` (fix required, named) · `rejected` (with reason) · `register` (outside the contract, recorded) · `closed` (fix landed + re-reviewed).

## Lenses (closing review, fixed before reading the diff)

| id | lens | asks |
|---|---|---|
| L-CORR | correctness / spec | does the code meet `.agent/contracts/kernel.md` on every input it admits? (+ `CLAUDE.md` Correctness diff lens) |
| L-CLAIM | claim soundness | is every sentence fvTrace ships (CLI, GUI, docs, self-trace) true at its stated strength? |
| L-GAP | guarantee vs claim | does a shipped guarantee outrun the mechanism (proof, test, check) backing it? |
| L-HARD | verification integrity | red witnesses + mutation credit recorded; no fixture-shaped special case; survivors ruled |
| L-LAW | `CLAUDE.md` conformance | tiers, contracts, gate identity, authoring register, rules upkeep |
| L-SEC | security (MAIN alone) | untrusted trace text, project files, HTTP input → every sink: paths, terminal, HTML, server |

## Rows

| id | unit | lens | finding | status | acceptance check |
|---|---|---|---|---|---|
| R1 | U3 | L-HARD | Mutation survivor `Fvtrace/Decode.lean` `array`: `ok := false` → `true`. Claimed equivalent: every element that fails reports a diagnostic, and `decodeTrace` returns `.error` whenever a diagnostic exists, so the flag never changes a result. | open | A reviewer rules equivalent (cites the decodeTrace branch) or names an input whose result differs. |
| R2 | U3 | L-HARD | Mutation survivor `Fvtrace/Decode.lean` `outcome`: `ok := false` → `true`. Same claim as R1. | open | As R1. |
