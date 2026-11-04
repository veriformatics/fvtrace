#!/usr/bin/env bash
# Renovate run locally under the release-age floor (deps.md). `check` = the config validator,
# strict, its regexes compiled by RE2 (`--allow-build=re2`: without re2's native build it warns
# "RE2 not usable" + checks under JS RegExp instead). `lookup MANAGER[,MANAGER...]` = what Renovate
# would propose for this tree (dry run, no platform): the "packageFiles with updates" record, run
# under Node 24 (Renovate's engines: ^24.11; it refuses 26). Both run Renovate's newest release at
# least 7 days old.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root"

usage() {
    printf 'usage: tools/renovate.sh check | lookup MANAGER[,MANAGER...]\n' >&2
    exit 2
}

release() {
    npm view renovate time --json | node -e '
        const read = JSON.parse(require("fs").readFileSync(0, "utf8"));
        const t = Array.isArray(read) ? read[0] : read; // npm 11 wraps the object in an array
        const cutoff = Date.now() - 7 * 864e5;
        const key = (v) => v.split(".").map(Number);
        const ok = Object.keys(t)
            .filter((v) => /^\d+\.\d+\.\d+$/.test(v) && Date.parse(t[v]) <= cutoff)
            .sort((a, b) => { const x = key(a), y = key(b); return x[0] - y[0] || x[1] - y[1] || x[2] - y[2]; });
        if (ok.length === 0) { console.error("no renovate release is 7 days old"); process.exit(1); }
        console.log(ok[ok.length - 1]);'
}

check() {
    local out rc
    out="$(pnpm dlx --allow-build=re2 --package "renovate@$1" renovate-config-validator --strict 2>&1)" &&
        rc=0 || rc=$?
    printf '%s\n' "$out"
    # The validator passes under its JS RegExp fallback too (re2's native module built for another
    # Node), so the warning fails the check here.
    if grep -q 'RE2 not usable' <<<"$out"; then
        printf 'renovate.sh: the regexes were not checked by RE2\n' >&2
        return 1
    fi
    return "$rc"
}

case "${1:-}" in
check)
    [[ $# -eq 1 ]] || usage
    v="$(release)"
    printf 'renovate %s\n' "$v" >&2
    check "$v"
    ;;
lookup)
    [[ $# -eq 2 ]] || usage
    v="$(release)"
    printf 'renovate %s\n' "$v" >&2
    # github-releases + github-tags lookups need a token (else "skipReason": "github-token-required").
    GITHUB_COM_TOKEN="${GITHUB_COM_TOKEN:-$(gh auth token 2>/dev/null || true)}"
    export GITHUB_COM_TOKEN
    # pnpm prints plain lines before Renovate's JSON log.
    LOG_LEVEL=debug LOG_FORMAT=json pnpm dlx --allow-build=re2 --package node@24 --package "renovate@$v" \
        renovate --platform=local --dry-run=lookup --enabled-managers="$2" |
        jq -R 'fromjson? | select(.msg == "packageFiles with updates")'
    ;;
*) usage ;;
esac
