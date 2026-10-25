import Fvtrace
import Tests.Harness

namespace Tests.Export
open Tests Fvtrace Fvtrace.Export

def count (s sub : String) : Nat := (s.splitOn sub).length - 1

/-- The page assembly pieces (no I/O). -/
def pureTests : TestM Unit := do
  checkEq "export: base64 (RFC 4648 vectors)"
    (["", "f", "fo", "foo", "foob", "fooba", "foobar"].map (base64 ·.toUTF8))
    ["", "Zg==", "Zm8=", "Zm9v", "Zm9vYg==", "Zm9vYmE=", "Zm9vYmFy"]
  checkEq "export: hex to bytes" (hexBytes "00ff10").toList [0, 255, 16]
  checkEq "export: base64 of a top-6-bit triple + of SHA-256(\"\") (a CSP hash)"
    [base64 (hexBytes "fc0000"),
      base64 (hexBytes "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")]
    ["/AAA", "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="]
  let tricky := Json.Value.obj [("a", .str "</script><!-- & \u2028\u2029 >")]
  let safe := htmlSafe tricky.canonical
  check "export: no tag, comment or line separator survives in the data block"
    (count safe "<" == 0 && count safe ">" == 0 && count safe "&" == 0 &&
      count safe "\u2028" == 0 && count safe "\u2029" == 0) safe
  check "export: the escaped data block means the same JSON"
    ((Json.parse safe.toUTF8).toOption == some tricky)
  checkEq "export: an import line" (parseImport "import { a, b } from \"./m.js\";")
    (some (["a", "b"], "m"))
  checkEq "export: a multi-line import is refused" (parseImport "import {") none
  checkEq "export: export names"
    (["export function h(tag) {", "export const verdicts = {", "export class E extends Error {}",
      "export default x;"].map exportName) [some "h", some "verdicts", some "E", none]
  checkEq "export: a name keeps letters, digits, _ and $"
    (exportName "export function a_1$b(x) {") (some "a_1$b")
  match bundle modules with
  | .error m => check "export: the GUI modules bundle" false m
  | .ok script =>
    let lines := script.splitOn "\n"
    check "export: the bundle keeps no import or export statement"
      (lines.all fun l => !(l.trimAscii.toString.startsWith "import ") &&
        !(l.trimAscii.toString.startsWith "export ")) script
    let pos := fun (m : String) => (script.splitOn s!"const __{m} = ").head!.length
    check "export: modules come after the modules they import"
      (pos "words" < pos "circuit" && pos "dom" < pos "circuit" && pos "circuit" < pos "panels" &&
        pos "panels" < pos "app" && pos "envelope" < pos "app")
  let wrapped := "export: an import over several lines resolves (Prettier wraps long ones)"
  match bundle [("a", "export const x = 1;\nexport const y = 2;"),
      ("b", "import {\n  x,\n  y,\n} from \"./a.js\";\nexport const z = x + y;")] with
  | .error m => check wrapped false m
  | .ok script =>
    check wrapped (count script "  const { x, y } = __a;\n" == 1 && count script "import" == 0)
      script
  checkEq "export: an import that never names its source is refused"
    ((bundle [("b", "import {\n  x,\nexport const z = x;")]).toOption) none
  checkEq "export: an unsupported export is refused"
    ((bundle [("m", "export default 1;")]).toOption) none
  checkEq "export: a cycle is refused"
    ((bundle [("a", "import { y } from \"./b.js\";"),
      ("b", "import { x } from \"./a.js\";")]).toOption)
    none
  checkEq "export: base64 text = the base64 alphabet + padding alone"
    (["QUJD+/09", "", "QUJD<", "QU JD", "QUJD\n", "QUJD-_"].map base64Text)
    [true, true, false, false, false, false]
  checkEq "export: a missing module is refused"
    ((bundle [("a", "import { y } from \"./zz.js\";")]).toOption) none
  checkEq "export: a module holding </script is refused"
    ((bundle [("m", "const s = \"</script>\";")]).toOption) none

/-- The page + bundle on the synthetic study (SHA-256 over FFI: native suite). -/
def nativeTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let proj := dir / "proj"
    IO.FS.createDirAll (proj / "proofs")
    IO.FS.writeFile (proj / "proofs" / "Contrast.lean")
      "theorem contrast_correct : True := trivial\n"
    let env : Store.Env := { home := dir / "home", cwd := proj }
    let run := fun (args : List String) => capture (Cli.runIn env args)
    let (_, _, _) ← run ["init"]
    let (_, pathOut, _) ← run ["path"]
    IO.FS.writeBinFile pathOut.trimAscii.toString
      (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json")
    let (_, _, _) ← run ["pin"]
    -- export reads each evidence file again: a planted digest for the same size + mtime is ignored.
    let real ← IO.FS.realPath (proj / "proofs" / "Contrast.lean")
    let m ← real.metadata
    let planted : Receipt.Cache :=
      ({} : Receipt.Cache).insert real.toString (m.byteSize, m.modified.sec, m.modified.nsec, "x")
    Receipt.Cache.save planted
      ((System.FilePath.mk pathOut.trimAscii.toString).parent.get! / "cache.json")
    let pagePath := dir / "claims.html"
    let (rc, out, _) ← run ["export", "--html", pagePath.toString]
    checkEq "export: --html rc" rc 0
    check "export: --html names the page" (count out "claims.html" == 1) out
    let html ← IO.FS.readFile pagePath
    let script := ((html.splitOn "<script type=\"module\">")[1]!.splitOn "</script>")[0]!
    check "export: the CSP admits exactly the inline script + WebAssembly compilation"
      (count html s!"script-src {← cspHash script} 'wasm-unsafe-eval';" == 1 &&
        count html "unsafe-eval" == 1)
    let block := ((html.splitOn "id=\"fvtrace-engine\">")[1]!.splitOn "</script>")[0]!
    check "export: the page carries the engine block once, as built"
      (count html "id=\"fvtrace-engine\"" == 1 && block == Export.engine && !block.isEmpty &&
        Export.base64Text block)
    check "export: the page requires Trusted Types, one policy for its engine's Worker"
      (count html "require-trusted-types-for 'script'; trusted-types fvtrace-engine" == 1 &&
        count html "worker-src blob:;" == 1)
    let worker := ((html.splitOn "id=\"fvtrace-worker\">")[1]!.splitOn "</script>")[0]!
    check "export: the page carries its engine worker once, apart from the page's script"
      (count html "id=\"fvtrace-worker\"" == 1 &&
        some worker == (Export.bundle Export.workerModules).toOption &&
        count script "const __worker" == 0)
    check "export: the page links no file" (count html "src=\"" == 0 && count html "href=\"" == 0)
    let island := ((html.splitOn "id=\"fvtrace-data\">")[1]!.splitOn "</script>")[0]!
    check "export: the page's receipts come from a fresh read (no cache)"
      (count island "\"current\":false" == 0 && count island "\"current\":true" ≥ 1)
    match Json.parse island.toUTF8 with
    | .error e => check "export: the data block is JSON" false e.message
    | .ok (.obj kvs) =>
      let tg ← IO.ofExcept (← Store.resolve env none none)
      match ← Session.load tg false none false (← IO.mkRef {}) with
      | .error _ => check "export: the data block holds the recorded envelope" false
      | .ok l =>
        checkEq "export: the data block = schema 2, the recorded envelope + the snapshot"
          (kvs.map (·.1)) ["recorded", "schema", "snapshot"]
        check "export: the data block holds the recorded envelope (canonical: sorted keys)"
          ((kvs.lookup "recorded").map (·.canonical) == some (Session.envelope l).canonical)
        match kvs.lookup "snapshot" with
        | some v =>
          check "export: the snapshot is what the load read (E-snap)"
            ((Snapshot.decode v.canonical).toOption == some (Export.snapshot l))
          check "export: the engine's recorded answer = the recorded envelope (first paint)"
            (Snapshot.evaluate v.canonical "" == (Session.envelope l).pretty)
        | none => check "export: the data block holds a snapshot" false
    | .ok _ => check "export: the data block is an object" false
    let tg ← IO.ofExcept (← Store.resolve env none none)
    match ← Session.load tg false none true (← IO.mkRef {}) with
    | .error _ => check "export: the study loads for a planted engine" false
    | .ok l =>
      for (name, text) in [("an empty engine", ""), ("an engine that is not base64", "H4sI</")] do
        match ← (pageWith text l).toBaseIO with
        | .ok _ => check s!"export: a page around {name} is refused" false
        | .error e =>
          check s!"export: a page around {name} is refused" (count (toString e) "base64" == 1)
            (toString e)
    let (rc, _, err) ← run ["export", "--html", (proj / "claims.html").toString]
    checkEq "export: a page inside the project is refused" rc 2
    check "export: the refusal names the project" (count err "project folder" == 1) err
    let b := dir / "bundle"
    let (rc, _, _) ← run ["export", "--bundle", b.toString]
    checkEq "export: --bundle rc" rc 0
    check "export: the bundle copies the evidence byte for byte"
      ((← IO.FS.readBinFile (b / "project" / "proofs" / "Contrast.lean")) ==
        (← IO.FS.readBinFile (proj / "proofs" / "Contrast.lean")))
    let (rc, out, _) ← run ["check", "--trace", (b / "trace.json").toString, "--project",
      (b / "project").toString, "--strict"]
    checkEq "export: the bundle's receipts check against its copies" rc 0
    check "export: the bundle receipt reads current" (count out "receipt O1: current" == 1) out
    let (rc, _, _) ← run ["export", "--bundle", b.toString]
    checkEq "export: a non-empty bundle folder is refused" rc 2
    let absent := (dir / "absent.json").toString
    let pinnedT ← match decodeTrace (← IO.FS.readBinFile pathOut.trimAscii.toString) with
      | .ok t => pure t
      | .error _ => throw (IO.userError "the pinned trace does not decode")
    Cli.writeTrace absent { pinnedT with facts := pinnedT.facts.map fun f =>
      if f.id == "O1" then { f with evidence := f.evidence.map fun ev =>
        { ev with artifacts := ev.artifacts.map fun a => { a with path := "proofs/Absent.lean" } } }
      else f }
    let (rc, _, err) ← run ["export", "--bundle", (dir / "bundle2").toString, "--trace", absent]
    check "export: a bundle missing an evidence file exits 1 and names it"
      (rc == 1 && count err "cannot copy missing proofs/Absent.lean" == 1) err
    IO.FS.createDirAll (proj / "inside")
    let linked ← symlink (proj / "inside") (dir / "alias")
    let (rc, _, _) ← run ["export", "--bundle", (dir / "alias").toString]
    check "export: a link into the project is refused as a bundle folder" (linked && rc == 2)
    unlink (dir / "alias")
    IO.FS.removeDirAll (proj / "inside")
    let (rc, _, err) ← capture (Cli.runIn { home := proj / "proofs" / "Contrast.lean", cwd := proj }
      ["init"])
    checkEq "cli: an I/O failure no command anticipates exits 2" rc 2
    check "cli: the I/O failure is named" (err.startsWith "fvtrace: ") err
    let (rc, _, _) ← run ["export"]
    checkEq "export: no --html or --bundle rc" rc 2
    checkEq "export: nothing written into the project"
      ((← (proj / "proofs").readDir).map (·.fileName)).toList ["Contrast.lean"]

end Tests.Export
