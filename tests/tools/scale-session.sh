#!/usr/bin/env bash
set -uo pipefail
# shellcheck source=/dev/null
source <(sed -n '/^session_row() {/,/^}/p' tools/scale.sh)
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
for kind in page gui; do
    printf '%s 0 0.010 - 1024 0 0.1\n' "$kind:served:select" >"$work/$kind.rows"
    for status in 3 124; do
        printf '%s\n' "$status" >"$work/$kind.rc"
        read -r rc _ < <(session_row "$work" "$kind:served:select")
        [[ $rc -eq $status ]] || {
            printf 'FAIL: %s session exit %s became row rc %s\n' "$kind" "$status" "$rc" >&2
            exit 1
        }
    done
    printf '0\n' >"$work/$kind.rc"
    read -r rc wall _ < <(session_row "$work" "$kind:served:select")
    [[ $rc -eq 0 && $wall == 0.010 ]] || exit 1
done
printf 'session exits graded before their completed rows\n'
