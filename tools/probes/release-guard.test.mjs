import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

const yaml = readFileSync(".github/workflows/release.yml", "utf8");
const step = yaml.split("- name: Check that every archive names the tag's version")[1];
const block = step?.split("run: |\n")[1]?.match(/^(?: {10}[^\n]*\n|\n)*/)?.[0];
assert.ok(block, "release archive guard step exists");
const guard = block.replace(/^ {10}/gm, "");
const expected = [
  "linux-x86_64.tar.gz",
  "linux-arm64.tar.gz",
  "macos-arm64.tar.gz",
  "windows-x86_64.zip",
].flatMap((suffix) => [`fvtrace-0.1.0-${suffix}`, `fvtrace-0.1.0-${suffix}.sha256`]);

for (const extra of [
  undefined,
  "fvtrace-9.9.9-linux-x86_64.tar.gz",
  "notes.txt",
  ".hidden",
  "subdir/",
  "missing",
]) {
  void test(`publish guard: ${extra ?? "expected archive set"}`, () => {
    const dir = mkdtempSync(join(tmpdir(), "release-guard-"));
    try {
      mkdirSync(join(dir, "dist"));
      for (const name of extra === "missing" ? expected.slice(1) : expected)
        writeFileSync(join(dir, "dist", name), "archive");
      if (extra?.endsWith("/")) mkdirSync(join(dir, "dist", extra));
      else if (extra && extra !== "missing") writeFileSync(join(dir, "dist", extra), "unexpected");
      const p = spawnSync("bash", ["-e", "-c", guard], {
        cwd: dir,
        env: { ...process.env, TAG: "v0.1.0" },
        encoding: "utf8",
      });
      if (extra) {
        assert.notEqual(p.status, 0, `unexpected downloaded path accepted: ${extra}`);
        assert.match(
          p.stderr,
          extra === "missing" ? /release: no dist\// : /release: unexpected archive file/,
        );
      } else assert.equal(p.status, 0, p.stderr);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
}
