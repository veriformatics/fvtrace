#!/usr/bin/env bash
# Cross-revision byte equality (`.agent/contracts/kernel.md` P-evidence): two fvtrace binaries on the
# same inputs + flags, stdout + stderr + exit code compared byte for byte.
#   tools/compare.sh [--timeout S] OLD NEW   (OLD = the binary built before an engine change)
# Inputs: both examples, the test fixtures, every tools/scale.mjs shape at n = 3, 40, 150. Per
# input: check (+ --json), eval (+ what-ifs, refused ones too), claims, gaps, experiments, plan
# (+ --json). Every run gets a fresh data folder. Exit 1 on any difference, and on any run either
# binary does not finish within S seconds (default 600): equal partial output proves nothing.
# OLD's envelope form picks the JSON comparison: `fvtrace.evaluation/2` → byte equality throughout
# (+ `eval --complete` on every input; every action + item expanded on the small ones), else v1 →
# the V-cli transform + oracles below.
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
# v1 envelope → v2 (kernel.md V-env + V-cli): the moved lists dropped, actions as references, a
# fact's ceiling from its route + kind, the creator's title as the token + its id.
# shellcheck disable=SC2016 # jq variables ($k, $by, $title), not shell ones
v1_to_v2='def mustVerify: . as $k | ["entailment","result","estimand","numerical","implementation","dataflow"] | index($k) != null;
def ceilingOf: if (.route == "lean" or .route == "refinement") then "proved" elif .route == "runtime-checker" then "checked" elif (.kind | mustVerify) then "tested" else "assumed" end;
def plan2: if .result == "planned" then {result, state} else {result} end;
def claim2($by; $title): .subject as $s | .incompatibleCount = (.incompatible | length)
  | (if $title[$s] != null and (.label.qualifiers | index("if " + $title[$s] + " runs")) != null
     then .label.qualifiers |= map(if . == ("if " + $title[$s] + " runs") then "if-creator-runs" else . end)
       | .label.creator = $by[$s] else . end)
  | del(.sentence, .incompatible, .conflicts) | .plan |= plan2;
((.experiments // []) | map(select(.creates)) | map({(.subject): .id}) | add // {}) as $by
| ((.experiments // []) | map(select(.creates)) | map({(.subject): .title}) | add // {}) as $title
| .schema = "fvtrace.evaluation/2"
| if has("facts") then .facts |= map(. + {ceiling: ceilingOf}) else . end
| if has("claims") then .claims |= map(claim2($by; $title)) else . end
| if has("experiments") then .experiments |= map(del(.closure, .raises, .wins, .losses)) else . end
| if has("actions") then .actions |= map({id, kind, target}) else . end
| if has("claim") then .plan = .claim.plan | .claim |= claim2({}; {}) else . end'
# `plan --json` + `claims --json` carry no experiments: the creator qualifier is compared through
# eval alone.
creatorless='def plain: .label |= del(.creator) | .label.qualifiers |= map(if test("^if .* runs$") then "if-creator-runs" else . end);
if has("claim") then .claim |= plain else . end
| if has("claims") and (has("experiments") | not) then .claims |= map(plain) else . end'
# A run whose output form changed: v1 transformed = v2, structurally (jq -S); refusals byte-equal.
cmp_json() { # label, project, trace, args...
    local label="$1" project="$2" trace="$3"; shift 3
    local b
    for b in old new; do
        local bin="$old"
        [[ $b == new ]] && bin="$new"
        rm -rf "${work:?}/home"
        (cd "$project" && FVTRACE_HOME="$work/home" timeout "$limit" "$bin" "$@" --trace "$trace" \
            >"$work/$b.out" 2>"$work/$b.err"; echo "rc=$?" >"$work/$b.rc")
        sed -i '/^usage: fvtrace/,$d' "$work/$b.err"
    done
    runs=$((runs + 1))
    if [[ "$(<"$work/old.rc")" == rc=0 ]]; then
        jq -S "$v1_to_v2 | $creatorless" "$work/old.out" >"$work/old.json" 2>/dev/null
        jq -S "$creatorless" "$work/new.out" >"$work/new.json" 2>/dev/null
    else
        cp "$work/old.out" "$work/old.json"; cp "$work/new.out" "$work/new.json"
    fi
    for out in json err rc; do
        if ! cmp -s "$work/old.$out" "$work/new.$out"; then
            diffs=$((diffs + 1)); printf 'DIFF %s %s (%s)\n' "$label" "$*" "$out"
            diff <(head -c 2000 "$work/old.$out") <(head -c 2000 "$work/new.$out") | head -8
        fi
    done
}
# Oracles (small inputs): every v1 action = its v2 expansion; every v1 list = the v2 details.
oracles() { # label, project, trace
    local label="$1" project="$2" trace="$3" envelope
    envelope="$(cd "$project" && FVTRACE_HOME="$work/home" "$old" eval --trace "$trace" 2>/dev/null)" || return 0
    local id spec item want got
    while IFS=$'\t' read -r id spec; do
        runs=$((runs + 1))
        want="$(cd "$project" && FVTRACE_HOME="$work/home" "$old" eval --trace "$trace" ${spec:+--whatif "$spec"} | jq -S "$v1_to_v2")"
        got="$(cd "$project" && FVTRACE_HOME="$work/home" "$new" eval --trace "$trace" --action "$id" | jq -S .)"
        [[ "$want" == "$got" ]] || { diffs=$((diffs + 1)); printf 'DIFF %s expansion %s\n' "$label" "$id"; }
    done < <(jq -r '.actions[] | [.id, (.overrides | sort_by(.fact) | map("\(.fact)=\(.status)") | join(","))] | @tsv' <<<"$envelope")
    while IFS=$'\t' read -r item want; do
        runs=$((runs + 1))
        got="$(cd "$project" && FVTRACE_HOME="$work/home" "$new" eval --trace "$trace" --details "$item" | jq -cS 'del(.schema, .mode, .overrides, .trace, .item)')"
        [[ "$(jq -cS . <<<"$want")" == "$got" ]] || { diffs=$((diffs + 1)); printf 'DIFF %s details %s\n' "$label" "$item"; }
    done < <(jq -r '(.experiments[] | ["experiment:\(.id)", ({closure, raises, wins, losses} | tojson)]),
        (.claims[] | ["claim:\(.id)", ({plan, sentence, incompatible} | tojson)]),
        (. as $e | .facts[] | .id as $f | ["fact:\($f)", ({raisedBy: [$e.experiments[] | select(any(.raises[]; .fact == $f)) | .id]} | tojson)]) | @tsv' <<<"$envelope")
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
# Same form: every action + every item of OLD's envelope, byte for byte (V-action, V-details).
same_oracles() { # label, project, trace
    local label="$1" project="$2" trace="$3" envelope id
    envelope="$(cd "$project" && FVTRACE_HOME="$work/home" "$old" eval --trace "$trace" 2>/dev/null)" || return 0
    while read -r id; do
        cmp_run "$label" "$project" "$trace" eval --action "$id"
    done < <(jq -r '.actions[].id' <<<"$envelope")
    while read -r id; do
        cmp_run "$label" "$project" "$trace" eval --details "$id"
    done < <(jq -r '(.experiments[] | "experiment:\(.id)"), (.claims[] | "claim:\(.id)"),
        (.facts[] | "fact:\(.id)")' <<<"$envelope")
}
form="$(cd "$root/examples/synthetic/project" && FVTRACE_HOME="$work/home" timeout "$limit" "$old" \
    eval --trace "$root/examples/synthetic/trace.json" 2>/dev/null | jq -r '.schema? // empty' 2>/dev/null)"
if [[ "$form" == fvtrace.evaluation/2 ]]; then
    cmp_json() { cmp_run "$@"; }
    oracles() { same_oracles "$@"; }
fi
for spec in "${inputs[@]}"; do
    IFS='|' read -r label project trace claim whatif <<<"$spec"
    [[ "$form" == fvtrace.evaluation/2 ]] && cmp_run "$label" "$project" "$trace" eval --complete
    cmp_run "$label" "$project" "$trace" check
    cmp_run "$label" "$project" "$trace" check --json
    cmp_json "$label" "$project" "$trace" eval
    for cmd in claims gaps experiments; do
        cmp_run "$label" "$project" "$trace" "$cmd"
        cmp_json "$label" "$project" "$trace" "$cmd" --json
    done
    cmp_run "$label" "$project" "$trace" plan "$claim"
    cmp_json "$label" "$project" "$trace" plan "$claim" --json
    for w in "$whatif" "O9=proved" "E0=assumed" "E0=proved,E0=proved" "E0" ",,"; do
        [[ -n "$w" ]] || continue
        cmp_json "$label" "$project" "$trace" eval --whatif "$w"
        cmp_run "$label" "$project" "$trace" claims --whatif "$w"
    done
    [[ "$label" == *-40 || "$label" == *-150 ]] || oracles "$label" "$project" "$trace"
done
printf 'compare: %d runs, %d differing outputs, %d timeouts (%s vs %s)\n' "$runs" "$diffs" \
    "$timeouts" "$old" "$new"
[[ $diffs -eq 0 && $timeouts -eq 0 ]]
