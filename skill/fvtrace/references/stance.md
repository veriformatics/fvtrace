# Statuses, routes and verdicts

## Status of a fact (what is true now)

| status | meaning | record it when |
|---|---|---|
| `proved` | a completed proof covers the fact | a Lean or refinement proof exists, named as an artifact and pinned |
| `checked` | a proved checker accepted the actual object | a verified checker ran on the actual data or code, its output pinned |
| `assumed` | a declared premise | a background condition (kinds `statistical`, `provenance`, `interpretation`, `release`, `spec-review`, `instantiation`) rests on judgment, convention or empirical support; never for a fact that must be verified |
| `tested` | tests pass, nothing proves it | unit tests, spot checks, simulations |
| `open` | nobody has established it | the default |
| `violated` | it is false as worded | a counterexample is established |

## Route of a fact (how it could be verified)

| route | ceiling | use for |
|---|---|---|
| `lean` | `proved` | mathematical and algorithmic statements a Lean proof can cover |
| `refinement` | `proved` | code proved to implement a specification |
| `runtime-checker` | `checked` | properties of the actual data or outputs that a proved checker can test |
| `human-ruling` | `assumed` (`tested` for a must-verify fact) | interpretation, study design, reviewer judgment |
| `empirical` | `assumed` (`tested` for a must-verify fact) | observations, measurements, statistical evidence |

A status above the route's ceiling is an error (`fvtrace check`). Must-verify kinds (`entailment`, `result`, `estimand`, `numerical`, `implementation`, `dataflow`) are never `assumed`, recorded or in an outcome: `fvtrace check` reports an error.

## Verdict of a claim (decided by fvtrace)

- **Fully supported**: every need, the entailment included, is verified with a current receipt.
- **Conditional**: no need is violated, every must-verify need is verified, and the other needs are verified or assumed; the claim is stated as "Assuming …: claim".
- **Pending verification**: some need is open, tested or stale.
- **Claim not possible**: a need is violated, the claim needs both sides of a verified or assumed exclusion, or a what-if conflicts.

An entailment that only a person can rule on keeps the claim at Pending verification: reword the claim to what a proof can cover, or split the judgment out as a separate, contestable background condition (never one that only restates "the conclusion follows"). A subject that a new experiment would create holds only `open` facts until the experiment runs.

## Experiment outcomes

- `checked` only via a proved checker on the actual data; `proved` only via a completed proof.
- Empirical support raises a background condition to `assumed` at most; it cannot raise a must-verify fact.
- A failure is an established counterexample (`violated`); an inconclusive outcome changes nothing (`{}`).
- An experiment that creates new data (`subject` = a prospective subject) supports claims about that data, never the existing analysis.
