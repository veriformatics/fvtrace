import { test, expect } from "@playwright/test";
import { AxeBuilder } from "@axe-core/playwright";
import { serveFvtrace } from "./fvtrace-server.js";

test("the GUI loads through fvtrace serve without errors and passes axe", async ({ page }) => {
  const web = await serveFvtrace();
  /** @type {string[]} */
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(err.message));
  try {
    await page.goto(web.url);
    expect(page.url()).toBe(`${web.base}/`);
    await expect(page).toHaveTitle("fvTrace");
    await expect(page.getByRole("status")).toHaveText("No trace loaded yet.");
    const evaluation = await page.evaluate(async () => {
      const res = await fetch("/api/evaluation");
      /** @type {unknown} */
      const body = await res.json();
      return { status: res.status, body };
    });
    expect(evaluation.status).toBe(200);
    expect(evaluation.body).toMatchObject({ schema: "fvtrace.evaluation/1", mode: "recorded" });
    const axe = await new AxeBuilder({ page }).analyze();
    expect(axe.violations.map((v) => v.id)).toEqual([]);
    expect(errors).toEqual([]);
  } finally {
    await web.close();
  }
});

test("a page without the token link is refused", async ({ page }) => {
  const web = await serveFvtrace();
  try {
    const res = await page.goto(`${web.base}/`);
    expect(res?.status()).toBe(403);
  } finally {
    await web.close();
  }
});
