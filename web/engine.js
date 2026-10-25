// The exported page's engine (`.agent/contracts/kernel.md` § Page engine): the fvTrace engine
// compiled to WebAssembly. The page carries it as base64(gzip(module)); this loader decompresses
// it, provides the few system calls it imports (output, clock, entropy; no file system, no
// network) and passes strings as (pointer, byte length), so a what-if reaches the engine byte for
// byte. Any failure stops the instance for the session: a trapped engine is not called again.

/** The page cannot run its engine, or the engine stopped. */
export class EngineError extends Error {}

/** The engine: `load` decodes a snapshot once (null = loaded, else the problem's text) and
 * `request` answers a request against it (`kernel.md` E-request: envelope, details or problem
 * JSON text).
 * @typedef {{ load: (snapshot: string) => string | null, request: (text: string) => string }}
 *   Engine */
/** @typedef {(...args: number[]) => number} WasmFunction */

/** WASI errno for a file descriptor the engine has no business with. */
const EBADF = 8;

/** An exported function of i32 arguments; its result as a number (a void function's: 0).
 * @param {WebAssembly.Exports} exports @param {string} name @returns {WasmFunction} */
function wasmFunction(exports, name) {
  const f = exports[name];
  if (typeof f !== "function") throw new EngineError(`the engine exports no ${name}`);
  return (...args) => {
    /** @type {unknown} */
    const r = Reflect.apply(f, undefined, args);
    if (typeof r === "number") return r;
    if (r === undefined) return 0;
    throw new EngineError(`${name} returned a non-number`);
  };
}

/** @param {string} base64 */
function bytesOf(base64) {
  const text = atob(base64);
  const out = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i++) out[i] = text.charCodeAt(i);
  return out;
}

/**
 * Starts the engine from the page's engine block (base64 gzip).
 * @param {string} base64 @returns {Promise<Engine>}
 */
export const startEngine = async (base64) => {
  try {
    if (typeof WebAssembly !== "object" || typeof DecompressionStream !== "function")
      throw new EngineError("this browser lacks WebAssembly or DecompressionStream");
    const stream = new Blob([bytesOf(base64)])
      .stream()
      .pipeThrough(new DecompressionStream("gzip"));
    const module = await new Response(stream).arrayBuffer();
    /** @type {WebAssembly.Memory | undefined} */
    let memory;
    const mem = () => {
      if (!memory) throw new EngineError("the engine has no memory yet");
      return memory;
    };
    const view = () => new DataView(mem().buffer);
    /** @type {Record<number, string>} */
    const pending = {};
    const encoder = new TextEncoder();
    const decoder = new TextDecoder("utf-8", { fatal: true });
    const wasi = {
      /** @param {number} code */
      proc_exit: (code) => {
        throw new EngineError(`the engine exited (${code})`);
      },
      fd_close: () => EBADF,
      fd_read: () => EBADF,
      fd_seek: () => EBADF,
      fd_fdstat_get: () => EBADF,
      /** Output (a panic message): text, line by line, to the console.
       * @param {number} fd @param {number} iovs @param {number} count @param {number} written */
      fd_write: (fd, iovs, count, written) => {
        let total = 0;
        for (let i = 0; i < count; i++) {
          const at = view().getUint32(iovs + i * 8, true);
          const length = view().getUint32(iovs + i * 8 + 4, true);
          pending[fd] =
            (pending[fd] ?? "") +
            new TextDecoder().decode(new Uint8Array(mem().buffer, at, length));
          total += length;
        }
        const lines = (pending[fd] ?? "").split("\n");
        pending[fd] = lines.pop() ?? "";
        for (const line of lines) console.error(`fvTrace engine: ${line}`);
        view().setUint32(written, total, true);
        return 0;
      },
      /** @param {number} countAt @param {number} sizeAt */
      environ_sizes_get: (countAt, sizeAt) => {
        view().setUint32(countAt, 0, true);
        view().setUint32(sizeAt, 0, true);
        return 0;
      },
      environ_get: () => 0,
      /** @param {number} _clock @param {bigint} _precision @param {number} at */
      clock_time_get: (_clock, _precision, at) => {
        view().setBigUint64(at, BigInt(Date.now()) * 1000000n, true);
        return 0;
      },
      /** @param {number} at @param {number} length */
      random_get: (at, length) => {
        crypto.getRandomValues(new Uint8Array(mem().buffer, at, length));
        return 0;
      },
    };
    const { instance } = await WebAssembly.instantiate(module, {
      wasi_snapshot_preview1: wasi,
      env: { emscripten_notify_memory_growth: () => undefined },
    });
    const exports = instance.exports;
    if (!(exports["memory"] instanceof WebAssembly.Memory))
      throw new EngineError("the engine exports no memory");
    memory = exports["memory"];
    const alloc = wasmFunction(exports, "fvtrace_alloc");
    const free = wasmFunction(exports, "fvtrace_free");
    const load = wasmFunction(exports, "fvtrace_load");
    const ask = wasmFunction(exports, "fvtrace_answer");
    wasmFunction(exports, "_initialize")();
    if (wasmFunction(exports, "fvtrace_init")() !== 0)
      throw new EngineError("the engine did not start");
    /** Copies bytes into a fresh engine buffer (at least one byte: malloc(0) may be null). */
    const put = (/** @type {Uint8Array} */ bytes) => {
      const at = alloc(Math.max(bytes.length, 1)) >>> 0;
      if (at === 0) throw new EngineError("the engine ran out of memory");
      new Uint8Array(mem().buffer, at, bytes.length).set(bytes);
      return at;
    };
    /** One string in, the engine's fresh buffer out (NULL = out of memory, E-abi). */
    const pass = (/** @type {WasmFunction} */ f, /** @type {string} */ input) => {
      const bytes = encoder.encode(input);
      const at = put(bytes);
      const lengthAt = put(new Uint8Array(4));
      const out = f(at, bytes.length, lengthAt) >>> 0;
      if (out === 0) throw new EngineError("the engine ran out of memory");
      free(at);
      const length = view().getUint32(lengthAt, true);
      free(lengthAt);
      const text = decoder.decode(new Uint8Array(mem().buffer, out, length));
      free(out);
      return text;
    };
    let dead = false;
    /** Runs one call; any failure ends the engine for good. @template T @param {() => T} f */
    const guarded = (f) => {
      if (dead) throw new EngineError("the engine stopped earlier");
      try {
        return f();
      } catch (e) {
        dead = true;
        throw e instanceof EngineError ? e : new EngineError(String(e));
      }
    };
    return {
      load: (snapshot) =>
        guarded(() => {
          const problem = pass(load, snapshot);
          if (problem === "") return null;
          // A snapshot the engine refuses ends it, as any failure does (E-state).
          dead = true;
          return problem;
        }),
      request: (text) => guarded(() => pass(ask, text)),
    };
  } catch (e) {
    throw e instanceof EngineError ? e : new EngineError(String(e));
  }
};
