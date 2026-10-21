import Fvtrace
import Tests.Harness
import Tests.Engine

/-! Restating claims + the display fields `why` and `headline` (contract § Model shapes,
WF-entail, Receipts `restatedBy`, envelope). Inputs are JSON text, so each case runs the decoder
as a user's trace would. -/

namespace Tests.Fields
open Tests Fvtrace

def count (s sub : String) : Nat := (s.splitOn sub).length - 1

def fixtureText : IO String := IO.FS.readFile "tests/fixtures/restates.trace.json"

/-- Decodes `text`; a decode failure fails the named check and yields `none`. -/
def decoded (name text : String) : TestM (Option Trace) := do
  match decodeTrace text.toUTF8 with
  | .ok t => pure (some t)
  | .error ds =>
    check name false s!"{ds.toList.map fun d => (d.code, d.path, d.message)}"
    pure none

/-- The (rule, path) of every violation `fvtrace check` lists for `text`. -/
def violationsOf (text : String) : List (String × String) :=
  match decodeTrace text.toUTF8 with
  | .ok t => (Check.violations t).map fun v => (v.rule.code, v.path)
  | .error ds => ds.toList.map fun d => (s!"decode {d.code}", d.path)

def tests : TestM Unit := do
  let text ← fixtureText
  let some t ← decoded "fields: a restating claim decodes (no entailment)" text | return
  checkEq "fields: two claims restating two different results are well-formed (R3-R1)"
    (violationsOf text) []
  checkEq "fields: why, headline + restates round-trip (G-codec)"
    (decodeTrace (Encode.trace t).pretty.toUTF8).toOption (some t)
  let canon := (Encode.trace t).canonical
  check "fields: the encoding writes restates, headline + why"
    (count canon "\"restates\":true" == 2 && count canon "\"headline\":" == 1 &&
      count canon "\"why\":" == 1 && count canon "\"entailment\"" == 0) canon
  -- R3-R1: the shapes a restating claim may not take.
  let c2needs := "\"needs\": [\n        \"M2\"\n      ],\n      \"restates\": true"
  checkEq "fields: two claims restating one result → WF-entail on both"
    (violationsOf (text.replace c2needs "\"needs\": [\"M1\"],\n      \"restates\": true"))
    [("WF-entail", "/claims/0/needs"), ("WF-entail", "/claims/1/needs")]
  checkEq "fields: a restating claim needs one fact"
    (violationsOf (text.replace c2needs "\"needs\": [\"M2\", \"M1\"],\n      \"restates\": true"))
    [("WF-entail", "/claims/1/needs")]
  checkEq "fields: a claim with neither an entailment nor restates → WF-entail"
    (violationsOf (text.replace c2needs "\"needs\": [\"M2\"]"))
    [("WF-entail", "/claims/1")]
  let m2kind := "\"id\": \"M2\",\n      \"subject\": \"S\",\n      \"kind\": \"result\""
  checkEq "fields: a restating claim restates a result fact"
    (violationsOf (text.replace m2kind
      "\"id\": \"M2\",\n      \"subject\": \"S\",\n      \"kind\": \"dataflow\""))
    [("WF-entail", "/claims/1/needs")]
  let en := ",\n    {\"id\": \"EN\", \"subject\": \"S\", \"kind\": \"entailment\", " ++
    "\"text\": \"M2 entails C2.\", \"status\": \"open\", \"route\": \"lean\"}\n  ],\n  \"claims\""
  checkEq "fields: a restating claim names no entailment"
    (violationsOf ((text.replace "\n  ],\n  \"claims\"" en).replace c2needs
      "\"needs\": [\"M2\"],\n      \"entailment\": \"EN\",\n      \"restates\": true"))
    [("WF-entail", "/claims/1")]
  -- Each restated result binds its own restating claim; a result that a claim with an
  -- entailment needs alone binds none (its claim's text sits in the entailment's statement).
  let manifest := fun (tr : Trace) (id : String) =>
    (Receipt.factManifest tr ((tr.fact? id).get!)).canonical
  check "fields: each restated result binds its own claim (restatedBy)"
    (count (manifest t "M1") "\"restatedBy\":{\"id\":\"C1\"" == 1 &&
      count (manifest t "M2") "\"restatedBy\":{\"id\":\"C2\"" == 1)
    s!"{manifest t "M1"} {manifest t "M2"}"
  let main ← Tests.Engine.fixture
  check "fields: a result needed alone by a claim with an entailment binds no claim"
    (count (manifest main "M1") "restatedBy" == 0) (manifest main "M1")
  -- A restating claim reads as its result's effective state.
  let s : Scenario := { trace := t, current := fun _ => true }
  let finalOf := fun (sc : Scenario) (id : String) => sc.final ((t.claim? id).get!)
  checkEq "fields: a checked result → its restating claim is can" (finalOf s "C1") .can
  checkEq "fields: an open result → open" (finalOf s "C2") .«open»
  checkEq "fields: a violated result → cannot" (finalOf (s.withOverrides [("M1", .violated)]) "C1")
    .cannot
  checkEq "fields: a stale result → open"
    (finalOf { s with current := fun _ => false } "C1") .«open»
  let p : Fact := { id := "P1", subject := "S", kind := .provenance, text := "P1 holds.",
                    status := .«open», route := .humanRuling }
  let x : Exclusion := { id := "X1", subject := "S", between := ("P1", "P2"),
                         text := "P1 and P2 exclude each other.", status := .assumed,
                         route := .humanRuling }
  let clash := { t with facts := t.facts ++ [p, { p with id := "P2", text := "P2 holds." }],
                        exclusions := [x] }
  checkEq "fields: a conflicting what-if on the subject → cannot"
    (({ s with trace := clash, overrides := [("P1", .assumed), ("P2", .assumed)] } :
      Scenario).final ((t.claim? "C1").get!)) .cannot
  -- The envelope carries the display fields + restates; a restating claim has no entailment key.
  let env := Evaluate.envelope s [] "digest" .draft
  checkEq "fields: the envelope marks a restating claim"
    ((claimOf env "C1").bind (field · "restates"), (claimOf env "C1").bind (field · "entailment"))
    (some (.bool true), none)
  checkEq "fields: the envelope carries the headline"
    ((claimOf env "C1").bind (field · "headline"))
    (some (.str "Treated samples read higher on average."))
  checkEq "fields: the envelope carries why"
    ((recordOf env "facts" "M1").bind (field · "why"))
    (some (.str "The claim says the treated mean is higher, so the table must show it."))
  let envMain := Evaluate.envelope { trace := main, current := fun _ => true } [] "d" .draft
  checkEq "fields: a claim with an entailment does not restate"
    ((claimOf envMain "C1").bind (field · "restates"), (claimOf envMain "C1").bind
      (field · "entailment"))
    (some (.bool false), some (.str "EN1"))

/-- Receipts + review against real files (SHA-256 over FFI: native suite). -/
def nativeTests : TestM Unit := do
  let text ← fixtureText
  IO.FS.withTempDir fun dir => do
    let proj := dir / "proj"
    IO.FS.createDirAll (proj / "proofs")
    IO.FS.writeFile (proj / "proofs" / "Contrast.lean")
      "theorem contrast_correct : True := trivial\n"
    let env : Store.Env := { home := dir / "home", cwd := proj }
    let run := fun (args : List String) => capture (Cli.runIn env args)
    let trace := (dir / "t.json").toString
    IO.FS.writeFile trace text
    let (rc, _, _) ← run ["pin", "--trace", trace]
    checkEq "fields: pin rc" rc 0
    let (rc, out, _) ← run ["check", "--strict", "--trace", trace]
    check "fields: a pinned restating trace passes check --strict"
      (rc == 0 && count out "receipt M1: current" == 1) out
    let (rc, out, _) ← run ["review", "--trace", trace, "--reviewer", "R. Viewer"]
    checkEq "fields: review rc" rc 0
    check "fields: review prints what the sign-off vouches for"
      (count out "each headline says no more than its exact statement" == 1 &&
        count out "honest records, working instruments, correct labels" == 1) out
    let pinned ← IO.FS.readFile trace
    -- Display fields: a new headline or why leaves every receipt current; the review goes stale.
    for (name, a, b) in [("headline", "Treated samples read higher on average.",
        "Treated samples read higher."),
      ("why", "so the table must show it.", "so the table has to show it.")] do
      IO.FS.writeFile trace (pinned.replace a b)
      let (_, out, _) ← run ["check", "--trace", trace]
      check s!"fields: a new {name} keeps M1's receipt current + stales the review"
        (count out "receipt M1: current" == 1 && count out "review: stale" == 1) out
    -- Rewording the restating claim stales its result's receipt (restatedBy).
    IO.FS.writeFile trace (pinned.replace "\"text\": \"In the table, the treated mean is higher \
      than the control mean.\",\n      \"headline\""
      "\"text\": \"The treated mean is clearly higher.\",\n      \"headline\"")
    let (rc, out, _) ← run ["check", "--strict", "--trace", trace]
    check "fields: rewording a restating claim stales its result's receipt"
      (rc == 1 && count out "receipt M1: stale (statement-changed)" == 1) out

end Tests.Fields
