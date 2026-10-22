import Fvtrace
import Tests.Harness

namespace Tests.Replay
open Tests Fvtrace

/-- The verifier these tests run (`fvtrace-tests --replay-fixture STEP…`, no shell on any OS):
`out:FILE` prints FILE's bytes, `hex:HEX` prints those bytes, `err:TEXT` writes TEXT to stderr,
`fill:N` writes N `x` + `END` to stderr, `touch:FILE` creates FILE, `put:FILE` writes
"rewritten\n" into FILE, `sleep:MS`, `exit:N` ends with N; `late:MS` leaves a child that prints
`late` after MS (holding stdout alone), `orphan:MS` a child that sleeps MS (holding both
pipes). Paths are relative to the working folder (the project folder). -/
def fixture (steps : List String) : IO UInt32 := do
  let out ← IO.getStdout
  for step in steps do
    let op := String.ofList (step.toList.takeWhile (· != ':'))
    let arg := (step.drop (op.length + 1)).toString
    match op with
    | "out" => out.write (← IO.FS.readBinFile arg)
    | "hex" => out.write (Export.hexBytes arg)
    | "err" => (← IO.getStderr).putStr arg
    | "fill" => (← IO.getStderr).putStr ("".pushn 'x' arg.toNat! ++ "END")
    | "touch" => IO.FS.writeFile arg ""
    | "put" => IO.FS.writeFile arg "rewritten\n"
    | "sleep" => IO.sleep arg.toNat!.toUInt32
    | "exit" => out.flush; return arg.toNat!.toUInt32
    | "late" =>
      let app := (← IO.appPath).toString
      let _ ← IO.Process.spawn
        { cmd := app, args := #["--replay-fixture", s!"sleep:{arg}", "hex:6c6174650a"],
          stderr := .null }
    | "orphan" =>
      let app := (← IO.appPath).toString
      let _ ← IO.Process.spawn { cmd := app, args := #["--replay-fixture", s!"sleep:{arg}"] }
    | _ => throw (IO.userError s!"unknown fixture step {step}")
  out.flush
  return 0

def count (s sub : String) : Nat := (s.splitOn sub).length - 1

/-- Display quoting (no I/O). -/
def pureTests : TestM Unit := do
  checkEq "replay: a displayed command quotes arguments with a space or a quote"
    (Replay.display ["lake", "build", "a b", "say \"hi\"", "it's"])
    "lake build \"a b\" \"say \\\"hi\\\"\" \"it's\""
  checkEq "replay: a deadline lies S seconds after the start" (Replay.deadline 5 2) 2005
  check "replay: a deadline expires at its millisecond, not before"
    (Replay.expired 2005 2005 && !Replay.expired 2004 2005)
  checkEq "replay: the deadline is checked every 20 ms" Replay.pollMs 20

/-- `t` with fact `id`'s replay set to `r`. -/
def setReplay (t : Trace) (id : String) (r : Replay) : Trace :=
  { t with facts := t.facts.map fun f =>
      if f.id != id then f
      else { f with evidence := f.evidence.map ({ · with replay := some r }) } }

/-- `verify --run` + `pin --replay` against the fixture verifier, in temporary folders. -/
def tests : TestM Unit := do
  let app := (← IO.appPath).toString
  IO.FS.withTempDir fun dir => do
    let proj := dir / "proj"
    IO.FS.createDirAll (proj / "proofs")
    IO.FS.writeFile (proj / "proofs" / "Thm.lean") "theorem t : True := trivial\n"
    IO.FS.writeFile (proj / "proofs" / "Gen.lean") "generated\n"
    IO.FS.writeFile (proj / "spec.txt") "forall x, x = x\n"
    let marker := dir / "ran"
    let fx := fun (steps : List String) => [app, "--replay-fixture"] ++ steps
    let fact := fun (id : String) (status : Status) (path : String) (cmd : List String) =>
      ({ id, subject := "S", kind := .numerical, text := s!"{id} holds.", status, route := .lean,
         evidence := some
           { summary := "A proof.", artifacts := [{ path }], verifier := "Lean",
             statement := "t", replay := some { command := cmd } } } : Fact)
    let base : Trace :=
      { analysis := { id := "A", title := "Replay", summary := "Replay tests." },
        subjects := [{ id := "S", title := "Replay", kind := .existing }],
        questions := [{ id := "Q", title := "Q", text := "Does it hold?" }],
        facts := [fact "O1" .proved "proofs/Thm.lean" (fx [s!"touch:{marker}", "out:spec.txt"]),
          fact "O2" .«open» "proofs/Thm.lean" (fx ["hex:ff000a0d0a", "err:diagnostics"]),
          fact "O4" .proved "proofs/Gen.lean" (fx ["put:proofs/Gen.lean"]),
          { id := "EN", subject := "S", kind := .entailment, text := "O1 entails C.",
            status := .«open», route := .lean }],
        claims := [{ id := "C", question := "Q", subject := "S", level := .estimand,
                     text := "It holds.", needs := ["O1"], entailment := some "EN" }],
        exclusions := [{ id := "X", subject := "S", between := ("O2", "O4"),
                         text := "O2 rules out O4.", status := .«open», route := .lean,
                         evidence := some
                           { summary := "A check.",
                             replay := some { command := fx ["out:spec.txt"] } } }],
        waivers := [{ rule := "L-estimand", claim := "C", reason := "Replay tests." }] }
    let traceFile := dir / "trace.json"
    Cli.writeTrace traceFile base
    let env : Store.Env := { home := dir / "home", cwd := proj }
    let run := fun (args : List String) => capture (Cli.runIn env (args ++ ["--trace",
      traceFile.toString]))
    -- No command starts without the opt-in.
    let (rc, _, _) ← run ["pin"]
    checkEq "replay: plain pin rc" rc 0
    let (rc, out, _) ← run ["verify"]
    check "replay: verify lists the commands, runs none"
      (rc == 0 && count out "None runs without --run" == 1 && count out "O1:" == 1 &&
        count out "replay(s) passed" == 0) out
    let _ ← run ["check"]
    let _ ← run ["claims"]
    let _ ← run ["export", "--html", (dir / "page.html").toString]
    check "replay: pin, verify, check, claims + export run no command" !(← marker.pathExists)
    let (rc, _, _) ← run ["verify", "--timeout", "5"]
    checkEq "replay: --timeout without --run is a usage error" rc 2
    let (rc, _, _) ← run ["pin", "--timeout", "5"]
    checkEq "replay: --timeout without --replay is a usage error" rc 2
    let (rc, _, _) ← run ["check", "--run"]
    checkEq "replay: check --run is a usage error" rc 2
    -- Opted in: unpinned outputs fail, and the command did run.
    let (rc, out, _) ← run ["verify", "--run"]
    check "replay: an unpinned output fails" (rc == 1 && count out "output not pinned" == 4) out
    check "replay: --run runs the commands" (← marker.pathExists)
    -- pin --replay: outputs = raw stdout bytes; receipts hashed after the replays.
    let (rc, _, _) ← run ["pin", "--replay"]
    checkEq "replay: pin --replay rc" rc 0
    let pinned ← match decodeTrace (← IO.FS.readBinFile traceFile) with
      | .ok t => pure t
      | .error _ => throw (IO.userError "the pinned trace does not decode")
    let outputOf := fun (id : String) =>
      ((pinned.facts.find? (·.id == id)).bind (·.evidence) |>.bind (·.replay)).bind (·.output)
    checkEq "replay: an output = SHA-256 of the exact stdout bytes"
      (outputOf "O2") (some (← Digest.ofBytes (Export.hexBytes "ff000a0d0a")))
    checkEq "replay: stdout of a text verifier" (outputOf "O1")
      (some (← Digest.ofString "forall x, x = x\n"))
    let (rc, out, _) ← run ["check", "--json"]
    check "replay: a receipt pinned after its replay rewrote the artifact reads current"
      (rc == 0 && count out "\"current\": false" == 0 && count out "\"current\": true" == 2) out
    let (rc, out, _) ← run ["verify", "--run"]
    check "replay: unchanged outputs pass" (rc == 0 && count out "4 of 4 replay(s) passed" == 1) out
    check "replay: a passing command's stderr stays hidden" (count out "error output" == 0) out
    let (rc, _, _) ← run ["verify", "--run", "--timeout", "30"]
    checkEq "replay: a deadline that no command reaches changes nothing" rc 0
    -- A child of the verifier holds stdout after the verifier exits: the output read is all of it.
    Cli.writeTrace traceFile
      (setReplay pinned "O1" { command := fx ["late:300"], output := ← Digest.ofString "late\n" })
    let (rc, out, _) ← run ["verify", "--run", "--timeout", "30"]
    check "replay: under a deadline, the output is read to its end"
      (rc == 0 && count out "O1: passed" == 1) out
    if !System.Platform.isWindows then
      -- POSIX: the deadline ends the verifier's whole process group, a child holding the pipes too.
      Cli.writeTrace traceFile
        (setReplay pinned "O1" { command := fx ["orphan:20000"], output := outputOf "O1" })
      let t0 ← IO.monoMsNow
      let (_, out, _) ← run ["verify", "--run", "--timeout", "1"]
      check "replay: the deadline ends a child that holds the pipes"
        (count out "O1: failed (timeout)" == 1 && (← IO.monoMsNow) - t0 < 15000) out
    Cli.writeTrace traceFile pinned
    -- The acceptance: a statement weakened outside every pinned artifact.
    IO.FS.writeFile (proj / "spec.txt") "forall x, True\n"
    let (_, out, _) ← run ["check", "--json"]
    check "replay: the weakened statement leaves every receipt current"
      (count out "\"current\": false" == 0) out
    let (rc, out, _) ← run ["verify", "--run", "--json"]
    check "replay: the weakened statement fails its replays (fact + exclusion)"
      (rc == 1 && count out "\"output changed\"" == 2) out
    -- Exit status, timeout + a missing program each fail, whatever the output.
    Cli.writeTrace traceFile
      (setReplay pinned "O1" { command := fx ["out:spec.txt", "exit:7"], output := outputOf "O1" })
    let (_, out, _) ← run ["verify", "--run"]
    check "replay: a non-zero exit fails"
      (count out "O1: failed (exit 7)" == 1 && count out "2 of 4 replay(s) passed" == 1) out
    let (rc, out, err) ← run ["pin", "--replay"]
    check "replay: pin --replay reports a failed replay and exits 1"
      (rc == 1 && count out ", 1 replay(s) failed" == 1 && count err "O1: output not pinned" == 1)
      (out ++ err)
    Cli.writeTrace traceFile
      (setReplay pinned "O1" { command := fx ["fill:6000", "exit:3"], output := outputOf "O1" })
    let (_, out, _) ← run ["verify", "--run"]
    let shown := ((out.splitOn "its error output ends with: ").getD 1 "").takeWhile (· != '\n')
    check "replay: a failing command shows its stderr's last 4 KiB"
      (shown.toString.endsWith "END" && shown.toString.length == 4096) shown.toString
    Cli.writeTrace traceFile
      (setReplay pinned "O1" { command := fx ["sleep:20000"], output := outputOf "O1" })
    let t0 ← IO.monoMsNow
    let (_, out, _) ← run ["verify", "--run", "--timeout", "1"]
    check "replay: --timeout kills a verifier that runs too long"
      (count out "O1: failed (timeout)" == 1 && (← IO.monoMsNow) - t0 < 15000) out
    Cli.writeTrace traceFile
      (setReplay pinned "O1" { command := ["fvtrace-no-such-program"], output := outputOf "O1" })
    let (_, out, _) ← run ["verify", "--run"]
    IO.FS.writeFile (dir / "broken.json") "{"
    let (rc, _, _) ← capture (Cli.runIn env ["verify", "--trace", (dir / "broken.json").toString])
    checkEq "replay: verify on a trace that does not decode rc" rc 1
    Cli.writeTrace (dir / "raw.json") base
    let (rc, _, _) ← capture (Cli.runIn env ["verify", "--run", "--trace",
      (dir / "raw.json").toString])
    checkEq "replay: verify on a trace that is not well-formed rc (nothing runs)" rc 1
    check "replay: a missing program fails"
      (count out "O1: failed (exit 255)" + count out "O1: failed (cannot start" == 1) out

end Tests.Replay
