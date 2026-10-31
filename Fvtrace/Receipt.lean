import Std.Data.HashMap
import Std.Time
import Fvtrace.Digest
import Fvtrace.Encode
import Fvtrace.Json
import Fvtrace.Lookups
import Fvtrace.Receipt.Basic

/-!
# Receipts + review record (contract § Receipts, § Review)

A verified status counts only while its receipt is current: every artifact still hashes to its
pinned sha256 and the fact's statement (with what it binds: an entailment's claim, an
instantiation's source, an exclusion's endpoints) still hashes to its pinned `statementDigest`.
This module computes that binding from the project folder; the engine consumes it as input.
Every artifact is read + hashed again unless the caller opts into the cache (`--cached`): then a
file that kept its resolved path, size + mtime reuses its recorded digest, so an edit that keeps
all three goes unseen. Nothing here writes into the project folder.
-/

namespace Fvtrace.Receipt
open Fvtrace.Json

def factBrief (f : Fact) : Value :=
  .obj [("id", .str f.id), ("subject", .str f.subject), ("kind", .str f.kind.name),
    ("text", .str f.text)]

/-- The statement a fact's receipt certifies (D-canon input of its `statementDigest`): a restated
result binds its restating claim's text, as an entailment fact binds its claim's. Reads the trace
through `L` (`Lookups.fast` in every caller). -/
def factManifest (L : Lookups) (f : Fact) : Value :=
  let base := [("id", .str f.id), ("subject", .str f.subject), ("kind", .str f.kind.name),
    ("text", .str f.text), ("route", .str f.route.name)]
  let bound : List (String × Value) :=
    match f.kind with
    | .entailment =>
      match L.entailmentClaim? f.id with
      | some c =>
        let needs := c.needs.map fun n =>
          Value.obj [("id", .str n), ("text", .str ((L.fact? n).map (·.text) |>.getD ""))]
        [("claim", .obj [("id", .str c.id), ("subject", .str c.subject),
          ("level", .str c.level.name), ("text", .str c.text), ("needs", .arr needs)])]
      | none => []
    | .result =>
      match L.restatingClaim? f.id with
      | some c =>
        [("restatedBy", .obj [("id", .str c.id), ("subject", .str c.subject),
          ("level", .str c.level.name), ("text", .str c.text)])]
      | none => []
    | .instantiation =>
      match f.instantiates.bind L.fact? with
      | some s => [("source", factBrief s)]
      | none => []
    | _ => []
  .obj (base ++ bound)

/-- The statement an exclusion's receipt certifies, endpoints included (rewording one stales it). -/
def exclusionManifest (L : Lookups) (x : Exclusion) : Value :=
  let endpoint (id : String) : Value := ((L.fact? id).map factBrief).getD (.obj [("id", .str id)])
  .obj [("id", .str x.id), ("subject", .str x.subject), ("text", .str x.text),
    ("route", .str x.route.name), ("between", .arr [endpoint x.between.1, endpoint x.between.2])]

def statementDigest (manifest : Value) : IO String := Digest.ofString manifest.canonical

/-! ## Artifact resolution + digest cache -/

/-- An artifact path, resolved inside the project root (symlinks resolved first), or why not. -/
def resolve (root : System.FilePath) (rel : String) : IO (Except String System.FilePath) := do
  let p := root / rel
  unless ← p.pathExists do return .error s!"missing {rel}"
  -- A dangling link can read as present (Windows); it has no real path.
  let real ← try IO.FS.realPath p catch _ => return .error s!"missing {rel}"
  let rootReal ← IO.FS.realPath root
  unless rootReal.components.isPrefixOf real.components && real.components != rootReal.components do
    return .error s!"outside {rel}"
  unless (← real.metadata).type == .file do return .error s!"not a file {rel}"
  return .ok real

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

def bind (root : System.FilePath) (cache : IO.Ref Cache) (rehash : Bool) (id : String)
    (ev : Option Evidence) (manifest : Value) : IO Binding := do
  let some ev := ev | return { id, current := false, reasons := ["no receipt"] }
  let mut reasons := #[]
  for a in ev.artifacts do
    match ← resolve root a.path with
    | .error why => reasons := reasons.push why
    | .ok real =>
      if some (← fileDigest cache rehash real) != a.sha256 then
        reasons := reasons.push s!"changed {a.path}"
  if some (← statementDigest manifest) != ev.statementDigest then
    reasons := reasons.push "statement-changed"
  return { id, current := reasons.isEmpty, reasons := reasons.toList }

/-- Bindings of every recorded verified fact + exclusion (the only ones a binding affects). -/
def bindings (t : Trace) (root : System.FilePath) (cache : IO.Ref Cache) (rehash : Bool := false)
    (L : Lookups := Lookups.fast t) : IO (List Binding) := do
  let mut out := #[]
  for f in t.facts do
    if f.status.verified then
      out := out.push (← bind root cache rehash f.id f.evidence (factManifest L f))
  for x in t.exclusions do
    if x.status.verified then
      out := out.push (← bind root cache rehash x.id x.evidence (exclusionManifest L x))
  return out.toList

/-! ## Pinning -/

/-- Pins one evidence block: each artifact's sha256 + the statement digest. Missing or escaping
artifacts stay unpinned and are reported. -/
def pinEvidence (root : System.FilePath) (cache : IO.Ref Cache) (ev : Evidence) (manifest : Value) :
    IO (Evidence × List String) := do
  let mut artifacts := #[]
  let mut problems := #[]
  for a in ev.artifacts do
    match ← resolve root a.path with
    | .error why => artifacts := artifacts.push a; problems := problems.push why
    | .ok real =>
      artifacts := artifacts.push { a with sha256 := some (← fileDigest cache true real) }
  let digest ← statementDigest manifest
  return ({ ev with artifacts := artifacts.toList, statementDigest := some digest },
    problems.toList)

/-- Pins every fact + exclusion that carries evidence; returns the new trace + problems. -/
def pin (t : Trace) (root : System.FilePath) (cache : IO.Ref Cache) :
    IO (Trace × List String) := do
  let L := Lookups.fast t
  let mut problems := #[]
  let mut facts := #[]
  for f in t.facts do
    match f.evidence with
    | some ev =>
      let (ev', ps) ← pinEvidence root cache ev (factManifest L f)
      facts := facts.push { f with evidence := some ev' }
      problems := problems ++ (ps.map (s!"{f.id}: " ++ ·)).toArray
    | none => facts := facts.push f
  let mut exclusions := #[]
  for x in t.exclusions do
    match x.evidence with
    | some ev =>
      let (ev', ps) ← pinEvidence root cache ev (exclusionManifest L x)
      exclusions := exclusions.push { x with evidence := some ev' }
      problems := problems ++ (ps.map (s!"{x.id}: " ++ ·)).toArray
    | none => exclusions := exclusions.push x
  return ({ t with facts := facts.toList, exclusions := exclusions.toList }, problems.toList)

/-! ## Review record -/

/-- SHA-256 of the canonical trace without its review record + replay notices (contract
§ Review: a notice never changes the review state). -/
def reviewDigest (t : Trace) : IO String :=
  Digest.ofString (Encode.trace { t.withoutNotices with review := none }).canonical

/-- A draft needs no digest, which keeps FFI-free callers FFI-free (the interpreted suite). -/
def reviewState (t : Trace) : IO ReviewState := do
  if t.review.isNone then return .draft
  return reviewStateOf t (← reviewDigest t)

/-- Records a review of the current content, dated today (local date). -/
def review (t : Trace) (reviewer : String) (note : Option String) : IO Trace := do
  let date := toString (← Std.Time.PlainDate.now)
  return { t with review := some { reviewer, date, digest := ← reviewDigest t, note } }

end Fvtrace.Receipt
