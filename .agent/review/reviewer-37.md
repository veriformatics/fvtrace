# reviewer-37 — S-spec

Target = `48bc51d` (`.scratch/review-base`); lens = claim soundness + guarantee-vs-claim. Fixed set: every Spec docstring/comment vs its statement; kernel proved/tested labels + theorem/test citations vs evidence; units evidence cells vs named artifacts + commits.

| row | target | verdict | basis |
|---|---|---|---|
| S-spec | Spec/WellFormed.lean docstrings vs statements | pass | Every comment/docstring + all 21 definitions read; WF references are factored between rules as stated; both closing equivalences audited (`trust` rc 0, 26 claims). |
| S-spec | Spec/Engine.lean docstrings vs statements | reviewer-37-F1 | Every comment/docstring + all 21 definitions read against their referenced definitions; G4a/G4b summaries omit material domains; remaining summaries agree. |
| S-spec | Spec/Fast.lean + Spec/Version.lean | pass | All comments + 4 claims read; record fields/sort tie order/version definition matched; all four claims present in the 26-claim audit. |
| S-spec | kernel.md proved labels → theorems | unknown | unknown |
| S-spec | kernel.md tested labels → tests | unknown | unknown |
| S-spec | units.md evidence cells | unknown | unknown |

## Findings

### reviewer-37-F1 — minor — proof summaries omit material theorem domains

- Locations at `48bc51d`: `Fvtrace/Spec/Engine.lean:158,166`; `.agent/contracts/kernel.md:95,107,178`.
- Contract: S-spec / `CLAUDE.md` Engineering adversarial review — natural-language claims say no more than their formal statements; theorem hypotheses remain visible.
- Exact anchors (each matched with `rg -Fn` against the base):
  - Spec: `a plan holds its prerequisites`; `no prerequisite-closed set of experiments`.
  - kernel: `**proved**: complete, duplicate-free, sorted`; `**Proved** G4: P closed`; `G7 subject isolation: ω or an outcome`.
- Contradiction: `Spec.PlanSound` (`Spec/Engine.lean:161`) assumes `WellFormed s.trace`; `PlanOptimal` (`:171`) also assumes `c ∈ s.trace.claims`. Neither G4 docstring states these domains. The kernel's G4 summary drops both; its work summary calls duplicate-freedom proved without `WellFormed` although `Spec.WorkExact` (`:148`) states that hypothesis; G7 drops `WellFormed` + claim membership from `Spec.SubjectIsolation` (`:100`). Other nearby summaries state their domains explicitly (G5, G13; WorkExact's own docstring).
- Materiality witness: `.scratch/review/reviewer-37/domain-witness.lean` (pure, no target edits). Command:
  ```sh
  (cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-37/domain-witness.lean)
  ```
  rc 1; output includes:
  ```text
  duplicate work ids: ["F", "F"]
  dangling prerequisite plan: Fvtrace.PlanResult.planned
  ... ["E"] ... (Fvtrace.State.can) ...
  declared closure holds missing prerequisite: false
  WF trace, external claim plan: Fvtrace.PlanResult.noImprovement ...
  external claim state: Fvtrace.State.open → Fvtrace.State.can
  uncaught exception: unqualified duplicate-free work summary fails without WF
  ```
  The external trace's `WellFormed` is itself kernel-checked in the witness via `checkAcceptsExactlyWellFormed`; the external claim is proved absent from its claims. Thus even WF alone does not supply G4b's missing membership domain.
- Scope: wording defect, **not** a claim that the CLI evaluates malformed traces. The proved statements remain sound; the summaries expand their quantification.
- Fix: name WF + claim membership where required, or declare the shared domain explicitly and preserve the exceptions that really cover arbitrary scenarios.

## Register
