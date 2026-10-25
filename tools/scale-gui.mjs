// The GUI's response times (`.agent/contracts/kernel.md` U-time) on one generated trace, served
// (`fvtrace serve`) + exported (`fvtrace export --html`), in Playwright's bundled Chromium. Each
// interval runs from the input event's time stamp (the first view: the navigation's start) to the
// frame painted once the change shows; CSS selectors only (role queries cost seconds on a large
// page).
//   node tools/scale-gui.mjs <fvtrace binary> <trace dir> <page.html>
// The trace dir is tools/scale.mjs's (trace.json, project/, whatif.txt when the shape has one).
// Rows on stdout: `<step> <rc> <wall s> - <JS heap KiB> 0 <bound s>`, rc 1 = the change never
// showed within 60 s or the page failed. Steps per mode (`served`, `page`): `first` (navigation →
// the board painted), `select` (a click on the first card's id → its highlight + summary),
// `details` (a click on the second card's id → its details, the view already held), `busy` (a click
// on the first card's first symbol → the busy state), `whatif` (→ its answer); exported also
// `startup` (the symbol clicked as soon as the board shows, the engine still starting → its answer).
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { chromium } from "@playwright/test";

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

/** @param {string} step @param {number | undefined} ms @param {number} bound @param {number} heap */
function row(step, ms, bound, heap) {
  const wall = ms === undefined ? "timeout" : (ms / 1000).toFixed(3);
  const rc = ms === undefined ? 1 : 0;
  process.stdout.write(`${step} ${rc} ${wall} - ${Math.round(heap / 1024)} 0 ${bound}\n`);
}

/**
 * What a step waits for: the inspector showing a claim (`shown`), its details too (`ready`), the
 * busy state (`busy`), a what-if's answer (`answered`).
 * @typedef {{ kind: "shown", id: string } | { kind: "ready", id: string } | { kind: "busy" }
 *   | { kind: "answered" }} Wait
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
    /** Wait `i` holds (a function in the page). @param {number} i */
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
      const tag = document.querySelector("#inspector .claim-tag .tag-id")?.textContent;
      if (tag !== w.id) return false;
      return w.kind === "shown" || !document.querySelector("#inspector")?.hasAttribute("aria-busy");
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
            const give = setTimeout(() => resolve(at), wait);
            const check = () => {
              ws.forEach((_, i) => {
                if (at[i] === undefined && holds(i))
                  requestAnimationFrame(() => {
                    at[i] ??= performance.now() - t0;
                    if (at.every((x) => x !== undefined)) {
                      clearTimeout(give);
                      resolve(at);
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

/** The page's JS heap in bytes (Chromium's `performance.memory`). @param {import("@playwright/test").Page} p */
const heap = (p) =>
  p.evaluate(() => {
    /** @type {unknown} */
    const m = Reflect.get(performance, "memory");
    /** @type {unknown} */
    const used = typeof m === "object" && m !== null ? Reflect.get(m, "usedJSHeapSize") : 0;
    return typeof used === "number" ? used : 0;
  });

/** Every step of one mode. @param {import("@playwright/test").Browser} browser
 * @param {"served" | "page"} mode @param {string} url */
async function steps(browser, mode, url) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const p = await context.newPage();
  p.setDefaultTimeout(patience);
  try {
    row(`gui:${mode}:first`, await first(p, url), 10, await heap(p));
    // The engine (or server) holds the shown view before a selection's details are timed.
    await p.waitForFunction(() => !document.body.hasAttribute("aria-busy"));
    const ids = await p
      .locator(cardId)
      .evaluateAll((els) => els.slice(0, 2).map((e) => e.textContent ?? ""));
    const [a = "", b = a] = ids;
    const [select] = await timed(p, [{ kind: "shown", id: a }], () =>
      p.locator(cardId).first().click(),
    );
    row(`gui:${mode}:select`, select, 0.1, await heap(p));
    await p.waitForFunction(() => !document.body.hasAttribute("aria-busy"));
    const [ready] = await timed(p, [{ kind: "ready", id: b }], () =>
      p
        .locator(cardId)
        .nth(b === a ? 0 : 1)
        .click(),
    );
    row(`gui:${mode}:details`, ready, 1, await heap(p));
    await p.waitForFunction(() => !document.body.hasAttribute("aria-busy"));
    if ((await p.locator(symbol).count()) === 0) return;
    const [busy, answered] = await timed(p, [{ kind: "busy" }, { kind: "answered" }], () =>
      p.locator(symbol).first().click(),
    );
    row(`gui:${mode}:busy`, busy, 0.1, await heap(p));
    row(`gui:${mode}:whatif`, answered, 10, await heap(p));
    if (mode === "page") {
      // A click while the engine starts: a fresh page, its symbol clicked once the board shows.
      const q = await context.newPage();
      q.setDefaultTimeout(patience);
      await first(q, url);
      const [startup] = await timed(q, [{ kind: "answered" }], () =>
        q.locator(symbol).first().click(),
      );
      row("gui:page:startup", startup, 10, await heap(q));
    }
  } catch (e) {
    process.stderr.write(`${mode}: ${String(e)}\n`);
  } finally {
    await context.close();
  }
}

const browser = await chromium.launch();
const home = mkdtempSync(join(tmpdir(), "scale-gui-"));
const server = spawn(
  bin,
  [
    "serve",
    "--port",
    "0",
    "--no-browser",
    "--trace",
    join(dir, "trace.json"),
    "--project",
    join(dir, "project"),
  ],
  { env: { ...process.env, FVTRACE_HOME: home }, stdio: ["ignore", "pipe", "ignore"] },
);
try {
  let out = "";
  /** @type {string} */
  const link = await new Promise((resolve, reject) => {
    server.stdout.on("data", (/** @type {Buffer} */ chunk) => {
      out += chunk.toString();
      const m = /http:\/\/\S+#token=[0-9a-f]+/.exec(out);
      if (m) resolve(m[0]);
    });
    server.on("exit", () => reject(new Error(`fvtrace serve exited: ${out}`)));
  });
  await steps(browser, "served", hash ? `${link}&${hash}` : link);
  await steps(browser, "page", `${pathToFileURL(page).href}${hash ? `#${hash}` : ""}`);
} finally {
  server.kill();
  await browser.close();
  rmSync(home, { recursive: true, force: true });
}
