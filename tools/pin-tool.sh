#!/usr/bin/env bash
# Re-pins one tool in tools/tools.lock to a release: every platform line gets the release's asset
# URL + the sha256 digest GitHub records for it (linux + darwin tarballs; the Windows zip for a tool
# that pins one, i.e. elan-init). Usage: tools/pin-tool.sh <name> <version> (a Renovate PR bumps
# the linux-x86_64 version alone; this rewrites every line).
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/tools/tools.lock"
name="${1:?usage: pin-tool.sh <name> <version>}"
version="${2:?usage: pin-tool.sh <name> <version>}"

repo="$(awk -v n="$name" '$1 == n { sub(/^https:\/\/github.com\//, "", $5); split($5, p, "/"); print p[1] "/" p[2]; exit }' "$lock")"
if [[ -z "$repo" ]]; then
    printf 'pin-tool: %s is not in %s\n' "$name" "$lock" >&2
    exit 2
fi

release="$(curl -fsSL "https://api.github.com/repos/$repo/releases/tags/v$version" ||
    curl -fsSL "https://api.github.com/repos/$repo/releases/tags/$version")"
windows="$(awk -v n="$name" '$1 == n && $3 ~ /^windows-/ { print "true"; exit }' "$lock")"
want=4
[[ "$windows" == true ]] && want=5
lines="$(jq -r --arg n "$name" --arg v "$version" --argjson w "${windows:-false}" '.assets[]
    | select((.name | test("(linux|darwin).*tar.gz$")) or ($w and (.name | test("windows.*zip$"))))
    | (if (.name | test("linux")) then "linux" elif (.name | test("darwin")) then "darwin" else "windows" end) as $os
    | (if (.name | test("x86_64|amd64|x64")) then "x86_64" elif (.name | test("aarch64|arm64")) then "aarch64" else empty end) as $arch
    | "\($n) \($v) \($os)-\($arch) \(.digest | sub("^sha256:"; "")) \(.browser_download_url)"' <<<"$release" | sort -u)"
if [[ "$(wc -l <<<"$lines")" -ne $want ]]; then
    printf 'pin-tool: expected %d platform assets for %s %s, found:\n%s\n' "$want" "$name" "$version" "$lines" >&2
    exit 1
fi

{
    grep -v -E "^$name " "$lock"
    printf '%s\n' "$lines"
} | awk 'NR <= 2 || /^#/ { print; next } { print | "sort" }' >"$lock.new"
mv "$lock.new" "$lock"
printf 'pin-tool: %s pinned to %s\n' "$name" "$version"
