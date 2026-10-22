import Tests

def main (args : List String) : IO UInt32 := do
  -- The replay tests run this binary as their verifier (no shell on any OS).
  if let "--replay-fixture" :: steps := args then return ← Tests.Replay.fixture steps
  Tests.report (← Tests.exec Tests.all)
