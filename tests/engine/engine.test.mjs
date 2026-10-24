// The page engine's differential test in Node (`.agent/contracts/kernel.md` E-wasm): the
// WebAssembly build, run by the page's own loader (`web/engine.js`) from an exported page's engine
// block, answers every case byte for byte as the native engine does (`fvtrace-tests
// --evaluate-snapshot`). Headless Chromium runs the same cases: tests/e2e/engine.spec.js.
import assert from "node:assert/strict";
import { test } from "node:test";
import { startEngine } from "../../web/engine.js";
import { cases, engineOfPage, exportedPage, nativeAnswers, snapshotOfPage } from "./cases.mjs";

const seed = Number(process.env["FVTRACE_ENGINE_SEED"] ?? "20261022");

void test("the exported page's engine answers every case as the native engine does", async () => {
  const html = exportedPage();
  const engine = await startEngine(engineOfPage(html));
  const all = [
    {
      name: "the exported page's own snapshot",
      snapshot: snapshotOfPage(html),
      specs: [
        "",
        "O2=checked,EN2=proved",
        "O3=checked,O2=checked,EN2=proved",
        "R1=violated",
        "ZZ=proved",
      ],
    },
    ...cases(seed),
  ];
  let answers = 0;
  // A panic (`fd_write`, routed to the console) returns a default value, which may still give the
  // native answer: equal bytes alone would miss it.
  /** @type {string[]} */
  const said = [];
  const original = console.error;
  console.error = (/** @type {unknown[]} */ ...args) => void said.push(args.join(" "));
  try {
    for (const c of all) {
      const native = nativeAnswers(c.snapshot, c.specs);
      c.specs.forEach((spec, i) => {
        const where = `${c.name}, what-if ${JSON.stringify(spec.slice(0, 80))}`;
        /** @type {string} */
        let wasm;
        try {
          wasm = engine.answer(c.snapshot, spec);
        } catch (e) {
          assert.fail(`${where}: the engine failed (${String(e)})`);
        }
        const want = native[i] ?? "";
        if (wasm !== want) {
          let at = 0;
          while (at < wasm.length && wasm[at] === want[at]) at++;
          const near = (/** @type {string} */ t) => JSON.stringify(t.slice(at, at + 60));
          assert.fail(
            `${where}: answers differ at ${at}: wasm ${near(wasm)} vs native ${near(want)}`,
          );
        }
        assert.deepEqual(said, [], where);
        answers++;
      });
    }
  } finally {
    console.error = original;
  }
  console.log(
    `engine differential (Node): ${answers} answers on ${all.length} snapshots equal, seed ${seed}`,
  );
});
