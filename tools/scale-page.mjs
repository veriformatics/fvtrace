// The exported page's engine timed (`.agent/contracts/kernel.md` P-time: the page engine, its
// loader in Node): one instance answers the page's requests in the order the GUI sends them.
//   node tools/scale-page.mjs <page.html> <whatif> <action> [item…]
// Steps: `page` = start-up (the engine started from the page's engine block, the snapshot block
// loaded: E-state); `page:whatif` (a nonempty what-if: the view the page opens at);
// `page:details:<kind>` per item at that view (the first one there evaluates it: E-state computes
// answers lazily); `page:action` from that view. One row per step on stdout:
// `<step> <rc> <wall s> <cpu s> <max RSS KiB> <answer bytes>`; rc 1 = a problem answer, rc 2 = the
// engine failed (no later step runs: a failed engine ends for the session).
import { readFileSync } from "node:fs";
import { startEngine } from "../web/engine.js";
import { engineOfPage, snapshotOfPage } from "../tests/engine/cases.mjs";

const [page, whatif = "", action, ...items] = process.argv.slice(2);
if (!page || !action) {
  process.stderr.write("usage: node tools/scale-page.mjs <page.html> <whatif> <action> [item…]\n");
  process.exit(2);
}
const html = readFileSync(page, "utf8");

const mark = () => ({ cpu: process.cpuUsage(), at: performance.now() });

/** Prints one step's row; rc 2 ends the run. @param {string} step @param {number} rc
 * @param {ReturnType<typeof mark>} m @param {number} bytes */
function row(step, rc, m, bytes) {
  const wall = ((performance.now() - m.at) / 1000).toFixed(2);
  const user = (process.cpuUsage(m.cpu).user / 1e6).toFixed(2);
  process.stdout.write(
    `${step} ${rc} ${wall} ${user} ${process.resourceUsage().maxRSS} ${bytes}\n`,
  );
  if (rc === 2) process.exit(0);
}

/** @param {string} step @param {unknown} e @param {ReturnType<typeof mark>} m */
function failed(step, e, m) {
  process.stderr.write(`${step}: ${String(e)}\n`);
  row(step, 2, m, 0);
}

/** One request at the page's view (the engine answers within the call).
 * @param {string} step @param {import("../web/engine.js").Engine} engine
 * @param {{ whatif: string, action?: string, details?: string }} request */
function ask(step, engine, request) {
  const m = mark();
  try {
    const out = engine.request(JSON.stringify(request));
    row(step, /^\{\s*"problem"/.test(out.slice(0, 40)) ? 1 : 0, m, Buffer.byteLength(out));
  } catch (e) {
    failed(step, e, m);
  }
}

const m = mark();
/** @type {import("../web/engine.js").Engine | undefined} */
let engine;
try {
  const snapshot = snapshotOfPage(html);
  engine = await startEngine(engineOfPage(html));
  const problem = engine.load(snapshot);
  if (problem !== null) throw new Error(`the engine refused the page's snapshot: ${problem}`);
  row("page", 0, m, 0);
} catch (e) {
  failed("page", e, m);
}
if (engine) {
  if (whatif) ask("page:whatif", engine, { whatif });
  for (const item of items)
    ask(`page:details:${item.split(":")[0] ?? ""}`, engine, { whatif, details: item });
  ask("page:action", engine, { whatif, action });
}
