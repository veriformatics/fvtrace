#!/usr/bin/env bash
# wasm.md Determinism end to end: two clean page engine builds, in folders at different paths
# and depths, give byte-identical engine.wasm + engine.b64. Campaign tier (two full Lean +
# engine builds): run after a change to the build's object keys, flags or link order, and at a
# phase close. Each copy = the tracked files as they are in this tree + the pinned downloads from
# this tree's cache (the build verifies them again), never its objects, Init C or engine.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
copies=("$work/a/fvtrace" "$work/bb/deeper/fvtrace-copy")
for d in "${copies[@]}"; do
    mkdir -p "$d/.lake/build/wasm"
    git ls-files -z | rsync -a --from0 --files-from=- ./ "$d/"
    for f in .lake/build/wasm/download .lake/build/wasm/emsdk-* .lake/build/wasm/lean-runtime-* \
        .lake/build/wasm/libuv-*; do
        [[ -e "$f" ]] && cp -a "$f" "$d/.lake/build/wasm/"
    done
done
pids=()
for d in "${copies[@]}"; do
    (cd "$d" && lake build FvtraceEngine >"$d.log" 2>&1) &
    pids+=($!)
done
rc=0
for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || {
        printf 'wasm-repro: the build in %s failed:\n' "${copies[$i]}" >&2
        tail -20 "${copies[$i]}.log" >&2
        rc=1
    }
done
[[ $rc -eq 0 ]] || exit 1
for f in engine.wasm engine.b64; do
    cmp "${copies[0]}/.lake/build/wasm/$f" "${copies[1]}/.lake/build/wasm/$f" || rc=1
    printf 'wasm-repro: %s %s\n' "$f" "$(sha256sum "${copies[0]}/.lake/build/wasm/$f" | cut -d' ' -f1)"
done
[[ $rc -eq 0 ]] && printf 'wasm-repro: two clean builds in different folders gave the same bytes\n'
exit $rc
