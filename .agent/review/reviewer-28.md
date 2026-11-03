# reviewer-28 — K-receipt + K-eval

Target = `48bc51d` at `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Fixed checks = Cleanup + Altitude; separate pass per lens, per slice. Output = validator input; target stays read-only.

| row | target | verdict | basis |
|---|---|---|---|
| K-receipt | Cleanup: Receipt + Receipt/Basic + Replay + c shim | pass | Whole-file pass; cache/index state intentional (fast.md); replay streams already parallel, runs contractually sequential; manifest + pin/bind phases have different outputs. |
| K-receipt | Cleanup: tests | finding reviewer-28-F1 | Identical test utilities: count ×7, fixture ×3, mapFact ×3; full-base source search + matching bodies. |
| K-receipt | Altitude | pass | Second pass: path resolution, cache, pinning, review and positional replay updates remain mechanism-local; FFI/Init split, empty-draft FFI bypass, direct argv + sequential replay policy justified by contract. |
| K-eval | Cleanup: Evaluate + Request + Session + Snapshot + Render | finding reviewer-28-F2, reviewer-28-F3 | Whole-file pass + repo-wide helper search; identical JSON serializers repeated; Snapshot.Engine.answer rebuilds immutable binding index before checking cached Answers (confirmed in generated C). |
| K-eval | Cleanup: tests | finding reviewer-28-F1 | Evaluate suite reuses Engine fixture + Harness; Snapshot reimplements the common occurrence counter; native/interpreted split and fresh-engine parity paths serve independent checks. |
| K-eval | Altitude | pass | Second pass: no caller-specific policy inside shared request/evaluation helpers; Session reader injection tests D-json growth, Snapshot/native split preserves Init-only closure, count-only vs full detail/raiser paths intentionally avoid cross-products. F3 is lifecycle caching, not a policy special case. |

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

## reviewer-28-F2 — common JSON payloads serialized independently

Severity = **minor**. Contract = `CLAUDE.md` Engineering, Cleanup: existing helpers reused; near-duplicate blocks merged. These copies serialize the same values with the same field order; they are not distinct wire contracts.

| payload | independent implementations |
|---|---|
| Receipt binding `{id,current,reasons}` | `Fvtrace/Snapshot.lean:27–28`; `Fvtrace/Session.lean:155–156`; already also `Fvtrace/Cli.lean:198–199` |
| Optional replay-notices member | `Fvtrace/Evaluate.lean:65–69`; `Fvtrace/Session.lean:153,157–158` (same absence rule, domain order + fields); per-notice object also `Fvtrace/Cli.lean:152–153` |
| Claim details `{sentence,incompatible,plan}` | `Fvtrace/Evaluate.lean:214–215`; `Fvtrace/Evaluate.lean:287–288` |

Proof = complete bodies read + repo search for `bindingJson`, `noticesJson`, `noticeJson`, `A.sentence`, with these exact-byte anchors (all matches rc=0 on base):

```sh
rg -Fn '  .obj [("id", .str b.id), ("current", .bool b.current), ("reasons", .arr (b.reasons.map .str))]' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/{Cli,Snapshot}.lean
rg -Fn '    ("bindings", .arr (l.bindings.map fun b => .obj [("id", .str b.id),' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Session.lean
rg -Fn '  | ns => [("notices", .arr (ns.map fun (id, x) =>' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Evaluate.lean
rg -Fn '    (if notices.isEmpty then [] else [("notices", .arr (notices.map fun (id, x) =>' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Session.lean
rg -Fn '("id", .str id), ("date", .str x.date), ("reason", .str x.reason)' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/{Evaluate,Session,Cli}.lean
rg -Fn '    | some c => .ok [("sentence", .str (A.sentence c)), ("incompatible", strs (A.incompatible c)),' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Evaluate.lean
rg -Fn '  let claimLists := fun (c : Claim) => [("sentence", Value.str (A.sentence c)),' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Evaluate.lean
```

Fix → share pure binding + notice serializers below the native/page split; reuse `Evaluate.noticesJson` in `Session.viewOf`; extract one `claimLists` helper for both detail paths. Keep field order, notice omission + completeWith's indexed fact raisers unchanged. No `Std` import enters `Snapshot`/`Receipt.Basic`'s closure.

## reviewer-28-F3 — cached page details rebuild an immutable binding index

Severity = **minor**. Contract = `CLAUDE.md` Engineering, Cleanup: startup + hot paths lean; `.agent/contracts/kernel.md` E-state (snapshot + its indexes kept in the instance), P-index (index materialized once per consumer batch). This is an unnecessary-work finding, not a failed timing-bound claim.

- Anchor = `Fvtrace/Snapshot.lean:90`: `  let byId := Receipt.BindingIndex.of s.bindings`.
- `Engine` keeps `snap` + `last` (`:75–77`), but `Engine.answer` rebuilds the same immutable snapshot's binding index on each successful parsed what-if. The repeated-details path then takes cached `Answers` (`:94–96`) and `Evaluate.detailsWith` (`:111–115`), which uses the scenario's trace/overrides alone (`Evaluate.lean:222–229`): the newly built `current` index is not needed there at all. The cached Answers already retain the scenario's current-status answers; bindings never change within a page instance.
- Proof = source + generated base C. The compiler does sink the build past request/what-if parsing, so malformed-input cost is **not** claimed. It does **not** sink past the cached-Answers decision:
  - `.lake/build/ir/Fvtrace/Snapshot.c:2068`: `v_byId_570_ = lp_fvtrace_Fvtrace_Receipt_BindingIndex_of(v_bindings_554_);` in every successful-what-if branch, before any `answersAt` cache test.
  - Same file `:1938–1976`: `Engine_answer___lam__1` implements the later `last` override equality/cache test; on equality it returns the previous Answers and drops the new `current` closure.
  ```sh
  rg -Fn '  let byId := Receipt.BindingIndex.of s.bindings' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Snapshot.lean
  rg -n ' = lp_fvtrace_Fvtrace_Receipt_BindingIndex_of' /home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/ir/Fvtrace/Snapshot.c
  ```
  Both rc=0; first match source `:90`, second generated `:2068`.
- Fix → materialize the immutable binding index/current predicate once in `Engine.load`, carry it as structure state (fast.md's full-arity closure trap still applies), and reuse it for every request. Keep cached Answers semantics + output bytes unchanged.
- Not measured: runtime magnitude or any P-bound/U-time breach. No behavioral regression asserted; no red behavior test required for this source-level unnecessary-work proof under lens K.

## Register

- `c/fvtrace_digest.c:19` — security → MAIN (unconfirmed; source only).

## Coverage + verification

- Adjudicated = 6/6 target rows. Cleanup + Altitude = separate passes per slice. Read every assigned source/test file (2,414 lines); read relevant kernel/unit sections + fast/wasm/Lean law; traced related helper/caller sites in Encode, Digest, Store, Engine, Server, CLI, Harness, Check + Engine tests.
- Static checks run/passed = exact `rg -Fn` anchors for F1/F2/F3; repo-wide helper search; generated `Snapshot.c` inspection for F3. Seed validator = 6 matching lines (expected 6); final pending-cell search = no matches, rc=1 (expected 0 cells). Positive controls = F1 exact anchors matched expected 6 + 1 + 3 + 3 counts, each rc=0.
- Lean LSP unavailable: real-file `documentSymbol` request returned `No LSP server available for file type: .lean`; reference checks used named-path source search instead.
- Not run = builds, suites, full gate, mutation campaigns, benchmarks, browser checks (source-only lens K; no target edits). No numerical performance claim. Search scope = base source tree, normal ignore rules; generated output inspected only for F3, not a generated-tree dead-code census.
- Writes = this validator-input deliverable alone. Target + other primary-tree files untouched; no Git mutation, application run, process/server or retained scratch artifact. Known stderr-tail findings excluded as brief requires.

reviewer-28-DONE-1
