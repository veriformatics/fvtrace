import Tests.Harness
import Tests.Cli
import Tests.Json
import Tests.Decode
import Tests.Schema
import Tests.Assets
import Tests.Check
import Tests.Digest
import Tests.Receipt
import Tests.Args
import Tests.CliStore
import Tests.Engine
import Tests.Server
import Tests.Export

namespace Tests

/-- Suites that call no FFI code: the interpreter can run them (`TestPure.lean`, mutation
credit). -/
def pure : TestM Unit := do
  Tests.Cli.tests
  Tests.Cli.skillTests
  Tests.Json.tests
  Tests.Decode.tests
  Tests.Schema.tests
  Tests.Assets.tests
  Tests.Check.tests
  Tests.Args.tests
  Tests.Engine.tests
  Tests.Server.pureTests
  Tests.Export.pureTests

/-- Suites that call the C digest code: native binary alone (`lake test`). -/
def native : TestM Unit := do
  Tests.Digest.tests
  Tests.Receipt.tests
  Tests.CliStore.tests
  Tests.Server.nativeTests
  Tests.Export.nativeTests

/-- Every suite, in run order (`lake test`). -/
def all : TestM Unit := do
  pure
  native

end Tests
