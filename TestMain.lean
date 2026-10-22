import Tests

def main : IO UInt32 := do
  Tests.report (← Tests.exec Tests.all)
