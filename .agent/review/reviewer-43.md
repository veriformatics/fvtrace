# reviewer-43 — V-gate

Target = `48bc51d`, frozen `/home/eturkes/Projects/fvtrace/.scratch/review-base`; check set = brief's five V-gate checks + LENSES.md § V. Read-only target; plants = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-43/`.

| row | target | verdict | basis |
|---|---|---|---|
| V-gate | purpose-built checks ↔ probes (each has one, cause named) | reviewer-43-F2; known F21, F29–F31, F35 | 20 groups / 69 `expect` or `allow` rows traced to their owning checks; 11 single groups run, 26/26 controls passed. No mutation-tool probe. Existing dispatch/trust/mutation/parity defects cited, not re-reported. |
| V-gate | probe restore + re-hash | pass | `keep` → saved content digest → `restore` + digest equality, at every `expect`/`allow` and EXIT; present/absent paths covered. All exercised plants restored; TERM while lean-style held a planted file also restored it. |
| V-gate | upstream tool configs reach their files | pass | 32/32 JS/MJS files hit oxlint's DOM-sink rule, tsc assignment checking, Prettier; strict flag plants hit all three tsconfigs. 18/18 shell files hit SC2086. CSS specificity + HTML close-order fired. actionlint + zizmor named 4/4 workflows. betterleaks detected deleted history + hidden untracked fake tokens. Audit probes 4/4. |
| V-gate | stages that cannot fail / empty inputs | reviewer-43-F1; known F21, F29 | Engine + js-test report 0 tests, rc 0; lean-style sees no Lean files, rc 0. js-format correctly rejects empty input (pipeline rc 1). Known failure-discard paths = F21 + F29. |
| V-gate | trust skip key | reviewer-43-F3 | Real passing key survives a replay-consumer change: trust rc 0 + skipped; forcing the skipped statement replays on the same binary gives rc 1, 0/12 passed. |

## reviewer-43-F1 — empty source/test selections report green

Severity = **minor**. Anchors at `48bc51d`:

- `tools/gate.sh:99`: `engine() { node --test tests/engine/; }`
- `tools/gate.sh:144`: `js_test() { node --test tests/schema/ tests/palette/ tests/renovate/; }`
- `tools/lean-style.sh:9`: `mapfile -t files < <(git ls-files -co --exclude-standard -- '*.lean')`

Contract = brief check (4), Engineering verification integrity: an empty run must not substantiate a green check. The Node stages accept their runner's zero-test success; the Lean layout loop returns its initialized `rc=0` without seeing a file. A test rename or selection error can erase an entire differential/schema/palette/Renovate stage without making that stage red.

Red command:

```sh
python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-43/red-empty-stages.py
```

Observed rc 1; byte-identical owning scripts copied into a fixture with empty matching directories:

```text
engine: no matching source/test files; rc=0
ℹ tests 0
engine rc=0
js_test: no matching source/test files; rc=0
ℹ tests 0
js_test rc=0
lean_style: no matching source/test files; rc=0
lean_style rc=0
js_format: no matching source/test files; rc=1
AssertionError: FAIL: empty check inputs accepted by engine, js_test, lean_style
```

Controls: real lean-style plants 4/4 fired; real palette contrast plant fired; real engine-panic plant fired. Thus the zero-input outputs are not missing-tool errors. Logs: `empty-{engine,js_test,lean_style,js_format}.log`.

Fix → assert each required source/test selection nonempty before its checker; Node stages also require executed tests.

## reviewer-43-F2 — mutation-credit checker has no registered positive control

Severity = **minor**. Anchor = `tools/gate-probe.sh:485`, distinctive bytes:

```text
probes=(lean_style fanout meta trust capability
```

Contract = `.claude/rules/ops.md` Probes + Engineering deterministic checks: every purpose-built check ships a planted failing input + its own named cause. `.claude/rules/lean.md:20` identifies `tools/mutate.mjs` as the purpose-built mutation-credit checker. No probe invokes or references it; the complete default catalog above has no mutation group. The recorded hand checks/campaigns in `units.md` do not provide a maintained probe of the checker. F31 (raw-string mask) is already known; this finding is the missing required calibration, not a second report of that defect.

Text proof with positive control:

```sh
python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-43/red-mutation-probe.py
```

Observed rc 1:

```text
control: scale probe definitions = 1 (expected 1)
mutation tool probe references = 0 (expected at least 1)
AssertionError: FAIL: purpose-built mutation-credit checker has no registered planted failing input
```

Independent `rg` rematch: `probe_scale` definition count = 1, rc 0; `rg -n 'mutate[.]mjs|probe_mutat' tools/gate-probe.sh` = no matches, rc 1. No mutation campaign run.

Fix → register a mutation-tool probe with a deliberately uncovered mutation that must yield its named survivor/failure; pair with covered + invalid-mutant controls and source restoration.

## reviewer-43-F3 — trust cache omits the replay consumer

Severity = **major**. `tools/trust.sh:37–41` (`replay_key`), anchor at line 40:

```text
cat examples/fvtrace/trace.json TrustMain.lean tools/statement.sh | sha256sum;
```

Contract = brief check (5), ops.md trust stage + Engineering verification integrity: a skipped result must be keyed by every input that changes its verdict. The same key gates both independent-kernel replay and `statements`, but the latter runs `.lake/build/bin/fvtrace verify --run`. Neither that binary nor its replay-consumer implementation is in the key. Changes outside the exported proof closure leave the key unchanged even when the skipped check would fail.

Red command:

```sh
python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-43/red-trust-key.py
```

The script first checks the base's **existing real passing record**; it never manufactures a passing key. Plant = flip the digest equality in `Fvtrace/Replay.lean`'s `reasons`; rebuild the native binary; run the owning trust stage, then force its skipped `statements` function. Observed rc 1:

```text
control: copied base has a matching passing replay key
planted replay consumer: trust stage rc=0
trust: 26 proofs; this export already passed every kernel + the self-trace statement replays (key 77722280a3a7): skipped
same planted binary: direct statements rc=1
0 of 12 replay(s) passed.
AssertionError: FAIL: trust cache skipped self-trace replays after their consumer changed; direct replay fails
```

Every direct replay reports `failed (output changed)`. Logs = `red-trust-key.log`, `trust-key-stage.log`, `trust-key-statements.log`, `trust-key-build.log`. Source + original binary bytes restored; restored library rebuild passed. The script forces native relinking and rebuilds restored library artifacts, so a rerun does not depend on a prior plant's build cache.

Fix → key statement-replay reuse on the exact native replay consumer + verifier dependencies, or cache only the independent-kernel replay and rerun statements separately. Add this omitted-input plant to `trust_cache`.

## Evidence + coverage limits

### Probe catalog adjudication

`run N/N` = every `expect`/`allow` in that single selected group passed, invocation rc 0. `read` = every plant/command/cause/restoration path inspected; runtime firing **not confirmed here**.

| group | verdict | basis |
|---|---|---|
| lean_style | pass | run 4/4: tab, trailing space, length, newline |
| fanout | pass | run 5/5: unsharded stage, missing matrix shard, wrong/commented/heredoc gate step |
| meta | pass | run 1/1: Lake version differs |
| trust | known F30, F35 | read 4 plants: unproved claim, axiom, partial/opaque, vacuity; known constructor + Prop-alias gaps |
| capability | pass | read 3 plants; no new security analysis |
| replay_policy | pass | run 3/3: missing required kernel, optional rejection, permitted decline |
| trust_cache | reviewer-43-F3 | run 3/3 existing controls; omitted-consumer red above |
| audit | pass | run 4/4: Lake package, open advisory, residual now fixed, registry error |
| vendor | pass | run 2/2: edited digest, unpinned file |
| cli | pass | read stub unsets FVTRACE_HOME; smoke demands its own named data-folder failure |
| lean_pure | pass | run 1/1: FFI call rejected by interpreted runner |
| palette | pass | run 1/1: contrast plant |
| assets | pass | read 2 plants: verdict word drift, malformed skill example |
| engine | pass | run 1/1: panic beside byte-correct engine answer |
| examples | pass | run 1/1: changed proof stales P6's receipt |
| wasm | pass | read 4 plants: manifest, missing import, link warning, changed build step |
| scale | known F21 | read 17 controls + grading branches; known session exit + stale details-timer gaps |
| compare | known F21 | read 5 controls + parity branches; known ignored oracle rc/stderr + jq failures |
| release | pass | read 5 controls: package, digest, version, license, glibc floor; macOS/Windows floors not run here |
| locks | pass | read 2 half-version bumps + their owning checks |
| dispatch | known F29 | existing unexecuted-selection/function-rc defect; not re-reported |
| mutation tool | reviewer-43-F2; known F31 | omitted probe; known raw-string masking defect |

- No full gate, full probe suite, mutation campaign, timing assertion run, browser session, release build, or remote operation. Expensive groups above judged from source; their runtime firing remains unconfirmed here. Known findings F21 + F29–F36 were read before the target; no new finding repeats them. F33's C-header build-trace gap remains known, outside the upstream JS/shell/scanner input plants.
- `.agent/spec-lint` is explicitly classed upstream in ops.md Probes; additionally driven here: `Tasks` → `PlantedTasks` on a private spec copy gives rc 1, named section cause; untouched spec gives rc 0.
- `check-coverage.py {oxlint,types,type-flags,prettier,shell,stylelint,html}` restores every byte in `finally`. Oxlint emitted 32 restricted-property diagnostics. Type-flags plants at one file per config emitted `number | undefined`, `exactOptionalPropertyTypes`, and implicit-any errors in all three configs. Shell's first plant form executed while sourcing gate.sh, so that attempt was invalidated; inert function-form rerun gave 18/18 SC2086 diagnostics.
- `check-scanners.py`: all four workflows receive an actionlint context error, then a zizmor unpinned-use error; owning stage rc 1 + every target named. Inert fake tokens only, live validation off: a deleted historical token is detected through history (two-commit fixture); hidden untracked file detected through the working-file command (rc 123 from xargs). This tests scope, not the production history's contents.
- Restore proof: `tools/gate-probe.sh:26` compares restored sha256; line 34 runs restore on EXIT. `red-probe-signal.py` stalled the owning layout checker after a source plant, sent TERM, observed `probe TERM rc=-15; restored=True`, then removed its child process group. Present source + absent vendor file controls restored clean. The engine probe's post-run whole-copy diff briefly saw the independent replay-consumer plant, not an engine-probe leak; the replay red then restored it and the final copy diff passed.
- LSP `documentSymbol` on actual `tools/mutate.mjs` succeeded.

## Register

None.
