---
paths:
  - "Fvtrace/Answers.lean"
  - "Fvtrace/Answers/**"
  - "Fvtrace/Lookups.lean"
  - "Fvtrace/Index.lean"
  - "Fvtrace/Engine.lean"
  - "Fvtrace/Check.lean"
  - "Fvtrace/Lint.lean"
  - "Fvtrace/Json.lean"
  - "Fvtrace/Present.lean"
  - "Fvtrace/Receipt.lean"
  - "Fvtrace/Receipt/Basic.lean"
  - "Fvtrace/Evaluate.lean"
  - "Fvtrace/Session.lean"
  - "Fvtrace/Snapshot.lean"
  - "Fvtrace/Cli.lean"
  - "Fvtrace/Export.lean"
  - "Fvtrace/Replay.lean"
  - "Fvtrace/Spec/Fast.lean"
  - "Fvtrace/Proofs/Answers.lean"
  - "Fvtrace/Proofs/Closure.lean"
  - "Fvtrace/Proofs/Forest.lean"
  - "Fvtrace/Proofs/Index.lean"
  - "Fvtrace/Proofs/Lookups.lean"
  - "Fvtrace/Proofs/Positions.lean"
  - "Fvtrace/Proofs/Json.lean"
  - "tools/scale.mjs"
  - "tools/scale.sh"
  - "tools/compare.sh"
---

# Fast paths (`.agent/contracts/kernel.md` § Performance)

- The binary answers through indexes + memos (`Answers.fast`, `Lookups.fast`, `Json.sortMembers`), each proved equal to the plain definitions the other claims are about: `Spec.AnswersAgree` (every scenario), `Spec.LookupsAgree` (every trace), `Spec.SortMembersAgree`. A change to a fast path or to a `Scenario` / `Check` definition it mirrors keeps those proofs; the self-trace cites them (C9: P10–P12), so its receipts re-pin with the proof files (`examples.md`).
- Cost traps (each measured): a `def` that returns a closure after `let`s compiles to full arity, so the let-bound index is rebuilt on every call → carry the index in a structure (`Receipt.BindingIndex`) or pass it in; `Claim.needsAll` appends on every call → once per claim (`ClaimMemo.needs`, `planOf`); a forest experiment's closure reads its parent links (`Ctx.closureWith`); a walk from a blank array of marks costs O(n) per call, so it serves single requests + experiments outside the forest alone (per experiment in the experiments shape it was n² per scenario); no closure is kept for all experiments (the chain third of prereqs held 40 M positions).
- Proof statements that a rewrite must match name pair members by projection (`fun x => … x.1 …`): a pattern lambda (`fun (k, st) => …`) elaborates to an auxiliary matcher, and `rw` fails to match it across definitions.
- Evidence for a change here, in its commit body: `bash tools/compare.sh <binary before> .lake/build/bin/fvtrace` = 0 differing outputs + 0 timeouts (probe `compare` plants a difference + a timeout); `bash tools/scale.sh --assert` on an idle host = the F5 bounds (graded shapes ≤ 60 s at the 16 MiB cap, ≤ 2.5× per doubling; probe `scale` plants each breach). Supplemental shapes report output bytes beside time: time that grows faster than the output is a scan beside it (P-bound).
