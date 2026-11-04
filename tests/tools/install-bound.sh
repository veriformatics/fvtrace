#!/usr/bin/env bash
# tools/install-lean.sh `bounded` (ops.md: each attempt ≤ 180 s): TERM at the bound − 1 s, KILL at
# the bound, so a TERM-resistant download ends within it; quick commands keep their own rc.
set -uo pipefail
# shellcheck source=/dev/null
source <(sed -n '/^bounded() {/,/^}/p' tools/install-lean.sh)
attempt_secs=2
start=$EPOCHREALTIME
bounded bash -c 'trap "" TERM; exec sleep 6'
rc=$?
elapsed=$(awk -v a="$start" -v b="$EPOCHREALTIME" 'BEGIN { printf "%.2f", b - a }')
printf 'attempt limit=%ss; elapsed=%ss; rc=%s\n' "$attempt_secs" "$elapsed" "$rc"
awk -v e="$elapsed" -v l="$attempt_secs" 'BEGIN { exit !(e <= l + 0.5) }' && [[ $rc -eq 124 ]] || {
    printf 'FAIL: TERM-resistant install escaped its attempt bound\n' >&2
    exit 1
}
start=$EPOCHREALTIME
bounded bash -c 'trap "exit 0" TERM; while :; do sleep 0.1; done'
rc=$?
elapsed=$(awk -v a="$start" -v b="$EPOCHREALTIME" 'BEGIN { printf "%.2f", b - a }')
printf 'TERM-honouring attempt: elapsed=%ss; rc=%s\n' "$elapsed" "$rc"
awk -v e="$elapsed" -v l="$attempt_secs" 'BEGIN { exit !(e <= l - 0.5) }' && [[ $rc -eq 124 ]] || {
    printf 'FAIL: TERM did not come one second before the bound, or its exit read as success\n' >&2
    exit 1
}
# Quick controls: a budget whose TERM point (2 s) no millisecond command reaches.
attempt_secs=3
bounded bash -c 'exit 7'
[[ $? -eq 7 ]] || { printf 'FAIL: a quick failure lost its rc\n' >&2; exit 1; }
bounded true || { printf 'FAIL: a quick success failed\n' >&2; exit 1; }
printf 'install attempt bound holds\n'
