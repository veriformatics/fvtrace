import Fvtrace.Json
import Fvtrace.Model

/-!
# Trace decoding

JSON value → typed trace (`.agent/contracts/kernel.md` D-shape, D-id, D-text, D-date, D-sha).
Every shape error found in one pass is reported with an RFC 6901 pointer; a value that fails to
decode yields `none` while its siblings keep decoding, so one run lists them all.
-/

namespace Fvtrace.Decode
open Fvtrace.Json

structure Diag where
  code : String
  /-- RFC 6901 pointer into the trace document. -/
  path : String
  message : String
  deriving Repr, BEq, Inhabited

def escapeSegment (s : String) : String :=
  (s.replace "~" "~0").replace "/" "~1"

def pointer (segments : List String) : String :=
  String.join (segments.map fun s => "/" ++ escapeSegment s)

abbrev DecM := StateM (Array Diag)

def report (code : String) (path : List String) (message : String) : DecM Unit :=
  modify (·.push { code, path := pointer path, message })

abbrev Field (α : Type) := List String → Value → DecM (Option α)

-- `Char.isAlpha` + `isAlphanum` accept ASCII alone, as D-id requires.
def isIdStart (c : Char) : Bool := c.isAlpha
def isIdChar (c : Char) : Bool := c.isAlphanum || c == '_' || c == '.' || c == '-'

def validId (s : String) : Bool :=
  match s.toList with
  | c :: cs => isIdStart c && cs.all isIdChar && s.length ≤ 64
  | [] => false

def validText (s : String) : Bool :=
  !s.toList.all Char.isWhitespace && s.all fun c => c == '\n' || c.toNat ≥ 32

def validSha (s : String) : Bool :=
  s.length == 64 && s.all fun c => c.isDigit || ('a' ≤ c && c ≤ 'f')

def validDate (s : String) : Bool :=
  match s.toList with
  | [y1, y2, y3, y4, '-', m1, m2, '-', d1, d2] =>
    [y1, y2, y3, y4, m1, m2, d1, d2].all Char.isDigit &&
      (let m := (String.ofList [m1, m2]).toNat!
       let d := (String.ofList [d1, d2]).toNat!
       1 ≤ m && m ≤ 12 && 1 ≤ d && d ≤ 31)
  | _ => false

def string : Field String := fun path v =>
  match v with
  | .str s => pure (some s)
  | _ => do report "type" path "expected a string"; pure none

def text : Field String := fun path v => do
  match ← string path v with
  | some s =>
    if validText s then pure (some s)
    else do
      report "invalid-text" path "text must be non-empty and free of control characters"
      pure none
  | none => pure none

def ident : Field String := fun path v => do
  match ← string path v with
  | some s =>
    if validId s then pure (some s)
    else do
      report "invalid-id" path s!"\"{s}\" is not an id (letter, then letters, digits, _ . -; ≤ 64)"
      pure none
  | none => pure none

def sha : Field String := fun path v => do
  match ← string path v with
  | some s =>
    if validSha s then pure (some s)
    else do report "invalid-sha256" path "expected 64 lowercase hex digits"; pure none
  | none => pure none

def date : Field String := fun path v => do
  match ← string path v with
  | some s =>
    if validDate s then pure (some s)
    else do report "invalid-date" path "expected a date YYYY-MM-DD"; pure none
  | none => pure none

def bool : Field Bool := fun path v =>
  match v with
  | .bool b => pure (some b)
  | _ => do report "type" path "expected true or false"; pure none

def enum {α : Type} (all : List α) (name : α → String) : Field α := fun path v => do
  match ← string path v with
  | some s =>
    match all.find? (name · == s) with
    | some a => pure (some a)
    | none => do
      report "invalid-enum" path s!"\"{s}\" is not one of {", ".intercalate (all.map name)}"
      pure none
  | none => pure none

def array {α : Type} (item : Field α) : Field (List α) := fun path v =>
  match v with
  | .arr xs => do
    let mut out := []
    let mut ok := true
    for (x, i) in xs.zipIdx do
      match ← item (path ++ [toString i]) x with
      | some a => out := a :: out
      | none => ok := false
    pure (if ok then some out.reverse else none)
  | _ => do report "type" path "expected an array"; pure none

/-- An object's members; every key outside `allowed` is reported. -/
def members (path : List String) (v : Value) (allowed : List String) :
    DecM (Option (List (String × Value))) :=
  match v with
  | .obj kvs => do
    for (k, _) in kvs do
      unless allowed.contains k do report "unknown-field" (path ++ [k]) s!"unknown field \"{k}\""
    pure (some kvs)
  | _ => do report "type" path "expected an object"; pure none

def req {α : Type} (path : List String) (kvs : List (String × Value)) (key : String)
    (f : Field α) : DecM (Option α) :=
  match kvs.lookup key with
  | some v => f (path ++ [key]) v
  | none => do report "missing-field" path s!"missing field \"{key}\""; pure none

/-- `some none` = absent (allowed); `none` = present but invalid. -/
def opt {α : Type} (path : List String) (kvs : List (String × Value)) (key : String)
    (f : Field α) : DecM (Option (Option α)) :=
  match kvs.lookup key with
  | some v => do pure ((← f (path ++ [key]) v).map some)
  | none => pure (some none)

/-- An absent array reads as empty. -/
def optList {α : Type} (path : List String) (kvs : List (String × Value)) (key : String)
    (f : Field α) : DecM (Option (List α)) := do
  pure ((← opt path kvs key (array f)).map (·.getD []))

def optBool (path : List String) (kvs : List (String × Value)) (key : String) :
    DecM (Option Bool) := do
  pure ((← opt path kvs key bool).map (·.getD false))

def status : Field Status := enum Status.all Status.name
def route : Field Route := enum Route.all Route.name

/-- A fact id → status map (experiment outcomes). -/
def outcome : Field (List (String × Status)) := fun path v =>
  match v with
  | .obj kvs => do
    let mut out := []
    let mut ok := true
    for (k, x) in kvs do
      let key ← ident (path ++ [k]) (.str k)
      let st ← status (path ++ [k]) x
      match key, st with
      | some k, some s => out := (k, s) :: out
      | _, _ => ok := false
    pure (if ok then some out.reverse else none)
  | _ => do report "type" path "expected an object of fact id → status"; pure none

def analysis : Field Analysis := fun path v => do
  let some kvs ← members path v ["id", "title", "summary", "source"] | pure none
  let id ← req path kvs "id" ident
  let title ← req path kvs "title" text
  let summary ← req path kvs "summary" text
  let source ← opt path kvs "source" text
  pure do pure { id := ← id, title := ← title, summary := ← summary, source := ← source }

def subject : Field Subject := fun path v => do
  let some kvs ← members path v ["id", "title", "kind", "createdBy"] | pure none
  let id ← req path kvs "id" ident
  let title ← req path kvs "title" text
  let kind ← req path kvs "kind" (enum SubjectKind.all SubjectKind.name)
  let createdBy ← opt path kvs "createdBy" ident
  pure do pure { id := ← id, title := ← title, kind := ← kind, createdBy := ← createdBy }

def question : Field Question := fun path v => do
  let some kvs ← members path v ["id", "title", "text"] | pure none
  let id ← req path kvs "id" ident
  let title ← req path kvs "title" text
  let t ← req path kvs "text" text
  pure do pure { id := ← id, title := ← title, text := ← t }

def artifact : Field Artifact := fun path v => do
  let some kvs ← members path v ["path", "sha256", "role"] | pure none
  let p ← req path kvs "path" text
  let s ← opt path kvs "sha256" sha
  let r ← opt path kvs "role" text
  pure do pure { path := ← p, sha256 := ← s, role := ← r }

def evidence : Field Evidence := fun path v => do
  let some kvs ← members path v
    ["summary", "artifacts", "verifier", "statement", "statementDigest"] | pure none
  let summary ← req path kvs "summary" text
  let artifacts ← optList path kvs "artifacts" artifact
  let verifier ← opt path kvs "verifier" text
  let statement ← opt path kvs "statement" text
  let digest ← opt path kvs "statementDigest" sha
  pure do
    pure { summary := ← summary, artifacts := ← artifacts, verifier := ← verifier,
           statement := ← statement, statementDigest := ← digest }

def fact : Field Fact := fun path v => do
  let some kvs ← members path v
    ["id", "subject", "kind", "text", "status", "route", "evidence", "trusts", "instantiates"]
    | pure none
  let id ← req path kvs "id" ident
  let subj ← req path kvs "subject" ident
  let kind ← req path kvs "kind" (enum Kind.all Kind.name)
  let t ← req path kvs "text" text
  let st ← req path kvs "status" status
  let r ← req path kvs "route" route
  let ev ← opt path kvs "evidence" evidence
  let trusts ← optList path kvs "trusts" text
  let inst ← opt path kvs "instantiates" ident
  pure do
    pure { id := ← id, subject := ← subj, kind := ← kind, text := ← t, status := ← st,
           route := ← r, evidence := ← ev, trusts := ← trusts, instantiates := ← inst }

def claim : Field Claim := fun path v => do
  let some kvs ← members path v
    ["id", "question", "subject", "level", "text", "needs", "entailment", "latent", "variantOf"]
    | pure none
  let id ← req path kvs "id" ident
  let q ← req path kvs "question" ident
  let subj ← req path kvs "subject" ident
  let level ← req path kvs "level" (enum Level.all Level.name)
  let t ← req path kvs "text" text
  let needs ← req path kvs "needs" (array ident)
  let ent ← req path kvs "entailment" ident
  let latent ← optBool path kvs "latent"
  let variantOf ← opt path kvs "variantOf" ident
  pure do
    pure { id := ← id, question := ← q, subject := ← subj, level := ← level, text := ← t,
           needs := ← needs, entailment := ← ent, latent := ← latent, variantOf := ← variantOf }

def experiment : Field Experiment := fun path v => do
  let some kvs ← members path v
    ["id", "subject", "kind", "effort", "title", "method", "resources", "success", "failure",
     "requires", "caveat"] | pure none
  let id ← req path kvs "id" ident
  let subj ← req path kvs "subject" ident
  let kind ← req path kvs "kind" (enum ExpKind.all ExpKind.name)
  let effort ← req path kvs "effort" (enum Effort.all Effort.name)
  let title ← req path kvs "title" text
  let method ← req path kvs "method" text
  let resources ← req path kvs "resources" text
  let success ← req path kvs "success" outcome
  let failure ← opt path kvs "failure" outcome
  let requires ← optList path kvs "requires" ident
  let caveat ← req path kvs "caveat" text
  pure do
    pure { id := ← id, subject := ← subj, kind := ← kind, effort := ← effort, title := ← title,
           method := ← method, resources := ← resources, success := ← success,
           failure := (← failure).getD [], requires := ← requires, caveat := ← caveat }

def pair : Field (String × String) := fun path v => do
  match v with
  | .arr [a, b] =>
    let x ← ident (path ++ ["0"]) a
    let y ← ident (path ++ ["1"]) b
    pure do pure (← x, ← y)
  | .arr _ => do report "length" path "expected exactly two fact ids"; pure none
  | _ => do report "type" path "expected an array of two fact ids"; pure none

def exclusion : Field Exclusion := fun path v => do
  let some kvs ← members path v
    ["id", "subject", "between", "text", "status", "route", "evidence"] | pure none
  let id ← req path kvs "id" ident
  let subj ← req path kvs "subject" ident
  let between ← req path kvs "between" pair
  let t ← req path kvs "text" text
  let st ← req path kvs "status" status
  let r ← req path kvs "route" route
  let ev ← opt path kvs "evidence" evidence
  pure do
    pure { id := ← id, subject := ← subj, between := ← between, text := ← t, status := ← st,
           route := ← r, evidence := ← ev }

def waiver : Field Waiver := fun path v => do
  let some kvs ← members path v ["rule", "claim", "reason"] | pure none
  let rule ← req path kvs "rule" ident
  let c ← req path kvs "claim" ident
  let reason ← req path kvs "reason" text
  pure do pure { rule := ← rule, claim := ← c, reason := ← reason }

def review : Field Review := fun path v => do
  let some kvs ← members path v ["reviewer", "date", "digest", "note"] | pure none
  let reviewer ← req path kvs "reviewer" text
  let d ← req path kvs "date" date
  let digest ← req path kvs "digest" sha
  let note ← opt path kvs "note" text
  pure do pure { reviewer := ← reviewer, date := ← d, digest := ← digest, note := ← note }

def version : Field Unit := fun path v =>
  match v with
  | .num 1 => pure (some ())
  | _ => do report "version" path "this fvTrace reads trace format version 1"; pure none

def trace : Field Trace := fun path v => do
  let some kvs ← members path v
    ["fvtrace", "analysis", "subjects", "questions", "facts", "claims", "experiments",
     "exclusions", "waivers", "review"] | pure none
  let ver ← req path kvs "fvtrace" version
  let an ← req path kvs "analysis" analysis
  let subjects ← req path kvs "subjects" (array subject)
  let questions ← req path kvs "questions" (array question)
  let facts ← req path kvs "facts" (array fact)
  let claims ← req path kvs "claims" (array claim)
  let experiments ← optList path kvs "experiments" experiment
  let exclusions ← optList path kvs "exclusions" exclusion
  let waivers ← optList path kvs "waivers" waiver
  let rev ← opt path kvs "review" review
  pure do
    let () ← ver
    pure { analysis := ← an, subjects := ← subjects, questions := ← questions, facts := ← facts,
           claims := ← claims, experiments := ← experiments, exclusions := ← exclusions,
           waivers := ← waivers, review := ← rev }

end Fvtrace.Decode

namespace Fvtrace

/-- Bytes → trace: a syntax error stops with its line + column; otherwise every shape error is
listed. -/
def decodeTrace (input : ByteArray) : Except (Array Decode.Diag) Trace :=
  match Json.parse input with
  | .error e =>
    let (line, col) := Json.lineCol input e.offset
    .error #[{ code := "syntax", path := "",
                message := s!"line {line}, column {col}: {e.message}" }]
  | .ok v =>
    let (t, diags) := (Decode.trace [] v).run #[]
    match t with
    | some t => if diags.isEmpty then .ok t else .error diags
    | none => .error diags

end Fvtrace
