# reviewer-28 — K-receipt + K-eval

Target = `48bc51d` at `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Fixed checks = Cleanup + Altitude; separate pass per lens, per slice. Output = validator input; target stays read-only.

| row | target | verdict | basis |
|---|---|---|---|
| K-receipt | Cleanup: Receipt + Receipt/Basic + Replay + c shim | pass | Whole-file pass; cache/index state intentional (fast.md); replay streams already parallel, runs contractually sequential; manifest + pin/bind phases have different outputs. |
| K-receipt | Cleanup: tests | finding reviewer-28-F1 | Identical test utilities: count ×7, fixture ×3, mapFact ×3; full-base source search + matching bodies. |
| K-receipt | Altitude | pass | Second pass: path resolution, cache, pinning, review and positional replay updates remain mechanism-local; FFI/Init split, empty-draft FFI bypass, direct argv + sequential replay policy justified by contract. |
| K-eval | Cleanup: Evaluate + Request + Session + Snapshot + Render | unknown | unknown |
| K-eval | Cleanup: tests | unknown | unknown |
| K-eval | Altitude | unknown | unknown |

## reviewer-28-F1 — shared test utilities reimplemented per suite

Severity = **minor**. Contract = `CLAUDE.md` Engineering, Cleanup: existing helpers reused; near-duplicate blocks merged.

- Target anchors: `Tests/Replay.lean:39`, `Tests/Notices.lean:45`, `Tests/Snapshot.lean:7`, `Tests/Receipt.lean:7–13`.
- Count implementations = 7 identical expressions, parameter spelling aside: `Tests/{Replay,Notices,Snapshot,Fields,CliStore,Export,Assets}.lean`. Every suite imports `Tests.Harness`; none needs its own count algorithm. `Tests/Receipt.lean:7–13` also duplicates both `fixture` and `mapFact` byte-for-byte from `Tests/Engine.lean:7–13` and `Tests/Check.lean:7–10,18–19`. These are shared infrastructure, not independent behavior oracles: fixture = common input loader, mapFact = input mutation, count = output occurrence counter.
- Text proof, base-root absolute prefix `/home/eturkes/Projects/fvtrace/.scratch/review-base`:
  ```sh
  rg -n --hidden --glob '!*.md' 'def count \((s sub|text sub) : String\)|def mapFact \(t : Trace\)' /home/eturkes/Projects/fvtrace/.scratch/review-base
  ```
  rc=0: count definitions at `Tests/Fields.lean:12`, `Tests/CliStore.lean:7`, `Tests/Snapshot.lean:7`, `Tests/Replay.lean:39`, `Tests/Export.lean:7`, `Tests/Assets.lean:8`, `Tests/Notices.lean:45`; mapFact at `Tests/Engine.lean:12`, `Tests/Receipt.lean:12`, `Tests/Check.lean:18`.
- Distinctive exact-byte anchors:
  ```sh
  rg -Fn 'def count (s sub : String) : Nat := (s.splitOn sub).length - 1' /home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/{Replay,Snapshot,Fields,CliStore,Export,Assets}.lean
  rg -Fn 'def count (text sub : String) : Nat := (text.splitOn sub).length - 1' /home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Notices.lean
  rg -Fn '{ t with facts := t.facts.map fun x => if x.id == id then f x else x }' /home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/{Receipt,Engine,Check}.lean
  rg -Fn '  | .error ds => throw (IO.userError s!"fixture does not decode: {repr ds}")' /home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/{Receipt,Engine,Check}.lean
  ```
- Fix → move occurrence counting into `Tests.Harness`, and common trace fixture + fact mutation into one shared pure test-helper module; keep assertion bodies + expected values unchanged.
