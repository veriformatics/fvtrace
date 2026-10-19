import Std.Data.HashMap
import Std.Time
import Fvtrace.Digest
import Fvtrace.Encode
import Fvtrace.Json
import Fvtrace.Model

/-!
# Receipts + review record (contract § Receipts, § Review)

A verified status counts only while its receipt is current: every artifact still hashes to its
pinned sha256 and the fact's statement (with what it binds: an entailment's claim, an
instantiation's source, an exclusion's endpoints) still hashes to its pinned `statementDigest`.
This module computes that binding from the project folder; the engine consumes it as input.
Nothing here writes into the project folder.
-/

namespace Fvtrace.Receipt
open Fvtrace.Json

def factBrief (f : Fact) : Value :=
  .obj [("id", .str f.id), ("subject", .str f.subject), ("kind", .str f.kind.name),
    ("text", .str f.text)]

/-- The statement a fact's receipt certifies (D-canon input of its `statementDigest`). -/
def factManifest (t : Trace) (f : Fact) : Value :=
  let base := [("id", .str f.id), ("subject", .str f.subject), ("kind", .str f.kind.name),
    ("text", .str f.text), ("route", .str f.route.name)]
  let bound : List (String × Value) :=
    match f.kind with
    | .entailment =>
      match t.claims.find? (·.entailment == f.id) with
      | some c =>
        let needs := c.needs.map fun n =>
          Value.obj [("id", .str n), ("text", .str ((t.fact? n).map (·.text) |>.getD ""))]
        [("claim", .obj [("id", .str c.id), ("subject", .str c.subject),
          ("level", .str c.level.name), ("text", .str c.text), ("needs", .arr needs)])]
      | none => []
    | .instantiation =>
      match f.instantiates.bind t.fact? with
      | some s => [("source", factBrief s)]
      | none => []
    | _ => []
  .obj (base ++ bound)

/-- The statement an exclusion's receipt certifies, endpoints included (rewording one stales it). -/
def exclusionManifest (t : Trace) (x : Exclusion) : Value :=
  let endpoint (id : String) : Value := ((t.fact? id).map factBrief).getD (.obj [("id", .str id)])
  .obj [("id", .str x.id), ("subject", .str x.subject), ("text", .str x.text),
    ("route", .str x.route.name), ("between", .arr [endpoint x.between.1, endpoint x.between.2])]

def statementDigest (manifest : Value) : IO String := Digest.ofString manifest.canonical

/-! ## Artifact resolution + digest cache -/

/-- An artifact path, resolved inside the project root (symlinks resolved first), or why not. -/
def resolve (root : System.FilePath) (rel : String) : IO (Except String System.FilePath) := do
  let p := root / rel
  unless ← p.pathExists do return .error s!"missing {rel}"
  let real ← IO.FS.realPath p
  let rootReal ← IO.FS.realPath root
  if rootReal.components.isPrefixOf real.components && real.components != rootReal.components then
    return .ok real
  return .error s!"outside {rel}"

/-- Cached digests keyed by resolved path + size + modification time. -/
abbrev Cache := Std.HashMap String (UInt64 × Int × UInt32 × String)

def fileDigest (cache : IO.Ref Cache) (rehash : Bool) (path : System.FilePath) : IO String := do
  let m ← path.metadata
  let key := path.toString
  if !rehash then
    if let some (size, sec, nsec, digest) := (← cache.get)[key]? then
      if size == m.byteSize && sec == m.modified.sec && nsec == m.modified.nsec then
        return digest
  let digest ← Digest.ofFile path
  cache.modify (·.insert key (m.byteSize, m.modified.sec, m.modified.nsec, digest))
  return digest

def Cache.toJson (c : Cache) : Value :=
  .obj (c.toList.map fun (k, (size, sec, nsec, d)) =>
    (k, .arr [.num size.toNat, .num sec, .num nsec.toNat, .str d]))

def Cache.ofJson : Value → Cache
  | .obj kvs => kvs.foldl (init := {}) fun c (k, v) =>
    match v with
    | .arr [.num size, .num sec, .num nsec, .str d] =>
      c.insert k (size.toNat.toUInt64, sec, nsec.toNat.toUInt32, d)
    | _ => c
  | _ => {}

def Cache.load (file : System.FilePath) : IO Cache := do
  try
    match Json.parse (← IO.FS.readBinFile file) with
    | .ok v => return Cache.ofJson v
    | .error _ => return {}
  catch _ => return {}

def Cache.save (c : Cache) (file : System.FilePath) : IO Unit := do
  if let some dir := file.parent then IO.FS.createDirAll dir
  IO.FS.writeFile file (Cache.toJson c).canonical

/-! ## Binding -/

structure Binding where
  /-- Fact or exclusion id. -/
  id : String
  current : Bool
  /-- `changed <path>` · `missing <path>` · `outside <path>` · `statement-changed`. -/
  reasons : List String
  deriving Repr, BEq

def bind (root : System.FilePath) (cache : IO.Ref Cache) (rehash : Bool) (id : String)
    (ev : Option Evidence) (manifest : Value) : IO Binding := do
  let some ev := ev | return { id, current := false, reasons := ["no receipt"] }
  let mut reasons := []
  for a in ev.artifacts do
    match ← resolve root a.path with
    | .error why => reasons := reasons ++ [why]
    | .ok real =>
      if some (← fileDigest cache rehash real) != a.sha256 then
        reasons := reasons ++ [s!"changed {a.path}"]
  if some (← statementDigest manifest) != ev.statementDigest then
    reasons := reasons ++ ["statement-changed"]
  return { id, current := reasons.isEmpty, reasons }

/-- Bindings of every recorded verified fact + exclusion (the only ones a binding affects). -/
def bindings (t : Trace) (root : System.FilePath) (cache : IO.Ref Cache) (rehash : Bool := false) :
    IO (List Binding) := do
  let mut out := []
  for f in t.facts do
    if f.status.verified then
      out := out ++ [← bind root cache rehash f.id f.evidence (factManifest t f)]
  for x in t.exclusions do
    if x.status.verified then
      out := out ++ [← bind root cache rehash x.id x.evidence (exclusionManifest t x)]
  return out

/-! ## Pinning -/

/-- Pins one evidence block: each artifact's sha256 + the statement digest. Missing or escaping
artifacts stay unpinned and are reported. -/
def pinEvidence (root : System.FilePath) (cache : IO.Ref Cache) (ev : Evidence) (manifest : Value) :
    IO (Evidence × List String) := do
  let mut artifacts := []
  let mut problems := []
  for a in ev.artifacts do
    match ← resolve root a.path with
    | .error why => artifacts := artifacts ++ [a]; problems := problems ++ [why]
    | .ok real =>
      artifacts := artifacts ++ [{ a with sha256 := some (← fileDigest cache true real) }]
  let digest ← statementDigest manifest
  return ({ ev with artifacts, statementDigest := some digest }, problems)

/-- Pins every fact + exclusion that carries evidence; returns the new trace + problems. -/
def pin (t : Trace) (root : System.FilePath) (cache : IO.Ref Cache) :
    IO (Trace × List String) := do
  let mut problems := []
  let mut facts := []
  for f in t.facts do
    match f.evidence with
    | some ev =>
      let (ev', ps) ← pinEvidence root cache ev (factManifest t f)
      facts := facts ++ [{ f with evidence := some ev' }]
      problems := problems ++ ps.map (s!"{f.id}: " ++ ·)
    | none => facts := facts ++ [f]
  let mut exclusions := []
  for x in t.exclusions do
    match x.evidence with
    | some ev =>
      let (ev', ps) ← pinEvidence root cache ev (exclusionManifest t x)
      exclusions := exclusions ++ [{ x with evidence := some ev' }]
      problems := problems ++ ps.map (s!"{x.id}: " ++ ·)
    | none => exclusions := exclusions ++ [x]
  return ({ t with facts, exclusions }, problems)

/-! ## Review record -/

/-- SHA-256 of the canonical trace without its review record (contract § Review). -/
def reviewDigest (t : Trace) : IO String :=
  Digest.ofString (Encode.trace { t with review := none }).canonical

inductive ReviewState where
  | draft
  | stale
  | reviewed
  deriving DecidableEq, Repr

def ReviewState.name : ReviewState → String
  | .draft => "draft" | .stale => "stale" | .reviewed => "reviewed"

def reviewState (t : Trace) : IO ReviewState := do
  match t.review with
  | none => return .draft
  | some r => return if r.digest == (← reviewDigest t) then .reviewed else .stale

/-- Records a review of the current content, dated today (local date). -/
def review (t : Trace) (reviewer : String) (note : Option String) : IO Trace := do
  let date := toString (← Std.Time.PlainDate.now)
  return { t with review := some { reviewer, date, digest := ← reviewDigest t, note } }

end Fvtrace.Receipt
