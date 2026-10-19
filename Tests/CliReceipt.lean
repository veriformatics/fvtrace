import Fvtrace
import Tests.Harness

namespace Tests.CliReceipt
open Tests Fvtrace

/-- `pin` + `review` + `check --project` through the CLI, in a temporary project + data folder. -/
def tests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let proj := dir / "proj"
    IO.FS.createDirAll (proj / "proofs")
    IO.FS.writeFile (proj / "proofs" / "Contrast.lean")
      "theorem contrast_correct : True := trivial\n"
    let trace := (dir / "trace.json").toString
    IO.FS.writeBinFile trace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json")
    let (rc, _, _) ← capture (Cli.run ["pin", trace, "--project", proj.toString])
    checkEq "cli: pin rc" rc 0
    let (rc, out, _) ← capture (Cli.run ["check", trace, "--project", proj.toString, "--strict"])
    checkEq "cli: check --strict after pin rc" rc 0
    check "cli: pinned receipt reads current" ((out.splitOn "receipt O1: current").length == 2) out
    let (rc, _, _) ← capture (Cli.run ["review", trace, "--reviewer", "R. Viewer"])
    checkEq "cli: review rc" rc 0
    let (_, out, _) ← capture (Cli.run ["check", trace])
    check "cli: review recorded" ((out.splitOn "review: reviewed by R. Viewer").length == 2) out
    IO.FS.writeFile (proj / "proofs" / "Contrast.lean")
      "theorem contrast_correct : False := sorry\n"
    let (rc, _, _) ← capture (Cli.run ["check", trace, "--project", proj.toString, "--strict"])
    checkEq "cli: --strict fails on a stale receipt" rc 1
    let (rc, _, err) ← capture (Cli.run ["pin", trace])
    checkEq "cli: pin without --project rc" rc 2
    check "cli: pin names the missing option" (err.startsWith "fvtrace: pin needs --project DIR")
    let (rc, _, _) ← capture (Cli.run ["review", trace, "--reviewer", "a\x1bb"])
    checkEq "cli: review rejects control characters in the name" rc 2
    let entries ← (proj / "proofs").readDir
    checkEq "cli: nothing written into the project"
      (entries.map (·.fileName)).toList ["Contrast.lean"]

end Tests.CliReceipt
