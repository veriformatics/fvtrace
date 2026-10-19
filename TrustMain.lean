import Lean
open Lean

/-!
`fvtrace-trust`: do fvTrace's own claims hold, and what does believing them rest on?

Usage: `lake exe fvtrace-trust [--list-proofs]`.

- Claim = a `Prop`-valued definition in a module named `Fvtrace.Spec` or `Fvtrace.Spec.*`;
  proof = a theorem whose type is exactly that claim constant, declared outside the spec modules
  (so the spec text stays free of proof scripts).
- FAIL on: a claim with no proof; a proof using an axiom beyond `propext`, `Classical.choice`,
  `Quot.sound`; an escape hatch (`implemented_by`, `extern`, `unsafe`, `partial`, `opaque`) in a
  proof's closure outside Lean core; a claim whose statement never reaches shipped code (a
  non-spec `Fvtrace.*` constant), since such a claim certifies nothing about the binary.
- Lean core = modules whose `.olean` lies under the Lean sysroot, decided by file origin rather
  than module name, so a project-local module named `Lean.X` is still audited.
- `--list-proofs` prints the proof names alone, one per line, for `leanexport` replay.
-/

def standardAxioms : List Name := [``propext, ``Classical.choice, ``Quot.sound]

def modOf (env : Environment) (c : Name) : Name :=
  match env.getModuleIdxFor? c with
  | some i => env.header.moduleNames[i.toNat]!
  | none => .anonymous

def isSpecModule (m : Name) : Bool :=
  m == `Fvtrace.Spec || (`Fvtrace.Spec).isPrefixOf m

def isFvtraceModule (m : Name) : Bool :=
  (`Fvtrace).isPrefixOf m

/-- Worklist closure: `expand c` = successors of `c`, `none` = stop at `c`. -/
partial def closure (roots : Array Name) (expand : Name → Option (Array Name)) : Array Name :=
  go roots.toList {} #[]
where
  go : List Name → Std.HashSet Name → Array Name → Array Name
    | [], _, out => out
    | c :: rest, seen, out =>
      if seen.contains c then go rest seen out
      else go (((expand c).getD #[]).toList ++ rest) (seen.insert c) (out.push c)

def meaningDeps (ci : ConstantInfo) : Array Name :=
  let ty := ci.type.getUsedConstants
  match ci with
  | .defnInfo d => ty ++ d.value.getUsedConstants
  | .inductInfo i => ty ++ i.ctors.toArray
  | _ => ty

def escapeHatches (env : Environment) (c : Name) (ci : ConstantInfo) : Array String := Id.run do
  let mut fs := #[]
  if (Compiler.implementedByAttr.getParam? env c).isSome then fs := fs.push "implemented_by"
  if isExtern env c then fs := fs.push "extern"
  if ci.isUnsafe then fs := fs.push "unsafe"
  if ci.isPartial then fs := fs.push "partial"
  if let .opaqueInfo _ := ci then fs := fs.push "opaque"
  return fs

/-- Generated equation lemmas land in whichever module first unfolds a definition. -/
def isEqnLemma : Name → Bool
  | .str _ s =>
    s == "eq_def" || s == "eq_unfold" || (s.startsWith "eq_" && (s.drop 3).all Char.isDigit)
  | _ => false

structure Finding where
  claim : Name
  issue : String

def coreModules (env : Environment) : IO (Std.HashSet Name) := do
  let sys ← IO.FS.realPath ((← findSysroot) / "lib" / "lean")
  let mut core := {}
  for m in env.header.moduleNames do
    let f ← IO.FS.realPath (← findOLean m)
    if f.toString.startsWith (sys.toString ++ "/") then core := core.insert m
  return core

def audit (core : Std.HashSet Name) : CoreM (Array (Name × Array Name) × Array Finding) := do
  let env ← getEnv
  let isCore := fun c => core.contains (modOf env c)
  let mut claims : Array Name := #[]
  for (n, ci) in env.constants.toList do
    if isSpecModule (modOf env n) && !n.isInternal && !isEqnLemma n then
      if let .defnInfo d := ci then
        if d.type == .sort .zero then claims := claims.push n
  claims := claims.qsort Name.lt
  let mut proofsOf : Std.HashMap Name (Array Name) := {}
  for (n, ci) in env.constants.toList do
    if let .thmInfo t := ci then
      if let .const c [] := t.type then
        if !isSpecModule (modOf env n) then
          proofsOf := proofsOf.insert c ((proofsOf.getD c #[]).push n)
  let mut out := #[]
  let mut findings := #[]
  for c in claims do
    let prfs := (proofsOf.getD c #[]).qsort Name.lt
    out := out.push (c, prfs)
    if prfs.isEmpty then findings := findings.push { claim := c, issue := "no proof" }
    let stmt := closure #[c] fun n => match env.find? n with
      | some ci => if isCore n then none else some (meaningDeps ci)
      | none => none
    unless stmt.any (fun n => isFvtraceModule (modOf env n) && !isSpecModule (modOf env n)) do
      findings := findings.push { claim := c, issue := "statement reaches no shipped code" }
    for p in prfs do
      for ax in ← collectAxioms p do
        unless standardAxioms.contains ax do
          findings := findings.push { claim := c, issue := s!"{p} uses axiom {ax}" }
      let full := closure #[p] fun n => match env.find? n with
        | some ci => if isCore n then none
            else some (ci.type.getUsedConstants ++ (ci.value?.map Expr.getUsedConstants).getD #[])
        | none => none
      for n in full do
        if let some ci := env.find? n then
          unless isCore n do
            for f in escapeHatches env n ci do
              findings := findings.push { claim := c, issue := s!"{p} reaches {f} {n}" }
  return (out, findings)

def main (args : List String) : IO UInt32 := do
  initSearchPath (← findSysroot)
  let env ← importModules #[{ module := `Fvtrace }] {}
  let core ← coreModules env
  let ctx : Core.Context := { fileName := "<fvtrace-trust>", fileMap := default }
  let ((claims, findings), _) ← (audit core).toIO ctx { env }
  if args.contains "--list-proofs" then
    for (_, prfs) in claims do
      for p in prfs do IO.println p
    return if findings.isEmpty then 0 else 1
  for (c, prfs) in claims do
    let shown := if prfs.isEmpty then "UNPROVEN" else ", ".intercalate (prfs.toList.map toString)
    IO.println s!"claim {c}: {shown}"
  for f in findings do
    IO.eprintln s!"FAIL {f.claim}: {f.issue}"
  IO.println s!"trust: {claims.size} claims, {findings.size} findings"
  return if findings.isEmpty then 0 else 1
