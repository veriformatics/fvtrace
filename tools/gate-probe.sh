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

probe_meta() {
    keep lakefile.lean
    sed -i 's/^  version := v!".*"$/  version := v!"9.9.9"/' lakefile.lean
    expect meta-version 'meta: .* != lakefile.lean version "9.9.9"' meta
}

probe_trust() {
    # A plain `def` named like a generated equation lemma is still a claim.
    keep Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Spec\ndef eq_987654 : Prop := Fvtrace.version = "planted"\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    expect trust-unproven 'eq_987654: no proof' trust_build

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

    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    plant_import
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

probe_examples() {
    keep Fvtrace/Proofs/Plan.lean
    printf '\n-- planted\n' >>Fvtrace/Proofs/Plan.lean
    expect examples-stale-receipt 'receipt P6: stale \(changed Fvtrace/Proofs/Plan.lean' examples
}

probes=("$@")
[[ ${#probes[@]} -gt 0 ]] ||
    probes=(lean_style meta trust replay_policy audit vendor cli lean_pure palette assets examples)
for p in "${probes[@]}"; do "probe_$p"; done

printf '\nprobes: %d passed, %d failed\n' "$passed" "${#failures[@]}"
[[ ${#failures[@]} -eq 0 ]] || {
    printf 'FAILED: %s\n' "${failures[*]}"
    exit 1
}
