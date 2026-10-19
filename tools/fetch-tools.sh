#!/usr/bin/env bash
# Installs the scanner binaries pinned in tools/tools.lock into .tools/bin/, verifying each
# archive's sha256 before extracting it. Idempotent: a binary whose stamp matches its pinned
# version + digest is kept. Usage: tools/fetch-tools.sh [name...] (default: every pinned tool).
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
bin="$root/.tools/bin"
cache="$root/.tools/cache"
mkdir -p "$bin" "$cache"

case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) platform=linux-x86_64 ;;
    Linux-aarch64 | Linux-arm64) platform=linux-aarch64 ;;
    Darwin-x86_64) platform=darwin-x86_64 ;;
    Darwin-arm64) platform=darwin-aarch64 ;;
    *)
        printf 'fetch-tools: unsupported platform %s-%s\n' "$(uname -s)" "$(uname -m)" >&2
        exit 2
        ;;
esac

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

wanted=("$@")
found=0
while read -r name version plat digest url; do
    [[ -z "$name" || "$name" == \#* || "$plat" != "$platform" ]] && continue
    if [[ ${#wanted[@]} -gt 0 && ! " ${wanted[*]} " =~ \ $name\  ]]; then
        continue
    fi
    found=$((found + 1))
    stamp="$bin/.$name.stamp"
    if [[ -x "$bin/$name" && -f "$stamp" && "$(cat "$stamp")" == "$version $digest" ]]; then
        continue
    fi
    archive="$cache/$(basename "$url")"
    if [[ ! -f "$archive" || "$(sha256 "$archive")" != "$digest" ]]; then
        curl -fsSL --retry 3 -o "$archive.part" "$url"
        mv "$archive.part" "$archive"
    fi
    got="$(sha256 "$archive")"
    if [[ "$got" != "$digest" ]]; then
        printf 'fetch-tools: %s sha256 mismatch: got %s, pinned %s\n' "$name" "$got" "$digest" >&2
        rm -f "$archive"
        exit 1
    fi
    work="$(mktemp -d)"
    tar -xzf "$archive" -C "$work"
    member="$(find "$work" -type f -name "$name" | head -n 1)"
    if [[ -z "$member" ]]; then
        printf 'fetch-tools: %s archive holds no %s binary\n' "$name" "$name" >&2
        rm -rf "$work"
        exit 1
    fi
    install -m 0755 "$member" "$bin/$name"
    rm -rf "$work"
    printf '%s %s\n' "$version" "$digest" >"$stamp"
    printf 'fetch-tools: %s %s installed\n' "$name" "$version"
done <"$root/tools/tools.lock"

if [[ $found -eq 0 ]]; then
    printf 'fetch-tools: no pinned tool matches %s %s\n' "$platform" "${wanted[*]:-}" >&2
    exit 1
fi
