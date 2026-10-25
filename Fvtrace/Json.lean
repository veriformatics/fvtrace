import Fvtrace.Render

/-!
# JSON values, parser and printers

The trace format's JSON subset (`.agent/contracts/kernel.md` D-json, D-canon): integers alone,
duplicate keys rejected, nesting ≤ 64. Written on `Std` alone (`Lean.Data.Json` would link all of
`Lean` into the binary). The parser is total: every step consumes fuel bounded by the input size.
-/

namespace Fvtrace.Json

inductive Value where
  | null
  | bool (b : Bool)
  | num (n : Int)
  | str (s : String)
  | arr (xs : List Value)
  | obj (kvs : List (String × Value))
  deriving Repr, Inhabited

/-- `f` holds for every pair of same-position elements, a loop (`List.zip` recurses once per
element: the page engine's WebAssembly stack overflows near 9,600). -/
def allPairs {α β : Type} (f : α → β → Bool) : List α → List β → Bool
  | a :: as, b :: bs => f a b && allPairs f as bs
  | _, _ => true

/-- Structural equality; objects compare in member order. -/
partial def Value.beq : Value → Value → Bool
  | .null, .null => true
  | .bool a, .bool b => a == b
  | .num a, .num b => a == b
  | .str a, .str b => a == b
  | .arr a, .arr b => a.length == b.length && allPairs (fun x y => x.beq y) a b
  | .obj a, .obj b =>
    a.length == b.length && allPairs (fun x y => x.1 == y.1 && x.2.beq y.2) a b
  | _, _ => false

instance : BEq Value := ⟨Value.beq⟩

def maxDepth : Nat := 64

structure ParseError where
  /-- Byte offset into the input. -/
  offset : Nat
  message : String
  deriving Repr, BEq

/-- 1-based line and column (in bytes) of a byte offset. -/
def lineCol (input : ByteArray) (offset : Nat) : Nat × Nat := Id.run do
  let mut line := 1
  let mut col := 1
  for i in [0:min offset input.size] do
    if input[i]! == 10 then
      line := line + 1
      col := 1
    else
      col := col + 1
  return (line, col)

namespace Parse

abbrev Result (α : Type) := Except ParseError (α × Nat)

@[inline] def byteAt (b : ByteArray) (i : Nat) : Option UInt8 :=
  if h : i < b.size then some b[i] else none

def isWs (c : UInt8) : Bool := c == 32 || c == 9 || c == 10 || c == 13

def skipWs (b : ByteArray) (i : Nat) : Nat := Id.run do
  let mut j := i
  while (byteAt b j).any isWs do
    j := j + 1
  return j

def fail {α : Type} (offset : Nat) (message : String) : Result α :=
  .error { offset, message }

def expectLit (b : ByteArray) (i : Nat) (lit : String) (v : Value) : Result Value :=
  let bytes := lit.toUTF8
  if (List.range bytes.size).all (fun k => byteAt b (i + k) == some bytes[k]!) then
    .ok (v, i + bytes.size)
  else fail i "invalid literal"

def hexVal (c : UInt8) : Option Nat :=
  if 48 ≤ c && c ≤ 57 then some (c - 48).toNat
  else if 97 ≤ c && c ≤ 102 then some (c - 87).toNat
  else if 65 ≤ c && c ≤ 70 then some (c - 55).toNat
  else none

def hex4 (b : ByteArray) (i : Nat) : Option Nat := do
  let a ← hexVal (← byteAt b i)
  let c ← hexVal (← byteAt b (i + 1))
  let d ← hexVal (← byteAt b (i + 2))
  let e ← hexVal (← byteAt b (i + 3))
  return ((a * 16 + c) * 16 + d) * 16 + e

def pushUtf8 (out : ByteArray) (c : Char) : ByteArray :=
  out ++ (String.singleton c).toUTF8

/-- A string token starting at the opening quote `i`; raw bytes are copied (the whole input was
UTF-8-validated), escapes decoded, raw control characters rejected. -/
def string (b : ByteArray) (i : Nat) : Result String := Id.run do
  let mut out := ByteArray.empty
  let mut j := i + 1
  while j < b.size do
    let c := b[j]!
    if c == 34 then
      return match String.fromUTF8? out with
        | some s => .ok (s, j + 1)
        | none => fail i "invalid UTF-8 in string"
    else if c < 32 then
      return fail j "control character in string"
    else if c == 92 then
      match byteAt b (j + 1) with
      | some 34 => out := out.push 34; j := j + 2
      | some 92 => out := out.push 92; j := j + 2
      | some 47 => out := out.push 47; j := j + 2
      | some 98 => out := out.push 8; j := j + 2
      | some 102 => out := out.push 12; j := j + 2
      | some 110 => out := out.push 10; j := j + 2
      | some 114 => out := out.push 13; j := j + 2
      | some 116 => out := out.push 9; j := j + 2
      | some 117 =>
        match hex4 b (j + 2) with
        | none => return fail j "invalid \\u escape"
        | some hi =>
          if 0xD800 ≤ hi && hi < 0xDC00 then
            match byteAt b (j + 6), byteAt b (j + 7), hex4 b (j + 8) with
            | some 92, some 117, some lo =>
              if 0xDC00 ≤ lo && lo < 0xE000 then
                let cp := 0x10000 + (hi - 0xD800) * 0x400 + (lo - 0xDC00)
                out := pushUtf8 out (Char.ofNat cp)
                j := j + 12
              else return fail j "unpaired surrogate in \\u escape"
            | _, _, _ => return fail j "unpaired surrogate in \\u escape"
          else if 0xDC00 ≤ hi && hi < 0xE000 then
            return fail j "unpaired surrogate in \\u escape"
          else
            out := pushUtf8 out (Char.ofNat hi)
            j := j + 6
      | _ => return fail j "invalid escape"
    else
      out := out.push c
      j := j + 1
  return fail i "unterminated string"

def isDigit (c : UInt8) : Bool := 48 ≤ c && c ≤ 57

/-- D-json: digits an integer may carry. The trace format's one number is `1`; `cache.json`'s
sizes + times fit 64 bits. Without a cap, folding n digits into one integer costs n²: a 16 MiB
number would take hours. -/
def maxDigits : Nat := 20

/-- An integer; a fraction or exponent is rejected (the format carries integers alone). -/
def number (b : ByteArray) (i : Nat) : Result Value := Id.run do
  let mut j := i
  let neg := byteAt b j == some 45
  if neg then j := j + 1
  match byteAt b j with
  | some c =>
    if !isDigit c then return fail i "invalid number"
    if c == 48 && (byteAt b (j + 1)).any isDigit then return fail i "leading zero in number"
  | none => return fail i "invalid number"
  let start := j
  let mut n : Nat := 0
  repeat
    let some c := byteAt b j | break
    unless isDigit c do break
    if j - start == maxDigits then return fail i s!"integer longer than {maxDigits} digits"
    n := n * 10 + (c - 48).toNat
    j := j + 1
  if byteAt b j == some 46 || byteAt b j == some 101 || byteAt b j == some 69 then
    return fail i "non-integer number"
  return .ok (.num (if neg then -(n : Int) else n), j)

/-- The earliest repeated key among an object's `(key, offset)` pairs, the place where a scan
comparing each key with every earlier one stops, found in O(k log k) instead of k²: a stable sort
by key keeps equal keys in document order, so every entry after the first of its key repeats it.
One left fold carrying the previous key (an object may hold tens of thousands of keys, past the
page engine's WebAssembly stack for a recursion per key). -/
def firstRepeat (keys : List (String × Nat)) : Option (String × Nat) :=
  let sorted := keys.mergeSort fun a b => a.1 ≤ b.1
  (sorted.foldl (init := ((none : Option (String × Nat)), (none : Option String))) fun st b =>
    (if st.2 != some b.1 then st.1
     else match st.1 with
       | some r => if b.2 < r.2 then some b else st.1
       | none => some b, some b.1)).1

mutual
  /-- One value after optional whitespace. `fuel` bounds the recursion (≥ remaining bytes). -/
  def value (b : ByteArray) (fuel depth i : Nat) : Result Value :=
    match fuel with
    | 0 => fail i "unexpected end of input"
    | fuel + 1 =>
      let i := skipWs b i
      match byteAt b i with
      | none => fail i "unexpected end of input"
      | some c =>
        if c == 123 then
          if depth ≥ maxDepth then fail i "nesting deeper than 64"
          else members b fuel (depth + 1) (i + 1) [] []
        else if c == 91 then
          if depth ≥ maxDepth then fail i "nesting deeper than 64"
          else elements b fuel (depth + 1) (i + 1) []
        else if c == 34 then
          match string b i with
          | .ok (s, j) => .ok (.str s, j)
          | .error e => .error e
        else if c == 116 then expectLit b i "true" (.bool true)
        else if c == 102 then expectLit b i "false" (.bool false)
        else if c == 110 then expectLit b i "null" .null
        else if c == 45 || isDigit c then number b i
        else fail i "unexpected character"

  /-- Array elements after `[`; `acc` holds the parsed elements in reverse. -/
  def elements (b : ByteArray) (fuel depth i : Nat) (acc : List Value) : Result Value :=
    match fuel with
    | 0 => fail i "unexpected end of input"
    | fuel + 1 =>
      let i := skipWs b i
      if acc.isEmpty && byteAt b i == some 93 then .ok (.arr [], i + 1)
      else
        match value b fuel depth i with
        | .error e => .error e
        | .ok (v, j) =>
          let j := skipWs b j
          match byteAt b j with
          | some 44 => elements b fuel depth (j + 1) (v :: acc)
          | some 93 => .ok (.arr (v :: acc).reverse, j + 1)
          | _ => fail j "expected ',' or ']'"

  /-- Object members after `{`; `acc` + `keys` (each key with its offset) hold the members so far
  in reverse. A duplicate key is rejected at its offset once the object closes (`firstRepeat`). -/
  def members (b : ByteArray) (fuel depth i : Nat) (acc : List (String × Value))
      (keys : List (String × Nat)) : Result Value :=
    match fuel with
    | 0 => fail i "unexpected end of input"
    | fuel + 1 =>
      let i := skipWs b i
      if acc.isEmpty && byteAt b i == some 125 then .ok (.obj [], i + 1)
      else if byteAt b i != some 34 then fail i "expected a string key"
      else
        match string b i with
        | .error e => .error e
        | .ok (k, j) =>
          let j := skipWs b j
          if byteAt b j != some 58 then fail j "expected ':'"
          else
            match value b fuel depth (j + 1) with
            | .error e => .error e
            | .ok (v, l) =>
              let l := skipWs b l
              match byteAt b l with
              | some 44 => members b fuel depth (l + 1) ((k, v) :: acc) ((k, i) :: keys)
              | some 125 =>
                match firstRepeat ((k, i) :: keys).reverse with
                | some (dup, at_) => fail at_ s!"duplicate key \"{dup}\""
                | none => .ok (.obj ((k, v) :: acc).reverse, l + 1)
              | _ => fail l "expected ',' or '}'"
end

end Parse

/-- Parses a whole document: valid UTF-8, one value, nothing but whitespace after it. -/
def parse (input : ByteArray) : Except ParseError Value :=
  if (String.fromUTF8? input).isNone then .error { offset := 0, message := "input is not UTF-8" }
  else
    match Parse.value input (input.size + 2) 0 0 with
    | .error e => .error e
    | .ok (v, j) =>
      let j := Parse.skipWs input j
      if j < input.size then .error { offset := j, message := "trailing characters" } else .ok v

/-! ## Printers -/

def hexDigit (n : Nat) : Char := "0123456789abcdef".toList[n % 16]!

/-- `\uxxxx` (lowercase) for a code point below U+10000. -/
def uEscape (n : Nat) : String :=
  "\\u" ++ String.ofList ([12, 8, 4, 0].map fun k => hexDigit (n >>> k))

/-- String escaping of D-canon: `JSON.stringify`'s rules (short escapes, other C0 as `\u00xx`,
everything else raw). `shown` (printed JSON: CLI, server, written files) also writes DEL, C1 +
bidirectional formatting characters as `\uxxxx`, since a terminal acts on them; digests keep the
`JSON.stringify` bytes. -/
def escape (s : String) (shown : Bool := false) : String :=
  s.foldl (init := "\"") (fun acc c =>
    match c with
    | '"' => acc ++ "\\\""
    | '\\' => acc ++ "\\\\"
    | '\x08' => acc ++ "\\b"
    | '\x0c' => acc ++ "\\f"
    | '\n' => acc ++ "\\n"
    | '\r' => acc ++ "\\r"
    | '\t' => acc ++ "\\t"
    | c =>
      let n := c.toNat
      if n < 0x20 || (shown && ((0x7f ≤ n && n ≤ 0x9f) || Render.bidi n)) then acc ++ uEscape n
      else acc.push c) ++ "\""

/-- Inserts `k` after every member whose key is not above its own. -/
def insertBy (k : String × Value) : List (String × Value) → List (String × Value)
  | [] => [k]
  | x :: xs => if k.1 < x.1 then k :: x :: xs else x :: insertBy k xs

/-- Members sorted by key (code point order), for the canonical form: equal keys in reversed input
order, the order of the insertion sort `kvs.foldr insertBy []` it replaces (O(n²): a large
outcome map or digest cache) and is proved equal to (`Spec.SortMembersAgree`). -/
def sortMembers (kvs : List (String × Value)) : List (String × Value) :=
  kvs.reverse.mergeSort fun a b => a.1 ≤ b.1

/-- D-canon: sorted keys, no insignificant whitespace. -/
partial def Value.canonical : Value → String
  | .null => "null"
  | .bool b => toString b
  | .num n => toString n
  | .str s => escape s
  | .arr xs => "[" ++ ",".intercalate (xs.map Value.canonical) ++ "]"
  | .obj kvs =>
    "{" ++ ",".intercalate ((sortMembers kvs).map fun (k, v) => escape k ++ ":" ++ v.canonical) ++
      "}"

/-- Two-space indented form in member order, for files fvTrace writes; ends with a newline. -/
partial def Value.pretty (v : Value) : String :=
  go 0 v ++ "\n"
where
  go (indent : Nat) : Value → String
    | .arr [] => "[]"
    | .obj [] => "{}"
    | .arr xs =>
      let pad := "".pushn ' ' (indent + 2)
      "[\n" ++ ",\n".intercalate (xs.map fun x => pad ++ go (indent + 2) x) ++ "\n" ++
        "".pushn ' ' indent ++ "]"
    | .obj kvs =>
      let pad := "".pushn ' ' (indent + 2)
      "{\n" ++
        ",\n".intercalate (kvs.map fun (k, x) =>
          pad ++ escape k (shown := true) ++ ": " ++ go (indent + 2) x) ++
        "\n" ++ "".pushn ' ' indent ++ "}"
    | .str s => escape s (shown := true)
    | v => v.canonical

end Fvtrace.Json
