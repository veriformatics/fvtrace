#!/usr/bin/env bash
# The dev toolchain on a fresh host (gitignored paths start empty: a new clone, a remote runner):
# the Node packages at their locked versions, the pinned scanners, Playwright's Chromium. Each step
# returns at once when its part is already in place. Lean (elan) + the system tools: ops.md Env.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root"

pnpm install --frozen-lockfile
bash tools/fetch-tools.sh
pnpm exec playwright install chromium-headless-shell
