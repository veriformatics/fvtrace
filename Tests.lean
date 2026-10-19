import Tests.Harness
import Tests.Cli

namespace Tests

/-- Every suite, in run order. -/
def all : TestM Unit := do
  Tests.Cli.tests

end Tests
