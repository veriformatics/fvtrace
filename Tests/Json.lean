import Fvtrace.Json
import Tests.Harness

namespace Tests.Json
open Tests Fvtrace.Json

def bytes (s : String) : ByteArray := s.toUTF8

def parses (name input : String) (want : Value) : TestM Unit :=
  match parse (bytes input) with
  | .ok v => check name (v == want) s!"got {repr v}"
  | .error e => check name false s!"error at {e.offset}: {e.message}"

def rejects (name input : String) (offset : Nat) (message : String) : TestM Unit :=
  match parse (bytes input) with
  | .ok v => check name false s!"accepted as {repr v}"
  | .error e =>
    check name (e.offset == offset && e.message == message) s!"error at {e.offset}: {e.message}"

def nested (n : Nat) : String := "".pushn '[' n ++ "".pushn ']' n

/-- `n` objects nested under key `a`. -/
def nestedObj (n : Nat) : String :=
  String.join (List.replicate (n - 1) "{\"a\":") ++ "{}" ++ "".pushn '}' (n - 1)

def tests : TestM Unit := do
  parses "json: literals" " [true, false, null] " (.arr [.bool true, .bool false, .null])
  parses "json: integers" "[0, -1, 123, -0]" (.arr [.num 0, .num (-1), .num 123, .num 0])
  rejects "json: leading zero" "01" 0 "leading zero in number"
  rejects "json: fraction" "[1.5]" 1 "non-integer number"
  rejects "json: exponent" "1e3" 0 "non-integer number"
  rejects "json: capital exponent" "1E3" 0 "non-integer number"
  rejects "json: bare minus" "-" 0 "invalid number"
  rejects "json: minus letter" "-a" 0 "invalid number"
  parses "json: escapes" "\"a\\\"b\\\\c\\/d\\b\\f\\n\\r\\t\""
    (.str "a\"b\\c/d\x08\x0c\n\r\t")
  parses "json: unicode escape" "\"\\u0041\\u00e9\"" (.str "Aé")
  parses "json: uppercase hex" "\"\\u00E9\"" (.str "é")
  parses "json: surrogate pair" "\"\\ud83d\\ude00\"" (.str "😀")
  parses "json: raw UTF-8" "\"é😀\"" (.str "é😀")
  rejects "json: lone high surrogate" "\"\\ud83d\"" 1 "unpaired surrogate in \\u escape"
  rejects "json: high surrogate + non-low" "\"\\ud83d\\u0041\"" 1 "unpaired surrogate in \\u escape"
  rejects "json: lone low surrogate" "\"\\ude00\"" 1 "unpaired surrogate in \\u escape"
  rejects "json: short unicode escape" "\"\\u00\"" 1 "invalid \\u escape"
  rejects "json: bad escape" "\"\\x\"" 1 "invalid escape"
  rejects "json: control char" "\"a\nb\"" 2 "control character in string"
  rejects "json: unterminated string" "\"abc" 0 "unterminated string"
  parses "json: nested" "{\"a\": [1, {\"b\": {}}], \"c\": []}"
    (.obj [("a", .arr [.num 1, .obj [("b", .obj [])]]), ("c", .arr [])])
  rejects "json: duplicate key" "{\"a\": 1, \"a\": 2}" 9 "duplicate key \"a\""
  rejects "json: missing colon" "{\"a\" 1}" 5 "expected ':'"
  rejects "json: non-string key" "{1: 2}" 1 "expected a string key"
  rejects "json: trailing comma in array" "[1,]" 3 "unexpected character"
  rejects "json: trailing comma in object" "{\"a\":1,}" 7 "expected a string key"
  rejects "json: unclosed array" "[1 2]" 3 "expected ',' or ']'"
  rejects "json: unclosed object" "{\"a\":1 \"b\":2}" 7 "expected ',' or '}'"
  rejects "json: trailing characters" "{} x" 3 "trailing characters"
  rejects "json: empty input" "  " 2 "unexpected end of input"
  rejects "json: bad literal" "tru" 0 "invalid literal"
  rejects "json: stray character" "@" 0 "unexpected character"
  parses "json: depth 64 accepted" (nested 64) (Nat.repeat (fun v => .arr [v]) 63 (.arr []))
  rejects "json: depth 65 rejected" (nested 65) 64 "nesting deeper than 64"
  parses "json: object depth 64 accepted" (nestedObj 64)
    (Nat.repeat (fun v => .obj [("a", v)]) 63 (.obj []))
  rejects "json: object depth 65 rejected" (nestedObj 65) 320 "nesting deeper than 64"
  match parse (ByteArray.mk #[34, 0xff, 34]) with
  | .ok _ => check "json: invalid UTF-8 rejected" false "accepted"
  | .error e =>
    checkEq "json: invalid UTF-8 rejected" (e.offset, e.message) (0, "input is not UTF-8")
  checkEq "json: lineCol" (lineCol (bytes "ab\ncd") 4) (2, 2)
  checkEq "json: lineCol counts a leading newline" (lineCol (bytes "\nab") 2) (2, 2)
  parses "json: tab, CR + LF are whitespace" "\t[\r\n1\t]\r" (.arr [.num 1])
  parses "json: hex digit range ends" "\"\\u00af\\u00AF\\u0909\"" (.str "¯¯\u0909")
  rejects "json: ':' is no hex digit" "\"\\u00:0\"" 1 "invalid \\u escape"
  rejects "json: 'g' is no hex digit" "\"\\u00ag\"" 1 "invalid \\u escape"
  rejects "json: 'G' is no hex digit" "\"\\u00AG\"" 1 "invalid \\u escape"
  parses "json: surrogate range ends" "\"\\ud800\\udc00\\udbff\\udfff\\ue000\""
    (.str (String.ofList [Char.ofNat 0x10000, Char.ofNat 0x10FFFF, Char.ofNat 0xE000]))
  rejects "json: low surrogate first" "\"\\udc00\\udc00\"" 1 "unpaired surrogate in \\u escape"
  rejects "json: high surrogate + U+E000" "\"\\ud800\\ue000\"" 1
    "unpaired surrogate in \\u escape"
  parses "json: digits 0 + 9" "[90, 19]" (.arr [.num 90, .num 19])
  rejects "json: ':' is no digit" "[1:]" 2 "expected ',' or ']'"
  rejects "json: negative leading zero" "-01" 0 "leading zero in number"
  check "json: arrays differing in an element differ" (Value.arr [.num 1] != Value.arr [.num 2])
  check "json: objects differing in a key differ"
    (Value.obj [("a", .null)] != Value.obj [("b", .null)])
  check "json: objects differing in a value differ"
    (Value.obj [("a", .null)] != Value.obj [("a", .bool true)])
  check "json: different kinds differ" (Value.null != Value.bool false)
  checkEq "json: canonical keeps a space raw, escapes U+0010" (Value.str " \x10").canonical
    "\" \\u0010\""
  checkEq "json: printed JSON escapes DEL + C1 controls (a terminal acts on them)"
    (Value.obj [("k\x9b", .str "a\x7fb\x9bc\x85d")]).pretty
    "{\n  \"k\\u009b\": \"a\\u007fb\\u009bc\\u0085d\"\n}\n"
  checkEq "json: the digest form keeps them raw (JSON.stringify bytes)"
    (Value.str "a\x7fb\x9b").canonical "\"a\x7fb\x9b\""
  checkEq "json: printed JSON escapes bidirectional formatting"
    (Value.str "a\u202eb\u2066c").pretty "\"a\\u202eb\\u2066c\"\n"
  checkEq "json: the digest form keeps bidirectional formatting raw"
    (Value.str "a\u202eb").canonical "\"a\u202eb\""
  checkEq "json: pretty nests arrays" (Value.arr [.arr [.num 1]]).pretty "[\n  [\n    1\n  ]\n]\n"
  checkEq "json: lineCol start" (lineCol (bytes "ab\ncd") 0) (1, 1)
  checkEq "json: canonical sorts keys"
    (Value.obj [("b", .num 1), ("a", .arr [.bool false, .null]), ("ä", .str "x")]).canonical
    "{\"a\":[false,null],\"b\":1,\"ä\":\"x\"}"
  checkEq "json: canonical escapes"
    (Value.str "q\"b\\\x08\x0c\n\r\t\x01\x1f\x7fé").canonical
    "\"q\\\"b\\\\\\b\\f\\n\\r\\t\\u0001\\u001f\x7fé\""
  checkEq "json: canonical negative" (Value.num (-12)).canonical "-12"
  checkEq "json: pretty"
    (Value.obj [("z", .arr [.num 1, .num 2]), ("a", .obj []), ("e", .arr [])]).pretty
    "{\n  \"z\": [\n    1,\n    2\n  ],\n  \"a\": {},\n  \"e\": []\n}\n"
  let sample := "{\"x\":[1,-2,{\"y\":\"\\u0001é\"}],\"t\":true,\"n\":null}"
  match parse (bytes sample) with
  | .error e => check "json: canonical round-trips" false e.message
  | .ok v =>
    match parse (bytes v.canonical), parse (bytes v.pretty) with
    | .ok c, .ok p =>
      check "json: canonical round-trips" (c.canonical == v.canonical)
      check "json: pretty round-trips" (p == v)
    | _, _ => check "json: canonical round-trips" false "reparse failed"

end Tests.Json
