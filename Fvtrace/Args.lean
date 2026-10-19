/-!
# Command-line options

`fvtrace <command> [positional…] [--flag [value]]…`. Each command declares its flags; an unknown
flag, a missing value or a wrong positional count is a usage error (exit 2).
-/

namespace Fvtrace.Args

structure Spec where
  /-- Flags taking a value (`--project DIR`). -/
  valued : List String := []
  /-- Flags without a value (`--json`). -/
  switches : List String := []
  /-- Allowed positional counts. -/
  positional : List Nat := [0]

structure Parsed where
  positional : List String := []
  values : List (String × String) := []
  switches : List String := []

def Parsed.value? (p : Parsed) (flag : String) : Option String := p.values.lookup flag
def Parsed.has (p : Parsed) (flag : String) : Bool := p.switches.contains flag

def parse (spec : Spec) (args : List String) : Except String Parsed :=
  go args {}
where
  go : List String → Parsed → Except String Parsed
    | [], p =>
      if spec.positional.contains p.positional.length then
        .ok { p with positional := p.positional.reverse }
      else
        let counts := " or ".intercalate (spec.positional.map toString)
        .error s!"expected {counts} arguments, got {p.positional.length}"
    | a :: rest, p =>
      if a.startsWith "--" then
        if spec.switches.contains a then
          if p.switches.contains a then .error s!"{a} given twice"
          else go rest { p with switches := a :: p.switches }
        else if spec.valued.contains a then
          match rest with
          | v :: rest' =>
            if p.values.any (·.1 == a) then .error s!"{a} given twice"
            else go rest' { p with values := (a, v) :: p.values }
          | [] => .error s!"{a} needs a value"
        else .error s!"unknown option {a}"
      else go rest { p with positional := a :: p.positional }

end Fvtrace.Args
