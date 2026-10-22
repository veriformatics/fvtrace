#!/usr/bin/env bash
# Re-pins tools/wasm.lock (the exported page's engine build). Usage:
#   tools/pin-wasm.sh emsdk VERSION   every platform archive of Emscripten VERSION: URL + sha256
#   tools/pin-wasm.sh lean VERSION    the Lean runtime sources at tag vVERSION + the libuv tag that
#                                     Lean's CMake builds for Emscripten: commit + manifest sha256
# A Renovate PR bumps the emsdk linux-x86_64 or lean-runtime version alone; this rewrites the lines.
# The manifest = `sha256sum` of every fetched file, sorted by path (FvtraceWasm.Lock.manifest).
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
lock="$root/tools/wasm.lock"
what="${1:?usage: pin-wasm.sh emsdk|lean VERSION}"
version="${2:?usage: pin-wasm.sh emsdk|lean VERSION}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if command -v sha256sum >/dev/null 2>&1; then sha256=(sha256sum); else sha256=(shasum -a 256); fi

# Commit of a tag (peeled when annotated).
commit_of() {
    git ls-remote "$1" "refs/tags/$2" "refs/tags/$2^{}" | awk '{ c = $1 } END { print c }'
}

# Sparse checkout of paths at a commit (byte-exact: no line-ending conversion), then the sha256 of
# its manifest. Args: url commit dir path...
manifest() {
    local url="$1" commit="$2" dir="$3"
    shift 3
    git -c core.autocrlf=false init -q "$dir"
    git -C "$dir" -c core.autocrlf=false fetch -q --depth 1 --filter=blob:none "$url" "$commit"
    git -C "$dir" sparse-checkout set --no-cone "${@/#//}"
    git -C "$dir" -c core.autocrlf=false -c advice.detachedHead=false checkout -q FETCH_HEAD
    (cd "$dir" && find "${@%/}" -type f | LC_ALL=C sort | xargs -r "${sha256[@]}" | "${sha256[@]}" |
        cut -d' ' -f1)
}

# Replaces every `name ` line of the lock, keeping the header + the other lines.
rewrite() {
    local name="$1" lines="$2"
    {
        grep -v -E "^$name " "$lock"
        printf '%s\n' "$lines"
    } | awk '/^#/ { print; next } { print | "sort -k1,1 -k3,3" }' >"$lock.new"
    mv "$lock.new" "$lock"
    printf 'pin-wasm: %s pinned to %s\n' "$name" "$version"
}

case "$what" in
emsdk)
    rev="$(curl -fsSL "https://raw.githubusercontent.com/emscripten-core/emsdk/$version/emscripten-releases-tags.json" |
        jq -r --arg v "$version" '.releases[$v] // empty')"
    if [[ -z "$rev" ]]; then
        printf 'pin-wasm: emsdk %s names no release revision\n' "$version" >&2
        exit 1
    fi
    base="https://storage.googleapis.com/webassembly/emscripten-releases-builds"
    lines=""
    while read -r platform path; do
        url="$base/$path"
        curl -fsSL --retry 3 -o "$work/archive" "$url"
        digest="$("${sha256[@]}" "$work/archive" | cut -d' ' -f1)"
        lines+="emsdk $version $platform $digest $url"$'\n'
    done <<EOF
darwin-aarch64 mac/$rev/wasm-binaries-arm64.tar.xz
darwin-x86_64 mac/$rev/wasm-binaries.tar.xz
linux-aarch64 linux/$rev/wasm-binaries-arm64.tar.xz
linux-x86_64 linux/$rev/wasm-binaries.tar.xz
windows-x86_64 win/$rev/wasm-binaries.zip
EOF
    rewrite emsdk "${lines%$'\n'}"
    ;;
lean)
    url=https://github.com/leanprover/lean4
    commit="$(commit_of "$url" "v$version")"
    digest="$(manifest "$url" "$commit" "$work/lean" src/runtime/ src/include/ src/util/ \
        src/CMakeLists.txt)"
    rewrite lean-runtime "lean-runtime $version $commit $digest $url"
    tag="$(awk '/GIT_REPOSITORY https:\/\/github.com\/libuv\/libuv/ { getline; while ($1 != "GIT_TAG") getline; print $2; exit }' \
        "$work/lean/src/CMakeLists.txt")"
    uv=https://github.com/libuv/libuv
    uvcommit="$(commit_of "$uv" "$tag")"
    uvdigest="$(manifest "$uv" "$uvcommit" "$work/libuv" include/)"
    version="${tag#v}"
    rewrite libuv "libuv ${tag#v} $uvcommit $uvdigest $uv"
    ;;
*)
    printf 'usage: pin-wasm.sh emsdk|lean VERSION\n' >&2
    exit 2
    ;;
esac
