# reviewer-33 — K-gate at `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| K-gate | Cleanup: gate.sh + fast-gate.sh + ci-gate.sh | reviewer-33-F1, reviewer-33-F2 | Shared checks reused; fast metadata duplicates derivable names/complement; full/check runners serialize independent read-only checks. CI wrapper otherwise pass. |
| K-gate | Cleanup: gate-probe.sh | reviewer-33-F3 | Probe-specific plants reuse keep/restore/build helpers; expect/allow duplicate execution + accounting + restore policy. |
| K-gate | Cleanup: trust.sh + statement.sh + TrustMain.lean | pass | Read all three; closure/meaningDeps + replay policy/key/cache are reused; all helpers have callers; distinct statement/full-proof closures intentional. |
| K-gate | Cleanup: fetch/pin/install/vendor scripts + tools.lock + e2e-load + lean-style + mutate.mjs | reviewer-33-F4, reviewer-33-F5 | Sizing unnecessarily writes its source; portable SHA helper duplicated across tool scripts. Other helpers/caches/pins used. |
| K-gate | Cleanup: test harness + lakefile + configs + package.json + .gitignore | reviewer-33-F6 | Harness + target wiring reused; all 13 dev dependencies consumed; root/e2e TS policy repeats exactly. No proved-dead config/ignore key. |
| K-gate | Altitude | pass | Separate second pass: OS portability, embed tracing, replay policy, probe-specific fixtures + config consumers fit their mechanisms; no additional caller-specific workaround to block. |

## Findings

### reviewer-33-F1 — minor — fast-gate metadata repeats computable state

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/fast-gate.sh:16` (+ `:47–48`); mechanism already at `tools/gate.sh:271`.
- Contract: `CLAUDE.md` Engineering → Cleanup: derivable state computed, never duplicated; existing helpers reused.
- Proof: `fast-gate.sh:15` has nine stage names; `:16` repeats the same list after `-` → `_`, although `gate.sh:271` already derives each function by `${name//-/_}`. `fast-gate.sh:47–48` additionally stores the skipped-stage list = `STAGES` minus the selected stages, so stage inventory + function mapping + reporting need separate maintenance.
- Anchor commands (base): `rg -Fn 'fns=(lean_style js_format js_lint js_types js_test fanout spec shell meta)' tools/fast-gate.sh` → `16`; `rg -Fn 'stage "$name" "${name//-/_}"' tools/gate.sh` → `271`; `rg -Fn 'skipped="tools trust c-analyze vendor audit secrets workflows"' tools/fast-gate.sh` → `47` (each rc 0).
- Fix direction: keep one fast-stage selection; derive function names + skipped complement through the full gate's stage registry.
- Acceptance: full + fast stage selections, function routing, skip report + output ordering unchanged; one representation of each derived mapping/complement.

### reviewer-33-F2 — minor — independent checks remain serial on the full-gate path

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/gate.sh:268–272` (+ `:113–125`).
- Contract: `CLAUDE.md` Engineering → Cleanup: independent steps parallel; Execution: gates block the critical path, speedups keep every check + firing behavior.
- Proof: the full/checks-shard loop calls `stage` synchronously for every row. Its `lean-style`, `js-format`, `js-lint`, `js-types`, `js-test`, `fanout`, `spec`, `shell`, `meta` checks are read-only and already run concurrently by `fast-gate.sh:15–27`; the full gate serializes those same functions. Inside `js_types`, the three no-emit TS projects also run one after another (`:123`); `js_lint` serializes oxlint/stylelint/html-validate (`:115–117`). The full gate is the acceptance path and is rerun by e2e-load; fast-mode concurrency does not accelerate it.
- Anchors: `rg -Fn 'for row in "${rows[@]}"; do' tools/gate.sh` → `268`; `rg -Fn 'for p in . web tests/e2e; do tsc -p "$p" || rc=1; done' tools/gate.sh` → `123`; existing safe-concurrency implementation = `tools/fast-gate.sh:17–27`.
- Fix direction: share a dependency-aware check runner across full + fast gates; launch independent read-only checks concurrently, then print their buffered results + own wall-clock in stable order. Preserve tools/build dependencies, every stage, status + planted-failure detection.
- Limit: source-level scheduling proof; no full gate or wall-clock speedup measurement run in this review.

### reviewer-33-F3 — minor — probe result lifecycle implemented twice

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/gate-probe.sh:48–76`.
- Contract: `CLAUDE.md` Engineering → Cleanup: near-duplicate blocks merged; helpers reused.
- Proof: `expect` (`:48–61`) + `allow` (`:63–76`) both execute + capture argv, store rc, print a result, increment `passed` or append to `failures`, tail a failed check's output, then `restore`. The intended difference is a predicate (nonzero + named cause versus zero) + wording, yet accounting and restoration are separately implemented. A lifecycle change must be applied twice.
- Distinctive anchors: `rg -Fn 'out="$("$@" 2>&1)"' tools/gate-probe.sh` → `51,66`; `rg -Fn 'passed=$((passed + 1))' tools/gate-probe.sh` → `55,70`; `rg -Fn 'failures+=("$name")' tools/gate-probe.sh` → `58,73`; `rg -Fn '    restore' tools/gate-probe.sh` → `60,75` (all rc 0).
- Fix direction: keep `expect`/`allow` as readable thin wrappers; share command execution, outcome accounting + restoration in one adjudicator parameterized by the expected result.
- Acceptance: each existing probe and negative control keeps its predicate, named cause, messages + restore semantics; one lifecycle implementation.

### reviewer-33-F4 — minor — `--list` pays the mutation write/restore lifecycle

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/mutate.mjs:39–43,150–151`.
- Contract: `CLAUDE.md` Engineering → Cleanup: startup/hot paths do only the work their result needs; lens K explicitly covers unnecessary work.
- Proof: site enumeration is pure over `original`, but the script writes its backup before enumeration, installs mutation signal handlers, and its `--list` branch calls `restore()` (rewrites the input) before printing sites. Sizing requires none of those mutations; it changes a source's mtime even with zero mutants applied. The proposed cleanup preserves the site's output + rc.
- Anchors: `rg -Fn 'writeFileSync(backup, original);' tools/mutate.mjs` → `40`; `rg -Fn '  writeFileSync(file, original);' tools/mutate.mjs` → `42`; `rg -Fn 'if (values.list) {' tools/mutate.mjs` → `150`; its immediate `restore()` is `:151` (rc 0).
- Red test: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-33/red-list-readonly.py` → rc 1. Positive control first: command rc 0, `1 → 2`, `mutants: 1`, source bytes unchanged. Failing output: `source mtime before=1000000000, after=1793668810436509929`; `AssertionError: FAIL --list rewrote the source although it only enumerates mutant sites`. Log: `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-33/red-list-readonly.log`.
- Fix direction: enumerate + return under `--list` before creating the backup or installing the campaign's handlers; retain the write/restore lifecycle for actual campaigns.
- Acceptance: the red test passes; site list/count + exit code unchanged; sizing creates no backup and never writes its input. No mutation campaign run here.

### reviewer-33-F5 — minor — portable SHA selection/digest helper repeated

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/fetch-tools.sh:24–30`; matching existing helper = `tools/release.sh:25–28`; command selection repeated again at `tools/pin-wasm.sh:17`.
- Contract: `CLAUDE.md` Engineering → Cleanup: existing helpers reused; near-duplicate blocks merged.
- Proof: fetch + release independently implement the same function named `sha256`: choose `sha256sum`, else `shasum -a 256`, hash one file, cut the digest field. pin-wasm makes that same tool-selection decision again before hashing archives + manifests. No common source-only tools helper exists (all `tools/` paths enumerated; repo-wide shell search for `^sha256\(\)|shasum -a 256` finds these three implementations).
- Anchors: `rg -Fn 'shasum -a 256' tools/fetch-tools.sh tools/release.sh tools/pin-wasm.sh` → `fetch-tools.sh:28`, `release.sh:26`, `pin-wasm.sh:17` (rc 0); the full paired blocks are the line ranges above.
- Fix direction: share portable SHA command selection + file-digest extraction through a source-only tools helper; keep pin-wasm's full manifest-line format where required, and preserve all current digest checks.
- Acceptance: same file digests + lock/manifest bytes on sha256sum and shasum hosts; one implementation of portable tool selection/file digest.

### reviewer-33-F6 — minor — identical compiler policy copied between TS configs

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tests/e2e/tsconfig.json:2–14`; original block = `tsconfig.json:2–14`.
- Contract: `CLAUDE.md` Engineering → Cleanup: near-duplicate blocks merged; derivable state computed, never duplicated.
- Proof: the root + e2e configs repeat all 11 compiler-option keys and values exactly. Their only difference is `include`. Both are independently invoked by `tools/gate.sh:123`; policy changes need two edits. The web config's genuinely different browser resolution/libs remain intentional.
- Anchor: `rg -Fn '"exactOptionalPropertyTypes": true,' tsconfig.json tests/e2e/tsconfig.json` → both `:8` (rc 0).
- Equality command: `cmp -s <(jq -S '.compilerOptions' /home/eturkes/Projects/fvtrace/.scratch/review-base/tsconfig.json) <(jq -S '.compilerOptions' /home/eturkes/Projects/fvtrace/.scratch/review-base/tests/e2e/tsconfig.json)` → rc 0; `jq '.compilerOptions | keys | length' .../tsconfig.json` → `11`. Own-copy `node_modules/.bin/tsc --showConfig -p .` + `... -p tests/e2e` both rc 0, normalized effective compilerOptions `cmp` rc 0 (saved under reviewer-33 scratch).
- Fix direction: make e2e extend the root config and keep its own `include`, or move their common policy to one base config.
- Acceptance: normalized effective options + covered file sets unchanged for each gate invocation.

## Register

None. Known `mutate.mjs --help` defect excluded.

## Coverage

- Check set fixed before target read: K-gate Cleanup + Altitude; 6/6 seeded rows adjudicated. First pass = all assigned files read in full (tool lock: all 17 data entries inspected); second = abstraction/exception + caller pass over the same slice. `.agent/spec-lint` read only, as required for its shared-template status.
- Base = `/home/eturkes/Projects/fvtrace/.scratch/review-base`, revision `48bc51d`; source untouched. Own executable copy = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-33/tree`. No nested agents, git operations, server, mutation campaign or target build.
- Checks passed: individual `bash -n` on all 12 assigned shell scripts; `sh -n .agent/spec-lint`; `node --check tools/mutate.mjs`; both `tsc --showConfig` calls + source/effective compilerOptions equality; all finding anchors rematched. LSP coverage confirmed on own-copy `tools/mutate.mjs`.
- Red: F4 sizing rewrite witness, rc 1 with a positive `mutants: 1` control. F1/F2/F3/F5/F6 are source-anchored cleanup findings, not allegations of changed verdict/check output.
- Not run: full/fast/CI gate, probe suite, native/Lean suites, network downloads/re-pins, macOS/Windows execution, timing benchmarks. No measured acceleration claimed. All 13 package dependencies have direct consumers or typed-tool integrations; no package scripts exist. Ignore entries for upstream Playwright reporter outputs retained as supported tool outputs, not judged dead from the currently selected line reporter.
- Limits: shell helper deadness checked by source references across tools/tests/configs/workflows; dynamic CLI entry points retained. No unconfirmed behavioral finding. Parallel scheduling + SHA fallback preservation need their acceptance checks when fixed.

reviewer-33-DONE-1
