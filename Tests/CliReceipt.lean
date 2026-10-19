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
    let bad := (dir / "bad.json").toString
    IO.FS.writeFile bad "{}"
    let (rc, _, _) ← capture (Cli.run ["pin", bad, "--project", proj.toString])
    checkEq "cli: pin on a trace that does not decode rc" rc 1
    let (rc, _, _) ← capture (Cli.run ["review", bad, "--reviewer", "R. Viewer"])
    checkEq "cli: review on a trace that does not decode rc" rc 1
    let base ← match decodeTrace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json") with
      | .ok t => pure t
      | .error ds => throw (IO.userError s!"fixture does not decode: {repr ds}")
    let broken := (dir / "broken.json").toString
    Cli.writeTrace broken
      { base with claims := base.claims.map fun c => { c with needs := c.needs ++ ["Z9"] } }
    let (rc, _, _) ← capture (Cli.run ["review", broken, "--reviewer", "R. Viewer"])
    checkEq "cli: review on an ill-formed trace rc" rc 1
    let absent := (dir / "absent.json").toString
    Cli.writeTrace absent { base with facts := base.facts.map fun f =>
      if f.id == "O1" then { f with evidence := f.evidence.map fun ev =>
        { ev with artifacts := ev.artifacts.map fun a => { a with path := "proofs/Absent.lean" } } }
      else f }
    let (rc, _, err) ← capture (Cli.run ["pin", absent, "--project", proj.toString])
    checkEq "cli: pin with a missing artifact rc" rc 1
    check "cli: pin names the missing artifact" ((err.splitOn "proofs/Absent.lean").length == 2) err
    let entries ← (proj / "proofs").readDir
    checkEq "cli: nothing written into the project"
      (entries.map (·.fileName)).toList ["Contrast.lean"]

end Tests.CliReceipt
