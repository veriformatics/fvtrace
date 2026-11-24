import Fvtrace.Decode
import Fvtrace.Encode
import Tests.Harness
import Tests.Gen

namespace Tests.Decode
open Tests Fvtrace

/-- A minimal valid trace; `{FACT}` / `{CLAIM}` / `{EXTRA}` are replaced per case. -/
def template : String := r#"{
  "fvtrace": 1,
  "analysis": {"id": "demo", "title": "Demo", "summary": "A demo analysis."},
  "subjects": [{"id": "S", "title": "Existing data", "kind": "existing"}],
  "questions": [{"id": "Q1", "title": "Effect", "text": "Is there an effect?"}],
  "facts": [{FACT},
    {"id": "E1", "subject": "S", "kind": "entailment", "text": "O1 entails C1.",
     "status": "assumed", "route": "human-ruling"}],
  "claims": [{CLAIM}]{EXTRA}
}"#

def factOk : String :=
  r#"{"id": "O1", "subject": "S", "kind": "result", "text": "The effect is positive.", "# ++
  r#""status": "open", "route": "runtime-checker"}"#

def claimOk : String :=
  r#"{"id": "C1", "question": "Q1", "subject": "S", "level": "descriptive", "# ++
  r#""text": "The effect is positive.", "needs": ["O1"], "entailment": "E1"}"#

def doc (fact claim extra : String) : ByteArray :=
  ((template.replace "{FACT}" fact).replace "{CLAIM}" claim |>.replace "{EXTRA}" extra).toUTF8

def errorsOf (input : ByteArray) : List (String × String) :=
  match decodeTrace input with
  | .ok _ => []
  | .error ds => ds.toList.map fun d => (d.code, d.path)

def expectErrors (name : String) (input : ByteArray) (want : List (String × String)) :
    TestM Unit :=
  checkEq name (errorsOf input) want

def tests : TestM Unit := do
  match decodeTrace (doc factOk claimOk "") with
  | .error ds => check "decode: minimal trace" false s!"{repr ds}"
  | .ok t =>
    checkEq "decode: minimal trace facts" (t.facts.map (·.id)) ["O1", "E1"]
    checkEq "decode: absent arrays read empty" (t.experiments.length + t.exclusions.length) 0
    checkEq "decode: latent defaults false" (t.claims.map (·.latent)) [false]
    checkEq "decode: needsAll appends the entailment" (t.claims.map Claim.needsAll) [["O1", "E1"]]
    checkEq "decode: round trip" (decodeTrace (Encode.trace t).pretty.toUTF8 |>.toOption) (some t)
  expectErrors "decode: every shape error in one pass"
    (doc (factOk.replace "\"open\"" "\"maybe\"") (claimOk.replace "\"C1\"" "\"1C\"")
      ",\n  \"extra\": true")
    [("unknown-field", "/extra"), ("invalid-enum", "/facts/0/status"),
     ("invalid-id", "/claims/0/id")]
  expectErrors "decode: missing required field"
    (doc (factOk.replace ", \"route\": \"runtime-checker\"" "") claimOk "")
    [("missing-field", "/facts/0")]
  expectErrors "decode: unknown nested field"
    (doc (factOk.replace "\"open\"" "\"open\", \"colour\": \"red\"") claimOk "")
    [("unknown-field", "/facts/0/colour")]
  expectErrors "decode: whitespace-only text"
    (doc (factOk.replace "The effect is positive." "   ") claimOk "")
    [("invalid-text", "/facts/0/text")]
  expectErrors "decode: control character in text"
    (doc (factOk.replace "The effect is positive." "a\\u0007b") claimOk "")
    [("invalid-text", "/facts/0/text")]
  expectErrors "decode: newline allowed in text"
    (doc (factOk.replace "The effect is positive." "line one\\nline two") claimOk "") []
  expectErrors "decode: id too long"
    (doc factOk (claimOk.replace "\"C1\"" ("\"C" ++ "".pushn '1' 64 ++ "\"")) "")
    [("invalid-id", "/claims/0/id")]
  expectErrors "decode: id of 64 accepted"
    (doc factOk (claimOk.replace "\"C1\"" ("\"C" ++ "".pushn '1' 63 ++ "\"")) "") []
  expectErrors "decode: non-ASCII id" (doc factOk (claimOk.replace "\"C1\"" "\"Cé\"") "")
    [("invalid-id", "/claims/0/id")]
  expectErrors "decode: empty id" (doc factOk (claimOk.replace "\"C1\"" "\"\"") "")
    [("invalid-id", "/claims/0/id")]
  expectErrors "decode: id punctuation accepted"
    (doc factOk (claimOk.replace "\"C1\"" "\"C_1.a-b\"") "") []
  expectErrors "decode: id may not start with punctuation"
    (doc factOk (claimOk.replace "\"C1\"" "\"_C1\"") "") [("invalid-id", "/claims/0/id")]
  expectErrors "decode: non-ASCII letter rejected mid-id"
    (doc factOk (claimOk.replace "\"C1\"" "\"Cµ1\"") "") [("invalid-id", "/claims/0/id")]
  expectErrors "decode: needs must be an array"
    (doc factOk (claimOk.replace "[\"O1\"]" "\"O1\"") "")
    [("type", "/claims/0/needs")]
  expectErrors "decode: bad needs element"
    (doc factOk (claimOk.replace "[\"O1\"]" "[\"O1\", 7]") "")
    [("type", "/claims/0/needs/1")]
  expectErrors "decode: version 2 rejected"
    ((String.fromUTF8! (doc factOk claimOk "")).replace "\"fvtrace\": 1" "\"fvtrace\": 2").toUTF8
    [("version", "/fvtrace")]
  let sha := "".pushn 'a' 64
  let withEvidence := fun (digest : String) =>
    factOk.replace "\"route\": \"runtime-checker\""
      ("\"route\": \"runtime-checker\", \"evidence\": {\"summary\": \"s\", \"artifacts\": " ++
        "[{\"path\": \"a.txt\", \"sha256\": \"" ++ digest ++ "\"}]}")
  expectErrors "decode: sha256 accepted" (doc (withEvidence sha) claimOk "") []
  expectErrors "decode: short sha256" (doc (withEvidence (sha.drop 1).toString) claimOk "")
    [("invalid-sha256", "/facts/0/evidence/artifacts/0/sha256")]
  expectErrors "decode: long sha256 (65 hex digits)" (doc (withEvidence (sha ++ "0")) claimOk "")
    [("invalid-sha256", "/facts/0/evidence/artifacts/0/sha256")]
  expectErrors "decode: uppercase sha256" (doc (withEvidence ("".pushn 'A' 64)) claimOk "")
    [("invalid-sha256", "/facts/0/evidence/artifacts/0/sha256")]
  expectErrors "decode: sha256 digits + a-f accepted"
    (doc (withEvidence ("0123456789abcdef".pushn 'f' 48)) claimOk "") []
  expectErrors "decode: sha256 letter g rejected" (doc (withEvidence ("".pushn 'g' 64)) claimOk "")
    [("invalid-sha256", "/facts/0/evidence/artifacts/0/sha256")]
  let withReview := fun (date : String) =>
    ",\n  \"review\": {\"reviewer\": \"R\", \"date\": \"" ++ date ++ "\", \"digest\": \"" ++
      sha ++ "\"}"
  expectErrors "decode: review date accepted" (doc factOk claimOk (withReview "2026-10-19")) []
  expectErrors "decode: month 13 rejected" (doc factOk claimOk (withReview "2026-13-01"))
    [("invalid-date", "/review/date")]
  expectErrors "decode: unpadded date rejected" (doc factOk claimOk (withReview "2026-1-01"))
    [("invalid-date", "/review/date")]
  for d in ["2026-01-01", "2026-12-31"] do
    expectErrors s!"decode: date {d} accepted" (doc factOk claimOk (withReview d)) []
  for d in ["2026-00-10", "2026-10-00", "2026-10-32", "2026-1a-01"] do
    expectErrors s!"decode: date {d} rejected" (doc factOk claimOk (withReview d))
      [("invalid-date", "/review/date")]
  let withExclusion := fun (between : String) =>
    ",\n  \"exclusions\": [{\"id\": \"X1\", \"subject\": \"S\", \"between\": " ++ between ++
      ", \"text\": \"Not both.\", \"status\": \"assumed\", \"route\": \"human-ruling\"}]"
  expectErrors "decode: exclusion pair accepted"
    (doc factOk claimOk (withExclusion "[\"O1\", \"E1\"]")) []
  expectErrors "decode: exclusion of three"
    (doc factOk claimOk (withExclusion "[\"O1\", \"E1\", \"O1\"]"))
    [("length", "/exclusions/0/between")]
  let withExperiment := fun (success : String) =>
    ",\n  \"experiments\": [{\"id\": \"X2\", \"subject\": \"S\", \"kind\": \"dry\", \"effort\": " ++
      "\"hours\", \"title\": \"T\", \"method\": \"M\", \"resources\": \"R\", \"success\": " ++
      success ++ ", \"caveat\": \"C\"}]"
  expectErrors "decode: outcome accepted"
    (doc factOk claimOk (withExperiment "{\"O1\": \"checked\"}")) []
  expectErrors "decode: outcome key must be an id"
    (doc factOk claimOk (withExperiment "{\"1x\": \"checked\"}"))
    [("invalid-id", "/experiments/0/success/1x")]
  expectErrors "decode: outcome value must be a status"
    (doc factOk claimOk (withExperiment "{\"O1\": \"done\"}"))
    [("invalid-enum", "/experiments/0/success/O1")]
  checkEq "decode: pointer escapes ~ and /" (Decode.pointer ["a/b", "c~d"]) "/a~1b/c~0d"
  match decodeTrace "{\n  \"fvtrace\": 1,\n  @}".toUTF8 with
  | .ok _ => check "decode: syntax error located" false "accepted"
  | .error ds =>
    checkEq "decode: syntax error located" (ds.toList.map (·.message))
      ["line 3, column 3: expected a string key"]

/-! ## Properties: D-id, D-text, D-date, D-sha + the replay reason at their boundaries, against
the published schema's patterns (`schema/trace.schema.json`, read here as code) -/

def seed : UInt64 := 0x44454344

def isLetter (c : Char) : Bool := (65 ≤ c.toNat && c.toNat ≤ 90) || (97 ≤ c.toNat && c.toNat ≤ 122)
def isDigit (c : Char) : Bool := 48 ≤ c.toNat && c.toNat ≤ 57
def digitsIn (lo hi : Nat) (a b : Char) : Bool :=
  isDigit a && isDigit b && (let n := (a.toNat - 48) * 10 + (b.toNat - 48); lo ≤ n && n ≤ hi)

/-- `^[A-Za-z][A-Za-z0-9_.-]{0,63}$` -/
def schemaId (s : String) : Bool :=
  match s.toList with
  | c :: cs => isLetter c && cs.length ≤ 63 &&
      cs.all fun c => isLetter c || isDigit c || c == '_' || c == '.' || c == '-'
  | [] => false

/-- `^(?=[\s\S]*[^ \n])[^\u0000-\u0009\u000b-\u001f\ud800-\udfff]*$` -/
def schemaText (s : String) : Bool :=
  s.toList.any (fun c => c != ' ' && c != '\n') &&
    s.toList.all fun c => !(c.toNat ≤ 9 || (11 ≤ c.toNat && c.toNat ≤ 31))

/-- `^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$` -/
def schemaDate (s : String) : Bool :=
  match s.toList with
  | [y1, y2, y3, y4, '-', m1, m2, '-', d1, d2] =>
    [y1, y2, y3, y4].all isDigit && digitsIn 1 12 m1 m2 && digitsIn 1 31 d1 d2
  | _ => false

/-- `^[0-9a-f]{64}$` -/
def schemaSha (s : String) : Bool :=
  s.length == 64 && s.toList.all fun c => isDigit c || (97 ≤ c.toNat && c.toNat ≤ 102)

/-- `^(timeout|cannot start|output changed|exit N)$`, N = 1 … 4294967295 without a leading zero
(the schema's alternation spells that range digit by digit). -/
def schemaReason (s : String) : Bool :=
  s == "timeout" || s == "cannot start" || s == "output changed" ||
    match s.toList with
    | 'e' :: 'x' :: 'i' :: 't' :: ' ' :: d :: ds =>
      let digits := d :: ds
      d != '0' && digits.all isDigit && digits.length ≤ 10 &&
        digits.foldl (fun n c => n * 10 + (c.toNat - 48)) 0 ≤ 4294967295
    | _ => false

def genFrom (pool : List Char) (len : Nat) : Gen String := do
  return String.ofList (← listOf len (pick pool))

/-- A length at, beside or away from `bound`. -/
def nearLength (bound : Nat) : Gen Nat := do
  match ← draw 4 with
  | 0 => pick [0, 1, 2]
  | 1 => pick [bound - 1, bound, bound + 1]
  | _ => draw (bound + 8)

def genId : Gen String := do
  let first ← pick ['a', 'Z', 'q', 'A', '0', '_', '-', 'é', ' ']
  let rest ← genFrom ['a', 'z', 'A', 'Z', 'm', '0', '9', '_', '.', '-', '@', '`', '[', '/', ':',
    ' ', 'é', '{'] ((← nearLength 64) - 1)
  return if (← draw 8) == 0 then rest else first.toString ++ rest

def genText : Gen String := do
  genFrom ['a', ' ', '\n', '\t', '\r', '\x00', '\x0b', '\x09', '\x1f', '\x20', '\x7f', 'é',
    '😀'] (← draw 5)

def genDate : Gen String := do
  let two := fun (hi : Nat) => do
    let n ← draw hi
    return String.ofList [Char.ofNat (48 + n / 10), Char.ofNat (48 + n % 10)]
  let year ← genFrom ['0', '1', '2', '9', 'x'] 4
  let sep ← pick ['-', '-', '-', '/']
  let date := year ++ sep.toString ++ (← two 20) ++ "-" ++ (← two 40)
  match ← draw 6 with
  | 0 => return date.drop 1 |>.toString
  | 1 => return date ++ "1"
  | _ => return date

/-- A valid digest, then one character swapped for one at a class edge, or the length moved. -/
def genSha : Gen String := do
  let base ← genFrom ['0', '9', 'a', 'f', '5', 'c', 'e'] 64
  let at_ ← draw 64
  match ← draw 4 with
  | 0 => return base
  | 1 => return String.ofList (base.toList.set at_ (← pick ['g', 'A', 'F', ' ', '/', ':', '`']))
  | 2 => return (base.drop (1 + (← draw 2))).toString
  | _ => return base ++ (← genFrom ['0', 'a', 'f'] (1 + (← draw 2)))

def genReason : Gen String := do
  match ← draw 5 with
  | 0 => pick ["timeout", "cannot start", "output changed", "Timeout", "exit", "exit ", "exit 0",
      "cannot  start", "output changed "]
  | _ => do
    let len := 1 + (← draw 11)
    let digits ← listOf len (draw 10)
    let digits := if (← draw 3) == 0 then digits else
      if len == 10 then 4 :: 2 :: 9 :: 4 :: 9 :: 6 :: 7 :: 2 :: 9 :: (digits.drop 9) else digits
    return "exit " ++ String.ofList (digits.map fun d => Char.ofNat (48 + d))

def agrees (name : String) (salt : UInt64) (gen : Gen String) (impl oracle : String → Bool) :
    TestM Unit := do
  let cases := sample salt (listOf 2000 gen)
  let wrong := cases.filter fun s => impl s != oracle s
  let accepted := (cases.filter oracle).length
  check s!"decode property: {name} = the schema's pattern (seed={salt}, {cases.length} strings, \
    {accepted} accepted)" (wrong.isEmpty && accepted > 0 && accepted < cases.length)
    s!"{repr (wrong.take 5)}"

/-- A replay command (§ Model: a non-empty argv, each argument non-empty without NUL) reports one
`invalid-arg` per refused slot at its index and `invalid-replay` only for an empty array: a refused
slot never shortens the array (an all-refused one read as empty would add `invalid-replay`). -/
def commandProperty : TestM Unit := do
  -- (argument, its JSON) pairs; the JSON is written here, apart from the printer under test.
  let pool := [("lake", "\"lake\""), ("build", "\"build\""), ("", "\"\""),
    ("a\x00b", "\"a\\u0000b\"")]
  let cases := sample (seed + 5) (listOf 400 do listOf (← draw 5) (pick pool))
  let path := "/facts/0/evidence/replay/command"
  let refused := fun (a : String) => a.isEmpty || a.contains '\x00'
  let wanted := fun (args : List (String × String)) =>
    if args.isEmpty then [("invalid-replay", path)] else
      (args.zipIdx.filter (refused ·.1.1)).map fun (_, i) => ("invalid-arg", s!"{path}/{i}")
  let input := fun (args : List (String × String)) =>
    let json := ", ".intercalate (args.map (·.2))
    doc (factOk.replace "\"route\": \"runtime-checker\"}"
      s!"\"route\": \"runtime-checker\", \"evidence\": \{\"summary\": \"A log.\", \
        \"replay\": \{\"command\": [{json}]}}}") claimOk ""
  let wrong := cases.filter fun args => errorsOf (input args) != wanted args
  let allRefused := (cases.filter fun args => !args.isEmpty && args.all (refused ·.1)).length
  check s!"decode property: replay command diagnostics (seed={seed + 5}, {cases.length} commands, \
    {allRefused} all refused)" (wrong.isEmpty && allRefused > 0)
    s!"{repr ((wrong.take 3).map fun args => (args.map (·.1), errorsOf (input args)))}"

def propertyTests : TestM Unit := do
  commandProperty
  agrees "D-id" seed genId Decode.validId schemaId
  agrees "D-text" (seed + 1) genText Decode.validText schemaText
  agrees "D-date" (seed + 2) genDate Decode.validDate schemaDate
  agrees "D-sha" (seed + 3) genSha Decode.validSha schemaSha
  agrees "replay reason" (seed + 4) genReason Decode.validFailReason schemaReason

/-- G-codec on an outcome map written out of key order (pretty keeps member order). -/
def outcomeOrderTests : TestM Unit := do
  match decodeTrace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json") with
  | .error _ => check "decode: fixture" false
  | .ok t =>
    let shuffled := { t with experiments := t.experiments.map fun e =>
      { e with success := (("O3", .assumed) :: e.success).reverse } }
    match decodeTrace (Encode.trace shuffled).pretty.toUTF8 with
    | .error ds => check "decode: an outcome map in any key order decodes" false s!"{repr ds}"
    | .ok d =>
      let again := (decodeTrace (Encode.trace d).canonical.toUTF8).toOption
      check "decode: decode (encode t) = t for a trace decoded from unsorted keys" (again == some d)

/-- D-json's size limit: checked before parsing, on a small limit (building 16 MiB in the
interpreted suite costs a minute); the shipped limit is pinned apart. -/
def sizeTests : TestM Unit := do
  checkEq "decode: the shipped limit is 16 MiB" maxTraceBytes (16 * 1024 * 1024)
  checkEq "decode: an input over the limit is refused before parsing"
    ((decodeTraceWithin 10 "{\"fvtrace\": 1}".toUTF8).toOption.isNone,
     match decodeTraceWithin 10 "{\"fvtrace\": 1}".toUTF8 with
     | .error ds => ds.toList.map (·.code)
     | .ok _ => []) (true, ["size"])
  checkEq "decode: an input at the limit reaches the parser"
    (match decodeTraceWithin 3 "[1]".toUTF8 with
     | .error ds => ds.toList.map (·.code)
     | .ok _ => []) ["type"]

end Tests.Decode
