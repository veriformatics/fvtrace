# IMPLEMENT — GUI (closed)

> I think its time to go straight into IMPLEMENT phase in the next session to sort some of these tough questions out with high fidelity

- [x] 90e4119 Rulings: open gaps + deferred rows → Decisions (AskUserQuestion: self-trace rebuild, must-verify kinds incl. calculation + code, check = error, waived checks → details, question bar kept, work rows name joint needs; I1 = universal premise)
- [x] 03fe522 U1 contract delta (kernel.md + units.md); consultant-2: 9 rows, G5 membership defect + 2 gaps fixed before code
- [x] fe75832 U2 must-verify kinds + verdict words + Conditional gate (G12, G13, G5 strengthened); examples rebuilt; mutation: 58 mutants, 0 unruled survivors (HARD-1 equivalent)
- [x] 08eaeef U3 `why` / `headline` / `restates` (format, WF + proofs, `restatedBy`, envelope, schema corpus); a6cbedb survivor tests (H2-1)
- [x] 971f42c U4 export bundler: multi-line imports
- [x] 9910c08 U5 GUI port (web/ = the ITERATE page on the engine); operator-2 visual QA 21 rows: V16 fixed, V20 rejected
- [x] 26e8c2a U6 docs + acceptance tests (README browser view, skill authoring, valid actions, mixed rows, self-trace verdicts)
- [x] 0d49b5c U7 prototype retired (tag `prototype-gui-iterate`) + rules upkeep
- [x] 87eb561 U8 closing review: reviewer-8 L-CORR, reviewer-9 L-CLAIM, reviewer-10 L-GAP, reviewer-11 L-HARD, reviewer-12 L-LAW, operator-2 L-UI, MAIN L-SEC; fixes 4185902 + 87eb561 (user rulings on the key note + suppose wording); re-review reviewer-13: 13/13 closed
- [x] U9 close: Decisions current, Tasks cleared, Phase → MAINTAIN (the commit that adds this file)

## Closing review (ledger `.agent/review.md`)

Lenses fixed before reading 19277b4..cfb0087. Findings: 2 major (CLAIM-3 = GAP-1 key vs exclusion cases; H2-1 Receipt survivor) + 14 minor, deduplicated across lenses; every row closed by a fix + one re-review round, rejected (V20) or registered (SEC-1, SEC-2, REG-1–3 → `.agent/deferred.md`). Mutation credit: U2 + U3 + U4 + U6 campaigns on the changed lines, survivors ruled (HARD-1, HARD-2) or killed (H2-1). Gates: full `tools/gate.sh` rc=0 at 87eb561 (73.6 s).
