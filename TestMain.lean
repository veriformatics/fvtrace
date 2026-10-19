import Tests

def main : IO UInt32 := do
  let ((), run) ← Tests.all.run {}
  Tests.report run
