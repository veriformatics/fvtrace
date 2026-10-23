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
import Tests.Evaluate
import Tests.Server
import Tests.Export
import Tests.Fields
import Tests.Replay
import Tests.Snapshot
import Tests.Wasm

namespace Tests

/-- Suites that call no FFI code: the interpreter can run them (`TestPure.lean`, mutation
credit). -/
def pure : TestM Unit := do
  area "cli" do
    Tests.Cli.tests; Tests.Cli.skillTests; Tests.Cli.writeTests; Tests.Cli.bindTests
    Tests.Cli.readTests
  area "json" Tests.Json.tests
  area "decode" do
    Tests.Decode.tests; Tests.Decode.sizeTests; Tests.Decode.outcomeOrderTests
  area "schema" Tests.Schema.tests
  area "assets" Tests.Assets.tests
  area "check" Tests.Check.tests
  area "args" Tests.Args.tests
  area "engine" do
    Tests.Engine.tests; Tests.Engine.witnessTests; Tests.Engine.kindTests
    Tests.Engine.acceptanceTests
  area "evaluate" Tests.Evaluate.tests
  area "server" Tests.Server.pureTests
  area "export" Tests.Export.pureTests
  area "fields" Tests.Fields.tests
  area "replay-pure" Tests.Replay.pureTests
  area "snapshot" Tests.Snapshot.pureTests
  area "wasm" do Tests.Wasm.pureTests; Tests.Wasm.markerTests

/-- Suites that call the C digest code, or run too long interpreted (plan-scale: 3 s, rerun by
every mutant): native binary alone (`lake test`). -/
def native : TestM Unit := do
  area "digest" Tests.Digest.tests
  area "receipt" Tests.Receipt.tests
  area "cli-store" Tests.CliStore.tests
  area "server-native" Tests.Server.nativeTests
  area "export-native" Tests.Export.nativeTests
  area "plan-scale" Tests.Engine.scaleTests
  area "json-scale" Tests.Json.scaleTests
  area "replay" Tests.Replay.tests
  area "fields-native" Tests.Fields.nativeTests
  area "snapshot-native" Tests.Snapshot.nativeTests
  area "wasm-native" Tests.Wasm.nativeTests

/-- Every suite, in run order (`lake test`). -/
def all : TestM Unit := do
  pure
  native

end Tests
