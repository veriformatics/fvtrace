/-!
The exported page's engine: base64(gzip(WebAssembly)) of `Fvtrace.Snapshot`'s import closure,
built by `lake build` (target `engine`, `.agent/contracts/kernel.md` E-build), never committed.
-/

namespace FvtraceEngine

def wasmGzipBase64 : String := include_str ".lake/build/wasm/engine.b64"

end FvtraceEngine
