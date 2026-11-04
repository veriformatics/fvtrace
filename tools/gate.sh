#!/usr/bin/env bash
# The one gate command: a human, an agent and CI run exactly this, so one result is one claim.
# Stages run to completion after a failure (no `set -e`), so one run reports every problem; each
# prints `<stage> rc=N <s>s`, the run closes on `gate rc=N <s>s`.
# Usage: tools/gate.sh [--shard NAME] — no argument = every stage; a shard = its stages alone
# (CI runs one job per shard, see STAGES).
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 1
export PATH="$root/.tools/bin:$root/node_modules/.bin:$PATH"

failed=()

stamp() { printf '%s' "${EPOCHREALTIME//[!0-9]/}"; }
elapsed() {
    local us=$(($(stamp) - $1))
    printf '%d.%d' $((us / 1000000)) $((us / 100000 % 10))
}

# Step ledger: the record of which stages catch defects for their wall-clock. One TSV row per
# stage per run + the run's total: date · tree (the working tree's content; = `HEAD^{tree}` when
# clean) · run (`gate[:<shard>]` | `fast` | `ci:<run id>`) · step · seconds · verdict (`green` |
# `red`); tools/gate-ledger.sh lists + classifies reds. GATE_LEDGER = another file, empty = none.
ledger="${GATE_LEDGER-$root/.gate/ledger.tsv}"
ledger_run=""

# Stages run before a run begins (probes) write no rows.
ledger_begin() {
    local idx
    ledger_run="$1"
    ledger_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    idx="$(mktemp)"
    # A copy of the index keeps its stat cache, so only changed files are hashed (≈ 0.05 s).
    ledger_tree="$({ cp -- "$(git rev-parse --git-path index)" "$idx" &&
        GIT_INDEX_FILE="$idx" git add -A && GIT_INDEX_FILE="$idx" git write-tree; } 2>/dev/null)" ||
        ledger_tree=-
    rm -f -- "$idx"
}

# ledger_add <step> <seconds> <rc>: a row that cannot be written is reported, never a verdict.
ledger_add() {
    [[ -n "$ledger_run" && -n "$ledger" ]] || return 0
    local verdict=green
    [[ $3 -eq 0 ]] || verdict=red
    { mkdir -p -- "$(dirname -- "$ledger")" &&
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$ledger_date" "$ledger_tree" "$ledger_run" "$1" "$2" \
            "$verdict" >>"$ledger"; } 2>/dev/null ||
        printf 'ledger: cannot append to %s\n' "$ledger" >&2
}

stage() {
    local name="$1" start rc secs
    shift
    start="$(stamp)"
    printf '\n=== %s ===\n' "$name"
    "$@"
    rc=$?
    secs="$(elapsed "$start")"
    printf '%s rc=%d %ss\n' "$name" "$rc" "$secs"
    ledger_add "$name" "$secs" "$rc"
    [[ $rc -eq 0 ]] || failed+=("$name")
    return 0
}

# Stage · CI shards. A full run takes every stage in this order, each running the function of its
# name (`-` → `_`). CI runs one job per shard (gate.yml matrix), each on a fresh checkout, so a
# shard whose stages read the build lists lean-build too; `fanout` holds the matrix = these shards.
STAGES='
tools       checks
lean-style  checks
lean-build  lean e2e
lean-test   lean
lean-pure   lean
cli         lean
examples    lean
engine      lean
trust       lean
c-analyze   checks
vendor      checks
js-format   checks
js-lint     checks
js-types    checks
js-test     checks
e2e         e2e
audit       checks
secrets     checks
workflows   checks
fanout      checks
spec        checks
filler      checks
shell       checks
meta        checks
'

# Read-only checks that need neither the build nor the fetched tools: they run side by side (the full
# gate + the fast gate), each log printed whole, in this order, with its own wall-clock.
TOGETHER='lean-style js-format js-lint js-types js-test fanout spec filler shell meta'
together_log=""
together_pids=()
together_names=()
# Starts the named stages in the background (their rows + verdicts come from `together_finish`).
together_start() {
    local i
    together_log="$(mktemp -d)"
    together_names=("$@")
    together_pids=()
    for i in "${!together_names[@]}"; do
        (
            t0="$(stamp)"
            "${together_names[$i]//-/_}" >"$together_log/$i" 2>&1
            rc=$?
            elapsed "$t0" >"$together_log/$i.time"
            exit $rc
        ) &
        together_pids+=($!)
    done
}
# Waits for them; prints each log + `<stage> rc=N <s>s`; one writer adds every ledger row (rows from
# parallel subshells could interleave).
together_finish() {
    local i rc secs
    for i in "${!together_names[@]}"; do
        wait "${together_pids[$i]}"
        rc=$?
        secs="$(cat "$together_log/$i.time")"
        printf '\n=== %s ===\n' "${together_names[$i]}"
        cat "$together_log/$i"
        printf '%s rc=%d %ss\n' "${together_names[$i]}" "$rc" "$secs"
        ledger_add "${together_names[$i]}" "$secs" "$rc"
        [[ $rc -eq 0 ]] || failed+=("${together_names[$i]}")
    done
    rm -rf "$together_log"
}

# Every stage STAGES names, in order.
stage_names() { awk 'NF { print $1 }' <<<"$STAGES"; }

# Every shard STAGES names, once each, in first-use order.
shard_names() { awk 'NF { for (i = 2; i <= NF; i++) if (!seen[$i]++) print $i }' <<<"$STAGES"; }

tools() { bash tools/fetch-tools.sh && tools_local; }

# Tools install project-local: each name tools/tools.lock pins resolves to .tools/bin first.
tools_local() {
    local rc=0 name found
    while read -r name; do
        found="$(command -v "$name" || true)"
        if [[ "$found" != "$root/.tools/bin/$name" ]]; then
            printf 'tools: %s resolves to "%s", not %s\n' "$name" "$found" "$root/.tools/bin/$name" >&2
            rc=1
        fi
    done < <(awk 'NF && $1 !~ /^#/ { print $1 }' tools/tools.lock | sort -u)
    return $rc
}

# Lean has no formatter in the 4.35 toolchain; this holds the mechanical layout rules.
lean_style() { bash tools/lean-style.sh; }

# Builds every target (library, shipped binary, tests, trust audit, the exported page's
# WebAssembly engine + its build tool); every proof is kernel-checked here, and `warningAsError`
# turns lints + deprecations into failures. The engine's first build per toolchain fetches
# Emscripten + generates Init's C (minutes); later builds reuse both and recompile what changed.
lean_build() { lake build Fvtrace fvtrace «fvtrace-tests» «fvtrace-trust» «fvtrace-wasm» FvtraceEngine; }

lean_test() { lake test; }

# The FFI-free suites interpreted, as the mutation tool runs them (an FFI call there aborts it).
lean_pure() { lake env lean --run TestPure.lean; }

cli() { bash tests/cli/smoke.sh; }

# fvTrace's own trace + the synthetic study: valid, every warning waived, every receipt current.
# A changed file that the self-trace pins (a proof, a spec) stales its receipt until re-pinned.
# README's self-trace paragraph states its verdict counts in words (examples.md); the engine's
# counts decide them, and the paragraph covers every claim.
readme_verdicts() {
    local counts="$1" rc=0 n verdict want stated=0 total
    local -A number=([One]=1 [Two]=2 [Three]=3 [Four]=4 [Five]=5 [Six]=6 [Seven]=7 [Eight]=8
        [Nine]=9 [Ten]=10 [Eleven]=11 [Twelve]=12)
    local -A state=(["Fully supported"]=can [Conditional]=conditional
        ["Pending verification"]=open ["Claim not possible"]=cannot)
    while IFS='|' read -r n verdict; do
        want="$(jq -r --arg k "${state[$verdict]}" '.[$k]' <<<"$counts")"
        if [[ "${number[$n]:-}" != "$want" ]]; then
            printf 'examples: README says %s claims read %s; the self-trace has %s\n' "$n" "$verdict" "$want" >&2
            rc=1
        fi
        stated=$((stated + want))
    done < <(awk '/applies fvTrace to itself/ { on = 1 } on && /^$/ { exit } on' README.md | tr '\n' ' ' |
        grep -oE '[A-Z][a-z]+ (of its )?claims read \*\*(Fully supported|Conditional|Pending verification|Claim not possible)\*\*' |
        sed -E 's/^([A-Za-z]+) .*\*\*(.*)\*\*$/\1|\2/')
    total="$(jq '[.[]] | add' <<<"$counts")"
    if [[ "$stated" != "$total" ]]; then
        printf 'examples: README states verdicts for %s of the self-trace'"'"'s %s claims\n' "$stated" "$total" >&2
        rc=1
    fi
    return $rc
}

examples() {
    local rc=0 home counts bin="$root/.lake/build/bin/fvtrace"
    home="$(mktemp -d)"
    FVTRACE_HOME="$home" "$bin" check --strict --trace examples/fvtrace/trace.json --project . ||
        rc=1
    counts="$(FVTRACE_HOME="$home" "$bin" claims --json --trace examples/fvtrace/trace.json --project . |
        jq -c .counts)" && readme_verdicts "$counts" || rc=1
    (cd examples/synthetic/project &&
        FVTRACE_HOME="$home" "$bin" check --strict --trace ../trace.json) || rc=1
    rm -rf "$home"
    return $rc
}

# The exported page's engine (WebAssembly, run by the page's loader) answers every differential
# case byte for byte as the native engine does (`kernel.md` E-wasm); Chromium = e2e engine.spec.js.
# `node --test` over folders, each holding ≥ 1 `*.test.mjs` (an emptied folder would run nothing
# and read green).
node_tests() {
    local d
    for d in "$@"; do
        compgen -G "$d*.test.mjs" >/dev/null || { printf 'no test file in %s\n' "$d" >&2; return 1; }
    done
    local out rc
    out="$(node --test "$@" 2>&1)"
    rc=$?
    printf '%s\n' "$out"
    # ops.md: a suite names its three slowest parts (top-level tests, by their reported time).
    sed -nE 's/^[✔✖] (.+) \(([0-9.]+)ms\)$/\2\t\1/p' <<<"$out" | sort -t$'\t' -k1,1 -rn | head -3 |
        awk -F'\t' '{ printf "%s%s %.0f ms", (NR > 1 ? ", " : "slowest: "), $2, $1 } END { if (NR) print "" }'
    return "$rc"
}

engine() { node_tests tests/engine/; }

# What the engine stage reads: the built engine + its loader + worker, its tests + their traces,
# the export + snapshot code that frames the page + answers natively, the toolchain. The fast gate
# skips the stage while this key equals its last pass's; the full gate always runs it.
engine_key() {
    cat .lake/build/wasm/engine.wasm web/engine.js web/worker.js tests/engine/*.mjs \
        examples/*/trace.json tests/fixtures/*.json Fvtrace/Export.lean Fvtrace/Snapshot.lean \
        Tests/Snapshot.lean TestMain.lean lean-toolchain 2>/dev/null | sha256sum | cut -d' ' -f1
}

# Claims ↔ proofs ↔ axioms ↔ escape hatches, then every proof's closure replayed through the
# independent kernels bundled with Lean (`lake check --paranoid`).
trust() { bash tools/trust.sh; }

prettier_files() {
    git ls-files -co --exclude-standard -- 'web/*' 'tests/e2e/*' 'tests/engine/*' 'tests/schema/*' 'tests/palette/*' 'tests/renovate/*' 'schema/*' \
        'tools/*.mjs' ':(top,glob)*.json' ':(top,glob)*.mjs' ':(top,glob).*.json' '.github/*' |
        grep -v -e '^lake-manifest.json$'
}

js_format() { prettier_files | xargs -r prettier --check; }

js_lint() {
    local rc=0
    oxlint --type-aware --deny-warnings web tests/e2e tests/engine tests/schema tests/palette tests/renovate tools ./*.mjs || rc=1
    stylelint 'web/**/*.css' || rc=1
    html-validate web || rc=1
    return $rc
}

js_types() {
    local rc=0 p
    for p in . web tests/e2e; do tsc -p "$p" || rc=1; done
    return $rc
}

# The FFI shim + the page engine's C bridge under clang's static analyzer, findings as errors
# (HACL* itself is verified upstream and compiled verbatim; `vendor` holds it byte-equal to the
# pinned release).
c_analyze() {
    local rc=0
    clang --analyze -Xclang -analyzer-werror -I"$(lean --print-prefix)/include" -Ic/hacl \
        -Ic/hacl/include -DKRML_VERIFIED_UINT128 c/fvtrace_digest.c -o /dev/null || rc=1
    clang --analyze -Xclang -analyzer-werror -I"$(lean --print-prefix)/include" \
        c/page_engine.c -o /dev/null || rc=1
    return $rc
}

vendor() { bash tools/vendor-hacl.sh --verify; }

# The JSON Schema agrees with the decoder on tests/schema/cases/ (Tests/Schema.lean = other half);
# the GUI palette meets contrast + color-vision floors (tests/palette/); Renovate's regex managers
# extract the dependencies of their files (tests/renovate/).
js_test() { node_tests tests/schema/ tests/palette/ tests/renovate/; }

e2e() { playwright test; }

# Advisories with no fixed release, ignored only while none exists (a fix turns `audit` red):
# GHSA-vfj7-8cjw-p6xm = braces stack exhaustion on nested brace patterns; reached only through
# stylelint's globbing of the gate's own literal pattern (`web/**/*.css`), dev tooling only.
DEV_RESIDUALS=(GHSA-vfj7-8cjw-p6xm)

# Decides `pnpm audit --json` output; split out so tools/gate-probe.sh can feed it a planted
# report. A missing `advisories` object (registry error) fails.
audit_policy() {
    local found
    found="$(jq -r --args '
        if (.advisories | type) != "object" then "no advisory report (registry error?)"
        else .advisories[]
            | if (.github_advisory_id | IN($ARGS.positional[])) then
                (if (.patched_versions // "<0.0.0") == "<0.0.0" then empty
                 else "\(.github_advisory_id) (\(.module_name)) now has a fix: \(.patched_versions)" end)
              else "\(.github_advisory_id) \(.severity) \(.module_name) \(.vulnerable_versions)" end
        end' "${DEV_RESIDUALS[@]}")" || {
        printf 'audit: unreadable advisory report\n' >&2
        return 1
    }
    if [[ -n "$found" ]]; then
        printf 'audit: %s\n' "$found" >&2
        return 1
    fi
    printf 'audit: no unaccepted advisories\n'
}

# Lean code carries no third-party package (asserted on the manifest); the JS dev tree is audited
# against the npm advisory database.
audit() {
    local rc=0
    if [[ "$(jq '.packages | length' lake-manifest.json)" != 0 ]]; then
        printf 'audit: lake-manifest.json lists Lake packages; audit them before adding\n' >&2
        rc=1
    fi
    { pnpm audit --json || true; } | audit_policy || rc=1
    return $rc
}

# History + every tracked or untracked-unignored file; live validation stays off (no network).
secrets() {
    local rc=0
    betterleaks git --no-banner --redact . || rc=1
    git ls-files -co --exclude-standard -z | xargs -0 -r betterleaks dir --no-banner --redact || rc=1
    return $rc
}

workflows() {
    local rc=0
    zizmor --no-progress .github/ || rc=1
    actionlint || rc=1
    return $rc
}

# CI runs the gate as one job per gate.yml matrix shard: a stage without a shard, or a shard the
# matrix lacks, would pass a local run and never run in CI.
fanout() {
    local rc=0 wf=.github/workflows/gate.yml matrix shards
    awk 'NF == 1 { print "fanout: stage " $1 " has no CI shard"; bad = 1 } END { exit bad }' \
        <<<"$STAGES" >&2 || rc=1
    matrix="$(sed -n 's/^ *shard: \[\(.*\)\]$/\1/p' "$wf" | tr -d ' ' | tr ',' '\n' | sort)"
    shards="$(shard_names | sort)"
    if [[ "$matrix" != "$shards" ]]; then
        printf 'fanout: %s matrix shards [%s] != tools/gate.sh shards [%s]\n' "$wf" \
            "$(paste -sd, - <<<"$matrix")" "$(paste -sd, - <<<"$shards")" >&2
        rc=1
    fi
    # Matched by YAML position, not parsed (no YAML parser in the toolchain): the `run:` key of a
    # step in job `gate` (job keys at 2 spaces, step keys at 8), the whole line. The same text in a
    # comment, behind `|| true`, or inside a block scalar (indented deeper than its key) runs no gate.
    # `$SHARD` here = the workflow's literal text, which the runner's shell expands.
    # shellcheck disable=SC2016
    if [[ "$(awk '
        /^[^ #]/ { top = $0 }
        top == "jobs:" && /^  [^ #]/ { job = $1 }
        job == "gate:" && /^        run: bash tools\/gate\.sh --shard "\$SHARD"$/ { n++ }
        END { print n + 0 }' "$wf")" != 1 ]]; then
        printf 'fanout: %s runs no single `bash tools/gate.sh --shard "$SHARD"` step\n' "$wf" >&2
        rc=1
    fi
    provision || rc=1
    return $rc
}

# Cross-workflow relations no workflow linter reads (ci.md, release.md, wasm.md CI cache),
# matched by text like fanout's step: the release targets (publish's archive list) = build.yml's
# matrix = installed's; installed runs macOS on the floor's runner; Python + the engine cache come
# before every Lean build; the cache key holds what changes every engine object. `${{ … }}` here =
# the workflows' literal expression text.
# shellcheck disable=SC2016
provision() {
    local rc=0 act=.github/actions/page-engine/action.yml b=.github/workflows/build.yml
    local g=.github/workflows/gate.yml r=.github/workflows/release.yml
    local published list macos os skip f
    local -a bad=()
    published="$(sed -n 's/^ *for a in \(.*\); do$/\1/p' "$r" | tr ' ' '\n' | sed -E 's/\.(tar\.gz|zip)$//' | sort)"
    [[ "$(wc -w <<<"$published")" -eq 4 ]] || bad+=("$r publish names $(wc -w <<<"$published") archives, not 4")
    for f in "$b" "$r"; do
        list="$(sed -n 's/^ *target: \(.*\)$/\1/p' "$f" | sort)"
        [[ "$list" == "$published" ]] ||
            bad+=("$f targets [$(paste -sd, - <<<"$list")] != release targets [$(paste -sd, - <<<"$published")]")
    done
    macos="$(sed -n 's/^macos_min=//p' tools/release.sh)"
    os="$(awk '/^ *- os: / { os = $3 } /^ *target: macos-arm64$/ { print os }' "$r")"
    [[ "$os" == "macos-${macos%.0}" ]] ||
        bad+=("$r runs macos-arm64 on $os, not macos-${macos%.0} (tools/release.sh macos_min)")
    grep -qF "MACOSX_DEPLOYMENT_TARGET=\$(sed -n 's/^macos_min=//p' tools/release.sh)" "$b" ||
        bad+=("$b sets MACOSX_DEPLOYMENT_TARGET from no tools/release.sh macos_min")
    grep -qE '^ +uses: actions/setup-python@[0-9a-f]{40} ' "$act" || bad+=("$act installs no Python")
    grep -qE '^ +python-version: "3\.(1[0-9]|[2-9][0-9])' "$act" || bad+=("$act names no Python >= 3.10")
    f="$(awk '/^ *key: / { print }' "$act")"
    [[ "$f" == *'key: engine-${{ runner.os }}-${{ runner.arch }}-${{ hashFiles('* ]] ||
        bad+=("$act engine cache key lacks OS + arch")
    for list in lean-toolchain tools/wasm.lock 'tools/wasm/**' 'FvtraceWasm/**' WasmMain.lean; do
        [[ "$f" == *"'$list'"* ]] || bad+=("$act engine cache key lacks $list")
    done
    grep -qxF '          .lake/build/wasm/*' "$act" && grep -qxF '          !.lake/build/wasm/download' "$act" ||
        bad+=("$act caches other than .lake/build/wasm/* minus download/")
    for f in "$b:lake build" "$g:bash tools/gate.sh --shard"; do
        awk -v run="${f#*:}" '/uses: \$\/\.github\/actions\/page-engine$/ { p = NR } index($0, "run: " run) && !l { l = NR }
            END { exit !(p && l && p < l) }' "${f%%:*}" || bad+=("${f%%:*} builds without the page-engine step before it")
    done
    grep -qF 'cache: ${{ !inputs.release && github.event_name != '"'schedule'"' }}' "$b" ||
        bad+=("$b caches the engine on a release or the weekly run")
    grep -qF 'cache: ${{ github.event_name != '"'schedule'"' }}' "$g" || bad+=("$g caches the engine on the weekly run")
    skip="$(awk '/^ *if: / { c = $0 } /uses: \$\/\.github\/actions\/page-engine$/ { print c; exit } /^ *- name: / { c = "" }' "$g")"
    if [[ -n "$skip" ]]; then
        skip="$(sed -n "s/^ *if: matrix.shard != '\([a-z-]*\)'\$/\1/p" <<<"$skip")"
        if [[ -z "$skip" ]]; then
            bad+=("$g page-engine step: a condition other than one skipped shard")
        elif awk -v s="$skip" '$1 == "lean-build" { for (i = 2; i <= NF; i++) if ($i == s) found = 1 } END { exit !found }' <<<"$STAGES"; then
            bad+=("$g skips Python + the engine cache on shard $skip, which builds")
        fi
    fi
    for f in "${bad[@]}"; do printf 'fanout: %s\n' "$f" >&2; done
    [[ ${#bad[@]} -eq 0 ]] || rc=1
    return $rc
}

# The spec's shape (spec-lint = the shared template's copy) + the repo's own instruction + state
# files (tools/meta-lint.mjs: rule frontmatter + globs, Artifacts paths, deferred acceptance,
# retired prototypes).
spec() {
    local rc=0
    sh .agent/spec-lint .agent/spec.md || rc=1
    node tools/meta-lint.mjs || rc=1
    return $rc
}

# CLAUDE.md Authoring's filler words, cut from the human-facing text outside the GUI: README,
# SECURITY, the skill, the CLI's help + messages (the Lean sources). GUI copy = review judgment.
filler() {
    local hits
    hits="$(git grep -n -i -w -E 'simply|robust(ly)?|seamless(ly)?|leverag(e|es|ed|ing)' -- \
        README.md SECURITY.md skill Fvtrace Main.lean)"
    [[ -z "$hits" ]] && return 0
    printf 'filler: words that human-facing text cuts (CLAUDE.md Authoring):\n%s\n' "$hits" >&2
    return 1
}

# Every shell script: `*.sh` + each other file whose shebang names sh or bash (`.agent/spec-lint`).
shell() {
    local files=()
    mapfile -t files < <(
        git ls-files -co --exclude-standard -- '*.sh'
        git ls-files -co --exclude-standard -z -- ':!*.sh' | xargs -0 awk 'FNR == 1 {
            if (/^#!(\/usr)?\/bin\/(env +)?(ba)?sh([ \t]|$)/) print FILENAME
            nextfile }'
    )
    shellcheck -- "${files[@]}"
}

# The version lives in two places Lake + the binary each read.
# One version in Fvtrace/Version.lean + lakefile.lean; README Install's floors = the ones
# tools/release.sh checks (release.md: moved together).
meta() {
    local lean lake glibc macos v rc=0
    lean="$(sed -n 's/^def version : String := "\(.*\)"$/\1/p' Fvtrace/Version.lean)"
    lake="$(sed -n 's/^  version := v!"\(.*\)"$/\1/p' lakefile.lean)"
    if [[ -z "$lean" || "$lean" != "$lake" ]]; then
        printf 'meta: Fvtrace/Version.lean version "%s" != lakefile.lean version "%s"\n' "$lean" "$lake" >&2
        rc=1
    fi
    glibc="$(sed -n 's/^glibc_max=//p' tools/release.sh)"
    macos="$(sed -n 's/^macos_min=//p' tools/release.sh)"
    while read -r v; do
        [[ "$v" == "$glibc" ]] || {
            printf 'meta: README promises glibc %s; tools/release.sh checks %s\n' "$v" "$glibc" >&2
            rc=1
        }
    done < <(grep -oE 'with glibc [0-9.]+ or later' README.md | cut -d' ' -f3)
    while read -r v; do
        [[ "$v" == "${macos%.0}" ]] || {
            printf 'meta: README promises macOS %s; tools/release.sh checks %s\n' "$v" "$macos" >&2
            rc=1
        }
    done < <(grep -oE 'macOS [0-9.]+ or later' README.md | cut -d' ' -f2)
    if [[ "$(grep -cE 'with glibc [0-9.]+ or later|macOS [0-9.]+ or later' README.md)" -ne 3 ]]; then
        printf 'meta: README Install names 3 floors (2 glibc, 1 macOS)\n' >&2
        rc=1
    fi
    return $rc
}

# Untracked files outside .gitignore, sorted.
untracked() { git ls-files --others --exclude-standard | sort; }

# A gate run leaves no untracked, unignored file: each new one = an output .gitignore lacks, or a
# stage that no longer cleans up after itself. $1 = `untracked` before the run.
leftovers() {
    local new
    new="$(comm -13 <(printf '%s\n' "$1") <(untracked))"
    [[ -z "$new" ]] && return 0
    printf 'leftovers: the run left files that are neither tracked nor ignored:\n%s\n' "$new" >&2
    return 1
}

main() {
    local start shard="" rows row name shards secs before
    if [[ $# -gt 0 ]]; then
        if [[ $# -ne 2 || "$1" != --shard ]] || ! shard_names | grep -x -F -- "$2" >/dev/null; then
            printf 'usage: tools/gate.sh [--shard %s]\n' "$(shard_names | paste -sd'|' -)" >&2
            exit 2
        fi
        shard="$2"
    fi
    start="$(stamp)"
    before="$(untracked)"
    ledger_begin "gate${shard:+:$shard}"
    # An array, not a `while read` loop: stages keep the caller's stdin.
    mapfile -t rows <<<"$STAGES"
    local picked=() together=()
    for row in "${rows[@]}"; do
        read -r name shards <<<"$row"
        [[ -n "$name" && ( -z "$shard" || " $shards " == *" $shard "* ) ]] || continue
        if [[ " $TOGETHER " == *" $name "* ]]; then together+=("$name"); else picked+=("$name"); fi
    done
    together_start "${together[@]}"
    for name in "${picked[@]}"; do stage "$name" "${name//-/_}"; done
    together_finish
    stage leftovers leftovers "$before"
    printf '\n=== gate%s ===\n' "${shard:+ (shard $shard)}"
    secs="$(elapsed "$start")"
    if [[ ${#failed[@]} -ne 0 ]]; then
        ledger_add gate "$secs" 1
        printf 'FAILED: %s\n' "${failed[*]}"
        printf 'each red before a rerun: bash tools/gate-ledger.sh classify STAGE product|gate|flake|planted\n'
        printf 'gate rc=1 %ss\n' "$secs"
        exit 1
    fi
    ledger_add gate "$secs" 0
    printf 'gate rc=0 %ss\n' "$secs"
}

# Sourcing exposes the stage functions without running the gate (tools/fast-gate.sh, probes).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
