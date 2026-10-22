import Fvtrace.Digest
import FvtraceWasm.Binary
import FvtraceWasm.Lock

/-!
# The page engine build (`kernel.md` E-build)

Fetches + verifies the pinned inputs (`tools/wasm.lock`), generates the C of every `Init` module
with the installed `lean` (the source's stage0 C differs from the release compiler's), compiles it
with the patched Lean runtime + the engine's own C (Lake's C for `Fvtrace.Snapshot`'s import
closure) to one standalone WebAssembly module, checks its link contract, and writes
base64(gzip(module)) for `FvtraceEngine` to embed. A fetched input is reused while its marker
names the pins that verified it; an object is reused under the digest of its source, flags and
toolchain, so a rebuild recompiles only what changed.
-/

namespace FvtraceWasm.Build
open System FvtraceWasm

structure Config where
  /-- The package folder: `tools/wasm.lock`, `tools/wasm/`, `c/page_engine.c`. -/
  root : FilePath
  /-- Fetched inputs, generated C, objects + the module (`.lake/build/wasm`). -/
  cache : FilePath
  lean : FilePath
  /-- The toolchain's Lean sources (`src/lean`): `Init` to generate C from. -/
  leanSrc : FilePath
  githash : String
  /-- Lake's C for `Fvtrace.Snapshot`'s import closure. -/
  appC : Array FilePath
  /-- base64(gzip(module)). -/
  out : FilePath

def fail {α : Type} (msg : String) : IO α := throw (IO.userError s!"fvtrace-wasm: {msg}")

def say (msg : String) : IO Unit := IO.println s!"fvtrace-wasm: {msg}"

/-- Forward slashes: Emscripten (Python) and its response files take them on every system. -/
def slashed (p : FilePath) : String := p.toString.replace "\\" "/"

/-- A program's output, or a failure naming it with the tail of its error output. -/
def runOut (cmd : String) (args : Array String) (cwd : Option FilePath := none)
    (env : Array (String × Option String) := #[]) : IO IO.Process.Output := do
  let out ← try IO.Process.output { cmd, args, cwd, env }
    catch e => fail s!"cannot run {cmd}: {e}"
  unless out.exitCode == 0 do
    let shown := " ".intercalate (args.toList.take 8)
    let tail := "\n".intercalate ((out.stderr.splitOn "\n").reverse.take 30).reverse
    fail s!"{cmd} {shown} … exited with {out.exitCode}:\n{tail}"
  return out

def run (cmd : String) (args : Array String) (cwd : Option FilePath := none)
    (env : Array (String × Option String) := #[]) : IO String :=
  return (← runOut cmd args cwd env).stdout

/-- `python3` or `python`, whichever is Python 3.10 or later (Emscripten's floor). -/
def python : IO String := do
  for cand in ["python3", "python"] do
    let ok ← try
        let out ← IO.Process.output
          { cmd := cand, args := #["-c", "import sys; print(sys.version_info >= (3, 10))"] }
        pure (out.exitCode == 0 && out.stdout.trimAscii.toString == "True")
      catch _ => pure false
    if ok then return cand
  fail "the page engine build needs Python 3.10 or later on PATH (python3 or python)"

/-- Runs `tasks` on Lean's thread pool (one worker per processor); every failure is reported. -/
def parallel {α : Type} (tasks : Array (IO α)) : IO (Array α) := do
  let running ← tasks.mapM (IO.asTask ·)
  let mut out := #[]
  let mut errors := #[]
  for t in running do
    match ← IO.wait t with
    | .ok a => out := out.push a
    | .error e => errors := errors.push (toString e)
  unless errors.isEmpty do
    fail s!"{errors.size} step(s) failed:\n{"\n".intercalate (errors.toList.take 5)}"
  return out

/-- `file` hashes to `pin`, or a failure naming both. -/
def verifyFile (name : String) (file : FilePath) (pin : String) : IO Unit := do
  let got ← Fvtrace.Digest.ofFile file
  unless got == pin do fail s!"{name}: sha256 {got}, but tools/wasm.lock pins {pin}"

/-- A marker beside a fetched input holds the pins that verified it. -/
def verified (marker : FilePath) (stamp : String) : IO Bool := do
  -- Nested `(← …)` actions run before `&&` decides, so the existence test needs its own branch.
  if ← marker.pathExists then return (← IO.FS.readFile marker) == stamp
  return false

def replaceDir (dir : FilePath) : IO Unit := do
  if ← dir.pathExists then IO.FS.removeDirAll dir

/-- Writes `path` whole or not at all (a stopped build leaves no half-written file). The
temporary keeps the extension: Emscripten picks its output format by it. -/
def writeAtomic (path : FilePath) (write : FilePath → IO Unit) : IO Unit := do
  let ext := (path.extension.map ("." ++ ·)).getD ""
  let tmp := path.withFileName s!"{path.fileStem.getD "out"}.tmp{ext}"
  write tmp
  IO.FS.rename tmp path

/-- Every file under `paths` (folders end in `/`) of `dir`: (path relative to `dir` with `/`,
sha256). -/
def files (dir : FilePath) (paths : List String) : IO (List (String × String)) := do
  let mut out := []
  for p in paths do
    let top := dir / (if p.endsWith "/" then (p.dropEnd 1).toString else p)
    let found ← if ← top.isDir then top.walkDir else pure #[top]
    for f in found do
      unless ← f.isDir do
        let rel := (f.toString.drop (dir.toString.length + 1)).toString.replace "\\" "/"
        out := out ++ [(rel, ← Fvtrace.Digest.ofFile f)]
  return out

/-! ## Pinned inputs -/

/-- The Emscripten release for this platform, extracted + configured: its `install` folder.
Archive + tree are named by their pin, so another pin never touches a verified copy. -/
def emsdk (cfg : Config) (e : Lock.Entry) : IO FilePath := do
  let id := s!"emsdk-{e.version}-{e.key}-{e.sha256.take 16}"
  let dir := cfg.cache / id
  let marker := cfg.cache / s!"{id}.verified"
  let install := dir / "install"
  if ← verified marker e.sha256 then return install
  replaceDir dir
  let name := (e.url.splitOn "/").getLast?.getD "archive"
  let archive := cfg.cache / "download" / s!"{id}-{name}"
  IO.FS.createDirAll (cfg.cache / "download")
  let cached ← if ← archive.pathExists then pure ((← Fvtrace.Digest.ofFile archive) == e.sha256)
    else pure false
  unless cached do
    say s!"downloading Emscripten {e.version} for {e.key}"
    discard <| run "curl" #["-fsSL", "--retry", "3", "-o", archive.toString, e.url]
  try verifyFile name archive e.sha256
  catch err =>
    IO.FS.removeFile archive
    throw err
  IO.FS.createDirAll dir
  discard <| run "tar" #["-xf", archive.toString, "-C", dir.toString]
  -- Emscripten reads this Python file; `FROZEN_CACHE` holds it to the release's prebuilt
  -- libraries (a missing one fails instead of being built here). Node is never needed.
  let py := fun (p : FilePath) => "'" ++ (slashed p).replace "'" "\\'" ++ "'"
  IO.FS.writeFile (dir / ".emscripten")
    s!"LLVM_ROOT = {py (install / "bin")}\nBINARYEN_ROOT = {py install}\nNODE_JS = 'node'\n\
      FROZEN_CACHE = True\n"
  IO.FS.writeFile marker e.sha256
  return install

/-- A sparse checkout of `paths` (folders end in `/`) at the pinned commit, verified by its
manifest digest; `patch` (when given) is applied after the check and named in the marker. -/
def gitTree (cfg : Config) (e : Lock.Entry) (paths : List String)
    (patch : Option FilePath := none) : IO FilePath := do
  let dir := cfg.cache / s!"{e.name}-{e.key}"
  let marker := cfg.cache / s!"{e.name}-{e.key}.verified"
  let patchDigest ← match patch with
    | some p => Fvtrace.Digest.ofFile p
    | none => pure "none"
  let stamp := s!"{e.key} {e.sha256} patch {patchDigest}"
  if ← verified marker stamp then return dir
  replaceDir dir
  say s!"fetching {e.name} {e.version} ({e.key.take 12})"
  -- Byte-exact checkout on every system (a CRLF conversion would change every digest).
  let git := fun (args : Array String) =>
    run "git" (#["-C", dir.toString, "-c", "core.autocrlf=false", "-c", "core.eol=lf"] ++ args)
  IO.FS.createDirAll dir
  discard <| git #["init", "-q"]
  discard <| git #["fetch", "-q", "--depth", "1", "--filter=blob:none", e.url, e.key]
  discard <| git (#["sparse-checkout", "set", "--no-cone"] ++ (paths.map ("/" ++ ·)).toArray)
  discard <| git #["-c", "advice.detachedHead=false", "checkout", "-q", "FETCH_HEAD"]
  let head := (← git #["rev-parse", "HEAD"]).trimAscii.toString
  unless head == e.key do fail s!"{e.name}: checked out {head}, but tools/wasm.lock pins {e.key}"
  let digest ← Fvtrace.Digest.ofString (Lock.manifest (← files dir paths))
  unless digest == e.sha256 do
    fail s!"{e.name}: manifest sha256 {digest}, but tools/wasm.lock pins {e.sha256}"
  if let some p := patch then discard <| git #["apply", p.toString]
  IO.FS.writeFile marker stamp
  return dir

/-- The libuv tag Lean's CMake builds for Emscripten (`GIT_TAG` after libuv's repository). -/
def libuvTag (cmake : String) : Option String := do
  let after ← (cmake.splitOn "GIT_REPOSITORY https://github.com/libuv/libuv")[1]?
  let rest ← (after.splitOn "GIT_TAG ")[1]?
  let tag := (rest.takeWhile (!·.isWhitespace)).toString
  return if tag.startsWith "v" then (tag.drop 1).toString else tag

/-- The runtime's sources: `RUNTIME_OBJS` in `src/runtime/CMakeLists.txt`. -/
def runtimeSources (cmake : String) : List String :=
  match (cmake.splitOn "RUNTIME_OBJS")[1]? with
  | some block =>
    let body := ((block.splitOn ")").head!.replace "\n" " ").replace "\t" " "
    (body.splitOn " ").filter (·.endsWith ".cpp")
  | none => []

/-! ## Generated sources -/

/-- `lean/config.h`, `lean/version.h` + `githash.h`, which the runtime's CMake would generate:
no mimalloc, a release of the pinned version. -/
def headers (cfg : Config) (version : String) : IO FilePath := do
  let dir := cfg.cache / s!"include-{cfg.githash}"
  IO.FS.createDirAll (dir / "lean")
  let v := (version.splitOn ".").toArray
  IO.FS.writeFile (dir / "lean" / "config.h")
    "#pragma once\n#include <lean/version.h>\n#define LEAN_IS_STAGE0 0\n"
  IO.FS.writeFile (dir / "lean" / "version.h") <|
    s!"#pragma once\n#define LEAN_VERSION_MAJOR {v.getD 0 "0"}\n" ++
    s!"#define LEAN_VERSION_MINOR {v.getD 1 "0"}\n#define LEAN_VERSION_PATCH {v.getD 2 "0"}\n" ++
    "#define LEAN_VERSION_IS_RELEASE 1\n#define LEAN_SPECIAL_VERSION_DESC \"\"\n" ++
    s!"#define LEAN_VERSION_STRING \"{version}\"\n" ++
    "#define LEAN_PLATFORM_TARGET \"wasm32-unknown-emscripten\"\n#define LEAN_MANUAL_ROOT \"\"\n"
  IO.FS.writeFile (dir / "githash.h") s!"#pragma once\n#define LEAN_GITHASH \"{cfg.githash}\"\n"
  return dir

/-- The C of every `Init` module, generated once per toolchain by its own compiler. -/
def initC (cfg : Config) : IO (Array FilePath) := do
  let dir := cfg.cache / s!"init-c-{cfg.githash}"
  let rel := fun (f : FilePath) =>
    (f.toString.drop (cfg.leanSrc.toString.length + 1)).toString.replace "\\" "/"
  -- Sorted: `walkDir` lists in directory order, which varies by file system, and this order is
  -- the link order (a different order moves functions, so different bytes).
  let mods := (((← (cfg.leanSrc / "Init").walkDir).filter (·.extension == some "lean")).push
    (cfg.leanSrc / "Init.lean")).qsort fun a b => rel a < rel b
  let outOf := fun (f : FilePath) => dir / ((rel f).dropEnd 5).toString |>.addExtension "c"
  let done := cfg.cache / s!"init-c-{cfg.githash}.complete"
  if ← done.pathExists then return mods.map outOf
  let todo ← mods.filterM fun f => return !(← (outOf f).pathExists)
  say s!"generating C for {todo.size} of {mods.size} Init modules (once per toolchain)"
  discard <| parallel <| todo.map fun f => do
    let out := outOf f
    if let some parent := out.parent then IO.FS.createDirAll parent
    writeAtomic out fun tmp => discard <| run cfg.lean.toString
      #["-R", cfg.leanSrc.toString, "-c", tmp.toString, f.toString]
  IO.FS.writeFile done s!"{mods.size}\n"
  return mods.map outOf

/-! ## Compile + link -/

structure Tools where
  python : String
  emcc : FilePath
  emxx : FilePath
  env : Array (String × Option String)

/-- One object per source, named by the digest of the source, its flags and the toolchain;
`true` = compiled now (else reused). -/
def compile (cfg : Config) (t : Tools) (toolchain : String) (flags : Array String)
    (src : FilePath) : IO (FilePath × Bool) := do
  let key ← Fvtrace.Digest.ofBytes <|
    (← IO.FS.readBinFile src) ++ ("\n".intercalate (toolchain :: flags.toList)).toUTF8
  let obj := cfg.cache / "obj" / s!"{key}.o"
  if ← obj.pathExists then return (obj, false)
  writeAtomic obj fun tmp => discard <| run t.python
    (#[slashed t.emcc] ++ flags ++ #["-c", slashed src, "-o", slashed tmp]) (cwd := cfg.cache)
    (env := t.env)
  return (obj, true)

/-- What the page's loader names (`FvtraceWasm.Binary.requiredExports`, Emscripten spelling). -/
def exportedFunctions : String :=
  ",".intercalate (["fvtrace_init", "fvtrace_alloc", "fvtrace_free", "fvtrace_evaluate"].map
    ("_" ++ ·))

/-- Linker warnings the build accepts: `Init` declares the temporary-file primitives without the
world token the runtime takes; the page never reaches them. -/
def allowedWarnings : List String :=
  ["function signature mismatch: lean_io_create_tempfile",
   "function signature mismatch: lean_io_create_tempdir"]

/-- Warning lines outside `allowedWarnings` (`>>>` lines continue the warning above them). -/
def unexpectedWarnings (stderr : String) : List String :=
  (stderr.splitOn "\n").filter fun l =>
    (l.splitOn "warning:").length > 1 && !allowedWarnings.any fun w => (l.splitOn w).length > 1

def link (cfg : Config) (t : Tools) (objs : Array FilePath) (wasm : FilePath) : IO Unit := do
  -- One argument per line, quoted for Emscripten's `shlex` reading (Windows' command line would
  -- not hold ~700 object paths).
  let rsp := cfg.cache / "link.rsp.utf-8"
  IO.FS.writeFile rsp <| String.join <| objs.toList.map fun o =>
    "\"" ++ ((slashed o).replace "\\" "\\\\").replace "\"" "\\\"" ++ "\"\n"
  let out ← runOut t.python (#[slashed t.emxx, "-O2", "-fwasm-exceptions", s!"@{slashed rsp}",
      "-o", slashed wasm, "-sSTANDALONE_WASM", "--no-entry", "-sALLOW_MEMORY_GROWTH=1",
      "-sSTACK_SIZE=1MB", s!"-sEXPORTED_FUNCTIONS={exportedFunctions}", "-Wl,--gc-sections"])
    (env := t.env)
  let extra := unexpectedWarnings out.stderr
  unless extra.isEmpty do fail s!"unexpected linker warnings:\n{"\n".intercalate extra}"

/-- base64(gzip(module)): Python's `gzip` (Lean has no compressor; Emscripten needs Python). -/
def compress (t : Tools) (wasm out : FilePath) : IO Unit :=
  writeAtomic out fun tmp => discard <| run t.python #["-c",
    "import base64, gzip, sys\n" ++
    "data = open(sys.argv[1], 'rb').read()\n" ++
    "text = base64.b64encode(gzip.compress(data, 9, mtime=0)).decode('ascii')\n" ++
    "open(sys.argv[2], 'w', newline='').write(text)\n", wasm.toString, tmp.toString]

def build (input : Config) : IO Unit := do
  -- Absolute paths: compiles run inside the cache folder.
  let here ← IO.currentDir
  let abs := fun (p : FilePath) => if p.isAbsolute then p else here / p
  -- App C sorted: with the sorted Init list + CMake's runtime order it fixes the link order,
  -- whatever order the caller passes (a different order moves functions: different bytes).
  let cfg := { input with root := abs input.root, cache := abs input.cache,
                          leanSrc := abs input.leanSrc, out := abs input.out,
                          appC := (input.appC.map abs).qsort fun a b => slashed a < slashed b }
  let lock ← match Lock.parse (← IO.FS.readFile (cfg.root / "tools" / "wasm.lock")) with
    | .ok es => pure es
    | .error m => fail m
  let platform ← match Lock.platform System.Platform.target with
    | .ok p => pure p
    | .error m => fail m
  let sdkPin ← match Lock.find lock "emsdk" (some platform) with
    | .ok e => pure e
    | .error m => fail m
  let rtPin ← match Lock.find lock "lean-runtime" with | .ok e => pure e | .error m => fail m
  let uvPin ← match Lock.find lock "libuv" with | .ok e => pure e | .error m => fail m
  unless rtPin.key == cfg.githash do
    fail s!"tools/wasm.lock pins the Lean runtime at {rtPin.key}, but the installed Lean is \
      {cfg.githash}; re-pin with `bash tools/pin-wasm.sh lean <version>`"
  IO.FS.createDirAll (cfg.cache / "obj")
  let py ← python
  let install ← emsdk cfg sdkPin
  let rt ← gitTree cfg rtPin ["src/runtime/", "src/include/", "src/util/", "src/CMakeLists.txt"]
    (some (cfg.root / "tools" / "wasm" / "lean-runtime.patch"))
  let uv ← gitTree cfg uvPin ["include/"]
  match libuvTag (← IO.FS.readFile (rt / "src" / "CMakeLists.txt")) with
  | some tag => unless tag == uvPin.version do
      fail s!"Lean {rtPin.version} builds libuv {tag} for Emscripten, but tools/wasm.lock pins \
        {uvPin.version}; re-pin with `bash tools/pin-wasm.sh lean {rtPin.version}`"
  | none => fail "cannot find the libuv tag in Lean's src/CMakeLists.txt"
  let gen ← headers cfg rtPin.version
  let initFiles ← initC cfg
  let rtFiles := runtimeSources (← IO.FS.readFile (rt / "src" / "runtime" / "CMakeLists.txt"))
  if rtFiles.isEmpty then fail "cannot find RUNTIME_OBJS in the runtime's CMakeLists.txt"
  let t : Tools :=
    { python := py, emcc := install / "emscripten" / "emcc.py",
      emxx := install / "emscripten" / "em++.py",
      env := #[("EM_CONFIG", some (slashed (install.parent.getD install / ".emscripten")))] }
  -- Everything a header or the compiler contributes, so a new pin recompiles every object.
  let toolchain := s!"{sdkPin.sha256} {rtPin.sha256} {uvPin.sha256} \
    {← Fvtrace.Digest.ofFile (cfg.root / "tools" / "wasm" / "lean-runtime.patch")} {cfg.githash}"
  -- Relative to the cache (each compile runs there): object keys stay the same wherever the
  -- checkout lives, so a moved tree or another host reuses them.
  let rel := fun (p : FilePath) => (slashed p).drop ((slashed cfg.cache).length + 1) |>.toString
  let includes := #[s!"-I{rel gen}", s!"-I{rel (rt / "src" / "include")}", s!"-I{rel (rt / "src")}",
    s!"-I{rel (uv / "include")}"]
  let cflags := #["-O2", "-DNDEBUG", "-DLEAN_EMSCRIPTEN", "-ffp-contract=off", "-fdata-sections",
    "-ffunction-sections", "-fvisibility=hidden", "-fwasm-exceptions"] ++ includes
  let cxxflags := cflags ++ #["-std=c++20", "-DLEAN_EXPORTING", "-DLEAN_BUILD_TYPE=\"Release\"",
    "-fvisibility-inlines-hidden", "-Wno-unused-parameter"]
  let cSources := initFiles ++ cfg.appC.push (cfg.root / "c" / "page_engine.c")
  let built ← parallel <|
    (rtFiles.toArray.map fun (f : String) =>
      compile cfg t toolchain cxxflags (rt / "src" / "runtime" / f)) ++
    cSources.map (compile cfg t toolchain cflags)
  let objs := built.map (·.1)
  say s!"{rtFiles.length} runtime + {cSources.size} C sources: \
    {(built.filter (·.2)).size} compiled, {(built.filter (!·.2)).size} reused"
  -- Checked before it replaces anything: a module that breaks the contract leaves no output.
  let wasm := cfg.cache / "engine.wasm"
  writeAtomic wasm fun tmp => do
    link cfg t objs tmp
    match Binary.parse (← IO.FS.readBinFile tmp) with
    | .error m => fail s!"engine.wasm: {m}"
    | .ok m =>
      let ps := Binary.problems m
      unless ps.isEmpty do fail s!"engine.wasm breaks its link contract:\n{"\n".intercalate ps}"
    compress t tmp cfg.out
  let bytes ← IO.FS.readBinFile wasm
  say s!"engine.wasm {bytes.size} bytes, sha256 {← Fvtrace.Digest.ofBytes bytes}"

end FvtraceWasm.Build
