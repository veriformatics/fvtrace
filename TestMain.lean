import Tests

def main (args : List String) : IO UInt32 := do
  -- The replay tests run this binary as their verifier (no shell on any OS).
  if let "--replay-fixture" :: steps := args then return ← Tests.Replay.fixture steps
  -- The page engine's differential test (tests/engine/) compares the WebAssembly build with this
  -- native evaluation, for what-ifs a command line cannot carry (a NUL) too.
  if let ["--evaluate-snapshot", snapshot, specs] := args then
    return ← Tests.Snapshot.evaluateFile snapshot specs
  Tests.report (← Tests.exec Tests.all)
