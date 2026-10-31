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
 * @param {import("@playwright/test").Browser} browser @param {string} [hash]
 * @param {string} [file] another exported page */
async function openOffline(browser, hash = "", file = fixture.page) {
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
  return { context, page, counts, errors, url: `${pathToFileURL(file).href}${hash}` };
}

/** Each claim's verdict as `fvtrace claims --whatif SPEC --json` words it.
 * @param {string} spec @param {{ project: string, env: NodeJS.ProcessEnv }} [study]
 * @returns {Map<string, string>} */
function nativeVerdicts(spec, { project, env } = fixture) {
  /** @type {unknown} */
  const out = JSON.parse(fvtrace(["claims", "--whatif", spec, "--json"], project, env));
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

test("a reviewed study's page runs a linked what-if", async ({ browser }) => {
  const study = await prepareStudy("synthetic");
  try {
    fvtrace(["review", "--reviewer", "A. Reviewer"], study.project, study.env);
    const file = join(study.dir, "reviewed.html");
    fvtrace(["export", "--html", file], study.project, study.env);
    const { context, page, counts, errors, url } = await openOffline(
      browser,
      "#whatif=O2%3Dchecked",
      file,
    );
    await page.goto(url);
    await expect(page.locator("#review")).toContainText("Reviewed by A. Reviewer on ");
    await expect(page.getByRole("status")).toHaveText(
      "Showing a what-if: suppose O2 is verified by a checker. Nothing has been recorded.",
    );
    await expect(page.locator("#error")).toBeHidden();
    await Promise.all(
      [...nativeVerdicts("O2=checked", study)].map(([id, words]) =>
        expect(verdict(card(page, id))).toHaveText(words),
      ),
    );
    expect(errors).toEqual([]);
    expect(counts.requests).toBe(0);
    await context.close();
  } finally {
    await rm(study.dir, { recursive: true, force: true });
  }
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
  // Engine only (user ruling): a detail section that needs the engine says so.
  await page.locator(".experiment-row").filter({ hasText: "Check the result" }).click();
  await expect(page.locator("#inspector")).toContainText(
    "This browser cannot run the what-ifs on this page, so it cannot show these details.",
  );
  await context.close();
});

/**
 * Plants faults between the page and its engine's Worker (the engine runs off the page's thread,
 * so the page's own `WebAssembly` never sees it): `delay` holds the start message back (and the
 * messages posted after it, which a worker takes in order), `trapAt`
 * answers that request with a failure instead of forwarding it, `corrupt` garbles the first
 * request's answer, `hold` delays every answer; the page reads the request count
 * (`fvtraceCalls`), the workers made (`fvtraceWorkers`) + a ready flag.
 * @param {import("@playwright/test").Page} page
 * @param {{ delay?: number, trapAt?: number, corrupt?: boolean, hold?: number }} opts
 */
async function plantWorker(page, { delay = 0, trapAt = 0, corrupt = false, hold = 0 }) {
  await page.addInitScript(([ms, trap, garble, held]) => {
    const Real = globalThis.Worker;
    let calls = 0;
    let workers = 0;
    Reflect.set(globalThis, "fvtraceCalls", () => calls);
    Reflect.set(globalThis, "fvtraceWorkers", () => workers);
    class Planted extends Real {
      /** @param {string | URL} url @param {WorkerOptions} [options] */
      constructor(url, options) {
        super(url, options);
        workers++;
        /** @type {((e: MessageEvent) => void) | null} */
        this.handler = null;
        /** @type {unknown} */
        this.startId = undefined;
        /** Messages posted while the start is held back, forwarded after it in order.
         * @type {unknown[] | undefined} */
        this.behind = undefined;
        let firstAnswer = true;
        super.addEventListener("message", (/** @type {MessageEvent} */ event) => {
          /** @type {unknown} */
          const data = event.data;
          if (typeof data !== "object" || data === null) return;
          /** @type {unknown} */
          const id = Reflect.get(data, "id");
          if (id === this.startId) Reflect.set(globalThis, "fvtraceReady", true);
          /** @type {unknown} */
          const value = Reflect.get(data, "value");
          if (garble && id !== this.startId && typeof value === "string" && firstAnswer) {
            firstAnswer = false;
            this.handler?.(
              new MessageEvent("message", { data: { id, value: `!${value.slice(1)}` } }),
            );
            return;
          }
          if (held && id !== this.startId) setTimeout(() => this.handler?.(event), held);
          else this.handler?.(event);
        });
      }
      /** The page's one message listener; the planted one above hands it each reply.
       * @param {string} type @param {EventListenerOrEventListenerObject} listener */
      addEventListener(type, listener) {
        if (type !== "message") return super.addEventListener(type, listener);
        if (typeof listener === "function") this.handler = (e) => listener(e);
      }
      /** @param {unknown} message */
      postMessage(message) {
        /** @type {unknown} */
        const op =
          typeof message === "object" && message !== null ? Reflect.get(message, "op") : undefined;
        /** @type {unknown} */
        const id =
          typeof message === "object" && message !== null ? Reflect.get(message, "id") : undefined;
        if (op === "start") {
          this.startId = id;
          this.behind = [];
          setTimeout(() => {
            super.postMessage(message, []);
            for (const m of this.behind ?? []) super.postMessage(m, []);
            this.behind = undefined;
          }, ms);
          return;
        }
        if (op === "request") {
          calls++;
          if (trap && calls >= trap) {
            setTimeout(
              () =>
                this.handler?.(
                  new MessageEvent("message", { data: { id, failed: "planted trap" } }),
                ),
              0,
            );
            return;
          }
        }
        if (this.behind) this.behind.push(message);
        else super.postMessage(message, []);
      }
    }
    Reflect.set(globalThis, "Worker", Planted);
  }, /** @type {[number, number, boolean, number]} */ ([delay, trapAt, corrupt, hold]));
}

test("the page's engine works in a Worker: a selection shows while it answers", async ({
  browser,
}) => {
  const { context, page, url } = await openOffline(browser);
  await plantWorker(page, { hold: 4000 });
  await page.goto(url);
  await page.waitForFunction(() => Reflect.get(globalThis, "fvtraceReady") === true);
  await card(page, "C2").getByRole("button", { name: "Suppose O2 checked" }).click();
  // The answer is held for 4 s; the page answers a selection meanwhile (user ruling: Worker).
  await card(page, "C1").locator(".tag-id").getByRole("button").click();
  await expect(page.locator("#inspector").getByRole("heading", { level: 2 })).toBeVisible({
    timeout: 1000,
  });
  const workers = await page.evaluate(() => {
    /** @type {unknown} */
    const count = Reflect.get(globalThis, "fvtraceWorkers");
    /** @type {unknown} */
    const n = typeof count === "function" ? Reflect.apply(count, undefined, []) : -1;
    return typeof n === "number" ? n : -1;
  });
  expect(workers).toBe(1);
  await context.close();
});

test("a details request that fails ends the engine: the facts as recorded + the notice", async ({
  browser,
}) => {
  const { context, page, url } = await openOffline(browser);
  // The second request (the selection's details) traps.
  await plantWorker(page, { trapAt: 2 });
  await page.goto(url);
  await card(page, "C2").getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.getByRole("status")).toContainText("suppose O2 is verified by a checker");
  await card(page, "C1").locator(".claim-head .tag-id").getByRole("button").click();
  await expect(page.locator("#error")).toHaveText(engineFailed);
  await expect(page.getByRole("status")).toContainText(recorded);
  await expect(page.locator("#inspector")).toContainText("cannot show these details");
  const calls = await page.evaluate(() => {
    /** @type {unknown} */
    const count = Reflect.get(globalThis, "fvtraceCalls");
    /** @type {unknown} */
    const n = typeof count === "function" ? Reflect.apply(count, undefined, []) : -1;
    return typeof n === "number" ? n : -1;
  });
  expect(calls).toBe(2);
  await context.close();
});

test("an engine that fails mid-session is never called again", async ({ browser }) => {
  const { context, page, url } = await openOffline(browser);
  // The second request traps: a stand-in for any failure inside the engine.
  await plantWorker(page, { trapAt: 2 });
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
  await plantWorker(page, { delay: ms, corrupt: corruptFirst });
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
  // The engine works off the page's thread: the count settles once the failure shows.
  await expect(page.locator("#error")).toHaveText(engineFailed);
  expect(await evaluations(page)).toBe(1);
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
  await writeFile(damaged, html.replace('"schema":"fvtrace.evaluation/2"', '"schema":"x"'));
  const { context, page } = await openOffline(browser);
  await page.goto(`${pathToFileURL(damaged).href}#action=suppose%3AO2`);
  await expect(page.locator("#error")).toContainText("This page is damaged");
  await context.close();
});

test("an exported page shows a replay notice, with or without its engine", async ({ browser }) => {
  const study = await prepareStudy("synthetic", (t) => {
    const facts = t["facts"];
    /** @type {unknown} */
    const o1 = Array.isArray(facts) ? facts.find((f) => isRecord(f) && f["id"] === "O1") : null;
    if (!isRecord(o1) || !isRecord(o1["evidence"])) throw new Error("no O1 evidence");
    o1["evidence"]["replay"] = {
      command: ["true"],
      failed: { date: "2026-10-31", reason: "output changed" },
    };
  });
  const file = join(study.dir, "notice.html");
  /** The recorded view carries the notice: the page's engine is not needed to show it. */
  const shows = async (/** @type {boolean} */ wasm) => {
    const { context, page, url } = await openOffline(browser, "", file);
    if (!wasm)
      await page.addInitScript(() => {
        Object.defineProperty(globalThis, "WebAssembly", { value: undefined });
      });
    await page.goto(url);
    await expect(page.locator("#replays")).toHaveText(
      "O1's check was run again and failed. Open O1 to see when and why.",
    );
    await page.locator("#replays").getByRole("button", { name: "O1" }).click();
    await expect(page.locator("#inspector")).toContainText(
      "Its check was run again on 2026-10-31 and failed: its output changed since it was pinned.",
    );
    await context.close();
  };
  try {
    fvtrace(["export", "--html", file], study.project, study.env);
    await Promise.all([shows(true), shows(false)]);
  } finally {
    await rm(study.dir, { recursive: true, force: true });
  }
});
