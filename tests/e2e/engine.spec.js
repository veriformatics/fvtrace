// The page engine's differential test in headless Chromium (`.agent/contracts/kernel.md` E-wasm):
// the cases of tests/engine/ (Node), run by the page's own loader (`web/engine.js`) inside the
// browser, from an exported page's engine block; every answer equals the native engine's.
import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import {
  cases,
  engineOfPage,
  exportedPage,
  nativeRequests,
  requestsFor,
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
  const all = [
    {
      name: "the exported page's own snapshot",
      snapshot: snapshotOfPage(html),
      specs: ["", "O2=checked,EN2=proved", "R1=violated", "ZZ=proved"],
    },
    ...cases(seed),
  ];
  let answers = 0;
  // Request sequences (E-request), one engine per snapshot: a refused snapshot ends its engine.
  /** @type {[string, string[]][]} */
  const sequences = all.map((c) => [
    c.snapshot,
    [...c.specs.map((whatif) => JSON.stringify({ whatif })), ...requestsFor(c)],
  ]);
  const replies = await page.evaluate(
    async ([base64, seqs]) => {
      /** @type {unknown} */
      const start = Reflect.get(globalThis, "fvtraceStart");
      if (typeof start !== "function") throw new Error("no loader");
      /** @type {string[][]} */
      const out = [];
      const make = async () => {
        /** @type {unknown} */
        const engine = await Reflect.apply(start, undefined, [base64]);
        return engine;
      };
      const engines = await Promise.all(seqs.map(() => make()));
      for (const [k, [snapshot, requests]] of seqs.entries()) {
        const engine = engines[k];
        if (typeof engine !== "object" || engine === null) throw new Error("no engine");
        /** @type {unknown} */
        const load = Reflect.get(engine, "load");
        /** @type {unknown} */
        const request = Reflect.get(engine, "request");
        if (typeof load !== "function" || typeof request !== "function")
          throw new Error("no calls");
        /** @type {unknown} */
        const problem = Reflect.apply(load, engine, [snapshot]);
        if (typeof problem === "string") {
          out.push([problem]);
          continue;
        }
        out.push(
          requests.map((r) => {
            /** @type {unknown} */
            const reply = Reflect.apply(request, engine, [r]);
            return typeof reply === "string" ? reply : "";
          }),
        );
      }
      return out;
    },
    /** @type {[string, [string, string[]][]]} */ ([engineOfPage(html), sequences]),
  );
  all.forEach((c, k) => {
    const native = nativeRequests(c.snapshot, sequences[k]?.[1] ?? []);
    expect(replies[k], `${c.name}: request sequence`).toEqual(native);
    answers += native.length;
  });
  // A panic (`fd_write`, routed to the console) may still give the native answer.
  expect(said).toEqual([]);
  console.log(`engine differential (Chromium): ${answers} answers equal, seed ${seed}`);
});
