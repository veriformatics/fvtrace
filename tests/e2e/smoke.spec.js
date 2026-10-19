import { test, expect } from "@playwright/test";
import { AxeBuilder } from "@axe-core/playwright";
import { serveWeb } from "./static-server.js";

test("the GUI stub loads without errors and passes axe", async ({ page }) => {
  const web = await serveWeb();
  /** @type {string[]} */
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(err.message));
  try {
    await page.goto(web.url);
    await expect(page).toHaveTitle("fvTrace");
    await expect(page.getByRole("status")).toHaveText("No trace loaded yet.");
    const axe = await new AxeBuilder({ page }).analyze();
    expect(axe.violations.map((v) => v.id)).toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await web.close();
  }
});
