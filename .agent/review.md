# Review ledger (IMPLEMENT — what-ifs by reference)

Open rows gate the phase close; the closing-diff `reviewer`s (U10) rule each. Earlier ledgers: `.agent/archive/review-*.md`.

| id | finding | owner | status |
|---|---|---|---|
| M1 | Mutation survivor `Fvtrace/Json.lean:187` `<` → `<=` in `firstRepeat` (U2; `node tools/mutate.mjs Fvtrace/Json.lean --lines 22-38,179-189 --timeout 900`: 15 of 16 killed). MAIN reads it as equivalent: each member's key sits at its own byte offset, so two offsets never tie; the code before U2 carried the same comparison | closing-diff reviewer | open |
