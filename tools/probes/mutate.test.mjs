import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

const tool = "tools/mutate.mjs";
for (const [arg, status] of /** @type {const} */ ([
  ["--help", 0],
  ["--unknown", 2],
]))
  void test(`mutation CLI usage: ${arg}`, () => {
    const p = spawnSync(process.execPath, [tool, arg], { encoding: "utf8" });
    assert.equal(p.status, status, arg);
    assert.match(p.stdout + p.stderr, /^usage: node tools\/mutate\.mjs/m);
    assert.doesNotMatch(p.stderr, /ERR_PARSE_ARGS|\n\s+at /);
  });

/** @param {string} source @param {(out: string, file: string) => void} check */
function list(source, check) {
  const dir = mkdtempSync(join(tmpdir(), "mutation-probe-"));
  try {
    const file = join(dir, "Raw.lean");
    writeFileSync(file, source);
    const p = spawnSync(process.execPath, [tool, file, "--list"], { encoding: "utf8" });
    assert.equal(p.status, 0, p.stderr);
    check(p.stdout, file);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

void test("mutation sites exclude Lean raw strings through their exact terminators", () => {
  list(
    [
      "def before : Nat := 7",
      'def raw := r#"a " true 9 " tail"#',
      'def multiline := r##"true 13 "#',
      'false 15 "##',
      'def plain := r"backslash \\"',
      "def after : Bool := true",
      "",
    ].join("\n"),
    (out, file) => {
      assert.equal(out, `${file}:1 7 → 8\n${file}:6 true → false\nmutants: 2\n`);
    },
  );
});

void test("a raw prefix requires a token boundary", () => {
  list(
    [
      "import Lean",
      'syntax "regular" str : term',
      "macro_rules | `(regular $s:str) => `($s)",
      'def adjacent := regular"before \\" true 9 tail"',
      "",
    ].join("\n"),
    (out) => assert.equal(out, "mutants: 0\n"),
  );
});
