#!/usr/bin/env bash
# Positive controls for the purpose-built checks (upstream tools carry their own suites): each
# probe plants one failing input, runs the owning check, and demands a nonzero rc whose output
# names the expected cause. Targets are restored after every probe + on exit, then re-verified by
# sha256. Usage: tools/gate-probe.sh [probe...] (default: all). `git status --porcelain` after a
# run = the restore check.
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 1
export PATH="$root/.tools/bin:$root/node_modules/.bin:$PATH"
# shellcheck source=tools/gate.sh
source tools/gate.sh
# shellcheck source=tools/trust.sh
source tools/trust.sh

backup="$(mktemp -d)"
declare -A saved=()
restore() {
    local f
    for f in "${!saved[@]}"; do
        if [[ "${saved[$f]}" == absent ]]; then
            rm -f "$f"
        else
            cp "$backup/$(printf '%s' "$f" | tr '/' '_')" "$f"
            [[ "$(sha256sum "$f" | cut -d' ' -f1)" == "${saved[$f]}" ]] || {
                printf 'probe: %s did not restore\n' "$f" >&2
                exit 3
            }
        fi
    done
    saved=()
}
trap 'restore; rm -rf "$backup"' EXIT
keep() {
    local f="$1"
    if [[ -e "$f" ]]; then
        cp "$f" "$backup/$(printf '%s' "$f" | tr '/' '_')"
        saved[$f]="$(sha256sum "$f" | cut -d' ' -f1)"
    else
        saved[$f]=absent
    fi
}

passed=0
failures=()
# expect <probe> <regex> <command...>: the command must fail with output matching regex.
expect() {
    local name="$1" pattern="$2" out rc
    shift 2
    out="$("$@" 2>&1)"
    rc=$?
    if [[ $rc -ne 0 ]] && grep -q -E -- "$pattern" <<<"$out"; then
        printf 'probe %s: fired (rc=%d)\n' "$name" "$rc"
        passed=$((passed + 1))
    else
        printf 'probe %s: DID NOT FIRE (rc=%d)\n%s\n' "$name" "$rc" "$(tail -5 <<<"$out")" >&2
        failures+=("$name")
    fi
    restore
}
# allow <probe> <command...>: a negative control; the command must pass.
allow() {
    local name="$1" out rc
    shift
    out="$("$@" 2>&1)"
    rc=$?
    if [[ $rc -eq 0 ]]; then
        printf 'probe %s: passed as expected\n' "$name"
        passed=$((passed + 1))
    else
        printf 'probe %s: FAILED a valid input (rc=%d)\n%s\n' "$name" "$rc" "$(tail -5 <<<"$out")" >&2
        failures+=("$name")
    fi
    restore
}

# A build failure prints its errors, so a plant that no longer compiles reads as such.
trust_build() { lake build Fvtrace «fvtrace-trust» 2>&1 | grep -E '^error' ; lake exe fvtrace-trust; }
# Fvtrace/Proofs.lean imports the Spec submodules alone; a proof of a claim planted in the
# aggregate Fvtrace/Spec.lean needs that module imported.
plant_import() { sed -i '1i import Fvtrace.Spec' Fvtrace/Proofs.lean; }

probe_lean_style() {
    keep Fvtrace/Version.lean
    printf '\tdef plantedTab : Nat := 0\n' >>Fvtrace/Version.lean
    expect lean-style-tab 'tab$' lean_style
    keep Fvtrace/Version.lean
    printf 'def plantedTrailing : Nat := 0 \n' >>Fvtrace/Version.lean
    expect lean-style-trailing 'trailing whitespace' lean_style
    keep Fvtrace/Version.lean
    printf 'def plantedLong : String := "%s"\n' "$(printf 'x%.0s' {1..90})" >>Fvtrace/Version.lean
    expect lean-style-long 'longer than 100' lean_style
    keep Fvtrace/Version.lean
    printf 'def plantedNoNewline : Nat := 0' >>Fvtrace/Version.lean
    expect lean-style-newline 'no final newline' lean_style
}

# CI runs one job per gate.yml matrix shard: a stage without a shard, a shard the matrix lacks, or
# a job that never runs its shard would leave stages unrun in CI.
probe_fanout() {
    local table="$STAGES"
    STAGES+=$'planted\n'
    expect fanout-unsharded 'fanout: stage planted has no CI shard' fanout
    STAGES="$table"
    keep .github/workflows/gate.yml
    sed -i -E 's/^( +shard: \[)lean, /\1/' .github/workflows/gate.yml
    expect fanout-matrix 'matrix shards \[checks,e2e\] != tools/gate.sh shards \[checks,e2e,lean\]' fanout
    keep .github/workflows/gate.yml
    # `$SHARD` = the workflow's literal step text
    # shellcheck disable=SC2016
    sed -i 's/--shard "\$SHARD"/--shard lean/' .github/workflows/gate.yml
    # shellcheck disable=SC2016
    expect fanout-step 'runs no single `bash tools/gate.sh --shard "\$SHARD"` step' fanout
    keep .github/workflows/gate.yml
    # shellcheck disable=SC2016
    sed -i 's/run: bash tools\/gate.sh --shard "\$SHARD"/run: echo skipped # &/' .github/workflows/gate.yml
    # shellcheck disable=SC2016
    expect fanout-step-comment 'runs no single `bash tools/gate.sh --shard "\$SHARD"` step' fanout
    keep .github/workflows/gate.yml
    # shellcheck disable=SC2016
    sed -i 's/^\( *\)run: bash tools\/gate.sh --shard "\$SHARD"$/\1run: |\n\1  cat <<'\''LABEL'\''\n\1  run: bash tools\/gate.sh --shard "$SHARD"\n\1  LABEL/' \
        .github/workflows/gate.yml
    # shellcheck disable=SC2016
    expect fanout-step-heredoc 'runs no single `bash tools/gate.sh --shard "\$SHARD"` step' fanout
}

probe_meta() {
    keep lakefile.lean
    sed -i 's/^  version := v!".*"$/  version := v!"9.9.9"/' lakefile.lean
    expect meta-version 'meta: .* != lakefile.lean version "9.9.9"' meta
}

probe_trust() {
    # A plain `def` named like a generated equation lemma is still a claim.
    keep Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Spec\ndef eq_987654 : Prop := Fvtrace.version = "planted"\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    expect trust-unproven 'eq_987654: no proof' trust_build

    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    plant_import
    printf 'namespace Fvtrace.Spec\ndef PlantedAxiom : Prop := Fvtrace.version = "planted"\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\naxiom planted : False\ntheorem plantedAxiom : Spec.PlantedAxiom := planted.elim\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-axiom 'uses axiom Fvtrace.Proofs.planted' trust_build

    keep Fvtrace/Version.lean
    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    plant_import
    printf 'namespace Fvtrace\npartial def plantedLoop (n : Nat) : Nat := plantedLoop n\nend Fvtrace\n' \
        >>Fvtrace/Version.lean
    printf 'namespace Fvtrace.Spec\ndef PlantedPartial : Prop := Fvtrace.plantedLoop 0 = Fvtrace.plantedLoop 0\nend Fvtrace.Spec\n' \
        >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\ntheorem plantedPartial : Spec.PlantedPartial := rfl\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-escape-hatch 'reaches (partial|opaque) Fvtrace.plantedLoop' trust_build

    keep Fvtrace/Spec.lean
    keep Fvtrace/Proofs.lean
    plant_import
    printf 'namespace Fvtrace.Spec\ndef PlantedVacuous : Prop := 1 + 1 = 2\nend Fvtrace.Spec\n' >>Fvtrace/Spec.lean
    printf 'namespace Fvtrace.Proofs\ntheorem plantedVacuous : Spec.PlantedVacuous := rfl\nend Fvtrace.Proofs\n' \
        >>Fvtrace/Proofs.lean
    expect trust-vacuous 'PlantedVacuous: statement reaches no shipped code' trust_build

    lake build Fvtrace «fvtrace-trust» >/dev/null 2>&1
}

probe_capability() {
    # Capabilities (security review F1, fvtrace-trust): a server route reading a file, a handle
    # opened with a mode passed in as a value, a listed capability no definition uses.
    keep Fvtrace/Server.lean
    printf 'namespace Fvtrace.Server\ndef plantedRead (p : System.FilePath) : IO String := IO.FS.readFile p\nend Fvtrace.Server\n' \
        >>Fvtrace/Server.lean
    expect trust-capability \
        'Fvtrace.Server: uses read outside the capability list \(Fvtrace.Server.plantedRead\)' trust_build
    keep Fvtrace/Server.lean
    printf 'namespace Fvtrace.Server\ndef plantedOpen (p : System.FilePath) (m : IO.FS.Mode) : IO IO.FS.Handle := IO.FS.Handle.mk p m\nend Fvtrace.Server\n' \
        >>Fvtrace/Server.lean
    expect trust-capability-mode \
        'Fvtrace.Server: uses write outside the capability list \(Fvtrace.Server.plantedOpen\)' trust_build
    keep TrustMain.lean
    # shellcheck disable=SC2016 # the backticks quote Lean names
    sed -i 's/^  \[(`Fvtrace.Cli, /  [(`Fvtrace.Engine, ["process"]), (`Fvtrace.Cli, /' TrustMain.lean
    expect trust-capability-unused \
        'Fvtrace.Engine: capability list names process, which it no longer uses' trust_build
    lake build Fvtrace «fvtrace-trust» >/dev/null 2>&1
}

probe_replay_policy() {
    local log="$backup/check.log" accepts
    accepts=$'Lean paranoid kernel accepts the solution\nlean4lean kernel accepts the solution\nnanoda kernel accepts the solution\nLean default kernel accepts the solution'
    printf '%s\n' "${accepts/lean4lean kernel accepts the solution/lean4lean kernel rejected the solution}" >"$log"
    expect replay-required-kernel 'lean4lean kernel did not accept' replay_policy "$log" 1
    printf '%s\ncon-leche kernel rejected the solution\n' "$accepts" >"$log"
    expect replay-optional-kernel-rejects 'con-leche rejected the export' replay_policy "$log" 1
    printf '%s\ncon-ron: declined: unsupported Nat.div/mod environment\ncon-ron kernel rejected the solution\n' \
        "$accepts" >"$log"
    allow replay-optional-kernel-declines replay_policy "$log" 1
}

# The replay is skipped only for the very key that passed: an export one byte off, or no record,
# replays.
probe_trust_cache() {
    local keyfile="$backup/replayed" export="$backup/export.ndjson" key
    printf '{"planted":1}\n' >"$export"
    key="$(replay_key "$export")"
    printf '%s\n' "$key" >"$keyfile"
    allow trust-cache-hit replay_cached "$keyfile" "$key"
    printf '{"planted":2}\n' >"$export"
    expect trust-cache-changed-export 'replay needed' replay_cached "$keyfile" "$(replay_key "$export")"
    rm -f "$keyfile"
    expect trust-cache-no-record 'replay needed' replay_cached "$keyfile" "$key"
}

probe_audit() {
    keep lake-manifest.json
    jq '.packages = [{"name": "planted"}]' lake-manifest.json >"$backup/m.json" && cp "$backup/m.json" lake-manifest.json
    expect audit-lake-packages 'lists Lake packages' audit
    local open fixed
    open='{"advisories":{"1":{"github_advisory_id":"GHSA-plnt-0000-0000","severity":"low","module_name":"planted","vulnerable_versions":"<2","patched_versions":">=2"}}}'
    fixed="${open/GHSA-plnt-0000-0000/${DEV_RESIDUALS[0]}}"
    expect audit-open-advisory 'GHSA-plnt-0000-0000 low planted' audit_policy <<<"$open"
    expect audit-residual-fixed 'now has a fix' audit_policy <<<"$fixed"
    expect audit-registry-error 'no advisory report' audit_policy <<<'{"error":{"code":"ERR_PNPM_AUDIT_BAD_RESPONSE"}}'
}

probe_vendor() {
    keep c/hacl/Hacl_Hash_SHA2.h
    printf '// planted\n' >>c/hacl/Hacl_Hash_SHA2.h
    expect vendor-edited-file 'Hacl_Hash_SHA2.h does not match its pinned sha256' vendor
    keep c/hacl/planted.h
    printf '// planted\n' >c/hacl/planted.h
    expect vendor-unpinned-file 'unpinned file in c/hacl: planted.h' vendor
}

probe_cli() {
    local stub="$backup/fvtrace-ignores-home"
    printf '#!/usr/bin/env bash\nunset FVTRACE_HOME\nexec %q "$@"\n' "$root/.lake/build/bin/fvtrace" >"$stub"
    chmod +x "$stub"
    expect cli-data-folder 'FAIL FVTRACE_HOME holds the trace' \
        env FVTRACE_SMOKE_BIN="$stub" bash tests/cli/smoke.sh
}

probe_lean_pure() {
    keep TestPure.lean
    sed -i 's/^def main : IO UInt32 := do$/def main : IO UInt32 := do\n  let _ ← Fvtrace.Digest.ofString "planted"/' TestPure.lean
    expect lean-pure-ffi 'Could not find native implementation' lean_pure
}

probe_palette() {
    local css="$backup/palette.css"
    sed 's/--conductor: #506984;/--conductor: #b0bfce;/' web/style.css >"$css"
    expect palette-contrast 'conductor on --paper' env FVTRACE_PALETTE_CSS="$css" node --test tests/palette/
}

# The GUI's verdict words held equal to the engine's (Tests/Assets) + the skill's example trace held
# well-formed (Tests/Check): both run in the native suite, rebuilt after each plant.
assets_test() { lake build «fvtrace-tests» >/dev/null 2>&1; .lake/build/bin/fvtrace-tests; }

probe_assets() {
    keep web/words.js
    sed -i 's/^  open: "Pending verification",$/  open: "Not yet",/' web/words.js
    expect assets-verdict-words 'web/words.js names open as the engine does' assets_test
    keep skill/fvtrace/assets/example.trace.json
    jq '(.facts[] | select(.id == "O2") | .status) = "assumed"' \
        skill/fvtrace/assets/example.trace.json >"$backup/example.json" &&
        cp "$backup/example.json" skill/fvtrace/assets/example.trace.json
    expect assets-skill-example "the skill's example trace is well-formed" assets_test
    lake build «fvtrace-tests» >/dev/null 2>&1
}

# The page engine build (fvtrace-wasm, run by `lake build FvtraceEngine`): a pinned manifest digest
# that the fetched tree does not match, an import the page's loader does not provide, a linker
# warning outside the accepted two, a changed build step in lakefile.lean (Lake traces no target's
# own step, so the engine target traces the file; else a cached engine would replay). Each plant
# relinks (≈ 1 min); a failed build leaves the embedded engine as it was.
engine_build() { lake build FvtraceEngine 2>&1; }

probe_wasm() {
    keep tools/wasm.lock
    sed -i -E "s/^(libuv [^ ]+ [^ ]+ )[0-9a-f]{64}/\1$(printf '0%.0s' {1..64})/" tools/wasm.lock
    expect wasm-manifest 'libuv: manifest sha256 [0-9a-f]+, but tools/wasm.lock pins 0{64}' engine_build
    keep c/page_engine.c
    sed -i -e 's/^int fvtrace_init(void) {$/__attribute__((import_module("env"), import_name("probe"))) void fvtrace_probe(void);\nint fvtrace_init(void) {\n  fvtrace_probe();/' c/page_engine.c
    expect wasm-import 'imports env.probe \(kind 0\), which the page does not provide' engine_build
    keep c/page_engine.c
    sed -i -e 's/^lean_object \*initialize_fvtrace_Fvtrace_Snapshot(uint8_t builtin);$/lean_object *initialize_fvtrace_Fvtrace_Snapshot(void);/' \
        -e 's/initialize_fvtrace_Fvtrace_Snapshot(1);/initialize_fvtrace_Fvtrace_Snapshot();/' c/page_engine.c
    expect wasm-warning 'unexpected linker warnings' engine_build
    keep lakefile.lean
    sed -i -e 's/ "--githash", lean.githash,//' lakefile.lean
    expect wasm-build-step 'usage: fvtrace-wasm' engine_build
}

# The page engine's differential (gate stage `engine`) also fails on any engine output to standard
# error: a panic returns a default value that may still equal the native answer. The plant writes
# a panic line on one answer, as the loader routes the engine's fd_write, and answers correctly.
probe_engine() {
    local plant="$backup/plant-panic.mjs"
    cat >"$plant" <<'PLANT'
const real = WebAssembly.instantiate.bind(WebAssembly);
let calls = 0;
WebAssembly.instantiate = async (bytes, imports) => {
  const { module, instance } = await real(bytes, imports);
  const answer = instance.exports.fvtrace_answer;
  const exports = {
    ...instance.exports,
    fvtrace_answer: (...args) => {
      if (++calls === 7) console.error("fvTrace engine: PANIC planted");
      return answer(...args);
    },
  };
  return { module, instance: { exports } };
};
PLANT
    expect engine-panic 'fvTrace engine: PANIC planted' node --import "$plant" tests/engine/engine.test.mjs
}

probe_examples() {
    keep Fvtrace/Proofs/Plan.lean
    printf '\n-- planted\n' >>Fvtrace/Proofs/Plan.lean
    expect examples-stale-receipt 'receipt P6: stale \(changed Fvtrace/Proofs/Plan.lean' examples
}

# tools/scale.sh --assert (the F5 acceptance, run by hand on an idle host) grades rc, timeout, wall
# time + per-doubling ratio. A stub stands in for fvtrace: it sleeps STUB_K × n² s (n from its
# trace folder's name) and exits STUB_RC.
probe_scale() {
    local stub="$backup/fvtrace-stub"
    cat >"$stub" <<'STUB'
#!/usr/bin/env bash
# Stand-in fvtrace: sleeps k·n², prints STUB_B·n² bytes and holds STUB_M·n² MiB (STUB_SHAPE: that
# shape alone), n = the size in the trace folder's name; exits STUB_RC (STUB_ONLY: for that command
# alone). `export` writes a page
# whose engine cannot start; `serve` with STUB_SERVE = a server that answers with that HTTP status
# after k·n² s.
trace=""
for ((i = 1; i < $#; i++)); do [[ ${!i} == --trace ]] && { j=$((i + 1)); trace="${!j}"; }; done
dir="${trace%/trace.json}" n="${dir##*-}" shape="${dir##*/}"
if [[ $1 == serve && -n "${STUB_SERVE:-}" ]]; then
    exec python3 -c '
import http.server, os, sys, time
class Answer(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.rfile.read(int(self.headers["Content-Length"]))
        time.sleep(float(os.environ.get("STUB_K", "0")) * int(sys.argv[1]) ** 2)
        self.send_response(int(os.environ["STUB_SERVE"]))
        self.end_headers()
        self.wfile.write(b"{}")
    def log_message(self, *args):
        pass
s = http.server.HTTPServer(("127.0.0.1", 0), Answer)
print(f"Open http://fvtrace.localhost:{s.server_port}/#token=00", flush=True)
s.serve_forever()' "$n"
fi
sleep "$(awk -v n="$n" -v k="${STUB_K:-0}" 'BEGIN { printf "%.3f", k * n * n }')"
[[ $1 == export ]] && printf '%s' '<script type="application/json" id="fvtrace-data">{"snapshot":{}}</script><script type="application/octet-stream" id="fvtrace-engine">AAAA</script>' >"$3"
[[ -n "${STUB_B:-}" ]] && head -c "$((STUB_B * n * n))" /dev/zero
if [[ -n "${STUB_M:-}" && ( -z "${STUB_SHAPE:-}" || $shape == "${STUB_SHAPE}"-* ) ]]; then
    exec python3 -c "import sys; b = bytearray($((STUB_M * n * n)) << 20); sys.exit(${STUB_RC:-0})"
fi
[[ -n "${STUB_ONLY:-}" && $1 != "${STUB_ONLY}" ]] && exit 0
exit "${STUB_RC:-0}"
STUB
    chmod +x "$stub"
    local run=(bash tools/scale.sh --assert --bin "$stub" --n "2 4" wide)
    STUB_RC=3 expect scale-rc 'FAIL wide check n=2: rc 3' "${run[@]}"
    STUB_RC=3 STUB_ONLY=plan expect scale-text 'FAIL wide plan n=2: rc 3' "${run[@]}"
    STUB_K=0.02 expect scale-ratio 'FAIL wide check n=2→4: ratio [0-9.]+ > 2.5 per doubling' "${run[@]}"
    STUB_K=0.02 expect scale-wall 'FAIL wide check n=4: wall [0-9.]+ s > 0.1 s' "${run[@]}" --max-wall 0.1
    STUB_K=0.2 expect scale-timeout 'FAIL wide check n=4: timeout after 1 s' "${run[@]}" --timeout 1
    STUB_M=20 expect scale-rss 'FAIL wide check n=2→4: rss ratio [0-9.]+ > 2.5 per doubling' "${run[@]}"
    STUB_B=100000 expect scale-bytes 'FAIL wide eval n=2→4: bytes ratio [0-9.]+ > 2.2 per doubling' \
        "${run[@]}"
    STUB_M=10 STUB_SHAPE=outcomes expect scale-rss-cap 'FAIL outcomes eval: rss [0-9]+ MiB > 1.25' \
        "${run[@]}" outcomes --max-ratio 100
    # The serve rows: a server that exits, one that never prints its link, one that answers an
    # error, one past the time limit; the page rows: an engine that cannot start.
    STUB_RC=3 expect scale-serve-exit 'FAIL wide serve n=2: rc 3' "${run[@]}"
    STUB_K=0.2 expect scale-serve-start 'FAIL wide serve n=4: timeout after 1 s' "${run[@]}" --timeout 1
    STUB_SERVE=500 expect scale-serve-status 'FAIL wide serve:action n=2: rc 500' "${run[@]}"
    STUB_SERVE=200 STUB_K=0.2 expect scale-serve-timeout 'FAIL wide serve:action n=4: timeout after 1 s' \
        "${run[@]}" --timeout 1
    expect scale-page 'FAIL wide page n=2: rc 2' "${run[@]}"
    # The GUI rows: a stand-in driver whose served selection takes 0.5 s against its 0.1 s bound.
    local gui="$backup/scale-gui-stub.mjs"
    cat >"$gui" <<'STUB'
const steps = ["first", "select", "details", "busy", "whatif"].flatMap((s) => [`served:${s}`, `page:${s}`]);
for (const s of [...steps, "page:startup"])
  process.stdout.write(`gui:${s} 0 ${s === "served:select" ? "0.500" : "0.010"} - 0 0 0.1\n`);
STUB
    expect scale-gui-bound 'FAIL wide gui:served:select n=2: wall 0.500 s > 0.1 s' \
        "${run[@]}" --gui "$gui"
    allow scale-pass bash tools/scale.sh --assert --n "2 4" --max-ratio 100 wide
}

# tools/compare.sh (cross-revision byte equality) fails on any difference: two stand-in binaries
# that exit differently differ on every run, one compared with itself on none; a run past the
# time limit fails too.
probe_compare() {
    expect compare-differ 'DIFF self check \(rc\)' bash tools/compare.sh /bin/true /bin/false
    allow compare-same bash tools/compare.sh /bin/true /bin/true
    # Equal partial output proves nothing: a stand-in whose first run outlasts the limit.
    local slow="$backup/slow-once"
    # shellcheck disable=SC2016 # the stand-in's own script text
    printf '#!/usr/bin/env bash\n[[ -e "$0.ran" ]] || { : >"$0.ran"; sleep 3; }\n' >"$slow"
    chmod +x "$slow"
    expect compare-timeout 'TIMEOUT old form eval' bash tools/compare.sh --timeout 1 "$slow" "$slow"
    # The v1 → v2 paths time out too: both binaries stall alike (equal partial output, equal rc), on
    # a JSON comparison and on an expansion oracle.
    local json="$backup/slow-whatif" oracle="$backup/slow-action"
    printf '%s\n' '#!/usr/bin/env bash' '[[ " $* " == *" O9=proved "* ]] && sleep 3' 'exit 0' >"$json"
    printf '%s\n' '#!/usr/bin/env bash' 'case " $* " in' \
        '*" --action "*) sleep 3 ;;' \
        '" eval --trace "*) printf '"'"'{"actions":[{"id":"a","overrides":[]}]}\n'"'"' ;;' \
        'esac' >"$oracle"
    chmod +x "$json" "$oracle"
    expect compare-json-timeout 'TIMEOUT old self eval --whatif O9=proved' \
        bash tools/compare.sh --timeout 1 "$json" "$json"
    expect compare-oracle-timeout 'TIMEOUT new self eval --action a' \
        bash tools/compare.sh --timeout 1 "$oracle" "$oracle"
}

probes=("$@")
[[ ${#probes[@]} -gt 0 ]] ||
    probes=(lean_style fanout meta trust capability replay_policy trust_cache audit vendor cli lean_pure palette assets engine examples wasm scale compare)
for p in "${probes[@]}"; do "probe_$p"; done

printf '\nprobes: %d passed, %d failed\n' "$passed" "${#failures[@]}"
[[ ${#failures[@]} -eq 0 ]] || {
    printf 'FAILED: %s\n' "${failures[*]}"
    exit 1
}
