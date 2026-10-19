import Tests

/-- The FFI-free suites, run interpreted: `lake env lean --run TestPure.lean`. -/
def main : IO UInt32 := do
  let ((), run) ← Tests.pure.run {}
  Tests.report run
