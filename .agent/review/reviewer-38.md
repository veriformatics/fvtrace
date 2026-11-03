# reviewer-38 — S-comments-lean

Target = frozen `48bc51d`; check set = BRIEF.md + LENSES.md § S + S-comments-lean brief. Read-only target; duplicate known findings cited by ledger id.

| row | target | verdict | basis |
|---|---|---|---|
| S-comments-lean | Fvtrace/ shipped modules (codec, model, check, engine, fast) | reviewer-38-F1, reviewer-38-F2; known F6 | All scoped comments read; core definitions + consumers cross-checked; `needs` + `position` witnesses rc 1. |
| S-comments-lean | Fvtrace/ shell modules (receipt, replay, evaluate, session, snapshot, cli, store, server, export) | unknown | unknown |
| S-comments-lean | FvtraceWasm/ + WasmMain + Main + TrustMain + lakefile | unknown | unknown |
| S-comments-lean | Tests/ + test entry points | unknown | unknown |
| S-comments-lean | what-only comments (CLAUDE.md Engineering) | unknown | unknown |

## Findings

### reviewer-38-F1 — minor — `needsAll` overstates the dependency set

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Model.lean:153`; anchor: `` `needs` + the entailment fact: everything the claim's state depends on. ``
- Contract = S-comments-lean (each comment's guarantee matches its implementation). `Scenario.final` (`Fvtrace/Engine.lean:129–130`) also depends on subject validity, hence exclusions and facts outside `needsAll`. `Present.changedByWhatif` (`Fvtrace/Present.lean:65–68`) already names that second dependency.
- Witness = `comment-witness.lean needs`, command defined below, rc 1: `needsAll=["F"]; need statuses unchanged=true; final=can->cannot` / `FAIL needsAll is not everything the claim's state depends on`.
- Fix → describe the explicit needs including entailment; name subject validity separately instead of claiming completeness.

### reviewer-38-F2 — minor — duplicate-identical claims contradict `positionOf`'s comment

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Answers/Delta.lean:118–119`; anchor: `sharing an id with an earlier one, has none`.
- Contract = S-comments-lean + P-shared (malformed collections remain in the fast answers' domain). Lines 120–122 use the first id match and compare its whole record to `c`; two identical records pass and return the first position, not `none`. The implementation's first-match behavior is coherent; the prose excludes an input it actually accepts.
- Witness = `comment-witness.lean position`, rc 1: `claims=[C,C] (identical); positionOf C=some 0` / `FAIL a claim sharing an earlier id can return its first identical occurrence, not none`.
- Fix → say that a nonidentical later duplicate falls back; an identical duplicate uses the first matching position.

Witness command (replace MODE with the named case):

```sh
(cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-38/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-38/comment-witness.lean MODE)
```

Witness outputs: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-38/witness.log`.

## Register

