import Fvtrace
import Tests.Harness

namespace Tests.CliStore
open Tests Fvtrace

def count (s sub : String) : Nat := (s.splitOn sub).length - 1

def line (s : String) : String := s.trimAscii.toString

def decoded : IO Trace := do
  match decodeTrace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json") with
  | .ok t => pure t
  | .error ds => throw (IO.userError s!"fixture does not decode: {repr ds}")

def releaseWaiver : Waiver :=
  { rule := "L-release", claim := "C1",
    reason := "Released through the journal, recorded elsewhere." }

/-- The data folder, receipts + evaluation commands through the CLI, in temporary folders. -/
def tests : TestM Unit := do
  let fixture ← decoded
  IO.FS.withTempDir fun dir => do
    let home := dir / "home"
    let proj := dir / "proj"
    IO.FS.createDirAll (proj / "proofs")
    IO.FS.writeFile (proj / "proofs" / "Contrast.lean")
      "theorem contrast_correct : True := trivial\n"
    let projReal ← IO.FS.realPath proj
    let env : Store.Env := { home, cwd := proj }
    let run := fun (args : List String) => capture (Cli.runIn env args)
    let (rc, _, err) ← run ["check"]
    checkEq "store: check before init rc" rc 2
    check "store: check before init names the fix" (count err "run fvtrace init" == 1) err
    let (rc, initOut, _) ← run ["init"]
    checkEq "store: init rc" rc 0
    let (rc, pathOut, _) ← run ["path"]
    checkEq "store: path rc" rc 0
    let trace := line pathOut
    check "store: the trace sits in the data folder" (trace.startsWith home.toString) trace
    check "store: init names the trace" (count initOut trace == 1) initOut
    let (rc, out, _) ← run ["check"]
    checkEq "store: the starter trace is valid" rc 0
    check "store: check names the project" (count out s!"project: {projReal}" == 1) out
    let (rc, _, err) ← run ["init"]
    checkEq "store: init never overwrites rc" rc 2
    check "store: init names the existing trace" (count err "already exists" == 1) err
    -- The synthetic study as the project's trace.
    Cli.writeTrace trace fixture
    let (rc, _, _) ← run ["pin"]
    checkEq "cli: pin rc" rc 0
    let (rc, out, _) ← run ["check", "--strict"]
    checkEq "cli: check --strict after pin rc" rc 0
    check "cli: pinned receipt reads current" (count out "receipt O1: current" == 1) out
    check "store: the digest cache persists beside the trace"
      (← ((System.FilePath.mk trace).parent.getD "." / "cache.json").pathExists)
    -- --strict: a warning fails the check until a waiver records why it does not apply.
    let pinned ← match decodeTrace (← IO.FS.readBinFile trace) with
      | .ok t => pure t
      | .error _ => throw (IO.userError "the pinned trace does not decode")
    let release := { pinned with claims := pinned.claims.map fun c =>
      if c.id == "C1" then { c with level := .release } else c }
    let variant := (dir / "release.json").toString
    Cli.writeTrace variant release
    let (rc, _, _) ← run ["check", "--strict", "--trace", variant]
    checkEq "cli: --strict fails on an unwaived warning" rc 1
    Cli.writeTrace variant { release with waivers := [releaseWaiver] }
    let (rc, out, _) ← run ["check", "--strict", "--trace", variant]
    checkEq "cli: --strict passes a waived warning" rc 0
    check "cli: the waived warning stays listed" (count out "(waived: Released" == 1) out
    let (rc, _, _) ← run ["review", "--reviewer", "R. Viewer"]
    checkEq "cli: review rc" rc 0
    let (_, out, _) ← run ["check"]
    check "cli: review recorded" (count out "review: reviewed by R. Viewer" == 1) out
    -- Evaluation commands: text + JSON projections of one envelope.
    -- Evidence is read again unless --cached: a planted cache entry (same size + mtime, another
    -- digest) is used by --cached alone.
    let real ← IO.FS.realPath (proj / "proofs" / "Contrast.lean")
    let m ← real.metadata
    let planted : Receipt.Cache :=
      ({} : Receipt.Cache).insert real.toString (m.byteSize, m.modified.sec, m.modified.nsec, "x")
    planted.save ((System.FilePath.mk trace).parent.get! / "cache.json")
    let (_, out, _) ← run ["claims", "--cached"]
    check "cli: claims --cached reuses a digest recorded for the same size + mtime"
      (count out "C1 Not yet" == 1) out
    let (rc, out, _) ← run ["claims"]
    checkEq "cli: claims rc" rc 0
    check "cli: claims reads each evidence file again by default"
      (count out "C1 On assumption" == 1) out
    check "cli: claims prints the engine's sentence" (count out
      "C1 On assumption: Assuming “O1 entails C1.”: The contrast is the treatment effect." == 1)
      out
    check "cli: claims names the project" (count out s!"(project: {projReal})" == 1) out
    let (rc, out, _) ← run ["claims", "--whatif", "O2=checked,EN2=proved"]
    checkEq "cli: claims --whatif rc" rc 0
    check "cli: a what-if raises C2 + says so" (count out
      "C2 On assumption [what-if]: Assuming “The model assumptions hold.”: \
        Treatment raises the marker." == 1) out
    let (rc, _, err) ← run ["claims", "--whatif", "O3=proved"]
    checkEq "cli: a what-if above the route rc" rc 2
    check "cli: the route limit is named" (count err "O3 cannot reach proved" == 1) err
    let (_, evalOut, _) ← run ["eval"]
    let some envelope := (Json.parse evalOut.toUTF8).toOption
      | check "cli: eval prints JSON" false evalOut
    let projections := [("claims", ["subjects", "counts", "claims"]),
      ("gaps", ["work", "blockers"]), ("experiments", ["experiments"])]
    for (cmd, keys) in projections do
      let (rc, out, _) ← run [cmd, "--json"]
      checkEq s!"cli: {cmd} --json rc" rc 0
      check s!"cli: {cmd} --json = the envelope's projection"
        ((Json.parse out.toUTF8).toOption == some (Cli.project envelope
          (Cli.projectionKeys ++ keys))) out
    let (rc, out, _) ← run ["plan", "C2"]
    checkEq "cli: plan rc" rc 0
    check "cli: plan names the claim" (count out "C2 Not yet: Treatment raises the marker." == 1)
      out
    check "cli: plan names what no experiment raises"
      (count out "No suggested experiment raises EN2. It needs a new experiment or a ruling." == 1)
      out
    check "cli: plan sets apart a fact at its route's ceiling"
      (count out "Stays as it is: O3 (no route allows a stronger status)." == 1) out
    let (rc, _, _) ← run ["plan", "C9"]
    checkEq "cli: plan on an unknown claim rc" rc 2
    let (rc, out, _) ← run ["gaps"]
    checkEq "cli: gaps rc" rc 0
    check "cli: gaps lists closable facts" (count out
      "  EN2 O1, O2 and O3 entail C2.\n      Makes available alone: none. Needed by: C2.\n" == 1)
      out
    let (rc, out, _) ← run ["experiments"]
    checkEq "cli: experiments rc" rc 0
    check "cli: experiments shows what E1's failure does" (count out
      ("  E1 Check the result table (dry, days)\n" ++
        "      If it succeeds and the result is observed: no claim changes.\n" ++
        "      If it fails: C2 changes from Not yet to Cannot claim.\n") == 1) out
    -- A changed artifact stales its receipt.
    IO.FS.writeFile (proj / "proofs" / "Contrast.lean")
      "theorem contrast_correct : False := sorry\n"
    let (rc, _, _) ← run ["check", "--strict"]
    checkEq "cli: --strict fails on a stale receipt" rc 1
    -- --trace: a data-folder trace keeps its project from any folder; any other file reads
    -- the project of the current folder.
    let away : Store.Env := { home, cwd := dir }
    let (_, out, _) ← capture (Cli.runIn away ["check", "--trace", trace])
    check "store: a data-folder trace keeps its project" (count out s!"project: {projReal}" == 1)
      out
    let draft := (dir / "draft.json").toString
    Cli.writeTrace draft fixture
    let (_, out, _) ← run ["check", "--trace", draft]
    check "store: a draft reads the current folder's project"
      (count out s!"project: {projReal}" == 1) out
    -- Entries: same-named folders differ, a symlinked folder shares its target's entry.
    IO.FS.createDirAll (dir / "a" / "analysis")
    IO.FS.createDirAll (dir / "b" / "analysis")
    let (_, pa, _) ← capture (Cli.runIn away ["path", "--project", "a/analysis"])
    let (_, pb, _) ← capture (Cli.runIn away ["path", "--project", "b/analysis"])
    check "store: same-named folders get distinct entries" (line pa != line pb) s!"{pa} {pb}"
    let linked ← symlink proj (dir / "link") true
    check "store: a symlink to the project can be made" linked
    let (_, pl, _) ← capture (Cli.runIn away ["path", "--project", "link"])
    checkEq "store: a symlinked folder shares its target's entry" (line pl) trace
    let (rc, _, err) ← capture (Cli.runIn away ["path", "--project", "absent"])
    checkEq "store: a missing --project folder rc" rc 2
    check "store: the missing folder is named" (count err "no folder absent" == 1) err
    -- Exit codes on traces that do not decode or are not well-formed.
    let bad := (dir / "bad.json").toString
    IO.FS.writeFile bad "{}"
    let (rc, _, _) ← run ["pin", "--trace", bad]
    checkEq "cli: pin on a trace that does not decode rc" rc 1
    let (rc, _, _) ← run ["review", "--trace", bad, "--reviewer", "R. Viewer"]
    checkEq "cli: review on a trace that does not decode rc" rc 1
    let (rc, _, _) ← run ["claims", "--trace", bad]
    checkEq "cli: claims on a trace that does not decode rc" rc 1
    let broken := (dir / "broken.json").toString
    Cli.writeTrace broken
      { fixture with claims := fixture.claims.map fun c => { c with needs := c.needs ++ ["Z9"] } }
    let (rc, _, _) ← run ["review", "--trace", broken, "--reviewer", "R. Viewer"]
    checkEq "cli: review on an ill-formed trace rc" rc 1
    let (rc, _, _) ← run ["claims", "--trace", broken]
    checkEq "cli: claims on an ill-formed trace rc" rc 1
    let absent := (dir / "absent.json").toString
    Cli.writeTrace absent { fixture with facts := fixture.facts.map fun f =>
      if f.id == "O1" then { f with evidence := f.evidence.map fun ev =>
        { ev with artifacts := ev.artifacts.map fun a => { a with path := "proofs/Absent.lean" } } }
      else f }
    let (rc, _, err) ← run ["pin", "--trace", absent]
    checkEq "cli: pin with a missing artifact rc" rc 1
    check "cli: pin names the missing artifact" (count err "proofs/Absent.lean" == 1) err
    let (rc, _, _) ← run ["review", "--trace", draft, "--reviewer", "a\x1bb"]
    checkEq "cli: review rejects control characters in the name" rc 2
    let (rc, _, _) ← run ["review", "--trace", draft]
    checkEq "cli: review without --reviewer rc" rc 2
    -- check on files named directly (receipts against the current folder's project).
    let repo : Store.Env := { home, cwd := ← IO.currentDir }
    let (rc, out, _) ← capture (Cli.runIn repo
      ["check", "--trace", "tests/fixtures/synthetic.trace.json"])
    checkEq "cli: check valid rc" rc 0
    checkEq "cli: check valid output" out
      (s!"{repo.cwd / "tests/fixtures/synthetic.trace.json"}: valid\n" ++
        s!"  project: {← IO.FS.realPath repo.cwd}\n" ++
        "  receipt O1: stale (missing proofs/Contrast.lean, statement-changed)\n" ++
        "  review: draft\n")
    let (rc, out, _) ← capture (Cli.runIn repo
      ["check", "--json", "--trace", "tests/schema/cases/invalid-status.json"])
    checkEq "cli: check invalid rc" rc 1
    check "cli: check --json is JSON" ((Json.parse out.toUTF8).toOption.isSome)
    let (rc, _, err) ← capture (Cli.runIn repo ["check", "--trace", "tests/fixtures/absent.json"])
    checkEq "cli: check unreadable rc" rc 2
    check "cli: unreadable file named"
      (err.startsWith s!"fvtrace: cannot read {repo.cwd / "tests/fixtures/absent.json"}") err
    let entries ← (proj / "proofs").readDir
    checkEq "store: nothing written into the project"
      (entries.map (·.fileName)).toList ["Contrast.lean"]
    checkEq "store: the project folder holds only what it had"
      ((← proj.readDir).map (·.fileName)).toList ["proofs"]

end Tests.CliStore
