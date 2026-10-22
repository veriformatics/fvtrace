#!/usr/bin/env bash
# Replay verifier of the self-trace's proof facts (`fvtrace verify --run`): rebuilds the library
# first (fvtrace-trust loads Fvtrace's .olean files at run time, so a stale build would print the
# old statement), then prints the claims' statement fingerprints. Build output goes to stderr.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
lake build Fvtrace «fvtrace-trust» >&2
exec lake env "$PWD/.lake/build/bin/fvtrace-trust" --statement "$@"
