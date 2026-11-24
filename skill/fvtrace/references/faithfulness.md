# Does the proof say what the fact says?

A proof covers its own formal statement, not the sentence of the fact. The same is true for a
proved checker: its proof covers the checker's specification. The Lean kernel checks the proof.
Nothing checks that the statement means the sentence. A statement can be wrong, weaker than the
sentence, or empty. Its proof still passes. fvTrace trusts this reading. The user's review is the
only other check. Thus you must try to break each statement before you record a fact
`proved` or `checked`.

## When to run the checks

- Before you record a fact `proved` or `checked`.
- For each entailment fact: its statement must start from the facts that the claim needs and
  reach the exact text of the claim.
- When the evidence of a verified fact changes, before you pin it again.
- When you read a trace or a bundle that another person made.

## How to read

- Assume that the author of the proof has your blind spots. Often an AI agent wrote the proof.
  That agent can be you. A wrong statement reads as smoothly as a correct one.
- Read the statement itself. Do not trust its name, its comment, the evidence summary or the fact
  text.
- Read the full statement. In Lean, `#check @Name` shows every hypothesis, also the hypotheses that
  come from `variable` lines and the instance arguments. `#check` does not show the value of a
  definition. Read the value of each definition that the statement uses (`#print Name`).
- For a checker, read the theorem that says what its acceptance proves. Do not rely on its
  documentation.
- If your agent tool can start a separate agent with a fresh context, give that agent this file,
  the fact and the statement. Do not give it your conversation. Ask it to break the statement.

## The checks

| Check | It passes when |
|---|---|
| Object | The statement is about the thing that the fact names. |
| Conventions | Its definitions use the conventions of the analysis. |
| Edge cases | It decides degenerate inputs as the analysis does. |
| Default values | No default value outside the intended domain makes it true. |
| Hypotheses | Each condition that the data or code must meet is a fact of its own. |
| Not empty | Its hypotheses can hold, and it says more than what holds for every input. |
| Generality | It covers the case that the analysis is in. |
| Trusted base | Each axiom and tool that the proof relies on is known and named. |
| Actual object | The proof or the checker is about the data and code that the analysis used. |

### Object

The fact names one thing. The statement must be about that thing. For example, the fact is
about the mean marker level of the recorded cohort, but the theorem is about the median. Or the
theorem is about the mean of any list of numbers, and nothing connects that list to the cohort. A
theorem about an ideal model (real numbers, an infinite population) is not about the code that
ran.

### Conventions

Compare each definition with the one that the analysis uses:

- a variance that divides by n or by n − 1;
- the base of a logarithm;
- a one-sided or a two-sided test;
- units and scales;
- indices that start at 0 or at 1;
- rounding.

### Edge cases

Find out what the statement says for degenerate inputs. Compare it with the analysis. Check an
empty group, one sample, ties, zero counts, missing values, and all values equal.

### Default values

Outside its domain, a function can give a default value. A theorem can then be true only because
of that value. In Lean:

- On natural numbers, `3 - 5 = 0` and `5 / 0 = 0`.
- On integers, `-7 / 2 = -4`, not `-3`, and `7 / 0 = 0`.
- In Mathlib, on real numbers, `x / 0 = 0`, `Real.log 0 = 0`, `Real.log (-x) = Real.log x`,
  `√x = 0` when `x ≤ 0`, and `sSup ∅ = 0`.
- Floating-point numbers (`Float`) are not real numbers: `0.1 + 0.2 == 0.3` is false,
  `0.0 / 0.0` is NaN and `1.0 / 0.0` is infinity.

A proof about real numbers says nothing about floating-point code. Another fact must connect them.

### Hypotheses

List each hypothesis and each instance argument of the statement. For each one, ask what it
requires of the actual data or code:

- A condition that the analysis must meet (for example, independent samples, or no missing values)
  is a fact of its own in the `needs` of each claim that relies on the proof. Record its honest
  status: verified, or `assumed` if it is a background condition.
- A hypothesis must never assume what the fact asserts. For example, a theorem that "the estimate
  is unbiased if its expected error is zero" proves nothing about the estimate.
- A hypothesis that you cannot connect to the analysis is a gap. Tell the user.

### Not empty

Look for hypotheses that cannot hold together, for a stand-in such as `True` where a condition
should be, and for a statement that holds for every input, whatever the analysis did. An
unfinished proof (`sorry`) proves nothing.

Work out one or two small cases by hand, where you know the answer. For example, the mean of 1, 2
and 3 is 2. Use a group of one sample and an empty group too. Prove each case as a theorem about
the same definitions. If a case fails, or you cannot state it, the statement does not say what the
fact says.

You write into the project folder only when the user asks. If the user agrees, put the cases in a
file in the project. Add that file to the evidence as an artifact with the role `sanity check`. Run
`fvtrace pin` again. If not, run the cases with `lake env lean --stdin`. Give them with the plain
reading.

### Generality

The statement must cover the case of the analysis. A theorem for a fixed number of samples does not
cover other numbers. A theorem about integers does not cover measurements with decimals.

### Trusted base

In Lean, `#print axioms Name` lists the axioms that the proof relies on:

- `propext`, `Classical.choice` and `Quot.sound` are the standard axioms of Lean.
- `sorryAx` means that the proof is not finished. The fact is not proved.
- Each other axiom adds trust. For example, `native_decide` adds an axiom whose name contains
  `native_decide`. The proof then trusts the Lean compiler too. Name it in the `trusts` of the
  fact. Tell the user.

For other verifiers, name each tool that the verification relies on in `trusts`.

### Actual object

- A checker must have run on the pinned file of the data or the code, at the version that the
  analysis used.
- A refinement proof must be about the code that ran: the same file, at the same version. Its
  specification must say what the fact says.

## What to do with the result

- Every check passes: record the status that the evidence supports. A check that cannot fail for
  this fact does not apply.
- A check fails: keep the fact `open`, or `tested` if tests pass. Tell the user which check failed
  and why. With the agreement of the user, reword the fact and its claims to what the statement
  says.
- You cannot decide a check: do not record the status. Tell the user what stopped you.

## A plain reading for the review

The user's review vouches that the claims and facts match the study. A reviewer who does not read
Lean cannot check a formal statement. Thus, write a plain reading of the statement of each verified
fact:

- what the statement says, hypothesis by hypothesis, in the words of the analysis;
- the result of each check, and each default value or edge case that the statement reaches;
- the small cases that you proved, with their answers.

Put the reading in the `summary` of the fact's evidence, after the name of the proof or the
checker. `fvtrace serve` and an exported page show the summary in the details of the fact, as one
paragraph. Write sentences, not a list. Give the reading to the user at hand-over too. A change to
the summary after the review makes the review stale.

## A replay that shows the statement

A replay can print the statement, the definitions that it uses and its axioms. Then a later
change to one of them makes `fvtrace verify --run` fail. In a Lake project, on a system with `sh`,
the command can be:

```json
["sh", "-c", "lake build MyAnalysis.Result >&2 && printf '%s\\n' 'import MyAnalysis.Result' '#check @MyAnalysis.mean_rise' '#print MyAnalysis.meanLevel' '#print axioms MyAnalysis.mean_rise' | lake env lean --stdin"]
```

- The command builds the module first. `lean` reads the last build of a module that it imports.
  Without the build, the replay can thus show an old statement. The build writes to standard
  error. `fvtrace` pins only the standard output.
- `#check` shows the name of a definition, not its value. Add one `#print` line for each
  definition of the analysis that the statement uses, also the definitions that those definitions
  use. A definition that the replay does not print can change. The replay then still passes.

Read the output before you record `proved`. `fvtrace pin --replay` pins the output that the command
prints, also when the output shows `sorryAx`. The command exits with 0 when a proof uses `sorry`.
Write a replay only when the user asks for one.
