import Fvtrace
import Tests.Harness

namespace Tests.Server
open Tests Fvtrace Fvtrace.Server

def token : String := "0123456789abcdef0123456789abcdef"

def cfgAt (dir : System.FilePath) : Config :=
  { target := { trace := dir / "trace.json", project := dir, entry := dir / "entry" },
    explicit := false, token, hosts := Cli.loopbackHosts 8718 }

def req (path : String) (query : List (String × String) := [])
    (authorization : Option String := none) (host : Option String := some "fvtrace.localhost:8718")
    (method : Std.Http.Method := .get) : Req :=
  { method, path, query := fun k => query.lookup k, host, authorization }

def bearerOk : Option String := some s!"Bearer {token}"

/-- (status code, a header's value, body) of a decided reply; `evaluate w` as status 0. -/
def outcome (a : Action) (header : String := "") : Nat × Option String × String :=
  match a with
  | .reply r => (r.status.toCode.toNat, r.headers.lookup header, r.body)
  | .answer v => (1, v, "")

/-- A decided reply's JSON problem kind. -/
def decidedKind (a : Action) : Option String :=
  match a with
  | .reply r => match (Json.parse r.body.toUTF8).toOption with
    | some (.obj [("problem", .obj ps)]) => match ps.lookup "kind" with
      | some (.str k) => some k
      | _ => none
    | _ => none
  | _ => none

/-- Access, host + routing decisions (no I/O). -/
def pureTests : TestM Unit := do
  let c := cfgAt "/nowhere"
  checkEq "server: only GET" (outcome (decide c (req "/" (method := .post))) "Allow")
    (405, some "GET", "Only GET is served.\n")
  -- The answer route (kernel.md V-serve): POST alone, the token before the body is read.
  checkEq "server: the answer route takes POST alone"
    (outcome (decide c (req "/api/answer" (authorization := bearerOk))) "Allow")
    (405, some "POST", "Only POST is served.\n")
  checkEq "server: a POST with the token reaches the answer, with its view"
    (outcome (decide c { req "/api/answer" (authorization := bearerOk) (method := .post) with
      view := some "v1" })) (1, some "v1", "")
  checkEq "server: a POST without the token is refused before its body is read"
    (let a := decide c (req "/api/answer" (method := .post)); ((outcome a).1, decidedKind a))
    (403, some "access")
  checkEq "server: a POST to a foreign Host is refused"
    (outcome (decide c (req "/api/answer" (authorization := bearerOk) (method := .post)
      (host := some "evil.example:8718")))).1 421
  checkEq "server: a foreign Host is refused (DNS rebinding)"
    (outcome (decide c (req "/api/answer" (authorization := bearerOk) (method := .post)
      (host := some "evil.example:8718")))).1 421
  checkEq "server: a missing Host is refused" (outcome (decide c (req "/" (host := none)))).1 421
  checkEq "server: the loopback names" (Cli.loopbackHosts 8718)
    ["fvtrace.localhost:8718", "localhost:8718", "127.0.0.1:8718", "[::1]:8718"]
  for h in Cli.loopbackHosts 8718 do
    checkEq s!"server: {h} is an allowed name" (outcome (decide c (req "/" (host := some h)))).1 200
  checkEq "server: another port's name is refused"
    (outcome (decide c (req "/" (host := some "fvtrace.localhost:9999")))).1 421
  checkEq "server: the page loads without a credential (open-source code, no data)"
    (outcome (decide c (req "/"))).2.2 ((FvtraceWeb.files.lookup "/").map (·.2)).get!
  match decide c (req "/app.js") with
  | .reply r =>
    checkEq "server: a GUI module" (r.status.toCode, r.contentType)
      (200, "text/javascript; charset=utf-8")
  | _ => check "server: a GUI module" false
  checkEq "server: an unknown path" (outcome (decide c (req "/etc/passwd"))).1 404
  let refused := fun (name : String) (a : Action) =>
    checkEq name ((outcome a).1, decidedKind a) (403, some "access")
  refused "server: no credential, no claims" (decide c (req "/api/answer" (method := .post)))
  refused "server: the token in the query opens nothing (old links)"
    (decide c (req "/api/answer" [("token", token)] (method := .post)))
  refused "server: a wrong token is refused"
    (decide c (req "/api/answer" (authorization := some "Bearer x") (method := .post)))
  let near := String.ofList (token.toList.take 31) ++ "0"
  refused "server: a token differing in one character is refused"
    (decide c (req "/api/answer" (authorization := some s!"Bearer {near}") (method := .post)))
  refused "server: a token prefix is refused"
    (decide c (req "/api/answer" (authorization := some s!"Bearer {token.take 8}")
      (method := .post)))
  refused "server: the token without its scheme is refused"
    (decide c (req "/api/answer" (authorization := some token) (method := .post)))
  checkEq "server: the GET evaluation route is gone (v2: POST /api/answer)"
    (outcome (decide c (req "/api/evaluation" [("whatif", "O2=checked")] bearerOk))).1 404
  checkEq "server: bearer parsing" (bearer "Bearer abc", bearer "Basic abc", bearer "bearer abc")
    (some "abc", none, none)
  check "server: equal secrets match" (sameSecret token token)
  check "server: unequal secrets differ" (!sameSecret token near && !sameSecret token "")

def body (r : Reply) : Option Json.Value := (Json.parse r.body.toUTF8).toOption

def problemKind (r : Reply) : Option String :=
  match body r with
  | some (.obj [("problem", .obj ps)]) => match ps.lookup "kind" with
    | some (.str k) => some k
    | _ => none
  | _ => none

/-- `facts[id].receipt.current` of an envelope reply. -/
def receiptCurrent (r : Reply) (id : String) : Option Bool := do
  let .obj kvs ← body r | none
  let .arr fs ← kvs.lookup "facts" | none
  let .obj fk ← fs.find? (fun v => match v with
    | .obj fk => fk.lookup "id" == some (.str id)
    | _ => false) | none
  let .obj rk ← fk.lookup "receipt" | none
  let .bool b ← rk.lookup "current" | none
  pure b

/-- `POST /api/answer` = the CLI's answer, byte for byte; refusals by kind; the view header. -/
def answerTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    -- The synthetic study's own project folder: its receipts read current.
    let project ← IO.FS.realPath "examples/synthetic/project"
    let c := { cfgAt dir with target := { (cfgAt dir).target with project } }
    let cache ← IO.mkRef ({} : Receipt.Cache)
    IO.FS.writeBinFile c.target.trace (← IO.FS.readBinFile "examples/synthetic/trace.json")
    let repo : Store.Env := { home := dir / "home", cwd := ← IO.currentDir }
    let cli := fun (args : List String) => do
      let (_, out, _) ← capture (Cli.runIn repo (["eval", "--trace", c.target.trace.toString,
        "--project", project.toString] ++ args))
      return out
    let viewOf := fun (r : Reply) => r.headers.lookup "X-Fvtrace-View"
    for (body, args) in [("{\"whatif\":\"\"}", []),
        ("{\"whatif\":\"O2=checked\",\"details\":\"claim:C2\"}",
          ["--whatif", "O2=checked", "--details", "claim:C2"]),
        ("{\"whatif\":\"\",\"action\":\"plan:C2\"}", ["--action", "plan:C2"])] do
      let r ← answer c cache none body
      checkEq s!"server: {body} = fvtrace eval's bytes" (r.status.toCode, r.body) (200, ← cli args)
      check s!"server: {body} names its view" (viewOf r).isSome
    for (body, kind) in [("{\"whatif\":\"O9=proved\"}", "what-if"),
        ("{\"whatif\":\"\",\"action\":\"plan:C9\"}", "action"),
        ("{\"whatif\":\"\",\"details\":\"E9\"}", "item"), ("{}", "invalid"), ("[", "invalid"),
        ("{\"whatif\":\"O9=proved\",\"action\":\"x\",\"details\":\"y\"}", "what-if")] do
      let r ← answer c cache none body
      checkEq s!"server: {body} refused" (r.status.toCode, problemKind r) (400, some kind)
    let first ← answer c cache none "{\"whatif\":\"\"}"
    let same ← answer c cache (viewOf first) "{\"whatif\":\"\",\"details\":\"fact:O2\"}"
    checkEq "server: details for the page's view" same.status.toCode 200
    let other ← answer c cache (some "00ff") "{\"whatif\":\"\",\"details\":\"fact:O2\"}"
    checkEq "server: details for another view = 409 view" (other.status.toCode, problemKind other)
      (409, some "view")
    checkEq "server: an answer past the body cap = 413"
      ((← answerBody c cache none none).status.toCode) 413

/-- The evaluation route against a real project folder (SHA-256 over FFI: native suite). -/
def nativeTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let c := cfgAt dir
    let cache ← IO.mkRef ({} : Receipt.Cache)
    let requestOf := fun (w : Option String) =>
      some (Json.Value.obj [("whatif", .str (w.getD ""))]).canonical.toUTF8
    let ask := fun (w : Option String) => answerBody c cache none (requestOf w)
    let r ← ask none
    checkEq "server: no trace yet" (r.status.toCode, problemKind r) (409, some "no-trace")
    IO.FS.writeBinFile c.target.trace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json")
    let r ← ask none
    checkEq "server: the envelope" r.status.toCode 200
    match ← Session.load c.target false none false (← IO.mkRef {}) with
    | .ok l => check "server: the route serves the session's envelope" (body r == some
        (Session.envelope l))
    | .error _ => check "server: the route serves the session's envelope" false
    -- Evidence is read again by default; `cached` (serve --cached) reuses a digest recorded for
    -- the same size + mtime (planted: "x").
    IO.FS.createDirAll (dir / "proofs")
    let proof := "theorem contrast_correct : True := trivial\n"
    IO.FS.writeFile (dir / "proofs" / "Contrast.lean") proof
    let fixture ← match decodeTrace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json") with
      | .ok t => pure t
      | .error _ => throw (IO.userError "the fixture does not decode")
    let (pinned, _) ← Receipt.pin fixture dir (← IO.mkRef {})
    Cli.writeTrace c.target.trace pinned
    let real ← IO.FS.realPath (dir / "proofs" / "Contrast.lean")
    let m ← real.metadata
    let planted : Receipt.Cache :=
      ({} : Receipt.Cache).insert real.toString (m.byteSize, m.modified.sec, m.modified.nsec, "x")
    let fresh ← answerBody c (← IO.mkRef planted) none (requestOf none)
    checkEq "server: evidence is read again by default" (receiptCurrent fresh "O1") (some true)
    let reused ← answerBody { c with cached := true } (← IO.mkRef planted) none (requestOf none)
    checkEq "server: cached reuses a recorded digest" (receiptCurrent reused "O1") (some false)
    let r ← ask (some "O3=proved")
    checkEq "server: a what-if above the route" (r.status.toCode, problemKind r)
      (400, some "what-if")
    IO.FS.createDirAll (c.target.entry / "cache.json")
    let r ← ask none
    checkEq "server: an I/O failure answers a JSON problem, not an empty 500"
      (r.status.toCode, problemKind r) (500, some "io")
    IO.FS.removeDirAll (c.target.entry)
    IO.FS.writeFile c.target.trace "{}"
    let r ← ask none
    checkEq "server: a trace that does not decode" (r.status.toCode, problemKind r)
      (409, some "invalid")

end Tests.Server
