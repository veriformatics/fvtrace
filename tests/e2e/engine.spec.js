// The page engine's differential test in headless Chromium (`.agent/contracts/kernel.md` E-wasm):
// the cases of tests/engine/ (Node), run by the page's own loader (`web/engine.js`) inside the
// browser, from an exported page's engine block; every answer equals the native engine's.
import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import {
  cases,
  engineOfPage,
  exportedPage,
  nativeAnswers,
  root,
  snapshotOfPage,
} from "../engine/cases.mjs";

const seed = Number(process.env["FVTRACE_ENGINE_SEED"] ?? "20261022");

test("the page's engine answers every case in Chromium as the native engine does", async ({
  page,
}) => {
  test.setTimeout(600_000);
  /** @type {string[]} */
  const said = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") said.push(msg.text());
  });
  const html = exportedPage();
  const loader = readFileSync(new URL("web/engine.js", root), "utf8");
  // A test origin served from memory: nothing leaves the machine.
  await page.route("http://engine.test/**", (route) =>
    new URL(route.request().url()).pathname === "/engine.js"
      ? route.fulfill({ contentType: "text/javascript", body: loader })
      : route.fulfill({
          contentType: "text/html",
          body:
            '<!doctype html><html lang="en"><title>engine</title><script type="module">' +
            'import { startEngine } from "/engine.js"; globalThis.fvtraceStart = startEngine;' +
            "</script></html>",
        }),
  );
  await page.goto("http://engine.test/");
  await page.waitForFunction(() => "fvtraceStart" in globalThis);
  await page.evaluate(async (base64) => {
    /** @type {unknown} */
    const start = Reflect.get(globalThis, "fvtraceStart");
    if (typeof start !== "function") throw new Error("no loader");
    /** @type {unknown} */
    const engine = await Reflect.apply(start, undefined, [base64]);
    Reflect.set(globalThis, "fvtraceEngine", engine);
  }, engineOfPage(html));
  const all = [
    {
      name: "the exported page's own snapshot",
      snapshot: snapshotOfPage(html),
      specs: ["", "O2=checked,EN2=proved", "R1=violated", "ZZ=proved"],
    },
    ...cases(seed),
  ];
  /** @type {[string, string[]][]} */
  const inputs = all.map((c) => [c.snapshot, c.specs]);
  // One call for every case: the engine answers in order, in the page.
  const wasm = await page.evaluate((cs) => {
    /** @type {unknown} */
    const engine = Reflect.get(globalThis, "fvtraceEngine");
    if (typeof engine !== "object" || engine === null) throw new Error("no engine");
    /** @type {unknown} */
    const answer = Reflect.get(engine, "answer");
    if (typeof answer !== "function") throw new Error("no answer");
    return cs.map(([snapshot, specs]) =>
      specs.map((spec) => {
        /** @type {unknown} */
        const out = Reflect.apply(answer, engine, [snapshot, spec]);
        return typeof out === "string" ? out : "";
      }),
    );
  }, inputs);
  let answers = 0;
  all.forEach((c, k) => {
    const native = nativeAnswers(c.snapshot, c.specs);
    c.specs.forEach((spec, i) => {
      expect(wasm[k]?.[i], `${c.name}, what-if ${JSON.stringify(spec.slice(0, 80))}`).toBe(
        native[i],
      );
      answers++;
    });
  });
  // A panic (`fd_write`, routed to the console) may still give the native answer.
  expect(said).toEqual([]);
  console.log(`engine differential (Chromium): ${answers} answers equal, seed ${seed}`);
});
