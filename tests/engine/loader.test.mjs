// The page's loader (`web/engine.js`, kernel.md E-abi + E-sec), observed at its boundary with the
// instance: every answer frees what it allocated plus the engine's output; after a failure no call
// enters the instance; a panic line from the engine reaches the console.
import assert from "node:assert/strict";
import { test } from "node:test";
import { EngineError, startEngine } from "../../web/engine.js";
import { engineOfPage, exportedPage, snapshotOfPage } from "./cases.mjs";

const html = exportedPage();
const block = engineOfPage(html);
const snapshot = snapshotOfPage(html);
const realInstantiate = WebAssembly.instantiate.bind(WebAssembly);

/** @param {WebAssembly.Exports} real @param {string} name @returns {(...args: number[]) => number} */
function call(real, name) {
  const f = real[name];
  if (typeof f !== "function") throw new Error(`no ${name}`);
  return (...args) => {
    /** @type {unknown} */
    const r = Reflect.apply(f, undefined, args);
    return typeof r === "number" ? r : 0;
  };
}

/** Starts the engine through a recording proxy of its exports; evaluate call number `nullAt`
 * (1-based) answers NULL. @param {number} [nullAt] */
async function recorded(nullAt = 0) {
  /** @type {string[]} */
  const calls = [];
  /** @type {Set<number>} */
  const allocated = new Set();
  const counts = { outputs: 0, evaluations: 0 };
  /** @type {{ real?: WebAssembly.Exports, imports?: WebAssembly.Imports }} */
  const seen = {};
  const proxy = async (
    /** @type {BufferSource} */ bytes,
    /** @type {WebAssembly.Imports} */ imports,
  ) => {
    const { module, instance } = await realInstantiate(bytes, imports);
    const real = instance.exports;
    Object.assign(seen, { real, imports });
    const exports = {
      ...real,
      fvtrace_alloc: (/** @type {number} */ n) => {
        calls.push("alloc");
        const at = call(real, "fvtrace_alloc")(n);
        allocated.add(at);
        return at;
      },
      fvtrace_free: (/** @type {number} */ at) => {
        calls.push("free");
        if (!allocated.delete(at)) counts.outputs++;
        return call(real, "fvtrace_free")(at);
      },
      fvtrace_evaluate: (/** @type {number[]} */ ...args) => {
        calls.push("evaluate");
        counts.evaluations++;
        return counts.evaluations === nullAt ? 0 : call(real, "fvtrace_evaluate")(...args);
      },
    };
    return { module, instance: { exports } };
  };
  Reflect.set(WebAssembly, "instantiate", proxy);
  try {
    return { engine: await startEngine(block), calls, allocated, counts, seen };
  } finally {
    Reflect.set(WebAssembly, "instantiate", realInstantiate);
  }
}

void test("every answer frees its three buffers and the engine's output", async () => {
  const r = await recorded();
  const n = 20;
  for (let i = 0; i < n; i++) r.engine.answer(snapshot, i % 2 ? "O2=checked,EN2=proved" : "ZZ=x");
  assert.equal(r.calls.filter((c) => c === "alloc").length, 3 * n);
  assert.equal(r.calls.filter((c) => c === "free").length, 4 * n);
  assert.equal(r.allocated.size, 0, "a loader buffer was not freed");
  assert.equal(r.counts.outputs, n, "an engine output was not freed");
});

void test("after a NULL answer no call enters the instance, a free included", async () => {
  const r = await recorded(1);
  assert.throws(() => r.engine.answer(snapshot, "O2=checked"), EngineError);
  const afterNull = () => r.calls.slice(r.calls.indexOf("evaluate") + 1);
  assert.deepEqual(afterNull(), []);
  assert.throws(() => r.engine.answer(snapshot, ""), EngineError);
  assert.deepEqual(afterNull(), []);
});

void test("a panic line the engine writes reaches the console", async () => {
  const r = await recorded();
  const real = r.seen.real;
  const wasi = r.seen.imports?.["wasi_snapshot_preview1"];
  const memory = real?.["memory"];
  const write = wasi?.["fd_write"];
  if (!real || !(memory instanceof WebAssembly.Memory) || typeof write !== "function")
    throw new Error("no instance");
  const text = new TextEncoder().encode("PANIC planted\nrest");
  const at = call(real, "fvtrace_alloc")(text.length + 12);
  const iov = at + text.length;
  new Uint8Array(memory.buffer, at, text.length).set(text);
  const view = new DataView(memory.buffer);
  view.setUint32(iov, at, true);
  view.setUint32(iov + 4, text.length, true);
  /** @type {string[]} */
  const lines = [];
  const original = console.error;
  console.error = (/** @type {unknown[]} */ ...args) => void lines.push(args.join(" "));
  try {
    /** @type {unknown} */
    const errno = Reflect.apply(write, undefined, [2, iov, 1, iov + 8]);
    assert.equal(errno, 0);
  } finally {
    console.error = original;
  }
  assert.deepEqual(lines, ["fvTrace engine: PANIC planted"]);
  assert.equal(new DataView(memory.buffer).getUint32(iov + 8, true), text.length);
});
