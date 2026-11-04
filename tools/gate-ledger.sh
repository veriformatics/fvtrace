#!/usr/bin/env bash
# The gate's step ledger (rows: tools/gate.sh `ledger`; law: .claude/rules/ops.md). A red is ruled
# by a row of its own that repeats the red's date, tree, run + step, with seconds `-` and verdict
# `class:<class>`: rows are only ever appended.
# Usage: tools/gate-ledger.sh [reds]                    the unclassified reds; rc 1 if any
#        tools/gate-ledger.sh classify STEP CLASS [RUN] the newest unclassified red of STEP (in RUN)
#                                                       → CLASS: product | gate | flake | planted
#        tools/gate-ledger.sh summary                   per step: runs, seconds, reds by class
#        tools/gate-ledger.sh append                    rows from stdin (tools/ci-gate.sh)
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 2
# shellcheck source=tools/gate.sh
source tools/gate.sh
[[ -n "$ledger" ]] || {
    printf 'gate-ledger: GATE_LEDGER is empty: no ledger\n' >&2
    exit 2
}

# Unclassified reds, oldest first (filtered by step + run when given). Each class row rules one
# red of its key: two runs begun in the same second on one tree share a key, never a class.
unclassified() {
    [[ -r "$ledger" ]] || return 0
    awk -F'\t' -v step="${1-}" -v run="${2-}" '
        { k = $1 FS $2 FS $3 FS $4 }
        $6 == "red" && (step == "" || $4 == step) && (run == "" || $3 == run) { red[++n] = k; row[n] = $0 }
        $6 ~ /^class:/ { ruled[k]++ }
        END { for (i = 1; i <= n; i++) if (ruled[red[i]]-- <= 0) print row[i] }' "$ledger"
}

case "${1-reds}" in
reds)
    out="$(unclassified)"
    [[ -z "$out" ]] && exit 0
    printf '%s\n' "$out"
    exit 1
    ;;
classify)
    [[ $# -eq 3 || $# -eq 4 ]] || {
        printf 'usage: tools/gate-ledger.sh classify STEP CLASS [RUN]\n' >&2
        exit 2
    }
    case "$3" in
    product | gate | flake | planted) ;;
    *)
        printf 'gate-ledger: class must be product, gate, flake or planted, not "%s"\n' "$3" >&2
        exit 2
        ;;
    esac
    red="$(unclassified "$2" "${4-}" | tail -n 1)"
    [[ -n "$red" ]] || {
        printf 'gate-ledger: no unclassified red of %s%s\n' "$2" "${4:+ in $4}" >&2
        exit 1
    }
    printf '%s\t-\tclass:%s\n' "$(cut -f1-4 <<<"$red")" "$3" >>"$ledger"
    ;;
summary)
    [[ -r "$ledger" ]] || exit 0
    format='%-36s %5s %9s %5s %8s %5s %6s %8s %12s\n'
    # shellcheck disable=SC2059 # the one format string, shared with awk
    printf "$format" step runs seconds reds product gate flake planted unclassified
    # Most seconds first; each line leads with its sort key (CI job names hold spaces).
    awk -F'\t' -v format="$format" '
        $6 == "green" || $6 == "red" { runs[$4]++; secs[$4] += $5; if ($6 == "red") reds[$4]++ }
        $6 ~ /^class:/ { cls[$4, substr($6, 7)]++; ruled[$4]++ }
        END {
            for (s in runs)
                printf "%s\t" format, secs[s], s, runs[s], sprintf("%.1f", secs[s]), reds[s] + 0, \
                    cls[s, "product"] + 0, cls[s, "gate"] + 0, cls[s, "flake"] + 0, \
                    cls[s, "planted"] + 0, reds[s] - ruled[s]
        }' "$ledger" | sort -t$'\t' -k1,1 -rn | cut -f2-
    ;;
append)
    mkdir -p -- "$(dirname -- "$ledger")" && cat >>"$ledger"
    ;;
*)
    printf 'usage: tools/gate-ledger.sh [reds | classify STEP CLASS [RUN] | summary | append]\n' >&2
    exit 2
    ;;
esac
