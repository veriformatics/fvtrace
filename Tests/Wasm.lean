import FvtraceWasm
import Tests.Harness

namespace Tests.Wasm
open Tests FvtraceWasm

/-! ## Planted modules, byte by byte -/

def leb (n : Nat) : List UInt8 :=
  if n < 128 then [n.toUInt8] else (n % 128 + 128).toUInt8 :: leb (n / 128)
termination_by n
decreasing_by omega

def wname (s : String) : List UInt8 := leb s.utf8ByteSize ++ s.toUTF8.toList

def wsection (id : Nat) (body : List UInt8) : List UInt8 := id.toUInt8 :: (leb body.length ++ body)

def importFn (m n : String) : List UInt8 := wname m ++ wname n ++ [0] ++ leb 0
def importMemory (m n : String) : List UInt8 := wname m ++ wname n ++ [2, 0, 1]
def exportOf (n : String) (kind : Nat) : List UInt8 := wname n ++ [kind.toUInt8] ++ leb 0

def header : List UInt8 := [0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]

/-- A module with a custom section first (skipped), then imports + exports. -/
def moduleOf (imports exports : List (List UInt8)) : ByteArray :=
  ⟨(header ++ wsection 0 (wname "custom" ++ [1, 2, 3]) ++
    wsection 2 (leb imports.length ++ imports.flatten) ++
    wsection 7 (leb exports.length ++ exports.flatten)).toArray⟩

def goodImports : List (List UInt8) := Binary.allowedImports.map fun (m, n) => importFn m n
def goodExports : List (List UInt8) := Binary.requiredExports.map fun (n, k) => exportOf n k

def problemsOf (b : ByteArray) : Except String (List String) := do
  return Binary.problems (← Binary.parse b)

def has (s sub : String) : Bool := (s.splitOn sub).length > 1

def pureTests : TestM Unit := do
  checkEq "wasm: a module importing what the page provides + exporting what it calls keeps the \
    link contract" (problemsOf (moduleOf goodImports goodExports)).toOption (some [])
  match Binary.parse (moduleOf goodImports goodExports) with
  | .ok m =>
    checkEq "wasm: every import + export is read" (m.imports.length, m.exports.length)
      (Binary.allowedImports.length, Binary.requiredExports.length)
  | .error e => check "wasm: the planted module parses" false e
  let planted : List (String × ByteArray × String) :=
    [("an import the page does not provide",
      moduleOf (goodImports ++ [importFn "env" "probe"]) goodExports, "env.probe"),
     ("an allowed name imported as a memory",
      moduleOf (goodImports ++ [importMemory "wasi_snapshot_preview1" "fd_write"]) goodExports,
      "fd_write (kind 2)"),
     ("no fvtrace_evaluate export",
      moduleOf goodImports (goodExports.filter (· != exportOf "fvtrace_evaluate" 0)),
      "exports no fvtrace_evaluate"),
     ("memory exported as a function",
      moduleOf goodImports ((goodExports.filter (· != exportOf "memory" 2)) ++
        [exportOf "memory" 0]), "exports no memory of kind 2")]
  for (name, b, cause) in planted do
    match problemsOf b with
    | .ok [p] => check s!"wasm: {name} breaks the link contract" (has p cause) p
    | other =>
      check s!"wasm: {name} breaks the link contract (one problem)" false s!"{repr other}"
  -- Each import layout is read to the next entry (a misread shifts every later byte).
  let after := importFn "env" "after"
  let layouts : List (String × List UInt8) :=
    [("a memory with a maximum (two-byte LEB128)",
      wname "env" ++ wname "m" ++ [2, 1, 1] ++ leb 300),
     ("a shared memory with a maximum", wname "env" ++ wname "m" ++ [2, 3, 1, 2]),
     ("a 64-bit memory", wname "env" ++ wname "m" ++ [2, 4] ++ leb 128),
     ("a 64-bit memory with a maximum", wname "env" ++ wname "m" ++ [2, 5, 1] ++ leb 128),
     ("a funcref table", wname "env" ++ wname "t" ++ [1, 0x70, 0, 4]),
     ("a nullable typed table", wname "env" ++ wname "t" ++ [1, 0x63, 0x70, 1, 1, 9]),
     ("a non-null typed table", wname "env" ++ wname "t" ++ [1, 0x64, 0x05, 0, 1]),
     ("a global", wname "env" ++ wname "g" ++ [3, 0x7f, 0]),
     ("a tag (typeidx 128: a LEB128 byte of exactly 0x80)", wname "env" ++ wname "e" ++ [4, 0] ++
       leb 128)]
  for (name, entry) in layouts do
    checkEq s!"wasm: {name} is read to the next import"
      ((Binary.parse (moduleOf [entry, after] goodExports)).toOption.map
        (·.imports.map (·.name) |>.getLast?)) (some (some "after"))
  -- LEB128 up to 10 bytes (a u64): a custom section's size 1 in 10 bytes reads, in 11 does not.
  let sized := fun (n : Nat) =>
    (⟨(header ++ [0, 0x81] ++ List.replicate (n - 2) 0x80 ++ [0, 7]).toArray⟩ : ByteArray)
  check "wasm: a 10-byte LEB128 reads" (Binary.parse (sized 10)).isOk
  check "wasm: an 11-byte LEB128 is refused" (Binary.parse (sized 11)).toOption.isNone
  let good := (moduleOf goodImports goodExports).toList
  let malformed : List (String × ByteArray) :=
    [("a truncated module", ⟨(good.take 30).toArray⟩),
     ("another magic", ⟨(0x01 :: good.drop 1).toArray⟩),
     ("a section past the end", ⟨(header ++ [2, 100, 0]).toArray⟩),
     ("a name that is not UTF-8", ⟨(header ++ wsection 2 ([1, 1, 0xff, 1, 0x61, 0, 0])).toArray⟩),
     ("an 11-byte LEB128", ⟨(header ++ [2] ++ List.replicate 10 0x80 ++ [0]).toArray⟩),
     ("an unknown import kind", ⟨(header ++ wsection 2 ([1] ++ wname "env" ++ wname "x" ++
        [9, 0])).toArray⟩)]
  for (name, b) in malformed do
    check s!"wasm: {name} is refused" (Binary.parse b).toOption.isNone
  -- The lock file as committed: every platform the build maps to has its pinned archive.
  match Lock.parse (← IO.FS.readFile "tools/wasm.lock") with
  | .error e => check "wasm: tools/wasm.lock parses" false e
  | .ok es =>
    checkEq "wasm: the lock pins Emscripten for five platforms + the runtime + libuv"
      (es.map (·.name)) (List.replicate 5 "emsdk" ++ ["lean-runtime", "libuv"])
    for p in ["linux-x86_64", "linux-aarch64", "darwin-x86_64", "darwin-aarch64",
        "windows-x86_64"] do
      check s!"wasm: the lock pins Emscripten for {p}" (Lock.find es "emsdk" (some p)).isOk
    check "wasm: one lean-runtime line" (Lock.find es "lean-runtime").isOk
    check "wasm: two emsdk lines for one platform are refused"
      (Lock.find (es ++ es.take 1) "emsdk" (some (es.head!.key))).toOption.isNone
  for (target, want) in [("x86_64-unknown-linux-gnu", some "linux-x86_64"),
      ("aarch64-unknown-linux-gnu", some "linux-aarch64"),
      ("arm64-apple-darwin23.6.0", some "darwin-aarch64"),
      ("x86_64-apple-darwin", some "darwin-x86_64"),
      ("x86_64-w64-windows-gnu", some "windows-x86_64"),
      ("x86_64-w64-mingw32", some "windows-x86_64"),
      ("riscv64-unknown-linux-gnu", none), ("x86_64-unknown-freebsd", none)] do
    checkEq s!"wasm: platform of {target}" (Lock.platform target).toOption want
  let digest := String.ofList (List.replicate 64 'a')
  for (line, ok) in [(s!"emsdk 1 linux-x86_64 {digest} https://x/y", true),
      (s!"emsdk 1 linux-x86_64 {digest} http://x/y", false),
      ("emsdk 1 linux-x86_64 abc https://x/y", false),
      (s!"emsdk 1 linux-x86_64 {String.ofList (List.replicate 64 'g')} https://x/y", false),
      (s!"emsdk 1 linux-x86_64 {String.ofList (List.replicate 64 'A')} https://x/y", false),
      (s!"emsdk 1 {digest} https://x/y", false), ("# a comment", true), ("", true)] do
    checkEq s!"wasm: lock line {repr line}" (Lock.parseLine line).isOk ok
  checkEq "wasm: a manifest = sha256sum lines sorted by path"
    (Lock.manifest [("src/b.h", "22"), ("src/a.h", "11")]) "11  src/a.h\n22  src/b.h\n"
  let cmake := "ExternalProject_Add(\n    libuv\n    PREFIX libuv\n" ++
    "    GIT_REPOSITORY https://github.com/libuv/libuv\n    # Sync version with flake.nix\n" ++
    "    GIT_TAG v1.48.0\n    CMAKE_ARGS\n"
  checkEq "wasm: the libuv tag Lean's CMake builds" (Build.libuvTag cmake) (some "1.48.0")
  checkEq "wasm: no libuv repository, no tag" (Build.libuvTag "GIT_TAG v9") none
  checkEq "wasm: the runtime's sources from its CMake list"
    (Build.runtimeSources "set(\n  RUNTIME_OBJS\n  debug.cpp\n\tthread.cpp\n  uv/tcp.cpp\n)\nx.cpp")
    ["debug.cpp", "thread.cpp", "uv/tcp.cpp"]
  let allowed := "wasm-ld: warning: function signature mismatch: lean_io_create_tempdir\n" ++
    ">>> defined as () -> i32 in Init_System_IO.o\n>>> defined as (i32) -> i32 in io.o\n"
  checkEq "wasm: the accepted linker warnings pass" (Build.unexpectedWarnings allowed) []
  let planted := "wasm-ld: warning: function signature mismatch: initialize_fvtrace_Fvtrace_X"
  checkEq "wasm: another linker warning is reported"
    (Build.unexpectedWarnings (allowed ++ planted)) [planted]
  let prefixed := "wasm-ld: warning: function signature mismatch: lean_io_create_tempfile_extra"
  checkEq "wasm: a warning naming an allowed one's prefix is reported (exact match)"
    (Build.unexpectedWarnings prefixed) [prefixed]

/-- Fetched-input markers: one counts only beside its folder; replacing the folder removes it
first, so a failed refresh leaves no marker vouching for a half-written folder. -/
def markerTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let tree := dir / "tree"
    let marker := dir / "tree.verified"
    IO.FS.writeFile marker "pins"
    check "wasm: a marker without its folder does not count"
      (!(← Build.verified marker tree "pins"))
    IO.FS.createDirAll tree
    check "wasm: a marker beside its folder counts for its own pins alone"
      ((← Build.verified marker tree "pins") && !(← Build.verified marker tree "other"))
    Build.replaceDir tree marker
    check "wasm: replacing a folder removes its marker first"
      (!(← marker.pathExists) && !(← tree.pathExists))

/-- A step that fails after writing its temporary leaves neither the temporary nor its target, so
the cache never holds a module that failed its checks beside the one that passed. -/
def writeTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let out := dir / "engine.wasm"
    let r ← (Build.writeAtomic out fun tmp => do
      IO.FS.writeFile tmp "planted"
      throw (IO.userError "planted failure")).toBaseIO
    check "wasm: a failed write fails" (r matches .error _)
    check "wasm: a failed write leaves no temporary" (!(← (dir / "engine.tmp.wasm").pathExists))
    check "wasm: a failed write leaves no target" (!(← out.pathExists))
    Build.writeAtomic out fun tmp => IO.FS.writeFile tmp "module"
    check "wasm: a write replaces its target whole"
      ((← IO.FS.readFile out) == "module" && !(← (dir / "engine.tmp.wasm").pathExists))

/-- The archive check on a planted file (SHA-256 over FFI: native suite). -/
def nativeTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let f := dir / "archive.tar.xz"
    IO.FS.writeFile f "planted"
    let pin ← Fvtrace.Digest.ofFile f
    let ok ← try Build.verifyFile "archive" f pin; pure true catch _ => pure false
    check "wasm: an archive with its pinned digest verifies" ok
    let wrong := String.ofList (List.replicate 64 '0')
    match ← (Build.verifyFile "archive" f wrong).toBaseIO with
    | .ok _ => check "wasm: an archive with another digest is refused" false
    | .error e =>
      check "wasm: an archive with another digest is refused, naming both digests"
        (has (toString e) pin && has (toString e) wrong) (toString e)

end Tests.Wasm
