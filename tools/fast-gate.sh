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

# shellcheck disable=SC2086 # TOGETHER = a word list
together_start $TOGETHER
start="$(stamp)"
stage lean-build lean_build
stage lean-test lean_test
stage lean-pure lean_pure
stage cli cli
stage examples examples
engine_seen=.lake/fast-gate/engine.key
key="$(engine_key)"
if [[ -f "$engine_seen" && "$(<"$engine_seen")" == "$key" ]]; then
    skip_engine=1
else
    before=${#failed[@]}
    stage engine engine
    if [[ ${#failed[@]} -eq $before ]]; then
        mkdir -p "${engine_seen%/*}" && printf '%s\n' "$key" >"$engine_seen"
    fi
fi
if [[ " $* " == *" --e2e "* ]]; then stage e2e e2e; fi

together_finish

# The skipped stages = the registry's (tools/gate.sh STAGES) minus the ones this run took.
ran=" $TOGETHER lean-build lean-test lean-pure cli examples "
[[ -n ${skip_engine:-} ]] || ran+="engine "
[[ " $* " != *" --e2e "* ]] || ran+="e2e "
skipped=""
for name in $(stage_names); do [[ "$ran" == *" $name "* ]] || skipped+=" $name"; done
[[ -z ${skip_engine:-} ]] || skipped+=" (engine: its inputs = its last pass's)"
printf '\n=== fast gate ===\nskipped:%s\n' "$skipped"
secs="$(elapsed "$start")"
if [[ ${#failed[@]} -ne 0 ]]; then
    ledger_add fast-gate "$secs" 1
    printf 'FAILED: %s\nfast-gate rc=1 %ss\n' "${failed[*]}" "$secs"
    exit 1
fi
ledger_add fast-gate "$secs" 0
printf 'fast-gate rc=0 %ss\n' "$secs"
