import Fvtrace.Check
import Fvtrace.Digest
import Fvtrace.Encode
import Fvtrace.Snapshot

/-!
# Coverage-guided fuzz targets (`.claude/rules/testing.md`)

One function per reader of other people's bytes: input bytes → 0 when the input meets its
contract, else the code of the broken property. A libFuzzer driver (`tools/fuzz/driver.c`, built
sanitized by `tools/fuzz.sh`) calls each export per generated input; `fvtrace-fuzz replay`
(`FuzzMain.lean`) calls the same functions on the committed corpus + crash inputs in the gate.
Crash-only targets still return 0: a panic (`LEAN_ABORT_ON_PANIC`), a sanitizer report or a
timeout is their failure. Dev-only: never imported by the shipped binary.
-/

namespace FvtraceFuzz
open Fvtrace Fvtrace.Json

def hexDigit? (c : UInt8) : Option Nat :=
  if 48 ≤ c && c ≤ 57 then some (c.toNat - 48)
  else if 97 ≤ c && c ≤ 102 then some (c.toNat - 87)
  else if 65 ≤ c && c ≤ 70 then some (c.toNat - 55)
  else none

/-- The 4 hex digits at `i`, if there are. -/
def hex4? (b : ByteArray) (i : Nat) : Option Nat :=
  if i + 4 ≤ b.size then
    [0, 1, 2, 3].foldlM (fun acc k => (hexDigit? (b.get! (i + k))).map (acc * 16 + ·)) 0
  else none

/-- What `"\uHHHH"` (+ `\uLLLL` after a high surrogate) must parse to, computed apart from the
parser (RFC 8259 §7; D-shape: an unpaired surrogate = an error). -/
def escapeExpected (hi : Nat) (lo : Option Nat) : Option Char :=
  if 0xD800 ≤ hi && hi < 0xDC00 then
    match lo with
    | some l => if 0xDC00 ≤ l && l < 0xE000 then some (Char.ofNat (0x10000 +
        (hi - 0xD800) * 0x400 + (l - 0xDC00))) else none
    | none => none
  else if 0xDC00 ≤ hi && hi < 0xE000 then none
  else some (Char.ofNat hi)

/-- D-json + D-canon, three ways: (1) a parsed value's canonical text parses back to a value
printing the same text; (2) the input's own characters, as a string value (also an object key),
print canonically + parse back to that value; (3) the input's leading hex digits, as a `\u` escape
(a pair when they name a high surrogate), parse to the character computed apart from the parser.
(2) reaches every escape the printer writes from any input holding its character; (3) the escapes
it never writes; (1) alone needs an escape spelled another way (`\u000a` for `\n`): a planted `\n`
decoded off by one survived 4.1 M inputs of (1) alone. -/
@[export fvtrace_fuzz_json]
def json (input : ByteArray) : IO UInt8 := pure <|
  let parsed := match Json.parse input with
    | .error _ => 0
    | .ok v =>
      let text := v.canonical
      match Json.parse text.toUTF8 with
      | .error _ => 1
      | .ok w => if w.canonical == text then 0 else 2
  let own := match String.fromUTF8? input with
    | none => 0
    | some s =>
      let v := Value.arr [.str s, .obj [(s, .str s)]]
      match Json.parse v.canonical.toUTF8 with
      | .ok w => if w == v then 0 else 4
      | .error _ => 3
  let escape := match hex4? input 0 with
    | none => 0
    | some hi =>
      let lo := if 0xD800 ≤ hi && hi < 0xDC00 then hex4? input 4 else none
      let hex := fun (i : Nat) => String.fromUTF8! (input.extract i (i + 4))
      let text := "\"\\u" ++ hex 0 ++ (if lo.isSome then "\\u" ++ hex 4 else "") ++ "\""
      match Json.parse text.toUTF8, escapeExpected hi lo with
      | .ok (.str s), some c => if s == String.singleton c then 0 else 5
      | .error _, none => 0
      | _, _ => 6
  if parsed != 0 then parsed else if own != 0 then own else escape

/-- G-codec: a decoded trace encodes to a document that decodes back to the same trace, and the
well-formedness check runs to its end on it. -/
@[export fvtrace_fuzz_decode]
def decode (input : ByteArray) : IO UInt8 := pure <|
  match decodeTrace input with
  | .error _ => 0
  | .ok t =>
    let text := (Encode.trace t).canonical
    match decodeTrace text.toUTF8 with
    | .error _ => 1
    | .ok u =>
      if (Encode.trace u).canonical != text then 2
      -- The count keeps the check's result live (the compiler drops an unused value).
      else if (Check.violations u).length == (Check.violations t).length then 0 else 3

def encodeRequest (r : Fvtrace.Request) : Value :=
  .obj ([("whatif", .str r.whatif)] ++ (r.action.map fun a => ("action", .str a)).toList ++
    (r.details.map fun d => ("details", .str d)).toList)

/-- V-request (`/api/answer` + the page engine): a parsed request re-encodes to one that parses
the same; an item name parses back to itself. -/
@[export fvtrace_fuzz_request]
def request (input : ByteArray) : IO UInt8 := pure <|
  match String.fromUTF8? input with
  | none => 0
  | some text =>
    match Fvtrace.Request.parse text with
    | .error _ => 0
    | .ok r =>
      match Fvtrace.Request.parse (encodeRequest r).canonical with
      | .error _ => 1
      | .ok r' =>
        if r' != r then 2
        else match r.details.map Item.parse with
          | some (.ok i) => if i.name == r.details.getD "" then 0 else 3
          | _ => 0

/-- The input before its first NUL = a snapshot, the rest = one request (`c/page_engine.c`'s
split: a NUL inside a what-if must reach the engine). -/
def splitAtNul (input : ByteArray) : ByteArray × ByteArray := Id.run do
  for i in [0:input.size] do
    if input.get! i == 0 then return (input.extract 0 i, input.extract (i + 1) input.size)
  return (input, .empty)

/-- E-snap + E-request: the page engine loads a snapshot + answers a request (crash-only; the
driver feeds `c/page_engine.c`, the replay these Lean entries it calls). -/
@[export fvtrace_fuzz_page]
def page (input : ByteArray) : IO UInt8 := pure <|
  let (snapshot, req) := splitAtNul input
  match String.fromUTF8? snapshot, String.fromUTF8? req with
  | some s, some r =>
    match Snapshot.Engine.load s with
    | .error m => if m.isEmpty then 1 else 0
    | .ok e => if (e.answer r).2.isEmpty then 2 else 0
  | _, _ => 0

/-- The FFI shim over HACL* (`c/fvtrace_digest.c`): the input fed in slices of (first byte + 1)
bytes digests as it does in one update. -/
@[export fvtrace_fuzz_digest]
def digest (input : ByteArray) : IO UInt8 := do
  let whole ← Digest.ofBytes input
  let step := if input.isEmpty then 1 else (input.get! 0).toNat + 1
  let s ← Digest.Sha256.new
  let mut i := 0
  while i < input.size do
    s.update (input.extract i (i + step))
    i := i + step
  return if Digest.hex (← s.finish) == whole then 0 else 1

/-- Every target by name (the replay + `tools/fuzz.sh` share these names). -/
def targets : List (String × (ByteArray → IO UInt8)) :=
  [("json", json), ("decode", decode), ("request", request), ("page", page),
   ("digest", digest)]

end FvtraceFuzz
