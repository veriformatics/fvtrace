import Fvtrace.Json
import Fvtrace.Model

/-!
# Trace encoding

Typed trace → JSON value in the schema's field order (`.agent/contracts/kernel.md` G-codec:
`decode (encode t) = t`). Absent options + empty optional lists + `latent = false` are omitted,
which decodes back to the same defaults.
-/

namespace Fvtrace.Encode
open Fvtrace.Json

def field (k : String) (v : Value) : List (String × Value) := [(k, v)]

def optField {α : Type} (k : String) (f : α → Value) : Option α → List (String × Value)
  | some a => [(k, f a)]
  | none => []

def listField {α : Type} (k : String) (f : α → Value) : List α → List (String × Value)
  | [] => []
  | xs => [(k, .arr (xs.map f))]

def str (s : String) : Value := .str s

def analysis (a : Analysis) : Value :=
  .obj (field "id" (str a.id) ++ field "title" (str a.title) ++ field "summary" (str a.summary) ++
    optField "source" str a.source)

def subject (s : Subject) : Value :=
  .obj (field "id" (str s.id) ++ field "title" (str s.title) ++ field "kind" (str s.kind.name) ++
    optField "createdBy" str s.createdBy)

def question (q : Question) : Value :=
  .obj (field "id" (str q.id) ++ field "title" (str q.title) ++ field "text" (str q.text))

def artifact (a : Artifact) : Value :=
  .obj (field "path" (str a.path) ++ optField "sha256" str a.sha256 ++ optField "role" str a.role)

def replay (r : Replay) : Value :=
  .obj (field "command" (.arr (r.command.map str)) ++ optField "output" str r.output)

def evidence (e : Evidence) : Value :=
  .obj (field "summary" (str e.summary) ++ listField "artifacts" artifact e.artifacts ++
    optField "verifier" str e.verifier ++ optField "statement" str e.statement ++
    optField "statementDigest" str e.statementDigest ++ optField "replay" replay e.replay)

def fact (f : Fact) : Value :=
  .obj (field "id" (str f.id) ++ field "subject" (str f.subject) ++
    field "kind" (str f.kind.name) ++
    field "text" (str f.text) ++ field "status" (str f.status.name) ++
    field "route" (str f.route.name) ++ optField "evidence" evidence f.evidence ++
    listField "trusts" str f.trusts ++ optField "instantiates" str f.instantiates ++
    optField "why" str f.why)

def claim (c : Claim) : Value :=
  .obj (field "id" (str c.id) ++ field "question" (str c.question) ++
    field "subject" (str c.subject) ++ field "level" (str c.level.name) ++
    field "text" (str c.text) ++ optField "headline" str c.headline ++
    field "needs" (.arr (c.needs.map str)) ++ optField "entailment" str c.entailment ++
    (if c.restates then field "restates" (.bool true) else []) ++
    (if c.latent then field "latent" (.bool true) else []) ++
    optField "variantOf" str c.variantOf)

def outcome (m : List (String × Status)) : Value :=
  .obj (m.map fun (k, s) => (k, str s.name))

def experiment (e : Experiment) : Value :=
  .obj (field "id" (str e.id) ++ field "subject" (str e.subject) ++
    field "kind" (str e.kind.name) ++ field "effort" (str e.effort.name) ++
    field "title" (str e.title) ++ field "method" (str e.method) ++
    field "resources" (str e.resources) ++ field "success" (outcome e.success) ++
    (if e.failure.isEmpty then [] else field "failure" (outcome e.failure)) ++
    listField "requires" str e.requires ++ field "caveat" (str e.caveat))

def exclusion (x : Exclusion) : Value :=
  .obj (field "id" (str x.id) ++ field "subject" (str x.subject) ++
    field "between" (.arr [str x.between.1, str x.between.2]) ++ field "text" (str x.text) ++
    field "status" (str x.status.name) ++ field "route" (str x.route.name) ++
    optField "evidence" evidence x.evidence)

def waiver (w : Waiver) : Value :=
  .obj (field "rule" (str w.rule) ++ field "claim" (str w.claim) ++ field "reason" (str w.reason))

def review (r : Review) : Value :=
  .obj (field "reviewer" (str r.reviewer) ++ field "date" (str r.date) ++
    field "digest" (str r.digest) ++ optField "note" str r.note)

def trace (t : Trace) : Value :=
  .obj (field "fvtrace" (.num 1) ++ field "analysis" (analysis t.analysis) ++
    field "subjects" (.arr (t.subjects.map subject)) ++
    field "questions" (.arr (t.questions.map question)) ++
    field "facts" (.arr (t.facts.map fact)) ++ field "claims" (.arr (t.claims.map claim)) ++
    listField "experiments" experiment t.experiments ++
    listField "exclusions" exclusion t.exclusions ++ listField "waivers" waiver t.waivers ++
    optField "review" review t.review)

end Fvtrace.Encode
