import FvtraceWasm

/-- Build tool for the exported page's engine, run by the Lake target `engine` (`lakefile.lean`):
`fvtrace-wasm --root DIR --cache DIR --lean FILE --lean-src DIR --githash HASH --out FILE C…`. -/
def main (args : List String) : IO UInt32 := do
  let rec opts : List String → List (String × String) → Except String (List (String × String) ×
      List String)
    | k :: v :: rest, acc =>
      if k.startsWith "--" then opts rest ((k, v) :: acc) else .ok (acc, k :: v :: rest)
    | rest, acc => .ok (acc, rest)
  let some (kv, cFiles) := (opts args []).toOption | return 2
  let get := fun (k : String) => kv.lookup s!"--{k}"
  let (some root, some cache, some lean, some leanSrc, some githash, some out) :=
      (get "root", get "cache", get "lean", get "lean-src", get "githash", get "out")
    | IO.eprintln "usage: fvtrace-wasm --root DIR --cache DIR --lean FILE --lean-src DIR \
        --githash HASH --out FILE C-FILE…"
      return 2
  try
    FvtraceWasm.Build.build
      { root, cache, lean, leanSrc, githash, out, appC := cFiles.toArray.map (⟨·⟩) }
    return 0
  catch e =>
    IO.eprintln e
    return 1
