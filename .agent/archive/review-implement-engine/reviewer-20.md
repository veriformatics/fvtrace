# reviewer-20 verdicts: claim soundness lens (closing review, IMPLEMENT — engine speed-up)

Target = `af5a2f1..fa7f307`; read-only, claim-soundness rows R2.1–R2.3 fixed before target inspection. Acceptance = `kernel.md` P-bound…P-evidence + ledger F5. Report = validator input; findings require a red behavior witness or exact matching text. Audit/replay evidence must distinguish executed checks from inspected records.

| id | asks | verdict | findings |
|---|---|---|---|
| R2.1 | `Spec.LookupsAgree`, `Spec.SortMembersAgree`, `Spec.AnswersAgree`: non-vacuous, about the shipped functions the binary calls, domain = every trace / scenario; docstrings say no more than the statements | finding | R2-F1 |
| R2.2 | proofs: no `sorry`, axiom or escape hatch; `fvtrace-trust` covers the new modules (claims, capabilities); kernel replay | pass | - |
| R2.3 | self-trace C9 + P10–P12 + E9 texts, README "How fvTrace verifies itself" + Development lines say what the theorems + tools establish, no more | finding | R2-F1 |

## Findings

### R2-F1 — timing prose broadens the graded workload contract

Severity = **minor**. Text defect; no implementation defect alleged. Theorem statements + per-claim docstrings + self-trace semantic claims pass; finding = the module overview + README timing scope.

Locations:
- `/home/eturkes/Projects/fvtrace/README.md:223`
- `/home/eturkes/Projects/fvtrace/README.md:271`
- `/home/eturkes/Projects/fvtrace/Fvtrace/Spec/Fast.lean:9`

Exact anchor bytes (`rg -Fn` matched at those lines; each file `cmp`-identical to `git show fa7f307:<file>`):

```text
indexes and keeps the results that it uses again, so a trace of 16 MiB takes seconds. Lean
  of up to 16 MiB and fails when a run takes more than 60 seconds, or more than 2.5 times as
fvTrace reads a trace through sorted indexes, so a 16 MiB trace takes seconds. Each claim below
```

Why wrong: functional equality proves no runtime bound. P-bound explicitly grades only `wide`, `deep`, `experiments`, `exclusions`, on an idle host; it says “The limits grade those workloads, not every trace” (`/home/eturkes/Projects/fvtrace/.agent/contracts/kernel.md:122`). Other traces may emit super-linear output or explore up to 2^20 plan leaves. The unqualified 16 MiB sentence widens this measured domain. The Development sentence likewise says the default scale command fails when “a run” exceeds the bounds, but the command also runs eight ungraded shapes: `/home/eturkes/Projects/fvtrace/tools/scale.sh:33` lists the four graded names, `:54` sets `grade` only for them, `:80` guards all bound failures. Its `:11` explicitly says “Other shapes are reported, never graded.”

Acceptance: qualify both timing assertions with the four graded workloads + idle-host condition; state supplemental shapes are reported without these limits. Keep the unconditional answer-equality statements intact. No theorem, gate, benchmark limit or self-trace semantic claim needs weakening.

## Evidence / coverage

- R2.1: exact record equalities quantify over every `Trace` / `Scenario`; function-valued fields extend to arbitrary ids/claims/facts, without WF or membership hypotheses. `Answers.reference` reads `Scenario.*`; target diff leaves those semantic definitions unchanged (`Overrides.parse` is P-shell). `Lookups.reference` reads original list operations. `SortMembersAgree` retains `foldr Json.insertBy []`, including duplicate-key reversal.
- Consumer paths inspected: `Evaluate.envelope` → `Answers.fast`; CLI claims/gaps/experiments/plan → `Answers.fast`; Check/Lint → `Lookups.fast`; receipt manifests take the shared `Lookups`; `Json.Value.canonical` calls `sortMembers`. `Fvtrace/Proofs/Check.lean` rewrites fast violations to the reference before WF proofs.
- `ContractWiring.lean`: `cd /home/eturkes/Projects/fvtrace && lake env lean --run .scratch/reviewer-20/ContractWiring.lean` → rc 0; unconditional envelope/check/lint/manifest/binding/sort equalities + E9 conjunction accepted. Three new proofs' axiom lists = `propext`, `Classical.choice`, `Quot.sound`; log `wiring.log`.
- Audit executed: `cd /home/eturkes/Projects/fvtrace && lake env .lake/build/bin/fvtrace-trust --proofs .scratch/reviewer-20/proofs.txt` → rc 0, 26 claims / 0 findings; `audit.log` names all three new claim/proof pairs. Fresh proof-list bytes = `.lake/trust/proofs.txt` (`cmp`, rc 0).
- Self-trace executed with `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/reviewer-20/home`: built binary `check --strict --trace examples/fvtrace/trace.json --project .` → rc 0; `eval` → rc 0, 7 can / 2 open, C9 Fully supported + draft, P10/P11/P12/E9 current and proved. Logs `self-check.log`, `self-eval.json`.
- Live statement fingerprints: built `fvtrace-trust --statement Fvtrace.Spec.AnswersAgree|LookupsAgree|SortMembersAgree` → each rc 0; SHA-256 equals P10/P11/P12's pinned replay output (`statement-checks.log`). This reviewer bypassed the building `tools/statement.sh`; MAIN's completed full trust stage below separately reran all 12 statement commands.
- Kernel replay **confirmed** against fresh export SHA-256 `1d7c2bb46d0a69c1826c4a9da952798769750eaa35a74e2718a3bdbd81217f49`: own `lake env leanexport Fvtrace -- <proofs.txt>` → rc 0; `cmp` against `.lake/trust/export.ndjson` → rc 0. Refreshed `.lake/trust/check.log` accepts Lean default/paranoid, lean4lean, nanoda, con-leche, con-ron; con-leche/con-ron report 7,028 declarations, lean4lean 7,025. Final axiom list = `propext, Quot.sound, Classical.choice`. Snapshot `replay-completion.log`; `ReplayCoverage.sh` repeats export + byte comparison (rc 0). Replay itself ran under MAIN's shared build ownership, not this reviewer. MAIN's completed `/home/eturkes/Projects/fvtrace/.scratch/trustsh-fa7f307.log` inspected after its terminal `rc=0`: 26 claims / 0 findings, 26 proofs replayed, all six kernels accept, 12/12 statement replays pass (P10–P12 included). After completion, shared export SHA-256 still matches the fresh export above; `.lake/trust/replayed` exists. Thus the full trust-stage rc is confirmed from its named log, not inferred from intermediate output.
- Resolved doubt: initially the shared replay export was the superseded `Ctx.closureFuel` implementation (`79077214…`, 6,958 declarations), with no final `Proofs.Closure`. It was refreshed during this review; the matching current export + all-kernel acceptance above supersede that gap. No finding remains on kernel replay.
- Audit-module coverage executed: `lake env lean --run .scratch/reviewer-20/ModuleCoverage.lean` imports the same `Fvtrace` root as `TrustMain`; 14 expected new/adapted modules present, 0 missing, rc 0 (`module-coverage.log`). `TrustMain.audit` closes each discovered claim/proof; `capabilityUses` scans all imported `Fvtrace.*` constants. Source escape-hatch search over the new kernel/proof files → rc 1 / no matches; positive control `theorem answersAgree` → one match / rc 0. Audit's dependency closure + axiom collection cover imported helpers too.
- Coverage limits: judgment pass = the three closed statements, final proof assemblies + relevant helper invariants, reference/shipped consumer wiring, audit implementation + import graph, named self-trace/README entries. Individual helper tactic lines were not all manually re-derived; machine audit + full matching-export replay cover their proof closures. Full build/test/performance/browser gates not run by this reviewer (MAIN owns them). No remaining unconfirmed acceptance claim in R2.1–R2.3; no behavioral implementation defect found.
- LSP coverage checked on `Fvtrace/Spec/Fast.lean`: no Lean LSP available; source + kernel/audit checks used instead.
- Revision boundary: source reads/anchors above = `fa7f307` (later HEAD only adds review planning). Unstaged edits to `tools/compare.sh` + `tools/scale.sh` appeared at close, outside this review's writes; those later edits are not adjudicated here. This reviewer wrote only its allowed `.scratch/reviewer-20/`. Temporary duplicate export/fingerprint bytes removed; scripts/logs retained.

## Register (defects outside the check set)

- REG1 (outside R2's specified prose targets): `/home/eturkes/Projects/fvtrace/Fvtrace/Lookups.lean:10,102` says `O(log n) each`, but whole-list answers are not point lookups: `:138` runs `Index.nodup compare t.allIds` on demand, `:139–142` scans declarations to return duplicates, and `nodup` sorts its arbitrary argument. Exact `rg -Fn` anchors: ``(`Fvtrace.Index`), O(log n) each.`` and `The same answers from sorted indexes: O(log n) each.` Qualify the point-lookup cost separately from whole-list answers; no runtime defect alleged.


reviewer-20-DONE-1

## Re-review (84da642)

Scope = R2-F1 acceptance alone; one round, no new rows. Target = `84da6426bdb9d6947357d727133f12872e70ca64`; named-file diff + commit body read. Current named files byte-equal that commit (`git show 84da642:<file> | cmp -s - <file>` → rc 0 for both).

| finding | verdict |
|---|---|
| R2-F1 | fixed |

Deciding bytes (`rg -Fn` matched):

- `/home/eturkes/Projects/fvtrace/README.md:223–226`: runtime claim explicitly applies to generated traces graded by the tool, on an idle computer; unconditional answer equality stays separate.

```text
indexes and keeps the results that it uses again. On the generated traces that
`tools/scale.sh` grades, a trace of 16 MiB takes seconds on an idle computer. Lean theorems
prove that these fast paths give the same answers as the definitions, for every trace and every
what-if (`Fvtrace/Spec/Fast.lean`). Thus the other guarantees cover what the program shows.
```

- `/home/eturkes/Projects/fvtrace/README.md:271–273`: assertion failures apply to the four graded shapes; other shapes are reported without those limits; idle-host condition explicit.

```text
  of up to 16 MiB. It grades four trace shapes: it fails when one of their runs takes more than
  60 seconds, or more than 2.5 times as long when the trace doubles. It reports the other
  shapes without a limit. Run it on an idle computer.
```

- `/home/eturkes/Projects/fvtrace/Fvtrace/Spec/Fast.lean:9–10`: the universal timing sentence is removed, replaced by a scoped pointer; all three `Prop` definitions remain unchanged by this fix.

```text
fvTrace reads a trace through sorted indexes + memos (time bounds: `tools/scale.sh`, graded
workloads alone). Each claim below says that an indexed answer equals the plain definition it
```

Acceptance satisfied. Prose-only re-review: no build, benchmark, replay or broader code review rerun; other findings/register entries not re-adjudicated.

reviewer-20-DONE-2
