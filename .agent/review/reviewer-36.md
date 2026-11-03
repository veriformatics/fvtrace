# reviewer-36 — S-skill

Target = `48bc51d`; base = `/home/eturkes/Projects/fvtrace/.scratch/review-base`; lens = claim soundness + guarantee-vs-claim. Acceptance fixed before target read: assigned skill/docs/example/self-trace texts versus CLI, decoder/checker, Decisions + named Lean theorem/code. Verdicts below = 8/8 adjudicated; four minor text findings.

| row | target | verdict | basis |
|---|---|---|---|
| S-skill | SKILL.md (instructions vs CLI + rules) | reviewer-36-F1 | Embedded `skills show` byte-equal; 101-command isolated audit; command/flag ownership read against `Cli` + `Args`; pin-then-status workflow works. Review-staleness prose omits the notice exception. |
| S-skill | references/trace-format.md vs decoder + checker | reviewer-36-F2 | Whole document versus `Decode`, `Model`, `Check`, receipt manifests; route/status matrix + all must-verify kinds driven. Default-array prose is broader than the required-field notation + decoder. |
| S-skill | references/stance.md vs Decisions + engine | pass | Whole document; 30 route/status combinations + all 12 kinds; `stance.py` drives can/conditional/open/cannot, stale, reasoning refusal, derived violation + subject conflict. |
| S-skill | assets/example.trace.json | pass | `check --strict` rc 0; every claim starts open; exact structural equality with synthetic example after verified statuses → open + pin fields removed. |
| S-skill | self-trace claims + headlines vs theorems | pass | Every C1–C9 sentence read against named Spec statements, with the tool's checked-input domain; C2/C7 explicitly pending, C7 security routed below. Twelve named proofs + three receipt conjunctions typecheck; 12/12 statement fingerprints match. No self-trace headlines. |
| S-skill | self-trace facts: statements, verifiers, trusted base, why | reviewer-36-F4 | Every P/I/T/E fact + receipt read; 24 facts, no `why`; named statements/proofs exist; verifier version matches Lean 4.35.0; exact fingerprints match. T2 overstates which evidence files are read. |
| S-skill | synthetic example texts + project files | pass | Whole trace + both Lean files; `check --strict` rc 0; placeholders explicitly disclosed and both typecheck; C1/C2 wording = Decisions Examples, C3 restates its result; real C2 plan action → conditional. |
| S-skill | self-trace summary count | reviewer-36-F3 | Nine recorded claims = seven proof-backed + two pending; summary still says six proof-backed. |

## reviewer-36-F1 — minor — review-staleness statement omits replay notices

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/skill/fvtrace/SKILL.md:43`.
- Contract: Decisions Review + Evidence binding (a replay notice never changes review state); S-skill truthfulness.
- Anchor: `A change to the trace content after a review makes the review stale` (`rg -Fn` → line 43).
- Wrong: an ordinary `verify --run` can change `replay.failed` without invalidating review. The skill tells an agent that this change requires another review, contradicting the explicit exception.
- Source: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Receipt.lean:188-189` hashes `t.withoutNotices`; `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Model.lean:214` removes each `failed` notice.
- Red command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-36/red-review-notice.py` (rc 1).

```text
positive control: pin --replay rc=1, review rc=0, verify --run rc=1; notice exit 1 -> exit 2
trace content changed=True
review before=reviewed after=reviewed
digest unchanged=True
AssertionError: SKILL says a content change makes the review stale; replay-notice content changed but review stayed reviewed
```

- Fix: name replay notices beside formatting as exceptions; keep the intended notice-independent review implementation.

## reviewer-36-F2 — minor — absent-array default overclaims the decoder's domain

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/skill/fvtrace/references/trace-format.md:3`.
- Contract: assigned required/optional-field agreement with decoder + checker; kernel.md D-shape.
- Anchor: `Absent arrays mean empty; never write` (`rg -Fn` → line 3).
- Wrong: this unqualified default contradicts the document's own required-field notation. `subjects`, `questions`, `facts`, `claims`, claim `needs`, and replay `command` are required arrays, not absent-as-empty. Optional collection arrays alone default empty.
- Source: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Decode.lean:373-379` requires the four root arrays and defaults only experiments/exclusions/waivers; `:294` requires needs; `:233` requires command.
- Red command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-36/red-array-default.py` (rc 1).

```text
positive control: explicit questions=[] rc=0 (expected 0)
absent questions rc=1: missing-field missing field "questions"
AssertionError: trace-format says absent arrays mean empty; questions is required instead
```

- Fix: scope the opening default to optional arrays (the adjacent field notation is already correct).

## reviewer-36-F3 — minor — self-trace summary counts six proof-backed claims, actual seven

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/examples/fvtrace/trace.json:6`.
- Contract: S-skill numerical claims match artifact; Decisions Examples.
- Anchor: `Six claims rest on Lean proofs` (`rg -Fn` → line 6).
- Proof: `jq '.claims|length' /home/eturkes/Projects/fvtrace/.scratch/review-base/examples/fvtrace/trace.json` → `9`; C2 + C7 are pending; C1,C3,C4,C5,C6,C8,C9 have proved needs + entailments. Real `fvtrace eval` (own FVTRACE_HOME) agrees: seven `can`, two `open`; `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-36/self-eval.json` holds the output. Twelve referenced Prop statements + their proofs typecheck in `claims.lean`.
- Fix: six → seven (or remove the count).

## reviewer-36-F4 — minor — T2 says all evidence files are read, but only verified records bind

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/examples/fvtrace/trace.json:475`.
- Contract: S-skill fact texts match the code they name; Decisions Examples.
- Anchor: `Without --cached, fvtrace reads every evidence file again` (`rg -Fn` → line 475).
- Wrong: `Receipt.bindings` visits only recorded verified facts/exclusions. Evidence of an open, tested or assumed fact is not read during evaluation, even when previously pinned. The self-trace itself carries evidence on tested I2/T1/T2. C2's narrower verified-need claim is not disproved; this finding is T2's unrestricted read claim alone.
- Source: `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Receipt.lean:133-144` (`if f.status.verified`, `if x.status.verified`); native loading calls it at `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Session.lean:105`.
- Red command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-36/red-evidence-read.py` (rc 1; strace of native eval, two pinned artifacts, one proved + one open).

```text
positive control: verified evidence opens=1 (expected 1)
open-status evidence opens=0; fvtrace eval rc=0
AssertionError: T2 says every evidence file is read again; the open fact's pinned evidence was not opened
```

- Fix: restrict T2 to evidence of recorded verified facts/exclusions; re-pin the changed wording. Reading unused evidence is unnecessary.

## Register

- `/home/eturkes/Projects/fvtrace/.scratch/review-base/examples/fvtrace/trace.json:451,705,1023` — T1/E7/C7 security → MAIN.
- Named-entailment ownership: existing F9 covers the contract's universal-vs-named scope; not re-reported. Known plan prospective qualifier + schema surrogate/UInt32 gaps excluded per brief.

## Coverage

- All assigned texts read, not sampled: 43-line SKILL, 40-line stance, 32-line format; all three JSON documents; both synthetic Lean proof files; 24 self-trace facts + nine claims, every evidence statement/verifier/trust entry. Self-trace `headline` = 0; fact `why` = 0.
- Passed: embedded SKILL `cmp` rc 0; `check --strict` on self-trace, synthetic + skill asset rc 0 each; 101 CLI invocations in `audit.py` rc 0; `stance.py` rc 0; named proof + receipt-conjunction typecheck rc 0; both synthetic placeholder Lean files rc 0.
- `statements.py`: own reflink copy; each P1–P12's exact recorded `tools/statement.sh` invocation run under `nice -n 10`, incremental build only. All 12 commands rc 0; SHA-256 of each stdout equals its pinned `replay.output` (details in `statements.log`; raw dumps P1.statement … P12.statement). No independent-kernel replay run by this reviewer; MAIN baseline owns it. Natural-language ↔ Lean interpretation remains the receipt's declared trust boundary.
- P6/P7/P8 + C5/C6's well-formed-input hypotheses are implicit in the product-facing wording, not a new unrestricted raw-Scenario guarantee: `Session.checked` (`Session.lean:117-133`) rejects malformed native inputs; `Snapshot.decode` (`Snapshot.lean:61-64`) rejects malformed page inputs. This domain restriction was checked rather than reported as an omitted-precondition defect.
- LSP probe on real `.lean` file: no server available; source/compiled proof checks used instead.
- Browser interaction/exported-page compatibility not run in this slice; the real HTML export command succeeds, envelope/what-if/details/complete/actions driven natively. Full gate, mutation campaigns, remote/production changes: not run. Target untouched; changes confined to this deliverable + own scratch.

Work in progress: final CLI server smoke + cleanup + validator.
