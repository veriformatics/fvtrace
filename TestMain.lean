import Tests

def main : IO UInt32 := do
  let ((), outcomes) ← Tests.all.run #[]
  Tests.report outcomes
