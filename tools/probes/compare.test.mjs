import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import test from "node:test";

const source = readFileSync("tools/compare.sh", "utf8");
const helpers = source.slice(source.indexOf("run_one() {"), source.indexOf("inputs=("));
const form = source.slice(
  source.indexOf("run_one old form "),
  source.indexOf('for spec in "${inputs[@]}"'),
);
const v1 = {
  schema: "fvtrace.evaluation/1",
  facts: [],
  claims: [],
  experiments: [],
  actions: [{ id: "a", overrides: [] }],
};
const v2 = {
  ...v1,
  schema: "fvtrace.evaluation/2",
  actions: [{ id: "a", kind: null, target: null }],
};

/** @param {string} mode @param {string} expression @param {boolean} expected */
function check(mode, expression, expected) {
  const dir = mkdtempSync(join(tmpdir(), "compare-probe-"));
  try {
    const stub = `#!/usr/bin/env bash
if [[ "$MODE" == malformed ]]; then
  [[ "$0" == */old ]] && printf '{' || printf '['
elif [[ "$MODE" == multiple ]]; then
  if [[ "$0" == */old ]]; then printf '%s\\n' '${JSON.stringify(v1)}' '${JSON.stringify(v1)}'
  else printf '%s\\n' '${JSON.stringify(v2)}' '${JSON.stringify(v2)}'; fi
elif [[ "$MODE" == transform ]]; then
  printf '%s\\n' '{"claims":false}'
elif [[ " $* " == *" --details "* ]]; then
  printf '{"raisedBy":[]}\\n'
elif [[ "$0" == */old ]]; then
  printf '%s\\n' '${JSON.stringify(v1)}'
else
  printf '%s\\n' '${JSON.stringify(v2)}'
fi
if [[ "$0" == */new && ( " $* " == *" --action "* || " $* " == *" --details "* ) ]]; then
  printf '%s\\n' "$*" >>"$WORK/calls"
  [[ "$MODE" == stderr ]] && printf 'planted stderr\\n' >&2
  [[ "$MODE" == rc ]] && exit 7
fi
exit 0
`;
    for (const name of ["old", "new"]) {
      writeFileSync(join(dir, name), stub);
      chmodSync(join(dir, name), 0o755);
    }
    if (expression === "details") {
      // The stand-in's OLD envelope owns the detail payload, independently of the grader.
      writeFileSync(
        join(dir, "old"),
        stub.replaceAll(
          JSON.stringify(v1),
          JSON.stringify({ ...v1, facts: [{ id: "f" }], actions: [] }),
        ),
      );
    }
    const command =
      expression === "form"
        ? form
        : expression === "json"
          ? 'cmp_json test "$root" trace eval'
          : 'oracles test "$root" trace';
    const script = `set -uo pipefail\nold="$WORK/old" new="$WORK/new" work="$WORK" root="$ROOT" limit=30 runs=0 diffs=0 timeouts=0\n${helpers}\n${command}\nprintf 'differences=%s\\n' "$diffs"\n[[ $diffs -eq 0 ]]`;
    const p = spawnSync("bash", ["-c", script], {
      env: { ...process.env, MODE: mode, WORK: dir, ROOT: resolve(".") },
      encoding: "utf8",
    });
    if (expression === "actions" || expression === "details")
      assert.match(
        readFileSync(join(dir, "calls"), "utf8"),
        expression === "actions" ? /--action a/ : /--details fact:f/,
      );
    assert.equal(p.status === 0, expected, p.stdout + p.stderr);
    if (!expected) assert.match(p.stdout, /DIFF/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

for (const oracle of ["actions", "details"])
  for (const mode of ["same", "rc", "stderr"])
    void test(`v1 ${oracle} oracle: ${mode}`, () => check(mode, oracle, mode === "same"));
void test("JSON transforms reject different malformed outputs", () =>
  check("malformed", "json", false));
void test("envelope form detection rejects malformed JSON", () =>
  check("malformed", "form", false));
void test("JSON transform failures count independently of their empty output", () =>
  check("transform", "json", false));
void test("envelope form detection requires one document", () => check("multiple", "form", false));
void test("JSON comparisons require one document", () => check("multiple", "json", false));
