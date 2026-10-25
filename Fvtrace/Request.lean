import Fvtrace.Json

/-!
# One question to the engine (`.agent/contracts/kernel.md` V-request)

Every surface asks the same way: the CLI from its options, the server from a request body, the
page's engine from its worker. Init-only: the page engine compiles this module.
-/

namespace Fvtrace
open Fvtrace.Json

/-- A what-if, optionally an action to expand from it, optionally an item whose details to answer
there. -/
structure Request where
  whatif : String
  action : Option String := none
  details : Option String := none
  deriving BEq, Repr

namespace Request

def malformed : String := "the request is not of the form {whatif, action?, details?}"

/-- A request's JSON text: exactly the keys `whatif` (required), `action`, `details`, each a
string. -/
def parse (text : String) : Except String Request := do
  let .ok (.obj kvs) := Json.parse text.toUTF8 | throw malformed
  unless kvs.all (fun kv => kv.1 == "whatif" || kv.1 == "action" || kv.1 == "details") do
    throw malformed
  let str := fun (k : String) => match kvs.lookup k with
    | none => Except.ok none
    | some (.str v) => .ok (some v)
    | some _ => .error malformed
  let some whatif ← str "whatif" | throw malformed
  return { whatif, action := ← str "action", details := ← str "details" }

end Request

/-- An item whose details a request asks for (`KIND:ID`). -/
inductive Item where
  | experiment (id : String)
  | claim (id : String)
  | fact (id : String)
  deriving BEq, Repr

namespace Item

/-- `experiment:E`, `claim:C` or `fact:F` (ids never hold a colon: D-id). -/
def parse (s : String) : Except String Item :=
  let refuse := Except.error s!"\"{s}\" is not of the form KIND:ID"
  match s.splitOn ":" with
  | [kind, id] =>
    if id.isEmpty then refuse
    else match kind with
      | "experiment" => .ok (.experiment id)
      | "claim" => .ok (.claim id)
      | "fact" => .ok (.fact id)
      | _ => refuse
  | _ => refuse

def name : Item → String
  | .experiment id => s!"experiment:{id}"
  | .claim id => s!"claim:{id}"
  | .fact id => s!"fact:{id}"

end Item
end Fvtrace
