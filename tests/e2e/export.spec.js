// The exported page (`fvtrace export --html`, `.agent/contracts/kernel.md` E-page + E-gui): opened
// from file:// with the network off, its engine (WebAssembly) evaluates stacked what-ifs whose
// verdicts equal `fvtrace claims --whatif`; a browser that cannot run the engine keeps the
// recorded view and says why.
import { test, expect } from "@playwright/test";
import { AxeBuilder } from "@axe-core/playwright";
import { readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { fvtrace, isRecord, prepareStudy } from "./fvtrace-server.js";

/** @type {{ dir: string, page: string, project: string, env: NodeJS.ProcessEnv }} */
let fixture;

test.beforeAll(async () => {
  const { dir, project, env } = await prepareStudy("synthetic");
  const page = join(dir, "claims.html");
  fvtrace(["export", "--html", page], project, env);
  fixture = { dir, page, project, env };
});

test.afterAll(async () => {
  await rm(fixture.dir, { recursive: true, force: true });
});

const recorded = "Showing the facts as recorded.";
const engineFailed =
  "This browser cannot run the what-ifs on this page, so it shows the facts as recorded.";

/** @param {import("@playwright/test").Page} page @param {string} id */
const card = (page, id) =>
  page
    .locator("article.circuit")
    .filter({ has: page.locator(".tag-id").getByText(id, { exact: true }) });

/** @param {import("@playwright/test").Locator} c */
const verdict = (c) => c.locator(".tag-soft .cap-trim");

/** The page in a context with the network off; every non-file request is refused + counted.
 * @param {import("@playwright/test").Browser} browser @param {string} [hash] */
async function openOffline(browser, hash = "") {
  const context = await browser.newContext({ offline: true });
  const counts = { requests: 0 };
  await context.route("**/*", (route) => {
    if (route.request().url().startsWith("file:")) return route.continue();
    counts.requests++;
    return route.abort();
  });
  const page = await context.newPage();
  /** @type {string[]} */
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(err.message));
  return { context, page, counts, errors, url: `${pathToFileURL(fixture.page).href}${hash}` };
}

/** Each claim's verdict as `fvtrace claims --whatif SPEC --json` words it.
 * @param {string} spec @returns {Map<string, string>} */
function nativeVerdicts(spec) {
  /** @type {unknown} */
  const out = JSON.parse(
    fvtrace(["claims", "--whatif", spec, "--json"], fixture.project, fixture.env),
  );
  const claims = isRecord(out) && Array.isArray(out["claims"]) ? out["claims"] : [];
  return new Map(
    claims.flatMap((c) =>
      isRecord(c) && isRecord(c["label"]) && typeof c["id"] === "string"
        ? [[c["id"], String(c["label"]["verdict"])]]
        : [],
    ),
  );
}

test("offline from file://, the page's engine stacks a two-fact what-if as fvtrace claims does", async ({
  browser,
}) => {
  const { context, page, counts, errors, url } = await openOffline(browser);
  await page.goto(url);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Synthetic study");
  await expect(page.locator("#export-note")).toHaveText(
    "This page was exported. It shows the evidence as it was at export, and its what-ifs run in your browser.",
  );
  const c2 = card(page, "C2");
  await expect(verdict(c2)).toHaveText("Pending verification");
  await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.getByRole("status")).toHaveText(
    "Showing a what-if: suppose O2 is verified by a checker. Nothing has been recorded.",
  );
  await c2.getByRole("button", { name: "Suppose EN2 proved" }).click();
  await expect(page.getByRole("status")).toHaveText(
    "Showing a what-if: suppose EN2 is proved, O2 is verified by a checker. Nothing has been recorded.",
  );
  expect(new URL(page.url()).hash).toContain("whatif=EN2%3Dproved%2CO2%3Dchecked");
  const native = nativeVerdicts("O2=checked,EN2=proved");
  expect(native.size).toBeGreaterThan(0);
  await Promise.all(
    [...native].map(([id, words]) => expect(verdict(card(page, id))).toHaveText(words)),
  );
  await c2.getByRole("button", { name: "Restore the recorded status of O2" }).click();
  await expect(page.getByRole("status")).toHaveText(
    "Showing a what-if: suppose EN2 is proved. Nothing has been recorded.",
  );
  await page.getByRole("button", { name: "Show the facts as recorded" }).click();
  await expect(page.getByRole("status")).toContainText(recorded);
  await expect(verdict(c2)).toHaveText("Pending verification");
  const axe = await new AxeBuilder({ page }).analyze();
  expect(axe.violations.map((v) => v.id)).toEqual([]);
  expect(errors).toEqual([]);
  expect(counts.requests).toBe(0);
  await context.close();
});

test("a linked what-if goes to the page's engine as written", async ({ browser }) => {
  const { context, page, url } = await openOffline(browser, "#whatif=O3%3Dchecked%2CO2%3Dchecked");
  await page.goto(url);
  await expect(page.getByRole("status")).toHaveText(
    "Showing a what-if: suppose O2 is verified by a checker, O3 is verified by a checker. Nothing has been recorded.",
  );
  await Promise.all(
    [...nativeVerdicts("O3=checked,O2=checked")].map(([id, words]) =>
      expect(verdict(card(page, id))).toHaveText(words),
    ),
  );
  await page.goto(`${pathToFileURL(fixture.page).href}#whatif=O2%3Dassumed`);
  await expect(page.locator("#error")).toHaveText(
    "O2 cannot be assumed: facts of its kind must be verified. This page shows the facts as recorded instead.",
  );
  await expect(page.getByRole("status")).toContainText(recorded);
  expect(new URL(page.url()).hash).not.toContain("whatif=");
  await page.goto(`${pathToFileURL(fixture.page).href}#whatif=O9%3Dchecked`);
  await expect(page.locator("#error")).toHaveText(
    '"O9" is not a fact on record. This page shows the facts as recorded instead.',
  );
  await context.close();
});

test("an older export's action link becomes its what-if; an unknown one says so", async ({
  browser,
}) => {
  const { context, page, url } = await openOffline(browser, "#action=suppose%3AO2");
  await page.goto(url);
  await expect(page.getByRole("status")).toHaveText(
    "Showing a what-if: suppose O2 is verified by a checker. Nothing has been recorded.",
  );
  expect(new URL(page.url()).hash).toBe("#whatif=O2%3Dchecked");
  await page.goto(`${pathToFileURL(fixture.page).href}#action=suppose%3AZZ`);
  await expect(page.locator("#error")).toHaveText(
    'This page holds no what-if "suppose:ZZ", so it shows the facts as recorded.',
  );
  await expect(page.getByRole("status")).toContainText(recorded);
  await context.close();
});

test("without WebAssembly the page keeps the recorded view and says why", async ({ browser }) => {
  const { context, page, url } = await openOffline(browser);
  await page.addInitScript(() => {
    Object.defineProperty(globalThis, "WebAssembly", { value: undefined });
  });
  await page.goto(url);
  const c2 = card(page, "C2");
  await expect(verdict(c2)).toHaveText("Pending verification");
  await expect(page.locator("#error")).toHaveText(engineFailed);
  await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.getByRole("status")).toContainText(recorded);
  await expect(page.locator("#error")).toHaveText(engineFailed);
  await context.close();
});

test("an engine that fails mid-session is never called again", async ({ browser }) => {
  const { context, page, url } = await openOffline(browser);
  // The second evaluation traps: a stand-in for any failure inside the engine.
  await page.addInitScript(() => {
    const real = WebAssembly.instantiate.bind(WebAssembly);
    let calls = 0;
    Reflect.set(globalThis, "fvtraceCalls", () => calls);
    Reflect.set(
      WebAssembly,
      "instantiate",
      async (/** @type {BufferSource} */ bytes, /** @type {WebAssembly.Imports} */ imports) => {
        const { module, instance } = await real(bytes, imports);
        /** @type {Record<string, WebAssembly.ExportValue>} */
        const exports = { ...instance.exports };
        const evaluate = exports["fvtrace_evaluate"];
        exports["fvtrace_evaluate"] = (/** @type {number[]} */ ...args) => {
          calls++;
          if (calls > 1) throw new WebAssembly.RuntimeError("planted trap");
          /** @type {unknown} */
          const out = typeof evaluate === "function" ? Reflect.apply(evaluate, undefined, args) : 0;
          return typeof out === "number" ? out : 0;
        };
        return { module, instance: { exports } };
      },
    );
  });
  await page.goto(url);
  const c2 = card(page, "C2");
  await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.getByRole("status")).toContainText("suppose O2 is verified by a checker");
  await c2.getByRole("button", { name: "Suppose EN2 proved" }).click();
  await expect(page.locator("#error")).toHaveText(engineFailed);
  await expect(page.getByRole("status")).toContainText(recorded);
  await c2.getByRole("button", { name: "Suppose O3 checked" }).click();
  await expect(page.locator("#error")).toHaveText(engineFailed);
  const calls = await page.evaluate(() => {
    /** @type {unknown} */
    const count = Reflect.get(globalThis, "fvtraceCalls");
    if (typeof count !== "function") return -1;
    /** @type {unknown} */
    const n = Reflect.apply(count, undefined, []);
    return typeof n === "number" ? n : -1;
  });
  expect(calls).toBe(2);
  await context.close();
});

/** A slow engine start (`ms`), a ready flag + an evaluation counter on the page; `corruptFirst`
 * garbles the first answer's bytes (no trap: only the page's validation catches it).
 * @param {import("@playwright/test").Page} page
 * @param {{ ms?: number, corruptFirst?: boolean }} [opts] */
async function slowEngine(page, { ms = 1500, corruptFirst = false } = {}) {
  await page.addInitScript(([delay, corrupt]) => {
    const real = WebAssembly.instantiate.bind(WebAssembly);
    let calls = 0;
    Reflect.set(globalThis, "fvtraceCalls", () => calls);
    Reflect.set(
      WebAssembly,
      "instantiate",
      async (/** @type {BufferSource} */ bytes, /** @type {WebAssembly.Imports} */ imports) => {
        await new Promise((resolve) => setTimeout(resolve, delay));
        const { module, instance } = await real(bytes, imports);
        /** @type {Record<string, WebAssembly.ExportValue>} */
        const exports = { ...instance.exports };
        const evaluate = exports["fvtrace_evaluate"];
        exports["fvtrace_evaluate"] = (/** @type {number[]} */ ...args) => {
          calls++;
          /** @type {unknown} */
          const out = typeof evaluate === "function" ? Reflect.apply(evaluate, undefined, args) : 0;
          const at = typeof out === "number" ? out : 0;
          const memory = exports["memory"];
          if (corrupt && calls === 1 && at !== 0 && memory instanceof WebAssembly.Memory)
            new Uint8Array(memory.buffer, at, 1).set([0x21]);
          return at;
        };
        Reflect.set(globalThis, "fvtraceReady", true);
        return { module, instance: { exports } };
      },
    );
  }, /** @type {[number, boolean]} */ ([ms, corruptFirst]));
}

/** Waits until the slow engine has started, then for queued answers to settle. @param {import("@playwright/test").Page} page */
async function engineStarted(page) {
  await page.waitForFunction(() => Reflect.get(globalThis, "fvtraceReady") === true, null, {
    timeout: 60_000,
  });
  await page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 100)));
}

/** @param {import("@playwright/test").Page} page */
const evaluations = (page) =>
  page.evaluate(() => {
    /** @type {unknown} */
    const count = Reflect.get(globalThis, "fvtraceCalls");
    /** @type {unknown} */
    const n = typeof count === "function" ? Reflect.apply(count, undefined, []) : -1;
    return typeof n === "number" ? n : -1;
  });

test("while the engine starts, a later view wins over an earlier what-if", async ({ browser }) => {
  const { context, page, url } = await openOffline(browser);
  await slowEngine(page, { ms: 3000 });
  await page.goto(url);
  await card(page, "C2").getByRole("button", { name: "Suppose O2 checked" }).click();
  expect(new URL(page.url()).hash).toContain("whatif=O2%3Dchecked");
  await page.goBack();
  await expect(page.getByRole("status")).toContainText(recorded);
  await engineStarted(page);
  await expect(page.getByRole("status")).toContainText(recorded);
  expect(new URL(page.url()).hash).not.toContain("whatif=");
  expect(await page.evaluate(() => document.body.hasAttribute("aria-busy"))).toBe(false);
  await context.close();
});

test("a failure ends the engine before a queued what-if enters it", async ({ browser }) => {
  const { context, page, url } = await openOffline(browser);
  await slowEngine(page, { ms: 3000, corruptFirst: true });
  await page.goto(url);
  const c2 = card(page, "C2");
  await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
  await c2.getByRole("button", { name: "Suppose O3 checked" }).click();
  await engineStarted(page);
  expect(await evaluations(page)).toBe(1);
  await expect(page.locator("#error")).toHaveText(engineFailed);
  await expect(page.getByRole("status")).toContainText(recorded);
  await context.close();
});

test("a linked what-if paints the recorded view first", async ({ browser }) => {
  const { context, page, url } = await openOffline(browser, "#whatif=O2%3Dchecked");
  await slowEngine(page, { ms: 3000 });
  await page.goto(url);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Synthetic study");
  await expect(page.getByRole("status")).toContainText(recorded);
  await engineStarted(page);
  await expect(page.getByRole("status")).toContainText("suppose O2 is verified by a checker");
  await context.close();
});

test("an explicit what-if, even empty, wins over an older action link", async ({ browser }) => {
  const { context, page, url } = await openOffline(browser, "#whatif=&action=suppose%3AO2");
  await page.goto(url);
  await expect(page.getByRole("status")).toContainText(recorded);
  await expect(page.locator("#error")).toBeHidden();
  await context.close();
});

test("a damaged recorded view says so, also behind an older action link", async ({ browser }) => {
  const damaged = join(fixture.dir, "damaged.html");
  const html = await readFile(fixture.page, "utf8");
  await writeFile(damaged, html.replace('"schema":"fvtrace.evaluation/1"', '"schema":"x"'));
  const { context, page } = await openOffline(browser);
  await page.goto(`${pathToFileURL(damaged).href}#action=suppose%3AO2`);
  await expect(page.locator("#error")).toContainText("This page is damaged");
  await context.close();
});
