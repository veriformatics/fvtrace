import Fvtrace.Engine
import Fvtrace.Receipt.Basic

/-!
# Presentation (contract § Sentences, § Experiments)

What a surface prints beside a claim's state: its verdict word, its sentence, its qualifiers, and
the order of the experiments. Pure functions of a scenario, below both answer records
(`Fvtrace.Answers`) and the envelope (`Fvtrace.Evaluate`).
-/

namespace Fvtrace

def State.verdict : State → String
  | .can => "Fully supported" | .conditional => "Conditional" | .«open» => "Pending verification"
  | .cannot => "Claim not possible"

namespace Scenario

/-- Quoted items with `; ` between them. -/
def joinParts : List String → List String
  | [] => []
  | [q] => [q]
  | q :: qs => q :: "; " :: joinParts qs

/-- A claim's sentence pieces from its final state + premise ids: verbatim claim + premise texts
(`Assuming “p₁”; “p₂”: text` for a conditional claim); the sentence is their concatenation. -/
def sentenceWith (final : State) (premises : List String) (factText : String → String)
    (c : Claim) : List String :=
  if final == .conditional then
    ["Assuming "] ++ joinParts (premises.map fun p => "“" ++ factText p ++ "”") ++ [": ", c.text]
  else [c.text]

/-- A claim's qualifiers: changed by the what-if, the review state, the experiment that creates
its subject (prospective subjects), a conflicting what-if on its subject. -/
def qualifiersWith (changed : Bool) (review : Receipt.ReviewState) (creator : Option String)
    (valid : Bool) : List String :=
  (if changed then ["what-if"] else []) ++
  (match review with | .draft => ["draft"] | .stale => ["stale review"] | .reviewed => []) ++
  (creator.map (fun t => [s!"if {t} runs"])).getD [] ++
  (if !valid then ["conflicting what-if"] else [])

/-- The title of the experiment that creates `subject` (its `createdBy`). -/
def creatorTitleWith (subject? : String → Option Subject) (experiment? : String → Option Experiment)
    (subject : String) : Option String := do
  let sub ← subject? subject
  let e ← sub.createdBy
  let x ← experiment? e
  return x.title

variable (s : Scenario)

def factText (id : String) : String := ((s.trace.fact? id).map (·.text)).getD id

def sentenceParts (c : Claim) : List String :=
  sentenceWith (s.final c) (s.premises c) s.factText c

def sentence (c : Claim) : String := String.join (s.sentenceParts c)

def baseline : Scenario := { s with overrides := [] }

def prospective (subject : String) : Bool :=
  ((s.trace.subject? subject).map (·.kind == .prospective)).getD false

/-- The what-if changes a need of the claim or its subject's consistency. -/
def changedByWhatif (c : Claim) : Bool :=
  c.needsAll.any (fun n => s.eff n != s.baseline.eff n) ||
    s.valid c.subject != s.baseline.valid c.subject

/-- The claim's state depends on the what-if (or its subject does not exist yet). -/
def hypothetical (c : Claim) : Bool := s.prospective c.subject || s.changedByWhatif c

/-- The experiment creates its subject (a prospective subject names it in `createdBy`). -/
def creates (e : Experiment) : Bool :=
  (s.trace.subject? e.subject).any (·.createdBy == some e.id)

def creatorTitle (subject : String) : Option String :=
  creatorTitleWith s.trace.subject? s.trace.experiment? subject

def qualifiers (c : Claim) (review : Receipt.ReviewState) : List String :=
  qualifiersWith (s.changedByWhatif c) review
    (if s.prospective c.subject then s.creatorTitle c.subject else none) (s.valid c.subject)

end Scenario

namespace Evaluate

def experimentBefore (sc : Scenario) (a b : Experiment) : Bool :=
  let ka := Scenario.lights (sc.moves (sc.applySuccess (sc.closure [a.id])))
  let kb := Scenario.lights (sc.moves (sc.applySuccess (sc.closure [b.id])))
  let ca := Scenario.clears (sc.moves (sc.applySuccess (sc.closure [a.id])))
  let cb := Scenario.clears (sc.moves (sc.applySuccess (sc.closure [b.id])))
  let ea := (Effort.all.idxOf a.effort)
  let eb := (Effort.all.idxOf b.effort)
  ka > kb || (ka == kb && (ca > cb || (ca == cb && (ea < eb || (ea == eb && a.id < b.id)))))

end Evaluate

end Fvtrace
