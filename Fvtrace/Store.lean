import Fvtrace.Decode
import Fvtrace.Digest
import Fvtrace.Json

/-!
# Where fvTrace keeps its files

One folder per project in fvTrace's data folder (`FVTRACE_HOME`, else the platform data folder +
`fvtrace`): `trace.json`, `project.json` (the project folder it belongs to) and `cache.json`
(artifact digests). fvTrace writes into the project folder only where the user points it there:
`--trace` naming a file in it, `FVTRACE_HOME` or `skills install --dir` inside it.
-/

namespace Fvtrace.Store
open Fvtrace.Json

/-- The data folder + the current folder: `Env.detect` reads both once per run, tests pass their
own (Lean cannot set an environment variable in-process). -/
structure Env where
  home : System.FilePath
  cwd : System.FilePath

/-- `p` as given when absolute, else under `base` (`FilePath./` would append an absolute path). -/
def absolute (base : System.FilePath) (p : String) : System.FilePath :=
  if (System.FilePath.mk p).isAbsolute then p else base / p

def envVar (name : String) : IO (Option String) := do
  return (← IO.getEnv name).filter (!·.isEmpty)

/-- Per user and machine: entries are keyed by absolute paths, so a roaming profile would only
carry orphans. -/
def platformData : IO (Except String System.FilePath) := do
  if System.Platform.isWindows then
    if let some d ← envVar "LOCALAPPDATA" then return .ok d
    if let some h ← envVar "USERPROFILE" then return .ok (h / "AppData" / "Local")
  else
    let some h ← envVar "HOME" | return .error "cannot find the home folder; set FVTRACE_HOME"
    if System.Platform.isOSX then return .ok (h / "Library" / "Application Support")
    if let some x ← envVar "XDG_DATA_HOME" then
      if (System.FilePath.mk x).isAbsolute then return .ok x
    return .ok (h / ".local" / "share")
  return .error "cannot find the user's data folder; set FVTRACE_HOME"

def Env.detect : IO (Except String Env) := do
  let cwd ← IO.currentDir
  if let some h ← envVar "FVTRACE_HOME" then return .ok { home := absolute cwd h, cwd }
  return (← platformData).map fun base => { home := base / "fvtrace", cwd }

/-- `<folder name>-<12 hex digits of SHA-256 of its real path>`: readable, and distinct for
same-named folders. -/
def entryName (project : System.FilePath) : IO String := do
  let name := (project.fileName.getD "project").map fun c =>
    if c.isAlphanum || c == '-' || c == '_' || c == '.' then c else '-'
  let digest ← Digest.ofString project.toString
  return s!"{name}-{String.ofList (digest.toList.take 12)}"

structure Target where
  /-- The trace a command reads (`pin` + `review` write it back). -/
  trace : System.FilePath
  /-- The project folder (real path): receipts are checked against it. -/
  project : System.FilePath
  /-- The project's folder in the data folder (it may not exist yet). -/
  entry : System.FilePath

def Target.cacheFile (t : Target) : System.FilePath := t.entry / "cache.json"

def projectFile (entry : System.FilePath) : System.FilePath := entry / "project.json"

def projectJson (project : System.FilePath) : Value := .obj [("path", .str project.toString)]

/-- The project recorded beside a trace in the data folder, if `file` is one. -/
def recordedProject (env : Env) (file : System.FilePath) : IO (Option System.FilePath) := do
  try
    let some dir := file.parent | return none
    let some above := (← IO.FS.realPath dir).parent | return none
    unless above == (← IO.FS.realPath env.home) do return none
    match Json.parse (← IO.FS.readBinFile (projectFile dir)) with
    | .ok (.obj [("path", .str p)]) =>
      let p : System.FilePath := p
      unless ← p.isDir do return none
      return some (← IO.FS.realPath p)
    | _ => return none
  catch _ => return none

/-- Project = `--project DIR`, else the project recorded beside a data-folder `--trace`, else the
current folder. Trace = `--trace FILE`, else the project's trace in the data folder. -/
def resolve (env : Env) (project trace : Option String) : IO (Except String Target) := do
  let given ← match project with
    | some dir =>
      let p := absolute env.cwd dir
      unless ← p.isDir do return .error s!"no folder {dir}"
      pure (some (← IO.FS.realPath p))
    | none => pure none
  let file := trace.map (absolute env.cwd)
  let recorded ← match given, file with
    | none, some f => recordedProject env f
    | _, _ => pure none
  let root ← match given <|> recorded with
    | some r => pure r
    | none => IO.FS.realPath env.cwd
  let entry := env.home / (← entryName root)
  return .ok { trace := file.getD (entry / "trace.json"), project := root, entry }

/-- `path` (present or a dangling link) is a link: its real path is not its folder's real path +
its name. Lean 4.35's `symlinkMetadata` follows links on Windows (it is `metadata` there), so the
test goes through real paths. -/
def isLink (path : System.FilePath) : IO Bool := do
  let some parent := path.parent | return false
  let some name := path.fileName | return false
  try return (← IO.FS.realPath path) != (← IO.FS.realPath parent) / name
  catch _ => return true

/-- Deletes `dir` and everything in it, removing each link itself instead of entering it (Lean
4.35's `removeDirAll` enters a link to a folder on Windows and deletes what it points at). -/
partial def removeTree (dir : System.FilePath) : IO Unit := do
  for ent in ← dir.readDir do
    if (← ent.path.isDir) && !(← isLink ent.path) then removeTree ent.path
    -- A link to a folder goes with rmdir on Windows, with unlink elsewhere.
    else try IO.FS.removeFile ent.path catch _ => IO.FS.removeDir ent.path
  IO.FS.removeDir dir

/-- A well-formed trace to start from: the analysis + the existing subject, nothing claimed. -/
def starter (project : System.FilePath) : Trace :=
  let name := project.fileName.getD ""
  let title := if Decode.validText name then name else "Analysis"
  { analysis := { id := "A", title,
                  summary := "Replace this summary with what the analysis sets out to show." },
    subjects := [{ id := "S", title, kind := .existing }],
    questions := [], facts := [], claims := [] }

end Fvtrace.Store
