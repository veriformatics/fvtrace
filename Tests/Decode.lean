import Fvtrace.Decode
import Fvtrace.Encode
import Tests.Harness

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
