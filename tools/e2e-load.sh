#!/usr/bin/env bash
# e2e under host load (.claude/rules/web.md e2e limits): the evidence behind each limit.
#   measure <hogs> — `playwright test` with limits lifted after <hogs> busy loops raise the 1-min load
#                    average to <hogs>; prints the load seen + the slowest tests (the limits' sizing).
#   gate <runs>    — `bash tools/gate.sh` <runs> times while busy loops hold the 1-min load at
#                    ≥ 1.5 × nproc; prints each run's load during e2e. rc 1 = a red run, rc 3 = a run
#                    whose e2e saw the load dip below 1.5 × nproc (it does not count).
# Logs → .scratch/e2e-load/. Run it where the load is yours to raise (a shared host slows its other work).
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 2
export PATH="$root/node_modules/.bin:$PATH"
out=.scratch/e2e-load
mkdir -p "$out"

load1() { cut -d' ' -f1 /proc/loadavg; }
spin() { while :; do :; done; }
# Load samples (epoch, 1-min load) every 5 s into $1 until killed.
sample() { while :; do printf '%s %s\n' "$EPOCHSECONDS" "$(load1)"; sleep 5; done >"$1"; }
# Lowest 1-min load sampled in $1 between epochs $2 and $3 (empty: no samples).
low() { awk -v s="$2" -v e="$3" '$1 >= s && $1 <= e && (n++ == 0 || $2 < lo) { lo = $2 } END { print lo }' "$1"; }
# min / max / mean of the samples in $1 between epochs $2 and $3.
span() {
    awk -v s="$2" -v e="$3" '$1 >= s && $1 <= e { if (n == 0 || $2 < lo) lo = $2; if ($2 > hi) hi = $2; t += $2; n++ }
        END { if (n) printf "load %s–%s, mean %.1f (%d samples)", lo, hi, t / n, n; else printf "no load samples" }' "$1"
}

measure() {
    local hogs="$1" pids=() s rc
    shift
    for _ in $(seq "$hogs"); do spin & pids+=($!); done
    until (($(load1 | cut -d. -f1) >= hogs)); do sleep 5; done
    sample "$out/measure.load" & pids+=($!)
    s=$EPOCHSECONDS
    playwright test --reporter=json --timeout=600000 "$@" >"$out/measure.json" 2>"$out/measure.err"
    rc=$?
    kill "${pids[@]}" 2>/dev/null
    wait 2>/dev/null
    printf 'measure: %d busy loops, playwright rc=%d in %ds, %s\n' "$hogs" "$rc" "$((EPOCHSECONDS - s))" \
        "$(span "$out/measure.load" "$s" "$EPOCHSECONDS")"
    jq -r '[.. | objects | select(has("specs")) | .specs[] | . as $s | .tests[].results[] |
        {t: "\($s.file):\($s.line)", d: .duration, st: .status}] | sort_by(-.d) | .[0:6][] |
        "  \(.d / 1000 * 10 | round / 10) s \(.st) \(.t)"' "$out/measure.json"
    return $rc
}

# Busy loops ±1 per 10 s toward a 1-min load in [$1, $1 + 3]; runs until killed. The average lags
# its input by about a minute, so the band sits above the load a run must hold.
control() {
    local band="$1" pids=() l
    trap 'kill "${pids[@]}" $! 2>/dev/null; exit 0' TERM
    while :; do
        l=$(load1)
        l=${l%.*}
        if ((l < band)); then
            spin &
            pids+=($!)
        elif ((l > band + 3 && ${#pids[@]} > 0)); then
            kill "${pids[-1]}"
            unset 'pids[-1]'
        fi
        # Waited on, not run in the foreground: the TERM trap then fires at once.
        sleep 10 &
        wait $!
    done
}

gate() {
    local runs="$1" target cpid spid rc s e i lo
    target=$(($(nproc) * 3 / 2))
    for i in $(seq "$runs"); do
        control $((target + 3)) &
        cpid=$!
        until (($(load1 | cut -d. -f1) >= target + 3)); do sleep 5; done
        sample "$out/gate-$i.load" &
        spid=$!
        bash tools/gate.sh 2>&1 | while IFS= read -r line; do printf '%s %s\n' "$EPOCHSECONDS" "$line"; done >"$out/gate-$i.log"
        rc=${PIPESTATUS[0]}
        kill "$spid" "$cpid"
        wait 2>/dev/null
        s=$(awk '/=== e2e ===/ { print $1; exit }' "$out/gate-$i.log")
        e=$(awk '/ e2e rc=/ { print $1; exit }' "$out/gate-$i.log")
        printf 'gate run %d (target load %d): %s · %s · during e2e: %s\n' "$i" "$target" \
            "$(grep -o 'gate rc=[0-9]* [0-9.]*s' "$out/gate-$i.log" | tail -1)" \
            "$(grep -o 'e2e rc=[0-9]* [0-9.]*s' "$out/gate-$i.log" | tail -1)" \
            "$(span "$out/gate-$i.load" "${s:-0}" "${e:-0}")"
        ((rc == 0)) || {
            printf 'gate run %d red: %s\n' "$i" "$(grep -o 'FAILED: .*' "$out/gate-$i.log")"
            return 1
        }
        lo=$(low "$out/gate-$i.load" "${s:-0}" "${e:-0}")
        if [[ -z "$lo" ]] || ! awk -v l="$lo" -v t="$target" 'BEGIN { exit !(l >= t) }'; then
            printf 'gate run %d: load during e2e fell to %s (< %d); the run does not count\n' "$i" "${lo:-none}" "$target"
            return 3
        fi
    done
}

if [[ "${1:-}" == measure && "${2:-}" =~ ^[0-9]+$ ]]; then
    shift
    measure "$@"
elif [[ "${1:-}" == gate && "${2:-}" =~ ^[1-9][0-9]*$ && $# -eq 2 ]]; then
    gate "$2"
else
    printf 'usage: tools/e2e-load.sh measure <hogs> [playwright args] | gate <runs>\n' >&2
    exit 2
fi
