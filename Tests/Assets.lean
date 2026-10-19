import Fvtrace
import Tests.Harness

namespace Tests.Assets
open Tests

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
  checkEq "assets: every GUI file in web/ is embedded"
    (shipped.mergeSort (· ≤ ·)) ((FvtraceWeb.files.map (fileOf ·.1)).mergeSort (· ≤ ·))

end Tests.Assets
