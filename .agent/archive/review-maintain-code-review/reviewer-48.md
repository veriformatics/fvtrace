# reviewer-48 — L template conformance

Target: tracked state `48bc51d` at `.scratch/review-base`; L-T23 also reads primary `CLAUDE.local.md`. Read-only target. Scope fixed = L-T1…L-T23; no nested agents.

| row | clause | verdict | basis |
|---|---|---|---|
| L-T1 | project-local installation/configuration | reviewer-48-F1 | Current scanner/Node/Lake destinations project-local (fetch-tools.sh:8–9, package.json, lakefile); no firing destination check: install plant redirects scanner bin to HOME/.local/bin; existing shell/spec/fanout/meta all rc 0. |
| L-T2 | gate timing + recorded fast gate | reviewer-48-F1 | Current stage wrapper prints wall-clock; Tests/Harness prints slowest 3; fast gate recorded in ops.md. No firing output-contract guard: removing stage timing passes existing mechanical checks (timing witness rc 1 because check aggregate rc 0). |
| L-T3 | CI gate law ↔ implementation | pass | Read ops CI gate + ci-gate.sh + gate.yml; matches commit→ci/unit→watch→delete and shard workflow. Gate fanout (gate.sh:204–229) + gate.yml shard: five plants fail named causes (unsharded/matrix/step/comment/heredoc); selected probes 19/19. |
| L-T4 | ignore coverage | reviewer-48-F1 | Ignore entries cover present build/test outputs; judgment found no ignored source worth tracking. No firing output hygiene guard: remove test-results/ + create confirmed untracked output; all existing mechanical checks rc 0. No full gate/Artifacts sweep rerun here. |
| L-T5 | stale artifacts + dangling symlinks | n/a tracked tree; primary inventory in Register R1 | 341 tracked paths: 0 symlinks, no scratch/test-results tracked. Read-only ls primary: Oct 20–Nov 1 screenshots/logs/copies remain; age alone establishes neither staleness nor current-session ownership; no deletion. |
| L-T6 | UI quality floor + firing checks | reviewer-48-F2 | Gate js-lint stylelint max-ID/specificity plant fires rc2; js-test palette contrast plant rc1; e2e reduced-motion CSS plant fails named test rc1. Existing focus-return + phone-docking checks accept confirmed invisible focus (outline-style:none) + viewport390/content1400 overflow, respectively: no firing checks for those floor clauses. |
| L-T7 | computed palette safety | pass | Gate js-test→tests/palette (gate.sh:144), palette.test.mjs:61–79 computes all-pair Machado protan/deutan + unsimulated OKLab floors, marks/text contrast. Baseline 3/3 pass; gate-probe palette-contrast plant fires rc 1 naming conductor on paper. |
| L-T8 | agent-optimized non-human text | F63, F64 | Judgment sample = all 10 rules + both contracts; comment strata = Session, Json, Answers/Forest, Wasm/Build, web/lazy, tools/gate + scale. Rules/contracts dense + contract-linked; sampled redundant what-only comments now covered by known F63/F64 (no new finding). |
| L-T9 | provenance omitted | reviewer-48-F3 | All rules/contracts + comment sample: calendar ruling dates in server/web rules + PR-number origin in gate-probe are removable provenance. Decisions user-ruling markers retain binding authority, not an origin story; archived/units evidence is required traceability, not live-law provenance. |
| L-T10 | positive future-facing directions | pass | Judgment over all rules + SKILL procedure/ground rules: desired operations explicit; necessary prohibitions name concrete forbidden action (review, project writes, sinks), not vague negative outcomes. |
| L-T11 | human-facing register + filler | reviewer-48-F4; F6, F16, F59 | Judgment sample = full README/SECURITY/SKILL + references, Cli usage + diagnostic sites, GUI index/words + panel/tour strings: direct register/control names; known diagnostic defects cited. Four banned non-GUI filler tokens absent (control count4, search rc1), but four-token README plant passes all existing checks. GUI word-list exemption honored. |
| L-T12 | portable tracked project files | F10 | Known F10 owns machine-bound facts + absent portability check. Re-read units.md:44 + archive path inventory; not re-reported. |
| L-T13 | rules scope + valid frontmatter | reviewer-48-F5, reviewer-48-F6; reviewer-48-F3 | Every rule parsed with PyYAML: 9 scoped + 1 bare, 83 quoted globs all match tracked files; scopes/live law appropriate. Invalid YAML + zero-match glob plants pass existing checks (no frontmatter guard). deps lock-refresh recipe remains multi-step inline; dates → F3. |
| L-T14 | durable guidance single scope + template copies | pass | Shared-template byte-copy half = MAIN supplied verified ruling. Judgment: all rules + spec + contracts; product Decisions, formal contracts and runner-specific rules serve distinct layers, references link them; no competing generic guidance found. |
| L-T15 | comments explain why | F63, F64 | Judgment sample as T8: useful constraints/domain maps/cache and upstream rationale remain; what-only docstrings in sampled Lean/JS overlap known F63/F64 inventories. No re-report. |
| L-T16 | deterministic checks + probes + recorded firing | reviewer-48-F7; reviewer-48-F1, reviewer-48-F2, reviewer-48-F4, reviewer-48-F5; F21, F29–F35 | Source inventory gate/probes + all rules. 19 cheap selected probes fire/pass as specified; full trust/build/scale probes not rerun (MAIN B2). Multiple owning check files match no scoped rule, so required firing record cannot load on edit; existing behavioral failures owned by cited F ids. |
| L-T17 | assurance tiers + fitting evidence | pass | Read every unit row in units.md: kernel/data/docs declared; route/spike/closing-review rows carry deliberate non-implementation tier; kernel proof/suite/mutation evidence, data validators/live checks, docs consistency passes named. Credit truth itself belongs V-mutation/S-spec, not re-certified here. |
| L-T18 | durable checks rerun from committed state | pass | Gate stages invoke committed scripts/config/tests; measured performance claims point to committed scale.sh, scale-gui/page.mjs + contract; all probes committed. All rules + units + gate read: no durable claim found relying solely on a scratch-local validator (archived raw logs are evidence, not an unreproducible checker). |
| L-T19 | generated-artifact repairs replayable/idempotent | pass | Repair entrypoints committed: pin-tool.sh, pin-wasm.sh, vendor-hacl.sh + fvtrace pin; no unexplained hand-repaired generated output found. Vendor altered/unpinned probes fire (rc1); synthetic receipt pin twice rc0 + cmp rc0. Remote multi-platform re-pins not repeated (MAIN B7); idempotence beyond this sample unconfirmed by execution. |
| L-T20 | spec shape + current artifacts + firing lint | reviewer-48-F5 | Current spec shape pass; added sixth heading fails with section Wrong/expected none. Artifacts entrypoints checked against tracked inventory; known soundness deviations outside shape remain S rows. Nonexistent Artifacts path plant still spec rc0: shape lint supplies no reference check. |
| L-T21 | deferred acceptance + archive | reviewer-48-F5 | All 6 deferred entries carry Acceptance and remain unresolved in base (no due-date=stale inference); archive spot-check latest deferred6 + upgrade2 holds finished work/evidence. New deferred entry without acceptance passes gate spec/fanout/meta/shell: no firing queue-shape guard. |
| L-T22 | retired prototypes absent + tags exist | reviewer-48-F5 | Tracked prototype tree absent; all three named tags exist (git tag). A tracked prototype/reviewer48.txt + nonexistent retirement-tag plant passes existing checks: no firing retirement/reference guard. |
| L-T23 | local Chromium + timing law agree | pass | Primary CLAUDE.local.md Chromium + reference-host clauses match tracked web.md browser override + kernel P-bound/U-time + spec Decisions. Config defaults to bundled Chromium (CHROME optional); host identity intentionally local. No timing run claimed. |

## Findings

Base = `/home/eturkes/Projects/fvtrace/.scratch/review-base` (`48bc51d`). Repro root `S=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-48`. Every plant restores its copy. No target edit; no full gate, build or mutation campaign.

### reviewer-48-F1 — minor — operational invariants lack firing checks

- Rows = L-T1, L-T2, L-T4 (+ L-T16). Anchors: `tools/fetch-tools.sh:8` → `bin="$root/.tools/bin"`; `tools/gate.sh:28` → `printf '%s rc=%d %ss\n'`; `.gitignore:6` → `test-results/`; gate inventory `tools/gate.sh:36` → `STAGES='`.
- Contract = CLAUDE Execution project-local installation, stage timing, current ignore coverage + Engineering deterministic checks. Present destinations/timing/ignore entries are correct; regression detection is absent. A destination moved outside the project, a removed timing field, or an unignored generated output still passes the repository's existing mechanical policy checks.
- Proof (each command rc 1; owning checks themselves all rc 0):
  ```sh
  S=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-48
  python3 -I "$S/plants.py" install
  python3 -I "$S/plants.py" timing
  python3 -I "$S/plants.py" ignore
  ```
  Each prints `spec rc=0`, `fanout rc=0`, `meta rc=0`, `shell rc=0`, `aggregate rc=0`, then `AssertionError: no firing check: <case> plant passed every relevant existing policy/metadata check`. `install` changes only the scanner destination to `bin="$HOME/.local/bin"` (the fetch is NOT executed); `timing` removes the stage's elapsed field; `ignore` removes `test-results/` and confirms `?? test-results/reviewer48-artifact.txt` with Git.
- Coverage: all gate functions/config entrypoints read; only those four narrow checks executed on these plants. Full gate NOT run. No other gate owner of these policy invariants found. Logs: `install.log`, `timing.log`, `ignore.log` under S.
- Fix → wire focused conformance regression checks for installation destinations, timed stage output and generated-output ignore coverage; plant each breach.

### reviewer-48-F2 — minor — focus visibility + mobile fit have no firing checks

- Row = L-T6 (+ L-T16). `tests/e2e/gui.spec.js:306` anchor `await expect(opener).toBeFocused();`; `:317` anchor `expect(box && box.y + box.height).toBeGreaterThan(844 - 16);`. These check focus ownership and tour docking, not a visible focus indicator or phone layout fit. Full e2e-tree search finds no outline-style or horizontal-overflow assertion. Axe checks do not supply a visible-focus indicator test.
- Contract = CLAUDE Execution UI floor: visible keyboard focus + responsive to mobile; Engineering deterministic checks.
- Repro (each wrapper rc 1 because original checker incorrectly passes):
  ```sh
  S=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-48
  python3 -I "$S/floor.py" focus
  python3 -I "$S/floor.py" mobile
  ```
  `focus`: stylesheet response suppresses the focus outline + shadow; final inspected state = `"width":"3px","style":"none","match":true` and the sheet ends in `:focus-visible { outline: none !important; box-shadow: none !important; }`; original keyboard-tour test = `1 passed`, `existing focus check rc=0`, then `AssertionError: no firing check: focus violation passes the existing floor assertion`.
  `mobile`: stylesheet response adds `body { min-width: 1400px; }`; inspected geometry = `reviewer48 mobile={"viewport":390,"content":1400}`; original phone test = `1 passed`, `existing mobile check rc=0`, then the corresponding assertion.
- Plant integrity: browser tests run the base binary, with CSS response replacement only; original assertions retained. The helper's temporary home is redirected to S/home, temporary folders to S/tmp. Initial focus output measured width alone (= 3px), so it was not accepted as plant proof; final rerun inspected `outlineStyle:none` + actual CSS rule. A width alone does not establish a drawn outline.
- Positive controls: same driver's `motion` mode removes the reduce-media match; original `reduced motion: no transition or animation runs` fails (`Expected: 0`, `Received: 1`, target checker rc 1). Stylelint plant `#reviewer48` fails rc 2 with `selector-max-id` + `selector-max-specificity`. Palette contrast plant fires rc 1. Thus the other UI-floor check owners fire; the finding is limited to focus visibility + mobile fit.
- Logs = S/`floor-focus.log`, `floor-mobile.log`, `floor-motion.log`, `specificity.log`, `probes.log`.
- Fix → add visible-focus + phone-overflow/layout checks with these bad CSS inputs; retain focus ownership, docking, motion, palette and specificity assertions.

### reviewer-48-F3 — minor — provenance remains in live law + comments

- Rows = L-T9, L-T13. Contract = CLAUDE Authoring: state rules/facts/warnings plainly; provenance → commit history/archive.
- Exact anchors (all match `rg -Fn` at base):
  - `.claude/rules/server.md:13`: `user rulings 2026-11-01`.
  - `.claude/rules/web.md:12`: `user ruling 2026-11-01`.
  - `tools/gate-probe.sh:473`: `Renovate PR #5's edit`.
- These calendar origins/PR number change no current behavior or reason. The live text can retain the exact current command requirement and half-bump failure mechanism without the source-event labels.
- Ruling requested by brief: Decisions' `user ruling` / `MAIN ruling` markers are binding authority labels (they determine who can amend a decision), not disposable provenance. Keep those labels. Phase/round history is not needed to convey that authority. Historical raw evidence in `units.md`/archives is required by Verification integrity and remains evidence, not live-law origin padding.
- Fix → remove calendar/PR-origin labels from live law/comments; preserve the behavioral rule, rationale and authority labels.

### reviewer-48-F4 — minor — non-GUI filler rule has no firing check

- Row = L-T11 (+ L-T16). `CLAUDE.md:37` anchor `Cut filler: `; check inventory `tools/gate.sh:36` anchor `STAGES='`.
- Contract = CLAUDE Authoring's named filler set + deterministic enforcement. Current sampled non-GUI surfaces contain none of `simply`, `robust`, `seamlessly`, `leverage` (positive control: four tokens → count 4; search over README/SECURITY/skill + CLI/help/diagnostic source → rc 1). No checker owns their exclusion.
- Repro:
  ```sh
  python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-48/plants.py filler
  ```
  rc 1: `positive control: planted filler count=4 (expected 4)`; four existing mechanical checks + aggregate all rc 0; `AssertionError: no firing check: filler plant passed every relevant existing policy/metadata check`. Plant appends `This robust tool seamlessly helps you simply leverage the results.` to README. Other stages/config read: no non-GUI prose word check found. Full gate not run.
- GUI exception honored: Decisions explicitly leave GUI copy words to review judgment; this finding must NOT introduce a GUI word-list gate. Existing diagnostic defects = F6/F16/F59, not re-reported.
- Fix → wire the explicit four-word check on non-GUI human-facing prose/help/message surfaces + its probe; keep full register/wording judgments separate.

### reviewer-48-F5 — minor — tracked instruction/state metadata lacks firing checks

- Rows = L-T13, L-T20, L-T21, L-T22 (+ L-T16). `tools/gate.sh:231` anchor `spec() { sh .agent/spec-lint .agent/spec.md; }`; `.agent/spec-lint:40` anchor `sections: `; `.claude/rules/web.md:2` anchor `paths:`.
- Contract = CLAUDE Authoring frontmatter/glob rules + Session-flow Artifacts/deferred/retirement shape + Engineering deterministic checks.
- Current structure: PyYAML parses every rule (9 scoped, 1 bare); all 83 globs quoted + match tracked files; six deferred entries each have acceptance; spec shape correct; no tracked prototype tree; `prototype-gui`, `prototype-gui-iterate`, `prototype-lint` tags exist. A shape error (sixth `## Wrong`) fires spec-lint rc 1, ``section `Wrong`, expected none after `Phase` ``; the clean spec passes rc 0.
- Missing enforcement proof (each wrapper rc 1, named existing checks + aggregate rc 0):
  ```sh
  S=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-48
  python3 -I "$S/plants.py" frontmatter
  python3 -I "$S/plants.py" glob
  python3 -I "$S/plants.py" artifacts
  python3 -I "$S/plants.py" deferred
  python3 -I "$S/plants.py" prototype
  ```
  Plants = broken YAML `- [broken`; zero-match `missing-reviewer48/**`; nonexistent Artifacts `missing-reviewer48.lean`; a deferred entry without acceptance; tracked `prototype/reviewer48.txt` + a nonexistent retirement tag. Each ends `AssertionError: no firing check: <case> plant passed every relevant existing policy/metadata check`.
- Evidence/limits: gate function inventory + configs read; spec/fanout/meta/shell executed, not full gate. PyYAML structural spot-check script = S/`frontmatter.py` (`S/venv/bin/python -I "$S/frontmatter.py" <base>`); this scratch validator is review evidence, not a shipped durable gate claim. Logs = matching case names under S.
- Fix → a repo-local metadata validator for rule frontmatter/quote/glob matches, state artifact/tag references, deferred acceptance shape and retired-tree exclusion, with one planted input per invariant. Keep the supplied shared-template spec-lint byte-copy intact.

### reviewer-48-F6 — minor — multi-step Node-refresh recipe remains inline law

- Row = L-T13. `.claude/rules/deps.md:17`; exact anchor `rm -rf node_modules pnpm-lock.yaml && pnpm install --config.minimum-release-age=10080`.
- Contract = CLAUDE Authoring `.claude/rules/`: multi-step recipe → committed script named by the rule. This is a destructive refresh + install + manual eligibility-exclusion/positive-output procedure; the executable recipe remains prose instead of the required script.
- Text proof: anchor matches once in deps.md (positive count = 1). `rg -lF -- 'minimum-release-age' <base>/tools <base>/.github <base>/package.json` → rc 1; no executable/config implementation of that refresh found. Source inventory of tools read; no refresh script.
- Fix → commit the floored refresh procedure (including per-package exclusions + positive `Progress: resolved` witness) as a replayable script; leave the live rule's floor/rationale + script invocation.

### reviewer-48-F7 — minor — probe firings are not scoped to check source files

- Row = L-T16. Contract = CLAUDE Engineering: purpose-built check's firing recorded in a `paths:` rule on its files. `.claude/rules/ops.md:8` anchor `Probes = ` is bare. The scoped rules omit several check source paths entirely, so none can carry/load the required firing record when those sources change.
- Missing source matches = `tools/gate.sh` (fanout/meta/audit/examples), `tools/lean-style.sh`, `tools/trust.sh`, `tools/fetch-tools.sh`, `tests/palette/palette.test.mjs`. Existing scoped records for `tools/scale.sh`, `tools/compare.sh`, `tools/release.sh`, `TrustMain.lean` and engine differential show the intended pattern.
- Repro:
  ```sh
  /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-48/venv/bin/python -I \
    /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-48/scoped-probes.py
  ```
  rc 1: positive control `tools/release.sh matched scoped rules=['release.md']` (expected release.md); all five targets print `scoped_rules=[]`; `AssertionError: purpose-built check files cannot receive required scoped firing record: ...`. The parser reads all scoped rule frontmatter; this is not an empty-search inference.
- Firing evidence actually run: `bash tools/gate-probe.sh lean_style fanout meta replay_policy trust_cache vendor palette` in own copy → rc 0, `probes: 19 passed, 0 failed` (2 passing negative controls + 17 expected failures). Full trust/wasm/scale/release probe execution not repeated; MAIN B2 owns it. Known check weaknesses F21/F29–F35 remain those findings.
- Fix → add appropriate check-source globs + concise probe/firing records to scoped rule files (or a dedicated scoped gate rule); preserve ops.md's one authoritative overall gate command.

## Register

- R1 — L-T5 primary ignored inventory (read-only, no deletion): `/home/eturkes/Projects/fvtrace/.scratch/` contains pre-session screenshots (`a.png`, `cond*.png`, `self-1.png`, Oct 20), logs/scripts/patches (`build-1.log`, `fast-*.log`, `mut*.log`, `notes-fix.patch`, Oct 20–24), old reviewer/operator/research copies (Oct 21–25), `fvapi/` (Oct 30), `guierr-*.log` (Nov 1). `.lake`/`.tools` are reusable build/tool caches, not stale by age. `test-results/.last-run.json` is current-session (Nov 3); `dist`, `playwright-report`, `blob-report` absent. Bound = root ignored-directory ls + first 95 scratch lines + first 45 test-results lines, NOT recursive ownership/use analysis. Staleness + current ownership of the old paths unconfirmed; MAIN can decide cleanup. Tracked tree has zero symlinks.
- R2 — L-T19 execution limit: source inspection + vendor probes + synthetic pin twice establishes this sample only; all-platform remote re-pin byte equality not rerun (MAIN B7). No claim of a complete clean-clone Artifacts run, full gate, timing acceptance, mutation campaign or GUI screenshot review.
- R3 — Check-set interpretation: numerical/layout/metadata properties above are mechanical; full prose register, authority-marker intent and stale-file usefulness remain judgment. Existing F10/F63/F64/F6/F16/F59 and check-behavior findings cited in the table are not new findings.

## Validation + cleanup

- Rows adjudicated = 23/23; 8 pass, 14 with findings (new or known), 1 n/a; seven new root findings, all minor.
- Ran: 19 selected probes; palette 3/3 baseline; specificity plant; spec clean/bad shape; nine operational/metadata plants; phone/focus/motion browser plants; all-rule YAML/glob validation; scoped-record red witness; synthetic pin twice + byte comparison; exact source anchors.
- No target changes. Private copy restored (`git status --porcelain` empty after plants). Browser helper closes each server by its ChildProcess PID; final `pgrep -af '[r]eviewer-48/tree/.lake/build/bin/fvtrace'` = no matches (rc 1). No commits/branches/stashes/pushes in primary/base. Scratch scripts/copy/logs retained as review-proof inputs.

reviewer-48-DONE-1
