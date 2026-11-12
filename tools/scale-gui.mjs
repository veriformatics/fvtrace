// The GUI's response times (`.agent/contracts/kernel.md` U-time) on one generated trace, served
// (`fvtrace serve`) + exported (`fvtrace export --html`), in Playwright's bundled Chromium. Each
// interval runs from the input event's time stamp (the first view: the navigation's start) to the
// frame painted once the change shows; CSS selectors only (role queries cost seconds on a large
// page).
//   node tools/scale-gui.mjs <fvtrace binary> <trace dir> <page.html>
// The trace dir is tools/scale.mjs's (trace.json, project/, whatif.txt when the shape has one).
// Rows on stdout: `<step> <rc> <wall s> - <live JS KiB> 0 <bound s>`, rc 1 = the change never
// showed within 60 s or the page failed. Steps per mode (`served`, `page`): `first` (navigation →
// the board painted), `select` (a click on the first card's id → its highlight + summary),
// `details` (a click on the second card's id → its details, the view already held), `busy` (a click
// on the first card's first symbol → the busy state), `whatif` (→ its answer), `experiment` (a click
// on the first experiment row's id → its details, the view already held; shapes with experiments);
// exported also `startup` (the symbol clicked as soon as the board shows, the engine still
// starting → its answer). Served `first` navigates the moment the server prints its link, the
// browser + page made before the spawn. `SCALE_GUI_PHASES=<file>` appends that view's phases
// (`phases`).
import { appendFileSync, existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { pathToFileURL } from "node:url";
import { chromium } from "@playwright/test";
import { serve } from "./serve-link.mjs";

const [bin, dir, page] = process.argv.slice(2);
if (!bin || !dir || !page) {
  process.stderr.write("usage: node tools/scale-gui.mjs <fvtrace> <trace dir> <page.html>\n");
  process.exit(2);
}
/** How long a step may wait for its change before it counts as failed. */
const patience = 60000;
const whatifFile = join(dir, "whatif.txt");
const whatif = existsSync(whatifFile) ? readFileSync(whatifFile, "utf8").trim() : "";
const hash = whatif ? `whatif=${encodeURIComponent(whatif)}` : "";
const cardId = "article.circuit .claim-head .tag-id .ref";
// Any enabled what-if switch: "Suppose …" on the recorded view, "Restore …" under the whatif
// shape's what-if (every fact supposed there).
const symbol = 'article.circuit button.switch:not([aria-disabled="true"])';
const experimentId = ".experiment-meta .ref";

/** A row; `bytes` undefined = the memory reading failed, which fails the row (a zero would drop it
 * from the memory ratios). @param {string} step @param {number | undefined} ms
 * @param {number} bound @param {number | undefined} bytes */
function row(step, ms, bound, bytes) {
  const wall = ms === undefined ? "timeout" : (ms / 1000).toFixed(3);
  const rc = ms === undefined || bytes === undefined ? 1 : 0;
  process.stdout.write(`${step} ${rc} ${wall} - ${Math.round((bytes ?? 0) / 1024)} 0 ${bound}\n`);
}

/**
 * What a step waits for: the inspector showing a claim (`shown`), its details too (`ready`), an
 * experiment with its details (`experiment`), the busy state (`busy`), a what-if's answer
 * (`answered`).
 * @typedef {{ kind: "shown", id: string } | { kind: "ready", id: string }
 *   | { kind: "experiment", id: string } | { kind: "busy" } | { kind: "answered" }} Wait
 */

/**
 * Times the next click: from its time stamp to the frame after each wait in `waits` holds.
 * @param {import("@playwright/test").Page} p @param {Wait[]} waits @param {() => Promise<void>} click
 * @returns {Promise<(number | undefined)[]>}
 */
async function timed(p, waits, click) {
  const result = p.evaluate(([ws, wait]) => {
    /** The scenario line when the click came: an answer shows a different one. */
    let before = "";
    let detailsRequested = false;
    /** @param {number} i */
    const holds = (i) => {
      const w = ws[i];
      if (!w) return true;
      if (w.kind === "busy") return document.body.hasAttribute("aria-busy");
      // The click's own answer: the shown what-if changed (a view shown before the click, or the
      // engine still busy, is no answer).
      if (w.kind === "answered")
        return (
          (document.querySelector("#scenario-text")?.textContent ?? "") !== before &&
          !document.body.hasAttribute("aria-busy")
        );
      // Details count once the engine's answer shows (`data-details`: a refused or failed request
      // leaves the inspector idle too).
      const ready =
        detailsRequested &&
        document.querySelector("#inspector")?.getAttribute("data-details") === "ready";
      if (w.kind === "experiment")
        return (
          document.querySelector("#inspector .reference")?.textContent === `Experiment ${w.id}` &&
          ready
        );
      const tag = document.querySelector("#inspector .claim-tag .tag-id")?.textContent;
      if (tag !== w.id) return false;
      return w.kind === "shown" || ready;
    };
    return new Promise(
      /** @param {(at: (number | undefined)[]) => void} resolve */ (resolve) => {
        document.addEventListener(
          "click",
          (ev) => {
            const t0 = ev.timeStamp;
            before = document.querySelector("#scenario-text")?.textContent ?? "";
            /** @type {(number | undefined)[]} */
            const at = ws.map(() => undefined);
            // A reselected item may already be ready at capture time. Observe the click's own
            // pending → ready transition, including one completed between animation frames.
            const inspector = document.querySelector("#inspector");
            const observer = new MutationObserver((records) => {
              detailsRequested ||=
                records.some((r) => r.oldValue === "pending") ||
                inspector?.getAttribute("data-details") === "pending";
            });
            if (inspector)
              observer.observe(inspector, {
                attributes: true,
                attributeOldValue: true,
                attributeFilter: ["data-details"],
              });
            const finish = () => {
              observer.disconnect();
              clearTimeout(give);
              resolve(at);
            };
            const give = setTimeout(finish, wait);
            const check = () => {
              ws.forEach((_, i) => {
                if (at[i] === undefined && holds(i))
                  requestAnimationFrame(() => {
                    at[i] ??= performance.now() - t0;
                    if (at.every((x) => x !== undefined)) {
                      finish();
                    }
                  });
              });
              if (at.some((x) => x === undefined)) requestAnimationFrame(check);
            };
            check();
          },
          { capture: true, once: true },
        );
      },
    );
  }, /** @type {[Wait[], number]} */ ([waits, patience]));
  // A click that throws (the browser closed under a signal) abandons `result`: its rejection must
  // not end the process before the server is stopped.
  result.catch(() => {});
  await click();
  return result;
}

/** The first view: navigation start → the frame after the board's first rows (the app marks it
 * `fvtrace:painted`). @param {import("@playwright/test").Page} p @param {string} url */
async function first(p, url) {
  await p.goto(url, { waitUntil: "commit" });
  return p.evaluate(
    (wait) =>
      new Promise(
        /** @param {(ms: number | undefined) => void} resolve */ (resolve) => {
          const give = setTimeout(() => resolve(undefined), wait);
          const check = () => {
            const m = performance.getEntriesByName("fvtrace:painted")[0];
            if (m) {
              clearTimeout(give);
              resolve(m.startTime);
            } else setTimeout(check, 20);
          };
          check();
        },
      ),
    patience,
  );
}

/**
 * The page's live JS memory in bytes after a full collection: V8's heap + ArrayBuffer backing
 * stores (what `performance.memory.usedJSHeapSize` counts). Chromium's own `performance.memory`
 * is bucketed + cached for 20 minutes, so it repeated one early reading, uncollected buffers
 * included (wide 23,040 → 46,081: 68.9 → 189.8 MiB; live 66.3 → 128.7 MiB).
 * @param {import("@playwright/test").Page} p
 */
async function heap(p) {
  const cdp = await p.context().newCDPSession(p);
  try {
    await cdp.send("HeapProfiler.collectGarbage");
    const u = await cdp.send("Runtime.getHeapUsage");
    return u.usedSize + u.backingStorageSize;
  } finally {
    await cdp.detach();
  }
}

/** `SCALE_HOST_LOG` marks around one step (`tools/scale-host.mjs`; telemetry, never graded).
 * @template T @param {string} step @param {() => Promise<T>} run */
async function marked(step, run) {
  const log = process.env.SCALE_HOST_LOG;
  if (log) appendFileSync(log, `m ${Date.now()} start gui:${step}\n`);
  try {
    return await run();
  } finally {
    if (log) appendFileSync(log, `m ${Date.now()} end gui:${step}\n`);
  }
}

/** A fresh page in its own context. @param {import("@playwright/test").Browser} browser */
async function blank(browser) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const p = await context.newPage();
  p.setDefaultTimeout(patience);
  return p;
}

/** The served first view's phases (ms) → one line appended to `SCALE_GUI_PHASES`: spawn → link,
 * link → the page's time origin (its navigation's start; both wall clocks), then from the page's
 * first answer request: its wait (request → response start), transfer, response end → painted,
 * and the first view. Timing output, never graded.
 * @param {import("@playwright/test").Page} p @param {number[]} at spawn, link (`performance.now`)
 * @param {number | undefined} ms */
async function phases(p, at, ms) {
  const file = process.env.SCALE_GUI_PHASES;
  if (!file || ms === undefined) return;
  // Page clock (from navigation start), like `ms`; an entry's getters do not serialize.
  const [origin, wait, transfer, end] = await p.evaluate(() => {
    const e = performance
      .getEntriesByType("resource")
      .find((x) => x instanceof PerformanceResourceTiming && x.name.includes("api/answer"));
    return e instanceof PerformanceResourceTiming
      ? [
          performance.timeOrigin,
          e.responseStart - e.requestStart,
          e.responseEnd - e.responseStart,
          e.responseEnd,
        ]
      : [performance.timeOrigin];
  });
  const [spawn = 0, link = 0] = at;
  const nav = origin === undefined ? undefined : origin - performance.timeOrigin - link;
  const after = end === undefined ? undefined : ms - end;
  const line = [link - spawn, nav, wait, transfer, after, ms].map((x) =>
    x === undefined ? "-" : Math.round(x),
  );
  appendFileSync(file, `${basename(dir ?? "")} ${line.join(" ")}\n`);
}

/** Every step of one mode on page `p`; the page's memory is read once its steps end (a collection
 * between timed steps would change the next one's time). @param {import("@playwright/test").Page} p
 * @param {"served" | "page"} mode @param {string} url @param {number[]} [at] served: spawn + link */
async function steps(p, mode, url, at) {
  const context = p.context();
  /** @type {[string, number | undefined, number, number?][]} */
  const rows = [];
  try {
    const ms = await marked(`${mode}:first`, () => first(p, url));
    rows.push([`gui:${mode}:first`, ms, 10]);
    // Telemetry never fails a graded step.
    if (at)
      await phases(p, at, ms).catch((/** @type {unknown} */ e) => {
        process.stderr.write(`${mode}: phases: ${String(e)}\n`);
      });
    // The engine (or server) holds the shown view before a selection's details are timed.
    await p.waitForFunction(() => !document.body.hasAttribute("aria-busy"));
    const ids = await p
      .locator(cardId)
      .evaluateAll((els) => els.slice(0, 2).map((e) => e.textContent ?? ""));
    const [a = "", b = a] = ids;
    const [select] = await marked(`${mode}:select`, () =>
      timed(p, [{ kind: "shown", id: a }], () => p.locator(cardId).first().click()),
    );
    rows.push([`gui:${mode}:select`, select, 0.1]);
    await p.waitForFunction(() => !document.body.hasAttribute("aria-busy"));
    const [ready] = await marked(`${mode}:details`, () =>
      timed(p, [{ kind: "ready", id: b }], () =>
        p
          .locator(cardId)
          .nth(b === a ? 0 : 1)
          .click(),
      ),
    );
    rows.push([`gui:${mode}:details`, ready, 1]);
    await p.waitForFunction(() => !document.body.hasAttribute("aria-busy"));
    const symbols = await p.locator(symbol).count();
    if (symbols > 0) {
      const [busy, answered] = await marked(`${mode}:whatif`, () =>
        timed(p, [{ kind: "busy" }, { kind: "answered" }], () => p.locator(symbol).first().click()),
      );
      rows.push([`gui:${mode}:busy`, busy, 0.1], [`gui:${mode}:whatif`, answered, 10]);
    }
    // Last, so the claim steps keep the selection they had: an experiment's details re-asked
    // after the what-if would lengthen its answer.
    if ((await p.locator(experimentId).count()) > 0) {
      await p.waitForFunction(() => !document.body.hasAttribute("aria-busy"));
      const e = (await p.locator(experimentId).first().textContent()) ?? "";
      const [shown] = await marked(`${mode}:experiment`, () =>
        timed(p, [{ kind: "experiment", id: e }], () => p.locator(experimentId).first().click()),
      );
      rows.push([`gui:${mode}:experiment`, shown, 1]);
    }
    if (symbols > 0 && mode === "page") {
      // A click while the engine starts: a fresh page, its symbol clicked once the board shows.
      const q = await context.newPage();
      q.setDefaultTimeout(patience);
      const [startup] = await marked("page:startup", async () => {
        await first(q, url);
        return timed(q, [{ kind: "answered" }], () => q.locator(symbol).first().click());
      });
      rows.push(["gui:page:startup", startup, 10, await heap(q)]);
    }
  } catch (e) {
    process.stderr.write(`${mode}: ${String(e)}\n`);
  } finally {
    const live = await heap(p).catch((/** @type {unknown} */ e) => {
      process.stderr.write(`${mode}: memory: ${String(e)}\n`);
      return undefined;
    });
    for (const [step, ms, bound, own] of rows) row(step, ms, bound, own ?? live);
    await context.close();
  }
}

/** The browser's launch: a signal during it still closes what it made (its profile folder). */
/** @type {Promise<import("@playwright/test").Browser> | undefined} */
let launching;
/** The server, spawned once the browser + the served page exist. @type {ReturnType<typeof serve>
 * | undefined} */
let server;
/** @type {Promise<void> | undefined} */
let stopping;
/** Stops the server and waits for its exit (it may still write its data folder until then), closes
 * the browser, removes the folder; once, on every way out. */
function stop() {
  stopping ??= (async () => {
    await server?.stop();
    await launching?.then(
      (b) => b.close(),
      () => {},
    );
    rmSync(home, { recursive: true, force: true });
  })();
  return stopping;
}
// Signals are handled here, not by Playwright (its SIGINT handler exits at once), and from before
// the folder + browser exist: without a listener a signal ends node by its default action, leaving
// them behind. A listener runs between ticks; the tick that spawns the server first checks
// `stopping`, so a stop either finds the server or prevents it.
for (const [signal, code] of /** @type {const} */ ([
  ["SIGINT", 130],
  ["SIGTERM", 143],
  ["SIGHUP", 129],
]))
  process.once(signal, () => void stop().finally(() => process.exit(code)));
const home = mkdtempSync(join(tmpdir(), "scale-gui-"));
try {
  launching = chromium.launch({ handleSIGINT: false, handleSIGTERM: false, handleSIGHUP: false });
  const b = await launching;
  // The served first view starts as `serve`'s own opener does: the browser open, navigation the
  // moment the link prints (the launch evaluation then running). A page made after the spawn lands
  // at an uncontrolled point of that evaluation, and the fastest of 3 can pick the latest landing.
  const p = await blank(b);
  if (stopping) throw new Error("stopped before the server started");
  const spawned = performance.now();
  server = serve(bin, ["--trace", join(dir, "trace.json"), "--project", join(dir, "project")], {
    env: { ...process.env, FVTRACE_HOME: home },
  });
  const link = await server.link;
  await steps(p, "served", hash ? `${link}&${hash}` : link, [spawned, performance.now()]);
  await steps(await blank(b), "page", `${pathToFileURL(page).href}${hash ? `#${hash}` : ""}`);
} finally {
  await stop();
}
