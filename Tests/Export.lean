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
  checkEq "export: an unsupported export is refused"
    ((bundle [("m", "export default 1;")]).toOption) none
  checkEq "export: a cycle is refused"
    ((bundle [("a", "import { y } from \"./b.js\";"),
      ("b", "import { x } from \"./a.js\";")]).toOption)
    none
  checkEq "export: a missing module is refused"
    ((bundle [("a", "import { y } from \"./zz.js\";")]).toOption) none

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
    let pagePath := dir / "claims.html"
    let (rc, out, _) ← run ["export", "--html", pagePath.toString]
    checkEq "export: --html rc" rc 0
    check "export: --html names the page" (count out "claims.html" == 1) out
    let html ← IO.FS.readFile pagePath
    let script := ((html.splitOn "<script type=\"module\">")[1]!.splitOn "</script>")[0]!
    check "export: the CSP admits exactly the inline script"
      (count html s!"script-src {← cspHash script};" == 1)
    check "export: the page requires Trusted Types"
      (count html "require-trusted-types-for 'script'; trusted-types 'none'" == 1)
    check "export: the page links no file" (count html "src=\"" == 0 && count html "href=\"" == 0)
    let island := ((html.splitOn "id=\"fvtrace-data\">")[1]!.splitOn "</script>")[0]!
    match Json.parse island.toUTF8 with
    | .error e => check "export: the data block is JSON" false e.message
    | .ok (.obj kvs) =>
      let tg ← IO.ofExcept (← Store.resolve env none none)
      match ← Session.load tg false none false (← IO.mkRef {}) with
      | .error _ => check "export: the data block holds the recorded envelope" false
      | .ok l =>
        check "export: the data block holds the recorded envelope (canonical: sorted keys)"
          ((kvs.lookup "recorded").map (·.canonical) == some (Session.envelope l).canonical)
        let ids := (Evaluate.actions l.scenario).map (·.1)
        checkEq "export: one envelope per one-click action"
          (match kvs.lookup "actions" with | some (.obj as) => as.map (·.1) | _ => [])
          (ids.mergeSort (· ≤ ·))
    | .ok _ => check "export: the data block is an object" false
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
    let (rc, _, _) ← run ["export"]
    checkEq "export: no --html or --bundle rc" rc 2
    checkEq "export: nothing written into the project"
      ((← (proj / "proofs").readDir).map (·.fileName)).toList ["Contrast.lean"]

end Tests.Export
