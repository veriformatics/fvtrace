import Fvtrace
import Tests.Harness

namespace Tests.Cli
open Tests

def tests : TestM Unit := do
  let (rc, out, _) ← capture (Fvtrace.Cli.run ["--version"])
  checkEq "cli: --version rc" rc 0
  checkEq "cli: --version prints the version" out s!"fvtrace {Fvtrace.version}\n"
  let (rc, out, _) ← capture (Fvtrace.Cli.run ["--help"])
  checkEq "cli: --help rc" rc 0
  check "cli: --help prints usage on stdout" (out.startsWith "usage: fvtrace")
  let (rc, out, err) ← capture (Fvtrace.Cli.run [])
  checkEq "cli: no command rc" rc 2
  check "cli: no command prints usage on stderr" (out.isEmpty && err.startsWith "usage: fvtrace")
  let (rc, _, err) ← capture (Fvtrace.Cli.run ["bogus"])
  checkEq "cli: unknown command rc" rc 2
  check "cli: unknown command named" (err.startsWith "fvtrace: unknown command 'bogus'") err

/-- `serve`'s bind address: loopback by default, a concrete `--host`, wildcards refused. -/
def bindTests : TestM Unit := do
  let v4 := fun (h : Option String) (want : Std.Net.IPv4Addr) (name : String) =>
    match Fvtrace.Cli.bindAddress h 8642 with
    | .ok (.v4 a, n) => a.addr == want && a.port == 8642 && n == name
    | _ => false
  check "serve: loopback 127.0.0.1 by default" (v4 none (Std.Net.IPv4Addr.ofParts 127 0 0 1)
    "127.0.0.1")
  check "serve: --host takes a concrete IPv4 address"
    (v4 (some "192.168.1.5") (Std.Net.IPv4Addr.ofParts 192 168 1 5) "192.168.1.5")
  check "serve: --host takes a concrete IPv6 address" (match Fvtrace.Cli.bindAddress
    (some "fe80::1") 8642 with | .ok (.v6 _, n) => n == "[fe80::1]" | _ => false)
  check "serve: the IPv4 wildcard is refused"
    ((Fvtrace.Cli.bindAddress (some "0.0.0.0") 8642).toOption.isNone)
  check "serve: the IPv6 wildcard is refused"
    ((Fvtrace.Cli.bindAddress (some "::") 8642).toOption.isNone)
  check "serve: a host name is refused"
    ((Fvtrace.Cli.bindAddress (some "lab") 8642).toOption.isNone)
  checkEq "serve: the default port is 8718" Fvtrace.Cli.defaultPort 8718
  let opener := fun (vars : List (String × String)) (windows macos : Bool) =>
    Fvtrace.Cli.browserOpener (fun n => vars.lookup n) windows macos
  checkEq "serve: Linux with a display opens through xdg-open"
    (opener [("DISPLAY", ":0")] false false, opener [("WAYLAND_DISPLAY", "wayland-0")] false false)
    (some "xdg-open", some "xdg-open")
  checkEq "serve: Linux without a display prints the link"
    (opener [] false false, opener [("DISPLAY", "")] false false) (none, none)
  checkEq "serve: macOS + Windows open through their own openers"
    (opener [] false true, opener [] true false) (some "open", some "explorer.exe")
  checkEq "serve: an SSH session prints the link (the browser is on the other computer)"
    ([false, true].map fun w => (opener [("SSH_CONNECTION", "a"), ("DISPLAY", ":0")] w (!w),
      opener [("SSH_TTY", "/dev/pts/1"), ("DISPLAY", ":0")] w false)) [(none, none), (none, none)]
  checkEq "serve: WSL prints the link (its browser cannot read this file system)"
    (opener [("WSL_DISTRO_NAME", "Ubuntu"), ("DISPLAY", ":0")] false false) none
  let link := "http://fvtrace.localhost:8718/#token=00ff"
  let page := Fvtrace.Cli.redirectPage link
  check "serve: the redirect page sends the browser on to the link"
    ((page.splitOn s!"content=\"0;url={link}\"").length == 2 &&
      (page.splitOn s!"href=\"{link}\"").length == 2 && (page.splitOn "http://").length == 3) page

/-- `skills install --dir` + `skills show` (no store: pure suite). -/
def skillTests : TestM Unit := do
  let (rc, out, _) ← capture (Fvtrace.Cli.run ["skills", "show"])
  checkEq "skills: show rc" rc 0
  check "skills: show prints SKILL.md" (out.startsWith "---\nname: fvtrace\n")
  IO.FS.withTempDir fun dir => do
    let (rc, out, _) ← capture (Fvtrace.Cli.run ["skills", "install", "--dir", dir.toString])
    checkEq "skills: install rc" rc 0
    check "skills: install names the folder"
      ((out.splitOn (dir / "fvtrace").toString).length == 2) out
    check "skills: install says how to load it"
      ((out.splitOn "Start a new session of your coding agent to load it.").length == 2) out
    let mut same := true
    for (path, body) in FvtraceSkill.files do
      same := same && (← IO.FS.readFile (dir / "fvtrace" / path)) == body
    check "skills: every file installed byte-equal" same
    IO.FS.writeFile (dir / "fvtrace" / "SKILL.md") "edited"
    let (rc, _, _) ← capture (Fvtrace.Cli.run ["skills", "install", "--dir", dir.toString])
    checkEq "skills: reinstall replaces its own copy rc" rc 0
    check "skills: reinstall restores the skill"
      ((← IO.FS.readFile (dir / "fvtrace" / "SKILL.md")) ==
        (FvtraceSkill.files.lookup "SKILL.md").get!)
    IO.FS.removeFile (dir / "fvtrace" / ".fvtrace-skill")
    let (rc, out, err) ← capture (Fvtrace.Cli.run ["skills", "install", "--dir", dir.toString])
    checkEq "skills: a folder fvtrace did not write is refused" rc 1
    check "skills: a refused install does not say it loads"
      ((out.splitOn "Start a new session").length == 1) out
    check "skills: the refusal names the folder"
      ((err.splitOn "was not written by fvtrace").length == 2) err
  IO.FS.withTempDir fun dir => do
    let target := dir / "elsewhere"
    IO.FS.createDirAll target
    IO.FS.writeFile (target / ".fvtrace-skill") "planted"
    IO.FS.writeFile (target / "keep.txt") "the user's file"
    IO.FS.createDirAll (dir / "skills")
    let linked ← symlink target (dir / "skills" / "fvtrace")
    check "skills: the linked skill folder exists" linked
    let (rc, _, _) ← capture (Fvtrace.Cli.run ["skills", "install", "--dir",
      (dir / "skills").toString])
    checkEq "skills: a linked skill folder is refused" rc 1
    check "skills: the link's target keeps its files" (← (target / "keep.txt").pathExists)
    check "skills: a link reads as a link, its target as a folder"
      ((← Fvtrace.Store.isLink (dir / "skills" / "fvtrace")) && !(← Fvtrace.Store.isLink target))
    unlink (dir / "skills" / "fvtrace")
    IO.FS.writeFile (dir / "gone.txt") "soon gone"
    let dangling ← symlink (dir / "gone.txt") (dir / "dangling")
    IO.FS.removeFile (dir / "gone.txt")
    check "skills: a dangling link reads as a link"
      (dangling && (← Fvtrace.Store.isLink (dir / "dangling")))
    unlink (dir / "dangling")
    -- A link planted inside an installed copy goes with the copy; what it points at stays.
    let (rc, _, _) ← capture (Fvtrace.Cli.run ["skills", "install", "--dir",
      (dir / "skills").toString])
    checkEq "skills: install beside the removed link rc" rc 0
    let planted ← symlink target (dir / "skills" / "fvtrace" / "planted")
    check "skills: a link can be planted in the installed copy" planted
    let (rc, _, _) ← capture (Fvtrace.Cli.run ["skills", "install", "--dir",
      (dir / "skills").toString])
    checkEq "skills: reinstall over a planted link rc" rc 0
    check "skills: reinstall removes the planted link, not what it points at"
      ((← (target / "keep.txt").pathExists) &&
        !(← (dir / "skills" / "fvtrace" / "planted").pathExists))
  let (rc, _, _) ← capture (Fvtrace.Cli.run ["skills", "install", "--agent", "vim"])
  checkEq "skills: an unknown agent rc" rc 2
  let (rc, _, _) ← capture (Fvtrace.Cli.run ["skills"])
  checkEq "skills: no subcommand rc" rc 2

/-- `replaceFile` never writes through a link planted at its temporary path. -/
def writeTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let victim := dir / "victim.txt"
    IO.FS.writeFile victim "keep"
    let file := dir / "trace.json"
    let linked ← symlink victim (dir / "trace.json.fvtrace-tmp")
    check "write: a link can be planted at the temporary path" linked
    Fvtrace.Cli.replaceFile file "new"
    checkEq "write: a link at the temporary path is not written through"
      (← IO.FS.readFile victim) "keep"
    checkEq "write: the file gets the new content" (← IO.FS.readFile file) "new"
    check "write: the file is a plain file, not the link"
      ((← file.symlinkMetadata).type == .file)

/-- A trace is read only from a regular file and only up to one byte past the size limit. -/
def readTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let at_ := fun (limit : Nat) (file : System.FilePath) =>
      Fvtrace.Session.readWithin limit { trace := file, project := dir, entry := dir / "e" } true
    let codes := fun (r : Except Fvtrace.Session.Problem (Except (Array Fvtrace.Decode.Diag)
        Fvtrace.Trace)) =>
      match r with
      | .ok (.error ds) => ds.toList.map fun d => d.code ++ ": " ++ d.message
      | .ok (.ok _) => ["ok"]
      | .error (.unreadable _ why) => [s!"unreadable: {why}"]
      | .error _ => ["other problem"]
    let spaces := dir / "spaces.json"
    IO.FS.writeFile spaces "           "
    checkEq "read: a trace over the limit is refused by its size" (codes (← at_ 10 spaces))
      ["size: the trace has 11 bytes; the limit is 10 bytes"]
    checkEq "read: a trace at the limit reaches the parser"
      ((codes (← at_ 11 spaces)).map (·.startsWith "syntax")) [true]
    let valid := dir / "valid.json"
    -- The canonical form ends in `}`: a byte short of it no longer parses (the pretty form's
    -- final newline would).
    let text := (Fvtrace.Encode.trace (Fvtrace.Store.starter dir)).canonical
    IO.FS.writeFile valid text
    checkEq "read: a valid trace of exactly the limit decodes whole"
      (codes (← at_ text.utf8ByteSize valid)) ["ok"]
    unless System.Platform.isWindows do
      checkEq "read: a device is never read" (codes (← at_ 10 "/dev/null"))
        ["unreadable: not a regular file"]
    let big := dir / "big.bin"
    IO.FS.writeBinFile big (ByteArray.mk (Array.replicate 1048586 7))
    checkEq "read: a prefix past one chunk stops at its length"
      (← Fvtrace.Session.readPrefix big 1048581).size 1048581
    checkEq "read: a shorter file comes back whole"
      (← Fvtrace.Session.readPrefix big 2000000).size 1048586
    checkEq "read: a prefix of 0 bytes reads nothing" (← Fvtrace.Session.readPrefix big 0).size 0

private def groupClaim (id sub : String) : Fvtrace.Claim :=
  { id, subject := sub, question := "Q", level := .descriptive, text := id,
    needs := [id ++ "R"], restates := true }

private def groupFact (id sub : String) : Fvtrace.Fact :=
  { id := id ++ "R", subject := sub, kind := .result, route := .runtimeChecker,
    status := .«open», text := id }

private def groupCreator (id sub result : String) : Fvtrace.Experiment :=
  { id, subject := sub, kind := .dry, effort := .hours, title := id, method := id,
    resources := id, success := [(result, .checked)], caveat := id }

/-- `claims` groups a question's claims on prospective subjects: one group per subject in subject
order, its claims in trace order (the original `subjects.filter prospective` ×
`claims.filter (·.subject == id)`, empty groups dropped). Claims interleave across subjects. -/
def groupTests : TestM Unit := do
  let t : Fvtrace.Trace :=
    { analysis := { id := "A", title := "A", summary := "A" },
      subjects := [{ id := "S", title := "S", kind := .existing },
        { id := "P", title := "P", kind := .prospective, createdBy := some "EP" },
        { id := "T", title := "T", kind := .prospective, createdBy := some "ET" }],
      questions := [{ id := "Q", title := "Q", text := "Q" }],
      facts := [groupFact "T1" "T", groupFact "P1" "P", groupFact "P2" "P", groupFact "T2" "T",
        groupFact "S1" "S"],
      claims := [groupClaim "T1" "T", groupClaim "P1" "P", groupClaim "P2" "P",
        groupClaim "T2" "T", groupClaim "S1" "S"],
      experiments := [groupCreator "EP" "P" "P1R", groupCreator "ET" "T" "T1R"] }
  checkEq "cli groups: the trace is well-formed" (Fvtrace.Check.violations t).length 0
  let ix := Fvtrace.Index.ofKeys compare (t.subjects.map (·.id))
  let got := (Fvtrace.Cli.prospectiveGroups t (ix.first? (cmp := compare)) t.claims).map
    fun (sub, cs) => (sub.id, cs.map (·.id))
  let want := ((t.subjects.filter (·.kind == .prospective)).map fun sub =>
    (sub.id, (t.claims.filter (·.subject == sub.id)).map (·.id))).filter (!·.2.isEmpty)
  checkEq "cli groups: subject order, then trace order inside a subject" got want
  checkEq "cli groups: P before T, each claim once" got [("P", ["P1", "P2"]), ("T", ["T1", "T2"])]

end Tests.Cli
