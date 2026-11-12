# reviewer-3 — C-check @ 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| C-check | WF-* definitions vs kernel.md + Decisions | pass | Fifteen rule groups traced through `Spec/WellFormed.lean` + `Check.lean`; decoded-domain guards confirmed; 32 independent native WF cases pass. WF-path platform aspect routed below. |
| C-check | WF-path platform-boundary observation | n/a security → MAIN | `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Check.lean:17` security → MAIN. |
| C-check | lints + waivers vs kernel.md § Lints + Decisions | pass | `Lint.lean:22–47`: five contract predicates; claim→rule order; exact `(rule, claim)` first waiver; independent 65-case level×need-kind matrix + waiver/order probes pass. |
| C-check | wiring: binary → proved constants | pass | Main→Cli.check/Session.checked→`violationsWith (Lookups.fast t) t` = `violations t` by rfl; generated C call sites confirmed. Server/export/Snapshot reach it; live CLI + served reload probes pass; no shipped checker replacement attribute. |
| C-check | Model.lean (shapes, ceilings, kinds) | pass | Shapes/defaults + wire domains match § Model; exhaustive 12 kinds×5 routes×6 statuses, ceilings, verified/asserted, needs order + replay-notice traversal: independent probes pass. |
| C-check | unproved code (messages, order) | reviewer-3-F1 | Rule/path ordering + wrapper/waiver matching pass; failure-side WF-route diagnostic describes a success + recommends an illegal failure repair (red witness rc 1). |
| C-check | Tests/Check.lean (setup/teardown, asserts) | pass | Whole file + Harness + suite wiring read; fixture-local immutable updates, no side effects to undo, exact rule/path assertions; selected existing suite rerun 50/50, rc 0. |

## Scope

Fixed check set = table above + correctness asks in `.agent/review.md`; target = frozen `48bc51d`. Read-only target; witnesses/logs confined to `.scratch/review/reviewer-3/`. No mutation campaign/full gate.

## reviewer-3-F1 — minor — failure-side route diagnostic recommends an invalid repair

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Check.lean:203` (shared caller `:208–212`).
- Contract: kernel.md WF-outcome = failure values are `violated` alone; `CLAUDE.md` Authoring = an error states what happened + the fix. This row explicitly covers unproved messages.
- Defect: `outcomeRoutes` concatenates success + failure entries, then calls `disallowedOutcome` for both. For a failure entry that assumes a must-verify fact, its WF-route diagnostic says **a success** failed + advises **set a verified status**. A verified failure status is itself forbidden by WF-outcome. The same invocation prints contradictory repairs; following the first one keeps the trace invalid. Verdict computation/rejection remains correct.
- Exact anchor (`rg -Fn` matches `:203`): `a success cannot assume`.
- Red command on the base:

```sh
python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/failure-diagnostic.py
```

Output, rc **1**:

```text
Input: experiments[0].success = {"F":"checked"}; failure = {"F":"assumed"}
WF-route /experiments/0: outcome "F": a success cannot assume F: facts of kind result must be verified; set a verified status that its route allows, or leave F out
WF-outcome /experiments/0/failure: a failure sets violated alone
AssertionError: the failure-side WF-route diagnostic must describe the failure and must not advise a verified failure status; WF-outcome permits violated alone
```

- Proof files: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/failure-diagnostic.py` + `failure-diagnostic.log`; input `traces/failure-diagnostic.json`.
- Fix direction: preserve success/failure identity through `outcomeRoutes`; describe failure entries accurately + advise `violated` or omission for a failure. A neutral diagnostic with an applicable repair also satisfies the contract.
- Acceptance: red command → rc 0; existing Check suite + independent native WF cases remain green.

## WF definition audit

Source abbreviations: Lean implementation + `Spec/` + `Proofs/` paths resolve under `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/`; `Main.lean` + `lakefile.lean` at the base root; generated `ir/` under its `.lake/build/`. Every rule's theorem interface read; proof bodies left to kernel checking. `CheckAcceptsExactlyWellFormed` names `Check.violations`, not another checker. The equivalence alone does not establish this English↔Lean mapping.

| rule | verdict | definition ↔ contract / checker |
|---|---|---|
| WF-ids | pass | `Spec/WellFormed.lean:16`, `Model.lean` `Trace.allIds`, `Check.lean:61`: one namespace across the six record collections; analysis has no collection membership. |
| WF-refs | pass | `Spec/WellFormed.lean:19`, `Check.lean:106`: all question/subject/fact/claim/experiment references, creator, outcome keys, waiver claim + instantiation source; unresolved references remain errors even where another predicate is vacuous. |
| WF-subject | pass | `Spec/WellFormed.lean:36`, `Check.lean:136`: needsAll, both outcome sides + exclusion endpoints share owner subject; instantiation source differs. |
| WF-entail | pass | `Spec/WellFormed.lean:47`, `Check.lean:184`: entailment iff not restates; right kind, outside needs, exclusive claim owner; no entailment-kind need; restates = one result, exclusive restater. Id uniqueness closes the id-based ownership check. |
| WF-needs | pass | `Spec/WellFormed.lean:58`, `Check.lean:187`: nonempty + duplicate-free. |
| WF-route | pass | `Spec/WellFormed.lean:63`, `Check.lean:214`: every fact + success/failure status obeys Fact.allows; exclusions obey Route.allows; all six must-verify kinds reject assumed. F1 affects text alone. |
| WF-outcome | pass | `Spec/WellFormed.lean:72`, `Check.lean:227`: nonempty asserted success; violated-only failure; requires = earlier same-subject experiment, so prefix order enforces acyclicity. |
| WF-receipt | pass | `Spec/WellFormed.lean:79–89`, `Check.lean:236–251`: verified statuses require artifacts + all digests + verifier/statement/statementDigest. Nonempty strings + digest syntax belong to the decoded domain (`Decode.lean:250–258`); native empty-verifier case is rejected before WF. |
| WF-path | n/a security → MAIN | Segment/C0 checks + ordinary parent/absolute-path regression cases read/run; platform-boundary observation routed to MAIN, no security adjudication here. |
| WF-prospective | pass | `Spec/WellFormed.lean:99`, `Check.lean:275`: prospective iff creator present; creator on that subject; at least one existing subject; prospective facts open. |
| WF-variant | pass | `Spec/WellFormed.lean:107`, `Check.lean:287`: variant's subject prospective, target's subject existing; missing references rejected separately. |
| WF-exclusion | pass | `Spec/WellFormed.lean:113`, `Check.lean:299`: distinct endpoints; same-subject unordered pair unique. |
| WF-consistent | pass | `Spec/WellFormed.lean:121`, `Check.lean:312`: recorded asserted exclusion + two recorded asserted sides rejected; no receipt-current test substituted for recorded status. |
| WF-waiver | pass | `Spec/WellFormed.lean:127`, `Check.lean:318`: declared lint rule + unique `(rule, claim)`; claim resolution via WF-refs, nonempty reason via Decode.text. |
| WF-kind | pass | `Spec/WellFormed.lean:131`, `Check.lean:324`: instantiation iff source present; reference + cross-subject checks separate. |

## Wiring basis

- Native entry: `Main.lean:3–4` → `Cli.run:1129` → `runIn:1122` → dispatch `check:1105` → `Cli.check:293`; `:309–311` constructs `Lookups.fast t` + calls `Check.violationsWith L t`.
- Equality to theorem constant: `Check.lean:342` is definitionally the same expression. `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/wiring.lean` checks that equality by `rfl`, instantiates `checkAcceptsExactlyWellFormed` + `fast_eq_reference`; rc 0. `Proofs/Check.lean:384`, `Spec/WellFormed.lean:149–155`, `Proofs/Lookups.lean:266` interfaces agree.
- Evaluation/export: `Cli.load:558` / `exportCmd:880` → `Session.load:127` → `Session.checked:116–123` → identical checker expression. Server: `Cli.serveCmd` → `Server.answer:153–173` → `Session.checked` on each new trace-byte key; decoded checked trace is reused only on equal keys. Native probe drives valid→invalid→valid edits against one server.
- Page engine: `lakefile.lean:56–74` selects Snapshot's import closure; C bridge calls `fvtrace_snapshot_load` → `Snapshot.loadExport:128` → `Engine.load:80` → `decode:52–64` → `Check.violations t`. No alternative checker or shipped `implemented_by`/`csimp` replacement found.
- Generated C cross-check: `ir/Main.c:23` calls `lp_fvtrace_Fvtrace_Cli_run`; `ir/Fvtrace/Cli.c:6541–6543` and `Session.c:1994–1995` call `Lookups_fast` then `Check_violationsWith`; `Snapshot.c:1442` calls `Check_violations`. Compiler/runtime remain the declared trusted base.

## Commands + outcomes

Scratch root = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/`; every fvtrace subprocess explicitly sets its `home/` as FVTRACE_HOME. Base binary sha256 = `2f4f08ea11ee24cb1a06cfa77b1dba132197b87de6851dca4941a48923cb768a`.

| command | result |
|---|---|
| `(cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/home lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/probe.lean)` | rc 0; **735/735** model + lint checks; log `probe.log`. |
| `(cd /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/suite-root && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/home lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/check-suite.lean)` | rc 0; **50/50** existing Check checks; log `check-suite.log`. Its two fixture copies compare byte-equal to base (`cmp`, both rc 0). |
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/native-probe.py` | rc 0; **32/32** native WF cases; valid eval, invalid eval/export refusals + served valid→invalid→valid checker/cache boundary. Log `native-probe.log`. |
| `(cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/home lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/wiring.lean)` | rc 0; alias equality + theorem interfaces + lookup agreement; log `wiring.log`. |
| `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-3/failure-diagnostic.py` | rc 1; F1's deliberate red assertion, output above. |

Native probe's server PID 897000 terminated + waited (`rc=-15`); `pgrep -af '[f]vtrace serve'` afterward rc 1, no match. Full scratch tree removed; minimal byte-equal suite fixtures + scripts/logs retained as rerun inputs. No target edit/build/git action.

Limits: finite-domain probes supplement source review, not a proof of complete test coverage. Fresh full gate, mutation campaign, independent-kernel replay, browser/wasm runtime replay not run here. Proof bodies not audited. Lean LSP unavailable (`No LSP server available for file type: .lean`); direct source + Lean compiler + generated C used instead. No unconfirmed behavioral finding.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Check.lean:17` security → MAIN.

reviewer-3-DONE-1
