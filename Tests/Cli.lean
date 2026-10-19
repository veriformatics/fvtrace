import Fvtrace
import Tests.Harness

namespace Tests.Cli
open Tests

def tests : TestM Unit := do
  let (rc, out, _) ← capture (Fvtrace.Cli.run ["--version"])
  checkEq "cli: --version rc" rc 0
  checkEq "cli: --version prints the version" out s!"fvtrace {Fvtrace.version}\n"
  let (rc, out, err) ← capture (Fvtrace.Cli.run [])
  checkEq "cli: no command rc" rc 2
  check "cli: no command prints usage on stderr" (out.isEmpty && err.startsWith "usage: fvtrace")
  let (rc, _, err) ← capture (Fvtrace.Cli.run ["bogus"])
  checkEq "cli: unknown command rc" rc 2
  check "cli: unknown command named" (err.startsWith "fvtrace: unknown command 'bogus'") err

end Tests.Cli
