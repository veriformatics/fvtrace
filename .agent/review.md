# Review ledger (IMPLEMENT — what-ifs by reference)

Open rows gate the phase close; the closing-diff `reviewer`s (U10) rule each. Earlier ledgers: `.agent/archive/review-*.md`.

| id | finding | owner | status |
|---|---|---|---|
| M1 | Mutation survivor `Fvtrace/Json.lean:187` `<` → `<=` in `firstRepeat` (U2; `node tools/mutate.mjs Fvtrace/Json.lean --lines 22-38,179-189 --timeout 900`: 15 of 16 killed). MAIN reads it as equivalent: each member's key sits at its own byte offset, so two offsets never tie; the code before U2 carried the same comparison | closing-diff reviewer | open |
| M2 | U3 mutation campaign (`.scratch/refs/mutate-u3.sh`, pool), complete: Request.lean 5/5 killed, Evaluate.lean 9/9 killed, Cli.lean 4 killed · 3 survived · 4 incompetent. Survivors (MAIN reads all three as equivalent): Cli.lean:405 + :406 `evalSpec 0` → `evalSpec 1` inside `evalOnlySpec` (the valued + switch lists do not read the positional count); Cli.lean:649 `withLoaded env args 0` → `1` with `spec := evalOnlySpec` given (the positional count feeds only the default spec) | closing-diff reviewer | open |
| M3 | U6 page engine state: `Snapshot.lean` changed lines (`.scratch/refs/mutate-u6.sh`, pool): 1 mutant (the kept-answers test `if o' == o`), killed; no survivor | — | closed |
| M4 | U6 server-cache campaign (`.scratch/refs/mutate-u6b.sh`, pool): Server.lean 4/4 killed; Session.lean 1/2 killed, survivor Session.lean:65 `readPrefix t.trace (limit + 1)` → `limit + 2` (moved, unchanged, from `readWithin`). D-json specifies "at most one byte past the limit is read": the bound matters only for a file that grows between its size check and its read, so no test observes it; a deterministic test needs an injected reader (a byte-counting `readPrefix`) | closing-diff reviewer (ruling: add that test, or record the race as untestable) | open |
