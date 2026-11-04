#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=/dev/null
source <(sed -n '/^load1() {/,/^if \[\[ /{ /^if \[\[ /!p; }' tools/e2e-load.sh)
out="$(mktemp -d)"
trap 'rm -rf -- "$out"' EXIT
nproc() { printf '%s\n' "$CPUS"; }
load1() { printf '10.0\n'; }
control() { :; }
sample() {
    local epoch
    for ((epoch = EPOCHSECONDS - 60; epoch <= EPOCHSECONDS + 60; epoch++)); do
        printf '%s %s\n' "$epoch" "$LOAD"
    done >"$1"
    : >"$1.ready"
}
bash() {
    if [[ "${1:-}" == tools/gate.sh ]]; then
        until [[ -f "$out/gate-1.load.ready" ]]; do command sleep 0.01; done
        printf '=== e2e ===\ne2e rc=0 0.1s\ngate rc=0 0.2s\n'
    else command bash "$@"; fi
}
export -f nproc load1 control sample bash
export out CPUS LOAD
for row in '1 1.20 3' '1 1.50 0' '3 4.49 3' '3 4.50 0'; do
    read -r CPUS LOAD expected <<<"$row"
    rm -f "$out/gate-1.load" "$out/gate-1.load.ready"
    result="$(gate 1)"
    rc=$?
    printf '%s\nCPUs=%s; load=%s; grader rc=%s\n' "$result" "$CPUS" "$LOAD" "$rc"
    [[ $rc -eq $expected && "$result" == *"load $LOAD"* ]] || {
        printf 'FAIL: fractional load threshold or sample window disagrees\n' >&2
        exit 1
    }
done
