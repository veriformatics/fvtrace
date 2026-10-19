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
  area "cli" do Tests.Cli.tests; Tests.Cli.skillTests; Tests.Cli.writeTests
  area "json" Tests.Json.tests
  area "decode" do
    Tests.Decode.tests; Tests.Decode.sizeTests; Tests.Decode.outcomeOrderTests
  area "schema" Tests.Schema.tests
  area "assets" Tests.Assets.tests
  area "check" Tests.Check.tests
  area "args" Tests.Args.tests
  area "engine" do Tests.Engine.tests; Tests.Engine.witnessTests
  area "server" Tests.Server.pureTests
  area "export" Tests.Export.pureTests

/-- Suites that call the C digest code: native binary alone (`lake test`). -/
def native : TestM Unit := do
  area "digest" Tests.Digest.tests
  area "receipt" Tests.Receipt.tests
  area "cli-store" Tests.CliStore.tests
  area "server-native" Tests.Server.nativeTests
  area "export-native" Tests.Export.nativeTests

/-- Every suite, in run order (`lake test`). -/
def all : TestM Unit := do
  pure
  native

end Tests
