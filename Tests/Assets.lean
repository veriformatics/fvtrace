import Fvtrace
import FvtraceEngine
import Tests.Harness

namespace Tests.Assets
open Tests

def count (s sub : String) : Nat := (s.splitOn sub).length - 1

def tests : TestM Unit := do
  let onDisk ← IO.FS.readFile "schema/trace.schema.json"
  check "assets: embedded schema = schema/trace.schema.json" (Fvtrace.Assets.traceSchema == onDisk)
  let (rc, out, _) ← capture (Fvtrace.Cli.run ["schema"])
  checkEq "cli: schema rc" rc 0
  check "cli: schema prints the embedded schema" (out == onDisk)
  check "cli: schema output is JSON" ((Fvtrace.Json.parse out.toUTF8).toOption.isSome)
  let fileOf := fun (path : String) => if path == "/" then "index.html" else path.drop 1 |>.toString
  for (path, _, body) in FvtraceWeb.files do
    check s!"assets: web/{fileOf path} embedded byte-equal"
      (body == (← IO.FS.readFile ("web" / fileOf path)))
  let shipped := (← System.FilePath.readDir "web").toList.map (·.fileName) |>.filter fun n =>
    n.endsWith ".html" || n.endsWith ".js" || n.endsWith ".css"
  for (path, body) in FvtraceSkill.files do
    check s!"assets: skill/fvtrace/{path} embedded byte-equal"
      (body == (← IO.FS.readFile ("skill/fvtrace" / path)))
  let skill := (FvtraceSkill.files.lookup "SKILL.md").getD ""
  let front := (skill.splitOn "---\n")[1]!
  let field := fun (k : String) => (front.splitOn "\n").find? (·.startsWith s!"{k}: ")
  check "skill: frontmatter names the folder" (field "name" == some "name: fvtrace")
  check "skill: the description fits the Agent Skills limit (1-1024 characters)"
    ((field "description").any fun d => 13 < d.length && d.length ≤ 13 + 1024)
  check "skill: the compatibility note fits its limit (1-500 characters)"
    ((field "compatibility").any fun d => d.length ≤ 15 + 500)
  -- The GUI's verdict words (legend, moves, plans) = the engine's labels, one word per state.
  let words := ((FvtraceWeb.files.find? (·.1 == "/words.js")).map (·.2.2)).getD ""
  for st in [Fvtrace.State.can, .conditional, .«open», .cannot] do
    check s!"assets: web/words.js names {st.name} as the engine does"
      (count words s!"  {st.name}: \"{st.verdict}\",\n" == 1) words
  checkEq "assets: every GUI file in web/ is embedded"
    (shipped.mergeSort (· ≤ ·)) ((FvtraceWeb.files.map (fileOf ·.1)).mergeSort (· ≤ ·))
  -- The page engine: what `lake build` wrote, base64 of a gzip stream ("H4sI" = 1f 8b 08).
  let engine := FvtraceEngine.wasmGzipBase64
  check "assets: the embedded engine = .lake/build/wasm/engine.b64"
    (engine == (← IO.FS.readFile ".lake/build/wasm/engine.b64"))
  check "assets: the embedded engine is base64 of gzip"
    (engine.startsWith "H4sI" && engine.length % 4 == 0 &&
      engine.all fun c => c.isAlphanum || c == '+' || c == '/' || c == '=')

end Tests.Assets
