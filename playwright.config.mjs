// Browser checks of the GUI. CI + gate use Playwright's bundled headless Chromium (it honors
// reduced-motion emulation); `CHROME` points a local run at another Chromium binary.
import { defineConfig } from "@playwright/test";

const executablePath = process.env["CHROME"];

export default defineConfig({
  testDir: "tests/e2e",
  testMatch: "**/*.spec.js",
  fullyParallel: true,
  forbidOnly: true,
  retries: 0,
  // Per test, setup hook + fixture teardown: a loaded host stretches every test, e.g.
  // export.spec.js:76 3.9 s → 33.9 s at load ≈ 2.6× on 8 CPUs; the limit is for hangs, not speed.
  timeout: 90_000,
  reporter: "line",
  use: {
    browserName: "chromium",
    headless: true,
    ...(executablePath ? { launchOptions: { executablePath } } : {}),
  },
});
