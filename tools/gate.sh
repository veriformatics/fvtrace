#!/usr/bin/env bash
# The one gate command: a human, an agent and CI run exactly this, so one result is one claim.
# Stages run to completion after a failure (no `set -e`), so one run reports every problem; each
# prints `<stage> rc=N <s>s`, the run closes on `gate rc=N <s>s`.
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

# Lean has no formatter in the 4.35 toolchain; this holds the mechanical layout rules.
lean_style() { bash tools/lean-style.sh; }

# Builds every target (library, shipped binary, tests, trust audit); every proof is
# kernel-checked here, and `warningAsError` turns lints + deprecations into failures.
lean_build() { lake build Fvtrace fvtrace «fvtrace-tests» «fvtrace-trust»; }

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

# Claims ↔ proofs ↔ axioms ↔ escape hatches, then every proof's closure replayed through the
# independent kernels bundled with Lean (`lake check --paranoid`).
trust() { bash tools/trust.sh; }

prettier_files() {
    git ls-files -co --exclude-standard -- 'web/*' 'tests/e2e/*' 'tests/schema/*' 'tests/palette/*' 'tests/renovate/*' 'schema/*' \
        'tools/*.mjs' ':(top,glob)*.json' ':(top,glob)*.mjs' ':(top,glob).*.json' '.github/*' |
        grep -v -e '^lake-manifest.json$'
}

js_format() { prettier_files | xargs -r prettier --check; }

js_lint() {
    local rc=0
    oxlint --type-aware --deny-warnings web tests/e2e tests/schema tests/palette tests/renovate tools ./*.mjs || rc=1
    stylelint 'web/**/*.css' || rc=1
    html-validate web || rc=1
    return $rc
}

js_types() {
    local rc=0 p
    for p in . web tests/e2e; do tsc -p "$p" || rc=1; done
    return $rc
}

# The FFI shim under clang's static analyzer, findings as errors (HACL* itself is verified upstream
# and compiled verbatim; `vendor` holds it byte-equal to the pinned release).
c_analyze() {
    clang --analyze -Xclang -analyzer-werror -I"$(lean --print-prefix)/include" -Ic/hacl \
        -Ic/hacl/include -DKRML_VERIFIED_UINT128 c/fvtrace_digest.c -o /dev/null
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
    local start
    start="$(stamp)"
    stage tools bash tools/fetch-tools.sh
    stage lean-style lean_style
    stage lean-build lean_build
    stage lean-test lean_test
    stage lean-pure lean_pure
    stage cli cli
    stage examples examples
    stage trust trust
    stage c-analyze c_analyze
    stage vendor vendor
    stage js-format js_format
    stage js-lint js_lint
    stage js-types js_types
    stage js-test js_test
    stage e2e e2e
    stage audit audit
    stage secrets secrets
    stage workflows workflows
    stage spec spec
    stage shell shell
    stage meta meta
    printf '\n=== gate ===\n'
    if [[ ${#failed[@]} -ne 0 ]]; then
        printf 'FAILED: %s\n' "${failed[*]}"
        printf 'gate rc=1 %ss\n' "$(elapsed "$start")"
        exit 1
    fi
    printf 'gate rc=0 %ss\n' "$(elapsed "$start")"
}

# Sourcing exposes the stage functions without running the gate (tools/fast-gate.sh, probes).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
