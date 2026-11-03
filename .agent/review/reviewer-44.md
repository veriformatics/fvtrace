# reviewer-44 — F-model at 48bc51d

| row | target | verdict | basis |
|---|---|---|---|
| F-model | Trace model + FV stance | pass | `probe-model.py model`: 30 route × status cases + model-field relationships; ceilings, all six statuses, verbatim text/headline/why/trusts/evidence. |
| F-model | Only background conditions may be assumed | finding F6 (known) | `probe-model.py must`: 24 must-verify refusals; all 6 premise kinds allowed; 12 empirical/human must-verify ceilings = tested. Failure-side advice meets existing F6; enforcement passes. |
| F-model | Claim state + verdict words + Conditional + Entailment | pass | `probe-model.py claims`: exhaustive 80-case valid status product + 24 per-kind gate cases; all 4 verdict words + conditional sentence; 8 malformed entailment/restates shapes; single-result exception + stale rewording. |
| F-model | Subjects + Exclusions | pass | `probe-model.py subjects`: creator+prerequisite closure lights 3 prospective siblings only; 5 cross-subject/reuse refusals; 5 exclusion statuses × 3 conflicts; verified-only derivation, recorded contradictions, stale relation, unrelated subject isolation. |
| F-model | Results + lints | pass | `probe-model.py lints`: all 5 levels / 8 missing-role warnings; strict fails; adding roles removes warnings; explicit reasoned waivers pass and remain visible; absent/empty reasons refused. |
| F-model | Where FV pays + latent | pass | `probe-model.py work`: exact unlock/gates sets + ranking; zero-unlock rows retained, violated/unused/empirical-ceiling facts excluded; blockers separate; `latent` under “Overlooked directions”. |
| F-model | Experiments + outcome honesty | pass | `probe-model.py experiments`: exact 7-row ranking/counts, failures + prerequisite closure + join, result-contingent CLI text, dry/wet; route/outcome/empirical ceilings + empty failure. Receipt issuers’ scientific honesty = declared trust boundary, not dynamically confirmed. |
| F-model | Plans | pass | `probe-model.py plans`: 3 independent exhaustive oracles / 58 distinct closed candidates; state before ordinal cost; prerequisite closure + no conflict; all result branches; 20/21 relevant boundary, alternatives/premises/uncovered + coverage wording. |
| F-model | Intent (overall) | pass | `probe-model.py intent`: no-FV analysis stays Pending verification; questions/gaps/work/latent exposed; future conditional names remaining premise + what-if/provisional; queries preserve bytes; sign-off covers universal premises, adds no verification. Model/CLI scope; GUI = F-gui. |

## Scope + method

Frozen target = `/home/eturkes/Projects/fvtrace/.scratch/review-base` (`48bc51d`). Check set = F-model rows above; Decisions clauses quoted with each probe. Real binary = target `.lake/build/bin/fvtrace`; each run uses `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-44/home`. Primary tree + target stay read-only except this deliverable; probes + evidence confined to reviewer scratch. Known findings F1–F52 referenced rather than re-reported.

## Reproduction + result

```sh
uv run --no-project python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-44/probe-model.py
```

Final run: rc **0**, `17/17 checks passed`; all 9 table rows adjudicated, **0 new findings**, known **F6** met. Rows can run separately: script argument `model`, `must`, `claims`, `subjects`, `lints`, `work`, `experiments`, `plans`, `intent`.

Evidence root = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-44/`:

- `probe-model.py` = trace generator + assertions + independent plan oracle.
- `all-output.txt` = final summary; `results.json` = 17 checks, quoted contract words, outcome + detail.
- `traces/*.json` = actual inputs; `logs/*.json` = exact argv, cwd, `FVTRACE_HOME`, rc, stdout + stderr for each captured invocation (448 distinct records incl setup + exploratory inputs).
- `project/witness.txt` = explicitly artificial receipt artifact. `pin` supplies current receipt digests so model probes test statuses rather than accidentally testing stale receipts. This fixture is **not** scientific verification.
- Base binary sha256 = `2f4f08ea11ee24cb1a06cfa77b1dba132197b87de6851dca4941a48923cb768a`.

## Decisions → behavioral probes

Paths below resolve under the evidence root. Decisions anchors resolve under `/home/eturkes/Projects/fvtrace/.scratch/review-base/`.

### Trace model + FV stance

Contract `.agent/spec.md:32–33`:

> `questions → claims → facts + subjects + experiments + exclusions + waivers + review`
>
> `proved` needs `lean` | `refinement`, `checked` needs `runtime-checker`, the rest top out at `assumed`, or `tested` for a must-verify kind
>
> `assumed` = declared premise ⇒ claim only in conditional form. `tested` | `open` = gaps. `violated` ⇒ claim cannot be made as written.

`model`: `route-*.json` covers 5 routes × all 6 statuses. Correct routes retain their recorded/effective status and ceiling; other verified-route pairs fail `WF-route`. A claim with verified reasoning follows its sole other fact: proved/checked → can; assumed → conditional; tested/open → open; violated → cannot. `model-fields.json` carries question/subject links + exact text, headline, why, trusts, evidence; evaluation preserves each. Experiments, exclusions, waivers + review are exercised below.

### Only background conditions may be assumed

Contract `.agent/spec.md:34`:

> entailment (Reasoning), result, estimand (Measurement), numerical (Calculation), implementation, dataflow (Data flow) never hold `assumed`: recorded or in an experiment outcome = `fvtrace check` error, in a what-if = rejected.
>
> Assumable kinds = statistical, provenance, interpretation, release, spec-review, instantiation.

`must`: `must-<kind>-{recorded,success,failure,whatif}.json` = 24 refusals. Recorded/success/failure inputs fail check (`WF-route`; failures also `WF-outcome`). What-ifs exit 2 naming the must-verify assumption. All 6 premise kinds permit assumed in recorded/outcome/what-if positions; instantiation names a source on another subject. All 6 must-verify kinds × empirical/human-ruling have ceiling tested, not assumed. Conditional gating for every kind is also exercised in `claims` (24 cases); `Fvtrace/Engine.lean:116–127` independently shows the unconditional `restsOn` gate before Conditional.

### Claim state + Conditional + Entailment

Contract `.agent/spec.md:35–36,38`:

> `cannot` (a need violated, incl. derived; needs both sides of an exclusion; or a conflicting scenario) > `can` (every need verified) > `conditional` (every must-verify need verified, the rest assumed) > `open`
>
> Fully supported (can) / Conditional (conditional) / Pending verification (open) / Claim not possible (cannot)
>
> A claim that restates one checked result needs no separate reasoning fact
>
> every claim but a restating one names one entailment fact … counted as a need; unverified, it holds the claim at Pending verification at best.

`claims`: `state-table.json` under 80 combinations (4 result statuses × 4 reasoning statuses × 5 premise statuses) checks state precedence, exact verified/premises/gaps/blockers lists, labels + four CLI verdict words. Conditional text contains the exact premise and claim sentence. `conditional-kind-*.json` independently tests each of the 6 must-verify kinds at open/tested/verified/violated: only verified permits Conditional over an assumed premise. `entail-*.json`: 8 malformed entailment/restates shapes rejected; empirical/human reasoning remains open at tested. `restates.json`: valid checked result passes strict without entailment; checked/tested/open/violated follow the expected states; rewording the restated claim stales its result and returns open. Universal-premise sign-off is exercised under Intent; substantive-vs-universal premise meanings remain a human review judgment, not a text classifier.

### Subjects + Exclusions

Contract `.agent/spec.md:41–42`:

> an experiment's outcomes touch only its subject's facts ⇒ a new-data experiment lights sibling claims, never existing ones; cross-subject reuse = an explicit instantiation fact.
>
> only a verified exclusion derives a violation (from a verified side)
>
> a recorded contradiction (asserted exclusion + both sides asserted) = `fvtrace check` error; a what-if asserting both sides ⇒ every claim on that subject reads Claim not possible (`conflicting what-if`); a claim needing both sides ⇒ cannot.

`subjects`: `subjects.json` has an existing claim + 3 prospective siblings, explicit instantiation, creator + its own prerequisite. Follow-up closure = `Prepare, Create, Follow`; all 3 siblings become can, existing claim's evaluated object stays equal, and each sibling retains its creator qualifier. Five invalid cross-subject/reuse shapes fail. `exclusion-*.json` exercises 5 relation statuses × 3 both-asserted what-ifs: every same-subject claim, including an independent one, becomes cannot with conflicting-what-if label for an asserted relation; another subject stays unchanged. Only current checked/proved relations + a verified source derive the partner's violation (with exact witness). An assumed source alone derives nothing. Asserted relation + both needs makes intrinsic cannot. Three recorded contradictions fail `WF-consistent`; rewording a checked exclusion makes it stale and stops derivation.

### Results + lints

Contract `.agent/spec.md:43`:

> `fvtrace check` warns per claim level (estimand, descriptive, inferential, causal, release) on missing roles, suppressed only by a recorded waiver with reason.

`lints`: all 5 levels, all 8 applicable role warnings. Regular check permits warnings, strict fails. Adding each missing role removes its warning. Recorded waivers with non-empty reasons suppress strict failure; the evaluated lint retains the exact waiver reason. Missing/empty reasons are refused. The natural-language truth that a result describes the observed pattern is not inferred from fixture prose; it is part of review/receipt interpretation.

### Where FV pays + latent

Contract `.agent/spec.md:44`:

> per closable fact (not violated): claims it gates + claims verifying it alone unlocks, ranked by unlocks; violated facts list apart as blockers (reword or new data). `latent` claims = overlooked directions.

`work`: `work.json` checks exact order `P, R1, OtherPremise, R2`, exact gates/unlocks, zero-unlock rows retained, violated/unused facts excluded, and empirical must-verify facts at open/tested excluded because neither can rise above tested's strength. Blocker V lists only C5, separately. CLI `claims` prints latent C4 under `Overlooked directions`.

### Experiments + outcome honesty

Contract `.agent/spec.md:45–46`:

> `kind` `dry` | `wet`, `effort` hours < days < weeks < months, `success` (asserting statuses only) + `failure` (`violated` only) replayed as what-ifs … closed over `requires` + the creator of a prospective subject
>
> `lights` (claims raised into can | conditional), `clears` (cannot → open), `breaks` (failure → cannot); ranked lights > clears > cheaper.
>
> A success touching a `result` fact reads "if this result is observed".
>
> empirical support → `assumed` at most for a background condition, nothing for a must-verify fact (no success outcome reaches it; record `tested`); failure = established counterexample, inconclusive → `{}`.

`experiments`: `experiment-rank.json` checks 7-row ordering (2 lights before cheaper 1-light rows; 1-light hours/days/weeks/months; 0-light/1-clear before 0/0), exact lights/clears/breaks, and failure outcomes. Text explicitly says `If it succeeds and the result is observed:`; an outcome without a result says `If it succeeds:`. `experiment-requires.json` checks preview closure; `experiment-no-weaken.json` checks an assumed success leaves an already checked premise checked. Prospective creator closure is checked in `subjects`. Dry/wet both valid. Empirical/human background outcomes accept assumed, reject checked/proved. All 6 statuses in an empirical result success are refused: no outcome closes that must-verify fact. Failure values other than violated fail; empty failure is valid. Empty/unasserted success and self/forward prerequisites fail.

### Plans

Contract `.agent/spec.md:47`:

> a coherent experiment set (one subject, prerequisite-closed, no conflict) reaching the highest state the suggestions allow, cheapest by ordinal effort among those (exact search; above 20 relevant experiments the result is `tooLarge`, no plan claimed); alternatives per fact + remaining premises listed; labelled coverage, never scientific priority.

`plans`: `plan-{full,conditional-only,bundle-only}.json` checked against an independent Python powerset oracle: 58 distinct closed candidate sets across the 3 traces. Oracle derives join statuses, coherence, state, then ordinal effort cost and id tie-break directly from the contract. Highest can beats cheaper conditional; weeks beat months once states tie; prerequisite closure retained; cheap conflicting suggestion + unrelated experiment excluded. Conditional plan lists P as its remaining premise and exposes every need's alternatives; text names coverage. `plan-no-improvement.json` retains current premises, gaps, uncovered needs + textual guidance. Conflicting current what-if → inconsistent, no members. 20 relevant suggestions → exact planned E00; 21 → tooLarge without state or members; 21 total/20 relevant still plans. No separate re-review of known F11 (`plan`'s prospective text label) is claimed here; label correctness is recorded already under C-cli/Review.

### Intent (overall)

Contract `.agent/spec.md:5`:

> a claim can only be made if it is formally verified
>
> where no formal verification work has been performed yet, this tool can identify where such work can be applied, and if verified, what resultant claims can be made
>
> navigate what their scientific questions are, what gaps that need filling in order to answer those questions, and help ensure nothing is overstated
>
> directions and associated relationships that a user might have overlooked or understated

`intent`: `intent.json` begins with no verified fact. Both claims stay Pending verification; question, all verification gaps, work rows and latent direction remain available. A plan for the main claim shows Conditional, not can, and P stays named as a premise. Applying that plan through a success action is an explicit what-if + provisional; all model queries leave input bytes unchanged, returning to recorded leaves both claims open. Review sign-off names honest records, working instruments + correct labels once, yet does not raise either claim's state. This exercises the model/CLI path; GUI presentation belongs to F-gui.

## Known finding F6 — reference only

No new id. `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Check.lean:203` anchor `a success cannot assume` matches. Existing ledger F6 covers a failure-side must-verify assumption receiving success-side advice. Own corroboration:

```sh
FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-44/home \
/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/bin/fvtrace check --json \
  --trace /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-44/traces/must-result-failure.json \
  --project /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-44/project
```

rc 1, errors include:

```text
WF-route: outcome "F": a success cannot assume F: facts of kind result must be verified; set a verified status that its route allows, or leave F out
WF-outcome: a failure sets violated alone
```

## Coverage limits + register

- **Unconfirmed semantic claims:** whether a receipt's checker is itself proved and ran on the actual data; whether a claimed proof is complete; whether a failure is an established counterexample rather than inconclusive; whether an authored premise is substantive/background rather than a disguised conclusion or universal premise. Looked at `.agent/spec.md:36,46`, kernel.md receipt/Outcome guarantees trust boundary, route/outcome refusal behavior, and `review` sign-off. The issuer's formal/natural-language interpretation is deliberately accepted, not verified by these CLI probes. Artificial receipts test routing/binding only.
- Finite acceptance probes + source gate inspection, not a new universal proof. Exhaustive scopes = the stated 30 route/status and 80 valid claim-status matrices + each small plan fixture's powerset; other traces are adversarial representatives. No browser, performance timing, full gate, mutation campaign, proof replay, private project, or remote service run. No server started.
- Probe-development failures were fixture/assertion errors, not product defects: envelope blockers/uncovered are id strings; missing waiver reason fails decoding before pin; a fact id Q collided with question Q; open and tested have equal strength; uncovered guidance is generic rather than checker-specific. Corrected harness then rerun as one set: 17/17 pass.
- Outside-contract register: none. No target edits; no Git command; deliverable + reviewer scratch only, unstaged.

reviewer-44-DONE-1
