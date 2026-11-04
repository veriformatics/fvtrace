#!/usr/bin/env bash
# Iteration gate: the cheap stages in parallel, then the Lean build + tests (incremental).
# Never the claim: kernel replay, e2e, audit, secrets + workflows run in tools/gate.sh alone, and
# this prints them as skipped. Usage: tools/fast-gate.sh [--e2e] (adds the browser suite).
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 1
# shellcheck source=tools/gate.sh
source tools/gate.sh
ledger_begin fast

log="$(mktemp -d)"
trap 'rm -rf "$log"' EXIT
pids=()
names=(lean-style js-format js-lint js-types js-test fanout spec shell meta)
fns=(lean_style js_format js_lint js_types js_test fanout spec shell meta)
for i in "${!names[@]}"; do
    (
        t0="$(stamp)"
        "${fns[$i]}" >"$log/${names[$i]}" 2>&1
        rc=$?
        elapsed "$t0" >"$log/${names[$i]}.time"
        exit $rc
    ) &
    pids+=($!)
done

start="$(stamp)"
stage lean-build lean_build
stage lean-test lean_test
stage lean-pure lean_pure
stage cli cli
stage examples examples
stage engine engine
if [[ " $* " == *" --e2e "* ]]; then stage e2e e2e; fi

# Their ledger rows come from here, one writer: rows from parallel subshells could interleave.
for i in "${!names[@]}"; do
    wait "${pids[$i]}"
    rc=$?
    secs="$(cat "$log/${names[$i]}.time")"
    printf '\n=== %s ===\n' "${names[$i]}"
    cat "$log/${names[$i]}"
    printf '%s rc=%d %ss\n' "${names[$i]}" "$rc" "$secs"
    ledger_add "${names[$i]}" "$secs" "$rc"
    [[ $rc -eq 0 ]] || failed+=("${names[$i]}")
done

skipped="tools trust c-analyze vendor audit secrets workflows"
[[ " $* " == *" --e2e "* ]] || skipped="$skipped e2e"
printf '\n=== fast gate ===\nskipped: %s\n' "$skipped"
secs="$(elapsed "$start")"
if [[ ${#failed[@]} -ne 0 ]]; then
    ledger_add fast-gate "$secs" 1
    printf 'FAILED: %s\nfast-gate rc=1 %ss\n' "${failed[*]}" "$secs"
    exit 1
fi
ledger_add fast-gate "$secs" 0
printf 'fast-gate rc=0 %ss\n' "$secs"
