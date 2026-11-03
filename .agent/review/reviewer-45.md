# reviewer-45 — F-cli

Target = `48bc51d` (`.scratch/review-base`); check set = F spec-fit × scoped Decisions entries. Writes = this validator input + `.scratch/review/reviewer-45/`; base read-only.

| row | target | verdict | basis |
|---|---|---|---|
| F-cli | Product (data folder, writes, export refusal, named limits, no service mention) | F12 (known) | `probe.py product` rc 0: data-dir init + 10 command paths, four direct/symlink export refusals, before/after project manifests equal, explicit trace write isolated; computational caps named; service scan 0 matches. |
| F-cli | Evidence binding + replay + notices + log | F4, F5, F8, F17 (known) | `probe.py evidence` + `replay` rc 0: six stale cases; digest display-text boundary; opt-in, argv/cwd, output + exit notices, failed pin, review/verdict invariance, success clearing, log after trace deletion; F4 reproduced. F5/F8/F17 = accepted findings, not re-reported. |
| F-cli | Review | F11 (known) | `probe.py review` rc 0: draft/reviewed/stale, formatting invariant, draft/stale provisional, reviewed what-if separately labelled; `plan C3` reproduces F11 (creator qualifier dropped). |
| F-cli | Headline + exact statement | pass | `probe.py headline` rc 0: claims/plan print C2's exact text, not headline; claims/plan/eval JSON keeps both; review prints headline ceiling + honest records/working instruments/correct labels. |
| F-cli | Agent instructions + skill | F13, F53 (known) | `probe.py skill` rc 0: embedded show + all four installed files equal source; reinstall stable. `Cli.skillDirs` routes claude/agents to user-level dirs (code-only, as brief requires). Skill delegates draft/check/review correctly; no LLM call path. |
| F-cli | Examples | F53 (known) | `probe.py examples` rc 0: both strict checks; self C1/C3–C6/C8/C9 can, C2/C7 open; synthetic C1 conditional, C2/C3 open, C2 plan E1+E4→conditional. Synthetic wording/outcomes match scoped Decisions. |
| F-cli | Trace format + Batch path | F7 (known) | `probe.py batch` rc 0: schema equals source, fvtrace=1; recorded/what-if/action complete envelopes + all 14 item payloads exactly match individual calls; details+complete refused. Schema conformance gaps remain known F7 (outside this transport row). |
| F-cli | What-if refusals | pass | `probe.py refusals` rc 0: all four exact Decision messages × six command forms = 24 rc-2 refusals; first stderr line uses `fvtrace: `, stdout empty. |

## Findings

New findings = none. Known overlaps only: F4/F5/F8/F17 (replay), F11 (plan label), F12 (data-entry basename), F13 (skill refusal exit), F53 (skill + example text), F7 (schema gaps). F4 + F11 reproduced; remaining ids inherit the ledger's accepted proof, not a fresh rerun. No duplicate finding submitted.

## Decision coverage + rerun evidence

Runner = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-45/probe.py`; binary = `/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/bin/fvtrace`; every subprocess sets `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-45/home`. Exact argv, rc, stdout + stderr = `<case>.commands.json` beside the runner. Each command below = `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-45/probe.py <case>`.

### Product

Decision: “fvTrace's own files (trace, review record, digest cache) live in its data dir”; “Writes land in the project only where the user points them”; “`export` refuses destinations inside it”; “each local limit stays named in one place”; “nothing shipped mentions the service until it exists.”

- `product` → rc 0: `PASS Product: data dir + starter; 10 command paths; 4 inside/symlink export refusals; project.before == project.after; explicit --trace changes draft.json alone`.
- `cmp product/project.before.json product/project.after.json` → rc 0 (paths under this reviewer's scratch). Manifests include every project entry's kind, mode + regular-file sha256/link target. Checks include read commands, pin, review + both export forms; rejected exports cover direct descendants + symlinked file/parent. Explicit `--trace` review changes only its requested `draft.json`.
- `Fvtrace/Store.lean:32–52` → platform data-dir fallback + `FVTRACE_HOME` override; `:106–126` → canonical project resolution. Native host = Linux; other-platform branches read, not run.
- Computational caps: `Json.maxDepth` (`Json.lean:41`), `Json.maxDigits` (`:173`), `maxTraceBytes` (`Decode.lean:392`), `maxRelevant` (`Engine.lean:288`), derived `Server.bodyCap` (`Server.lean:97`); consumers reference the definitions.
- Service-text scan over README, skill, web, Fvtrace + Main: `rg -ni -e '\bfvapi\b|\bvflab\b|hosted service|paid product' <paths>` → 0 matches, rc 1. Positive control `rg -l fvTrace` over README/skill/web/Cli → 8 matching files. Scan = these named shipping surfaces, not every possible paraphrase.

### Evidence binding + replay

Decision: “an artifact changed or missing, or the fact or claim reworded since pinning ⇒ effective status `stale`”; “nothing runs without `--run` / `--replay`”; “a replay never changes a verdict”; failed replay “keeps the pin + leaves a lasting notice”, removed by a passing run; “every replay run, pass or fail, stays readable in a replay log”.

- `evidence` → rc 0; stale cases = artifact changed, artifact missing, fact text, entailment claim text, claim needs, restated-result claim text. Pin restores current binding. `headline` + `why` edits keep statement binding current and stale the review.
- `replay` → rc 0; ten commands without opt-in leave the before/after project manifests byte-equal (`cmp` rc 0) and create no replay marker. Opted-in argv writes a marker naming the project cwd; metacharacter argument stays literal; pinned stdout digest = SHA-256 of exactly `statement-v1\n`.
- Output mismatch → rc 1, persisted `output changed` notice; exit 7 under `pin --replay` → rc 1, persisted `exit 7` notice, receipt current. `check` rc 0 names the notice; `check --strict` rc 1. Both failures leave verdict + recorded review unchanged. Passing verify removes the notice. Log contains exactly `[pass, pass, fail, fail, pass]`, with both failure stderr tails; history stays readable after trace deletion.
- Known F4 reproduced: exit-0/output-changed diagnostic appears in the log, absent from command display. F5/F8/F17 = ledger proof only.
- Exact GUI notice words source-checked at `web/panels.js:157–168`, `:229–230`, `web/words.js:95–106`: singular/plural page lines, date prefix + all four reason endings match Decisions. Live GUI notice rendering not run in this CLI slice.

### Review

Decision: “`draft` (none) | `stale` (digest differs) | `reviewed`”; “every verdict of a draft or stale trace reads provisional”; “what-ifs are never reviewed evidence”; “Every surface shows the engine's label … [including] prospective qualifier”.

- `review` → rc 0: all three states; formatting/key order alone preserves review; content edit stales it; draft/stale claims + CLI footer provisional. Reviewed what-if retains recorded trace review while the affected claim carries `hypothetical: true` + `what-if` qualifier.
- Probe correction: initial assertion assumed hypothetical ⇒ provisional. `kernel.md` S-state explicitly defines provisional ⇔ recorded review ≠ reviewed; corrected test, no defect. What-if mode + qualifier remain required and pass.
- Known F11 reproduced: `claims --whatif M1=checked` includes `if Collect a new cohort runs`; `plan C3 --whatif M1=checked` omits it.

### Headline + exact statement

Decision: “the CLI prints the exact sentence, `--json` carries both”; “`fvtrace review` prints what the sign-off vouches for (headlines say no more than their exact statements + the universal premises).”

- `headline` → rc 0: claims + plan contain synthetic C2's exact statement, not its headline; claims/plan/eval JSON contains both. Review prints the headline ceiling, claims/facts matching the study, honest records, working instruments + correct labels.

### Agent instructions + skill

Decision: “portable Agent Skill embedded in the binary”; “`skills install --agent claude|agents` writes the user-level skills dir by default”; “the host agent drafts the trace, `fvtrace check` validates, the user's review gates final verdicts”; “fvTrace never calls an LLM.”

- `skill` → rc 0: show + four installed files match source, reinstall idempotent; six independent `cmp` calls (show, schema, four installed files) → rc 0. Every install uses the required explicit scratch `--dir`.
- Default dirs code-only: `Fvtrace/Cli.lean:807–815` routes claude → `$HOME/.claude/skills`, agents → `$HOME/.agents/skills`, neither specified → both (Windows home = USERPROFILE). Real user dirs untouched.
- Read `skill/fvtrace/{SKILL.md,references/stance.md,references/trace-format.md,assets/example.trace.json}`. Draft → check → user's review separation explicit; truthful statuses + claim wording boundary retained. Skill example `check --strict` → rc 0, draft. Shipped code process paths = replay/opener, no LLM inference path/dependency.
- F13 + F53 remain accepted text/diagnostic departures; no duplicate submitted.

### Examples

Decision: public examples = “fvTrace's own trace … + a synthetic study”; self “C2 + C7 need tested code, so E2 + E7 stay open”; “I1 … universal premise … off the claims”; “I2 … tested”. Synthetic wording/outcomes = GUI Decisions' Example wording + Example says only what can be verified clauses.

- `examples` → rc 0. Both `check --strict` pass. Self verdict map = C1/C3/C4/C5/C6/C8/C9 Fully supported; C2/C7 Pending verification. I1 absent; I2 tested; E2/E7 open.
- Synthetic = C1 Conditional, C2/C3 Pending verification; C2 plan E1+E4 → Conditional. Full synthetic trace read: C1/C2 exact text + approved headlines, restated M1/C3, R1/R2 assumptions, O3/E4 separation, E1/E3 outcomes, L-statistical waiver + plain why text match Decisions.
- Self summary/T2 wording departures already F53. The English↔Lean theorem appraisal belongs to S-skill, not re-derived here.

### Trace format + Batch path

Decision: “JSON (`\"fvtrace\": 1`) + JSON Schema printed by `fvtrace schema`”; “`fvtrace eval --complete` = the envelope + every item's details in one document, opt-in”.

- `batch` → rc 0: schema output `cmp` source → rc 0; version discriminator = 1. Recorded, `--whatif O3=checked`, `--action plan:C2`: complete envelope equals ordinary eval, all 14 items equal individually requested detail payloads, required experiment→claim→fact ordering kept. `--details` + `--complete` → rc 2.
- Known F7 = schema-vs-decoder conformance, not a new finding.

### What-if refusals

Decision: one message for GUI + CLI, opening with the rejected token; CLI prefixes `fvtrace: `.

`refusals` → rc 0: each exact first stderr line below × claims/gaps/experiments/plan/eval/eval-complete; all 24 invocations exit 2, no stdout:

```text
fvtrace: "O9" is not a fact on record
fvtrace: "bogus" is not a status
fvtrace: "O2" is not of the form FACT=STATUS
fvtrace: O2 cannot be assumed: facts of its kind must be verified
```

## Coverage limits

- Final probe cases all rc 0; no full gate, mutation campaign, performance measurement or server/browser run (outside this slice). No new red witness; known F4/F11 behaviors reproduced without duplicating findings.
- Replay native probes cover output mismatch + nonzero exit, not timeout/spawn-error execution; those branches + exact GUI reason words read in `Replay.lean`/`words.js`.
- Default skill dirs + non-Linux platform dirs source-only by brief; private traces untouched. Target unchanged; writes only deliverable + assigned scratch; no git mutation, no server started.

## Register

None.

reviewer-45-DONE-1
