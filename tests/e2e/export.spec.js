import { test, expect } from "@playwright/test";
import { AxeBuilder } from "@axe-core/playwright";
import { rm } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { fvtrace, prepareStudy } from "./fvtrace-server.js";

/** @type {{ dir: string, page: string }} */
let fixture;

test.beforeAll(async () => {
  const { dir, project, env } = await prepareStudy("synthetic");
  const page = join(dir, "claims.html");
  fvtrace(["export", "--html", page], project, env);
  fixture = { dir, page };
});

test.afterAll(async () => {
  await rm(fixture.dir, { recursive: true, force: true });
});

/** @param {import("@playwright/test").Page} page */
const c2 = (page) =>
  page
    .locator("article.circuit")
    .filter({ has: page.locator(".tag-id").getByText("C2", { exact: true }) });

test("the exported page works offline under its own CSP", async ({ page }) => {
  /** @type {string[]} */
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(err.message));
  await page.goto(pathToFileURL(fixture.page).href);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Synthetic study");
  await expect(page.getByText("This page was exported: each what-if applies alone.")).toBeVisible();
  await expect(c2(page).locator(".tag-soft .cap-trim")).toHaveText("Pending verification");
  await c2(page).getByRole("button", { name: "Suppose EN2 proved" }).click();
  await expect(page.getByRole("status")).toHaveText(
    "Showing a what-if: suppose EN2 is proved. Nothing has been recorded.",
  );
  await expect(
    c2(page).getByRole("button", { name: "Restore the recorded status of EN2" }),
  ).toBeVisible();
  await c2(page).getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.getByRole("status")).toContainText("suppose O2 is verified by a checker");
  await expect(page.getByRole("status")).not.toContainText("EN2");
  expect(new URL(page.url()).hash).toContain("action=suppose%3AO2");
  await page.getByRole("button", { name: "Show the facts as recorded" }).click();
  await expect(page.getByRole("status")).toContainText("Showing the facts as recorded.");
  // Another action supposes O2: its symbol stays put until the reset (actions apply alone).
  await page.locator(".experiment-row").filter({ hasText: "Check the result" }).click();
  await page.locator("#inspector").getByRole("button", { name: "Suppose it succeeds" }).click();
  await expect(page.getByRole("status")).toContainText("O2 is verified by a checker");
  await expect(c2(page).getByRole("button", { name: "O2: Verified by a checker" })).toHaveAttribute(
    "aria-disabled",
    "true",
  );
  await page.getByRole("button", { name: "Show the facts as recorded" }).click();
  await expect(page.getByRole("status")).toContainText("Showing the facts as recorded.");
  const axe = await new AxeBuilder({ page }).analyze();
  expect(axe.violations.map((v) => v.id)).toEqual([]);
  expect(errors).toEqual([]);
});

test("a link to a what-if the page does not hold says so", async ({ page }) => {
  await page.goto(`${pathToFileURL(fixture.page).href}#action=suppose%3AZZ`);
  await expect(page.locator("#error")).toHaveText(
    'This page holds no what-if "suppose:ZZ", so it shows the facts as recorded.',
  );
  await expect(page.getByRole("status")).toContainText("Showing the facts as recorded.");
});
