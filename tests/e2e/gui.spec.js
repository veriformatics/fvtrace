import { test, expect } from "@playwright/test";
import { isRecord, serveFvtrace } from "./fvtrace-server.js";

/** @type {Awaited<ReturnType<typeof serveFvtrace>>} */
let web;
test.afterEach(async () => {
  await web.close();
});

/** @param {import("@playwright/test").Page} page @param {string} id */
function card(page, id) {
  return page
    .locator("article.circuit")
    .filter({ has: page.locator(".tag-id").getByText(id, { exact: true }) });
}

/** @param {import("@playwright/test").Locator} c */
const verdict = (c) => c.locator(".tag-soft .cap-trim");

/**
 * Presses `key` `n` times, one press after another (each waits for the page to take the last).
 * @param {import("@playwright/test").Page} page @param {string} key @param {number} n
 * @returns {Promise<void>}
 */
async function pressTimes(page, key, n) {
  if (n <= 0) return;
  await page.keyboard.press(key);
  await pressTimes(page, key, n - 1);
}

const c2Exact =
  "If the treatment did nothing, a difference this large would arise by chance in fewer than 1 " +
  "in 20 random assignments.";

test.describe("the synthetic study", () => {
  test.beforeEach(async () => {
    web = await serveFvtrace();
  });

  test("the recorded view shows the engine's verdicts, headlines and reasons", async ({ page }) => {
    await page.goto(web.url);
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("Synthetic study");
    await expect(page.locator("#review")).toHaveText("Not reviewed yet.");
    await expect(page.getByRole("status")).toHaveText(
      "Showing the facts as recorded. Press a fact's symbol to see what would change if it were verified.",
    );
    const key = page.locator(".key-pairs");
    await expect(key.locator("tbody tr")).toHaveCount(4);
    await expect(key.locator("tbody tr").nth(1)).toContainText("Assumed");
    await expect(key.locator("tbody tr").nth(1)).toContainText("1Conditional");
    await expect(key.locator("tbody tr").nth(2)).toContainText("1Pending verification");
    // The question bar shows for one question too (user ruling).
    await expect(page.locator("#questions")).toContainText("Effect3 claims");
    const c1 = card(page, "C1");
    await expect(c1.locator(".tag-kind")).toHaveText("Measurement");
    await expect(verdict(c1)).toHaveText("Conditional");
    await expect(c1.locator(".sentence")).toHaveText(
      "The difference between treated and control samples measures the average effect of the treatment.",
    );
    await expect(c1.locator(".conditions-label")).toHaveText(["Holds only if"]);
    await expect(c1.locator(".conditions")).toContainText(
      "Why it is needed: Otherwise another difference between the groups could explain the result.",
    );
    await c1.getByText("Show the exact statement").click();
    await expect(c1.locator("details.exact p")).toHaveText(
      "On average over all fair random assignments, the difference between treated and control samples equals the treatment's average effect on these samples.",
    );
    const c2 = card(page, "C2");
    await expect(verdict(c2)).toHaveText("Pending verification");
    await expect(c2.locator(".conditions-label")).toHaveText(["Still open", "Also assumes"]);
    // A restating claim has no reasoning fact in its diagram.
    const c3 = card(page, "C3");
    await expect(c3.locator(".tag-qualifier")).toHaveText("if Collect a new cohort runs");
    await expect(c3.locator(".contact")).toHaveCount(1);
    await expect(c3.locator(".contact")).toContainText("M1");
  });

  test("a fact's symbol supposes it; the engine answers; the address keeps it", async ({
    page,
  }) => {
    await page.goto(web.url);
    const c2 = card(page, "C2");
    await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
    await expect(page.getByRole("status")).toHaveText(
      "Showing a what-if: suppose O2 is verified by a checker. Nothing has been recorded.",
    );
    await expect(verdict(c2)).toHaveText("Pending verification");
    await expect(c2.locator(".tag-qualifier")).toHaveText("what-if");
    await c2.getByRole("button", { name: "Suppose O3 checked" }).click();
    await c2.getByRole("button", { name: "Suppose EN2 proved" }).click();
    await expect(verdict(c2)).toHaveText("Conditional");
    expect(new URL(page.url()).hash).toContain("whatif=");
    await page.reload();
    await expect(verdict(card(page, "C2"))).toHaveText("Conditional");
    await card(page, "C2")
      .getByRole("button", { name: "Restore the recorded status of O2" })
      .click();
    await expect(verdict(card(page, "C2"))).toHaveText("Pending verification");
    await page.getByRole("button", { name: "Show the facts as recorded" }).click();
    await expect(page.getByRole("status")).toContainText("Showing the facts as recorded.");
    await expect(card(page, "C2").locator(".tag-qualifier")).toHaveCount(0);
  });

  test("a linked what-if goes to the engine as written", async ({ page }) => {
    await page.goto(`${web.url}#whatif=O2%3Dchecked%2CO2%3Dviolated`);
    await expect(page.locator("#error")).toHaveText(
      "O2 appears twice in the what-if. This page shows the facts as recorded instead.",
    );
    await expect(page.getByRole("status")).toContainText("Showing the facts as recorded.");
    expect(new URL(page.url()).hash).not.toContain("whatif=");
    await page.goto("about:blank");
    await page.goto(`${web.url}#whatif=O2%3Dassumed`);
    await expect(page.locator("#error")).toHaveText(
      "O2 cannot be assumed: facts of kind result must be verified. This page shows the facts as recorded instead.",
    );
  });

  test("details: a fact, a claim with its waived check + plan, an experiment", async ({ page }) => {
    await page.goto(web.url);
    const inspector = page.locator("#inspector");
    await card(page, "C2").locator(".contact-label").filter({ hasText: "O2" }).click();
    await expect(inspector.getByRole("heading", { level: 2 })).toHaveText(
      "Treated samples have a higher average marker level, and chance alone rarely gives a difference this large.",
    );
    await expect(inspector).toContainText(
      "Why it is needed: The claim says chance rarely gives this difference, so the data must show it.",
    );
    await expect(inspector).toContainText("Proved checker on the actual data");
    await card(page, "C2").locator(".tag-id").getByRole("button").click();
    await expect(inspector.getByRole("heading", { level: 2 })).toHaveText(
      "Treated samples show a rise that chance alone rarely produces.",
    );
    await expect(inspector).toContainText(`Exact statement: ${c2Exact}`);
    // A waived check sits in its claim's details, not under "What may be missing" (user ruling).
    await expect(inspector).toContainText(
      "Not needed: a statistics fact. Reason: The test counts every possible split of the samples, so it needs no statistical model.",
    );
    await expect(page.locator("#checks")).toBeHidden();
    await expect(inspector).toContainText(
      "Run E1, E4. If the plan succeeds, the claim reads Conditional.",
    );
    await inspector.getByRole("button", { name: "Suppose the plan succeeds" }).click();
    await expect(verdict(card(page, "C2"))).toHaveText("Conditional");
    await page.getByRole("button", { name: "Show the facts as recorded" }).click();
    await page.locator(".experiment-row").filter({ hasText: "Check the result" }).click();
    await expect(inspector.getByRole("heading", { level: 2 })).toHaveText("Check the result");
    await expect(inspector).toContainText("If it succeeds and the result is observed");
    await expect(inspector).toContainText(
      "C2 changes from Pending verification to Claim not possible",
    );
  });

  test("work rows count only above 0 and name what else a claim needs", async ({ page }) => {
    await page.goto(web.url);
    const rows = page.locator(".work-item");
    await expect(rows.filter({ hasText: "M1" })).toContainText("Makes 1 claim available alone.");
    const o2 = page.locator('.work-item:has([data-key="work:O2"])');
    await expect(o2.locator(".list-meta")).toHaveText("Needed by C2, together with O3 and EN2.");
    await expect(o2.locator(".work-count")).toBeHidden();
    // A blocked claim still names what it needs with the row's fact.
    await page.goto(`${web.url}#whatif=O1%3Dviolated`);
    await expect(o2.locator(".list-meta")).toHaveText(
      "Needed by C2, together with O3 and EN2, but C2 is not possible as worded.",
    );
  });

  test("the text view lists headlines and the facts to verify", async ({ page }) => {
    await page.goto(web.url);
    await page.getByRole("button", { name: "Text", exact: true }).click();
    await expect(page.locator(".text-list").first()).toContainText(
      "Treated samples show a rise that chance alone rarely produces.",
    );
    await expect(page.getByRole("heading", { name: /Facts to verify/ })).toBeVisible();
    expect(new URL(page.url()).hash).toContain("view=text");
  });

  test("the tour walks the page by keyboard and hands focus back", async ({ page }) => {
    await page.goto(web.url);
    await page.locator("article.circuit").first().waitFor();
    const opener = page.locator("#tour-start");
    await opener.click();
    const tour = page.getByRole("dialog");
    await expect(tour.getByRole("heading", { level: 2 })).toHaveText("Welcome to fvTrace");
    const total = Number(
      /of (\d+)/.exec((await tour.locator(".tour-count").textContent()) ?? "")?.[1],
    );
    expect(total).toBe(13);
    await page.keyboard.press("ArrowRight");
    await expect(tour.locator(".tour-count")).toHaveText(`2 of ${total}`);
    // The what-if step spotlights a diagram button a reader can press, not an inert mark.
    await pressTimes(page, "ArrowRight", 5);
    await expect(tour.getByRole("heading", { level: 2 })).toHaveText("Ask “what if?”");
    await page.waitForFunction(() => {
      const spot = document.querySelector(".tour-spot")?.getBoundingClientRect();
      const button = document
        .querySelector('.contacts button.switch:not([aria-disabled="true"])')
        ?.getBoundingClientRect();
      if (!spot || !button) return false;
      const x = button.x + button.width / 2;
      const y = button.y + button.height / 2;
      return x > spot.left && x < spot.right && y > spot.top && y < spot.bottom;
    });
    await pressTimes(page, "ArrowRight", total - 7);
    await expect(tour.locator(".tour-count")).toHaveText(`${total} of ${total}`);
    await expect(tour.getByRole("heading", { level: 2 })).toHaveText("End of the tour");
    await page.keyboard.press("ArrowLeft");
    await expect(tour.locator(".tour-count")).toHaveText(`${total - 1} of ${total}`);
    await page.keyboard.press("Escape");
    await expect(tour).toHaveCount(0);
    await expect(opener).toBeFocused();
  });

  test("on a phone every tour card docks at the bottom", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(web.url);
    await page.locator("article.circuit").first().waitFor();
    await page.locator("#tour-start").click();
    const dialog = page.getByRole("dialog");
    await expect(dialog.getByRole("heading", { level: 2 })).toHaveText("Welcome to fvTrace");
    const box = await dialog.boundingBox();
    expect(box && box.y + box.height).toBeGreaterThan(844 - 16);
  });

  test("a claim's words select for copying; a plain click opens its details", async ({ page }) => {
    await page.goto(web.url);
    const words = card(page, "C1").locator(".sentence");
    const box = await words.boundingBox();
    if (!box) throw new Error("no headline box");
    await page.mouse.move(box.x + 2, box.y + box.height / 4);
    await page.mouse.down();
    await page.mouse.move(box.x + box.width - 2, box.y + box.height / 4, { steps: 8 });
    await page.mouse.up();
    expect(
      await page.evaluate(() => document.getSelection()?.toString().length ?? 0),
    ).toBeGreaterThan(10);
    const inspector = page.locator("#inspector");
    await expect(inspector.getByRole("heading", { level: 2 })).toHaveText(
      "Select a claim, a fact or an experiment",
    );
    await page.evaluate(() => document.getSelection()?.removeAllRanges());
    await words.click();
    await expect(inspector.getByRole("heading", { level: 2 })).toHaveText(
      "The difference between treated and control samples measures the average effect of the treatment.",
    );
  });

  test("reduced motion: no transition or animation runs", async ({ browser }) => {
    const context = await browser.newContext({ reducedMotion: "reduce" });
    const page = await context.newPage();
    await page.goto(web.url);
    await page.locator("article.circuit").first().waitFor();
    await page.locator("#tour-start").click();
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
});

test.describe("the feature fixture", () => {
  test("a conflicting what-if makes every claim on its subject not possible", async ({ page }) => {
    web = await serveFvtrace("fixture");
    await page.goto(`${web.url}#whatif=O4%3Dassumed%2CO5%3Dassumed`);
    const c1 = card(page, "C1");
    await expect(verdict(c1)).toHaveText("Claim not possible");
    await expect(c1.locator(".tag-qualifier")).toHaveText("what-if, conflicting what-if");
    // The card names the cause: no fact is false, the what-if supposes both sides (user ruling).
    await expect(c1.locator(".conditions-label").first()).toHaveText("Cannot stand because");
    await expect(c1.locator(".conditions-list").first()).toContainText(
      "X1An animal cannot be sampled once and twice.The what-if supposes O4 and O5, which exclude each other.",
    );
    await expect(page.locator(".how-note")).toHaveText(
      "A claim is also not possible when two facts exclude each other: when it needs both, or when a what-if supposes both.",
    );
    await expect(verdict(card(page, "C3"))).toHaveText("Pending verification");
  });

  test("a claim that needs both sides of an exclusion names it as its reason", async ({ page }) => {
    web = await serveFvtrace("fixture", (t) => {
      const facts = t["facts"];
      const claims = t["claims"];
      if (Array.isArray(facts) && Array.isArray(claims)) {
        facts.push({
          id: "EN9",
          subject: "S",
          kind: "entailment",
          text: "O4 and O5 entail C9.",
          status: "open",
          route: "lean",
        });
        claims.push({
          id: "C9",
          question: "Q1",
          subject: "S",
          level: "descriptive",
          text: "Both samplings hold.",
          needs: ["O4", "O5"],
          entailment: "EN9",
        });
      }
    });
    await page.goto(web.url);
    const c9 = card(page, "C9");
    await expect(verdict(c9)).toHaveText("Claim not possible");
    await expect(c9.locator(".conditions-label").first()).toHaveText("Cannot stand because");
    await expect(c9.locator(".conditions-list").first()).toContainText(
      "C9 needs O4 and O5, which exclude each other.",
    );
  });

  test("a plan names a violated need apart from the facts at their route's ceiling", async ({
    page,
  }) => {
    web = await serveFvtrace("fixture");
    await page.goto(`${web.url}#whatif=O1%3Dviolated`);
    await card(page, "C1").locator(".tag-id").click();
    const notes = page.locator("#inspector .note");
    await expect(notes.filter({ hasText: "Violated:" })).toHaveText(
      "Violated: O1. Reword the claim, or collect new data.",
    );
    await expect(notes.filter({ hasText: "Stays as it is:" })).toHaveText(
      "Stays as it is: O3 (no route allows a stronger status).",
    );
  });

  test("a violated fact lists apart with the claims it blocks", async ({ page }) => {
    web = await serveFvtrace("fixture");
    await page.goto(`${web.url}#whatif=O2%3Dviolated`);
    await expect(page.locator("#blockers")).toBeVisible();
    await expect(page.locator("#blocker-list")).toContainText(
      "O2 The marker rises in treated samples.",
    );
    await expect(page.locator("#blocker-list")).toContainText("Blocks C2.");
    await expect(card(page, "C2").locator(".conditions-label").first()).toHaveText(
      "Cannot stand because",
    );
  });

  test("an unwaived check shows under What may be missing", async ({ page }) => {
    // A release-level claim without a release fact draws L-release, with no waiver for it.
    web = await serveFvtrace("fixture", (t) => {
      const claims = t["claims"];
      const first = Array.isArray(claims) ? /** @type {unknown} */ (claims[0]) : undefined;
      if (isRecord(first)) first["level"] = "release";
    });
    await page.goto(web.url);
    await expect(page.locator("#checks")).toBeVisible();
    await expect(page.locator("#check-list")).toContainText(
      "C1 concerns publication but needs no release fact",
    );
  });
});
