import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { chromium } from "@playwright/test";

const source = readFileSync("tools/scale-gui.mjs", "utf8");
const start = source.indexOf("async function timed(");
const end = source.indexOf("/** The first view:", start);
/** @typedef {(p: import('@playwright/test').Page, waits: {kind: 'ready', id: string}[],
 * click: () => Promise<void>) => Promise<(number | undefined)[]>} Timer */
/** @param {unknown} value @returns {value is Timer} */
function isTimer(value) {
  return typeof value === "function";
}
// Load the exact helper without starting the CLI's browser + server.
const loaded = /** @type {unknown} */ (
  await import(
    `data:text/javascript,${encodeURIComponent(`const patience = 5000; export ${source.slice(start, end)}`)}`
  )
);
assert.ok(
  loaded !== null && typeof loaded === "object" && "timed" in loaded && isTimer(loaded.timed),
);
const timed = loaded.timed;

void test("details timing waits for the same item's new answer", async () => {
  const browser = await chromium.launch();
  try {
    const p = await browser.newPage();
    await p.setContent(
      '<button id="again">C0</button><div id="inspector" data-details="ready"><div class="claim-tag"><span class="tag-id">C0</span></div></div>',
    );
    await p.evaluate(() => {
      const again = document.querySelector("#again");
      if (!again) throw new Error("missing click fixture");
      again.addEventListener("click", (ev) => {
        const inspector = document.querySelector("#inspector");
        if (!inspector) throw new Error("missing details fixture");
        inspector.setAttribute("data-details", "pending");
        setTimeout(() => {
          inspector.setAttribute("data-details", "ready");
          document.body.dataset.actualMs = String(performance.now() - ev.timeStamp);
        }, 1200);
      });
    });
    const [reported] = await timed(p, [{ kind: "ready", id: "C0" }], () =>
      p.locator("#again").click(),
    );
    assert.ok(
      reported !== undefined && reported >= 1000,
      `pre-click details were timed as ${reported} ms`,
    );
    assert.ok((await p.evaluate(() => Number(document.body.dataset.actualMs))) >= 1000);
  } finally {
    await browser.close();
  }
});
