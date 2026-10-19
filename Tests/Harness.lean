namespace Tests

structure Outcome where
  name : String
  ok : Bool
  detail : String

abbrev TestM := StateT (Array Outcome) IO

def check (name : String) (ok : Bool) (detail : String := "") : TestM Unit :=
  modify (·.push { name, ok, detail })

def checkEq {α : Type} [BEq α] [Repr α] (name : String) (got want : α) : TestM Unit :=
  check name (got == want) s!"got {repr got}, want {repr want}"

/-- Runs `act` with stdout + stderr captured; returns (result, stdout, stderr). -/
def capture {α : Type} (act : IO α) : IO (α × String × String) := do
  let out ← IO.mkRef ({} : IO.FS.Stream.Buffer)
  let err ← IO.mkRef ({} : IO.FS.Stream.Buffer)
  let r ← IO.withStdout (IO.FS.Stream.ofBuffer out) <| IO.withStderr (IO.FS.Stream.ofBuffer err) act
  let o := String.fromUTF8! (← out.get).data
  let e := String.fromUTF8! (← err.get).data
  return (r, o, e)

/-- Prints each failure + a summary; rc 0 iff every check passed. -/
def report (outcomes : Array Outcome) : IO UInt32 := do
  let failed := outcomes.filter (!·.ok)
  for f in failed do
    IO.eprintln s!"FAIL {f.name}: {f.detail}"
  IO.println s!"{outcomes.size - failed.size}/{outcomes.size} checks passed"
  return if failed.isEmpty then 0 else 1

end Tests
