// Selectors the e2e specs share: one place to follow a markup change.

/** A claim's diagram card. @param {import("@playwright/test").Page} page @param {string} id */
export const card = (page, id) =>
  page
    .locator("article.circuit")
    .filter({ has: page.locator(".tag-id").getByText(id, { exact: true }) });

/** A card's verdict words. @param {import("@playwright/test").Locator} c */
export const verdict = (c) => c.locator(".tag-soft .cap-trim");
