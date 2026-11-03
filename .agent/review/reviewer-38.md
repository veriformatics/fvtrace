# reviewer-38 — S-comments-lean

Target = frozen `48bc51d`; check set = BRIEF.md + LENSES.md § S + S-comments-lean brief. Read-only target; duplicate known findings cited by ledger id.

| row | target | verdict | basis |
|---|---|---|---|
| S-comments-lean | Fvtrace/ shipped modules (codec, model, check, engine, fast) | reviewer-38-F1, reviewer-38-F2; known F6 | All scoped comments read; core definitions + consumers cross-checked; `needs` + `position` witnesses rc 1. |
| S-comments-lean | Fvtrace/ shell modules (receipt, replay, evaluate, session, snapshot, cli, store, server, export) | reviewer-38-F3, reviewer-38-F4; known F4, F8, F19, F20, F58 | All scoped comments vs declarations + consumers; bind order source-checked; `moves` witness rc 1. |
| S-comments-lean | FvtraceWasm/ + WasmMain + Main + TrustMain + lakefile | reviewer-38-F5, reviewer-38-F6; known F15, F30, F35 | All scoped comments vs build/parser/audit code; loader ABI + version gate cross-checked; `leb` + `parallel` witnesses rc 1. |
| S-comments-lean | Tests/ + test entry points | reviewer-38-F4, reviewer-38-F5; known F7, F15 | Every scoped test comment/docstring vs its test body/helper + runner; stale server sentinel + u64 wording; `server-outcome` witness rc 1. |
| S-comments-lean | what-only comments (CLAUDE.md Engineering) | reviewer-38-F7 | 412 redundant comment units / 52 files; per-file counts + ≤3 anchors below; all 121 anchors rematched with `rg -Fn`. |

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

### reviewer-38-F3 — minor — binding-order comment reverses the implementation

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Session.lean:94–95`; anchors: `` `bindChecked` on the trace's prepared parts: receipts bound afresh (evidence is read again), `` + `then the what-if.`
- Contract = S-comments-lean (order claims match code). `bindPrepared` parses/refuses the what-if at lines 99–104, then calls `Receipt.bindings` at line 105. An invalid what-if therefore avoids binding I/O; the comment says binding precedes it. The `load` comment at line 125 repeats the same order.
- Source proof: `rg -n -F -e 'then the what-if.' -e 'let overrides' -e 'let bindings' /home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Session.lean` → lines `95`, `99`, `105`, rc 0.
- Fix → describe decode/check → what-if parsing → receipt binding, preserving the current code.

### reviewer-38-F4 — minor — two output-shape comments describe obsolete formats

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:713`; anchor: `One line per claim whose state changes:`. `movesText` at lines 715–718 joins all moves with `; ` and produces one line, not one line per claim.
  - `comment-witness.lean moves`, rc 1: `C1 changes from Pending verification to Conditional; C2 changes from Conditional to Fully supported.` / `claims=2; lines=1` / `FAIL movesText does not emit one line per changed claim`.
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Server.lean:23`; anchor: `` `evaluate w` as status 0 ``. `Server.Action` has `answer`, not `evaluate` (`Fvtrace/Server.lean:91–94`), and this helper returns `(1, v, "")` at line 27. Its callers assert the sentinel `1` at lines 52 and 65.
  - `comment-witness.lean server-outcome`, rc 1: `Action.answer none -> status sentinel 1` / `FAIL Tests.Server.outcome documents a removed evaluate constructor and status 0; it returns 1`.
- Contract = S-comments-lean (output/removed-code claims match the target). Fix → describe one semicolon-separated sentence + the current `.answer` sentinel.

### reviewer-38-F5 — minor — a ten-byte cap is called `u64`, but permits 70 bits

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/FvtraceWasm/Binary.lean:38`; anchor: `Unsigned LEB128 (at most 10 bytes: a u64).`
- Repeated in `/home/eturkes/Projects/fvtrace/.scratch/review-base/Tests/Wasm.lean:81`; anchor: `LEB128 up to 10 bytes (a u64):`.
- Contract = S-comments-lean (numeric/type-bound claims match code). `leb.go` at lines 41–47 limits byte count but accumulates all seven payload bits of byte ten in a `Nat`; no top-bit/range test limits it to 64 bits. The test at `Tests/Wasm.lean:82–86` checks ten vs eleven bytes, not a u64 range.
- `comment-witness.lean leb`, rc 1: `accepted 10 bytes; value=1180591620717411303423; u64 max=18446744073709551615` / `FAIL the documented u64 parser accepts a 70-bit value`.
- Fix → state the actual ten-byte parser cap, distinct from validating the u64 range (the link scanner is not a full wasm validator).

### reviewer-38-F6 — minor — parallel-build comment promises diagnostic completeness it caps at five

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/FvtraceWasm/Build.lean:67`; anchor: `every failure is reported`.
- Contract = S-comments-lean (coverage guarantee matches code). The helper waits for and counts all task errors, but line 77 prints `errors.toList.take 5`. With six failing tasks the sixth cause is unavailable, despite the unqualified promise.
- `comment-witness.lean parallel`, rc 1:
  ```text
  fvtrace-wasm: 6 step(s) failed:
  failure-1
  failure-2
  failure-3
  failure-4
  failure-5
  uncaught exception: FAIL the sixth failure's diagnostic is omitted, despite every failure is reported
  ```
- Fix → say that all failures are counted and the first five diagnostics shown, or remove the diagnostic cap.

### reviewer-38-F7 — minor — what-only comments repeat declarations/bodies

- Contract = `CLAUDE.md` Engineering: comments spend tokens on the why; the code states the what. This task explicitly requires this class as a finding.
- 412 comment units in 52 files. Count = selected docstring/block or standalone line-comment unit, not lines. Sections, rationale, constraints, non-obvious upstream quirks, historical measurements and contract-motivated test cases were not counted merely for being descriptive. These selected comments narrate the adjacent declaration/body without a further reason; e.g. `Answers.lookups : Lookups` → “The trace's lookups”, `Counts.of` → a formula restatement, and `Args.Spec.positional` → “Allowed positional counts”.
- Exact selected line lists + counts: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-38/what-only.json`. Derivation/anchor validator: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-38/what-only.py` → `what-only: files=52, comments=412, anchors=121; every rg -Fn anchor matched`, rc 0. ≤3 worst anchors/file below (all available when a file has fewer than three).
- Fix → prune these redundant summaries or retain only the fresh-reader reason/constraint; keep the behavior/proof statements unchanged.

| file | count | ≤3 worst anchors (`line: exact bytes`) |
|---|---:|---|
| `Fvtrace/Answers/Delta.lean` | 54 | 263: <code>`(s.withOverrides extra).eff1`.</code>; 284: <code>`Scenario.eff` read on `eff1`.</code>; 58: <code>The ids of the `result` facts.</code> |
| `Fvtrace/Answers/Fast.lean` | 3 | 13: <code>`Counts.of` over need triples (id, status, must verify).</code>; 19: <code>A claim's envelope member: each need's status + kind read once, its excluded pairs once; a</code>; 37: <code>The same answers from indexes + memos.</code> |
| `Fvtrace/Answers/Forest.lean` | 32 | 209: <code>Writes `v k` at each key's position.</code>; 315: <code>What every step of the walk reads.</code>; 159: <code>A claim's counts at the node (the base's where the node changed none).</code> |
| `Fvtrace/Answers.lean` | 18 | 33: <code>The trace's lookups.</code>; 79: <code>A claim's envelope member.</code>; 112: <code>The `Scenario` functions themselves.</code> |
| `Fvtrace/Check.lean` | 7 | 47: <code>Lint rule ids a waiver may name.</code>; 337: <code>Every broken rule instance, in rule order, read through `L`.</code>; 341: <code>Every broken rule instance, in rule order (the trace read through its indexes).</code> |
| `Fvtrace/Decode.lean` | 11 | 155: <code>An absent array reads as empty.</code>; 394: <code>D-json: why an input of `size` bytes is refused.</code>; 415: <code>D-json: at most 16 MiB.</code> |
| `Fvtrace/Digest.lean` | 1 | 30: <code>Lowercase hex, two characters per byte.</code> |
| `Fvtrace/Engine.lean` | 36 | 93: <code>The effective status every judgment reads.</code>; 447: <code>`parseWith` on the trace's own lookups.</code>; 192: <code>The stronger of two statuses (the first on a tie).</code> |
| `Fvtrace/Index.lean` | 12 | 70: <code>How many positions carry key `k`.</code>; 74: <code>The first position whose key is `k`.</code>; 61: <code>Where the run of key `k` starts (or would start).</code> |
| `Fvtrace/Json.lean` | 16 | 44: <code>Byte offset into the input.</code>; 363: <code>D-canon: sorted keys, no insignificant whitespace.</code>; 366: <code>The two-space indented form, appended to `acc`.</code> |
| `Fvtrace/Lint.lean` | 6 | 22: <code>Whether claim `c` needs a fact of kind `k`.</code>; 37: <code>Every role warning, in claim order then rule order, read through `L`.</code>; 46: <code>Every role warning, in claim order then rule order (the trace read through its indexes).</code> |
| `Fvtrace/Lookups.lean` | 17 | 63: <code>The subject a fact id lives on, when it resolves.</code>; 66: <code>The original expressions over the trace's lists.</code>; 99: <code>The restated result of a claim that restates exactly one fact.</code> |
| `Fvtrace/Model.lean` | 12 | 269: <code>`proved` + `checked` = verified (contract § Model).</code>; 274: <code>Verified or a declared premise.</code>; 279: <code>The strongest status a route can reach.</code> |
| `Fvtrace/PTree.lean` | 1 | 32: <code>A depth whose `2 ^ d` positions cover `0 … n - 1`.</code> |
| `Fvtrace/Present.lean` | 7 | 20: <code>Quoted items with `; ` between them.</code>; 43: <code>The title of the experiment that creates `subject` (its `createdBy`).</code>; 73: <code>The experiment creates its subject (a prospective subject names it in `createdBy`).</code> |
| `Fvtrace/Args.lean` | 3 | 11: <code>Flags taking a value (`--project DIR`).</code>; 13: <code>Flags without a value (`--json`).</code>; 15: <code>Allowed positional counts.</code> |
| `Fvtrace/Assets.lean` | 1 | 10: <code>JSON Schema of the trace format, printed by `fvtrace schema`.</code> |
| `Fvtrace/Cli.lean` | 20 | 107: <code>Usage error: message + usage on stderr, exit 2.</code>; 201: <code>Flags every command that works on a trace accepts.</code>; 549: <code>`eval` also takes `--details ITEM` + `--complete`.</code> |
| `Fvtrace/Evaluate.lean` | 12 | 163: <code>The one-click what-ifs from this scenario (`actionsWith` on its fast answers).</code>; 201: <code>The envelope's `trace` member: the review digest + the review state.</code>; 208: <code>An item's lists (`kernel.md` V-details), the item resolved by its first match.</code> |
| `Fvtrace/Export.lean` | 14 | 34: <code>`import { a, b } from "./m.js";` ↦ `(["a", "b"], "m")`.</code>; 119: <code>Bytes of a lowercase hex string.</code>; 144: <code>The engine `lake build` compiled to WebAssembly: base64(gzip(module)).</code> |
| `Fvtrace/Receipt/Basic.lean` | 3 | 14: <code>Fact or exclusion id.</code>; 41: <code>`bindings.find? (·.id == id)` in O(log n).</code>; 45: <code>The review state for a given content digest (contract § Review).</code> |
| `Fvtrace/Receipt.lean` | 7 | 79: <code>Cached digests keyed by resolved path + size + modification time.</code>; 161: <code>Pins every fact + exclusion that carries evidence; returns the new trace + problems.</code>; 196: <code>Records a review of the current content, dated today (local date).</code> |
| `Fvtrace/Render.lean` | 3 | 12: <code>Lowercase hex of `n`, at least two digits.</code>; 16: <code>Bidirectional formatting characters: U+061C, U+200E–U+200F, U+202A–U+202E, U+2066–U+2069.</code>; 21: <code>C0 controls, DEL, C1 controls + bidirectional formatting as `\u{xx}`; the rest unchanged.</code> |
| `Fvtrace/Replay.lean` | 14 | 27: <code>`none` = killed at the deadline.</code>; 29: <code>SHA-256 of standard output, lowercase hex.</code>; 121: <code>What a run does to its replay's notice.</code> |
| `Fvtrace/Request.lean` | 4 | 13: <code>A what-if, optionally an action to expand from it, optionally an item whose details to answer</code>; 40: <code>An item whose details a request asks for (`KIND:ID`).</code>; 49: <code>`experiment:E`, `claim:C` or `fact:F` (ids never hold a colon: D-id).</code> |
| `Fvtrace/Server.lean` | 11 | 26: <code>The user named the trace file (`--trace`).</code>; 45: <code>A response before transport.</code>; 137: <code>A problem in the GUI's words.</code> |
| `Fvtrace/Session.lean` | 14 | 16: <code>Why a trace cannot be evaluated.</code>; 80: <code>D-json: at most 16 MiB.</code>; 161: <code>The batch document (`kernel.md` V-complete).</code> |
| `Fvtrace/Snapshot.lean` | 6 | 126: <code>The page's start-up call: the engine, or the problem text.</code>; 130: <code>The page's request call: the next engine state + the answer's text.</code>; 79: <code>Decodes the snapshot once; the refusal = the `invalid` problem's text.</code> |
| `Fvtrace/Store.lean` | 8 | 60: <code>The trace a command reads (`pin` + `review` write it back).</code>; 62: <code>The project folder (real path): receipts are checked against it.</code>; 64: <code>The project's folder in the data folder (it may not exist yet).</code> |
| `FvtraceWasm/Binary.lean` | 4 | 129: <code>What the page's loader (`web/engine.js`) provides.</code>; 136: <code>What the page's loader uses, with its kind: the memory + six functions.</code>; 141: <code>Why the module breaks the link contract (empty = it keeps it).</code> |
| `FvtraceWasm/Build.lean` | 14 | 21: <code>The package folder: `tools/wasm.lock`, `tools/wasm/`, `c/page_engine.c`.</code>; 23: <code>Fetched inputs, generated C, objects + the module (`.lake/build/wasm`).</code>; 31: <code>base64(gzip(module)).</code> |
| `FvtraceWasm/Lock.lean` | 2 | 44: <code>The single entry named `name` (with key `key`, when given).</code>; 51: <code>The lock's platform key for an LLVM target triple (`System.Platform.target`).</code> |
| `TrustMain.lean` | 1 | 37: <code>Worklist closure: `expand c` = successors of `c`, `none` = stop at `c`.</code> |
| `lakefile.lean` | 2 | 31: <code>The Agent Skill `fvtrace skills install` writes (module `FvtraceSkill`), traced like the GUI.</code>; 80: <code>The page engine `fvtrace export --html` embeds (module `FvtraceEngine`).</code> |
| `Tests/Assets.lean` | 1 | 45: <code>The texts an exported page's "Licenses" section carries (`Export.licensesHtml`).</code> |
| `Tests/Check.lean` | 1 | 24: <code>`t` breaks exactly the listed (rule, path) instances.</code> |
| `Tests/Cli.lean` | 1 | 51: <code>A recording `start` (bound port = 40000 + call number), `[::1]` busy on its first try.</code> |
| `Tests/CliStore.lean` | 3 | 48: <code>The synthetic study as the project's trace.</code>; 76: <code>Evaluation commands: text + JSON projections of one envelope.</code>; 283: <code>check on files named directly (receipts against the current folder's project).</code> |
| `Tests/Decode.lean` | 1 | 8: <code>A minimal valid trace; `{FACT}` / `{CLAIM}` / `{EXTRA}` are replaced per case.</code> |
| `Tests/Details.lean` | 1 | 11: <code>An answer as (value, refusal), comparable.</code> |
| `Tests/Engine.lean` | 2 | 42: <code>Exclusions: X1 (assumed) relates O4 + O5 on S.</code>; 64: <code>Experiments: E1 checks O2; E2 (requires E1) asserts O4; E3 creates N + checks M1.</code> |
| `Tests/Evaluate.lean` | 1 | 21: <code>C1 conditional + C2 open on S; C3 sits on the prospective subject N.</code> |
| `Tests/Fields.lean` | 2 | 16: <code>Decodes `text`; a decode failure fails the named check and yields `none`.</code>; 24: <code>The (rule, path) of every violation `fvtrace check` lists for `text`.</code> |
| `Tests/Harness.lean` | 4 | 12: <code>Wall-clock (ms) per suite area, in run order.</code>; 30: <code>The record with this `id` in array `key` of an envelope.</code>; 38: <code>Runs `act` with stdout + stderr captured; returns (result, stdout, stderr).</code> |
| `Tests/Json.lean` | 1 | 22: <code>`n` objects nested under key `a`.</code> |
| `Tests/Receipt.lean` | 1 | 34: <code>EN1 (entailment of C1) + X1 (exclusion O4/O5) become verified, with receipts to pin.</code> |
| `Tests/Replay.lean` | 1 | 51: <code>`t` with fact `id`'s replay set to `r`.</code> |
| `Tests/Scale.lean` | 8 | 123: <code>The array at `key` of a JSON object (empty when absent).</code>; 129: <code>A string member of a JSON object (empty when absent).</code>; 30: <code>n claims, each needing F_i (statistical, assumed) + its entailment E_i (open, lean).</code> |
| `Tests/Server.lean` | 4 | 20: <code>A reply's body as text (bodies are UTF-8 bytes).</code>; 29: <code>A decided reply's JSON problem kind.</code>; 122: <code>`facts[id].receipt.current` of an envelope reply.</code> |
| `Tests/Snapshot.lean` | 2 | 31: <code>What `Session.envelope` prints for the same frozen inputs.</code>; 46: <code>The snapshot's own member list with `k` replaced (`none` drops it).</code> |
| `Tests/Wasm.lean` | 1 | 24: <code>A module with a custom section first (skipped), then imports + exports.</code> |
| `Tests.lean` | 1 | 72: <code>Every suite, in run order (`lake test`).</code> |

## Known findings met (not re-reported)

- F6 → `Fvtrace/Check.lean:199–203` success-only outcome explanation is also used for failure entries.
- F4 + F8 → `Fvtrace/Cli.lean:280–289` + `Fvtrace/Replay.lean:4–10,94–96` promise failing-run stderr tails more broadly than the kept/displayed result.
- F15 → `FvtraceWasm/Build.lean:99–109` promises no temporary after any failed write, but rename is outside its catch; `Tests/Wasm.lean:174–187` checks the callback-failure path alone.
- F19 + F20 → `Fvtrace/Server.lean:57,150–152` every-response fixed headers + each answer's view-header promises.
- F30 + F35 → `TrustMain.lean:9–15` Prop-valued claim + escape-hatch closure promises.
- F7 → `Tests/Schema.lean:7–8` schema/decoder agreement statement, within the known expressible-shape gaps.
- F58 (same class as F53 T2) → `Fvtrace/Receipt.lean:16–18` “Every artifact is read + hashed again” + `Fvtrace/Cli.lean:318–319` “Every command reads each evidence file by default” overstate the binding domain (`Receipt.bindings` only visits recorded-verified facts/exclusions; commands such as `verify` do not bind).

## Coverage + verification limits

- Scope inventory = 66 files, 879 lexical comment units (each `--` line / nested block), extracted with a string-aware scanner: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-38/comments.py` → `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-38/comments.json`; all comment text reviewed, not sampled. Code cross-check = described declarations, test bodies and relevant consumers; no full correctness review claimed.
- Six isolated FFI-free Lean witnesses were run on the frozen base: `needs`, `position`, `moves`, `server-outcome`, `leb`, `parallel`. Each compiled and reached its named contradictory assertion (rc 1). The anchor/count validator passed (rc 0). No full gate, build, suite, browser or server run; none required to establish the text defects.
- LSP probe on `Fvtrace/Model.lean` → `No LSP server available for file type: .lean`; source reads + interpreted witnesses used instead.
- Historical timing/size claims were not re-benchmarked. **Unconfirmed exact historical values**: the quarter-startup claim (`Fvtrace/Json.lean:109–111`), hour/minute estimates (`Fvtrace/Json.lean:170–172`, `Tests/Json.lean:147–148`, `Tests/Decode.lean:159–160`), 118 MB link (`lakefile.lean:91`), five delta builds at 43,949 facts (`Fvtrace/Answers/Delta.lean:576–578`), exact 29.5 s/load ≈26 + sub-second/load assertions (`Tests/Scale.lean:6–13`), interpreted 35 s (`Tests/Snapshot.lean:123`) + 3 s (`Tests.lean:52`). Looked in the target's `.agent/archive/` with bounded exact-number queries; `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-38/measurement-citations.txt` preserves the matches. The archive corroborates the 9,600-claim stack issue and af5a2f1's 101 s/>900 s baseline, not every listed number. These are coverage limits, not invented findings.
- Ruled-out lead: `Evaluate.actionsWith`'s “route's ceiling” is correct over its **closable** domain: the only fact/route-ceiling mismatch is must-verify + assumed-ceiling → tested; no non-violated fact there is closable. No finding.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:993–994` (earlier redirect pages' token-state claim): security → MAIN.

reviewer-38-DONE-1

