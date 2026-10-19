import Fvtrace.Args
import Tests.Harness

namespace Tests.Args
open Tests Fvtrace

def spec : Args.Spec := { valued := ["--project"], switches := ["--json"], positional := [1, 2] }

def parsed (args : List String) : Option (List String × List (String × String) × List String) :=
  (Args.parse spec args).toOption.map fun p => (p.positional, p.values, p.switches)

def failure (args : List String) : Option String :=
  match Args.parse spec args with
  | .ok _ => none
  | .error m => some m

def tests : TestM Unit := do
  checkEq "args: positional, value + switch" (parsed ["t.json", "--project", "p", "--json"])
    (some (["t.json"], [("--project", "p")], ["--json"]))
  checkEq "args: order of positionals kept" (parsed ["a", "--json", "b"])
    (some (["a", "b"], [], ["--json"]))
  checkEq "args: unknown option" (failure ["t.json", "--nope"]) (some "unknown option --nope")
  checkEq "args: missing value" (failure ["t.json", "--project"]) (some "--project needs a value")
  checkEq "args: repeated value" (failure ["t", "--project", "a", "--project", "b"])
    (some "--project given twice")
  checkEq "args: repeated switch" (failure ["t", "--json", "--json"]) (some "--json given twice")
  checkEq "args: too few positionals" (failure []) (some "expected 1 or 2 arguments, got 0")
  checkEq "args: too many positionals" (failure ["a", "b", "c"])
    (some "expected 1 or 2 arguments, got 3")
  checkEq "args: a command declaring no positionals takes none"
    ((Args.parse {} []).toOption.isSome, (Args.parse {} ["x"]).toOption.isSome) (true, false)
  check "args: lookups" ((Args.parse spec ["t", "--project", "p"]).toOption.all fun p =>
    p.value? "--project" == some "p" && p.value? "--other" == none && !p.has "--json")

end Tests.Args
