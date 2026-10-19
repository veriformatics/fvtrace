# Statuses, routes and verdicts

## Status of a fact (what is true now)

| status | meaning | record it when |
|---|---|---|
| `proved` | a completed proof covers the fact | a Lean or refinement proof exists, named as an artifact and pinned |
| `checked` | a proved checker accepted the actual object | a verified checker ran on the actual data or code, its output pinned |
| `assumed` | a declared premise | the fact rests on judgment, convention or empirical support |
| `tested` | tests pass, nothing proves it | unit tests, spot checks, simulations |
| `open` | nobody has established it | the default |
| `violated` | it is false as worded | a counterexample is established |

## Route of a fact (how it could be verified)

| route | ceiling | use for |
|---|---|---|
| `lean` | `proved` | mathematical and algorithmic statements a Lean proof can cover |
| `refinement` | `proved` | code proved to implement a specification |
| `runtime-checker` | `checked` | properties of the actual data or outputs that a proved checker can test |
| `human-ruling` | `assumed` | interpretation, study design, reviewer judgment |
| `empirical` | `assumed` | observations, measurements, statistical evidence |

A status above the route's ceiling is an error (`fvtrace check`).

## Verdict of a claim (decided by fvtrace)

- **Can claim**: every need, the entailment included, is verified with a current receipt.
- **On assumption**: no need is violated and every need is verified or assumed; the claim is stated as "Assuming …: claim".
- **Not yet**: some need is open, tested or stale.
- **Cannot claim**: a need is violated, the claim needs both sides of an exclusion, or a what-if conflicts.

An entailment ruled by a person caps the claim at On assumption. A subject that a new experiment would create holds only `open` facts until the experiment runs.

## Experiment outcomes

- `checked` only via a proved checker on the actual data; `proved` only via a completed proof.
- Empirical support raises a fact to `assumed` at most.
- A failure is an established counterexample (`violated`); an inconclusive outcome changes nothing (`{}`).
- An experiment that creates new data (`subject` = a prospective subject) supports claims about that data, never the existing analysis.
