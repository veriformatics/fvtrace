#!/usr/bin/env bash
# Coverage-guided fuzz campaigns (.claude/rules/testing.md). Builds one libFuzzer binary per target
# of FvtraceFuzz.lean from Lake's C for its import closure + the C shims, compiled by the system
# clang with AddressSanitizer + UndefinedBehaviorSanitizer, linked as `leanc` links (Lean's static
# runtime, Init, Std, libc++, GMP, libuv). Usage:
#   tools/fuzz.sh targets                          the target names
#   tools/fuzz.sh build [TARGET...]                → .lake/build/fuzz/bin/<target>
#   tools/fuzz.sh run TARGET SECONDS [ARG...]      a time-boxed campaign from tests/fuzz/<target>;
#                                                  rc 0 = nothing found, else the crash input sits in
#                                                  .lake/build/fuzz/crashes/<target>/
# The gate replays tests/fuzz with `fvtrace-fuzz replay` (no libFuzzer); a crash input found here
# joins tests/fuzz/<target>/ once its cause is fixed.
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root"
targets=(json decode request page digest)
out="$root/.lake/build/fuzz"
cc="${FUZZ_CC:-clang}"
cxx="${FUZZ_CXX:-clang++}"

usage() {
    printf 'usage: tools/fuzz.sh targets | build [TARGET...] | run TARGET SECONDS [ARG...]\n' >&2
    exit 2
}

known() {
    local t
    for t in "${targets[@]}"; do [[ $t == "$1" ]] && return 0; done
    printf 'tools/fuzz.sh: no target %s (targets: %s)\n' "$1" "${targets[*]}" >&2
    exit 2
}

# FvtraceFuzz + every project module it imports, transitively (Init + Std come from Lean's libs).
closure() {
    local -A seen=()
    local queue=(FvtraceFuzz) m file dep
    while ((${#queue[@]})); do
        m="${queue[0]}"
        queue=("${queue[@]:1}")
        [[ -n ${seen[$m]:-} ]] && continue
        file="${m//.//}.lean"
        [[ -f $file ]] || continue
        seen[$m]=1
        printf '%s\n' "$m"
        while read -r _ dep; do queue+=("$dep"); done < <(grep -E '^import [A-Za-z]' "$file")
    done
}

# One object per source, rebuilt when the source or the flags changed.
compile() {
    local src="$1" obj="$2" stamp
    shift 2
    stamp="$(printf '%s\n' "$*" | sha256sum | cut -c1-16)"
    if [[ ! -f $obj || $src -nt $obj || "$(cat "$obj.flags" 2>/dev/null)" != "$stamp" ]]; then
        mkdir -p "$(dirname "$obj")"
        "$cc" "$@" -c "$src" -o "$obj"
        printf '%s\n' "$stamp" >"$obj.flags"
    fi
}

build() {
    local prefix modules m obj objs=() t defs flags san hacl
    prefix="$(lean --print-prefix)"
    lake build «fvtrace-fuzz» >/dev/null
    san=('-fsanitize=address,undefined' -fno-sanitize-recover=undefined)
    flags=(-g -O1 -fno-omit-frame-pointer -I"$prefix/include" "${san[@]}" -fsanitize=fuzzer-no-link)
    mapfile -t modules < <(closure)
    for m in "${modules[@]}"; do
        obj="$out/obj/${m//.//}.o"
        compile ".lake/build/ir/${m//.//}.c" "$obj" "${flags[@]}" -w
        objs+=("$obj")
    done
    hacl=(-Ic/hacl -Ic/hacl/include -DKRML_VERIFIED_UINT128)
    compile c/hacl/Hacl_Hash_SHA2.c "$out/obj/c/hacl.o" "${flags[@]}" "${hacl[@]}"
    compile c/fvtrace_digest.c "$out/obj/c/digest.o" "${flags[@]}" "${hacl[@]}" -Wall -Wextra -Werror
    objs+=("$out/obj/c/hacl.o" "$out/obj/c/digest.o")
    # libuv's own uv_strerror links natively; the bridge's stand-in exists for WebAssembly alone.
    compile c/page_engine.c "$out/obj/c/page_engine.o" "${flags[@]}" -Duv_strerror=fvtrace_page_uv_strerror \
        -Wall -Wextra -Werror
    mkdir -p "$out/bin"
    for t in "$@"; do
        if [[ $t == page ]]; then defs=(-DFVTRACE_FUZZ_PAGE); else defs=(-DFVTRACE_FUZZ_TARGET="$t"); fi
        compile tools/fuzz/driver.c "$out/obj/driver-$t.o" "${flags[@]}" "${defs[@]}" -Wall -Wextra -Werror
        local extra=()
        [[ $t == page ]] && extra=("$out/obj/c/page_engine.o")
        "$cxx" -fsanitize=fuzzer "${san[@]}" -o "$out/bin/$t" "$out/obj/driver-$t.o" "${objs[@]}" "${extra[@]}" \
            -L"$prefix/lib" -L"$prefix/lib/lean" -lStd -Wl,--start-group -lInit -lleanrt -Wl,--end-group \
            -Wl,-Bstatic -lc++ -lc++abi -Wl,-Bdynamic -lgmp -luv -pthread -ldl -lrt -lm
        printf 'fuzz: built %s\n' "${out#"$root/"}/bin/$t"
    done
}

case "${1:-}" in
targets) printf '%s\n' "${targets[@]}" ;;
build)
    shift
    (($#)) || set -- "${targets[@]}"
    for t in "$@"; do known "$t"; done
    build "$@"
    ;;
run)
    [[ $# -ge 3 && $3 =~ ^[0-9]+$ ]] || usage
    t="$2" seconds="$3"
    shift 3
    known "$t"
    build "$t"
    mkdir -p "$out/corpus/$t" "$out/crashes/$t"
    dict=()
    [[ $t == json || $t == decode ]] && dict=(-dict=tests/fuzz/json.dict)
    # Lean keeps some objects for the process lifetime (GMP limbs among them): leaks are no finding.
    ASAN_OPTIONS="detect_leaks=0:abort_on_error=1:${ASAN_OPTIONS:-}" \
        UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1:${UBSAN_OPTIONS:-}" \
        "$out/bin/$t" -max_total_time="$seconds" -timeout=10 -rss_limit_mb=4096 -print_final_stats=1 \
        -artifact_prefix="$out/crashes/$t/" "${dict[@]}" "$@" "$out/corpus/$t" "tests/fuzz/$t"
    ;;
*) usage ;;
esac
