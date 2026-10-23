#!/usr/bin/env bash
# The one gate command: a human, an agent and CI run exactly this, so one result is one claim.
# Stages run to completion after a failure (no `set -e`), so one run reports every problem; each
# prints `<stage> rc=N <s>s`, the run closes on `gate rc=N <s>s`.
# Usage: tools/gate.sh [--shard NAME] — no argument = every stage; a shard = its stages alone
# (CI runs one job per shard, see STAGES).
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 1
export PATH="$root/.tools/bin:$root/node_modules/.bin:$PATH"

failed=()

stamp() { printf '%s' "${EPOCHREALTIME//[!0-9]/}"; }
elapsed() {
    local us=$(($(stamp) - $1))
    printf '%d.%d' $((us / 1000000)) $((us / 100000 % 10))
}

stage() {
    local name="$1" start rc
    shift
    start="$(stamp)"
    printf '\n=== %s ===\n' "$name"
    "$@"
    rc=$?
    printf '%s rc=%d %ss\n' "$name" "$rc" "$(elapsed "$start")"
    [[ $rc -eq 0 ]] || failed+=("$name")
    return 0
}

# Stage · CI shards. A full run takes every stage in this order, each running the function of its
# name (`-` → `_`). CI runs one job per shard (gate.yml matrix), each on a fresh checkout, so a
# shard whose stages read the build lists lean-build too; `fanout` holds the matrix = these shards.
STAGES='
tools       checks
lean-style  checks
lean-build  lean e2e
lean-test   lean
lean-pure   lean
cli         lean
examples    lean
engine      lean
trust       lean
c-analyze   checks
vendor      checks
js-format   checks
js-lint     checks
js-types    checks
js-test     checks
e2e         e2e
audit       checks
secrets     checks
workflows   checks
fanout      checks
spec        checks
shell       checks
meta        checks
'

# Every shard STAGES names, once each, in first-use order.
shard_names() { awk 'NF { for (i = 2; i <= NF; i++) if (!seen[$i]++) print $i }' <<<"$STAGES"; }

tools() { bash tools/fetch-tools.sh; }

# Lean has no formatter in the 4.35 toolchain; this holds the mechanical layout rules.
lean_style() { bash tools/lean-style.sh; }

# Builds every target (library, shipped binary, tests, trust audit, the exported page's
# WebAssembly engine + its build tool); every proof is kernel-checked here, and `warningAsError`
# turns lints + deprecations into failures. The engine's first build per toolchain fetches
# Emscripten + generates Init's C (minutes); later builds reuse both and recompile what changed.
lean_build() { lake build Fvtrace fvtrace «fvtrace-tests» «fvtrace-trust» «fvtrace-wasm» FvtraceEngine; }

lean_test() { lake test; }

# The FFI-free suites interpreted, as the mutation tool runs them (an FFI call there aborts it).
lean_pure() { lake env lean --run TestPure.lean; }

# The shipped binary end to end (data folder from the environment, exit codes, no write outside).
cli() { bash tests/cli/smoke.sh; }

# fvTrace's own trace + the synthetic study: valid, every warning waived, every receipt current.
# A changed file that the self-trace pins (a proof, a spec) stales its receipt until re-pinned.
examples() {
    local rc=0 home bin="$root/.lake/build/bin/fvtrace"
    home="$(mktemp -d)"
    FVTRACE_HOME="$home" "$bin" check --strict --trace examples/fvtrace/trace.json --project . ||
        rc=1
    (cd examples/synthetic/project &&
        FVTRACE_HOME="$home" "$bin" check --strict --trace ../trace.json) || rc=1
    rm -rf "$home"
    return $rc
}

# The exported page's engine (WebAssembly, run by the page's loader) answers every differential
# case byte for byte as the native engine does (`kernel.md` E-wasm); Chromium = e2e engine.spec.js.
engine() { node --test tests/engine/; }

# Claims ↔ proofs ↔ axioms ↔ escape hatches, then every proof's closure replayed through the
# independent kernels bundled with Lean (`lake check --paranoid`).
trust() { bash tools/trust.sh; }

prettier_files() {
    git ls-files -co --exclude-standard -- 'web/*' 'tests/e2e/*' 'tests/engine/*' 'tests/schema/*' 'tests/palette/*' 'tests/renovate/*' 'schema/*' \
        'tools/*.mjs' ':(top,glob)*.json' ':(top,glob)*.mjs' ':(top,glob).*.json' '.github/*' |
        grep -v -e '^lake-manifest.json$'
}

js_format() { prettier_files | xargs -r prettier --check; }

js_lint() {
    local rc=0
    oxlint --type-aware --deny-warnings web tests/e2e tests/engine tests/schema tests/palette tests/renovate tools ./*.mjs || rc=1
    stylelint 'web/**/*.css' || rc=1
    html-validate web || rc=1
    return $rc
}

js_types() {
    local rc=0 p
    for p in . web tests/e2e; do tsc -p "$p" || rc=1; done
    return $rc
}

# The FFI shim + the page engine's C bridge under clang's static analyzer, findings as errors
# (HACL* itself is verified upstream and compiled verbatim; `vendor` holds it byte-equal to the
# pinned release).
c_analyze() {
    local rc=0
    clang --analyze -Xclang -analyzer-werror -I"$(lean --print-prefix)/include" -Ic/hacl \
        -Ic/hacl/include -DKRML_VERIFIED_UINT128 c/fvtrace_digest.c -o /dev/null || rc=1
    clang --analyze -Xclang -analyzer-werror -I"$(lean --print-prefix)/include" \
        c/page_engine.c -o /dev/null || rc=1
    return $rc
}

vendor() { bash tools/vendor-hacl.sh --verify; }

# The JSON Schema agrees with the decoder on tests/schema/cases/ (Tests/Schema.lean = other half);
# the GUI palette meets contrast + color-vision floors (tests/palette/); Renovate's regex managers
# extract the dependencies of their files (tests/renovate/).
js_test() { node --test tests/schema/ tests/palette/ tests/renovate/; }

e2e() { playwright test; }

# Advisories with no fixed release, ignored only while none exists (a fix turns `audit` red):
# GHSA-vfj7-8cjw-p6xm = braces stack exhaustion on nested brace patterns; reached only through
# stylelint's globbing of the gate's own literal pattern (`web/**/*.css`), dev tooling only.
DEV_RESIDUALS=(GHSA-vfj7-8cjw-p6xm)

# Decides `pnpm audit --json` output; split out so tools/gate-probe.sh can feed it a planted
# report. A missing `advisories` object (registry error) fails.
audit_policy() {
    local found
    found="$(jq -r --args '
        if (.advisories | type) != "object" then "no advisory report (registry error?)"
        else .advisories[]
            | if (.github_advisory_id | IN($ARGS.positional[])) then
                (if (.patched_versions // "<0.0.0") == "<0.0.0" then empty
                 else "\(.github_advisory_id) (\(.module_name)) now has a fix: \(.patched_versions)" end)
              else "\(.github_advisory_id) \(.severity) \(.module_name) \(.vulnerable_versions)" end
        end' "${DEV_RESIDUALS[@]}")" || {
        printf 'audit: unreadable advisory report\n' >&2
        return 1
    }
    if [[ -n "$found" ]]; then
        printf 'audit: %s\n' "$found" >&2
        return 1
    fi
    printf 'audit: no unaccepted advisories\n'
}

# Lean code carries no third-party package (asserted on the manifest); the JS dev tree is audited
# against the npm advisory database.
audit() {
    local rc=0
    if [[ "$(jq '.packages | length' lake-manifest.json)" != 0 ]]; then
        printf 'audit: lake-manifest.json lists Lake packages; audit them before adding\n' >&2
        rc=1
    fi
    { pnpm audit --json || true; } | audit_policy || rc=1
    return $rc
}

# History + every tracked or untracked-unignored file; live validation stays off (no network).
secrets() {
    local rc=0
    betterleaks git --no-banner --redact . || rc=1
    git ls-files -co --exclude-standard -z | xargs -0 -r betterleaks dir --no-banner --redact || rc=1
    return $rc
}

workflows() {
    local rc=0
    zizmor --no-progress .github/ || rc=1
    actionlint || rc=1
    return $rc
}

# CI runs the gate as one job per gate.yml matrix shard: a stage without a shard, or a shard the
# matrix lacks, would pass a local run and never run in CI.
fanout() {
    local rc=0 wf=.github/workflows/gate.yml matrix shards
    awk 'NF == 1 { print "fanout: stage " $1 " has no CI shard"; bad = 1 } END { exit bad }' \
        <<<"$STAGES" >&2 || rc=1
    matrix="$(sed -n 's/^ *shard: \[\(.*\)\]$/\1/p' "$wf" | tr -d ' ' | tr ',' '\n' | sort)"
    shards="$(shard_names | sort)"
    if [[ "$matrix" != "$shards" ]]; then
        printf 'fanout: %s matrix shards [%s] != tools/gate.sh shards [%s]\n' "$wf" \
            "$(paste -sd, - <<<"$matrix")" "$(paste -sd, - <<<"$shards")" >&2
        rc=1
    fi
    # Matched by YAML position, not parsed (no YAML parser in the toolchain): the `run:` key of a
    # step in job `gate` (job keys at 2 spaces, step keys at 8), the whole line. The same text in a
    # comment, behind `|| true`, or inside a block scalar (indented deeper than its key) runs no gate.
    # `$SHARD` here = the workflow's literal text, which the runner's shell expands.
    # shellcheck disable=SC2016
    if [[ "$(awk '
        /^[^ #]/ { top = $0 }
        top == "jobs:" && /^  [^ #]/ { job = $1 }
        job == "gate:" && /^        run: bash tools\/gate\.sh --shard "\$SHARD"$/ { n++ }
        END { print n + 0 }' "$wf")" != 1 ]]; then
        printf 'fanout: %s runs no single `bash tools/gate.sh --shard "$SHARD"` step\n' "$wf" >&2
        rc=1
    fi
    return $rc
}

spec() { sh .agent/spec-lint .agent/spec.md; }

shell() {
    local files=()
    mapfile -t files < <(git ls-files -co --exclude-standard -- '*.sh')
    shellcheck -- "${files[@]}"
}

# The version lives in two places Lake + the binary each read.
meta() {
    local lean lake
    lean="$(sed -n 's/^def version : String := "\(.*\)"$/\1/p' Fvtrace/Version.lean)"
    lake="$(sed -n 's/^  version := v!"\(.*\)"$/\1/p' lakefile.lean)"
    if [[ -z "$lean" || "$lean" != "$lake" ]]; then
        printf 'meta: Fvtrace/Version.lean version "%s" != lakefile.lean version "%s"\n' "$lean" "$lake" >&2
        return 1
    fi
}

main() {
    local start shard="" rows row name shards
    if [[ $# -gt 0 ]]; then
        if [[ $# -ne 2 || "$1" != --shard ]] || ! shard_names | grep -x -F -- "$2" >/dev/null; then
            printf 'usage: tools/gate.sh [--shard %s]\n' "$(shard_names | paste -sd'|' -)" >&2
            exit 2
        fi
        shard="$2"
    fi
    start="$(stamp)"
    # An array, not a `while read` loop: stages keep the caller's stdin.
    mapfile -t rows <<<"$STAGES"
    for row in "${rows[@]}"; do
        read -r name shards <<<"$row"
        if [[ -n "$name" && ( -z "$shard" || " $shards " == *" $shard "* ) ]]; then
            stage "$name" "${name//-/_}"
        fi
    done
    printf '\n=== gate%s ===\n' "${shard:+ (shard $shard)}"
    if [[ ${#failed[@]} -ne 0 ]]; then
        printf 'FAILED: %s\n' "${failed[*]}"
        printf 'gate rc=1 %ss\n' "$(elapsed "$start")"
        exit 1
    fi
    printf 'gate rc=0 %ss\n' "$(elapsed "$start")"
}

# Sourcing exposes the stage functions without running the gate (tools/fast-gate.sh, probes).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
