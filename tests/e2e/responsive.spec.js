// The GUI's responsiveness, functional half (`.agent/contracts/kernel.md` U-select, U-update,
// U-long, U-access, U-busy, U-coalesce; the times = tools/scale-gui.mjs): a selection or an
// answer keeps every unchanged card's element, long lists mount as they come near and stay
// reachable by keyboard, a request past 1 s shows that the page is working, one evaluation runs
// at a time and the newest wins.
import { test, expect } from "@playwright/test";
import { serveFvtrace, serveScale } from "./fvtrace-server.js";

/** @type {{ url: string, close: () => Promise<void> }} */
let web;
test.afterEach(async () => {
  await web.close();
});

/** @param {import("@playwright/test").Page} page @param {string} id */
const card = (page, id) =>
  page
    .locator("article.circuit")
    .filter({ has: page.locator(".claim-head .tag-id").getByText(id, { exact: true }) });

/** Tags every card element now on the board (a property, not an attribute: a new element lacks
 * it). @param {import("@playwright/test").Page} page */
const tagCards = (page) =>
  page.evaluate(() => {
    for (const el of document.querySelectorAll("article.circuit"))
      Reflect.set(el, "fvtraceTag", el.querySelector(".claim-head .tag-id")?.textContent);
  });

/** The ids of the cards still carrying their tag, and of those that do not.
 * @param {import("@playwright/test").Page} page */
const tagged = (page) =>
  page.evaluate(() => {
    /** @type {{ kept: string[], fresh: string[] }} */
    const out = { kept: [], fresh: [] };
    for (const el of document.querySelectorAll("article.circuit")) {
      const id = el.querySelector(".claim-head .tag-id")?.textContent ?? "";
      (Reflect.get(el, "fvtraceTag") === id ? out.kept : out.fresh).push(id);
    }
    out.kept.sort();
    out.fresh.sort();
    return out;
  });

/** Holds each answer to a what-if request (no `details`) until `release`; counts them and the
 * most in flight at once. @param {import("@playwright/test").Page} page */
async function holdEvaluations(page) {
  /** @type {(() => void)[]} */
  const held = [];
  const seen = { specs: /** @type {string[]} */ ([]), inFlight: 0, most: 0 };
  await page.route("**/api/answer", async (route) => {
    /** @type {unknown} */
    const body = JSON.parse(route.request().postData() ?? "{}");
    const isRecord = typeof body === "object" && body !== null;
    /** @type {unknown} */
    const details = isRecord ? Reflect.get(body, "details") : undefined;
    /** @type {unknown} */
    const whatif = isRecord ? Reflect.get(body, "whatif") : undefined;
    if (details !== undefined || whatif === "") return route.continue();
    seen.specs.push(String(whatif));
    seen.inFlight++;
    seen.most = Math.max(seen.most, seen.inFlight);
    await new Promise((resolve) => held.push(() => resolve(undefined)));
    await route.continue();
    seen.inFlight--;
  });
  return { seen, release: () => held.splice(0).forEach((go) => go()) };
}

test("a selection moves the highlight and keeps every card's element", async ({ page }) => {
  web = await serveFvtrace();
  await page.goto(web.url);
  await card(page, "C3").waitFor();
  await tagCards(page);
  await card(page, "C2").locator(".claim-head .tag-id .ref").click();
  await expect(card(page, "C2")).toHaveClass(/selected/);
  await expect(page.locator("#inspector h2")).toBeVisible();
  await card(page, "C1").locator(".claim-head .tag-id .ref").click();
  await expect(card(page, "C1")).toHaveClass(/selected/);
  await expect(card(page, "C2")).not.toHaveClass(/selected/);
  await expect(card(page, "C2").locator(".claim-head .tag-id .ref")).toHaveAttribute(
    "aria-pressed",
    "false",
  );
  expect(await tagged(page)).toEqual({ kept: ["C1", "C2", "C3"], fresh: [] });
});

test("a what-if replaces only the cards whose content changed", async ({ page }) => {
  web = await serveFvtrace();
  await page.goto(web.url);
  await card(page, "C3").waitFor();
  await tagCards(page);
  await card(page, "C2").getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.locator("#scenario-text")).toContainText("suppose O2 is verified");
  await expect(page.locator("body")).not.toHaveAttribute("aria-busy");
  // O2 sits on C2's diagram alone: C1 + C3 keep their elements.
  expect(await tagged(page)).toEqual({ kept: ["C1", "C3"], fresh: ["C2"] });
});

test("a long board mounts as it comes near, names each position and stays reachable", async ({
  page,
}) => {
  web = await serveScale("wide", 300);
  await page.setViewportSize({ width: 1280, height: 800 });
  await page.goto(web.url);
  const cards = page.locator("article.circuit");
  await cards.first().waitFor();
  const first = await cards.count();
  expect(first).toBeGreaterThan(0);
  expect(first).toBeLessThan(300);
  await expect(cards.first()).toHaveAttribute("aria-posinset", "1");
  await expect(cards.first()).toHaveAttribute("aria-setsize", "300");
  // Keyboard: focus inside the last mounted cards mounts the next ones before Tab needs them.
  const last = cards.nth(first - 1).locator(".claim-head .tag-id .ref");
  await last.focus();
  await expect.poll(() => cards.count()).toBeGreaterThan(first);
  // Scrolling down the board mounts every card: its end comes near again and again.
  await expect
    .poll(
      async () => {
        await cards.last().scrollIntoViewIfNeeded();
        return cards.count();
      },
      { timeout: 60_000 },
    )
    .toBe(300);
  await expect(cards.last()).toHaveAttribute("aria-posinset", "300");
});

test("a request past 1 s shows that the page is working, until its answer", async ({ page }) => {
  web = await serveFvtrace();
  await page.goto(web.url);
  await card(page, "C3").waitFor();
  const { release } = await holdEvaluations(page);
  await card(page, "C2").getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.locator("body")).toHaveAttribute("aria-busy", "true");
  await expect(page.locator("#working")).toBeHidden();
  await expect(page.locator("#working")).toBeVisible({ timeout: 3000 });
  release();
  await expect(page.locator("#scenario-text")).toContainText("suppose O2 is verified");
  await expect(page.locator("#working")).toBeHidden();
  await expect(page.locator("body")).not.toHaveAttribute("aria-busy");
});

test("one evaluation at a time: A → B → A sends A twice, never B, and shows the last", async ({
  page,
}) => {
  web = await serveFvtrace();
  await page.goto(web.url);
  await card(page, "C3").waitFor();
  const { seen, release } = await holdEvaluations(page);
  const c2 = card(page, "C2");
  await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect.poll(() => seen.specs.length).toBe(1);
  await c2.getByRole("button", { name: "Suppose O3 checked" }).click();
  await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
  // The second waits behind the first and the third replaces it.
  expect(seen.specs).toEqual(["O2=checked"]);
  release();
  await expect.poll(() => seen.specs.length).toBe(2);
  release();
  await expect(page.locator("#scenario-text")).toContainText("suppose O2 is verified");
  await expect(page.locator("body")).not.toHaveAttribute("aria-busy");
  expect(seen.specs).toEqual(["O2=checked", "O2=checked"]);
  expect(seen.most).toBe(1);
});

test("details stay absent while pending; an older selection's answer is dropped", async ({
  page,
}) => {
  web = await serveFvtrace();
  await page.goto(web.url);
  await card(page, "C3").waitFor();
  /** @type {(() => void)[]} */
  const held = [];
  await page.route("**/api/answer", async (route) => {
    const body = route.request().postData() ?? "";
    if (body.includes('"details":"claim:C2"'))
      await new Promise((resolve) => held.push(() => resolve(undefined)));
    await route.continue();
  });
  await card(page, "C2").locator(".claim-head .tag-id .ref").click();
  await expect(page.locator("#inspector")).toHaveAttribute("aria-busy", "true");
  await expect(page.locator("#inspector")).not.toContainText("Run ");
  await card(page, "C1").locator(".claim-head .tag-id .ref").click();
  await expect(page.locator("#inspector")).not.toHaveAttribute("aria-busy");
  const shown = await page.locator("#inspector").textContent();
  held.splice(0).forEach((go) => go());
  await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 500)));
  expect(await page.locator("#inspector").textContent()).toBe(shown);
  await expect(page.locator("#inspector .claim-tag .tag-id")).toHaveText("C1");
});

test("the find route reaches a claim that is not mounted, selects it and focuses it", async ({
  page,
}) => {
  web = await serveScale("wide", 300);
  await page.goto(web.url);
  await page.locator("article.circuit").first().waitFor();
  await expect(card(page, "C290")).toHaveCount(0);
  await expect(page.locator("#find-results")).toBeHidden();
  await page.locator("#find").fill("C290");
  await expect(page.locator("#find-count")).toHaveText("1 match.");
  await page.locator("#find").press("Enter");
  await expect(card(page, "C290")).toHaveClass(/selected/);
  await expect(card(page, "C290").locator(".claim-head .tag-id .ref")).toBeFocused();
  await expect(page.locator("#inspector .claim-tag .tag-id")).toHaveText("C290");
  await expect(card(page, "C290")).toHaveAttribute("aria-posinset", "291");
  // Words find too; Escape clears the field and its matches.
  await page.locator("#find").fill("no such words anywhere");
  await expect(page.locator("#find-count")).toHaveText(
    "No claim, fact or experiment matches “no such words anywhere”.",
  );
  await page.locator("#find").press("Escape");
  await expect(page.locator("#find")).toHaveValue("");
  await expect(page.locator("#find-count")).toBeHidden();
});

test("a board the reader has scrolled past stays as it is; its end mounts more once in view", async ({
  page,
}) => {
  web = await serveScale("wide", 3000);
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.goto(web.url);
  const cards = page.locator("article.circuit");
  await cards.first().waitFor();
  await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 500)));
  const loaded = await cards.count();
  await page.locator("#experiments-heading").evaluate((el) => el.scrollIntoView());
  await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 1500)));
  expect(await cards.count()).toBe(loaded);
  await page.evaluate(() => window.scrollBy(0, -400));
  await expect.poll(() => cards.count()).toBeGreaterThan(loaded);
  await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 1500)));
  expect(await cards.count()).toBeLessThan(3000);
});
