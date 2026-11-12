# reviewer-34 — K-scale + K-release

Target: frozen base `48bc51d`, `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Fixed checks: Cleanup + Altitude, one pass per lens and slice. Contract: `CLAUDE.md` Engineering code-diff lenses; `.agent/review/LENSES.md` § K.

| row | target | verdict | basis |
|---|---|---|---|
| K-scale | Cleanup: scale.mjs + scale.sh + compare.sh | reviewer-34-F1, reviewer-34-F2 | Read all three files; repository helper/caller search; duplicate comparison loops + three shape catalogs anchored. Timing serialization retained: idle-host measurements; timeout/temp boilerplate differs by runner purpose. |
| K-scale | Cleanup: scale-gui.mjs + scale-page.mjs | reviewer-34-F3 | Read both drivers + e2e launcher + engine case helpers; spawn/link/stop is implemented twice. Page driver already reuses engine/block helpers; its row format + CPU/RSS measurements differ legitimately. |
| K-scale | Altitude | pass | Separate pass over all five tools + caller/contracts: shape-specific actions/items are fixture definitions; deep gaps exemption + v1/v2 normalization are explicit P-time/V-cli requirements, not one-caller workarounds in generic infrastructure. |
| K-release | Cleanup: release.sh + tools/release/* | pass | Read script + both license artifacts; traced every helper + artifact to callers. package/check share archive/digest helpers; platform floor bodies need different tools; no dead definition, parameter or license file found. Tiny portable-shell primitives do not justify coupling standalone entry scripts. |
| K-release | Cleanup: workflows + actionlint.yaml + renovate.json + tests/renovate | reviewer-34-F4 | Read four workflows + actionlint/Renovate config/test; bootstrap/cache recipe duplicated. Inputs/env/cache output all used; Renovate rules reach current pins; extraction test rc 0; actionlint from base root rc 0. |
| K-release | Altitude | pass | Separate pass: release input's scratch-build/archive semantics + installed job's distinct macOS floor are explicit release.md rulings; platform floor logic uses native mechanisms. actionlint exceptions are narrow upstream compatibility adapters, not consumer quirks in common helpers. |

## Findings

### reviewer-34-F1 — minor — comparison witness logic duplicated

- Location: `tools/compare.sh:34–49` + `:74–95` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: existing helpers reused; near-duplicate blocks merged; elegant, tightly-scoped modular components.
- Proof: `cmp_run` and `cmp_json` both execute the old/new pair, strip usage suffixes, increment `runs`, compare the three result components, increment `diffs`, print the same DIFF line + bounded diff. The entire six-line result loop differs only in `out` versus `json` as its first component. The JSON path's legitimate extra operation is normalization between execution and comparison; it does not require duplicating the witness emitter.
- Exact anchors: `for out in out err rc; do` (`:42`), `for out in json err rc; do` (`:88`), `diff <(head -c 2000` (`:45`, `:91`). Reproduce: `rg -Fn 'for out in' /home/eturkes/Projects/fvtrace/.scratch/review-base/tools/compare.sh`; `rg -Fn 'diff <(head -c 2000' /home/eturkes/Projects/fvtrace/.scratch/review-base/tools/compare.sh`.
- Fix: one old/new comparison pipeline + optional normalization hook; one component-comparison/witness helper. Keep raw/normalized semantics, stdout/stderr/rc checks + probe coverage unchanged; known correctness findings remain separate.

### reviewer-34-F2 — minor — supported shape catalog copied into both consumers

- Location: `tools/scale.mjs:166–347`, `tools/scale.sh:52`, `tools/compare.sh:123–124` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: derivable state computed, never duplicated; near-duplicate blocks merged.
- Proof: the generator's `shapes` keys are the twelve supported shapes; both drivers carry the same twelve-name catalog manually. `scale.sh`'s default set and `compare.sh`'s promised every-shape coverage are derivable from that registry. Each new generator shape requires matching changes in both shell consumers; no shared list exists (searched `tools/`, `tests/`, `web/`, `.github/`, Lean callers).
- Exact anchors: `const shapes = {` (`scale.mjs:166`); `shapes=(wide deep experiments exclusions hub questions waivers receipts outcomes prereqs whatif invalid)` (`scale.sh:52`); `for shape in wide deep experiments exclusions hub questions waivers receipts outcomes prereqs whatif` (`compare.sh:123`). Reproduce with `rg -Fn` on the three named files.
- Fix: expose the generator registry's shape names through a side-effect-free list API/CLI; both shell drivers read that one source. Preserve explicit graded/F5 sets + every existing generated shape, size and check.

### reviewer-34-F3 — minor — timing driver forks the e2e server lifecycle

- Location: `tools/scale-gui.mjs:244–259`, `:270–297`; `tests/e2e/fvtrace-server.js:92–123` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: existing helpers reused; near-duplicate blocks merged.
- Proof: both spawn the same `serve --port 0 --no-browser` process, buffer stdout until a link is present, reject a pending link on `exit`, then close by observing `exitCode`/`signalCode`, subscribing with `once(server, "exit")`, killing + awaiting it. Only fixture arguments, printed-link parsing breadth + consumer cleanup policy differ. `scale-page.mjs` has no server launcher; it already imports its engine/block helpers rather than duplicating them.
- Exact anchors, each matches both source files: `server.stdout.on("data"` (`scale-gui:290`, `fvtrace-server:99`); `const exited = once(server, "exit");` (`scale-gui:247`, `fvtrace-server:114`). The rejection anchors are `server.on("exit", () => reject` (`scale-gui:295`) and `server.on("exit", (code) => reject` (`fvtrace-server:107`). Reproduce with `rg -Fn` on the two files; the first two anchors each return two matches.
- Fix: extract a neutral, configurable process/link/close helper shared by the timing tool + e2e harness; leave browser/signal ownership + study/temp-folder setup with their consumers. Preserve timing boundaries, e2e worker cleanup and timing driver's forced-kill behavior. This is duplication evidence, not a re-report of the known spawn-error correctness finding.

### reviewer-34-F4 — minor — page-engine CI bootstrap recipe copied across workflows

- Location: `.github/workflows/gate.yml:49–75`; `.github/workflows/build.yml:44–63` at `48bc51d`.
- Contract: `CLAUDE.md` Engineering → Cleanup: near-duplicate blocks merged; derivable state computed, never duplicated. `.claude/rules/wasm.md` CI cache binds both implementations to one cache recipe.
- Proof: both install the same pinned Python, restore the same two cache path patterns under the same content-key expression, then delete partial restore state when `cache-hit != 'true'`. The actual differences are caller eligibility (`checks` shard versus release build) + an explicit Bash shell on the cross-platform caller. The cache path, key inputs, Action pins, Python pin and partial-restore procedure each have two independent edit sites. No composite action exists under `.github/`; `build.yml` already shares the platform build, not this gate/build prerequisite recipe.
- Exact anchors: `python-version: "3.15.2"` (`gate:53`, `build:47`); `key: engine-${{ runner.os }}-${{ runner.arch }}-` (`gate:69`, `build:58`); `run: rm -rf .lake/build/wasm` (`gate:75`, `build:63`). `rg -Fn` over the two files matches each anchor twice. The whole cache key is byte-identical, including all five hashFiles inputs.
- Fix: one repository-local engine-bootstrap composite action (or equivalent shared step mechanism), caller-supplied cache eligibility; retain the exact key, paths, partial-restore cleanup and Python pin. Keep release/schedule cache exclusion + cross-platform Bash semantics unchanged. Ordinary checkout steps and thin calls to the already-shared `tools/install-lean.sh` are not additional findings.
- Cost/acceptance: actionlint + zizmor must both remain green on the new action + all entry workflows; the new structure must preserve the existing cache-poisoning planted control and every gate shard. Existing base actionlint passed from the base root; no candidate refactor or zizmor run was performed here.

## Register

None.

## Coverage

- 6/6 fixed rows adjudicated; Cleanup + Altitude each completed over both slices. Every target file read in full; helper/caller searches included `tools/`, `tests/`, `web/`, `.github/`, Lean sources + Lakefile. Related law + contracts read; base stayed unchanged; only this deliverable written.
- Checks passed: textual anchors matched on the frozen base; stdlib static corroboration → two byte-identical comparison result bodies, three ordered-equal twelve-name catalogs, two byte-identical engine cache keys, rc 0; `node --test --test-reporter=dot /home/eturkes/Projects/fvtrace/.scratch/review-base/tests/renovate/renovate.test.mjs` → one test marker, rc 0; actionlint over all four target workflows from the base root with its config → rc 0.
- Initial actionlint invocation from the primary root → rc 1, two `workflow-call` diagnostics for the supported `$/` form. Cause: paths rendered as `.scratch/review-base/.github/...`, outside the config's `.github/workflows/**/*.yml` ignore scope. Re-run from the base root → rc 0; invocation error, not a target finding.
- Not run: full gate, timing sweep, release packaging/publishing, browser/server, zizmor, strict Renovate validator or local lookup. No runtime-performance or refactor-correctness claim. Hosted Renovate option validity/resulting update grouping unconfirmed; inspected `renovate.json`, matched its extraction inputs + ran the extraction test only. No behavioral findings/red tests; all four findings are anchored duplication under K.
- No target sampling/search truncation; the bounded platform-helper search returned fewer rows than its cap. No server started or scratch artifact created.
- Known correctness findings excluded per brief: scale session exit ordering; stale details timer; compare rc/stderr and malformed JSON oracles; scale-gui spawn-error cleanup; extra release archive guard; release trap quoting.

reviewer-34-DONE-1
