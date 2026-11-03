# reviewer-45 — F-cli

Target = `48bc51d` (`.scratch/review-base`); check set = F spec-fit × scoped Decisions entries. Writes = this validator input + `.scratch/review/reviewer-45/`; base read-only.

| row | target | verdict | basis |
|---|---|---|---|
| F-cli | Product (data folder, writes, export refusal, named limits, no service mention) | pass | `probe.py product` rc 0: data-dir init + 10 command paths, four direct/symlink export refusals, before/after project manifests equal, explicit trace write isolated; computational caps named; service scan 0 matches. |
| F-cli | Evidence binding + replay + notices + log | F4, F5, F8, F17 (known) | `probe.py evidence` + `replay` rc 0: six stale cases; digest display-text boundary; opt-in, argv/cwd, output + exit notices, failed pin, review/verdict invariance, success clearing, log after trace deletion; F4 reproduced. F5/F8/F17 = accepted findings, not re-reported. |
| F-cli | Review | F11 (known) | `probe.py review` rc 0: draft/reviewed/stale, formatting invariant, draft/stale provisional, reviewed what-if separately labelled; `plan C3` reproduces F11 (creator qualifier dropped). |
| F-cli | Headline + exact statement | pass | `probe.py headline` rc 0: claims/plan print C2's exact text, not headline; claims/plan/eval JSON keeps both; review prints headline ceiling + honest records/working instruments/correct labels. |
| F-cli | Agent instructions + skill | pass | `probe.py skill` rc 0: embedded show + all four installed files equal source; reinstall stable. `Cli.skillDirs` routes claude/agents to user-level dirs (code-only, as brief requires). Skill delegates draft/check/review correctly; no LLM call path. |
| F-cli | Examples | pass | `probe.py examples` rc 0: both strict checks; self C1/C3–C6/C8/C9 can, C2/C7 open; synthetic C1 conditional, C2/C3 open, C2 plan E1+E4→conditional. Synthetic wording/outcomes match scoped Decisions. |
| F-cli | Trace format + Batch path | pass | `probe.py batch` rc 0: schema equals source, fvtrace=1; recorded/what-if/action complete envelopes + all 14 item payloads exactly match individual calls; details+complete refused. Schema conformance gaps remain known F7 (outside this transport row). |
| F-cli | What-if refusals | pass | `probe.py refusals` rc 0: all four exact Decision messages × six command forms = 24 rc-2 refusals; first stderr line uses `fvtrace: `, stdout empty. |

## Findings

Pending.

## Register

None.
