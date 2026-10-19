/-!
# Terminal-safe text

Trace content reaches the terminal (unknown JSON keys echo in diagnostics, texts in reports); a
control character there could drive the terminal (cursor moves, title or clipboard sequences), and
a bidirectional formatting character could reorder how the rest of the line reads. Every text line
the CLI prints passes through `safe`.
-/

namespace Fvtrace.Render

/-- Lowercase hex of `n`, at least two digits. -/
def hex (n : Nat) : String :=
  String.ofList ((if n < 16 then ['0'] else []) ++ Nat.toDigits 16 n)

/-- Bidirectional formatting characters: U+061C, U+200E–U+200F, U+202A–U+202E, U+2066–U+2069. -/
def bidi (n : Nat) : Bool :=
  n == 0x61c || n == 0x200e || n == 0x200f || (0x202a ≤ n && n ≤ 0x202e) ||
    (0x2066 ≤ n && n ≤ 0x2069)

/-- C0 controls, DEL, C1 controls + bidirectional formatting as `\u{xx}`; the rest unchanged. -/
def safe (s : String) : String :=
  s.foldl (init := "") fun acc c =>
    let n := c.toNat
    if n < 0x20 || (0x7f ≤ n && n ≤ 0x9f) || bidi n then acc ++ "\\u{" ++ hex n ++ "}"
    else acc.push c

end Fvtrace.Render
