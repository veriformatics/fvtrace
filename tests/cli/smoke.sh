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
want='C1 Conditional [draft]: Assuming “The model assumptions hold.”: The contrast is the treatment effect.'
[[ "$out" == *"$want"* ]] || expect "claims prints C1's sentence" "$want" "$out"
# A must-verify fact (here the result O2) is never recorded assumed: check fails, naming it.
jq '(.facts[] | select(.id == "O2") | .status) = "assumed"' "$trace" >"$tmp/assumed.json"
out="$(fv FVTRACE_HOME="$tmp/fv" "$bin" check --trace "$tmp/assumed.json" 2>&1)"
expect "check on an assumed result rc" 1 $?
[[ "$out" == *"error WF-route /facts/1/status: O2 cannot be assumed"* ]] ||
    expect "check names the assumed result" "WF-route on O2" "$out"
fv FVTRACE_HOME="$tmp/fv" "$bin" plan C9 >/dev/null 2>&1
expect "plan on an unknown claim rc" 2 $?
fv FVTRACE_HOME="$tmp/fv" "$bin" bogus >/dev/null 2>&1
expect "unknown command rc" 2 $?

# GNU stat, truncate + a FIFO: Linux (the gate's cli stage runs there).
if [[ "$(uname -s)" == Linux ]]; then
    # A trace from someone else (a bundle can carry links): a FIFO would block on open, a device
    # never end, a sparse giant be allocated whole. Each is refused before a byte is read.
    mkfifo "$tmp/fifo.json"
    ln -s /dev/null "$tmp/device.json"
    for f in fifo device; do
        out="$(fv FVTRACE_HOME="$tmp/fv" timeout 20 "$bin" check --trace "$tmp/$f.json" 2>&1)"
        expect "check on a $f rc" 2 $?
        [[ "$out" == *"not a regular file"* ]] || expect "check names the $f" "not a regular file" "$out"
    done
    truncate -s 64G "$tmp/huge.json"
    out="$(fv FVTRACE_HOME="$tmp/fv" timeout 20 "$bin" check --trace "$tmp/huge.json" 2>&1)"
    expect "check on a 64 GiB trace rc" 1 $?
    [[ "$out" == *"the trace has 68719476736 bytes"* ]] ||
        expect "check refuses the 64 GiB trace by its size" "the trace has 68719476736 bytes" "$out"

    # serve opens the browser itself through a private redirect page: a fake xdg-open records the
    # file it gets (never the link: a command line shows in every user's process list).
    mkdir -p "$tmp/bin"
    # shellcheck disable=SC2016 # $1 + $OPENED belong to the fake opener
    printf '#!/bin/sh\nprintf "%%s\\n" "$1" >"$OPENED"\n' >"$tmp/bin/xdg-open"
    chmod +x "$tmp/bin/xdg-open"
    # Starts serve with the given assignments, then flags; waits for its last line, keeps its output.
    serve_until_ready() {
        local vars=()
        while [[ "${1:-}" == *=* ]]; do vars+=("$1"); shift; done
        rm -f "$tmp/opened" "$tmp/serve.out"
        (cd "$tmp/proj" && exec env -i PATH="$tmp/bin:$PATH" OPENED="$tmp/opened" \
            FVTRACE_HOME="$tmp/fv" "${vars[@]}" "$bin" serve --port 0 "$@" >"$tmp/serve.out" 2>&1) &
        spid=$!
        for _ in $(seq 200); do
            grep -q 'Stop with Ctrl+C.' "$tmp/serve.out" 2>/dev/null && break
            sleep 0.05
        done
        kill "$spid" 2>/dev/null
        wait "$spid" 2>/dev/null
    }
    mkdir -p "$tmp/fv/serve"
    printf 'an earlier run, its token dead\n' >"$tmp/fv/serve/open-1.html"
    serve_until_ready DISPLAY=:9
    expect "an earlier run's page is removed" "" "$(ls "$tmp/fv/serve/open-1.html" 2>/dev/null)"
    page="$(cat "$tmp/opened" 2>/dev/null)"
    [[ "$page" =~ ^"$tmp"/fv/serve/open-[0-9]+\.html$ ]] ||
        expect "serve hands the opener the redirect page" "$tmp/fv/serve/open-<port>.html" "$page"
    expect "the redirect folder is private" 700 "$(stat -c %a "$tmp/fv/serve" 2>/dev/null)"
    link="$(sed -n 's/^If the page did not open, use this link: //p' "$tmp/serve.out")"
    [[ "$link" == http://fvtrace.localhost:*/#token=* ]] ||
        expect "serve prints the link as a fallback" "http://fvtrace.localhost:<port>/#token=…" "$link"
    [[ -n "$link" && "$(cat "$page" 2>/dev/null)" == *"url=$link\""* ]] ||
        expect "the redirect page holds the link" "$link" "$(cat "$page" 2>/dev/null)"
    opened="$(grep '^Opened the claims in your browser: ' "$tmp/serve.out")"
    [[ "$opened" == *"http://fvtrace.localhost:"*"/" && "$opened" != *token* ]] ||
        expect "serve names the address without the token" "Opened … http://fvtrace.localhost:<port>/" \
            "$(cat "$tmp/serve.out")"
    for env in "DISPLAY=:9 SSH_CONNECTION=x" "DISPLAY=:9 WSL_DISTRO_NAME=x" "NO_DISPLAY=1" \
        "DISPLAY=:9 --no-browser"; do
        # shellcheck disable=SC2086 # each word = one assignment or flag
        serve_until_ready $env
        expect "no browser opens ($env)" "" "$(cat "$tmp/opened" 2>/dev/null)"
        grep -q '^Open http://fvtrace.localhost:[0-9]*/#token=[0-9a-f]*$' "$tmp/serve.out" ||
            expect "serve prints the link to open ($env)" "Open http://…/#token=…" "$(cat "$tmp/serve.out")"
    done
    # An opener that keeps running (the browser itself, started in the foreground) counts as
    # opened; a missing opener leaves the link to open by hand.
    # shellcheck disable=SC2016 # $1 + $OPENED belong to the fake opener
    printf '#!/bin/sh\nprintf "%%s\\n" "$1" >"$OPENED"\nsleep 5\n' >"$tmp/bin/xdg-open"
    serve_until_ready DISPLAY=:9
    grep -q '^Opened the claims in your browser: ' "$tmp/serve.out" ||
        expect "an opener still running counts as opened" "Opened …" "$(cat "$tmp/serve.out")"
    rm "$tmp/bin/xdg-open"
    # PATH = the emptied folder alone (a later assignment wins): no system xdg-open answers.
    serve_until_ready DISPLAY=:9 PATH="$tmp/bin"
    grep -q '^Open http://fvtrace.localhost:[0-9]*/#token=[0-9a-f]*$' "$tmp/serve.out" ||
        expect "no opener: serve prints the link" "Open http://…/#token=…" "$(cat "$tmp/serve.out")"
fi

rm -rf "$tmp/proj/rel"
after="$(cd "$tmp/proj" && find . -print0 | sort -z | xargs -0 sha256sum 2>/dev/null)"
expect "project folder unchanged" "$before" "$after"

[[ $fail -eq 0 ]] && printf 'cli smoke: ok\n'
exit "$fail"
