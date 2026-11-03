# reviewer-43 — V-gate

Target = `48bc51d`, frozen `/home/eturkes/Projects/fvtrace/.scratch/review-base`; check set = brief's five V-gate checks + LENSES.md § V. Read-only target; plants = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-43/`.

| row | target | verdict | basis |
|---|---|---|---|
| V-gate | purpose-built checks ↔ probes (each has one, cause named) | unknown | unknown |
| V-gate | probe restore + re-hash | unknown | unknown |
| V-gate | upstream tool configs reach their files | pass | 32/32 JS/MJS plants: oxlint DOM sink (32 causes), tsc strict assignment, Prettier; 18/18 shell plants: SC2086; CSS specificity + HTML close-order fire; actionlint + zizmor name 4/4 workflows; betterleaks detects deleted historical + hidden untracked fake tokens; pnpm audit policy probes 4/4. |
| V-gate | stages that cannot fail / empty inputs | reviewer-43-F1; known F21, F29 | Empty-input red: engine + js-test report 0 tests, rc 0; lean-style has 0 Lean files, rc 0. js-format correctly rejects empty input (pipeline rc 1). Known failure-discard paths = F21 + F29. |
| V-gate | trust skip key | unknown | unknown |

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

Controls: real `lean_style` plants 4/4 fired; real palette contrast plant fired; the real engine-panic plant fired. Thus the zero-input outputs are not missing-tool errors. Logs: `empty-{engine,js_test,lean_style,js_format}.log`.

Fix → assert each required source/test selection nonempty before invoking its checker; Node stages also require executed tests.

## Evidence

- Probe catalog: 20 groups, 69 `expect`/`allow` rows. Static read covers every plant, owning command, cause regex, and `keep`/restore path.
- Single groups run so far: `lean_style` 4/4; `fanout` 5/5; `meta` 1/1; `replay_policy` 3/3; `trust_cache` 3/3; `vendor` 2/2; `palette` 1/1; `audit` 4/4; `engine` 1/1. Each group invocation rc 0. No full probe suite or gate run.
- Coverage harnesses: `check-coverage.py {oxlint,types,prettier,shell,stylelint,html}`; `check-scanners.py`. Each harness restores target bytes in `finally`; logs = `coverage-*.log`. Shell plant's first form executed while sourcing gate.sh, so that attempt was invalidated; inert function-form plant rerun → 18/18 SC2086 diagnostics.
- `check-scanners.py`: each of four workflows receives an actionlint context error, then a zizmor unpinned-use error; stage rc 1 and every target named. Inert fake token only, validation off: a token removed from a committed fixture remains detected through history; hidden untracked file detected through the working-file command (rc 123 from xargs).
- LSP `documentSymbol` on actual `tools/mutate.mjs` succeeded (JS/MJS coverage).

## Register

None.
