import Fvtrace.Answers.Fast
import Fvtrace.Check
import Fvtrace.Json
import Fvtrace.Receipt.Basic

/-!
# The fast paths answer as the definitions do (`kernel.md` P-claims)

fvTrace reads a trace through sorted indexes, so a 16 MiB trace takes seconds. Each claim below
says that an indexed answer equals the plain definition it replaces. The other claims are stated
over the plain definitions, so they cover what the binary shows.
-/

namespace Fvtrace.Spec
open Fvtrace

/-- Every question that the checker, the lints and the receipt statements ask of a trace (a fact,
subject, claim or experiment by its id, whether an id is declared, the ids declared twice, which
claims use an entailment fact or restate a result, an earlier experiment or exclusion, a waiver)
gets the same answer from the trace's sorted indexes as from its lists. A receipt binding found by
its id through an index is the first binding with that id. -/
def LookupsAgree : Prop :=
  (∀ t : Trace, Lookups.fast t = Lookups.reference t) ∧
    ∀ bindings : List Receipt.Binding,
      (Receipt.BindingIndex.of bindings).find = fun id => bindings.find? (·.id == id)

/-- The canonical form of a JSON object (the input of every digest) orders its members exactly as
the insertion sort that it replaces: by key, and members with equal keys in reversed order. -/
def SortMembersAgree : Prop :=
  ∀ kvs : List (String × Json.Value), Json.sortMembers kvs = kvs.foldr Json.insertBy []

/-- Every answer that the envelope, the GUI and the CLI read about a scenario (each fact's status,
each claim's verdict, its sentence and qualifiers, the claims each fact unlocks, the experiments in
their order and the claims that they move, each claim's plan) is the same from the indexed engine
as from the plain definitions that the other claims are about. -/
def AnswersAgree : Prop := ∀ s : Scenario, Answers.fast s = Answers.reference s

end Fvtrace.Spec
