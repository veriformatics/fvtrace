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
    let _ ← symlink target (dir / "skills" / "fvtrace") true
    let (rc, _, _) ← capture (Fvtrace.Cli.run ["skills", "install", "--dir",
      (dir / "skills").toString])
    checkEq "skills: a linked skill folder is refused" rc 1
    check "skills: the link's target keeps its files" (← (target / "keep.txt").pathExists)
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
    let linked ← symlink victim (dir / "trace.json.fvtrace-tmp") false
    check "write: a link can be planted at the temporary path" linked
    Fvtrace.Cli.replaceFile file "new"
    checkEq "write: a link at the temporary path is not written through"
      (← IO.FS.readFile victim) "keep"
    checkEq "write: the file gets the new content" (← IO.FS.readFile file) "new"
    check "write: the file is a plain file, not the link"
      ((← file.symlinkMetadata).type == .file)

end Tests.Cli
