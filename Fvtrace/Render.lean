/-!
# Terminal-safe text

Trace content reaches the terminal (unknown JSON keys echo in diagnostics, texts in reports); a
control character there could drive the terminal (cursor moves, title or clipboard sequences).
Every text line the CLI prints passes through `safe`.
-/

namespace Fvtrace.Render

def hex2 (n : Nat) : String :=
  let d := "0123456789abcdef".toList
  String.ofList [d[n / 16 % 16]!, d[n % 16]!]

/-- C0 controls, DEL and C1 controls as `\u{xx}`; everything else unchanged. -/
def safe (s : String) : String :=
  s.foldl (init := "") fun acc c =>
    let n := c.toNat
    if n < 0x20 || (0x7f ≤ n && n ≤ 0x9f) then acc ++ "\\u{" ++ hex2 n ++ "}" else acc.push c

end Fvtrace.Render
