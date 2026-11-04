#!/usr/bin/env bash
# Positive controls for the purpose-built checks (upstream tools carry their own suites): each
# probe plants one failing input, runs the owning check, and demands a nonzero rc whose output
# names the expected cause. Targets are restored after every probe + on exit, then re-verified by
# sha256. Usage: tools/gate-probe.sh [probe...] (default: all). `git status --porcelain` after a
# run = the restore check.
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 1
export PATH="$root/.tools/bin:$root/node_modules/.bin:$PATH"
# shellcheck source=tools/gate.sh
source tools/gate.sh
# shellcheck source=tools/trust.sh
source tools/trust.sh

backup="$(mktemp -d)"
declare -A saved=()
restore() {
    local f
    for f in "${!saved[@]}"; do
        if [[ "${saved[$f]}" == absent ]]; then
            rm -f "$f"
        else
            cp --preserve=mode "$backup/$(printf '%s' "$f" | tr '/' '_')" "$f"
            [[ "$(sha256sum "$f" | cut -d' ' -f1)" == "${saved[$f]}" ]] || {
                printf 'probe: %s did not restore\n' "$f" >&2
                exit 3
            }
        fi
    done
    saved=()
}
trap 'restore; rm -rf "$backup"' EXIT
keep() {
    local f="$1"
    if [[ -e "$f" ]]; then
        cp --preserve=mode "$f" "$backup/$(printf '%s' "$f" | tr '/' '_')"
        saved[$f]="$(sha256sum "$f" | cut -d' ' -f1)"
    else
        saved[$f]=absent
    fi
}

passed=0
failures=()
# One probe: runs the command, checks its result against the wanted one, counts it, restores every
# planted target. `pattern` empty = a negative control (the command must pass).
probe() {
    local name="$1" pattern="$2" out rc
    shift 2
    out="$("$@" 2>&1)"
    rc=$?
    if [[ -z $pattern && $rc -eq 0 ]]; then
        printf 'probe %s: passed as expected\n' "$name"
        passed=$((passed + 1))
    elif [[ -n $pattern && $rc -ne 0 ]] && grep -q -E -- "$pattern" <<<"$out"; then
        printf 'probe %s: fired (rc=%d)\n' "$name" "$rc"
        passed=$((passed + 1))
    else
        printf 'probe %s: %s (rc=%d)\n%s\n' "$name" \
            "$([[ -z $pattern ]] && echo 'FAILED a valid input' || echo 'DID NOT FIRE')" "$rc" \
            "$(tail -5 <<<"$out")" >&2
        failures+=("$name")
    fi
    restore
}
# expect <probe> <regex> <command...>: the command must fail with output matching regex.
expect() { probe "$@"; }
# allow <probe> <command...>: a negative control; the command must pass.
allow() { probe "$1" "" "${@:2}"; }

# A build failure prints its errors, so a plant that no longer compiles reads as such.
trust_build() { lake build Fvtrace «fvtrace-trust» 2>&1 | grep -E '^error' ; lake exe fvtrace-trust; }
# Fvtrace/Proofs.lean imports the Spec submodules alone; a proof of a claim planted in the
# aggregate Fvtrace/Spec.lean needs that module imported.
plant_import() { sed -i '1i import Fvtrace.Spec' Fvtrace/Proofs.lean; }

probe_lean_style() {
    keep Fvtrace/Version.lean
    printf '\tdef plantedTab : Nat := 0\n' >>Fvtrace/Version.lean
    expect lean-style-tab 'tab$' lean_style
    keep Fvtrace/Version.lean
    printf 'def plantedTrailing : Nat := 0 \n' >>Fvtrace/Version.lean
    expect lean-style-trailing 'trailing whitespace' lean_style
    keep Fvtrace/Version.lean
    printf 'def plantedLong : String := "%s"\n' "$(printf 'x%.0s' {1..90})" >>Fvtrace/Version.lean
    expect lean-style-long 'longer than 100' lean_style
    keep Fvtrace/Version.lean
    printf 'def plantedNoNewline : Nat := 0' >>Fvtrace/Version.lean
    expect lean-style-newline 'no final newline' lean_style
}

# CI runs one job per gate.yml matrix shard: a stage without a shard, a shard the matrix lacks, or
# a job that never runs its shard would leave stages unrun in CI.
# The cross-workflow relations (gate.sh `provision`, run by fanout): one plant per relation.
probe_provision() {
    keep .github/workflows/build.yml
    sed -i '/^          - os: windows-2025$/,/^            target: windows-x86_64$/d' .github/workflows/build.yml
    expect provision-targets 'build.yml targets \[linux-arm64,linux-x86_64,macos-arm64\] != release targets' fanout
    keep .github/workflows/release.yml
    sed -i 's/^          - os: macos-15$/          - os: macos-26/' .github/workflows/release.yml
    expect provision-macos 'runs macos-arm64 on macos-26, not macos-15' fanout
    keep .github/actions/page-engine/action.yml
    sed -i '/uses: actions\/setup-python@/d' .github/actions/page-engine/action.yml
    expect provision-python 'action.yml installs no Python' fanout
    keep .github/actions/page-engine/action.yml
    sed -i "s/, 'FvtraceWasm\/\*\*'//" .github/actions/page-engine/action.yml
    expect provision-cache-key 'engine cache key lacks FvtraceWasm/\*\*' fanout
    keep .github/workflows/gate.yml
    sed -i "s/^        if: matrix.shard != 'checks'$/        if: matrix.shard != 'lean'/" .github/workflows/gate.yml
    expect provision-skip 'skips Python \+ the engine cache on shard lean, which builds' fanout
    keep .github/workflows/build.yml
    sed -i 's/cache: ${{ !inputs.release \&\& /cache: ${{ /' .github/workflows/build.yml
    expect provision-release-cache 'build.yml caches the engine on a release' fanout
    keep .github/workflows/build.yml
    sed -i '/uses: \$\/.github\/actions\/page-engine$/d' .github/workflows/build.yml
    expect provision-order 'build.yml builds without the page-engine step before it' fanout
}

probe_fanout() {
    local table="$STAGES"
    STAGES+=$'planted\n'
    expect fanout-unsharded 'fanout: stage planted has no CI shard' fanout
    STAGES="$table"
    keep .github/workflows/gate.yml
    sed -i -E 's/^( +shard: \[)lean, /\1/' .github/workflows/gate.yml
    expect fanout-matrix 'matrix shards \[checks,e2e\] != tools/gate.sh shards \[checks,e2e,lean\]' fanout
    keep .github/workflows/gate.yml
    # `$SHARD` = the workflow's literal step text
    # shellcheck disable=SC2016
    sed -i 's/--shard "\$SHARD"/--shard lean/' .github/workflows/gate.yml
    # shellcheck disable=SC2016
    expect fanout-step 'runs no single `bash tools/gate.sh --shard "\$SHARD"` step' fanout
    keep .github/workflows/gate.yml
    # shellcheck disable=SC2016
    sed -i 's/run: bash tools\/gate.sh --shard "\$SHARD"/run: echo skipped # &/' .github/workflows/gate.yml
    # shellcheck disable=SC2016
    expect fanout-step-comment 'runs no single `bash tools/gate.sh --shard "\$SHARD"` step' fanout
    keep .github/workflows/gate.yml
    # shellcheck disable=SC2016
    sed -i 's/^\( *\)run: bash tools\/gate.sh --shard "\$SHARD"$/\1run: |\n\1  cat <<'\''LABEL'\''\n\1  run: bash tools\/gate.sh --shard "$SHARD"\n\1  LABEL/' \
        .github/workflows/gate.yml
    # shellcheck disable=SC2016
    expect fanout-step-heredoc 'runs no single `bash tools/gate.sh --shard "\$SHARD"` step' fanout
}

probe_meta() {
    keep lakefile.lean
    sed -i 's/^  version := v!".*"$/  version := v!"9.9.9"/' lakefile.lean
    expect meta-version 'meta: .* != lakefile.lean version "9.9.9"' meta
    keep README.md
    sed -i "s/^| Linux on ARM64, with glibc 2\\.17/| Linux on ARM64, with glibc 2.16/" README.md
    expect meta-glibc-floor 'meta: README promises glibc 2.16; tools/release.sh checks 2.17' meta
    keep README.md
    sed -i 's/^| macOS 15 or later/| macOS 14 or later/' README.md
    expect meta-macos-floor 'meta: README promises macOS 14; tools/release.sh checks 15.0' meta
}

probe_trust() {
    # A plain `def` named like a generated equation lemma is still a claim.
    keep Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Spec\ndef eq_987654 : Prop := Fvtrace.version = "planted"\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    expect trust-unproven 'eq_987654: no proof' trust_build

    # The claim's type may reduce to Prop through either reducible or ordinary definitions.
    local alias name
    for alias in abbrev def '@[irreducible] def'; do
        case "$alias" in
            abbrev) name=trust-alias ;;
            def) name=trust-alias-def ;;
            *) name=trust-alias-irreducible ;;
        esac
        keep Fvtrace/Spec.lean
        printf 'namespace Fvtrace.Spec\n%s PlantedProp := Prop\ndef PlantedAlias : PlantedProp := by unfold PlantedProp; exact Fvtrace.version = "planted"\nend Fvtrace.Spec\n' \
            "$alias" >>Fvtrace/Spec.lean
        expect "$name" 'PlantedAlias: no proof' trust_build
    done

    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    plant_import
    printf 'namespace Fvtrace.Spec\ndef PlantedAxiom : Prop := Fvtrace.version = "planted"\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\naxiom planted : False\ntheorem plantedAxiom : Spec.PlantedAxiom := planted.elim\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-axiom 'uses axiom Fvtrace.Proofs.planted' trust_build

    keep Fvtrace/Version.lean
    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    plant_import
    printf 'namespace Fvtrace\npartial def plantedLoop (n : Nat) : Nat := plantedLoop n\nend Fvtrace\n' \
        >>Fvtrace/Version.lean
    printf 'namespace Fvtrace.Spec\ndef PlantedPartial : Prop := Fvtrace.plantedLoop 0 = Fvtrace.plantedLoop 0\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\ntheorem plantedPartial : Spec.PlantedPartial := rfl\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-escape-hatch 'reaches (partial|opaque) Fvtrace.plantedLoop' trust_build

    # The inductive's own type omits the constructor's opaque dependency.
    keep Fvtrace/Version.lean
    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    plant_import
    cat >>Fvtrace/Version.lean <<'PLANT'
namespace Fvtrace
opaque plantedCtorBound : Nat := 3
inductive PlantedCtorBox where
  | box : Fin plantedCtorBound → PlantedCtorBox
end Fvtrace
PLANT
    printf 'namespace Fvtrace.Spec\ndef PlantedCtor : Prop := ∀ x : PlantedCtorBox, x = x\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\ntheorem plantedCtor : Spec.PlantedCtor := by intro x; rfl\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-ctor 'reaches opaque Fvtrace.plantedCtorBound' trust_build

    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    plant_import
    printf 'namespace Fvtrace.Spec\ndef PlantedVacuous : Prop := 1 + 1 = 2\nend Fvtrace.Spec\n' >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\ntheorem plantedVacuous : Spec.PlantedVacuous := rfl\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-vacuous 'PlantedVacuous: statement reaches no shipped code' trust_build

    lake build Fvtrace «fvtrace-trust» >/dev/null 2>&1
}

probe_capability() {
    # Capabilities (security review F1, fvtrace-trust): a server route reading a file, a handle
    # opened with a mode passed in as a value, a listed capability no definition uses.
    keep Fvtrace/Server.lean
    printf 'namespace Fvtrace.Server\ndef plantedRead (p : System.FilePath) : IO String := IO.FS.readFile p\nend Fvtrace.Server\n' \
        >>Fvtrace/Server.lean
    expect trust-capability \
        'Fvtrace.Server: uses read outside the capability list \(Fvtrace.Server.plantedRead\)' trust_build
    keep Fvtrace/Server.lean
    printf 'namespace Fvtrace.Server\ndef plantedOpen (p : System.FilePath) (m : IO.FS.Mode) : IO IO.FS.Handle := IO.FS.Handle.mk p m\nend Fvtrace.Server\n' \
        >>Fvtrace/Server.lean
    expect trust-capability-mode \
        'Fvtrace.Server: uses write outside the capability list \(Fvtrace.Server.plantedOpen\)' trust_build
    keep TrustMain.lean
    # shellcheck disable=SC2016 # the backticks quote Lean names
    sed -i 's/^  \[(`Fvtrace.Cli, /  [(`Fvtrace.Engine, ["process"]), (`Fvtrace.Cli, /' TrustMain.lean
    expect trust-capability-unused \
        'Fvtrace.Engine: capability list names process, which it no longer uses' trust_build
    lake build Fvtrace «fvtrace-trust» >/dev/null 2>&1
}

probe_replay_policy() {
    local log="$backup/check.log" accepts
    accepts=$'Lean paranoid kernel accepts the solution\nlean4lean kernel accepts the solution\nnanoda kernel accepts the solution\nLean default kernel accepts the solution'
    printf '%s\n' "${accepts/lean4lean kernel accepts the solution/lean4lean kernel rejected the solution}" >"$log"
    expect replay-required-kernel 'lean4lean kernel did not accept' replay_policy "$log" 1
    printf '%s\ncon-leche kernel rejected the solution\n' "$accepts" >"$log"
    expect replay-optional-kernel-rejects 'con-leche rejected the export' replay_policy "$log" 1
    printf '%s\ncon-ron: declined: unsupported Nat.div/mod environment\ncon-ron kernel rejected the solution\n' \
        "$accepts" >"$log"
    allow replay-optional-kernel-declines replay_policy "$log" 1
}

# A passing record covers export + receipt consumer bytes; a missing consumer cannot key a pass.
probe_trust_cache() {
    local keyfile="$backup/replayed" export="$backup/export.ndjson" key
    printf '{"planted":1}\n' >"$export"
    key="$(replay_key "$export")"
    printf '%s\n' "$key" >"$keyfile"
    allow trust-cache-hit replay_cached "$keyfile" "$key"
    keep .lake/build/bin/fvtrace
    printf '\nplanted replay consumer\n' >>.lake/build/bin/fvtrace
    expect trust-cache-changed-consumer 'replay needed' \
        replay_cached "$keyfile" "$(replay_key "$export")"
    keep .lake/build/bin/fvtrace
    rm .lake/build/bin/fvtrace
    expect trust-cache-missing-consumer 'fvtrace: No such file' replay_key "$export"
    printf '{"planted":2}\n' >"$export"
    expect trust-cache-changed-export 'replay needed' replay_cached "$keyfile" "$(replay_key "$export")"
    rm -f "$keyfile"
    expect trust-cache-no-record 'replay needed' replay_cached "$keyfile" "$key"
}

probe_audit() {
    keep lake-manifest.json
    jq '.packages = [{"name": "planted"}]' lake-manifest.json >"$backup/m.json" && cp "$backup/m.json" lake-manifest.json
    expect audit-lake-packages 'lists Lake packages' audit
    local open fixed
    open='{"advisories":{"1":{"github_advisory_id":"GHSA-plnt-0000-0000","severity":"low","module_name":"planted","vulnerable_versions":"<2","patched_versions":">=2"}}}'
    fixed="${open/GHSA-plnt-0000-0000/${DEV_RESIDUALS[0]}}"
    expect audit-open-advisory 'GHSA-plnt-0000-0000 low planted' audit_policy <<<"$open"
    expect audit-residual-fixed 'now has a fix' audit_policy <<<"$fixed"
    expect audit-registry-error 'no advisory report' audit_policy <<<'{"error":{"code":"ERR_PNPM_AUDIT_BAD_RESPONSE"}}'
}

probe_vendor() {
    keep c/hacl/Hacl_Hash_SHA2.h
    printf '// planted\n' >>c/hacl/Hacl_Hash_SHA2.h
    expect vendor-edited-file 'Hacl_Hash_SHA2.h does not match its pinned sha256' vendor
    keep c/hacl/planted.h
    printf '// planted\n' >c/hacl/planted.h
    expect vendor-unpinned-file 'unpinned file in c/hacl: planted.h' vendor
}

probe_cli() {
    local stub="$backup/fvtrace-ignores-home"
    printf '#!/usr/bin/env bash\nunset FVTRACE_HOME\nexec %q "$@"\n' "$root/.lake/build/bin/fvtrace" >"$stub"
    chmod +x "$stub"
    expect cli-data-folder 'FAIL FVTRACE_HOME holds the trace' \
        env FVTRACE_SMOKE_BIN="$stub" bash tests/cli/smoke.sh
    # A binary that adds an empty folder to the project (a file is no harder to see).
    local mkdir="$backup/fvtrace-adds-folder"
    printf '#!/usr/bin/env bash\nmkdir -p fvtrace-planted-folder\nexec %q "$@"\n' \
        "$root/.lake/build/bin/fvtrace" >"$mkdir"
    chmod +x "$mkdir"
    expect cli-project-folder 'FAIL project folder unchanged' \
        env FVTRACE_SMOKE_BIN="$mkdir" bash tests/cli/smoke.sh
}

probe_lean_pure() {
    keep TestPure.lean
    sed -i 's/^def main : IO UInt32 := do$/def main : IO UInt32 := do\n  let _ ← Fvtrace.Digest.ofString "planted"/' TestPure.lean
    expect lean-pure-ffi 'Could not find native implementation' lean_pure
}

probe_palette() {
    local css="$backup/palette.css"
    sed 's/--conductor: #506984;/--conductor: #b0bfce;/' web/style.css >"$css"
    expect palette-contrast 'conductor on --paper' env FVTRACE_PALETTE_CSS="$css" node --test tests/palette/
}

# Tools install project-local (gate `tools`): a pinned name missing from .tools/bin (a fetch that
# wrote elsewhere) resolves to another copy on PATH, or to none.
probe_install_dir() {
    keep .tools/bin/actionlint
    rm .tools/bin/actionlint
    expect tools-project-local 'tools: actionlint resolves to "[^"]*", not .*/\.tools/bin/actionlint' tools_local
}

probe_filler() {
    keep README.md
    printf '\nThis robust tool helps you simply leverage the results.\n' >>README.md
    expect filler '^README\.md:[0-9]+:This robust tool' filler
}

# tools/ci-gate.sh on recorded + stubbed GitHub answers: a job cancelled before any step (no
# runner) is named so; a job with steps prints its normal line; the wait outlasts a `gh run watch`
# that returns before the run completes (stub: watch fails, status in_progress once).
probe_ci_gate() {
    local stub="$backup/gh-stub" ghstate="$backup/gh-state"
    mkdir -p "$stub"
    # shellcheck disable=SC2016 # the stub's own expansions
    printf '#!/usr/bin/env bash\ncase "$1 $2" in\n"run watch") exit 1 ;;\n"run view") n="$(cat %q 2>/dev/null || echo 0)"; echo $((n + 1)) >%q; if [[ $n -ge 1 ]]; then echo completed; else echo in_progress; fi ;;\nesac\n' \
        "$ghstate" "$ghstate" >"$stub/gh"
    chmod +x "$stub/gh"
    allow ci-no-runner bash -c 'source tools/ci-gate.sh; summary <tests/tools/ci-run.json |
        grep -qxF "portability / build (macos-arm64) cancelled 901s no runner"'
    allow ci-runner-line bash -c 'source tools/ci-gate.sh; summary <tests/tools/ci-run.json |
        grep -qxF "gate (lean) success 574s"'
    # shellcheck disable=SC2016 # the inner script's own expansions
    allow ci-wait-early env PATH="$stub:$PATH" bash -c 'source tools/ci-gate.sh; sleep() { :; }
        wait_run 1 && [[ "$(cat "$1")" == 2 ]]' _ "$ghstate"
    rm -f "$ghstate"
}

# tools/meta-lint.mjs (gate `spec`): one plant per shape it holds.
probe_meta_lint() {
    keep .claude/rules/web.md
    sed -i '0,/^paths:$/s//paths:\n  - [broken/' .claude/rules/web.md
    expect meta-lint-frontmatter 'web.md:3: not a quoted glob:   - \[broken' spec
    keep .claude/rules/web.md
    sed -i '0,/^paths:$/s//paths:\n  - "missing-planted\/**"/' .claude/rules/web.md
    expect meta-lint-glob '"missing-planted/\*\*" matches no tracked file' spec
    keep .agent/spec.md
    # shellcheck disable=SC2016 # backticks = the spec's literal text
    sed -i '0,/^- `lakefile.lean` = /s//- `tools\/missing-planted.sh` + `lakefile.lean` = /' .agent/spec.md
    expect meta-lint-artifact 'Artifacts: tools/missing-planted.sh matches no tracked file' spec
    keep .agent/spec.md
    # shellcheck disable=SC2016 # backticks = the spec's literal text
    sed -i 's/tag `prototype-lint`/tag `prototype-planted`/' .agent/spec.md
    expect meta-lint-tag 'tag prototype-planted does not exist' spec
    keep .agent/deferred.md
    printf -- '- A planted entry with no check.\n' >>.agent/deferred.md
    expect meta-lint-deferred 'no "Acceptance:" in "A planted entry' spec
    keep prototype/planted.txt
    mkdir -p prototype && printf 'planted\n' >prototype/planted.txt
    cp .git/index "$backup/index"
    GIT_INDEX_FILE="$backup/index" git add -f prototype/planted.txt
    expect meta-lint-prototype 'prototype/planted.txt: a retired prototype tree stays tracked' \
        env GIT_INDEX_FILE="$backup/index" bash -c 'source tools/gate.sh; spec'
    rm -f "$backup/index"
    rmdir prototype 2>/dev/null || true
}

# A gate run leaves no untracked, unignored file (gate.sh `leftovers`, closing every run).
probe_leftovers() {
    local before
    before="$(untracked)"
    keep planted-leftover.txt
    printf 'planted\n' >planted-leftover.txt
    expect leftovers '^planted-leftover\.txt$' \
        leftovers "$before"
    allow leftovers-clean leftovers "$before"
}

# Renovate's config (js-test): a lookbehind (JS accepts it, the hosted app's RE2 refuses it) + a
# release-age floor under 7 days, each planted in a copy the test reads through its override.
probe_renovate() {
    local cfg="$backup/renovate.json"
    jq '.customManagers[0].matchStrings[0] |= "(?<!PLANTED)" + .' renovate.json >"$cfg"
    expect renovate-re2 'RE2 refuses "\(\?<!" in "\(\?<!PLANTED' env FVTRACE_RENOVATE_JSON="$cfg" node --test tests/renovate/
    jq '.minimumReleaseAge = "0 days"' renovate.json >"$cfg"
    expect renovate-age 'minimumReleaseAge "0 days" is under 7 days' \
        env FVTRACE_RENOVATE_JSON="$cfg" node --test tests/renovate/
}

# The GUI's verdict words held equal to the engine's (Tests/Assets) + the skill's example trace held
# well-formed (Tests/Check): both run in the native suite, rebuilt after each plant.
assets_test() { lake build «fvtrace-tests» >/dev/null 2>&1; .lake/build/bin/fvtrace-tests; }

probe_assets() {
    keep web/words.js
    sed -i 's/^  open: "Pending verification",$/  open: "Not yet",/' web/words.js
    expect assets-verdict-words 'web/words.js names open as the engine does' assets_test
    keep skill/fvtrace/assets/example.trace.json
    jq '(.facts[] | select(.id == "O2") | .status) = "assumed"' \
        skill/fvtrace/assets/example.trace.json >"$backup/example.json" &&
        cp "$backup/example.json" skill/fvtrace/assets/example.trace.json
    expect assets-skill-example "the skill's example trace is well-formed" assets_test
    lake build «fvtrace-tests» >/dev/null 2>&1
}

# The page engine build (fvtrace-wasm, run by `lake build FvtraceEngine`): a pinned manifest digest
# that the fetched tree does not match, an import the page's loader does not provide, a linker
# warning outside the accepted two, a changed build step in lakefile.lean (Lake traces no target's
# own step, so the engine target traces the file; else a cached engine would replay), a link with
# dlmalloc. Each plant relinks (≈ 1 min); a failed build leaves the embedded engine as it was.
engine_build() { lake build FvtraceEngine 2>&1; }

probe_wasm() {
    keep tools/wasm.lock
    sed -i -E "s/^(libuv [^ ]+ [^ ]+ )[0-9a-f]{64}/\1$(printf '0%.0s' {1..64})/" tools/wasm.lock
    expect wasm-manifest 'libuv: manifest sha256 [0-9a-f]+, but tools/wasm.lock pins 0{64}' engine_build
    keep c/page_engine.c
    sed -i -e 's/^int fvtrace_init(void) {$/__attribute__((import_module("env"), import_name("probe"))) void fvtrace_probe(void);\nint fvtrace_init(void) {\n  fvtrace_probe();/' c/page_engine.c
    expect wasm-import 'imports env.probe \(kind 0\), which the page does not provide' engine_build
    keep c/page_engine.c
    sed -i -e 's/^lean_object \*initialize_fvtrace_Fvtrace_Snapshot(uint8_t builtin);$/lean_object *initialize_fvtrace_Fvtrace_Snapshot(void);/' \
        -e 's/initialize_fvtrace_Fvtrace_Snapshot(1);/initialize_fvtrace_Fvtrace_Snapshot();/' c/page_engine.c
    expect wasm-warning 'unexpected linker warnings' engine_build
    keep lakefile.lean
    sed -i -e 's/ "--githash", lean.githash,//' lakefile.lean
    expect wasm-build-step 'usage: fvtrace-wasm' engine_build
    keep FvtraceWasm/Build.lean
    sed -i 's/"-sMALLOC=mimalloc"/"-sMALLOC=dlmalloc"/' FvtraceWasm/Build.lean
    expect wasm-allocator 'links an allocator other than mimalloc' engine_build
}

# The page engine's differential (gate stage `engine`) also fails on any engine output to standard
# error: a panic returns a default value that may still equal the native answer. The plant writes
# a panic line on one answer, as the loader routes the engine's fd_write, and answers correctly.
probe_engine() {
    local plant="$backup/plant-panic.mjs"
    cat >"$plant" <<'PLANT'
const real = WebAssembly.instantiate.bind(WebAssembly);
let calls = 0;
WebAssembly.instantiate = async (bytes, imports) => {
  const { module, instance } = await real(bytes, imports);
  const answer = instance.exports.fvtrace_answer;
  const exports = {
    ...instance.exports,
    fvtrace_answer: (...args) => {
      if (++calls === 7) console.error("fvTrace engine: PANIC planted");
      return answer(...args);
    },
  };
  return { module, instance: { exports } };
};
PLANT
    expect engine-panic 'fvTrace engine: PANIC planted' node --import "$plant" tests/engine/engine.test.mjs
}

probe_examples() {
    keep Fvtrace/Proofs/Plan.lean
    printf '\n-- planted\n' >>Fvtrace/Proofs/Plan.lean
    expect examples-stale-receipt 'receipt P6: stale \(changed Fvtrace/Proofs/Plan.lean' examples
    keep README.md
    sed -i 's/to itself\. Seven of its claims read/to itself. Eight of its claims read/' README.md
    expect examples-readme-count 'README says Eight claims read Fully supported; the self-trace has 7' examples
    keep README.md
    sed -i 's/^Two claims read \*\*Pending verification\*\*/Two claims read **Conditional**/' README.md
    expect examples-readme-verdict 'README says Two claims read Conditional; the self-trace has 0' examples
}

# tools/scale.sh --assert (the F5 acceptance, run by hand on an idle host) grades rc, timeout, wall
# time + per-doubling ratio. A stub stands in for fvtrace: it sleeps STUB_K × n² s (n from its
# trace folder's name) and exits STUB_RC.
probe_scale() {
    allow scale-session-exits bash tests/tools/scale-session.sh
    allow scale-details-transition node --test tools/probes/scale-gui.test.mjs
    allow scale-spawn-cleanup node --test tools/probes/scale-spawn.test.mjs
    local stub="$backup/fvtrace-stub"
    cat >"$stub" <<'STUB'
#!/usr/bin/env bash
# Stand-in fvtrace: sleeps k·n², prints STUB_B·n² bytes and holds STUB_M·n² MiB (STUB_SHAPE: that
# shape alone), n = the size in the trace folder's name; exits STUB_RC (STUB_ONLY: for that command
# alone). `export` writes a page
# whose engine cannot start; `serve` with STUB_SERVE = a server that answers with that HTTP status
# after k·n² s.
trace=""
for ((i = 1; i < $#; i++)); do [[ ${!i} == --trace ]] && { j=$((i + 1)); trace="${!j}"; }; done
dir="${trace%/trace.json}" n="${dir##*-}" shape="${dir##*/}"
if [[ $1 == serve && -n "${STUB_SERVE:-}" ]]; then
    exec python3 -c '
import http.server, os, sys, time
class Answer(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers["Content-Length"]))
        time.sleep(float(os.environ.get("STUB_K", "0")) * int(sys.argv[1]) ** 2)
        self.send_response(int(os.environ["STUB_SERVE"]))
        self.end_headers()
        self.wfile.write(b"{}")
    def log_message(self, *args):
        pass
s = http.server.HTTPServer(("127.0.0.1", 0), Answer)
print(f"Open http://fvtrace.localhost:{s.server_port}/#token=00", flush=True)
s.serve_forever()' "$n"
fi
sleep "$(awk -v n="$n" -v k="${STUB_K:-0}" 'BEGIN { printf "%.3f", k * n * n }')"
[[ $1 == export ]] && printf '%s' '<script type="application/json" id="fvtrace-data">{"snapshot":{}}</script><script type="application/octet-stream" id="fvtrace-engine">AAAA</script>' >"$3"
[[ -n "${STUB_B:-}" ]] && head -c "$((STUB_B * n * n))" /dev/zero
if [[ -n "${STUB_M:-}" && ( -z "${STUB_SHAPE:-}" || $shape == "${STUB_SHAPE}"-* ) ]]; then
    exec python3 -c "import sys; b = bytearray($((STUB_M * n * n)) << 20); sys.exit(${STUB_RC:-0})"
fi
[[ -n "${STUB_ONLY:-}" && $1 != "${STUB_ONLY}" ]] && exit 0
exit "${STUB_RC:-0}"
STUB
    chmod +x "$stub"
    # A server that exits while the GUI driver's browser launches: the driver reports it. Bounded,
    # since a driver that misses the exit waits for a link that never comes (rc 124, no cause).
    STUB_RC=3 expect scale-gui-serve-exit 'fvtrace serve exited' \
        timeout 60 node tools/scale-gui.mjs "$stub" "$backup/wide-2" "$backup/page.html"
    local run=(bash tools/scale.sh --assert --bin "$stub" --n "2 4" wide)
    STUB_RC=3 expect scale-rc 'FAIL wide check n=2: rc 3' "${run[@]}"
    STUB_RC=3 STUB_ONLY=plan expect scale-text 'FAIL wide plan n=2: rc 3' "${run[@]}"
    STUB_K=0.02 expect scale-ratio 'FAIL wide check n=2→4: ratio [0-9.]+ > 2.5 per doubling' "${run[@]}"
    STUB_K=0.02 expect scale-wall 'FAIL wide check n=4: wall [0-9.]+ s > 0.1 s' "${run[@]}" --max-wall 0.1
    STUB_K=0.2 expect scale-timeout 'FAIL wide check n=4: timeout after 1 s' "${run[@]}" --timeout 1
    STUB_M=20 expect scale-rss 'FAIL wide check n=2→4: rss ratio [0-9.]+ > 2.5 per doubling' "${run[@]}"
    STUB_B=100000 expect scale-bytes 'FAIL wide eval n=2→4: bytes ratio [0-9.]+ > 2.2 per doubling' \
        "${run[@]}"
    STUB_M=10 STUB_SHAPE=outcomes expect scale-rss-cap 'FAIL outcomes eval: rss [0-9]+ MiB > 1.5' \
        "${run[@]}" outcomes --max-ratio 100
    # The serve rows: a server that exits, one that never prints its link, one that answers an
    # error, one past the time limit; the page rows: an engine that cannot start.
    STUB_RC=3 expect scale-serve-exit 'FAIL wide serve n=2: rc 3' "${run[@]}"
    STUB_K=0.2 expect scale-serve-start 'FAIL wide serve n=4: timeout after 1 s' "${run[@]}" --timeout 1
    STUB_SERVE=500 expect scale-serve-status 'FAIL wide serve:action n=2: rc 500' "${run[@]}"
    STUB_SERVE=200 STUB_K=0.2 expect scale-serve-timeout 'FAIL wide serve:action n=4: timeout after 1 s' \
        "${run[@]}" --timeout 1
    expect scale-page 'FAIL wide page n=2: rc 2' "${run[@]}"
    # The GUI rows: a stand-in driver whose served selection takes 0.5 s against its 0.1 s bound.
    local gui="$backup/scale-gui-stub.mjs"
    cat >"$gui" <<'STUB'
const steps = ["first", "select", "details", "busy", "whatif"].flatMap((s) => [`served:${s}`, `page:${s}`]);
for (const s of [...steps, "page:startup"])
  process.stdout.write(`gui:${s} 0 ${s === "served:select" ? "0.500" : "0.010"} - 0 0 0.1\n`);
STUB
    expect scale-gui-bound 'FAIL wide gui:served:select n=2: wall 0.500 s > 0.1 s' \
        "${run[@]}" --gui "$gui"
    local gexit="$backup/scale-gui-exit.mjs"
    sed 's/s === "served:select" ? "0.500" : "0.010"/"0.010"/' "$gui" >"$gexit"
    printf 'process.exit(Number(process.env.GUI_RC));\n' >>"$gexit"
    GUI_RC=3 expect scale-gui-session-rc 'FAIL wide gui:served:select n=2: rc 3' \
        bash tools/scale.sh --assert --bin "$stub" --n 2 --gui "$gexit" wide
    GUI_RC=124 expect scale-gui-session-timeout 'FAIL wide gui:served:select n=2: timeout after' \
        bash tools/scale.sh --assert --bin "$stub" --n 2 --gui "$gexit" wide
    # A shape with experiments adds the experiment step: its row is graded at its own 1 s bound.
    local gexp="$backup/scale-gui-experiment.mjs"
    cat >"$gexp" <<'STUB'
const steps = ["first", "select", "details", "busy", "whatif", "experiment"];
for (const s of [...steps.flatMap((x) => [`served:${x}`, `page:${x}`]), "page:startup"])
  process.stdout.write(`gui:${s} 0 ${s === "served:experiment" ? "1.500" : "0.010"} - 0 0 1\n`);
STUB
    expect scale-gui-experiment 'FAIL outcomes gui:served:experiment n=2: wall 1.500 s > 1 s' \
        bash tools/scale.sh --assert --bin "$stub" --n "2 4" --gui "$gexp" outcomes
    allow scale-pass bash tools/scale.sh --assert --n "2 4" --max-ratio 100 wide
}

# tools/compare.sh (cross-revision byte equality) fails on any difference: two stand-in binaries
# that exit differently differ on every run, one compared with itself on none; a run past the
# time limit fails too.
probe_compare() {
    allow compare-oracle-integrity node --test tools/probes/compare.test.mjs
    # Own stand-ins: a host's /bin/true + /bin/false can be one multicall binary (NixOS coreutils),
    # which behaves alike once run by its real path, so the planted rc difference vanishes.
    local yes="$backup/exit-0" no="$backup/exit-1"
    printf '#!/usr/bin/env bash\nexit 0\n' >"$yes"
    printf '#!/usr/bin/env bash\nexit 1\n' >"$no"
    chmod +x "$yes" "$no"
    expect compare-differ 'DIFF self check \(rc\)' bash tools/compare.sh "$yes" "$no"
    local same="$backup/same-json"
    cat >"$same" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' '{"schema":"fvtrace.evaluation/2","actions":[],"experiments":[],"claims":[],"facts":[]}'
STUB
    chmod +x "$same"
    allow compare-same bash tools/compare.sh "$same" "$same"
    # Equal partial output proves nothing: a stand-in whose first run outlasts the limit.
    local slow="$backup/slow-once"
    # shellcheck disable=SC2016 # the stand-in's own script text
    printf '#!/usr/bin/env bash\n[[ -e "$0.ran" ]] || { : >"$0.ran"; sleep 3; }\n' >"$slow"
    chmod +x "$slow"
    expect compare-timeout 'TIMEOUT old form eval' bash tools/compare.sh --timeout 1 "$slow" "$slow"
    # The v1 → v2 paths time out too: both binaries stall alike (equal partial output, equal rc), on
    # a JSON comparison and on an expansion oracle.
    local json="$backup/slow-whatif" oracle="$backup/slow-action"
    printf '%s\n' '#!/usr/bin/env bash' '[[ " $* " == *" O9=proved "* ]] && sleep 3' 'exit 0' >"$json"
    printf '%s\n' '#!/usr/bin/env bash' 'case " $* " in' \
        '*" --action "*) sleep 3 ;;' \
        '" eval --trace "*) printf '"'"'{"actions":[{"id":"a","overrides":[]}]}\n'"'"' ;;' \
        'esac' >"$oracle"
    chmod +x "$json" "$oracle"
    expect compare-json-timeout 'TIMEOUT old self eval --whatif O9=proved' \
        bash tools/compare.sh --timeout 1 "$json" "$json"
    expect compare-oracle-timeout 'TIMEOUT new self eval --action a' \
        bash tools/compare.sh --timeout 1 "$oracle" "$oracle"
}

# tools/release.sh check (each CI build's archive + each downloaded release archive): a digest that
# differs, an archive whose program reports another version, a missing license text, a Linux binary
# past the glibc floor. The macOS + Windows floors fire on their own platforms alone (CI plants).
probe_release() {
    local dist="$backup/dist" version a
    version="$(sed -n 's/^def version : String := "\(.*\)"$/\1/p' Fvtrace/Version.lean)"
    a="fvtrace-$version-linux-x86_64"
    allow release-package env DIST="$dist" bash tools/release.sh package linux-x86_64
    keep "$dist/$a.tar.gz.sha256"
    sed -i -E 's/^[0-9a-f]{64}/'"$(printf '0%.0s' {1..64})"'/' "$dist/$a.tar.gz.sha256"
    expect release-digest "$a.tar.gz: sha256 differs" bash tools/release.sh check "$dist" linux-x86_64 "$version"
    # Repacked as 9.9.9 (its program still says $version), then without one license text.
    local tree="$backup/repack"
    mkdir -p "$tree" && tar -xzf "$dist/$a.tar.gz" -C "$tree" && mv "$tree/$a" "$tree/fvtrace-9.9.9-linux-x86_64"
    repack() {
        (cd "$tree" && tar -czf "$dist/fvtrace-9.9.9-linux-x86_64.tar.gz" fvtrace-9.9.9-linux-x86_64)
        (cd "$dist" && sha256sum fvtrace-9.9.9-linux-x86_64.tar.gz >fvtrace-9.9.9-linux-x86_64.tar.gz.sha256)
    }
    repack
    expect release-version "fvtrace --version printed \"fvtrace $version\", not \"fvtrace 9.9.9\"" \
        bash tools/release.sh check "$dist" linux-x86_64 9.9.9
    rm "$tree/fvtrace-9.9.9-linux-x86_64/licenses/musl.txt" && repack
    expect release-license 'fvtrace-9.9.9-linux-x86_64.tar.gz lacks licenses/musl.txt' \
        bash tools/release.sh check "$dist" linux-x86_64 9.9.9
    keep tools/release.sh
    sed -i 's/^glibc_max=.*/glibc_max=2.16/' tools/release.sh
    expect release-glibc 'needs GLIBC_2\.17, newer than the floor 2\.16' \
        bash tools/release.sh check "$dist" linux-x86_64 "$version"
}

# The lock checks (tools/wasm.lock in fvtrace-wasm, tools/tools.lock in tools/fetch-tools.sh)
# refuse a half-bumped lock: Renovate PR #5's edit = one line's version token alone.
probe_locks() {
    keep tools/wasm.lock
    sed -i -E 's/^emsdk [^ ]+ (linux-x86_64 )/emsdk 99.0.0 \1/' tools/wasm.lock
    expect lock-wasm-half-bump 'tools/wasm.lock: emsdk lines name versions .*99\.0\.0' engine_build
    keep tools/tools.lock
    sed -i -E 's/^actionlint [^ ]+ (linux-x86_64 )/actionlint 99.0.0 \1/' tools/tools.lock
    expect lock-tools-half-bump 'fetch-tools: actionlint lines name versions' bash tools/fetch-tools.sh
}

# The step ledger (tools/gate-ledger.sh): a red stage stays listed until a class rules it, the
# green beside it never is; a class outside the four is refused; the summary counts both rows,
# the green one's measured seconds + the red one's class.
probe_ledger() {
    local log="$backup/ledger.tsv" lg=(env GATE_LEDGER="$backup/ledger.tsv" bash tools/gate-ledger.sh)
    (ledger="$log" && ledger_begin probe && stage planted-red false && stage planted-green sleep 0.2) >/dev/null
    expect ledger-unclassified $'\tprobe\tplanted-red\t' "${lg[@]}" reds
    expect ledger-class 'class must be product, gate, flake or planted' "${lg[@]}" classify planted-red bogus
    "${lg[@]}" classify planted-red planted
    allow ledger-classified "${lg[@]}" reds
    # Columns after the step: runs seconds reds product gate flake planted unclassified.
    # shellcheck disable=SC2016 # the inner script's own expansions
    allow ledger-summary bash -c '
        s="$("$@" summary)" || exit 1
        grep -E "^planted-green +1 +(0\.[2-9]|[1-9][0-9]*\.[0-9]) +0 " <<<"$s" &&
            grep -E "^planted-red +1 +[0-9.]+ +1 +0 +0 +0 +1 +0$" <<<"$s"' _ "${lg[@]}"
    # Two runs begun in the same second on one tree share a row key: one class rules one of them.
    printf 'D\tT\tprobe\tsame-key\t0.0\tred\n%.0s' 1 2 | "${lg[@]}" append
    "${lg[@]}" classify same-key product
    expect ledger-same-key $'\tprobe\tsame-key\t' "${lg[@]}" reds
    rm -f -- "$log"
    # Every stage's closing line names its verdict + wall-clock (CLAUDE.md gate timing).
    # shellcheck disable=SC2016 # the inner script's own expansions
    allow stage-line bash -c 'source tools/gate.sh; ledger=""; stage planted true | grep -qxE "planted rc=0 [0-9]+\.[0-9]s"'
}

probe_c_headers() {
    local cc="$backup/cc" log="$backup/cc.log" count
    printf '#!/usr/bin/env bash\nprintf "compile\\n" >>%q\nexec cc "$@"\n' "$log" >"$cc"
    chmod +x "$cc"
    : >"$log"
    allow c-header-baseline env CC="$cc" lake build fvtracec
    keep c/hacl/Hacl_Hash_SHA2.h
    printf '\n#error PROBE_C_HEADER_MUST_REBUILD\n' >>c/hacl/Hacl_Hash_SHA2.h
    expect c-header-change 'PROBE_C_HEADER_MUST_REBUILD' env CC="$cc" lake build fvtracec
    allow c-header-restored env CC="$cc" lake build fvtracec
    count="$(wc -l <"$log")"
    allow c-header-compiled test "$count" -gt 0
    allow c-header-unchanged env CC="$cc" lake build fvtracec
    allow c-header-cached test "$(wc -l <"$log")" -eq "$count"
}

# The fast gate skips the engine stage while `engine_key` holds: a changed engine input must change
# the key, an untouched tree must keep it.
probe_fast_engine() {
    # shellcheck disable=SC2016 # the inner script's own expansions
    local key same=(bash -c 'source tools/gate.sh; [[ "$(engine_key)" == "$1" ]] || {
        echo "engine inputs changed"; exit 1; }' _)
    key="$(bash -c 'source tools/gate.sh; engine_key')"
    allow fast-engine-key-stable "${same[@]}" "$key"
    keep tests/engine/loader.test.mjs
    printf '// planted\n' >>tests/engine/loader.test.mjs
    expect fast-engine-key-change 'engine inputs changed' "${same[@]}" "$key"
}

# The side-by-side group (tools/gate.sh TOGETHER): a red stage in it reaches `failed`, its log + rc
# print, a green one stays green.
probe_together() {
    # shellcheck disable=SC2016 # the inner script's own expansions
    local run=(env GATE_LEDGER= bash -c 'source tools/gate.sh; ledger_begin probe
        code="$1"; meta() { echo "planted meta failure"; return "$code"; }
        together_start meta spec; together_finish
        [[ ${#failed[@]} -eq 0 ]] || { echo "failed: ${failed[*]}"; exit 1; }' _)
    allow together-green "${run[@]}" 0
    expect together-red '^failed: meta$' "${run[@]}" 3
}

# Stages over a file selection fail on an empty one (an emptied folder or pattern would read green).
probe_empty_inputs() {
    local empty="$backup/empty-tests/" repo="$backup/empty-repo"
    mkdir -p "$empty" "$repo"
    git -C "$repo" init -q
    mkdir -p "$repo/tools" && cp tools/lean-style.sh "$repo/tools/"
    # shellcheck disable=SC2016 # the inner script's own expansions
    expect empty-node-tests 'no test file in' \
        bash -c 'source tools/gate.sh; node_tests "$1"' _ "$empty"
    expect empty-lean-style 'no Lean file selected' bash "$repo/tools/lean-style.sh"
}

# lean.md layout: a Spec file importing Proofs or holding a theorem + a shipped module importing
# Lean each fail lean-style.
probe_layout() {
    keep Fvtrace/Spec/Fast.lean
    printf 'import Fvtrace.Proofs.Answers\n' | cat - Fvtrace/Spec/Fast.lean >"$backup/spec" &&
        cp "$backup/spec" Fvtrace/Spec/Fast.lean
    expect layout-spec-imports-proofs 'Spec imports Proofs' bash tools/lean-style.sh
    keep Fvtrace/Spec/Fast.lean
    printf '\ntheorem planted : True := trivial\n' >>Fvtrace/Spec/Fast.lean
    expect layout-spec-theorem 'Spec holds a theorem' bash tools/lean-style.sh
    keep Fvtrace/Render.lean
    printf 'import Lean\n' | cat - Fvtrace/Render.lean >"$backup/render" &&
        cp "$backup/render" Fvtrace/Render.lean
    expect layout-shipped-lean 'shipped module imports Lean' bash tools/lean-style.sh
}

probe_mutate() { allow mutation-scanner node --test tools/probes/mutate.test.mjs; }
probe_install() { allow install-attempt-bound bash tests/tools/install-bound.sh; }
probe_load() {
    allow load-fractional-floor bash tests/tools/load-floor.sh
    allow load-interrupt-cleanup python3 -I tests/tools/load-cleanup.py
}
probe_release_guard() { allow release-archive-set node --test tools/probes/release-guard.test.mjs; }
probe_release_tmpdir() {
    local dist="$backup/dist" tmp="$backup/tmp'quoted" version
    version="$(sed -n 's/^def version : String := "\(.*\)"$/\1/p' Fvtrace/Version.lean)"
    mkdir -p "$tmp"
    allow release-tmpdir-package env DIST="$dist" bash tools/release.sh package linux-x86_64
    allow release-tmpdir-quoted env TMPDIR="$tmp" bash tools/release.sh check "$dist" linux-x86_64 "$version"
    allow release-tmpdir-clean test -z "$(ls -A "$tmp")"
}

probe_dispatch() {
    expect dispatch-unknown 'unknown probe: __missing__' bash tools/gate-probe.sh __missing__
    local envfile="$backup/probe-env"
    printf 'probe_planted() { printf "planted failure\\n"; return 7; }\n' >"$envfile"
    expect dispatch-function-failure 'probe planted failed \(rc=7\)' \
        env BASH_ENV="$envfile" bash tools/gate-probe.sh planted
}

probes=("$@")
[[ ${#probes[@]} -gt 0 ]] ||
    probes=(lean_style fanout meta trust capability replay_policy trust_cache audit vendor cli lean_pure palette assets engine examples wasm scale compare release locks dispatch mutate install release_guard release_tmpdir c_headers load ledger fast_engine together empty_inputs layout renovate provision install_dir leftovers filler ci_gate meta_lint)
for p in "${probes[@]}"; do
    if ! declare -F "probe_$p" >/dev/null; then
        printf 'unknown probe: %s\n' "$p" >&2
        failures+=("$p")
        continue
    fi
    "probe_$p"
    rc=$?
    if [[ $rc -ne 0 ]]; then
        printf 'probe %s failed (rc=%d)\n' "$p" "$rc" >&2
        failures+=("$p")
    fi
done

printf '\nprobes: %d passed, %d failed\n' "$passed" "${#failures[@]}"
[[ ${#failures[@]} -eq 0 ]] || {
    printf 'FAILED: %s\n' "${failures[*]}"
    exit 1
}
