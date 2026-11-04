# shellcheck shell=bash
# Source-only: `sha256 FILE` prints FILE's SHA-256; `sha256_cmd` = the command itself (GNU
# `sha256sum`, else macOS's `shasum -a 256`), for manifests that keep each file's name.
if command -v sha256sum >/dev/null 2>&1; then sha256_cmd=(sha256sum); else sha256_cmd=(shasum -a 256); fi
sha256() { "${sha256_cmd[@]}" -- "$1" | cut -d' ' -f1; }
