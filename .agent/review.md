# Review ledger (IMPLEMENT — whole product)

Rows needing a ruling by someone other than the author (L-SEC rows: MAIN alone, per the IMPLEMENT body); a row closes with its ruling + evidence. Status: `open` · `accepted` (fix required, named) · `rejected` (with reason) · `register` (outside the contract, recorded) · `closed` (fix landed + re-reviewed).

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
| CORR-F1 | U3 | L-CORR | D-json 16 MiB cap absent (reviewer-1, red on 9884777). | accepted (fix 3d885af: `decodeTraceWithin`, code `size`) | A 16 MiB + 1 byte trace → rc 1 `size`; 16 MiB passes the cap. |
| CORR-F2 = GAP-F2 | U4 | L-CORR, L-GAP | WF-outcome rejects an acyclic forward `requires`; contract allowed any acyclic graph. | accepted (fix 3d885af: contract states the shipped rule — `requires` = earlier experiments; 38bb2e9: SKILL.md + README say "list an experiment after the experiments that it requires") | Contract, Spec `WellFormed`, checker + user docs state one rule; the error names it. |
| CORR-F3 = CLAIM-F4 = GAP-F1 | U4 | L-CORR, L-CLAIM, L-GAP | Size + mtime cache certified changed evidence as current (blocker). | accepted (fix 3d885af: every command reads evidence again; `--cached` opt-in, disclosed; 38bb2e9: Receipt docstring, contract, self-trace C2 + tested fact T2) | Same-size, mtime-restored edit → claim not Can claim, `check --strict` rc 1 without `--cached`; docs + C2 state the `--cached` limit. |
| CORR-F4 | U5 | L-CORR | A what-if that changes a new-data claim lost its `what-if` qualifier. | accepted (fix 3d885af: `changedByWhatif`) | Tests/Engine "a what-if that changes a new-data claim says so". |
| CORR-F5 = GAP-F3 | U3 | L-CORR, L-GAP | `decode (encode t) ≠ t`: outcome maps kept source key order. | accepted (fix 3d885af: decode sorts outcome keys) | Tests/Decode outcome-order round trip. |
| CORR-F6 | U9 | L-CORR | `export --bundle` through a link into the project wrote there. | accepted (fix 3d885af: existing destinations resolve their own links) | Link into the project as `DIR` → rc 2, nothing written. |
| CORR-F7 | U6 | L-CORR | Unforeseen I/O errors exited 1 (invalid-trace code). | accepted (fix 3d885af: `runIn` catch → exit 2 + message) | An unreadable/unwritable path → rc 2. |
| CORR-F8 | U7 | L-CORR | A folder in place of an artifact → HTTP 500 with no JSON body. | accepted (fix 3d885af: receipt reason `not a file`; server `{problem: io}` 500) | Folder artifact → stale receipt `not a file`; server answers a JSON problem. |
| CORR-F9 | U8 | L-CORR | GUI hash parser dropped malformed + merged duplicate what-if entries silently. | accepted (fix 38bb2e9: the linked spec goes to the engine as written; its problem is shown; exported page names an unknown action) | e2e: `#whatif=O2=checked,O2=violated` → error "O2 appears twice in the what-if", recorded view; export `#action=suppose:ZZ` → notice. |
| CORR-F10 | U5 | L-CORR | Envelope dropped a fact's `instantiates`. | accepted (fix 38bb2e9: emitted + decoded + shown in the inspector) | Tests/Engine "the envelope keeps a fact's instantiation source". |
| CORR-F11 | U5 | L-CORR | Prerequisite closure doubled per step (2^26 list, 527 MB). | accepted (fix 3d885af: `eraseDups` per step; proof updated) | reviewer-1's probe runs in 0.01 s / 13 MB; Tests/Engine 24-experiment case. |
| CORR-F12 | U2 | L-CORR | Contract wire schema differed from the shipped decoder + envelope. | accepted (fix 38bb2e9: contract documents the shipped review + envelope fields) | Contract field lists = `Decode` review keys + `Evaluate` emitted keys. |
| CORR-F13 | U8 | L-CORR | Exported Restore switch under another action selected `suppose:F` instead of restoring. | accepted (fix 38bb2e9: a switch undoes only its own action; a fact supposed by another action reads disabled until Reset) | e2e export: after `success:E1`, O2's switch is `aria-disabled`; Reset restores. |
| CLAIM-F1 | U5 | L-CLAIM | PlanOptimal docstring promised optimality for every no-plan result. | accepted (fix 38bb2e9: `noImprovement` only; `tooLarge`/`inconsistent` claim none) | Docstring = Prop scope. |
| CLAIM-F2 = GAP-F7 | U5 | L-CLAIM, L-GAP | Contract G3 labelled preview counts proved; no theorem covered them. | accepted (fix 38bb2e9: new proved claim G3b `CountsPartition` — lights + clears + lowers = moves; breaks labelled a tested definition) | `fvtrace-trust` lists `CountsPartition` proved; contract G3 text = `MovesExact` + `CountsPartition`. |
| CLAIM-F3 | U11 | L-CLAIM | README + self-trace P1/P2/C1 stated the decoded-trace theorem as a command-level guarantee. | accepted (fix 3d885af README; 38bb2e9: P1/P2/C1 + Spec docstrings scoped to the decoded-trace well-formedness check; re-pinned) | Texts name the decoded-trace check; decoding stated as tested. |
| CLAIM-F5 | U6/U8 | L-CLAIM | "No fact is left to verify." on empty work while assumptions remain. | accepted (fix 38bb2e9: "No fact that a claim needs can rise further: each one is violated or has the strongest status that its route allows.") | CLI + GUI empty-work text = the `work` definition (closable ∧ gating). |
| CLAIM-F6 | U8 | L-CLAIM | GUI "no claim changes on its own" when success lowered a claim. | accepted (fix 38bb2e9: engine `lowers`; GUI lists it; fallback "No claim changes if it succeeds" only when lights = clears = lowers = 0, which G3b makes ⇔ no move) | Tests/Engine lowering case (0, 0, 1); `CountsPartition` proved. |
| CLAIM-F7 | U8 | L-CLAIM | Experiment inspector showed the declared outcome as the resulting status. | accepted (fix 38bb2e9: engine `raises` = the overrides a success applies; inspector + "Experiments that raise it" read it) | Tests/Engine "weaker successes raise nothing", "raises = the facts a success lifts". |
| CLAIM-F8 | U11/U12 | L-CLAIM | README, stance.md, self-trace P5 dropped the exclusion's own asserted condition. | accepted (fix 38bb2e9: verified-or-assumed exclusion stated; derivation + contradiction cases separated) | Texts match `CannotExplained`, `BothSidesCannot`, `derivations`, `active`. |
| CLAIM-F9 = GAP-F6 | U6/U12 | L-CLAIM, L-GAP | "Writes into the project only with `--trace`" omitted `FVTRACE_HOME` inside it. | accepted (fix 6a157b8 + 38bb2e9: README, Store docstring, Decisions name every user-directed write; `export` refuses the project) | Every write path into the project is named where the guarantee is stated. |
| CLAIM-F10 | U12 | L-CLAIM | README export example wrote inside the project (refused). | accepted (fix 38bb2e9: `../claims.html`; destinations must lie outside the project) | README commands succeed from the project folder. |
| CLAIM-F11 | U10 | L-CLAIM | SKILL.md: "any edit" stales a review; formatting-only edits do not. | accepted (fix 38bb2e9: canonical content changes only) | SKILL.md = `Receipt.reviewDigest` semantics. |
| CLAIM-R1 = CORR-R1 = GAP-F5 | U2 | L-CLAIM, L-CORR, L-GAP | Contract named a `fvtrace about` command that does not exist. | accepted (fix 38bb2e9: contract names the README section as the disclosure surface) | No reference to `fvtrace about` remains. |
| GAP-F4 | U5/U6 | L-GAP | Contract witnesses R2-P2b (no-op test), R2-C1, R1-P5 joint, `plan --json` parity, acceptance cases (result-gated plan, new-data preview, state-then-cost), R2-E2 alternatives missing. | accepted (fix 38bb2e9: Tests/Engine `witnessTests`, Tests/CliStore R1-P5 + plan parity) | Each case asserts its contract behavior; mutation credit (Engine, Evaluate, Cli campaigns) shows the tests kill mutants of that code. |
| GAP-F8 | U1 | L-GAP | Trust audit skipped any spec def named like an equation lemma (`eq_987654`). | accepted (fix 38bb2e9: name filter removed — claims = `defnInfo` of type `Prop`; generated equation lemmas are theorems) | Audit lists 21 claims, 0 findings; probe plants `def eq_987654` → "eq_987654: no proof". |
| GAP-F9 | U1 | L-GAP | Probes trust-axiom/escape-hatch/vacuous never reached the audit (Proofs.lean lacks `import Fvtrace.Spec`; build errors hidden). | accepted (fix 38bb2e9: probes prepend the import; `trust_build` prints build errors) | `tools/gate-probe.sh trust` → all four trust probes fire. |
| LAW-F1 | all | L-LAW | No per-unit tier + contract declaration for U6/U7/U9/U10. | accepted (fix 38bb2e9: `.agent/contracts/units.md`) | Every unit row names tier, contract, evidence. |
| LAW-F2 | U3–U11 | L-LAW | Tested Server/Session/Export (+ final-code Json, Decode, Render, Cli, Store, Evaluate, Engine) lack red or mutation credit. | open | Mutation campaign on the final code per tested file (`.scratch/mutation/`), every survivor ruled by L-HARD. |
| LAW-F3 | U1 | L-LAW | Fast gate omitted tools/c-analyze/vendor from its skipped list; parallel stages printed no time. | accepted (fix 3d885af list; 38bb2e9: per-stage seconds) | `fast-gate.sh` prints each stage `rc=N <s>s` + the full skipped list. |
| LAW-F4 | U1 | L-LAW | lean.md `[[input_file]]`; ops.md stage inventory missing examples/c-analyze/vendor + clang. | accepted (fix 38bb2e9) | Rules = `lakefile.lean` targets + `tools/gate.sh` stages. |
| LAW-F5 | — | L-LAW | spec cited the pre-amend U6 SHA; stale QA + U12 rows. | accepted (fix 7703e60) | Tasks cite reachable SHAs (`git merge-base --is-ancestor`). |
| LAW-F6 | U1 | L-LAW | Renovate's tools.lock matcher extracted nothing (`^` = file start). | accepted (fix 3d885af: `(?:^\|\n)`; tests/renovate) | tests/renovate extracts actionlint, betterleaks, zizmor. |
| LAW-F7 | U6/U5 | L-LAW | Dead `readTrace`, `claimsOf`, `workKey`. | accepted (fix 3d885af: removed) | No definition without a caller. |
| LAW-F8 | U3 | L-LAW | lean.md said `partial` only in IO shells; JSON printers are `partial`. | accepted (fix 3d885af: rule scope = outside proof closures, enforced by `fvtrace-trust`) | Rule text = the audit's check. |
| LAW-R1 | — | L-LAW | Untracked `prototype/gui/fixture` copy left for migrator-1. | accepted (removed after migrator-1-DONE-1) | `prototype/` absent. |
| LAW-R2 | U1 | L-LAW | Suites printed no slowest tests. | accepted (fix 38bb2e9: timed areas, three slowest in the summary) | `lake test` + TestPure print `(slowest: …)`. |
| SEC-1 | U6/U7 | L-SEC | Printed JSON wrote DEL + C1 raw. | accepted (fix 3d885af) | Tests/Json printed vs digest form. |
| SEC-2 | U9 | L-SEC | Bundle copy read whole files into memory. | accepted (fix 3d885af: 1 MiB streaming) | Tests/Export bundle bytes equal. |
| SEC-3 | U5 | L-SEC | Plan search at the ruled limit: 72 s + 282 MB per claim (20 experiments), multiplied per envelope. | register (user-ruled limit; `.agent/deferred.md`) | Deferred row's acceptance check. |
| SEC-4 | U10 | L-SEC | Reinstall through a linked skill folder deleted the target's files. | accepted (fix 3d885af: refused) | Tests/Cli "the link's target keeps its files". |
| SEC-5 | U6 | L-SEC | Bidirectional formatting characters reached the terminal raw. | accepted (fix 38bb2e9; red recorded) | Tests/Check + Tests/Json bidi cases. |
| SEC-6 | U6/U9 | L-SEC | Temporary-file writes followed a link planted at `<file>.fvtrace-tmp`. | accepted (fix 38bb2e9: `replaceFile`, `O_EXCL`; red recorded) | Tests/Cli `writeTests`. |
| SEC-7 | U11 | L-SEC | Self-trace T1 overstated serve's access rule; E7 named Lean statements for tested code. | accepted (fix 38bb2e9) | T1 = `Server.decide`; E7 names the browser rules it trusts. |
