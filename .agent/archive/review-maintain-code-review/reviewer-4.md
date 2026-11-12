# reviewer-4 — C-check / Correctness

Target = `48bc51da577813891fc189be52d70e6ced24f951`, frozen `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Check set fixed by brief before target read. Read-only target; findings require contract + reproduced witness.

| row | target | verdict | basis |
|---|---|---|---|
| C-check | WF-* definitions vs kernel.md + Decisions | pass | All 15 rule predicates + checker bodies matched clause by clause; 17 native cases exercise every WF group + decode-first receipt text validation. Entailment uniqueness scopes to the named fact (investigated no-orphans reading retired; Register). |
| C-check | lints + waivers vs kernel.md § Lints + Decisions | pass | Five level/role predicates match; 160 level × role-subset cases with/without waivers pass; exact (rule, claim), first-match reason + duplicate-waiver rejection checked. CLI strict failure tests unwaived warnings alone. |
| C-check | wiring: binary → proved constants | pass | Main → Cli.run/runIn/dispatch/check → violationsWith (Lookups.fast t) t = violations t by rfl; Session.checked, export + server reuse it; Snapshot.decode calls violations directly. Equality theorem signatures + identity examples compile; no source compiler replacements found. |
| C-check | Model.lean (shapes, ceilings, kinds) | pass | All constructors, fields, defaults, names, lists, needsAll + replay helpers read; finite probes cover all 360 kind × route × status cases and all 60 fact ceilings. |
| C-check | unproved code (messages, order) | pass | Rule codes, paths, messages + list traversal/order read with consumers; waiver metadata/strict handling + multi-violation rule order tested. Replay helpers preserve record/order data; nonempty receipt strings delegated to decoder text validation and native-tested. |
| C-check | Tests/Check.lean (setup/teardown, asserts) | pass | Whole test module + Harness read; immutable fixture transforms, exact expected diagnostics and waiver assertions fit contract. Existing Check area executed inside 1252/1252 passing checks; read-only fixture setup, no teardown resources. |

## Findings

None.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Check.lean:18` — security → MAIN (`Artifact.pathSafe`).
- `/home/eturkes/Projects/fvtrace/.scratch/review-base/.agent/contracts/kernel.md:33` — ownership wording ambiguity: `used by exactly one claim` can sound like all entailment-kind facts need owners. Code permits unused entailment facts (`Check.lean:184-185`). Investigated lead reviewer-4-F1 retired: “the claim's needs” scopes the named entailment's constraints; Decisions imposes entailment per non-restating claim, not a no-orphans rule. Shared named entailments are rejected. Witness retained as an intentionally failing exploratory expectation, not a regression requirement.

## Coverage / checks

Result = **6/6 rows adjudicated; all pass; no blocking findings**. Security remains MAIN's scope. Proof bodies were outside this review; theorem statements + the human-facing predicates were the target.

### Predicate audit

- WF-ids/refs/subject/entail/needs/route/outcome/receipt/path/prospective/variant/exclusion/consistent/waiver/kind: every definition in `Spec/WellFormed.lean`, corresponding checker functions + `Rule.all`/dispatch read. Unresolved references defer to WF-refs; per-collection membership + same-subject constraints jointly close that domain.
- WF-receipt's `isSome` tests rely on decoded `verifier`/`statement` passing `Decode.text` (`Decode.lean:73-80,255-256`); empty values fail before WF. The native probe confirms both diagnostics, with no checker phase.
- WF-entail's owning-claim uniqueness + restated-result uniqueness checked against their intended per-claim scope. The broader no-orphans interpretation was investigated, then retired (Register); no code/spec change recommended for it.
- All five lint rules, applicable levels, requested kinds + waiver matching read against § Lints. Typed role-subset probes use an independent contract table, not `Lint.rules` as the expected-value source.

### Wiring audit

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Main.lean:3` → `Cli.run:1129` → `runIn:1122` → `dispatch:1098` → `check:293`; `readTarget:232` → `Session.read`; decoded branch `Cli.lean:308-311` constructs `Lookups.fast t` and calls `Check.violationsWith` + `Lint.warningsWith`.
- `Check.violationsWith (Lookups.fast t) t = Check.violations t` checked by an elaborated `rfl` example. The fast/reference equality and both checker guarantee constants also type-check in the probe. `Spec.CheckAcceptsExactlyWellFormed` + `Spec.CheckViolationsSound` name this same `Check.violations` constant.
- `Session.checked:117-123` uses the same fast checker; `Session.load:126` calls it before binding. `Cli.exportCmd:895` uses `Session.load`; `Server.answer:165` uses `Session.checked` for fresh bytes and reuses only a previously checked trace on a byte-key hit. `Snapshot.decode:64` calls `Check.violations` directly; `Engine.load`/exported load wrappers reach it.
- Compiler-replacement search over `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace` for `csimp|implemented_by`: no matches, rc 1. Scratch positive control: one matching line, rc 0. Standard-library/runtime behavior stays in the stated trusted base.

### Executed checks

1. Slice + finite-domain probes (rc **0**):
   ```sh
   (cd /tmp && FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4/home LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4/check-slice.lean)
   ```
   Output: `1252/1252 checks passed`. Existing `Tests.Check.tests`; all 360 kind × route × status cases; all 60 fact ceilings; all 160 level × five-role-subset cases with/without waivers; selected WF/path cases; snapshot accepted/rejected guard cases; elaborated constant/equality examples. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4/check-slice.log`.
2. Native binary (rc **0**):
   ```sh
   uv run --no-project --no-config python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4/binary-check.py /home/eturkes/Projects/fvtrace/.scratch/review-base /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4
   ```
   17 checker cases cover every WF group + decode-before-WF receipt text validation. Strict lint: unwaived rc 1; matching waiver rc 0 + reason retained. Invalid must-verify assumption: `eval`, HTML export + bundle export all rc 1, with no export output created. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4/binary-check.log`.
3. Retired exploratory expectation (rc **1**, **not** a finding or credited regression): `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4/orphan-entailment.py`. Shared-E control rejects with exactly two WF-entail errors; unused E + a valid restating claim passes strict check (rc 0). The script's demanded unused-E rejection fails because that broader condition is not established by Decisions. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4/orphan-entailment.log`.

### Limits / hygiene

- Whole assigned source files + `Tests/Check.lean` read; relevant CLI caller branches, `Lookups`, Session/Snapshot/Server/Export and proof signatures followed. Other CLI behavior, codec correctness, fast-index implementation proofs, security + other review lenses remain their assigned slices.
- No full gate, full test suite, fresh build, mutation campaign, independent-kernel replay, live server or browser run in this review. No claims that those passed here. Native checker/eval/export paths above were driven; the server wiring was checked statically, not launched.
- Lean LSP request on `Check.lean` returned `No LSP server available for file type: .lean`; source inspection + Lean elaboration supplied code intelligence.
- Frozen base + primary source files untouched. No git mutation. Native runs use the prescribed scratch `FVTRACE_HOME`. Private repository copy removed after the probes; scripts, logs + input fixtures retained under `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-4/`. No server/background process started. No instruction/Intent edit.

reviewer-4-DONE-1
