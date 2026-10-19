import { test, expect } from "@playwright/test";
import { serveFvtrace } from "./fvtrace-server.js";

/** @type {Awaited<ReturnType<typeof serveFvtrace>>} */
let web;
test.beforeEach(async () => {
  web = await serveFvtrace();
});
test.afterEach(async () => {
  await web.close();
});

/** @param {import("@playwright/test").Page} page @param {string} id */
function circuit(page, id) {
  return page.locator("article.circuit").filter({ hasText: `${id} /` });
}

test("the recorded view shows the engine's verdicts and sentences", async ({ page }) => {
  await page.goto(web.url);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Synthetic study");
  await expect(page.locator("#review")).toContainText("Draft");
  await expect(page.getByRole("status")).toHaveText("Recorded evidence.");
  await expect(circuit(page, "C1")).toContainText(
    "Assuming “O1 entails C1.”: The contrast is the treatment effect.",
  );
  await expect(circuit(page, "C1").locator(".claim-state")).toHaveText("On assumption (draft)");
  await expect(circuit(page, "C2").locator(".claim-state")).toHaveText("Not yet (draft)");
});

test("switches suppose facts, the engine answers, the address keeps it", async ({ page }) => {
  await page.goto(web.url);
  const c2 = circuit(page, "C2");
  await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.getByRole("status")).toContainText("What-if: O2 checked");
  await c2.getByRole("button", { name: "Suppose EN2 proved" }).click();
  await expect(page.getByRole("status")).toContainText("EN2 proved");
  await expect(c2.locator(".claim-state")).toHaveText("On assumption (what-if, draft)");
  await expect(c2.locator(".sentence")).toHaveText(
    "Assuming “The model assumptions hold.”: Treatment raises the marker.",
  );
  expect(new URL(page.url()).hash).toContain("whatif=");
  await page.reload();
  await expect(circuit(page, "C2").locator(".claim-state")).toHaveText(
    "On assumption (what-if, draft)",
  );
  await circuit(page, "C2")
    .getByRole("button", { name: "Restore the recorded status of O2" })
    .click();
  await expect(circuit(page, "C2").locator(".claim-state")).toHaveText("Not yet (what-if, draft)");
  await page.getByRole("button", { name: "Restore the recorded evidence" }).click();
  await expect(page.getByRole("status")).toHaveText("Recorded evidence.");
});

test("a linked what-if goes to the engine as written", async ({ page }) => {
  await page.goto(`${web.url}#whatif=O2%3Dchecked%2CO2%3Dviolated`);
  await expect(page.locator("#error")).toBeVisible();
  await expect(page.locator("#error")).toHaveText(
    "O2 appears twice in the what-if. This page shows the recorded evidence instead.",
  );
  await expect(page.getByRole("status")).toHaveText("Recorded evidence.");
  expect(new URL(page.url()).hash).not.toContain("whatif=");
});

test("the inspector shows a fact, a claim's plan and an experiment", async ({ page }) => {
  await page.goto(web.url);
  await circuit(page, "C2").getByRole("button", { name: /^O2 / }).click();
  const inspector = page.locator("#inspector");
  await expect(inspector.getByRole("heading", { level: 2 })).toHaveText(
    "The marker rises in treated samples.",
  );
  await inspector.getByRole("button", { name: "Suppose it is checked" }).click();
  await expect(page.getByRole("status")).toContainText("O2 checked");
  await circuit(page, "C2").getByRole("button", { name: "Suppose EN2 proved" }).click();
  await page.getByRole("button", { name: "Restore the recorded status of O2" }).first().click();
  await circuit(page, "C2").locator(".claim-head").click();
  await expect(inspector).toContainText(
    "Run E1. If the plan succeeds, the claim reads On assumption.",
  );
  await inspector.getByRole("button", { name: "Suppose the plan succeeds" }).click();
  await expect(circuit(page, "C2").locator(".claim-state")).toHaveText(
    "On assumption (what-if, draft)",
  );
  await page.getByRole("button", { name: /Check the result table/ }).click();
  await expect(inspector).toContainText("If it fails");
  await expect(inspector).toContainText("C2 changes from");
});

test("the text view lists the sentences and open facts", async ({ page }) => {
  await page.goto(web.url);
  await page.getByRole("button", { name: "Text" }).click();
  await expect(page.locator(".text-list").first()).toContainText(
    "Assuming “O1 entails C1.”: The contrast is the treatment effect.",
  );
  await expect(page.getByRole("heading", { name: /Facts to verify/ })).toBeVisible();
  expect(new URL(page.url()).hash).toContain("view=text");
});

test("reduced motion: no transition or animation runs", async ({ browser }) => {
  const context = await browser.newContext({ reducedMotion: "reduce" });
  const page = await context.newPage();
  await page.goto(web.url);
  await page.locator("article.circuit").first().waitFor();
  const moving = await page.evaluate(
    () =>
      [...document.querySelectorAll("*")].filter((el) => {
        const s = getComputedStyle(el);
        const durations = s.transitionDuration
          .split(",")
          .concat(s.animationName === "none" ? [] : s.animationDuration.split(","));
        return durations.some((t) => parseFloat(t) > 0);
      }).length,
  );
  expect(moving).toBe(0);
  await context.close();
});
