#!/usr/bin/env bash
# tools/scale.sh's run picking (user ruling: each row = its fastest run): a failed or unfinished
# run outranks the faster ones beside it; a step missing from a run is left out.
set -uo pipefail
# shellcheck source=/dev/null
source <(sed -n -e '/^fastest() {/,/^}/p' -e '/^walls() {/p' tools/scale.sh)
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
bad() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}
# Sessions, one file per run: a = fastest in run 2 (its whole row), b = run 2 failed though run 3
# is faster, c = missing from run 3, d = run 3 has no wall time.
printf '%s\n' 'a 0 0.480 - 10 0 1' 'b 0 0.010 - 10 0 1' 'c 0 0.020 - 10 0 1' 'd 0 0.030 - 10 0 1' \
    >"$work/1"
printf '%s\n' 'a 0 0.363 - 11 0 1' 'b 3 0.005 - 11 0 1' 'c 0 0.010 - 11 0 1' 'd 0 0.040 - 11 0 1' \
    >"$work/2"
printf '%s\n' 'a 0 0.380 - 12 0 1' 'b 0 0.001 - 12 0 1' 'd 0 timeout - 12 0 1' >"$work/3"
got="$(fastest "$work/1" "$work/2" "$work/3")"
[[ $got == $'a 0 0.363 - 11 0 1\nb 3 0.005 - 11 0 1\nd 0 timeout - 12 0 1' ]] ||
    bad "session rows picked as: $got"
[[ "$(walls a "$work/1" "$work/2" "$work/3")" == 0.480,0.363,0.380 ]] || bad "walls of a"
# A command's runs in one file (the CLI rows).
printf '%s\n' 'check 0 0.19 0.18 100 5' 'check 0 0.14 0.13 101 5' 'check 0 0.16 0.15 102 5' \
    >"$work/cli"
[[ "$(fastest "$work/cli")" == 'check 0 0.14 0.13 101 5' ]] || bad "the fastest CLI run"
printf '%s\n' 'check 0 0.19 0.18 100 5' 'check 124 timeout - 0 0' >"$work/cli"
[[ "$(fastest "$work/cli")" == 'check 124 timeout - 0 0' ]] || bad "a CLI run that timed out"
printf 'each row = its fastest run; a failed or unfinished run outranks it\n'
