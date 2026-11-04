import FvtraceWasm
import Tests.Harness

namespace Tests.Wasm
open Tests FvtraceWasm System

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
/-- kernel.md E-build's export set, spelled here (never read off `Binary.requiredExports`, the list
under test): the memory (kind 2) + six functions (kind 0). -/
def contractExports : List (String × Nat) :=
  [("memory", 2), ("_initialize", 0), ("fvtrace_init", 0), ("fvtrace_alloc", 0),
    ("fvtrace_free", 0), ("fvtrace_load", 0), ("fvtrace_answer", 0)]

def goodExports : List (List UInt8) := contractExports.map fun (n, k) => exportOf n k

def problemsOf (b : ByteArray) : Except String (List String) := do
  return Binary.problems (← Binary.parse b)

def has (s sub : String) : Bool := (s.splitOn sub).length > 1

def pureTests : TestM Unit := do
  let bytes := fun (s : String) => s.toUTF8
  -- A zero byte ending the needle: a scan past the hay's end reads 0 there (`get!`'s default).
  checkEq "wasm: occurs finds a needle at the start, middle + end, and nowhere else"
    ([("ab", "abxy"), ("xy", "abxy"), ("bx", "abxy"), ("abxy", "abxy"), ("", "a"), ("ya", "abxy"),
      ("abxyz", "abxy"), ("yy", "abxy"), ("\x00", "ab"), ("b\x00", "ab")].map fun (n, h) =>
        Binary.occurs (bytes n) (bytes h))
    [true, true, true, true, true, false, false, false, false, false]
  checkEq "wasm: a module carrying mimalloc's message prefix keeps the allocator contract"
    (Binary.allocatorProblems (bytes "\x00data mimalloc: error: %s\x00")) []
  let app := fun (ps : Array String) => (Build.appOrder (ps.map (⟨·⟩))).map (·.toString)
  checkEq "wasm: the app's C links sorted by path, repeats kept"
    (app #["z.c", "y.c", "a.c", "z.c"], app #["z.c", "a.c", "z.c", "y.c"])
    (#["a.c", "y.c", "z.c", "z.c"], #["a.c", "y.c", "z.c", "z.c"])
  checkEq "wasm: a module without it (dlmalloc) breaks it"
    (Binary.allocatorProblems (bytes "\x00data mimalloc: warn\x00"))
    ["links an allocator other than mimalloc"]
  checkEq "wasm: a module importing what the page provides + exporting what it calls keeps the \
    link contract" (problemsOf (moduleOf goodImports goodExports)).toOption (some [])
  match Binary.parse (moduleOf goodImports goodExports) with
  | .ok m =>
    checkEq "wasm: every import + export is read" (m.imports.length, m.exports.length)
      (Binary.allowedImports.length, contractExports.length)
  | .error e => check "wasm: the planted module parses" false e
  let planted : List (String × ByteArray × String) :=
    [("an import the page does not provide",
      moduleOf (goodImports ++ [importFn "env" "probe"]) goodExports, "env.probe"),
     ("an allowed name imported as a memory",
      moduleOf (goodImports ++ [importMemory "wasi_snapshot_preview1" "fd_write"]) goodExports,
      "fd_write (kind 2)"),
     ("no fvtrace_answer export",
      moduleOf goodImports (goodExports.filter (· != exportOf "fvtrace_answer" 0)),
      "exports no fvtrace_answer"),
     ("memory exported as a function",
      moduleOf goodImports ((goodExports.filter (· != exportOf "memory" 2)) ++
        [exportOf "memory" 0]), "exports no memory of kind 2")]
  -- Each required export, missing alone, breaks the contract (the checker names it).
  let planted := planted ++ contractExports.map fun (n, k) =>
    (s!"no {n} export", moduleOf goodImports (goodExports.filter (· != exportOf n k)),
      s!"exports no {n}")
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
  -- LEB128 up to 10 bytes (the byte cap alone; no u64 range check): a custom section's size 1 in
  -- 10 bytes reads, in 11 does not.
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
  -- Renovate PR #5's edit: the linux-x86_64 line's version alone, its URL + digest still the old
  -- release's. One name, two versions = a half-bumped lock.
  let lock ← IO.FS.readFile "tools/wasm.lock"
  let half := "\n".intercalate <| (lock.splitOn "\n").map fun l =>
    if l.startsWith "emsdk " && (l.splitOn " ")[2]? == some "linux-x86_64" then
      " ".intercalate ((l.splitOn " ").set 1 "99.0.0")
    else l
  check "wasm: the planted relabel changed one line" (half != lock)
  match Lock.parse half with
  | .ok _ => check "wasm: a lock whose emsdk lines name two versions is refused" false
  | .error e =>
    check "wasm: the refusal names emsdk's two versions"
      ((e.splitOn "emsdk lines name versions").length == 2 && (e.splitOn "99.0.0").length == 2) e
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
    IO.FS.removeFile marker
    check "wasm: a folder without its marker does not count"
      (!(← Build.verified marker tree "pins"))
    IO.FS.writeFile marker "pins"
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
    let failed ← (Build.writeAtomic (dir / "cleanup.wasm") fun tmp => do
      IO.FS.createDir tmp
      throw (IO.userError "planted cleanup failure")).toBaseIO
    check "wasm: cleanup trouble preserves the writer's original error"
      (match failed with | .error e => has (toString e) "planted cleanup failure" | .ok _ => false)
    IO.FS.removeDir (dir / "cleanup.tmp.wasm")
    IO.FS.removeFile out
    IO.FS.createDir out
    let result ← (Build.writeAtomic out fun tmp => IO.FS.writeFile tmp "module").toBaseIO
    check "wasm: a failed rename keeps its destination and removes its temporary"
      ((result matches .error _) && (← out.isDir) && (← out.readDir).isEmpty &&
        !(← (dir / "engine.tmp.wasm").pathExists))
      (match result with | .ok _ => "write succeeded" | .error e => toString e)
    if !System.Platform.isWindows && !System.Platform.isOSX then
      let rsp := dir / "link.rsp.utf-8"
      let linked ← symlink "/dev/full" rsp
      check "wasm: a failing response-file writer can be planted" linked
      let cfg : Build.Config :=
        { root := dir, cache := dir, lean := "lean", leanSrc := dir,
          githash := "", appC := #[], out := dir / "linked.b64" }
      let tools : Build.Tools :=
        { python := "fvtrace-no-python", emcc := "emcc", emxx := "em++", env := #[] }
      let objs := Array.replicate 256 (dir / "".pushn 'x' 128)
      let result ← (Build.link cfg tools objs (dir / "linked.wasm")).toBaseIO
      let left ← rsp.pathExists
      check "wasm: a failed response-file write removes the file and preserves ENOSPC"
        ((result matches .error (.resourceExhausted _ 28 _)) && !left)
        (match result with | .ok _ => "write succeeded" | .error e => toString e)
      if left then unlink rsp

/-- An executable `sh` script `dir / name` running `body`. -/
def script (dir : FilePath) (name body : String) : IO FilePath := do
  let p := dir / name
  IO.FS.writeFile p s!"#!/bin/sh\n{body}\n"
  discard <| IO.Process.output { cmd := "chmod", args := #["+x", p.toString] }
  return p

def sh (cmd : String) (args : Array String) : IO Unit := do
  let out ← IO.Process.output { cmd, args }
  unless out.exitCode == 0 do throw (IO.userError s!"{cmd} {args}: {out.stderr}")

/-- sha256("header\n") + the `sha256sum` manifest of `include/a.h` holding it, computed by
coreutils `sha256sum` (an oracle apart from the shipped digest). -/
def headerSha : String := "565f129f4727ecb986814e0278dd2d0b21521159ac19a1292403826302d62462"
def headerManifestSha : String :=
  "396f445451f6f5166af3b5a19f23cb91623c58299eb34d1442ecc74d82034c84"

def configIn (dir : FilePath) : Build.Config :=
  { root := dir, cache := dir / "cache", lean := "lean", leanSrc := dir, githash := "g",
    appC := #[], out := dir / "engine.b64" }

/-- The fetch + generate steps on local stand-ins (POSIX: `sh` scripts, `curl` on a `file://`
URL, `tar`, `git` from a local repository), observed through their results. -/
def fetchTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let tree := dir / "tree"
    IO.FS.createDirAll (tree / "include")
    IO.FS.writeFile (tree / "include" / "a.h") "header\n"
    IO.FS.writeFile (tree / "b.txt") "other\n"
    checkEq "wasm: files lists a folder's files by their path inside the tree"
      (← Build.files tree ["include/"]) [("include/a.h", headerSha)]
    if System.Platform.isWindows then return
    let old ← script dir "py-old" "echo False"
    let failing ← script dir "py-failing" "echo True; exit 1"
    let good ← script dir "py-good" "echo True"
    let missing := (dir / "py-missing").toString
    -- Output that is not UTF-8 makes the probe throw (a missing command exits 255 instead).
    let garbled ← script dir "py-garbled" "printf '\\377True\\n'"
    checkEq "wasm: Python = the first candidate that runs, exits 0 and is 3.10 or later"
      (← Build.pythonFrom [old.toString, failing.toString, missing, garbled.toString,
        good.toString]) good.toString
    let refused ← (Build.pythonFrom [old.toString, missing]).toBaseIO
    check "wasm: no usable Python names the floor"
      (match refused with | .error e => has (toString e) "Python 3.10 or later" | .ok _ => false)
    -- Emscripten: a fresh cache downloads the pinned archive, verifies + extracts it.
    IO.FS.createDirAll (dir / "sdk" / "install" / "bin")
    IO.FS.writeFile (dir / "sdk" / "install" / "bin" / "emcc") "stub\n"
    sh "tar" #["-cf", (dir / "sdk.tar").toString, "-C", (dir / "sdk").toString, "install"]
    let sdk : Lock.Entry := { name := "emsdk", version := "0.0.1", key := "linux-x86_64",
                              sha256 := ← Fvtrace.Digest.ofFile (dir / "sdk.tar"),
                              url := s!"file://{dir / "sdk.tar"}" }
    match ← (Build.emsdk (configIn dir) sdk).toBaseIO with
    | .ok install =>
      check "wasm: a fresh cache fetches, checks + extracts the pinned Emscripten"
        (← (install / "bin" / "emcc").pathExists)
    | .error e =>
      check "wasm: a fresh cache fetches, checks + extracts the pinned Emscripten" false
        (toString e)
    -- A pinned tree: fetched at its commit, verified by its manifest digest, marked.
    let repo := dir / "repo"
    IO.FS.createDirAll repo
    IO.FS.rename (tree / "include") (repo / "include")
    IO.FS.rename (tree / "b.txt") (repo / "b.txt")
    let git := fun (args : Array String) => sh "git" (#["-C", repo.toString, "-c", "user.name=t",
      "-c", "user.email=t@t", "-c", "commit.gpgsign=false"] ++ args)
    git #["init", "-q"]
    git #["add", "-A"]
    git #["commit", "-qm", "fixture"]
    let head := (← IO.Process.output { cmd := "git", args := #["-C", repo.toString, "rev-parse",
      "HEAD"] }).stdout.trimAscii.toString
    let pin : Lock.Entry := { name := "fixture", version := "1", key := head,
                              sha256 := headerManifestSha, url := repo.toString }
    match ← (Build.gitTree (configIn dir) pin ["include/"]).toBaseIO with
    | .ok got =>
      check "wasm: a pinned tree fetches at its commit + verifies by its manifest"
        ((← (got / "include" / "a.h").pathExists) &&
          (← (dir / "cache" / s!"fixture-{head}.verified").pathExists))
    | .error e =>
      check "wasm: a pinned tree fetches at its commit + verifies by its manifest" false
        (toString e)
    let wrong := { pin with name := "wrong", sha256 := String.ofList (List.replicate 64 '0') }
    let r ← (Build.gitTree (configIn dir) wrong ["include/"]).toBaseIO
    check "wasm: a tree whose manifest differs from its pin is refused, unmarked"
      ((match r with | .error e => has (toString e) s!"manifest sha256 {headerManifestSha}"
                     | .ok _ => false) &&
        !(← (dir / "cache" / s!"wrong-{head}.verified").pathExists))
    -- Init's C: one file per module from the installed compiler (a stub writing its -c output),
    -- a missing one regenerated alone.
    let src := dir / "leansrc"
    IO.FS.createDirAll (src / "Init")
    IO.FS.writeFile (src / "Init.lean") ""
    IO.FS.writeFile (src / "Init" / "A.lean") ""
    let calls := dir / "lean-calls"
    let lean ← script dir "lean-stub" s!"printf x >>'{calls}'
while [ $# -gt 0 ]; do [ \"$1\" = -c ] && printf '/* C */' >\"$2\"; shift; done"
    let cfg := { configIn dir with lean, leanSrc := src }
    let cs ← Build.initC cfg
    check "wasm: Init's C = one generated file per module" (cs.size == 2 &&
      (← cs.allM fun c => c.pathExists))
    IO.FS.removeFile (cs[0]!)
    IO.FS.removeFile (cfg.cache / "init-c-g.complete")
    IO.FS.writeFile calls ""
    let again ← Build.initC cfg
    check "wasm: a missing module's C is generated again, alone"
      ((← again.allM fun c => c.pathExists) && (← IO.FS.readFile calls) == "x")

/-- The archive check on a planted file (SHA-256 over FFI: native suite). -/
def nativeTests : TestM Unit := do
  fetchTests
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
