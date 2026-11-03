# reviewer-29 — K-cli

Target = frozen `48bc51d`, `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Check set fixed before target read: Cleanup + Altitude; behavior-preserving changes only. Known findings named in brief excluded.

| row | target | verdict | basis |
|---|---|---|---|
| K-cli | Cleanup: Cli.lean command bodies + helpers | reviewer-29-F1, reviewer-29-F2, reviewer-29-F3, reviewer-29-F4 | Read all 1,138 lines; searched existing helpers + callers; duplicate read/decode block, serializers, text-only JSON retention + repeated plan indexes anchored below. |
| K-cli | Cleanup: Args + Store + Assets + Version + Main + embeds | pass | Read every named support module + Version Spec/Proofs; generic parser + shared path/store/link helpers retained; embed tables + entrypoint used; declaration-name screen found no no-caller helper candidate. Known Store/Env issues excluded. |
| K-cli | Cleanup: tests + smoke.sh | reviewer-29-F5 | Read all named test files + smoke.sh; shared capture/symlink/unlink already used; substring counter cloned across suites + repeated inline in Cli.lean. Test runner wiring searched. |
| K-cli | Altitude | pass | Separate pass over CLI wrappers, parser/store helpers + test seams: Specs express command differences; Args has no command-specific branch; platform link/bind/opener adaptations implement their mechanism's contract. No additional one-caller workaround proved. |

## reviewer-29-F1 — duplicate decoded-target read path

- Severity: minor.
- Target: `Fvtrace/Cli.lean:463–467`, duplicate at `:527–531` (base `48bc51d`).
- Contract: `CLAUDE.md` Engineering / Cleanup = near-duplicate blocks merged; helpers reused.
- Proof: `verify` + `review` repeat the same five-line `readTarget` match, including the same decode-refusal message + rc 1. The surrounding three-line target-resolution match is duplicated too (`:458–460`, `:524–526`); later WF policy differs and need not merge. `readTarget` already centralizes the lower read path (`:232–236`), while `report` already owns this decode diagnostic (`:221–223`).
- Anchor: `complain s!"fvtrace: {tg.trace} does not decode; run fvtrace check"; return 1` → `rg -Fn` matches exactly `:466` + `:530`.
- Fix: add one flat decoded-target helper over `readTarget` + `report`, use it in `verify` + `review`; keep `pin`'s richer decode diagnostics + each command's validation order unchanged.

## reviewer-29-F2 — JSON serializers reimplemented per surface

- Severity: minor.
- Target: `Fvtrace/Cli.lean:136–140`, `:152–153`, `:198–199` (base `48bc51d`).
- Contract: `CLAUDE.md` Engineering / Cleanup = existing helpers reused + near-duplicate blocks merged.
- Proof: binding serializer `Cli.bindingJson` is byte-for-byte the same as `Snapshot.bindingJson` (`Fvtrace/Snapshot.lean:27–28`); `Session.viewOf` repeats it inline (`Fvtrace/Session.lean:155–156`). `Cli.warningJson` repeats `Evaluate.envelopeWith`'s warning serialization (`Fvtrace/Evaluate.lean:265–268`, same property order + optional `waived`); `Cli.noticeJson` repeats `Evaluate.noticesJson` (`:65–69`) + `Session.viewOf` (`:157–158`). One semantic record currently has several independently maintained wire encoders.
- Anchors: `def bindingJson (b : Receipt.Binding) : Value :=` → `rg -Fn` matches CLI `:198` + Snapshot `:27`; `.obj [("id", .str id), ("date", .str x.date), ("reason", .str x.reason)]` → CLI `:153`, Evaluate `:69`, Session `:158`; `("message", .str w.message)] ++` → CLI `:138`, Evaluate `:267`.
- Fix: share Init-only per-record JSON helpers below the consumers; preserve every field, property order + optional-field rule (the snapshot closure stays Std/FFI-free).

## reviewer-29-F3 — text paths retain JSON-only output state

- Severity: minor.
- Target: `Fvtrace/Cli.lean:430` (also `:485–501`, base `48bc51d`).
- Contract: `CLAUDE.md` Engineering / Cleanup = startup + hot paths lean; work their result does not need removed.
- Proof: `showLog` parses each log line, then unconditionally pushes the whole parsed object into `runs`. Text mode prints the entry immediately (`:431–434`); after the loop it reads only `runs.isEmpty` (`:443`). Therefore `verify --log` text retains every parsed log record for the entire run, although one count/boolean suffices. The log is append-only + unbounded by contract (§ Replay Log). Similarly, ordinary text `verify` constructs every JSON `fields` list + accumulates every `rows` entry (`:485–501`) that only `if json` (`:507–515`) consumes.
- Anchors: `runs := runs.push v` → `rg -Fn` matches `:430`; `rows := rows.push (id, fields)` → `:501`; `else if runs.isEmpty && bad == 0 then say` → `:443`.
- Fix: keep an entry count for `showLog`'s empty message; accumulate objects/row fields only under JSON mode. Keep per-line text output, malformed-entry counting, rc + replay/notice/log order unchanged.

## reviewer-29-F4 — `plan --json` builds the same answer indexes twice

- Severity: minor.
- Target: `Fvtrace/Cli.lean:748–753` (base `48bc51d`).
- Contract: `CLAUDE.md` Engineering / Cleanup = existing helpers reused; startup + hot paths lean.
- Proof: `planCmd` constructs `A := Answers.fast sc` before resolving the claim. Its JSON branch then calls `envelopeOf l` → `Session.envelope` (`Fvtrace/Session.lean:135`) → `Evaluate.envelope` (`Fvtrace/Evaluate.lean:276–278`) → another `Answers.fast sc`. The first A remains needed for `Evaluate.planJson (A.plan c)` (`Cli.lean:762`), so this is not merely a dead local. `Answers.fast` builds `Ctx.build` + `Core.build` (`Fvtrace/Answers/Fast.lean:40–41`); the second instance cannot reuse the first instance's indexes or thunks. Generated C confirms both calls survive Lean compilation: `.lake/build/ir/Fvtrace/Cli.c:21725` calls `Answers_fast`, then `:22415` calls `Session_envelope`; `.lake/build/ir/Fvtrace/Evaluate.c:7426` builds another `Answers_fast` in `Evaluate.envelope`.
- Anchors: `let A := Answers.fast sc` + `let env := envelopeOf l` → `rg -Fn` matches CLI `:748` + `:752`. Existing reusable entry point: `def envelopeWith (sc : Scenario) (A : Answers)` → Evaluate `:233`.
- Fix: pass the existing A to `Evaluate.envelopeWith` (or the shared loaded-envelope helper); preserve JSON bytes, absent-claim refusal + rc. No timing reduction quantified.

## reviewer-29-F5 — shared test substring counter cloned

- Severity: minor.
- Target: `Tests/CliStore.lean:7`, `Tests/Assets.lean:8`, `Tests/Cli.lean:95–114` (base `48bc51d`).
- Contract: `CLAUDE.md` Engineering / Cleanup = helpers reused + near-duplicate blocks merged.
- Proof: CliStore + Assets define exactly the same substring-count helper; the same definition also occurs in `Tests/{Fields:12,Export:7,Replay:39,Snapshot:7}.lean`, with an alpha-renamed copy in `Tests/Notices.lean:45`. Cli's install/refusal checks instead repeat `.splitOn … .length == 2` (one occurrence) / `== 1` (zero occurrences) inline (`:95`, `:97`, `:112`, `:114`). All these suites import `Tests.Harness`, the existing shared home of capture + assertion helpers.
- Anchor: `def count (s sub : String) : Nat := (s.splitOn sub).length - 1` → `rg -Fn` over `Tests/` matches exactly 6 definitions. Inline anchor: `((out.splitOn "Start a new session").length == 1) out` → `Tests/Cli.lean:112`.
- Fix: put the counter in `Tests.Harness` + reuse it; keep every test name, assertion, expected occurrence count + case unchanged.

## Coverage + checks

- 4/4 seeded rows adjudicated; every named target file read in full. Cleanup pass → declaration/caller + duplicate-helper searches; Altitude pass → shared abstractions, command Specs, platform adaptations + test injection seams. Supporting readers = `Session`, `Evaluate`, `Answers/Fast`, `Snapshot`, `Tests/Harness` + runner/import wiring; no search cap on the duplicate queries. The abstraction inventory's saved output was opened in full after the tool abbreviated it.
- Findings = source-structure findings, not claimed behavior failures; each has matching exact bytes + duplicate/control-flow evidence. F4 additionally checked against generated C in the base's existing build. Runtime/memory speedups unmeasured; no numerical improvement claimed.
- LSP probe on `Fvtrace/Cli.lean:748` → no `.lean` server available; source search + full-file reads used instead. No tests, build, mutation campaign or full gate run; no source changes or servers started.
- Known correctness findings in MAIN's brief excluded. Register: none.

reviewer-29-DONE-1
