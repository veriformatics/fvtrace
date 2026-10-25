#!/usr/bin/env bash
# Cross-revision byte equality (`.agent/contracts/kernel.md` P-evidence): two fvtrace binaries on the
# same inputs + flags, stdout + stderr + exit code compared byte for byte.
#   tools/compare.sh [--timeout S] OLD NEW   (OLD = the binary built before an engine change)
# Inputs: both examples, the test fixtures, every tools/scale.mjs shape at n = 3, 40, 150. Per
# input: check (+ --json), eval (+ what-ifs, refused ones too), claims, gaps, experiments, plan
# (+ --json). Every run gets a fresh data folder. Exit 1 on any difference, and on any run either
# binary does not finish within S seconds (default 600): equal partial output proves nothing.
set -uo pipefail
limit=600
[[ ${1:-} == --timeout ]] && { limit="$2"; shift 2; }
[[ $# -eq 2 ]] || { printf 'usage: tools/compare.sh [--timeout S] OLD NEW\n' >&2; exit 2; }
old="$(realpath -- "$1")" new="$(realpath -- "$2")"
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
runs=0 diffs=0 timeouts=0
cmp_run() { # label, project, trace, args...
    local label="$1" project="$2" trace="$3"; shift 3
    local b out
    for b in old new; do
        local bin="$old"
        [[ $b == new ]] && bin="$new"
        rm -rf "${work:?}/home"
        (cd "$project" && FVTRACE_HOME="$work/home" timeout "$limit" "$bin" "$@" --trace "$trace" \
            >"$work/$b.out" 2>"$work/$b.err"; echo "rc=$?" >"$work/$b.rc")
        if [[ "$(<"$work/$b.rc")" == rc=124 ]]; then
            timeouts=$((timeouts + 1)); printf 'TIMEOUT %s %s %s (%s s)\n' "$b" "$label" "$*" "$limit"
        fi
    done
    runs=$((runs + 1))
    # A refusal's usage text names the options each binary has: compared apart (kernel.md V-cli).
    for b in old new; do sed -i '/^usage: fvtrace/,$d' "$work/$b.err"; done
    for out in out err rc; do
        if ! cmp -s "$work/old.$out" "$work/new.$out"; then
            diffs=$((diffs + 1)); printf 'DIFF %s %s (%s)\n' "$label" "$*" "$out"
            diff <(head -c 2000 "$work/old.$out") <(head -c 2000 "$work/new.$out") | head -8
        fi
    done
}
inputs=("self|$root|$root/examples/fvtrace/trace.json|C1|P1=open,E2=proved"
    "synthetic|$root/examples/synthetic/project|$root/examples/synthetic/trace.json|C2|O2=checked,EN2=proved"
    "fixture|$root/examples/synthetic/project|$root/tests/fixtures/synthetic.trace.json|C2|O1=violated"
    "restates|$root/examples/synthetic/project|$root/tests/fixtures/restates.trace.json|C1|")
for shape in wide deep experiments exclusions hub questions waivers receipts outcomes prereqs whatif \
    invalid; do
    for n in 3 40 150; do
        dir="$work/$shape-$n"
        node "$root/tools/scale.mjs" "$shape" "$n" "$dir" || exit 2
        whatif="E0=proved,F1=proved"
        [[ -f "$dir/whatif.txt" ]] && whatif="$(<"$dir/whatif.txt")"
        inputs+=("$shape-$n|$dir/project|$dir/trace.json|C0|$whatif")
    done
done
for spec in "${inputs[@]}"; do
    IFS='|' read -r label project trace claim whatif <<<"$spec"
    cmp_run "$label" "$project" "$trace" check
    cmp_run "$label" "$project" "$trace" check --json
    cmp_run "$label" "$project" "$trace" eval
    for cmd in claims gaps experiments; do cmp_run "$label" "$project" "$trace" "$cmd"; done
    cmp_run "$label" "$project" "$trace" plan "$claim"
    cmp_run "$label" "$project" "$trace" plan "$claim" --json
    for w in "$whatif" "O9=proved" "E0=assumed" "E0=proved,E0=proved" "E0" ",,"; do
        [[ -n "$w" ]] || continue
        cmp_run "$label" "$project" "$trace" eval --whatif "$w"
        cmp_run "$label" "$project" "$trace" claims --whatif "$w"
    done
done
printf 'compare: %d runs, %d differing outputs, %d timeouts (%s vs %s)\n' "$runs" "$diffs" \
    "$timeouts" "$old" "$new"
[[ $diffs -eq 0 && $timeouts -eq 0 ]]
