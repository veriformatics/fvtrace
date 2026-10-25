// The exported page's engine worker (`.agent/contracts/kernel.md` E-page, E-abi; user ruling: the
// engine in a Worker): the engine runs here, off the page's thread, so the page answers clicks
// while it works. One message in = one reply out, matched by id: `start` (the engine block),
// `load` (the snapshot: null or the problem's text), `request` (a request's answer text); any
// failure replies `failed` and the page ends the engine.
import { startEngine } from "./engine.js";

/** @type {import("./engine.js").Engine | undefined} */
let engine;

/** @param {unknown} message */
const reply = (message) => {
  /** @type {unknown} */
  const post = Reflect.get(globalThis, "postMessage");
  if (typeof post === "function") Reflect.apply(post, globalThis, [message]);
};

/** Messages run in arrival order: `load` may arrive while `start` still compiles the engine. */
let chain = Promise.resolve();

Reflect.set(globalThis, "onmessage", (/** @type {MessageEvent} */ event) => {
  chain = chain.then(() => handle(event));
});

/** @param {MessageEvent} event */
async function handle(event) {
  /** @type {unknown} */
  const data = event.data;
  /** @type {unknown} */
  const id = typeof data === "object" && data !== null ? Reflect.get(data, "id") : undefined;
  /** @type {unknown} */
  const op = typeof data === "object" && data !== null ? Reflect.get(data, "op") : undefined;
  /** @type {unknown} */
  const arg = typeof data === "object" && data !== null ? Reflect.get(data, "arg") : undefined;
  try {
    if (typeof arg !== "string") throw new Error("a message without its text");
    if (op === "start") {
      engine = await startEngine(arg);
      reply({ id, value: null });
    } else if (!engine) throw new Error("the engine has not started");
    else if (op === "load") reply({ id, value: engine.load(arg) });
    else if (op === "request") reply({ id, value: engine.request(arg) });
    else throw new Error("an unknown message");
  } catch (e) {
    reply({ id, failed: String(e) });
  }
}
