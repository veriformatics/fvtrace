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

end Tests.Assets
