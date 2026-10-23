#!/usr/bin/env bash
# Engine time bounds (`.agent/contracts/kernel.md` § Performance, P-bound + P-evidence): times
# `fvtrace check` + `fvtrace eval` on the generated shapes of tools/scale.mjs.
#   tools/scale.sh [--assert] [--bin PATH] [--timeout S] [--max-wall S] [--max-ratio R]
#                  [--n "N1 N2 …"] [shape…]
# Default: every shape at n = cap/2 and cap (the largest n within 16 MiB; outcomes + prereqs:
# fixed smaller n), the built binary, 900 s per run. One row per run (shape, n, input bytes, command, rc, wall s, user s, max RSS MiB, output
# bytes); per shape + command, the wall ratio of consecutive rows, scaled to one doubling of n.
# --assert grades the graded shapes (wide deep experiments exclusions): exit 1 on a nonzero rc, a
# timeout, a wall time above --max-wall (60) or a per-doubling ratio above --max-ratio (2.5), one
# `FAIL` line per breach. Other shapes are reported, never graded. Time it where the host is idle:
# the bounds are wall-clock (load is printed at start + end).
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$root/.lake/build/bin/fvtrace"
limit=900 max_wall=60 max_ratio=2.5 assert=0
sizes=""
shapes=()
usage='usage: tools/scale.sh [--assert] [--bin PATH] [--timeout S] [--max-wall S] [--max-ratio R] [--n "N…"] [shape…]'
while [[ $# -gt 0 ]]; do
    case "$1" in
    --assert) assert=1; shift ;;
    --bin) bin="$(realpath -- "$2")"; shift 2 ;;
    --timeout) limit="$2"; shift 2 ;;
    --max-wall) max_wall="$2"; shift 2 ;;
    --max-ratio) max_ratio="$2"; shift 2 ;;
    --n) sizes="$2"; shift 2 ;;
    -*) printf '%s\n' "$usage" >&2; exit 2 ;;
    *) shapes+=("$1"); shift ;;
    esac
done
graded=" wide deep experiments exclusions "
[[ ${#shapes[@]} -gt 0 ]] ||
    shapes=(wide deep experiments exclusions hub questions waivers receipts outcomes prereqs whatif invalid)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=()
fail() { fails+=("$1"); printf 'FAIL %s\n' "$1"; }
printf 'binary %s sha256 %s\n' "$bin" "$(sha256sum "$bin" | cut -d' ' -f1)"
printf 'host %s, %s CPUs, load %s at start\n' "$(uname -n)" "$(nproc)" "$(cut -d' ' -f1-3 /proc/loadavg)"
printf '%-12s %8s %9s %-6s %4s %9s %9s %8s %11s\n' shape n bytes cmd rc wall user rss_mib out_bytes
# Output that grows with n² (one experiment's complete what-if in every claim's plan action, chain
# closures) would dominate these two at the cap: they run smaller unless --n says otherwise.
declare -A small=([outcomes]="1000 2000" [prereqs]="1200 2400")
for shape in "${shapes[@]}"; do
    ns="${sizes:-${small[$shape]:-}}"
    if [[ -z "$ns" ]]; then
        cap="$(node "$root/tools/scale.mjs" "$shape" cap)" || exit 2
        ns="$((cap / 2)) $cap"
    fi
    grade=0
    [[ $assert -eq 1 && "$graded" == *" $shape "* ]] && grade=1
    for cmd in check eval; do
        prev="" prev_n=""
        for n in $ns; do
            dir="$work/$shape-$n"
            [[ -f "$dir/trace.json" ]] || node "$root/tools/scale.mjs" "$shape" "$n" "$dir" || exit 2
            args=("$cmd" --trace "$dir/trace.json" --project "$dir/project")
            [[ $cmd == eval && -f "$dir/whatif.txt" ]] && args+=(--whatif "$(<"$dir/whatif.txt")")
            : >"$work/time"
            # Output is counted, never stored: the tail shapes print gigabytes at their cap.
            FVTRACE_HOME="$work/home" timeout "$limit" /usr/bin/time -o "$work/time" -f '%e %U %M' \
                "$bin" "${args[@]}" 2>/dev/null | wc -c >"$work/bytes"
            rc=${PIPESTATUS[0]}
            # GNU time puts "Command exited with non-zero status N" above its format line.
            wall="" user="" rss=0
            read -r wall user rss < <(tail -n 1 "$work/time") || true
            [[ $rc -eq 124 || -z "$wall" ]] && { wall=timeout; user=-; rss=0; }
            printf '%-12s %8s %9s %-6s %4s %9s %9s %8s %11s\n' "$shape" "$n" \
                "$(stat -c %s "$dir/trace.json")" "$cmd" "$rc" "$wall" "$user" "$((rss / 1024))" \
                "$(<"$work/bytes")"
            ratio=""
            if [[ -n "$prev" && "$wall" != timeout && "$prev" != timeout ]]; then
                ratio="$(awk -v a="$prev" -v b="$wall" -v na="$prev_n" -v nb="$n" \
                    'BEGIN { if (a > 0 && nb > na) printf "%.2f", exp(log(b / a) * log(2) / log(nb / na)) }')"
                [[ -n "$ratio" ]] && printf '%-12s ratio %s per doubling\n' "" "$ratio"
            fi
            if [[ $grade -eq 1 ]]; then
                if [[ $wall == timeout ]]; then
                    fail "$shape $cmd n=$n: timeout after ${limit} s"
                elif [[ $rc -ne 0 ]]; then
                    fail "$shape $cmd n=$n: rc $rc"
                elif awk -v w="$wall" -v m="$max_wall" 'BEGIN { exit !(w > m) }'; then
                    fail "$shape $cmd n=$n: wall $wall s > $max_wall s"
                fi
                if [[ -n "$ratio" ]] && awk -v r="$ratio" -v m="$max_ratio" 'BEGIN { exit !(r > m) }'; then
                    fail "$shape $cmd n=$prev_n→$n: ratio $ratio > $max_ratio per doubling"
                fi
            fi
            prev="$wall" prev_n="$n"
        done
    done
done
printf 'load %s at end\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
if [[ $assert -eq 1 ]]; then
    [[ ${#fails[@]} -eq 0 ]] || { printf 'scale: %d bound(s) exceeded\n' "${#fails[@]}"; exit 1; }
    printf 'scale: every graded run within its bounds\n'
fi
