import { test, expect } from "@playwright/test";
import { AxeBuilder } from "@axe-core/playwright";
import { serveFvtrace } from "./fvtrace-server.js";

/** @param {import("@playwright/test").Page} page */
async function axeIds(page) {
  const result = await new AxeBuilder({ page }).analyze();
  return result.violations.map(
    (v) => `${v.id}: ${v.nodes.map((n) => n.target.join(" ")).join(", ")}`,
  );
}

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
    await expect(page.getByRole("status")).toHaveText("Recorded evidence.");
    await page.locator("article.circuit").first().waitFor();
    const evaluation = await page.evaluate(async () => {
      const res = await fetch("/api/evaluation");
      /** @type {unknown} */
      const body = await res.json();
      return { status: res.status, body };
    });
    expect(evaluation.status).toBe(200);
    expect(evaluation.body).toMatchObject({ schema: "fvtrace.evaluation/1", mode: "recorded" });
    expect(await axeIds(page)).toEqual([]);
    await page
      .locator("article.circuit")
      .filter({ hasText: "C2 /" })
      .getByRole("button", { name: /^O2 / })
      .click();
    await page.getByRole("button", { name: "Suppose it is checked" }).click();
    await expect(page.getByRole("status")).toContainText("What-if");
    expect(await axeIds(page)).toEqual([]);
    await page.getByRole("button", { name: "Text" }).click();
    expect(await axeIds(page)).toEqual([]);
    await page.setViewportSize({ width: 390, height: 844 });
    expect(await axeIds(page)).toEqual([]);
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
