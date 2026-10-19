#!/usr/bin/env bash
# Trust stage: `fvtrace-trust` audits claims ↔ proofs ↔ axioms ↔ escape hatches, then every
# proof's dependency closure is exported + replayed through Lean's kernel and the independent
# kernels bundled with the toolchain. Policy: Lean default, Lean paranoid, lean4lean + nanoda must
# accept; con-leche + con-ron may decline a feature they do not implement yet (they reject the
# Nat.land environment in Lean 4.35), never reject otherwise.
set -uo pipefail

# Decides the replay from `lake check`'s log; split out so tools/gate-probe.sh can feed it a
# planted log. Args: <check.log> <lake check rc>.
replay_policy() {
    local log="$1" check_rc="$2" rc=0 kernel
    for kernel in "Lean default" "Lean paranoid" "lean4lean" "nanoda"; do
        if ! grep -q "^$kernel kernel accepts the solution" "$log"; then
            printf 'trust: %s kernel did not accept the export\n' "$kernel" >&2
            rc=1
        fi
    done
    for kernel in con-leche con-ron; do
        if grep -q "^$kernel kernel rejected the solution" "$log" &&
            ! grep -q -E "^$kernel: (not implemented yet|declined): unsupported" "$log"; then
            printf 'trust: %s rejected the export\n' "$kernel" >&2
            rc=1
        fi
    done
    if [[ $check_rc -ne 0 && $rc -eq 0 ]] &&
        ! grep -q -E '^con-(leche|ron): (not implemented yet|declined): unsupported' "$log"; then
        printf 'trust: lake check failed (rc=%d)\n' "$check_rc" >&2
        rc=1
    fi
    return $rc
}

main() {
    local root out check_rc rc proofs
    root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
    cd -- "$root" || return 1
    out="$root/.lake/trust"
    mkdir -p "$out"

    lake exe fvtrace-trust || return 1
    mapfile -t proofs < <(lake exe fvtrace-trust --list-proofs)
    if [[ ${#proofs[@]} -eq 0 ]]; then
        printf 'trust: no proofs to replay\n' >&2
        return 1
    fi

    lake env leanexport Fvtrace -- "${proofs[@]}" >"$out/export.ndjson" || return 1
    lake check --from-export="$out/export.ndjson" --paranoid >"$out/check.log" 2>&1
    check_rc=$?

    replay_policy "$out/check.log" "$check_rc"
    rc=$?
    grep -E 'kernel (accepts|rejected)|not implemented yet|declined' "$out/check.log"
    printf 'trust: %d proofs replayed\n' "${#proofs[@]}"
    return $rc
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
