import Fvtrace

def main (args : List String) : IO UInt32 :=
  Fvtrace.Cli.run args
