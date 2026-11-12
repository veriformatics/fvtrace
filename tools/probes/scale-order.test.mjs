import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

// The served first view counts from the printed link with the browser already open (kernel.md
// U-time): a server spawned first runs its launch evaluation while Chromium starts.
void test("GUI driver opens its browser before it starts the server", () => {
  const dir = mkdtempSync(join(tmpdir(), "scale-order-probe-"));
  try {
    const stub = join(dir, "fvtrace");
    const mark = join(dir, "mark");
    // Stand-in `fvtrace serve`: records whether a browser already runs beside it, then exits.
    writeFileSync(
      stub,
      `#!/usr/bin/env bash
if pgrep -P "$PPID" -f 'chrom|headless' >/dev/null; then echo browser >"$MARK"; else echo none >"$MARK"; fi
exit 3
`,
    );
    chmodSync(stub, 0o755);
    const p = spawnSync(
      process.execPath,
      ["tools/scale-gui.mjs", stub, dir, join(dir, "page.html")],
      {
        env: { ...process.env, MARK: mark },
        encoding: "utf8",
        timeout: 120000,
      },
    );
    assert.match(p.stderr, /fvtrace serve exited 3/);
    assert.equal(readFileSync(mark, "utf8").trim(), "browser");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
