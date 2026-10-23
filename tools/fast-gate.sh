#!/usr/bin/env bash
# Iteration gate: the cheap stages in parallel, then the Lean build + tests (incremental).
# Never the claim: kernel replay, e2e, audit, secrets + workflows run in tools/gate.sh alone, and
# this prints them as skipped. Usage: tools/fast-gate.sh [--e2e] (adds the browser suite).
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 1
# shellcheck source=tools/gate.sh
source tools/gate.sh

log="$(mktemp -d)"
trap 'rm -rf "$log"' EXIT
pids=()
names=(lean-style js-format js-lint js-types js-test fanout spec shell meta)
fns=(lean_style js_format js_lint js_types js_test fanout spec shell meta)
# Each parallel stage records its own wall-clock beside its log.
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

for i in "${!names[@]}"; do
    wait "${pids[$i]}"
    rc=$?
    printf '\n=== %s ===\n' "${names[$i]}"
    cat "$log/${names[$i]}"
    printf '%s rc=%d %ss\n' "${names[$i]}" "$rc" "$(cat "$log/${names[$i]}.time")"
    [[ $rc -eq 0 ]] || failed+=("${names[$i]}")
done

skipped="tools trust c-analyze vendor audit secrets workflows"
[[ " $* " == *" --e2e "* ]] || skipped="$skipped e2e"
printf '\n=== fast gate ===\nskipped: %s\n' "$skipped"
if [[ ${#failed[@]} -ne 0 ]]; then
    printf 'FAILED: %s\nfast-gate rc=1 %ss\n' "${failed[*]}" "$(elapsed "$start")"
    exit 1
fi
printf 'fast-gate rc=0 %ss\n' "$(elapsed "$start")"
