import Fvtrace
import Tests.Harness

namespace Tests.Snapshot
open Tests Fvtrace Fvtrace.Json Fvtrace.Snapshot

def count (s sub : String) : Nat := (s.splitOn sub).length - 1

def traceOf (path : String) : IO Trace := do
  match decodeTrace (← IO.FS.readBinFile path) with
  | .ok t => pure t
  | .error _ => throw (IO.userError s!"{path} does not decode")

/-- A binding for every recorded verified fact + exclusion: the first reads changed, the rest
current, so both receipt outcomes reach the envelope. -/
def snapOf (t : Trace) (review : Receipt.ReviewState) : Snapshot :=
  let ids := (t.facts.filter (·.status.verified)).map (·.id) ++
    (t.exclusions.filter (·.status.verified)).map (·.id)
  { trace := t, review, digest := String.ofList (List.replicate 64 'a'),
    bindings := ids.zipIdx.map fun (id, i) =>
      if i == 0 then
        { id, current := false, reasons := ["changed proofs/A.lean", "statement-changed"] }
      else { id, current := true, reasons := [] } }

def specOf (o : Overrides) : String := ",".intercalate (o.map fun (k, st) => s!"{k}={st.name}")

def scenarioOf (s : Snapshot) (o : Overrides) : Scenario :=
  { trace := s.trace, current := fun id => (s.bindings.find? (·.id == id)).any (·.current),
    overrides := Overrides.normalize o }

/-- What `Session.envelope` prints for the same frozen inputs. -/
def expected (s : Snapshot) (o : Overrides) : String :=
  (Evaluate.envelope (scenarioOf s o) s.bindings s.digest s.review).pretty

def problemOf (out : String) : Option (String × String) := do
  let v ← (Json.parse out.toUTF8).toOption
  let p ← field v "problem"
  let .str kind ← field p "kind" | none
  let .str message ← field p "message" | none
  return (kind, message)

def studies : List String :=
  ["examples/synthetic/trace.json", "examples/fvtrace/trace.json",
   "tests/fixtures/synthetic.trace.json", "tests/fixtures/restates.trace.json"]

/-- The snapshot's own member list with `k` replaced (`none` drops it). -/
def withMember (s : Snapshot) (k : String) (v : Option Value) : String :=
  match encode s with
  | .obj kvs =>
    let kvs := kvs.filterMap fun (k', v') => if k' == k then v.map (k, ·) else some (k', v')
    let added := if (kvs.lookup k).isNone then (v.map fun x => [(k, x)]).getD [] else []
    (Value.obj (kvs ++ added)).canonical
  | other => other.canonical

/-- Every one-click action + every stacked pair of supposed facts on `path` = the native
envelope (the GUI builds a pair by two presses). -/
def parity (path : String) : TestM Unit := do
  let s := snapOf (← traceOf path) .stale
  let snap := (encode s).canonical
  check s!"snapshot: {path} recorded = the native envelope" (evaluate snap "" == expected s [])
  let actions := Evaluate.actions (scenarioOf s [])
  let same := actions.filter fun (_, _, _, o) => evaluate snap (specOf o) == expected s o
  checkEq s!"snapshot: {path} every one-click action = the native envelope" same.length
    actions.length
  let supposes := actions.filterMap fun (_, kind, _, o) =>
    if kind == "suppose" then o.head? else none
  let pairs := supposes.zipIdx.flatMap fun (a, i) => (supposes.drop (i + 1)).map ([a, ·])
  let stacked := pairs.filter fun o => evaluate snap (specOf o) == expected s o
  checkEq s!"snapshot: {path} every stacked pair = the native envelope" stacked.length
    pairs.length

def pureTests : TestM Unit := do
  for path in studies do
    let t ← traceOf path
    for review in [Receipt.ReviewState.draft, .stale, .reviewed] do
      let s := snapOf t review
      check s!"snapshot: {path} ({review.name}) decodes to itself"
        ((decode (encode s).canonical).toOption == some s)
  let t ← traceOf "examples/synthetic/trace.json"
  let s := snapOf t .draft
  let snap := (encode s).canonical
  -- One cheap parity pair here, so the interpreted suite (the mutation tool's) sees bindings +
  -- overrides reach the envelope; `parity` covers every action natively.
  check "snapshot: recorded = the native envelope" (evaluate snap "" == expected s [])
  check "snapshot: a stacked what-if = the native envelope"
    (evaluate snap "O2=checked,EN2=proved" == expected s [("O2", .checked), ("EN2", .proved)])
  let whatifProblem := fun (spec : String) =>
    match Overrides.parse t spec with
    | .error m => some ("what-if", m)
    | .ok _ => none
  for spec in ["ZZ=proved", "O2=assumed", "O2=checked,O2=checked", "O2",
      "O2=checked\u0000,EN2=proved", "\u0000O2=checked", "O2=checked,", ",", "O2=chécked"] do
    checkEq s!"snapshot: what-if {repr spec} = the engine's problem"
      (problemOf (evaluate snap spec)) (whatifProblem spec)
  check "snapshot: an empty what-if entry is skipped as the command line skips it"
    (evaluate snap "O2=checked,,EN2=proved" == evaluate snap "O2=checked,EN2=proved")
  let illFormed :=
    { t with claims := t.claims.map fun c => { c with needs := c.needs ++ ["NOPE"] } }
  let invalid : List (String × String) :=
    [("not JSON", "{"), ("not an object", "[]"),
     ("another schema", withMember s "schema" (some (.str "fvtrace.snapshot/2"))),
     ("no digest", withMember s "digest" none),
     ("an extra member", withMember s "extra" (some .null)),
     ("a trace object, not its text", withMember s "trace" (some (Encode.trace t))),
     ("a trace text that does not decode", withMember s "trace" (some (.str "{}"))),
     ("an ill-formed trace", (encode { s with trace := illFormed }).canonical),
     ("bindings not a list", withMember s "bindings" (some (.obj []))),
     ("a binding with an extra member", withMember s "bindings" (some (.arr
       [.obj [("id", .str "O1"), ("current", .bool true), ("reasons", .arr []), ("x", .null)]]))),
     ("a binding whose current is a string", withMember s "bindings" (some (.arr
       [.obj [("id", .str "O1"), ("current", .str "yes"), ("reasons", .arr [])]]))),
     ("a reason that is not a string", withMember s "bindings" (some (.arr
       [.obj [("id", .str "O1"), ("current", .bool true), ("reasons", .arr [.num 1])]]))),
     ("an unknown review state", withMember s "review" (some (.str "approved"))),
     ("a digest that is not a string", withMember s "digest" (some (.num 1)))]
  for (name, input) in invalid do
    check s!"snapshot: {name} is an invalid snapshot"
      ((problemOf (evaluate input "")).map (·.1) == some "invalid") (evaluate input "")
  check "snapshot: an ill-formed trace decodes yet is refused (the engine's domain = WF traces)"
    ((decodeTrace (Encode.trace illFormed).canonical.toUTF8).isOk &&
      !(Check.violations illFormed).isEmpty)

/-- Parity with the native envelope on every study (35 s interpreted: native suite), then byte
parity with `fvtrace eval` on the synthetic study's pinned project (SHA-256 over FFI). -/
def nativeTests : TestM Unit := do
  for path in studies do parity path
  IO.FS.withTempDir fun dir => do
    let proj := dir / "proj"
    IO.FS.createDirAll (proj / "proofs")
    for e in ← System.FilePath.readDir "examples/synthetic/project/proofs" do
      IO.FS.writeBinFile (proj / "proofs" / e.fileName) (← IO.FS.readBinFile e.path)
    let env : Store.Env := { home := dir / "home", cwd := proj }
    let run := fun (args : List String) => capture (Cli.runIn env args)
    let (_, _, _) ← run ["init"]
    let (_, pathOut, _) ← run ["path"]
    IO.FS.writeBinFile pathOut.trimAscii.toString
      (← IO.FS.readBinFile "examples/synthetic/trace.json")
    let (_, _, _) ← run ["pin"]
    let tg ← IO.ofExcept (← Store.resolve env none none)
    match ← Session.load tg false none true (← IO.mkRef {}) with
    | .error _ => check "snapshot: the synthetic study loads" false
    | .ok l =>
      let snap := (encode
        { trace := l.scenario.trace, bindings := l.bindings, digest := l.digest,
          review := l.review }).canonical
      check "snapshot: the pinned study has a current receipt (parity covers bindings)"
        (l.bindings.any (·.current))
      for spec in ["", "O2=checked,EN2=proved", "O3=checked", "R1=violated,O2=checked",
          "EN1=proved,O1=open"] do
        let (rc, out, _) ← run (["eval"] ++ (if spec.isEmpty then [] else ["--whatif", spec]))
        check s!"snapshot: evaluate {repr spec} = fvtrace eval stdout, byte for byte"
          (rc == 0 && evaluate snap spec == out) s!"rc {rc}"
      let (rc, _, err) ← run ["eval", "--whatif", "O2=assumed"]
      match problemOf (evaluate snap "O2=assumed") with
      | some ("what-if", m) =>
        check "snapshot: a refused what-if = fvtrace eval's refusal"
          (rc == 2 && count err m == 1) err
      | other => check "snapshot: a refused what-if is a what-if problem" false s!"{repr other}"

/-- `fvtrace-tests --evaluate-snapshot SNAPSHOT SPECS`: SPECS = a JSON list of what-if strings;
prints the JSON list of `evaluate` outputs, in order. -/
def evaluateFile (snapshot specs : String) : IO UInt32 := do
  let snap ← IO.FS.readFile snapshot
  let .ok (.arr xs) := Json.parse (← IO.FS.readBinFile specs)
    | IO.eprintln s!"{specs}: not a JSON list"; return 2
  let outs ← xs.mapM fun | .str spec => pure (Value.str (evaluate snap spec))
                         | _ => throw (IO.userError s!"{specs}: a what-if is not a string")
  IO.print (Value.arr outs).canonical
  return 0

end Tests.Snapshot
