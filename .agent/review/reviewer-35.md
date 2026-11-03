# reviewer-35 — S-readme

Target = `48bc51d`, `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Check set fixed by brief: each sentence/table/example in README + SECURITY + help/encountered CLI copy, spec Artifacts existence/run claims, human-facing register. Known exclusions = eval missing from table; subcommand `--help`; schema extra-arg wording; plan prospective qualifier.

| row | target | verdict | basis |
|---|---|---|---|
| S-readme | README: intro + verdicts + Install + Build from source | pass | Read every statement; v0.1.0 + Lean 4.35 match binary/pin; archive names/floors match release.sh + build.yml; local emsdk archive 311,791,988 B, engine block 487,472 B. Cross-platform install + fresh compilation not independently rerun (coverage below). |
| S-readme | README: Quick start + browser view + Commands | existing F13, F14 | drive.sh: fresh init/path/pin/check/claims/review; synthetic projections/details/complete/action/what-if; exports + colleague bundle check all rc 0; BrowserOS page 239: exact statement, C2/fact details, suppose/reset, Text, find + tour verified. The universal exit-status wording is contradicted by existing ledger F13/F14 (not re-reported); omitted eval/subcommand help excluded by brief. |
| S-readme | README: The trace (+ Results, exclusions) + data folder | reviewer-35-F1, reviewer-35-F4 | Schema bytes equal; model/receipt/subject/exclusion text checked against kernel + Spec; replay-cycle.sh confirms failed/passed notice lifecycle, reviewed+can retained, log contents, no implicit replay; same-size+mtime edit gives cached can / rehashed open as disclosed; synthetic project byte-unchanged. Unpinned-output failure contradicts the notice promise. |
| S-readme | README: Sharing + coding agent + verifies itself + Limits + Development | reviewer-35-F3; existing F21 | Page holds whole trace + recorded view + 487,472-B engine; bundle trace/artifacts match; native + exported stacked what-if C2 Conditional. Self-trace 7 can / 2 open confirmed. Spec/Proofs/trust key/differential + scale/compare branches read. Skill-compliance guarantee exceeds plain instructions; grader overpromise already ledgered F21 (not re-reported). |
| S-readme | SECURITY.md | pass | Non-exploit consistency pass: bodyCap = maxTraceBytes + 1024; export/source worker + named policy + inline assets match; build verifies each fetched input and replay is opt-in. Supported-version policy = declared policy, not a historical guarantee. Boundary/exploit judgments remain MAIN's; GitHub reporting-tab route not visited (unconfirmed). |
| S-readme | `fvtrace --help` + CLI messages met | reviewer-35-F1, reviewer-35-F2; existing F13, F14 | Captured complete --help rc 0 and every driven command's stdout/stderr/rc; usage lines match implemented options/defaults/projections. Notice promise needs its unpinned-output exception; two reached errors omit remedies; existing exit-code defects not re-reported. |
| S-readme | spec.md Artifacts (paths + run commands) | pass | All 52 concrete file/dir/executable paths exist; all 3 retired tags resolve; Lake targets/testDriver/source imports match. Built binary --help/--version + documented CLI commands driven here. MAIN baseline.md B3 reports no-op lake build, help rc 0 + CI lake test green; not independently rebuilt/retested here. Development full gate/probes/timings remain baseline-owned. |
| S-readme | human-facing register (README, SECURITY, --help) | reviewer-35-F2 | Read all three surfaces; README + SECURITY natural/direct, condition-first instructions + fixed terms; help terse but intelligible. Filler count = 0 in every surface (positive control expected=1, actual=1). Reached CLI errors need remedies; no additional per-surface register finding. |

## Findings

### reviewer-35-F1 — minor — failed-replay notice promise includes a failure that creates no notice

- Target: `README.md:199–203`, `Fvtrace/Cli.lean:49` (`--help`). Contract: S claim soundness; kernel.md § Replay Notice explicitly distinguishes `output not pinned` (keep notice) from a verifier failure (set notice).
- Anchors: `commands write a notice into the trace` → README:200; `A failed replay leaves a notice on its fact in the` → Cli:49. Both matched with `rg -Fn` on the base.
- Why wrong: a valid, current, verified fact may declare a replay without pinned output. `verify --run` calls it failed (rc 1), yet leaves no notice and the next strict check passes. The README/help promise a notice for a failed replay without this exception. Code correctly implements the narrower kernel contract (`Fvtrace/Replay.lean:136`, `| none => .keep`).
- Red test: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-35/replay-unpinned.sh` at `48bc51d` → rc 1:
  ```text
  positive control: pin rc=0; valid/current check --strict rc=0
    R: running bash replay.sh
    R: failed (output not pinned)
  0 of 1 replay(s) passed.
  verify --run rc=1
  replay.failed=absent; check --strict rc=0
  FAIL: README/help say a failed replay leaves a notice, but output-not-pinned failure leaves none.
  ```
- Fix direction: distinguish missing output pins from verifier failures/output changes in README + help; direct the former to `pin --replay` rather than promise a notice.

### reviewer-35-F2 — minor — encountered CLI errors omit the remedy

- Target: `Fvtrace/Store.lean:102`, `Fvtrace/Cli.lean:220` (CLI copy reached by the documented `--project` / `--trace`). Contract: `CLAUDE.md` Authoring Human-facing: an error states what happened + the fix.
- Exact anchors: `return .error s!"no folder {dir}"` → Store:102; `cannot read {file}: {reason}` → Cli:220. `rg -Fn` matches both. The missing-project message is complete at that source return, and `target` prints it without further guidance (`Cli.lean:213`).
- Observed via `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-35/drive.sh` (logs retained): `fvtrace claims --project <scratch>/no-such-project` → rc 2, `fvtrace: no folder <scratch>/no-such-project`; `fvtrace claims --trace <scratch>/no-such-trace.json` → rc 2, `fvtrace: cannot read …: no such file or directory …`. Neither error gives an action. This contrasts with `Cli.report .noTrace`, which explicitly says `run fvtrace init`.
- Fix direction: add concise, condition-appropriate remediation to these human errors (choose/create an existing project folder; correct the trace path or create the trace). README + SECURITY otherwise pass the register judgment; status adjectives such as “verified” are not treated mechanically as passive-voice defects.

### reviewer-35-F3 — minor — skill instructions presented as guarantees about an external agent

- Target: `README.md:287–289`. Contract: S claim soundness / guarantee-vs-claim; Intent = ensure nothing overstated.
- Anchor: `The agent never marks a fact verified without evidence, and it never` → README:288 (`rg -Fn` matched). The following line completes the promise: `signs off the trace: the review is yours.`
- Proof: `Fvtrace/Cli.lean:823–837` installs ordinary instruction files + its marker; `skills show` prints those instructions (`Cli.lean:840–842`). `skill/fvtrace/SKILL.md:18` + `:20` instruct the agent not to record verified facts without evidence and not to run review. fvTrace never calls or controls that external agent. This establishes what the skill directs, not that the agent always complies. A runtime counterexample would require deliberately violating those instructions; none was attempted.
- Fix direction: keep the boundary explicit: “The skill tells the agent never to mark … and never to sign off …”; retain the user's responsibility for review.

### reviewer-35-F4 — minor — blanket rehash claim includes commands that read no evidence

- Target: `README.md:186`. Contract: S claim soundness. kernel.md § Receipts carries the same overbroad “Artifacts are read + hashed on every command” wording; the actual command contracts distinguish evaluation/check from replay listing + review.
- Anchor: `Each command reads every evidence file again` → README:186 (`rg -Fn` matched).
- Why wrong: `verify` lists replay declarations after decoding/checking the trace and never binds receipts (`Cli.lean:448–515`); `review` hashes the trace content, not evidence files (`Cli.lean:517–540`). Evaluation commands and `check` do bind evidence. The README's universal wording falsely promises this read/rehash for the other commands too.
- Red test: `bash /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-35/rehash-scope.sh` at `48bc51d` → rc 1. `strace -f -qq -e trace=openat` uses the same valid pinned fixture for the positive control and `verify`; an exact absolute-path match identifies its artifact:
  ```text
  positive control expected=1: check rc=0 artifact opens=1 (rg rc=0)
  verify rc=0 artifact opens=0 (rg rc=1)
  FAIL: README says each command reads every evidence file; verify does not open the valid trace's evidence.
  ```
- Fix direction: name the commands that recheck evidence; keep `verify`'s replay-only scope explicit. Align the matching kernel.md sentence through MAIN's ruling.

## Register

- `README.md:255` (`so no other program on this`) → security → MAIN.
- `README.md:137` / Limits: no README disclosure of the 20-relevant-experiment exact-plan limit; CLI itself discloses it and claims no optimum (`Cli.lean:790–791`), so this is a documentation completeness entry, not an unsound computed result.

## Coverage / unconfirmed claims

- Complete read = README (every section/table/example), SECURITY, full help, all stdout/stderr logs from `drive.sh` + the replay probes. Source/contract review = kernel.md, Decisions, rules, Cli/Store/Replay/Export, Spec Engine + Fast, trust/statement/scale/compare scripts, Lake/workflow/build-pin surfaces. Bounded `rg` searches were navigation, not a sampled README read.
- Runtime = `drive.sh` (35 named invocation results), `replay-cycle.sh` (20 lifecycle/cache invocation results), two red scripts above; all fvtrace invocations set the brief's isolated FVTRACE_HOME. `skills install` deliberately used `--dir <scratch>/skills`; all serve runs used `--port 0 --no-browser` rather than the README's desktop opener/default-port form, per BRIEF. No claim of independently testing the actual opener or SSH forwarding.
- Source/runtime checks confirm 7 Fully supported + 2 Pending self-claims; synthetic 3 claims (2 existing + 1 prospective); its C2 plan E1+E4; notices preserve reviewed/can, strict detects them, passing run clears them; logs retain argv/stderr; cached same-size+mtime edit misses the change, uncached read detects it. Schema bytes = emitted schema. Bundle trace + both artifacts = source; export snapshot = whole source trace, engine block = 487,472 bytes. Synthetic project compared byte-unchanged after CLI/serve/export.
- BrowserOS own page 239: real served view, exact statement, C2 details + waiver + plan, O3 find→details, symbol suppose→reset, Text, tour→Esc; exported file page stacks O2/O3/EN2 and reads C2 Conditional, with 0 external script/stylesheet links. Inspected screenshot retained at `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-35/recorded-browser.jpg`. Exported interactive page left open for inspection.
- Unconfirmed here: fresh compilation, full/native/pure/gate/probe/engine/e2e suites and reference-host timings (MAIN baseline owns them); clean downloads + released-archive checks/attestation; Windows/macOS installation/floors, macOS quarantine, Windows archive's approximate 700-MB size; Safari Lockdown behavior; external GitHub Security-tab/reporting UI. Looked at pins, release/build source, the local Linux archive, kernel.md evidence, and MAIN's baseline B3/B7; these are not substitute claims of running the other platforms. `tools/pin-wasm.sh` not rerun (network + pin rewrite outside this read-only review).
- Existing findings consumed, not duplicated: F13/F14 (exit-contract exceptions), F21 (grader can accept failing outputs/session status). The brief's four explicit known exclusions were left out. Security observations are routed to MAIN alone.
- Cleanup: owned serve PID 1261483 killed (rc 0); its tool background command ended 143 as expected. Port 38563 then refused (`curl` rc 7). Final `pgrep -af '[f]vtrace serve.*reviewer-35'` found none (rc 1); the earlier positive-control listing identified its exact PID. No target/source edits, builds, commits, branch operations or nested agents.

## Primary-source excerpts — coding-agent path claim

Official pages checked in own BrowserOS tabs; quotes are the page's text, not model paraphrases. These establish local skill discovery, not guaranteed agent compliance (F3).

- Codex, `https://learn.chatgpt.com/docs/build-skills`: `USER` → `$HOME/.agents/skills` (table entry); `Codex reads skills from repository, user, admin, and system locations.`
- Gemini CLI, `https://geminicli.com/docs/cli/skills/`: `User skills: Located in ~/.gemini/skills/ or the ~/.agents/skills/ alias.`
- GitHub Copilot, `https://docs.github.com/en/copilot/concepts/customizations/agent-skills`: `Personal skills, stored in your home directory and shared across projects (~/.copilot/skills or ~/.agents/skills)`.
- Cursor, `https://cursor.com/docs/skills`: `~/.agents/skills/` → `User-level (global) on the local machine` (table entry); `For compatibility, Cursor also loads skills from Claude and Codex directories: .claude/skills/, .codex/skills/, ~/.claude/skills/, and ~/.codex/skills/.` Cloud/remote caveat on the same page = local home skills are not automatically copied; README describes the local program/agent setup.

reviewer-35-DONE-1
