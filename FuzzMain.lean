import FvtraceFuzz

/-!
# `fvtrace-fuzz replay [DIR]` (gate stage `fuzz`)

Runs every fuzz target (`FvtraceFuzz.targets`) on each file under `DIR/<target>/` (default
`tests/fuzz`): the committed seed corpus + every crash input a campaign found, pinned. One line
per target; a failing input = `FAIL` naming its target, file + property code, rc 1. A folder
naming no target, or a target without inputs, fails too (a typo would replay nothing). Needs
`LEAN_ABORT_ON_PANIC` set: Lean's panic otherwise prints + returns a default the target may pass.
-/

open FvtraceFuzz

/-- Every regular file under `dir`, sorted (none when `dir` is absent). -/
def inputs (dir : System.FilePath) : IO (Array System.FilePath) := do
  unless ← dir.isDir do return #[]
  let all ← dir.walkDir
  let files ← all.filterM fun p => return !(← p.isDir)
  return files.qsort (·.toString < ·.toString)

def usage : String := "usage: fvtrace-fuzz replay [DIR]"

def replay (root : System.FilePath) : IO UInt32 := do
  let mut failed := false
  for entry in ← root.readDir do
    if (← entry.path.isDir) && !(targets.any (·.1 == entry.fileName)) then
      IO.eprintln s!"fuzz-replay: FAIL {entry.path}: no target is named {entry.fileName}"
      failed := true
  for (name, target) in targets do
    let files ← inputs (root / name)
    if files.isEmpty then
      IO.eprintln s!"fuzz-replay {name}: FAIL no inputs under {root / name}"
      failed := true
    let mut bad := 0
    for file in files do
      let code ← try target (← IO.FS.readBinFile file)
        catch e => do IO.eprintln s!"fuzz-replay {name}: {file}: {e}"; pure 255
      if code != 0 then
        IO.eprintln s!"fuzz-replay {name}: FAIL {file}: property {code}"
        bad := bad + 1
    if bad > 0 then failed := true
    IO.println s!"fuzz-replay {name}: {files.size} inputs, {bad} failed"
  return if failed then 1 else 0

def main (args : List String) : IO UInt32 := do
  let root ← match args with
    | ["replay"] => pure (some "tests/fuzz")
    | ["replay", dir] => pure (some dir)
    | _ => pure none
  let some root := root | IO.eprintln usage; return 2
  if (← IO.getEnv "LEAN_ABORT_ON_PANIC").isNone then
    IO.eprintln "fvtrace-fuzz: set LEAN_ABORT_ON_PANIC=1, so that a panic fails the replay"
    return 2
  replay root
