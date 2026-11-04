#!/usr/bin/env bash
# pnpm-lock.yaml re-resolved under the release-age floor (deps.md: 7 days = 10080 minutes).
# node_modules goes too: a lockfile deleted alone comes back from node_modules/.pnpm/lock.yaml
# ("resolution step is skipped", nothing refreshed). Each PKG@VERSION argument = an adopted pin
# still inside the window, exempted by one flag each (a comma list fails "Invalid versions union");
# a packageManager bump names pnpm + its @pnpm/exe.<platform> packages.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root"

exclude=()
for p in "$@"; do
    [[ $p == ?*@?* ]] || {
        printf 'usage: tools/refresh-lock.sh [PKG@VERSION...]\n' >&2
        exit 2
    }
    exclude+=("--config.minimum-release-age-exclude=$p")
done
rm -rf node_modules pnpm-lock.yaml
pnpm install --config.minimum-release-age=10080 "${exclude[@]}"
