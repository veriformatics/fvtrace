/-!
The exported page's engine: base64(gzip(WebAssembly)) of `Fvtrace.Snapshot`'s import closure,
built by `lake build` (target `engine`, `.agent/contracts/kernel.md` E-build), never committed.
-/

namespace FvtraceEngine

def wasmGzipBase64 : String := include_str ".lake/build/wasm/engine.b64"

/-- The license texts the engine build gathered (`FvtraceWasm.Build.licenses`), written by the same
target step as the engine, so its trace covers them. -/
def licenses : String := include_str ".lake/build/wasm/licenses.txt"

end FvtraceEngine
