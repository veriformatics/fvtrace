import Fvtrace.Version

namespace Fvtrace.Cli

def usage : String :=
  "usage: fvtrace <command> [options]\n\n" ++
  "Commands:\n" ++
  "  --version   Print the fvTrace version.\n" ++
  "  --help      Print this help.\n"

/-- Exit codes: 0 = success, 2 = usage error. -/
def run (args : List String) : IO UInt32 := do
  match args with
  | ["--version"] => IO.println s!"fvtrace {version}"; pure 0
  | ["--help"] | ["-h"] => IO.print usage; pure 0
  | [] => IO.eprint usage; pure 2
  | cmd :: _ => IO.eprintln s!"fvtrace: unknown command '{cmd}'"; IO.eprint usage; pure 2

end Fvtrace.Cli
