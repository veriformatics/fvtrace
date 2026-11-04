import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

void test("GUI driver removes its temporary home when the server cannot spawn", () => {
  const dir = mkdtempSync(join(tmpdir(), "scale-spawn-probe-"));
  try {
    const p = spawnSync(
      process.execPath,
      ["tools/scale-gui.mjs", join(dir, "missing"), dir, join(dir, "page.html")],
      {
        env: { ...process.env, TMPDIR: dir },
        encoding: "utf8",
        timeout: 120000,
      },
    );
    assert.notEqual(p.status, 0);
    assert.match(p.stderr, /ENOENT/);
    assert.deepEqual(
      readdirSync(dir).filter((name) => name.startsWith("scale-gui-")),
      [],
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
