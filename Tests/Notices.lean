import Fvtrace
import Tests.Harness
import Std.Time

namespace Tests.Notices
open Tests Fvtrace

abbrev J := Json.Value

def parsed (text : String) : J := (Json.parse text.toUTF8).toOption.getD .null

def member (value : J) (key : String) : J := (field value key).getD .null

def same (a b : J) : Bool := a.canonical == b.canonical

def items : J → List J
  | .arr xs => xs
  | _ => []

def put (value : J) (key : String) (next : Option J) : J :=
  .obj ((fields value).filter (·.1 != key) ++ next.toList.map (key, ·))

def atPath (value : J) (path : List String) : J := path.foldl member value

def editPath (value : J) (path : List String) (f : J → J) : J :=
  match path with
  | [] => f value
  | key :: rest => put value key (some (editPath (member value key) rest f))

def editRecord (value : J) (collection : String) (position : Nat) (f : J → J) : J :=
  put value collection (some (.arr ((items (member value collection)).zipIdx.map fun (x, i) =>
    if i == position then f x else x)))

def editReplay (value : J) (f : J → J) (collection := "facts") (position := 0) : J :=
  editRecord value collection position (fun x => editPath x ["evidence", "replay"] f)

def replayOf (value : J) (collection := "facts") (position := 0) : J :=
  atPath ((items (member value collection)).getD position .null) ["evidence", "replay"]

def notice (date reason : String) : J := .obj [("date", .str date), ("reason", .str reason)]

def withNotice (value : J) (n : Option J) (collection := "facts") (position := 0) : J :=
  editReplay value (put · "failed" n) collection position

def count (text sub : String) : Nat := (text.splitOn sub).length - 1

def has (text sub : String) : Bool := count text sub > 0

def write (path : System.FilePath) (value : J) : IO Unit :=
  IO.FS.writeFile path (value.canonical ++ "\n")

def readJson (path : System.FilePath) : IO J := parsed <$> IO.FS.readFile path

def readIf (path : System.FilePath) : IO String := do
  if ← path.pathExists then IO.FS.readFile path else pure ""

structure Fixture where
  dir : System.FilePath
  project : System.FilePath
  trace : System.FilePath
  home : System.FilePath
  entry : System.FilePath
  app : String
  pinned : J

def Fixture.run (f : Fixture) (args : List String) : IO (UInt32 × String × String) :=
  capture (Cli.runIn { home := f.home, cwd := f.project }
    (args ++ ["--trace", f.trace.toString]))

def Fixture.command (f : Fixture) (steps : List String) : J :=
  .arr (([f.app, "--replay-fixture"] ++ steps).map .str)

def Fixture.setCommand (f : Fixture) (value : J) (steps : List String) : J :=
  editReplay value (put · "command" (some (f.command steps)))

def Fixture.log (f : Fixture) : IO (List J) := do
  let text ← readIf (f.entry / "replays.log")
  return (text.splitOn "\n").filterMap fun line =>
    if line.isEmpty then none else (Json.parse line.toUTF8).toOption

/-- JSON text + CLI alone: the fixture names no feature-specific Lean field. -/
def withFixture (test : Fixture → TestM Unit) : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let project := dir / "project"
    let home := dir / "home"
    IO.FS.createDirAll project
    IO.FS.writeFile (project / "proof.bin") "proof\n"
    IO.FS.writeFile (project / "output.bin") "stable\n"
    IO.FS.writeFile (project / "gate.bin") ""
    let app := (← IO.appPath).toString
    let run := fun args => capture (Cli.runIn { home, cwd := project } args)
    let _ ← run ["init"]
    let (_, out, _) ← run ["path"]
    let trace : System.FilePath := out.trimAscii.toString
    let entry := trace.parent.getD home
    let value := parsed "{\"fvtrace\":1,\"analysis\":{\"id\":\"A\",\"title\":\"Notices\",\
        \"summary\":\"Replay notices.\"},\"subjects\":[{\"id\":\"S\",\"title\":\"Data\",\
        \"kind\":\"existing\"}],\"questions\":[{\"id\":\"Q\",\"title\":\"Result\",\
        \"text\":\"What holds?\"}],\"facts\":[{\"id\":\"O1\",\"subject\":\"S\",\
        \"kind\":\"result\",\"text\":\"The result holds.\",\"status\":\"proved\",\
        \"route\":\"lean\",\"evidence\":{\"summary\":\"A proof.\",\
        \"artifacts\":[{\"path\":\"proof.bin\"}],\"verifier\":\"Lean\",\
        \"statement\":\"The result holds.\",\"replay\":{\"command\":[\"placeholder\"]}}},\
        {\"id\":\"O2\",\"subject\":\"S\",\"kind\":\"provenance\",\
        \"text\":\"The source is known.\",\"status\":\"open\",\"route\":\"lean\"}],\
        \"claims\":[{\"id\":\"C\",\"question\":\"Q\",\"subject\":\"S\",\"level\":\"descriptive\",\
        \"text\":\"The result holds.\",\"needs\":[\"O1\"],\"restates\":true}]}"
    let outputDigest ← Digest.ofString "stable\n"
    let value := editReplay value fun r =>
      put (put r "command" (some (.arr ([app, "--replay-fixture", "out:output.bin"].map .str))))
        "output" (some (.str outputDigest))
    write trace value
    let _ ← run ["pin"]
    let pinned ← readJson trace
    test { dir, project, home, trace, entry, app, pinned }

def codecTests : TestM Unit := withFixture fun f => do
  for date in ["0000-01-01", "2024-02-29", "9999-12-31"] do
    for reason in ["timeout", "cannot start", "exit 1", "exit 255", "exit 4294967295",
        "output changed"] do
      let n := notice date reason
      let value := withNotice f.pinned (some n)
      write f.trace value
      let (rc, _, err) ← f.run ["pin"]
      let actual ← readJson f.trace
      check s!"notices codec: round-trip {date}/{reason}"
        (rc == 0 && member (replayOf actual) "failed" == n) err
  for i in [:64] do
    let code := 1 + (1664525 * (i + 1) + 1013904223) % 4294967295
    let date := ["0000-01-01", "2024-02-29", "9999-12-31"].getD (i % 3) "2026-10-31"
    let n := notice date s!"exit {code}"
    write f.trace (withNotice f.pinned (some n))
    let (rc, _, err) ← f.run ["pin"]
    check s!"notices codec property: generated exit code {code} round-trips"
      (rc == 0 && same (member (replayOf (← readJson f.trace)) "failed") n) err
  let invalid := [("extra", .obj [("date", .str "2026-10-31"), ("reason", .str "exit 1"),
      ("extra", .bool true)]), ("missing-date", .obj [("reason", .str "timeout")]),
    ("missing-reason", .obj [("date", .str "2026-10-31")]), ("null", .null),
    ("not-object", .str "timeout")]
  let invalid := invalid ++ (["2026-1-01", "2026-13-01", "yesterday"].map fun date =>
    (s!"date-{date}", notice date "timeout")) ++
    (["exit 0", "exit 01", "exit -1", "exit +1", "exit 1x", "exit ", "exit 4294967296",
      "exit 9999999999", "exit 10000000000", "failed", "output not pinned",
      "cannot start: missing", "Timeout"].map fun reason =>
        (s!"reason-{reason}", notice "2026-10-31" reason))
  for (name, n) in invalid do
    write f.trace (withNotice f.pinned (some n))
    let (rc, out, _) ← f.run ["check", "--json"]
    check s!"notices codec: rejects {name}"
      (rc == 1 && (if name.startsWith "reason-" then has out "invalid-replay" else
        has out "\"code\"")) out
  let x := parsed "{\"id\":\"X\",\"subject\":\"S\",\"between\":[\"O1\",\"O2\"],\
      \"text\":\"Not both.\",\"status\":\"open\",\"route\":\"lean\",\
      \"evidence\":{\"summary\":\"Relation.\",\"replay\":{\"command\":[\"no-run\"],\
      \"failed\":{\"date\":\"2026-10-31\",\"reason\":\"timeout\"}}}}"
  let value := put f.pinned "exclusions" (some (.arr [x]))
  write f.trace value
  let (rc, _, err) ← f.run ["pin"]
  check "notices codec: exclusion round-trip"
    (rc == 0 && member (replayOf (← readJson f.trace) "exclusions") "failed" ==
      notice "2026-10-31" "timeout") err

/-- Cartesian outcome × prior-notice coverage; each attempt must append its own event. -/
def matrixTests : TestM Unit := withFixture fun f => do
  let today := toString (← Std.Time.PlainDate.now)
  let changedDigest ← Digest.ofString "different\n"
  for mode in ["pin", "verify"] do
    let outcomes := if mode == "pin" then ["pass", "repin", "exit", "timeout", "missing"]
      else ["pass", "changed", "unpinned", "exit", "timeout", "missing"]
    for prior in [false, true] do
      for outcome in outcomes do
        let steps := match outcome with
          | "exit" => (if mode == "pin" then ["put:proof.bin"] else []) ++
              ["out:output.bin", "err:matrix-tail", "exit:7"]
          | "timeout" => ["sleep:1300"]
          | "changed" | "repin" => ["hex:646966666572656e740a"]
          | _ => ["out:output.bin"]
        let mut value := f.setCommand f.pinned steps
        if outcome == "missing" then
          value := editReplay value
            (put · "command" (some (.arr [.str "fvtrace-no-such-notice-program"])))
        if outcome == "unpinned" then value := editReplay value (put · "output" none)
        let pass := outcome == "pass" || outcome == "repin"
        let old := if prior then some (notice "2001-01-01" "exit 9") else none
        value := withNotice value old
        write f.trace value
        let before ← IO.FS.readBinFile f.trace
        let oldLog ← f.log
        let args := [mode, if mode == "pin" then "--replay" else "--run"] ++
          (if outcome == "timeout" then ["--timeout", "1"] else []) ++
          (if mode == "verify" then ["--json"] else [])
        let (rc, out, err) ← f.run args
        let actual ← readJson f.trace
        let got := field (replayOf actual) "failed"
        let reason := match outcome with
          | "exit" => "exit 7"
          | "timeout" => "timeout"
          | "changed" => "output changed"
          | _ => "cannot start"
        let want := if pass then none
          else if outcome == "unpinned" then old else some (notice today reason)
        let matchNotice := if outcome == "missing" then
            got == want || got == some (notice today "exit 255")
          else got == want
        let tag := s!"notices matrix: {mode}/{outcome}/prior={prior}"
        check (tag ++ " result + notice")
          (rc == (if pass then 0 else 1) && matchNotice) (out ++ err)
        let afterLog ← f.log
        let event := afterLog.getLast?.getD .null
        check (tag ++ " log")
          (afterLog.length == oldLog.length + 1 && member event "run" == .str mode &&
            member event "id" == .str "O1" &&
            member event "passed" == .bool pass &&
            (if pass then member event "reasons" == .arr []
             else !(items (member event "reasons")).isEmpty)) s!"{repr event}"
        let output := if outcome == "repin" then some (.str changedDigest)
          else field (replayOf value) "output"
        check (tag ++ " output pinned/kept") (field (replayOf actual) "output" == output)
        if mode == "verify" then
          let document := parsed out
          let row := (items (member document "replays")).getD 0 .null
          check (tag ++ " JSON reports post-run notice")
            (member document "schema" == .str "fvtrace.verify/1" &&
              field row "failed" == got && member row "ran" == .bool true &&
              member row "passed" == .bool pass) out
        if mode == "pin" then
          let fact := (items (member actual "facts")).getD 0 .null
          let artifact := (items (atPath fact ["evidence", "artifacts"])).getD 0 .null
          check (tag ++ " pins artifact even after failure")
            (member artifact "sha256" == .str (← Digest.ofBytes
              (← IO.FS.readBinFile (f.project / "proof.bin"))))
        if outcome == "unpinned" then
          check (tag ++ " bytes unchanged") ((← IO.FS.readBinFile f.trace) == before)
        if mode == "verify" && outcome == "pass" && !prior then
          check (tag ++ " no notice change keeps bytes") ((← IO.FS.readBinFile f.trace) == before)

/-- Notice-only differences leave receipts, all judgments + the review digest unchanged. -/
def reviewTests : TestM Unit := withFixture fun f => do
  let value := f.setCommand f.pinned ["out:output.bin", "out:gate.bin"]
  write f.trace value
  let _ ← f.run ["pin", "--replay"]
  let _ ← f.run ["review", "--reviewer", "Notice reviewer"]
  let clean ← IO.FS.readBinFile f.trace
  let (_, cleanOut, _) ← f.run ["eval"]
  IO.FS.removeFile (f.project / "gate.bin")
  let (rc, _, _) ← f.run ["pin", "--replay"]
  let today := toString (← Std.Time.PlainDate.now)
  let failed ← readJson f.trace
  let (checkRc, out, _) ← f.run ["check"]
  check "notices review: failure keeps pin + reviewed + check rc 0"
    (rc == 1 && checkRc == 0 && has out "receipt O1: current" &&
      has out "review: reviewed" && member (replayOf failed) "failed" == notice today "exit 1") out
  let first ← IO.FS.readBinFile f.trace
  let beforeLog ← f.log
  let _ ← f.run ["pin", "--replay"]
  check "notices repeat: pin same failure restores identical canonical bytes"
    ((← IO.FS.readBinFile f.trace) == first)
  let metadata ← f.trace.metadata
  let (_, failedOut, _) ← f.run ["eval"]
  let a := parsed cleanOut
  let b := parsed failedOut
  check "notices review: notice leaves every judgment + digest unchanged"
    (member a "trace" == member b "trace" &&
      ["counts", "claims", "work", "blockers", "experiments", "exclusions"].all fun key =>
        member a key == member b key) failedOut
  let _ ← f.run ["verify", "--run"]
  let afterMeta ← f.trace.metadata
  let afterLog ← f.log
  check "notices repeat: verify same failure writes nothing + appends"
    ((← IO.FS.readBinFile f.trace) == first && metadata.modified == afterMeta.modified &&
      afterLog.length == beforeLog.length + 2)
  IO.FS.writeFile (f.project / "gate.bin") ""
  let (rc, _, _) ← f.run ["pin", "--replay"]
  check "notices review: pass clears notice + recovers never-failed bytes"
    (rc == 0 && (← IO.FS.readBinFile f.trace) == clean)
  let (_, out, _) ← f.run ["check"]
  check "notices review: clear remains reviewed" (has out "review: reviewed") out
  let value ← readJson f.trace
  write f.trace (editPath value ["analysis", "summary"] fun _ => .str "A changed summary.")
  let (_, out, _) ← f.run ["check"]
  check "notices review: ordinary content change still stales review" (has out "review: stale") out

/-- Text, JSON, what-if + persistence surfaces; ids stay in fact-then-exclusion order. -/
def surfaceTests : TestM Unit := withFixture fun f => do
  let n := notice "2026-10-31" "exit 7"
  let x := parsed "{\"id\":\"X\",\"subject\":\"S\",\"between\":[\"O1\",\"O2\"],\
      \"text\":\"Not both.\",\"status\":\"open\",\"route\":\"lean\",\
      \"evidence\":{\"summary\":\"Relation.\",\"replay\":{\"command\":[\"no-run\"],\
      \"failed\":{\"date\":\"2026-10-30\",\"reason\":\"timeout\"}}}}"
  let value := put (withNotice f.pinned (some n)) "exclusions" (some (.arr [x]))
  write f.trace value
  let wanted := .arr [
    .obj [("id", .str "O1"), ("date", .str "2026-10-31"), ("reason", .str "exit 7")],
    .obj [("id", .str "X"), ("date", .str "2026-10-30"), ("reason", .str "timeout")]]
  let (rc, out, _) ← f.run ["check"]
  check "notices check: fact + exclusion text"
    (rc == 0 && has out "  replay O1: last run failed on 2026-10-31 (exit 7)" &&
      has out "  replay X: last run failed on 2026-10-30 (timeout)") out
  let (rc, out, _) ← f.run ["check", "--json"]
  check "notices check: ordered JSON notices"
    (rc == 0 && same (member (parsed out) "notices") wanted) out
  let (rc, _, _) ← f.run ["check", "--strict"]
  checkEq "notices check: strict rejects a current receipt with notices" rc 1
  let (rc, out, _) ← f.run ["verify"]
  check "notices verify: listing carries notice"
    (rc == 0 && has out "; last run failed on 2026-10-31: exit 7" &&
      has out "; last run failed on 2026-10-30: timeout") out
  let (rc, out, _) ← f.run ["verify", "--json"]
  let replays := items (member (parsed out) "replays")
  check "notices verify: JSON failed + ran=false"
    (rc == 0 && replays.length == 2 && member (replays.getD 0 .null) "failed" == n &&
      member (replays.getD 1 .null) "failed" == notice "2026-10-30" "timeout" &&
      replays.all fun r => member r "ran" == .bool false) out
  for args in [["eval"], ["eval", "--whatif", "O1=open"]] do
    let (rc, out, _) ← f.run args
    let env := parsed out
    check s!"notices envelope: {args} preserves recorded notices + fact evidence"
      (rc == 0 && same (member env "notices") wanted &&
        (recordOf env "facts" "O1").any fun fact =>
          atPath fact ["evidence", "replay", "failed"] == n) out
  for args in [["pin"], ["review", "--reviewer", "Notice reviewer"], ["check"], ["claims"]] do
    write f.trace value
    let (rc, out, err) ← f.run args
    check s!"notices keep: {args}"
      (rc == 0 && member (replayOf (← readJson f.trace)) "failed" == n &&
        member (replayOf (← readJson f.trace) "exclusions") "failed" ==
          notice "2026-10-30" "timeout") (out ++ err)
  write f.trace value
  let bundle := f.dir / "bundle"
  let (rc, out, err) ← f.run ["export", "--bundle", bundle.toString]
  let bundled ← readIf (bundle / "trace.json")
  check "notices keep: bundle copies fact + exclusion notices, not log"
    (rc == 0 && member (replayOf (parsed bundled)) "failed" == n &&
      member (replayOf (parsed bundled) "exclusions") "failed" == notice "2026-10-30" "timeout" &&
      !(← (bundle / "replays.log").pathExists)) (out ++ err)
  write f.trace f.pinned
  for args in [["check", "--json"], ["eval"]] do
    let (rc, out, _) ← f.run args
    check s!"notices omitted: {args}" (rc == 0 && (field (parsed out) "notices").isNone) out
  let (rc, out, _) ← f.run ["verify", "--json"]
  check "notices omitted: verify failed field absent"
    (rc == 0 && (items (member (parsed out) "replays")).all fun r =>
      (field r "failed").isNone) out

def domainTests : TestM Unit := withFixture fun f => do
  let value := f.setCommand f.pinned ["out:output.bin", "out:gate.bin"]
  let relation := parsed "{\"id\":\"X\",\"subject\":\"S\",\"between\":[\"O1\",\"O2\"],\
      \"text\":\"Not both.\",\"status\":\"open\",\"route\":\"lean\",\
      \"evidence\":{\"summary\":\"Relation.\",\"replay\":{\"command\":[\"placeholder\"]}}}"
  let relation := editPath relation ["evidence", "replay"] fun _ => replayOf value
  write f.trace (put value "exclusions" (some (.arr [relation])))
  let _ ← f.run ["pin", "--replay"]
  let _ ← f.run ["review", "--reviewer", "Domain reviewer"]
  let clean ← IO.FS.readBinFile f.trace
  IO.FS.removeFile (f.project / "gate.bin")
  let (rc, _, _) ← f.run ["pin", "--replay"]
  let actual ← readJson f.trace
  let today := toString (← Std.Time.PlainDate.now)
  let events ← f.log
  let (_, out, _) ← f.run ["check", "--json"]
  let notices := items (member (parsed out) "notices")
  check "notices domain: fact then exclusion fail independently + stay reviewed"
    (rc == 1 && member (replayOf actual) "failed" == notice today "exit 1" &&
      member (replayOf actual "exclusions") "failed" == notice today "exit 1" &&
      notices.map (member · "id") == [.str "O1", .str "X"] &&
      events.map (member · "id") == [.str "O1", .str "X", .str "O1", .str "X"]) out
  let (_, out, _) ← f.run ["check"]
  check "notices domain: fact + exclusion notices preserve review"
    (has out "review: reviewed") out
  IO.FS.writeFile (f.project / "gate.bin") ""
  let (rc, _, _) ← f.run ["verify", "--run"]
  check "notices domain: verify clears both + restores reviewed bytes"
    (rc == 0 && (← IO.FS.readBinFile f.trace) == clean)
  let events ← f.log
  check "notices domain: verify appends fact then exclusion passes"
    (events.length == 6 && (events.drop 4).map (member · "id") == [.str "O1", .str "X"] &&
      (events.drop 4).all fun event => member event "passed" == .bool true) s!"{repr events}"

def timestampShape (text : String) : Bool :=
  text.length == 19 && (text.toList.zipIdx.all fun (c, i) =>
    if i == 4 || i == 7 then c == '-'
    else if i == 10 then c == 'T'
    else if i == 13 || i == 16 then c == ':'
    else c ≥ '0' && c ≤ '9')

def logTests : TestM Unit := withFixture fun f => do
  let (rc, out, _) ← f.run ["verify", "--log"]
  check "notices log: absent log text"
    (rc == 0 && out == "No replay has run for this project yet.\n") out
  let (rc, out, _) ← f.run ["verify", "--log", "--json"]
  check "notices log: absent log JSON"
    (rc == 0 && member (parsed out) "schema" == .str "fvtrace.replays/1" &&
      member (parsed out) "runs" == .arr []) out
  for args in [["verify", "--log", "--run"], ["verify", "--log", "--timeout", "1"]] do
    let (rc, _, _) ← f.run args
    checkEq s!"notices log: rejects {args}" rc 2
  let value := f.setCommand f.pinned ["out:output.bin", "err:private-log-tail", "exit:7"]
  write f.trace value
  let _ ← f.run ["verify", "--run"]
  let logPath := f.entry / "replays.log"
  let text ← readIf logPath
  let events ← f.log
  let event := events.getD 0 .null
  let today := toString (← Std.Time.PlainDate.now)
  let atText := match member event "at" with | .str s => s | _ => ""
  check "notices log: event has canonical fields + local timestamp + resolved paths"
    (events.length == 1 && timestampShape atText && atText.startsWith today &&
      member event "run" == .str "verify" &&
      member event "trace" == .str (← IO.FS.realPath f.trace).toString &&
      member event "project" == .str (← IO.FS.realPath f.project).toString &&
      member event "id" == .str "O1" &&
      member event "command" == f.command ["out:output.bin", "err:private-log-tail", "exit:7"] &&
      member event "passed" == .bool false && member event "reasons" == .arr [.str "exit 7"] &&
      member event "stderr" == .str "private-log-tail" && text == event.canonical ++ "\n") text
  let (rc, out, _) ← f.run ["verify", "--log"]
  check "notices log: text renders failure for the project's own trace"
    (rc == 0 && out == s!"{atText} verify O1: failed (exit 7)\n") out
  let (rc, out, _) ← f.run ["verify", "--log", "--json"]
  check "notices log: JSON exposes entries + path"
    (rc == 0 && member (parsed out) "log" ==
        .str ((← IO.FS.realPath f.entry) / "replays.log").toString &&
      member (parsed out) "runs" == .arr events) out
  let before ← readIf logPath
  IO.FS.writeFile f.trace "{"
  let (rc, out, _) ← f.run ["verify", "--log", "--json"]
  check "notices log: broken draft history readable, trace + log kept"
    (rc == 0 && member (parsed out) "runs" == .arr events &&
      (← IO.FS.readFile f.trace) == "{" && (← readIf logPath) == before) out
  IO.FS.removeFile f.trace
  let (rc, out, _) ← f.run ["verify", "--log", "--json"]
  check "notices log: deleted draft history readable"
    (rc == 0 && member (parsed out) "runs" == .arr events && !(← f.trace.pathExists)) out
  let accepted := parsed "{\"at\":\"custom time\",\"run\":\"custom run\",\"id\":\"custom id\",\
      \"trace\":\"elsewhere.json\",\"passed\":true,\"reasons\":[],\"extra\":42}"
  let accepted := put accepted "reasons" (some (.arr [.str "", .str "arbitrary reason"]))
  let invalid := ["not JSON", "[]", "{}", "{\"at\":\"x\",\"run\":\"verify\",\"id\":\"O1\",\
      \"trace\":\"t\",\"passed\":1,\"reasons\":[]}"]
  let invalid := invalid ++ ([.num 1, .bool true, .null, .obj [], .arr []] : List J).map
    fun bad => (put accepted "reasons" (some (.arr [.str "valid", bad]))).canonical
  IO.FS.writeFile logPath (before ++ "\n".intercalate invalid ++ "\n" ++ accepted.canonical ++ "\n")
  let (rc, out, err) ← f.run ["verify", "--log", "--json"]
  check "notices log: malformed entries skipped + counted, loose valid entry retained"
    (rc == 1 && same (member (parsed out) "runs") (.arr (events ++ [accepted])) &&
      has err s!"{invalid.length}") (out ++ err)
  let (rc, out, _) ← f.run ["verify", "--log"]
  check "notices log: foreign trace is named"
    (rc == 1 && has out "custom time custom run custom id: passed in elsewhere.json") out
  IO.FS.removeFile logPath
  IO.FS.createDirAll logPath
  let (rc, _, _) ← f.run ["verify", "--log"]
  checkEq "notices log: unreadable log rc 2" rc 2
  let marker := f.dir / "continued-after-log-failure"
  let emptyDigest ← Digest.ofString ""
  let value := editRecord value "facts" 1 fun fact => put fact "evidence" (some
    (.obj [("summary", .str "Continues after a log fault."), ("replay", .obj
      [("command", f.command [s!"touch:{marker}"]), ("output", .str emptyDigest)])]))
  write f.trace value
  let (rc, _, err) ← f.run ["verify", "--run"]
  check "notices log: append failure rc 2, reported once, remaining verifier runs"
    (rc == 2 && has err "replays.log" &&
      ((err.splitOn "\n").filter (!·.isEmpty)).length == 1 && (← marker.pathExists)) err

/-- A log is independent of a draft's location + initialization. -/
def freshTests : TestM Unit := withFixture fun f => do
  let freshHome := f.dir / "fresh-home"
  let external := f.dir / "draft.json"
  write external f.pinned
  let externalReal ← IO.FS.realPath external
  let run := fun args => capture (Cli.runIn { home := freshHome, cwd := f.project }
    (args ++ ["--trace", external.toString]))
  let (rc, _, err) ← run ["verify", "--run"]
  let (_, path, _) ← capture (Cli.runIn { home := freshHome, cwd := f.project } ["path"])
  let ownTrace : System.FilePath := path.trimAscii.toString
  let entry := ownTrace.parent.getD freshHome
  let mapped ← readIf (entry / "project.json")
  let logText ← readIf (entry / "replays.log")
  let events := (logText.splitOn "\n").filterMap fun line =>
    if line.isEmpty then none else (Json.parse line.toUTF8).toOption
  check "notices fresh: explicit trace creates entry + mapping + log, no starter trace"
    (rc == 0 && !mapped.isEmpty && events.length == 1 && !(← ownTrace.pathExists) &&
      member (events.getD 0 .null) "trace" == .str externalReal.toString &&
      (field (events.getD 0 .null) "stderr").isNone) (err ++ mapped ++ logText)
  let mapping ← readIf (entry / "project.json")
  let (rc, out, _) ← run ["verify", "--log"]
  check "notices fresh: explicit draft is named + mapping unchanged"
    (rc == 0 && has out s!" in {externalReal}" &&
      (← readIf (entry / "project.json")) == mapping) out

/-- A decode-only trace may repeat an id: observations belong to positions, never id lookup. -/
def duplicateTests : TestM Unit := withFixture fun f => do
  let first := (items (member f.pinned "facts")).getD 0 .null
  let first := editPath first ["evidence", "replay"] fun r =>
    put r "command" (some (f.command ["out:output.bin", "exit:7"]))
  let second := editPath first ["evidence", "replay"] fun r =>
    put (put r "command" (some (f.command ["out:output.bin"]))) "failed"
      (some (notice "2000-01-01" "timeout"))
  let value := put f.pinned "facts" (some (.arr [first, second]))
  write f.trace value
  let (rc, _, err) ← f.run ["pin", "--replay"]
  let actual ← readJson f.trace
  let today := toString (← Std.Time.PlainDate.now)
  check "notices duplicate: same id retains failed first + clears passing second"
    (rc == 1 && member (replayOf actual "facts" 0) "failed" == notice today "exit 7" &&
      (field (replayOf actual "facts" 1) "failed").isNone) err
  let log ← f.log
  check "notices duplicate: two positional events kept"
    (log.length == 2 && member (log.getD 0 .null) "passed" == .bool false &&
      member (log.getD 1 .null) "passed" == .bool true) s!"{repr log}"

/-- Replays may edit the draft: a notice write must preserve that external edit + the log. -/
def refusalTests : TestM Unit := withFixture fun f => do
  for mode in ["pin", "verify"] do
    let value := f.setCommand f.pinned [s!"put:{f.trace}", "exit:7"]
    write f.trace value
    let beforeLog ← f.log
    let (rc, out, err) ← f.run [mode, if mode == "pin" then "--replay" else "--run"]
    let events ← f.log
    check s!"notices refusal: {mode} preserves concurrent edit + event"
      (rc == 2 && (← IO.FS.readFile f.trace) == "rewritten\n" &&
        events.length == beforeLog.length + 1) (out ++ err)
  for mode in ["pin", "verify"] do
    let value := f.setCommand f.pinned ["out:output.bin", "exit:7"]
    -- Fill a schema-valid display field, preserving a valid trace just below the byte cap.
    let empty := editPath value ["analysis", "summary"] fun _ => .str ""
    let emptySize := empty.canonical.utf8ByteSize
    let large := editPath empty ["analysis", "summary"] fun _ =>
      .str ("".pushn 'x' (16 * 1024 * 1024 - emptySize))
    IO.FS.writeFile f.trace large.canonical
    let before ← IO.FS.readBinFile f.trace
    let beforeLog ← f.log
    let (rc, out, err) ← f.run [mode, if mode == "pin" then "--replay" else "--run"]
    let events ← f.log
    check s!"notices refusal: {mode} oversized notice write keeps bytes + event"
      (rc == 2 && (← IO.FS.readBinFile f.trace) == before &&
        events.length == beforeLog.length + 1) ((out.take 250).toString ++ err)

/-- reviewer-1 boundaries: concurrent appends, a blank log line, a trace reached by a link. -/
def boundaryTests : TestM Unit := withFixture fun f => do
  -- 12 writers × 6 events of 120 KB each: a line longer than a stream buffer reaches the file in
  -- several writes, so unserialized appends interleave.
  let tg : Store.Target := { trace := f.trace, project := f.project, entry := f.dir / "concurrent" }
  let entry := fun (w i : Nat) =>
    Json.Value.obj [("id", .str s!"W{w}-{i}"), ("pad", .str ("".pushn 'x' 120000))]
  let writers ← (List.range 12).mapM fun w => IO.asTask (prio := .dedicated) do
    for i in List.range 6 do
      if let some e ← Cli.appendLog tg (entry w i) then throw (IO.userError e)
  for t in writers do
    match ← IO.wait t with
    | .ok () => pure ()
    | .error e => check "notices boundary: concurrent appends succeed" false (toString e)
  let lines := ((← readIf tg.logFile).splitOn "\n").filter (!·.isEmpty)
  let ids := lines.filterMap fun l => match parsed l with
    | v@(.obj _) => match member v "id" with | .str id => some id | _ => none
    | _ => none
  check "notices boundary: concurrent appends keep one whole line per event"
    (lines.length == 72 && ids.length == 72 && ids.eraseDups.length == 72)
    s!"lines={lines.length} parsed={ids.length}"
  -- A blank physical line is no entry: counted, rc 1, its neighbours kept.
  let one := f.setCommand f.pinned ["out:output.bin"]
  write f.trace one
  let _ ← f.run ["verify", "--run"]
  let _ ← f.run ["verify", "--run"]
  let logPath := f.entry / "replays.log"
  let events ← f.log
  match (← readIf logPath).splitOn "\n" with
  | a :: b :: rest => IO.FS.writeFile logPath (a ++ "\n\n" ++ b ++ "\n" ++ "\n".intercalate rest)
  | _ => pure ()
  let (rc, out, err) ← f.run ["verify", "--log", "--json"]
  check "notices boundary: a blank log line counts as no entry"
    (rc == 1 && member (parsed out) "runs" == .arr events && has err "1 line(s)") (out ++ err)
  -- Positions past the first exclusion: each exclusion's result lands on its own record (two
  -- exclusions after a fact; the second alone fails). `pin` decodes alone, so the pair may repeat.
  let pass := f.command ["out:output.bin"]
  let relation := fun (id : String) (cmd : J) =>
    Json.Value.obj [("id", .str id), ("subject", .str "S"),
      ("between", .arr [.str "O1", .str "O2"]), ("text", .str "Not both."),
      ("status", .str "open"), ("route", .str "lean"),
      ("evidence", .obj [("summary", .str "Relation."), ("replay", .obj [("command", cmd)])])]
  write f.trace (put one "exclusions" (some (.arr
    [relation "X1" pass, relation "X2" (f.command ["exit:7"])])))
  let _ ← f.run ["pin", "--replay"]
  let actual ← readJson f.trace
  let today := toString (← Std.Time.PlainDate.now)
  check "notices boundary: the second exclusion's failure lands on it alone"
    (field (replayOf actual) "failed" == none &&
      field (replayOf actual "exclusions" 0) "failed" == none &&
      field (replayOf actual "exclusions" 1) "failed" == some (notice today "exit 7"))
    actual.pretty
  write f.trace one
  if !System.Platform.isWindows then
    -- A trace reached through a link is logged by its real path.
    let alias := f.dir / "alias.json"
    let _ ← IO.Process.output { cmd := "ln", args := #["-s", f.trace.toString, alias.toString] }
    IO.FS.removeFile logPath
    let _ ← capture (Cli.runIn { home := f.home, cwd := f.project }
      ["verify", "--run", "--trace", alias.toString])
    let event := (← f.log).getD 0 .null
    checkEq "notices boundary: a linked trace is logged by its real path"
      (member event "trace") (.str (← IO.FS.realPath f.trace).toString)

def tests : TestM Unit := do
  area "notices-codec" codecTests
  area "notices-matrix" matrixTests
  area "notices-review" reviewTests
  area "notices-surfaces" surfaceTests
  area "notices-domain" domainTests
  area "notices-log" logTests
  area "notices-fresh" freshTests
  area "notices-duplicate" duplicateTests
  area "notices-refusal" refusalTests
  area "notices-boundary" boundaryTests

end Tests.Notices
