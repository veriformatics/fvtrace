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
  reporter: "line",
  use: {
    browserName: "chromium",
    headless: true,
    ...(executablePath ? { launchOptions: { executablePath } } : {}),
  },
});
