#!/usr/bin/env bash
# The shipped binary end to end: data-folder selection from the environment (the Lean suite cannot
# set variables in-process), exit codes, and no write outside the data folder.
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
# FVTRACE_SMOKE_BIN = another binary to judge (tools/gate-probe.sh plants a faulty one).
bin="${FVTRACE_SMOKE_BIN:-$root/.lake/build/bin/fvtrace}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

expect() {
    if [[ "$2" != "$3" ]]; then
        printf 'FAIL %s: want [%s], got [%s]\n' "$1" "$2" "$3" >&2
        fail=1
    fi
}

# Runs the binary in the project folder with a clean environment plus the given assignments.
fv() { (cd "$tmp/proj" && env -i PATH="$PATH" "$@"); }

mkdir -p "$tmp/home" "$tmp/xdg" "$tmp/proj/proofs"
printf 'theorem contrast_correct : True := trivial\n' >"$tmp/proj/proofs/Contrast.lean"
before="$(cd "$tmp/proj" && find . -print0 | sort -z | xargs -0 sha256sum 2>/dev/null)"

fv HOME="$tmp/home" "$bin" --version >/dev/null
expect "--version rc" 0 $?
fv HOME="$tmp/home" "$bin" check >/dev/null 2>&1
expect "check before init rc" 2 $?

fv HOME="$tmp/home" XDG_DATA_HOME="$tmp/xdg" FVTRACE_HOME="$tmp/fv" "$bin" init >/dev/null
expect "init rc" 0 $?
trace="$(fv HOME="$tmp/home" FVTRACE_HOME="$tmp/fv" "$bin" path)"
expect "FVTRACE_HOME holds the trace" "$tmp/fv" "${trace%/proj-*}"
expect "HOME untouched" "" "$(ls -A "$tmp/home")"
expect "XDG_DATA_HOME untouched" "" "$(ls -A "$tmp/xdg")"
expect "relative FVTRACE_HOME = under the current folder" "$tmp/proj/rel" \
    "$(p="$(fv HOME="$tmp/home" FVTRACE_HOME=rel "$bin" path)" && printf '%s' "${p%/proj-*}")"

if [[ "$(uname -s)" == Linux ]]; then
    p="$(fv HOME="$tmp/home" XDG_DATA_HOME="$tmp/xdg" "$bin" path)"
    expect "XDG_DATA_HOME/fvtrace" "$tmp/xdg/fvtrace" "${p%/proj-*}"
    p="$(fv HOME="$tmp/home" XDG_DATA_HOME=relative "$bin" path)"
    expect "relative XDG_DATA_HOME ignored" "$tmp/home/.local/share/fvtrace" "${p%/proj-*}"
    p="$(fv HOME="$tmp/home" "$bin" path)"
    expect "HOME/.local/share/fvtrace" "$tmp/home/.local/share/fvtrace" "${p%/proj-*}"
fi
fv "$bin" path >/dev/null 2>&1
expect "no HOME and no FVTRACE_HOME rc" 2 $?

cp "$root/tests/fixtures/synthetic.trace.json" "$trace"
fv FVTRACE_HOME="$tmp/fv" "$bin" pin >/dev/null
expect "pin rc" 0 $?
fv FVTRACE_HOME="$tmp/fv" "$bin" check --strict >/dev/null
expect "check --strict rc" 0 $?
out="$(fv FVTRACE_HOME="$tmp/fv" "$bin" claims)"
expect "claims rc" 0 $?
# The engine's curly quotes, as the claims command prints them.
want='C1 On assumption [draft]: Assuming “O1 entails C1.”: The contrast is the treatment effect.'
[[ "$out" == *"$want"* ]] || expect "claims prints C1's sentence" "$want" "$out"
fv FVTRACE_HOME="$tmp/fv" "$bin" plan C9 >/dev/null 2>&1
expect "plan on an unknown claim rc" 2 $?
fv FVTRACE_HOME="$tmp/fv" "$bin" bogus >/dev/null 2>&1
expect "unknown command rc" 2 $?

rm -rf "$tmp/proj/rel"
after="$(cd "$tmp/proj" && find . -print0 | sort -z | xargs -0 sha256sum 2>/dev/null)"
expect "project folder unchanged" "$before" "$after"

[[ $fail -eq 0 ]] && printf 'cli smoke: ok\n'
exit "$fail"
