#!/usr/bin/env bash
# Release archives (.github/workflows/build.yml + release.yml).
#   package TARGET: the built binary + README, LICENSE, NOTICES.md and the third-party license
#     texts → $DIST/fvtrace-VERSION-TARGET.tar.gz (windows-*: .zip) + a sha256sum-format .sha256
#     beside it, then `check` on it.
#   check DIR TARGET VERSION: what a downloaded archive must pass on its own platform: its digest,
#     its files, no library beyond the platform's own (Linux: glibc ≤ $glibc_max; macOS: system
#     dylibs, minimum macOS ≤ $macos_min; Windows: DLLs that ship with Windows), `fvtrace --version`
#     = VERSION, `fvtrace check --strict` on the synthetic study.
# VERSION = Fvtrace/Version.lean's; DIST defaults to dist/. Floors = the measured release builds.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root"

glibc_max=2.17
macos_min=14.0
licenses=(lean lean-toolchain libuv hacl-star mimalloc emscripten musl)

die() {
    printf 'release: %s\n' "$*" >&2
    exit 1
}

sha256() {
    if command -v sha256sum >/dev/null; then sha256sum -- "$1"; else shasum -a 256 -- "$1"; fi |
        cut -d' ' -f1
}

# `a` ≤ `b` for dotted versions.
version_le() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]; }

archive_of() { if [[ "$1" == windows-* ]]; then printf 'fvtrace-%s-%s.zip' "$2" "$1"; else printf 'fvtrace-%s-%s.tar.gz' "$2" "$1"; fi; }

package() {
    local target="$1" dist="${DIST:-dist}" version name stage exe=fvtrace prefix archive
    local emsdk=()
    version="$(sed -n 's/^def version : String := "\(.*\)"$/\1/p' Fvtrace/Version.lean)"
    [[ -n "$version" ]] || die "no version in Fvtrace/Version.lean"
    [[ "$target" == windows-* ]] && exe=fvtrace.exe
    name="fvtrace-$version-$target"
    stage="$dist/$name"
    rm -rf "$stage" && mkdir -p "$stage/licenses"
    cp ".lake/build/bin/$exe" LICENSE README.md "$stage/"
    sed "s/@VERSION@/$version/" tools/release/NOTICES.md >"$stage/NOTICES.md"
    prefix="$(lean --print-prefix)"
    cp "$prefix/LICENSE" "$stage/licenses/lean.txt"
    cp "$prefix/LICENSES" "$stage/licenses/lean-toolchain.txt"
    cp c/hacl/LICENSE "$stage/licenses/hacl-star.txt"
    cp tools/release/libuv.txt "$stage/licenses/libuv.txt"
    # The Emscripten that built the embedded page engine (one per platform in the build folder).
    emsdk=(.lake/build/wasm/emsdk-*/install/emscripten)
    [[ ${#emsdk[@]} -eq 1 && -d "${emsdk[0]}" ]] || die "expected one Emscripten in .lake/build/wasm, found: ${emsdk[*]}"
    cp "${emsdk[0]}/LICENSE" "$stage/licenses/emscripten.txt"
    cp "${emsdk[0]}/system/lib/libc/musl/COPYRIGHT" "$stage/licenses/musl.txt"
    cp "${emsdk[0]}/system/lib/mimalloc/LICENSE" "$stage/licenses/mimalloc.txt"
    # The builder's umask would reach the user's extracted files.
    chmod -R u=rwX,go=rX "$stage"
    archive="$(archive_of "$target" "$version")"
    rm -f "$dist/$archive"
    # COPYFILE_DISABLE: macOS tar would add AppleDouble `._*` entries for extended attributes.
    if [[ "$archive" == *.zip ]]; then
        (cd "$dist" && python -m zipfile -c "$archive" "$name")
    else
        (cd "$dist" && COPYFILE_DISABLE=1 tar -czf "$archive" "$name")
    fi
    rm -rf "$stage"
    printf '%s  %s\n' "$(sha256 "$dist/$archive")" "$archive" >"$dist/$archive.sha256"
    printf 'release: %s/%s\n' "$dist" "$archive"
    check "$dist" "$target" "$version"
}

# Linux: every needed library = glibc's own; the newest glibc symbol version ≤ the floor.
floor_linux() {
    local bin="$1" lib newest
    while read -r lib; do
        case "$lib" in
        libc.so.6 | libm.so.6 | libpthread.so.0 | libdl.so.2 | librt.so.1 | ld-linux-*.so.*) ;;
        *) die "fvtrace needs $lib, which is not part of glibc" ;;
        esac
    done < <(objdump -p "$bin" | sed -n 's/^ *NEEDED *//p')
    newest="$(objdump -T "$bin" | grep -o 'GLIBC_[0-9.]*' | sed 's/GLIBC_//' | sort -Vu | tail -1)"
    version_le "$newest" "$glibc_max" || die "fvtrace needs GLIBC_$newest, newer than the floor $glibc_max"
    printf 'release: glibc ≤ %s (floor %s)\n' "$newest" "$glibc_max"
}

# macOS: dylibs from the system alone; the minimum macOS ≤ the floor.
floor_macos() {
    local bin="$1" lib minos
    while read -r lib; do
        case "$lib" in
        /usr/lib/* | /System/Library/*) ;;
        *) die "fvtrace needs $lib, which is not part of macOS" ;;
        esac
    done < <(otool -L "$bin" | tail -n +2 | awk '{ print $1 }')
    minos="$(otool -l "$bin" | awk '/LC_BUILD_VERSION/ { b = 1 } b && $1 == "minos" { print $2; exit }')"
    [[ -n "$minos" ]] || die "fvtrace names no minimum macOS (LC_BUILD_VERSION)"
    version_le "$minos" "$macos_min" || die "fvtrace needs macOS $minos, newer than the floor $macos_min"
    printf 'release: macOS ≥ %s (floor %s)\n' "$minos" "$macos_min"
}

# Windows: every DLL ships with Windows (an API set, or a file in System32). A runner has MinGW on
# PATH, so a run alone would not show a missing libwinpthread or libgcc.
floor_windows() {
    local bin="$1" dll
    while read -r dll; do
        dll="$(printf '%s' "$dll" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
        case "$dll" in
        api-ms-win-* | ext-ms-*) ;;
        *) [[ -f "/c/Windows/System32/$dll" ]] || die "fvtrace needs $dll, which does not ship with Windows" ;;
        esac
    done < <(objdump -p "$bin" | sed -n 's/^[[:space:]]*DLL Name: //p')
    printf 'release: system DLLs alone: %s\n' "$(objdump -p "$bin" | sed -n 's/^[[:space:]]*DLL Name: //p' | tr -d '\r' | paste -sd' ' -)"
}

check() {
    local dir="$1" target="$2" version="$3" archive name want file tmp out home f
    local run=()
    archive="$(archive_of "$target" "$version")"
    name="${archive%.zip}"
    name="${name%.tar.gz}"
    [[ -f "$dir/$archive" ]] || die "no $archive in $dir"
    [[ -f "$dir/$archive.sha256" ]] || die "no $archive.sha256 in $dir"
    read -r want file <"$dir/$archive.sha256"
    [[ "$file" == "$archive" ]] || die "$archive.sha256 names $file"
    [[ "$(sha256 "$dir/$archive")" == "$want" ]] || die "$archive: sha256 differs from $archive.sha256"
    tmp="$(mktemp -d)"
    # shellcheck disable=SC2064 # the path is fixed now
    trap "rm -rf '$tmp'" EXIT
    if [[ "$archive" == *.zip ]]; then
        python -m zipfile -e "$dir/$archive" "$tmp"
    else
        tar -xzf "$dir/$archive" -C "$tmp"
    fi
    local bin="$tmp/$name/fvtrace"
    for f in LICENSE README.md NOTICES.md "${licenses[@]/#/licenses/}"; do
        [[ "$f" == licenses/* ]] && f="$f.txt"
        [[ -s "$tmp/$name/$f" ]] || die "$archive lacks $f"
    done
    case "$target" in
    linux-*) floor_linux "$bin" ;;
    macos-*) floor_macos "$bin" ;;
    windows-*)
        bin="$bin.exe"
        floor_windows "$bin"
        # Windows' own folders alone: a DLL found through MinGW's would hide a missing one.
        run=(env PATH="/c/Windows/System32:/c/Windows")
        ;;
    *) die "unknown target $target" ;;
    esac
    [[ -x "$bin" ]] || die "$archive: fvtrace is not executable"
    out="$(${run[@]+"${run[@]}"} "$bin" --version | tr -d '\r')"
    [[ "$out" == "fvtrace $version" ]] || die "fvtrace --version printed \"$out\", not \"fvtrace $version\""
    home="$tmp/home"
    command -v cygpath >/dev/null && home="$(cygpath -w "$home")"
    (cd examples/synthetic/project &&
        FVTRACE_HOME="$home" ${run[@]+"${run[@]}"} "$bin" check --strict --trace ../trace.json) ||
        die "fvtrace check --strict failed on examples/synthetic"
    printf 'release: %s passed\n' "$archive"
}

if [[ "${1:-}" == package && $# -eq 2 ]]; then
    package "$2"
elif [[ "${1:-}" == check && $# -eq 4 ]]; then
    check "$2" "$3" "$4"
else
    die "usage: tools/release.sh package TARGET | check DIR TARGET VERSION"
fi
