#!/usr/bin/env bash
# Vendors HACL*'s formally verified SHA-256 (C extracted from F*; the code CPython's hashlib ships)
# into c/hacl/ from upstream hacl-star at the pinned revision below, verifying every file's sha256.
# Files are copied verbatim (never edit them; fix forward by moving the pin). Usage:
# tools/vendor-hacl.sh [--check | --verify] — --check re-downloads + compares, writing nothing;
# --verify hashes the vendored files against the pins, offline.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
dest="$root/c/hacl"
# CPython main's Modules/_hacl/refresh.sh pins the same revision (3.14 + 3.15 pin 8ba599b2, whose
# copies of every file below are byte-identical).
rev=504c2987452f87fe44bce9b9f12e19d6e051761f
base="https://raw.githubusercontent.com/hacl-star/hacl-star/$rev"

# sha256 · local path · upstream path
files="
6cd390cc86d9054e3d577f75e1e4d1559a545ec22e4643179aa087c8bd612e4e Hacl_Hash_SHA2.c dist/gcc-compatible/Hacl_Hash_SHA2.c
616685799d2d029411ec8fe5c15aaedd481ecd75edf29161b12cf3d9f20b7d4c Hacl_Hash_SHA2.h dist/gcc-compatible/Hacl_Hash_SHA2.h
5bc854fe08765681fa241b51460e7a0107fc3ebc4f8db21435656c515e5937d5 Hacl_Krmllib.h dist/gcc-compatible/Hacl_Krmllib.h
efc7bd11460744768425aedf4e004d3ad3397a5489752b80044ae785f30b78d4 Hacl_Streaming_Types.h dist/gcc-compatible/Hacl_Streaming_Types.h
709c6272f77e2368f6cc0bf36527e3b16dd5d5f3dc26a2afdef8238200af8770 internal/Hacl_Hash_SHA2.h dist/gcc-compatible/internal/Hacl_Hash_SHA2.h
d0f85cc010234fddd2e9c5c60be458b5498e5b754bc1902328005a958a99b357 internal/Hacl_Krmllib.h dist/gcc-compatible/internal/Hacl_Krmllib.h
76997c7069a347ac78b65d26354a0324d54add4ca7a02e7be36d6d5e1c9702e0 internal/Hacl_Streaming_Types.h dist/gcc-compatible/internal/Hacl_Streaming_Types.h
6d1a350ec272c83761f1789611d8f60947a4d69fed3d23d8eee38709a0ad2c0a include/krml/lowstar_endianness.h dist/karamel/include/krml/lowstar_endianness.h
c5a04a1f99807cea29ac1832ba17d8a3d3805862d3a713642583be2106e04edb include/krml/internal/compat.h dist/karamel/include/krml/internal/compat.h
08bb43ef5626a8450f985da0af345b6658ac8bcc4585f77271decd0e41fc02e0 include/krml/internal/target.h dist/karamel/include/krml/internal/target.h
ea6fc7766230993ddea9b2e9b537323a337eb1752eb80fc74303ebb5b03e897e include/krml/internal/types.h dist/karamel/include/krml/internal/types.h
f01e3f0892935f3f659019875f580445b9ea23482afbe11ffbe7cdbd22dbd4d2 include/FStar_UInt_8_16_32_64.h dist/karamel/krmllib/dist/minimal/FStar_UInt_8_16_32_64.h
1c9bee7ac4b987c73cc3aba6b7ceed8ec7e75c9a741810e4411f35602490e0d8 include/fstar_uint128_struct_endianness.h dist/karamel/krmllib/dist/minimal/fstar_uint128_struct_endianness.h
69dc2e78411e9b271100eb0d2a2d8dc39dd2348afc26f8b4cfba14c025102c7f include/FStar_UInt128_Verified.h dist/karamel/krmllib/dist/minimal/FStar_UInt128_Verified.h
c21cfe74bcbab804fc7a1e112e070ae7e70a0446106b7c77d651a517ee19631e include/LowStar_Endianness.h dist/karamel/krmllib/dist/minimal/LowStar_Endianness.h
c5accbbd8546e94c34aed24afe689a617627d18eed5a6c48277e48db57c23851 LICENSE LICENSE
"

# --verify: offline, every vendored file still hashes to its pin (the gate's `vendor` stage).
if [[ "${1:-}" == "--verify" ]]; then
    rc=0
    while read -r digest local _; do
        [[ -z "$digest" ]] && continue
        got="$(sha256sum "$dest/$local" 2>/dev/null | cut -c1-64)"
        if [[ "$got" != "$digest" ]]; then
            printf 'vendor-hacl: c/hacl/%s does not match its pinned sha256\n' "$local" >&2
            rc=1
        fi
    done <<<"$files"
    extra="$(cd "$dest" && find . -type f | sed 's|^\./||' | sort | comm -23 - <(awk 'NF {print $2}' <<<"$files" | sort))"
    if [[ -n "$extra" ]]; then
        printf 'vendor-hacl: unpinned file in c/hacl: %s\n' "$extra" >&2
        rc=1
    fi
    exit $rc
fi

check=false
[[ "${1:-}" == "--check" ]] && check=true
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
rc=0
while read -r digest local upstream; do
    [[ -z "$digest" ]] && continue
    mkdir -p "$(dirname "$work/$local")"
    curl -fsSL --retry 3 -o "$work/$local" "$base/$upstream"
    got="$(sha256sum "$work/$local" | cut -c1-64)"
    if [[ "$got" != "$digest" ]]; then
        printf 'vendor-hacl: %s sha256 %s, pinned %s\n' "$local" "$got" "$digest" >&2
        rc=1
    elif $check && ! cmp -s "$work/$local" "$dest/$local"; then
        printf 'vendor-hacl: c/hacl/%s differs from upstream %s\n' "$local" "$rev" >&2
        rc=1
    fi
done <<<"$files"
[[ $rc -eq 0 ]] || exit $rc
if ! $check; then
    rm -rf "$dest"
    mkdir -p "$dest"
    cp -R "$work/." "$dest/"
    printf 'vendor-hacl: c/hacl/ = hacl-star %s\n' "$rev"
fi
