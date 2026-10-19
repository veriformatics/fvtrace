---
name: fvtrace
description: Drafts and maintains an fvTrace trace for a scientific analysis (its questions, the claims it wants to make, the facts each claim needs, how each fact could be formally verified, and experiments that could fill gaps), then runs the fvtrace command to check the trace and show which claims can and cannot be made. Use when the user asks what their analysis can or cannot claim, where formal verification would pay off, which experiments would strengthen a claim, or to set up fvTrace for a project folder.
license: Apache-2.0 WITH LLVM-exception
compatibility: Needs the fvtrace command (fvtrace --version) and a shell in the project folder.
metadata:
  fvtrace: "0.1.0"
---

# fvTrace

fvTrace takes one stance: a claim can be made only when every fact it needs is formally verified (proved, or checked by a proved checker on the actual data). Your job is to write down, honestly, what the user's analysis claims and what each claim rests on. The `fvtrace` command decides every verdict; you never do.

## Ground rules

- Never write into the project folder. fvTrace keeps its own files in its data folder; `fvtrace path` prints where the trace lives.
- Never record `proved` or `checked` unless the evidence exists and `fvtrace pin` has pinned it. A test that passes is `tested`; a judgment by a person is `assumed` at most (route `human-ruling`); a measurement or statistical result is `assumed` at most (route `empirical`).
- Quote claims and facts as the user would publish them. One fact = one statement that is true or false.
- Never run `fvtrace review`: the review records the user's own sign-off. Until the user reviews, every verdict is provisional; say so.
- Report what `fvtrace` printed. Do not restate a verdict in stronger words.

## Procedure

1. Check the tool: `fvtrace --version`. In the project folder, run `fvtrace path`. If that file does not exist, run `fvtrace init` (it writes a valid starter trace).
2. Read the analysis: code, notebooks, data descriptions, manuscript drafts, figures. Collect the scientific questions and the sentences the user wants to claim. Ask the user when the intended claims are unclear.
3. Draft the trace in the file that `fvtrace path` printed. Follow `references/trace-format.md`; `assets/example.trace.json` shows every part. For each claim:
   - list the facts it needs (`needs`): what the data are, what the code computes, which statistical or numerical conditions hold, how the result is interpreted;
   - add one entailment fact (`entailment`, kind `entailment`): "these needs entail the claim as worded";
   - give each fact the route by which it could be verified and its honest status now (`references/stance.md`).
4. Add experiments that could raise open facts: `dry` (existing data, code or proofs) or `wet` (new samples, bench work), with effort, method, resources, success and failure outcomes, and a caveat. A success asserts only what the experiment can establish; a failure sets facts `violated`.
5. Validate: `fvtrace check`. Fix every error. For each warning, add the missing kind of fact or a waiver with the reason the user gives.
6. When evidence files exist (a Lean proof, a checker log), add them as artifacts and run `fvtrace pin`. Never edit `sha256` or `statementDigest` by hand.
7. Show the result: `fvtrace claims`, `fvtrace gaps` (facts whose verification pays most), `fvtrace experiments`, `fvtrace plan CLAIM`. For a browser view, run `fvtrace serve` and give the user the printed link. Add `--whatif FACT=STATUS,...` to explore a supposition; say that it is a supposition.
8. Hand over: tell the user the trace is a draft, list the facts you were unsure about, and ask them to check it and run `fvtrace review --reviewer "Their Name"`.

## When the trace changes

Run `fvtrace check` after every edit. A reworded fact or claim, or a changed evidence file, makes its receipt stale; run `fvtrace pin` again only when the new evidence is real. Any edit after a review makes the review stale; the user reviews again.
