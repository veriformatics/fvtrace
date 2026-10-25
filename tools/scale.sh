#!/usr/bin/env bash
# Engine bounds (`.agent/contracts/kernel.md` § Performance, P-bound + P-evidence): times the
# P-time + U-time rows on the generated shapes of tools/scale.mjs.
#   tools/scale.sh [--assert] [--bin PATH] [--gui PATH] [--timeout S] [--max-wall S]
#                  [--max-ratio R] [--n "N1 N2 …"] [shape…]
# Default: every shape at n = cap/2 and cap (the largest n within 16 MiB; whatif: its what-if
# within one argument too), the built binary, 900 s per run. Rows per shape + n: `check`, `eval`,
# `action` (eval --action of action.txt), `details:<kind>` (eval --details of each items.txt
# line), `export` (--html), on the F5 four the text commands `claims`, `gaps`, `experiments`,
# `plan` (of items.txt's claim; elsewhere their output grows by design, kernel.md P-time); `serve` = one server: its launch (start → the recorded answer), then,
# as the GUI sends them, `serve:whatif` (a whatif.txt view), `serve:details:<kind>` at that view,
# `serve:action` from it; `page` = the exported page's engine (tools/scale-page.mjs): start-up,
# then the same steps; `gui:<served|page>:<step>` = the GUI in Chromium (tools/scale-gui.mjs or
# --gui: U-time, each row with its own bound). One row per run (shape, n, input bytes, command,
# rc, wall s, user s, max RSS MiB, output bytes; serve: the server's CPU + peak RSS so far; gui:
# the page's live JS memory once the mode's steps end); per shape + command, the wall ratio of
# consecutive rows, scaled to one doubling of n.
# --assert grades the graded shapes (wide deep experiments exclusions outcomes prereqs whatif):
# exit 1 on a nonzero rc, a timeout, a wall time above --max-wall (10: Nielsen's attention limit)
# or a GUI row's own bound, a per-doubling wall or RSS ratio above --max-ratio (2.5) or eval output
# ratio above 2.2 (P-bound), or an outcomes, prereqs or whatif eval (outcomes + prereqs: serve too)
# at its largest n above 1.25 × the worst eval RSS of the F5 four (P-memory), one `FAIL` line per
# breach. Other shapes are reported, never graded. Time it where the host is idle: the bounds are
# wall-clock (load is printed at start + end).
set -uo pipefail
export LC_ALL=C

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$root/.lake/build/bin/fvtrace"
gui="$root/tools/scale-gui.mjs"
limit=900 max_wall=10 max_ratio=2.5 assert=0
sizes=""
shapes=()
usage='usage: tools/scale.sh [--assert] [--bin PATH] [--gui PATH] [--timeout S] [--max-wall S] [--max-ratio R] [--n "N…"] [shape…]'
while [[ $# -gt 0 ]]; do
    case "$1" in
    --assert) assert=1; shift ;;
    --bin) bin="$(realpath -- "$2")"; shift 2 ;;
    --gui) gui="$(realpath -- "$2")"; shift 2 ;;
    --timeout) limit="$2"; shift 2 ;;
    --max-wall) max_wall="$2"; shift 2 ;;
    --max-ratio) max_ratio="$2"; shift 2 ;;
    --n) sizes="$2"; shift 2 ;;
    -*) printf '%s\n' "$usage" >&2; exit 2 ;;
    *) shapes+=("$1"); shift ;;
    esac
done
graded=" wide deep experiments exclusions outcomes prereqs whatif "
f5=" wide deep experiments exclusions "
[[ ${#shapes[@]} -gt 0 ]] ||
    shapes=(wide deep experiments exclusions hub questions waivers receipts outcomes prereqs whatif invalid)

work="$(mktemp -d)"
srv=""
trap '[[ -n "$srv" ]] && kill "$srv" 2>/dev/null; rm -rf "$work"' EXIT
fails=()
fail() { fails+=("$1"); printf 'FAIL %s\n' "$1"; }
declare -A last_rss=()
# The ratio of b to a scaled to one doubling of n (na → nb) + 1 when it is over the bound m,
# graded as a double before any rounding (2.504 prints as 2.50 but exceeds 2.5).
doubling() {
    awk -v a="$1" -v b="$2" -v na="$3" -v nb="$4" -v m="$5" 'BEGIN { if (a > 0 && b > 0 && nb > na) {
        r = exp(log(b / a) * log(2) / log(nb / na)); printf "%.4f %d\n", r, (r > m) } }'
}
since() { awk -v a="$1" -v b="$EPOCHREALTIME" 'BEGIN { printf "%.2f", b - a }'; }
tck="$(getconf CLK_TCK)"
# The server's user CPU seconds (/proc stat field 14, in clock ticks) + its peak RSS (KiB).
srv_user() { awk -v t="$tck" '{ printf "%.2f", $14 / t }' "/proc/$srv/stat" 2>/dev/null || echo 0; }
srv_rss() { awk '/^VmHWM:/ { print $2 }' "/proc/$srv/status" 2>/dev/null || echo 0; }

# One request to the server: its row (step rc wall user rss bytes) → "$rows"; wall counts from
# $3 (default: now), user CPU from $4 (default: the server's so far, at the request).
srv_ask() {
    local step="$1" t="${3:-$EPOCHREALTIME}" u0="${4:-$(srv_user)}" code rc
    printf '%s' "$2" >"$work/body"
    code="$(curl -s -o "$work/answer" -w '%{http_code}' --max-time "$limit" \
        -H "Authorization: Bearer $token" -H 'Content-Type: application/json' \
        --data-binary @"$work/body" "http://127.0.0.1:$port/api/answer")"
    rc=$?
    if [[ $rc -eq 28 ]]; then printf '%s 124 timeout - %s 0\n' "$step" "$(srv_rss)" >>"$rows"
    else
        [[ $rc -eq 0 && $code != 200 ]] && rc="$code"
        printf '%s %s %s %s %s %s\n' "$step" "$rc" "$(since "$t")" \
            "$(awk -v a="$u0" -v b="$(srv_user)" 'BEGIN { printf "%.2f", b - a }')" "$(srv_rss)" \
            "$(wc -c <"$work/answer")" >>"$rows"
    fi
}

# P-time's serve rows for the trace in $1: one server, its launch (start → the recorded answer
# ready: a request on arrival waits for the launch evaluation) + the GUI's requests in order.
serve_rows() {
    local dir="$1" w="$2" t0 link item
    rows="$dir/serve.rows" token="" port=""
    : >"$rows"
    t0="$EPOCHREALTIME"
    FVTRACE_HOME="$work/home" "$bin" serve --port 0 --no-browser --trace "$dir/trace.json" \
        --project "$dir/project" >"$work/serve.log" 2>&1 &
    srv=$!
    # Ready = the printed link; bounded by the server exiting + the time limit.
    until link="$(grep -o 'http://[^ ]*#token=[0-9a-f]*' "$work/serve.log")"; do
        if ! kill -0 "$srv" 2>/dev/null; then
            wait "$srv"
            printf 'serve %s - - 0 0\n' "$(($? ? $? : 1))" >>"$rows"
            srv=""
            return
        fi
        awk -v e="$(since "$t0")" -v l="$limit" 'BEGIN { exit !(e > l) }' && break
        sleep 0.02
    done
    if [[ -z "$link" ]]; then printf 'serve 124 timeout - 0 0\n' >>"$rows"
    else
        token="${link##*#token=}" port="${link#http://*:}" port="${port%%/*}"
        srv_ask serve '{"whatif":""}' "$t0" 0
        [[ -n "$w" ]] && srv_ask serve:whatif "$(jq -cn --arg w "$w" '{whatif: $w}')"
        while read -r item; do
            srv_ask "serve:details:${item%%:*}" \
                "$(jq -cn --arg w "$w" --arg i "$item" '{whatif: $w, details: $i}')"
        done <"$dir/items.txt"
        srv_ask serve:action "$(jq -cn --arg w "$w" --arg a "$(<"$dir/action.txt")" \
            '{whatif: $w, action: $a}')"
    fi
    kill "$srv" 2>/dev/null
    wait "$srv" 2>/dev/null
    srv=""
}

# P-time's page rows: the exported page ($dir/page.html, the export row's) through its engine.
page_rows() {
    local dir="$1" w="$2" items=()
    while read -r item; do items+=("$item"); done <"$dir/items.txt"
    timeout "$((limit * (${#items[@]} + 3)))" node "$root/tools/scale-page.mjs" "$dir/page.html" \
        "$w" "$(<"$dir/action.txt")" "${items[@]}" >"$dir/page.rows" 2>"$work/page.err"
    echo "$?" >"$dir/page.rc"
}

# P-time's GUI rows (kernel.md U-time): one Chromium run, served + exported (the export row's page).
gui_rows() {
    local dir="$1"
    timeout "$((limit * 2))" node "$gui" "$bin" "$dir" "$dir/page.html" >"$dir/gui.rows" \
        2>"$work/gui.err"
    echo "$?" >"$dir/gui.rc"
}

# A session step's measurement (rc wall user rss bytes [bound]); a step without a row = the
# session ended before it (rc 124 = it timed out).
session_row() {
    local row src="${2%%:*}"
    row="$(awk -v s="$2" '$1 == s { print $2, $3, $4, $5, $6, $7; exit }' "$1/$src.rows" 2>/dev/null)"
    if [[ -n "$row" ]]; then printf '%s\n' "$row"
    elif [[ "$(cat "$1/$src.rc" 2>/dev/null)" == 124 ]]; then printf '124 timeout - 0 0\n'
    else printf '1 - - 0 0\n'; fi
}

printf 'binary %s sha256 %s\n' "$bin" "$(sha256sum "$bin" | cut -d' ' -f1)"
printf 'host %s, %s CPUs, load %s at start\n' "$(uname -n)" "$(nproc)" "$(cut -d' ' -f1-3 /proc/loadavg)"
row='%-12s %8s %9s %-24s %4s %9s %9s %8s %11s\n'
# shellcheck disable=SC2059 # one format for the header + every row
printf "$row" shape n bytes cmd rc wall user rss_mib out_bytes
for shape in "${shapes[@]}"; do
    ns="${sizes:-}"
    if [[ -z "$ns" ]]; then
        cap="$(node "$root/tools/scale.mjs" "$shape" cap)" || exit 2
        ns="$((cap / 2)) $cap"
    fi
    grade=0
    [[ $assert -eq 1 && "$graded" == *" $shape "* ]] && grade=1
    first="$work/$shape-${ns%% *}"
    [[ -f "$first/trace.json" ]] || node "$root/tools/scale.mjs" "$shape" "${ns%% *}" "$first" ||
        exit 2
    # P-time's rows: the costliest action + the costliest item of each kind (tools/scale.mjs).
    kinds=()
    while read -r item; do kinds+=("${item%%:*}"); done <"$first/items.txt"
    cmds=(check eval action "${kinds[@]/#/details:}" export)
    [[ "$f5" == *" $shape "* ]] && cmds+=(claims gaps experiments plan)
    cmds+=(serve)
    [[ -f "$first/whatif.txt" ]] && cmds+=(serve:whatif)
    cmds+=("${kinds[@]/#/serve:details:}" serve:action page)
    [[ -f "$first/whatif.txt" ]] && cmds+=(page:whatif)
    cmds+=("${kinds[@]/#/page:details:}" page:action)
    for mode in served page; do
        for step in first select details busy whatif; do cmds+=("gui:$mode:$step"); done
    done
    cmds+=(gui:page:startup)
    for cmd in "${cmds[@]}"; do
        prev="" prev_n=""
        for n in $ns; do
            dir="$work/$shape-$n"
            [[ -f "$dir/trace.json" ]] || node "$root/tools/scale.mjs" "$shape" "$n" "$dir" || exit 2
            w=""
            [[ -f "$dir/whatif.txt" ]] && w="$(<"$dir/whatif.txt")"
            whatif=()
            [[ -n "$w" ]] && whatif=(--whatif "$w")
            case "$cmd" in
            serve*)
                [[ -f "$dir/serve.rows" ]] || serve_rows "$dir" "$w"
                read -r rc wall user rss bytes bound < <(session_row "$dir" "$cmd") ;;
            page*)
                [[ -f "$dir/page.rows" ]] || page_rows "$dir" "$w"
                read -r rc wall user rss bytes bound < <(session_row "$dir" "$cmd") ;;
            gui*)
                [[ -f "$dir/gui.rows" ]] || gui_rows "$dir"
                read -r rc wall user rss bytes bound < <(session_row "$dir" "$cmd") ;;
            *)
                case "$cmd" in
                check) args=(check) ;;
                eval) args=(eval "${whatif[@]}") ;;
                action) args=(eval "${whatif[@]}" --action "$(<"$dir/action.txt")") ;;
                details:*)
                    args=(eval "${whatif[@]}" --details "$(grep -m1 "^${cmd#details:}:" "$dir/items.txt")") ;;
                export) args=(export --html "$dir/page.html") ;;
                claims | gaps | experiments) args=("$cmd") ;;
                plan) c="$(grep -m1 '^claim:' "$dir/items.txt")" && args=(plan "${c#claim:}") ;;
                esac
                args+=(--trace "$dir/trace.json" --project "$dir/project")
                : >"$work/time"
                # Output is counted, never stored: the tail shapes print gigabytes at their cap.
                FVTRACE_HOME="$work/home" timeout "$limit" /usr/bin/time -o "$work/time" \
                    -f '%e %U %M' "$bin" "${args[@]}" 2>/dev/null | wc -c >"$work/bytes"
                rc=${PIPESTATUS[0]}
                bytes="$(<"$work/bytes")"
                # GNU time puts "Command exited with non-zero status N" above its format line.
                wall="" user="" rss=0
                read -r wall user rss < <(tail -n 1 "$work/time") || true
                [[ $rc -eq 124 || -z "$wall" ]] && { wall=timeout; user=-; rss=0; } ;;
            esac
            # shellcheck disable=SC2059
            printf "$row" "$shape" "$n" "$(stat -c %s "$dir/trace.json")" "$cmd" "$rc" "$wall" \
                "$user" "$((rss / 1024))" "$bytes"
            bound="${bound:-$max_wall}"
            ratio="" over=0 rratio="" rover=0 bratio="" bover=0
            if [[ -n "$prev" && "$wall" != timeout && "$prev" != timeout ]]; then
                read -r ratio over < <(doubling "$prev" "$wall" "$prev_n" "$n" "$max_ratio")
                read -r rratio rover < <(doubling "$prev_rss" "$rss" "$prev_n" "$n" "$max_ratio")
                [[ $cmd == eval ]] &&
                    read -r bratio bover < <(doubling "$prev_bytes" "$bytes" "$prev_n" "$n" 2.2)
                [[ -n "$ratio" ]] && printf '%-12s ratio %.2f per doubling (rss %s, bytes %s)\n' "" \
                    "$ratio" "${rratio:--}" "${bratio:--}"
            fi
            if [[ $grade -eq 1 ]]; then
                if [[ $wall == timeout ]]; then
                    fail "$shape $cmd n=$n: timeout after ${limit} s"
                elif [[ $rc -ne 0 ]]; then
                    fail "$shape $cmd n=$n: rc $rc"
                elif awk -v w="$wall" -v m="$bound" 'BEGIN { exit !(w > m) }'; then
                    fail "$shape $cmd n=$n: wall $wall s > $bound s"
                fi
                [[ "$rover" == 1 ]] &&
                    fail "$shape $cmd n=$prev_n→$n: rss ratio $rratio > $max_ratio per doubling"
                [[ "$bover" == 1 ]] &&
                    fail "$shape $cmd n=$prev_n→$n: bytes ratio $bratio > 2.2 per doubling"
                if [[ "$over" == 1 ]]; then
                    fail "$shape $cmd n=$prev_n→$n: ratio $ratio > $max_ratio per doubling"
                fi
            fi
            prev="$wall" prev_n="$n" prev_rss="$rss" prev_bytes="$bytes" bound=""
            last_rss["$shape:$cmd"]="$rss"
        done
    done
done
# P-memory: at their largest n, outcomes + prereqs + whatif eval and one outcomes + prereqs serve
# evaluation (its launch) within 1.25 × the worst eval RSS of the F5 four (same binary, same run).
worst=0
for f5 in wide deep experiments exclusions; do
    r="${last_rss["$f5:eval"]:-0}"
    ((r > worst)) && worst=$r
done
if [[ $assert -eq 1 && $worst -gt 0 ]]; then
    for big in outcomes:eval prereqs:eval whatif:eval outcomes:serve prereqs:serve; do
        r="${last_rss["$big"]:-}"
        [[ -n "$r" ]] && awk -v r="$r" -v w="$worst" 'BEGIN { exit !(r > 1.25 * w) }' &&
            fail "${big/:/ }: rss $((r / 1024)) MiB > 1.25 × $((worst / 1024)) MiB (the F5 four's worst)"
    done
fi
printf 'load %s at end\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
if [[ $assert -eq 1 ]]; then
    [[ ${#fails[@]} -eq 0 ]] || { printf 'scale: %d bound(s) exceeded\n' "${#fails[@]}"; exit 1; }
    printf 'scale: every graded run within its bounds\n'
fi
