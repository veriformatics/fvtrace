import FvtraceEngine
import FvtraceWeb
import Fvtrace.Digest
import Fvtrace.Session
import Fvtrace.Snapshot

/-!
# `fvtrace export`: a page or a bundle to share

`--html`: one self-contained page. The GUI's modules are joined into one script; the page carries
the recorded envelope (its first view), a snapshot of what the engine read, and the engine
itself compiled to WebAssembly (`FvtraceEngine`), which evaluates every what-if in the browser
(`.agent/contracts/kernel.md` E-page). A Content Security Policy admits exactly the page's own
script + style by hash, plus WebAssembly compilation. `--bundle`: the trace + copies of its pinned
evidence, laid out so a colleague's `fvtrace serve` checks the receipts against the copies.
Neither writes into the project folder.
-/

namespace Fvtrace.Export
open Fvtrace.Json

/-- The GUI modules as (name, source): `/dom.js` ↦ `("dom", …)`. -/
def modules : List (String × String) :=
  FvtraceWeb.files.filterMap fun (path, _, body) =>
    if path.endsWith ".js" then some ((path.drop 1).dropEnd 3 |>.toString, body) else none

/-- `import { a, b } from "./m.js";` ↦ `(["a", "b"], "m")`. -/
def parseImport (line : String) : Option (List String × String) := do
  let [_, rest] := line.splitOn "{" | none
  let [names, src] := rest.splitOn "} from \"./" | none
  let [m, ";"] := src.splitOn ".js\"" | none
  return ((names.splitOn ",").map (·.trimAscii.toString) |>.filter (!·.isEmpty), m)

/-- The name an `export function|const|class NAME` line declares. -/
def exportName (line : String) : Option String := do
  let decl ← ["export function ", "export const ", "export class "].find? (line.startsWith ·)
  let rest := (line.drop decl.length).toString
  return String.ofList (rest.toList.takeWhile fun c => c.isAlphanum || c == '_' || c == '$')

/-- One module as a block: its imports read from earlier blocks, its exports returned. An import
may span lines (Prettier wraps a long one): it ends on the line that names its source. -/
def block (name src : String) : Except String (List String × String) := do
  let mut out := #[]
  let mut deps := #[]
  let mut exports := #[]
  let mut pending := ""
  for line in src.splitOn "\n" do
    if !pending.isEmpty || line.startsWith "import" then
      let stmt := pending ++ line
      if (stmt.splitOn " from ").length < 2 then
        pending := stmt
        continue
      pending := ""
      let some (names, m) := parseImport stmt
        | throw s!"{name}.js: unsupported import: {stmt}"
      deps := deps.push m
      out := out.push s!"  const \{ {", ".intercalate names} } = __{m};"
    else if line.startsWith "export" then
      let some n := exportName line | throw s!"{name}.js: unsupported export: {line}"
      exports := exports.push n
      out := out.push ("  " ++ (line.drop "export ".length).toString)
    else out := out.push (if line.isEmpty then "" else "  " ++ line)
  unless pending.isEmpty do throw s!"{name}.js: an import never names its source: {pending}"
  let body := "\n".intercalate out.toList
  let ret := if exports.isEmpty then "" else s!"  return \{ {", ".intercalate exports.toList} };\n"
  return (deps.toList, s!"const __{name} = (() => \{\n{body}\n{ret}})();\n")

/-- The modules joined in dependency order into one script (no build step, no loader). -/
def bundle (mods : List (String × String)) : Except String String := do
  let blocks ← mods.mapM fun (n, src) => do
    let (deps, text) ← block n src
    pure (n, deps, text)
  let rec go : Nat → List String → List (String × List String × String) → Except String String
    | 0, _, rest => if rest.isEmpty then .ok "" else .error "the GUI modules import in a cycle"
    | fuel + 1, done, rest => do
      if rest.isEmpty then return ""
      match rest.find? (fun (_, deps, _) => deps.all done.contains) with
      | none => throw "a GUI module imports a missing or cyclic module"
      | some (n, _, text) =>
        let tail ← go fuel (n :: done) (rest.filter (·.1 != n))
        return text ++ tail
  let script ← go (blocks.length + 1) [] blocks
  if (script.splitOn "</script").length > 1 then throw "a GUI module contains </script"
  return script

/-- JSON safe inside an HTML `<script>` data block: `<`, `>`, `&`, U+2028, U+2029 escaped (each
can occur only inside JSON strings, where `\uXXXX` means the same character). -/
def htmlSafe (json : String) : String :=
  json.foldl (init := "") fun acc c =>
    match c with
    | '<' => acc ++ "\\u003c"
    | '>' => acc ++ "\\u003e"
    | '&' => acc ++ "\\u0026"
    | '\u2028' => acc ++ "\\u2028"
    | '\u2029' => acc ++ "\\u2029"
    | c => acc.push c

def base64 (bytes : ByteArray) : String := Id.run do
  let table := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".toList
  let b := bytes.toList.map (·.toNat)
  let mut out := ""
  let mut rest := b
  while !rest.isEmpty do
    let chunk := rest.take 3
    rest := rest.drop 3
    let n := (chunk.getD 0 0 * 256 + chunk.getD 1 0) * 256 + chunk.getD 2 0
    let digits := [n / 262144 % 64, n / 4096 % 64, n / 64 % 64, n % 64]
    let kept := digits.take (chunk.length + 1)
    out := out ++ String.ofList (kept.map (table[·]!)) ++ "".pushn '=' (3 - chunk.length)
  return out

/-- Bytes of a lowercase hex string. -/
def hexBytes (hex : String) : ByteArray :=
  let v := fun (c : Char) => if c.isDigit then c.toNat - 48 else c.toNat - 87
  let rec go : List Char → ByteArray → ByteArray
    | a :: b :: rest, acc => go rest (acc.push (v a * 16 + v b).toUInt8)
    | _, acc => acc
  go hex.toList .empty

/-- A CSP source admitting exactly `text`. -/
def cspHash (text : String) : IO String := do
  return s!"'sha256-{base64 (hexBytes (← Digest.ofString text))}'"

/-- What the page's engine reads (`kernel.md` E-snap): the load's trace + receipts + review. -/
def snapshot (l : Session.Loaded) : Snapshot.Snapshot :=
  { trace := l.scenario.trace, bindings := l.bindings, digest := l.digest, review := l.review }

/-- The data block: the recorded envelope (the page's first view) + the engine's snapshot. -/
def data (l : Session.Loaded) : Value :=
  .obj [("schema", .str "fvtrace.export/2"), ("recorded", Session.envelope l),
    ("snapshot", Snapshot.encode (snapshot l))]

/-- The engine block holds base64 alone, so it cannot close its `<script>`. -/
def base64Text (s : String) : Bool :=
  s.all fun c => c.isAlphanum || c == '+' || c == '/' || c == '='

/-- The engine `lake build` compiled to WebAssembly: base64(gzip(module)). -/
def engine : String := FvtraceEngine.wasmGzipBase64

/-- The page around `engineText` (the build's engine; tests plant others): the GUI's HTML with
its stylesheet + modules inlined under a hash-pinned CSP. -/
def pageWith (engineText : String) (l : Session.Loaded) : IO String := do
  let some (_, _, html) := FvtraceWeb.files.find? (·.1 == "/") | throw (IO.userError "no page")
  let some (_, _, css) := FvtraceWeb.files.find? (·.1 == "/style.css")
    | throw (IO.userError "no stylesheet")
  let script ← IO.ofExcept (bundle modules)
  unless !engineText.isEmpty && base64Text engineText do
    throw (IO.userError "the embedded engine is not base64 text; rebuild fvtrace")
  -- `'wasm-unsafe-eval'` admits WebAssembly compilation alone (JavaScript `eval` stays refused).
  let csp := s!"default-src 'none'; script-src {← cspHash script} 'wasm-unsafe-eval'; " ++
    s!"style-src {← cspHash css}; base-uri 'none'; form-action 'none'; " ++
    "require-trusted-types-for 'script'; trusted-types 'none'"
  let head := s!"<meta http-equiv=\"Content-Security-Policy\" content=\"{csp}\" />\n" ++
    s!"    <style>{css}</style>\n" ++
    s!"    <script type=\"application/json\" id=\"fvtrace-data\">\
      {htmlSafe (data l).canonical}</script>\n" ++
    s!"    <script type=\"application/octet-stream\" id=\"fvtrace-engine\">{engineText}\
      </script>\n" ++
    s!"    <script type=\"module\">{script}</script>"
  let linked := "<link rel=\"stylesheet\" href=\"style.css\" />\n" ++
    "    <script type=\"module\" src=\"app.js\"></script>"
  unless (html.splitOn linked).length == 2 do
    throw (IO.userError "the page no longer links style.css + app.js as the export expects")
  return html.replace linked head

def page (l : Session.Loaded) : IO String := pageWith engine l

/-- Copies a file in 1 MiB chunks (evidence can be far larger than memory). -/
def copyFile (src dest : System.FilePath) : IO Unit := do
  let i ← IO.FS.Handle.mk src .read
  let o ← IO.FS.Handle.mk dest .write
  repeat
    let chunk ← i.read 1048576
    if chunk.isEmpty then break
    o.write chunk

/-- `inner` lies inside `outer` (both real paths). -/
def within (outer inner : System.FilePath) : Bool :=
  outer.components.isPrefixOf inner.components

/-- Copies the trace + every artifact its evidence names into `dir`: `dir/trace.json`,
`dir/project/<path>`, `dir/README.txt`. Returns the artifacts it could not copy. -/
def writeBundle (t : Trace) (project dir : System.FilePath) : IO (List String) := do
  let paths := ((t.facts.filterMap (·.evidence)) ++ (t.exclusions.filterMap (·.evidence))).flatMap
    (·.artifacts.map (·.path)) |>.eraseDups
  let mut problems := []
  for p in paths do
    match ← Receipt.resolve project p with
    | .error why => problems := problems ++ [why]
    | .ok real =>
      let dest := dir / "project" / p
      if let some parent := dest.parent then IO.FS.createDirAll parent
      copyFile real dest
  IO.FS.createDirAll (dir / "project")
  IO.FS.writeFile (dir / "trace.json") (Encode.trace t).pretty
  IO.FS.writeFile (dir / "README.txt") <|
    "This bundle holds an fvTrace trace and copies of the evidence files that it names.\n" ++
    "To see its claims, install fvtrace, then run this command in the folder `project`:\n\n" ++
    "    fvtrace serve --trace ../trace.json\n\n" ++
    "fvtrace checks each receipt against the copies in `project`.\n"
  return problems

end Fvtrace.Export
