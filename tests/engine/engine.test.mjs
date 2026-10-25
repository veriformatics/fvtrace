// The page engine's differential test in Node (`.agent/contracts/kernel.md` E-wasm): the
// WebAssembly build, run by the page's own loader (`web/engine.js`) from an exported page's engine
// block, answers every case byte for byte as the native engine does (`fvtrace-tests
// --answer-snapshot`). Headless Chromium runs the same cases: tests/e2e/engine.spec.js.
import assert from "node:assert/strict";
import { test } from "node:test";
import { startEngine } from "../../web/engine.js";
import {
  cases,
  engineOfPage,
  exportedPage,
  nativeAnswers,
  nativeRequests,
  requestsFor,
  snapshotOfPage,
  specOf,
} from "./cases.mjs";

/** @param {unknown} v @returns {v is Record<string, unknown>} */
const isRecord = (v) => typeof v === "object" && v !== null && !Array.isArray(v);

const seed = Number(process.env["FVTRACE_ENGINE_SEED"] ?? "20261022");

void test("the exported page's engine answers every case as the native engine does", async () => {
  const html = exportedPage();
  const base64 = engineOfPage(html);
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
    // One instance per snapshot: a refused snapshot ends its engine (E-state).
    const engines = await Promise.all(all.map(() => startEngine(base64)));
    for (const [k, c] of all.entries()) {
      const engine = engines[k];
      if (!engine) throw new Error("no engine");
      const problem = engine.load(c.snapshot);
      if (problem !== null) {
        assert.equal(problem, nativeAnswers(c.snapshot, [""])[0], `${c.name}: load refusal`);
        answers++;
        continue;
      }
      const native = nativeAnswers(c.snapshot, c.specs);
      c.specs.forEach((spec, i) => {
        const where = `${c.name}, what-if ${JSON.stringify(spec.slice(0, 80))}`;
        /** @type {string} */
        let wasm;
        try {
          wasm = engine.request(JSON.stringify({ whatif: spec }));
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

void test("the engine answers every request sequence as the native engine does", async () => {
  const html = exportedPage();
  const base64 = engineOfPage(html);
  let answers = 0;
  /** @type {string[]} */
  const said = [];
  const original = console.error;
  console.error = (/** @type {unknown[]} */ ...args) => void said.push(args.join(" "));
  try {
    const all = cases(seed);
    // One instance per snapshot: a refused snapshot ends its engine (E-state).
    const engines = await Promise.all(all.map(() => startEngine(base64)));
    for (const [k, c] of all.entries()) {
      const engine = engines[k];
      if (!engine) throw new Error("no engine");
      const problem = engine.load(c.snapshot);
      if (problem !== null) {
        assert.equal(problem, nativeRequests(c.snapshot, [])[0], `${c.name}: load refusal`);
        answers++;
        continue;
      }
      const requests = requestsFor(c);
      const native = nativeRequests(c.snapshot, requests);
      requests.forEach((r, i) => {
        const wasm = engine.request(r);
        assert.equal(wasm, native[i], `${c.name}, request ${r.slice(0, 80)}`);
        assert.deepEqual(said, [], `${c.name}, request ${r.slice(0, 80)}`);
        answers++;
        // An item of the envelope at an accepted view answers its details, not a refusal: a
        // comparison of two refusals would leave the details unexercised.
        /** @type {unknown} */
        const asked = JSON.parse(r.startsWith("{") ? r : "null");
        const item = isRecord(asked) ? asked["details"] : undefined;
        if (
          typeof item === "string" &&
          /^(experiment|claim|fact):/.test(item) &&
          !item.endsWith(":E9")
        )
          assert.match(native[i] ?? "", /"schema": "fvtrace\.details\/1"/, `${c.name}: ${item}`);
      });
      // V-action: each one-click action's envelope = the envelope at the what-if it expands to.
      /** @type {unknown} */
      const recorded = JSON.parse(native[0] ?? "null");
      /** @type {unknown} */
      const listed = isRecord(recorded) ? recorded["actions"] : undefined;
      for (const a of (Array.isArray(listed) ? listed : []).slice(0, 4)) {
        const id = isRecord(a) ? String(a["id"]) : "";
        const [byAction = ""] = nativeRequests(c.snapshot, [
          JSON.stringify({ whatif: "", action: id }),
        ]);
        const spec = specOf(JSON.parse(byAction));
        const [bySpec] = nativeRequests(c.snapshot, [JSON.stringify({ whatif: spec })]);
        assert.equal(byAction, bySpec, `${c.name}: action ${id} = the what-if ${spec}`);
      }
    }
  } finally {
    console.error = original;
  }
  console.log(`engine requests (Node): ${answers} answers equal, seed ${seed}`);
});
