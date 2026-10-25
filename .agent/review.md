# Review ledger (IMPLEMENT — what-ifs by reference)

Open rows gate the phase close; the closing-diff `reviewer`s (U10) rule each. Earlier ledgers: `.agent/archive/review-*.md`.

| id | finding | owner | status |
|---|---|---|---|
| M1 | Mutation survivor `Fvtrace/Json.lean:187` `<` → `<=` in `firstRepeat` (U2; `node tools/mutate.mjs Fvtrace/Json.lean --lines 22-38,179-189 --timeout 900`: 15 of 16 killed). MAIN reads it as equivalent: each member's key sits at its own byte offset, so two offsets never tie; the code before U2 carried the same comparison | closing-diff reviewer | open |
| M2 | U3 mutation campaign (`.scratch/refs/mutate-u3.sh`, pool): Request.lean 5/5 killed, Evaluate.lean 4/9 killed at commit; the remaining Evaluate + Cli.lean mutants (5 + 11) finish after the U3 commit, their kills + survivors recorded in the next commit | MAIN (results), closing-diff reviewer (survivors) | open |
