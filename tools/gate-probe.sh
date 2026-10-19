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
            cp "$backup/$(printf '%s' "$f" | tr '/' '_')" "$f"
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
        cp "$f" "$backup/$(printf '%s' "$f" | tr '/' '_')"
        saved[$f]="$(sha256sum "$f" | cut -d' ' -f1)"
    else
        saved[$f]=absent
    fi
}

passed=0
failures=()
# expect <probe> <regex> <command...>: the command must fail with output matching regex.
expect() {
    local name="$1" pattern="$2" out rc
    shift 2
    out="$("$@" 2>&1)"
    rc=$?
    if [[ $rc -ne 0 ]] && grep -q -E -- "$pattern" <<<"$out"; then
        printf 'probe %s: fired (rc=%d)\n' "$name" "$rc"
        passed=$((passed + 1))
    else
        printf 'probe %s: DID NOT FIRE (rc=%d)\n%s\n' "$name" "$rc" "$(tail -5 <<<"$out")" >&2
        failures+=("$name")
    fi
    restore
}
# allow <probe> <command...>: a negative control; the command must pass.
allow() {
    local name="$1" out rc
    shift
    out="$("$@" 2>&1)"
    rc=$?
    if [[ $rc -eq 0 ]]; then
        printf 'probe %s: passed as expected\n' "$name"
        passed=$((passed + 1))
    else
        printf 'probe %s: FAILED a valid input (rc=%d)\n%s\n' "$name" "$rc" "$(tail -5 <<<"$out")" >&2
        failures+=("$name")
    fi
    restore
}

trust_build() { lake build Fvtrace «fvtrace-trust» >/dev/null 2>&1 && lake exe fvtrace-trust; }

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

probe_meta() {
    keep lakefile.toml
    sed -i 's/^version = ".*"$/version = "9.9.9"/' lakefile.toml
    expect meta-version 'meta: .* != lakefile.toml version "9.9.9"' meta
}

probe_trust() {
    keep Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Spec\ndef PlantedUnproven : Prop := Fvtrace.version = "planted"\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    expect trust-unproven 'PlantedUnproven: no proof' trust_build

    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    printf 'namespace Fvtrace.Spec\ndef PlantedAxiom : Prop := Fvtrace.version = "planted"\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\naxiom planted : False\ntheorem plantedAxiom : Spec.PlantedAxiom := planted.elim\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-axiom 'uses axiom Fvtrace.Proofs.planted' trust_build

    keep Fvtrace/Version.lean
    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    printf 'namespace Fvtrace\npartial def plantedLoop (n : Nat) : Nat := plantedLoop n\nend Fvtrace\n' \
        >>Fvtrace/Version.lean
    printf 'namespace Fvtrace.Spec\ndef PlantedPartial : Prop := Fvtrace.plantedLoop 0 = Fvtrace.plantedLoop 0\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\ntheorem plantedPartial : Spec.PlantedPartial := rfl\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-escape-hatch 'reaches (partial|opaque) Fvtrace.plantedLoop' trust_build

    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    printf 'namespace Fvtrace.Spec\ndef PlantedVacuous : Prop := 1 + 1 = 2\nend Fvtrace.Spec\n' >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\ntheorem plantedVacuous : Spec.PlantedVacuous := rfl\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-vacuous 'PlantedVacuous: statement reaches no shipped code' trust_build
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

probes=("$@")
[[ ${#probes[@]} -gt 0 ]] || probes=(lean_style meta trust replay_policy audit)
for p in "${probes[@]}"; do "probe_$p"; done

printf '\nprobes: %d passed, %d failed\n' "$passed" "${#failures[@]}"
[[ ${#failures[@]} -eq 0 ]] || {
    printf 'FAILED: %s\n' "${failures[*]}"
    exit 1
}
