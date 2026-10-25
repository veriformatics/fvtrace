import Tests.Harness
import Fvtrace.Check
import Fvtrace.Evaluate
import Fvtrace.Receipt

/-!
Scale (`kernel.md` P-bound, P-evidence): the shapes of `tools/scale.mjs` as `Trace` values, at sizes
where the list-scanning checker + engine ran for minutes (af5a2f1: `check` on 4,000 wide claims
29.5 s at load ≈ 26) and the indexed ones take a fraction of a second. A regression shows as this
area's time (the summary's three slowest) or the suite's timeout.
-/

namespace Tests.Scale
open Fvtrace

def fact (id : String) (k : Kind) (st : Status) (r : Route) : Fact :=
  { id, subject := "S", kind := k, text := s!"Fact {id} holds.", status := st, route := r }

def claim (i : Nat) (needs : List String) (entailment : String := s!"E{i}") : Claim :=
  { id := s!"C{i}", question := "Q", subject := "S", level := .inferential,
    text := s!"Claim {i} holds.", needs, entailment := some entailment }

def base (facts : List Fact) (claims : List Claim) : Trace :=
  { analysis := { id := "A", title := "Scale", summary := "Generated." },
    subjects := [{ id := "S", title := "Study", kind := .existing }],
    questions := [{ id := "Q", title := "Question", text := "Does it hold?" }], facts, claims }

/-- n claims, each needing F_i (statistical, assumed) + its entailment E_i (open, lean). -/
def wide (n : Nat) : Trace :=
  base ((List.range n).flatMap fun i =>
      [fact s!"F{i}" .statistical .assumed .humanRuling, fact s!"E{i}" .entailment .«open» .lean])
    ((List.range n).map fun i => claim i [s!"F{i}"])

/-- One claim needing F_0..F_{n-1} (even i assumed, odd i open on lean) + entailment E. -/
def deep (n : Nat) : Trace :=
  let fs := (List.range n).map fun i =>
    if i % 2 == 0 then fact s!"F{i}" .statistical .assumed .humanRuling
    else fact s!"F{i}" .statistical .«open» .lean
  base (fs ++ [fact "E" .entailment .«open» .lean]) [claim 0 (fs.map (·.id)) "E"]

/-- `wide` + one experiment per claim proving E_i (a failure violating it for even i). -/
def experiments (n : Nat) : Trace :=
  let efforts := [Effort.hours, .days, .weeks, .months]
  { wide n with
    experiments := (List.range n).map fun i =>
      { id := s!"R{i}", subject := "S", kind := .dry, effort := efforts[i % 4]!,
        title := s!"Prove {i}", method := "Write the proof.", resources := "One person.",
        success := [(s!"E{i}", .proved)],
        failure := if i % 2 == 0 then [(s!"E{i}", .violated)] else [], caveat := "None." } }

/-- `wide` + one experiment proving every E_i (`tools/scale.mjs` outcomes). -/
def outcomes (n : Nat) : Trace :=
  { wide n with
    experiments := [{ id := "R0", subject := "S", kind := .dry, effort := .days
                      title := "Prove all", method := "Write the proofs."
                      resources := "One person.", caveat := "None."
                      success := (List.range n).map fun i => (s!"E{i}", .proved) }] }

/-- `wide` + R_i proving E_i for the first two thirds (a chain R_i → R_(i-1), then a star on
R_third), the last third Y_i creating its own subject P_i, proving a fact no claim needs
(`tools/scale.mjs` prereqs). -/
def prereqs (n : Nat) : Trace :=
  let third := n / 3
  let w := wide n
  let exp := fun (id subject : String) (success : Overrides) (requires : List String) =>
    ({ id, subject, kind := .dry, effort := .days, title := s!"Run {id}", method := "Prove it."
       resources := "One person.", success, requires, caveat := "None." } : Experiment)
  { w with
    subjects := w.subjects ++ (List.range n).filterMap fun i =>
      if i < 2 * third then none
      else some ({ id := s!"P{i}", title := s!"Cohort {i}", kind := .prospective
                   createdBy := some s!"Y{i}" } : Subject)
    facts := w.facts ++ (List.range n).filterMap fun i =>
      if i < 2 * third then none
      else some { fact s!"K{i}" .statistical .«open» .lean with subject := s!"P{i}" }
    experiments := (List.range n).map fun i =>
      if i < 2 * third then
        exp s!"R{i}" "S" [(s!"E{i}", .proved)]
          (if i > 0 && i < third then [s!"R{i - 1}"] else if i > third then [s!"R{third}"]
            else [])
      else exp s!"Y{i}" s!"P{i}" [(s!"K{i}", .proved)] [] }

/-- `wide` with F_i open for even i + X_i between E_i and F_{i+1 mod n} (assumed exclusions:
receipts need files; `tools/scale.mjs` adds the proved ones). -/
def exclusions (n : Nat) : Trace :=
  let t := base ((List.range n).flatMap fun i =>
      [if i % 2 == 0 then fact s!"F{i}" .statistical .«open» .lean
       else fact s!"F{i}" .statistical .assumed .humanRuling,
       fact s!"E{i}" .entailment .«open» .lean])
    ((List.range n).map fun i => claim i [s!"F{i}"])
  { t with
    exclusions := (List.range n).map fun i =>
      { id := s!"X{i}", subject := "S", between := (s!"E{i}", s!"F{(i + 1) % n}"),
        text := "They exclude each other.", status := .assumed, route := .humanRuling } }

/-- The checker + lints on each shape: well-formed, one role warning per claim. -/
def checkTests : TestM Unit := do
  for (name, t, claims) in [("wide", wide 10000, 10000), ("deep", deep 30000, 1),
      ("experiments", experiments 10000, 10000), ("exclusions", exclusions 10000, 10000)] do
    checkEq s!"scale: {name} is well-formed" (Check.violations t).length 0
    checkEq s!"scale: {name} warns once per claim (no result fact)" (Lint.warnings t).length claims
  -- Error paths: a trace that fails anyway must not cost quadratic time either.
  let dup := { wide 10000 with claims := (wide 10000).claims.map fun c => { c with id := "C" } }
  checkEq "scale: 10,000 claims sharing one id → one ids violation naming it"
    ((Check.violations dup).filter (·.rule == .ids) |>.map (·.message))
    ["ids declared more than once: C"]
  let twice := { wide 10000 with
    claims := (wide 10000).claims ++
      (wide 10000).claims.map fun c => { c with entailment := none } }
  checkEq "scale: 10,000 ids declared twice → listed in the order of their second declaration"
    ((Check.violations twice).filter (·.rule == .ids) |>.map (·.message.length))
    [("ids declared more than once: " ++
      ", ".intercalate ((List.range 10000).map (s!"C{·}"))).length]
  -- Statement manifests read claims + facts through the indexes as well.
  let t := wide 10000
  let L := Lookups.fast t
  checkEq "scale: 10,000 entailment manifests name their claim"
    ((t.facts.filter (·.kind == .entailment)).filter (fun f =>
      (Receipt.factManifest L f).canonical.startsWith "{\"claim\"")).length 10000

/-- The array at `key` of a JSON object (empty when absent). -/
def items (v : Json.Value) (key : String) : List Json.Value :=
  match field v key with
  | some (.arr xs) => xs
  | _ => []

/-- A string member of a JSON object (empty when absent). -/
def text (v : Json.Value) (key : String) : String :=
  match field v key with
  | some (.str s) => s
  | _ => ""

def count (v : Json.Value) (key : String) : Option Json.Value :=
  (field v "counts").bind (field · key)

/-- The recorded envelope (`fvtrace eval`) on each shape: every verdict, work row, experiment +
plan, at sizes where the list-scanning engine ran for minutes (af5a2f1 binary, load ≈ 25: wide
4,000 101 s; deep 4,000, experiments + exclusions 1,000 each past 900 s). -/
def evalTests : TestM Unit := do
  let env := fun (t : Trace) => Evaluate.envelope { trace := t, current := fun _ => true } []
    "digest" .draft
  -- wide: C_i needs F_i (assumed at its ceiling) + E_i (open); proving E_i alone unlocks C_i.
  let n := 4000
  let e := env (wide n)
  checkEq "eval-scale: wide → every claim open" (count e "open") (some (.num n))
  let work := items e "work"
  checkEq "eval-scale: wide → one work row per E_i" work.length n
  checkEq "eval-scale: wide → each row unlocks its own claim alone"
    (work.filter fun w =>
      items w "unlocks" == [.str ("C" ++ ((text w "fact").drop 1).toString)]).length n
  checkEq "eval-scale: wide → one suppose action per E_i" (items e "actions").length n
  -- deep: one claim, odd F_i + E open (gaps), even F_i assumed (premises); no fact alone unlocks.
  let n := 8000
  let e := env (deep n)
  let c := (items e "claims").headD .null
  checkEq "eval-scale: deep → the claim stays open" (field c "final") (some (.str "open"))
  checkEq "eval-scale: deep → gaps = the odd F_i + E" (items c "gaps").length (n / 2 + 1)
  checkEq "eval-scale: deep → premises = the even F_i" (items c "premises").length (n / 2)
  let work := items e "work"
  checkEq "eval-scale: deep → one work row per open fact" work.length (n / 2 + 1)
  checkEq "eval-scale: deep → no row unlocks the claim"
    (work.filter (items · "unlocks" != [])).length 0
  -- experiments: R_i proves E_i (lights C_i), fails it for even i (breaks C_i); each claim's plan
  -- is its own R_i.
  let n := 2000
  let e := env (experiments n)
  let xs := items e "experiments"
  checkEq "eval-scale: experiments → every experiment lights one claim"
    (xs.filter (field · "lights" == some (.num 1))).length n
  checkEq "eval-scale: experiments → every even one breaks one claim"
    (xs.filter (field · "breaks" == some (.num 1))).length (n / 2)
  checkEq "eval-scale: experiments → order: lights, clears, cheaper effort, then id"
    ((xs.headD .null |> (field · "id")), (xs.getLast? |>.bind (field · "effort")))
    (some (.str "R0"), some (.str "months"))
  checkEq "eval-scale: experiments → each claim's plan = planned, conditional (the envelope)"
    ((items e "claims").filter fun c => (field c "plan").any fun p =>
      field p "result" == some (.str "planned") && field p "state" == some (.str "conditional")
      ).length n
  -- The plan's experiments (details, kernel.md V-details): its own R_i.
  let ex := experiments n
  let A := Answers.fast { trace := ex, current := fun _ => true }
  checkEq "eval-scale: experiments → each claim's plan = its own R_i"
    (ex.claims.filter fun c => match A.plan c with
      | .planned _ exps .. => exps == ["R" ++ (c.id.drop 1).toString]
      | _ => false).length n
  -- exclusions: X_i between E_i + F_(i+1); proving E_i unlocks C_i for odd i alone (even i:
  -- F_i open, or X_i makes the subject conflict).
  let n := 2000
  let e := env (exclusions n)
  let work := items e "work"
  checkEq "eval-scale: exclusions → rows: every E_i + the open F_i" work.length (n + n / 2)
  checkEq "eval-scale: exclusions → the odd E_i unlock their claim"
    (work.filter (items · "unlocks" != [])).length (n / 2)
  checkEq "eval-scale: exclusions → every claim open, the subject consistent"
    (count e "open", (items e "subjects").map (field · "valid"))
    (some (.num n), [some (.bool true)])
  -- outcomes: one experiment proves every E_i (U7: each claim's plan read at that experiment's
  -- node, not a delta over its n outcomes per claim).
  let n := 3000
  let e := env (outcomes n)
  checkEq "eval-scale: outcomes → the experiment lights every claim"
    ((items e "experiments").map (field · "lights")) [some (.num n)]
  checkEq "eval-scale: outcomes → each claim's plan = planned, conditional"
    ((items e "claims").filter fun c => (field c "plan").any fun p =>
      field p "result" == some (.str "planned") && field p "state" == some (.str "conditional")
      ).length n
  -- prereqs: a chain (R_i lights C_0 … C_i), a star (a leaf lights its claim + the root's), own
  -- creators (light nothing); plans of the first two thirds planned, the last third none.
  let n := 3000
  let e := env (prereqs n)
  let xs := items e "experiments"
  let lights := fun (id : String) =>
    (xs.find? (field · "id" == some (.str id))).bind (field · "lights")
  checkEq "eval-scale: prereqs → chain end, chain start, star root, star leaf, creator"
    ([lights "R999", lights "R0", lights "R1000", lights "R1999", lights "Y2999"])
    [some (.num 1000), some (.num 1), some (.num 1), some (.num 2), some (.num 0)]
  let plans := (items e "claims").filterMap fun c => (field c "plan").bind (field · "result")
  checkEq "eval-scale: prereqs → planned + no improvement"
    ((plans.filter (· == .str "planned")).length,
      (plans.filter (· == .str "noImprovement")).length) (2000, 1000)

end Tests.Scale
