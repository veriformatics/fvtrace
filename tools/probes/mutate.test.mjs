import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  utimesSync,
  writeFileSync,
} from "node:fs";
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

void test("--list reads the source alone: no write, no backup", () => {
  const dir = mkdtempSync(join(tmpdir(), "mutation-probe-"));
  try {
    const file = join(dir, "Listed.lean");
    writeFileSync(file, "def a : Nat := 1 + 2\n");
    const old = new Date("2020-01-01T00:00:00Z");
    utimesSync(file, old, old);
    const p = spawnSync(process.execPath, [tool, file, "--list"], { encoding: "utf8" });
    assert.equal(p.status, 0, p.stderr);
    assert.equal(statSync(file).mtimeMs, old.getTime());
    assert.deepEqual(readdirSync(dir), ["Listed.lean"]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

void test("a campaign classifies a checked site killed and an unchecked site survived", () => {
  const dir = mkdtempSync(join(tmpdir(), "mutation-probe-"));
  try {
    const file = join(dir, "Classified.lean");
    const source = "def a : Nat := 1 + 2\ndef b : Nat := 7\n";
    writeFileSync(file, source);
    // The suite checks line 1 alone: every line-1 mutant breaks it, line 2's survives.
    const p = spawnSync(
      process.execPath,
      [tool, file, "--build", "true", "--test", `grep -q '1 + 2' ${JSON.stringify(file)}`],
      { encoding: "utf8" },
    );
    assert.equal(p.status, 1, `a survivor exits 1: ${p.stderr}`);
    assert.match(p.stdout, /SURVIVED \S+Classified\.lean:2 7 → 8/);
    assert.match(p.stdout, /killed \S+Classified\.lean:1 \+ → -/);
    assert.match(p.stdout, /mutants: 4 · killed 3 · survived 1 · incompetent 0/);
    assert.equal(readFileSync(file, "utf8"), source, "the source comes back unchanged");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
