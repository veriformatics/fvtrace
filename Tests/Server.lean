import Fvtrace
import Tests.Harness

namespace Tests.Server
open Tests Fvtrace Fvtrace.Server

def token : String := "0123456789abcdef0123456789abcdef"

def cfgAt (dir : System.FilePath) : Config :=
  { target := { trace := dir / "trace.json", project := dir, entry := dir / "entry" },
    explicit := false, token, port := 8642, hosts := ["127.0.0.1:8642", "localhost:8642"] }

def req (path : String) (query : List (String × String) := []) (cookie : Option String := none)
    (host : Option String := some "127.0.0.1:8642") (method : Std.Http.Method := .get) : Req :=
  { method, path, query := fun k => query.lookup k, host, cookie }

def cookie : String := s!"other=1; fvtrace_8642={token}; x=y"

/-- (status code, a header's value, body) of a decided reply; `evaluate w` as status 0. -/
def outcome (a : Action) (header : String := "") : Nat × Option String × String :=
  match a with
  | .reply r => (r.status.toCode.toNat, r.headers.lookup header, r.body)
  | .evaluate w => (0, w, "")

/-- Access, host + routing decisions (no I/O). -/
def pureTests : TestM Unit := do
  let c := cfgAt "/nowhere"
  checkEq "server: only GET" (outcome (decide c (req "/" (method := .post))) "Allow")
    (405, some "GET", "Only GET is served.\n")
  checkEq "server: a foreign Host is refused (DNS rebinding)"
    (outcome (decide c (req "/" (cookie := cookie) (host := some "evil.example:8642")))).1 421
  checkEq "server: a missing Host is refused" (outcome (decide c (req "/" (host := none)))).1 421
  checkEq "server: localhost is an allowed name"
    (outcome (decide c (req "/" (cookie := cookie) (host := some "localhost:8642")))).1 200
  checkEq "server: the token link sets the cookie + drops the token from the address"
    (outcome (decide c (req "/" [("token", token)])) "Set-Cookie")
    (303, some s!"fvtrace_8642={token}; Path=/; HttpOnly; SameSite=Strict", "")
  checkEq "server: a wrong token is refused" (outcome (decide c (req "/" [("token", "x")]))).1 403
  checkEq "server: the token works on the entry page alone"
    (outcome (decide c (req "/app.js" [("token", token)]))).1 403
  checkEq "server: no cookie, no page" (outcome (decide c (req "/"))).1 403
  checkEq "server: no cookie, no evaluation" (outcome (decide c (req "/api/evaluation"))).1 403
  checkEq "server: another port's cookie is refused"
    (outcome (decide c (req "/" (cookie := s!"fvtrace_9999={token}")))).1 403
  let near := String.ofList (token.toList.take 31) ++ "0"
  checkEq "server: a token differing in one character is refused"
    (outcome (decide c (req "/" (cookie := s!"fvtrace_8642={near}")))).1 403
  checkEq "server: a token prefix is refused"
    (outcome (decide c (req "/" (cookie := s!"fvtrace_8642={token.take 8}")))).1 403
  checkEq "server: the page" (outcome (decide c (req "/" (cookie := cookie)))).2.2
    ((FvtraceWeb.files.lookup "/").map (·.2)).get!
  match decide c (req "/app.js" (cookie := cookie)) with
  | .reply r =>
    checkEq "server: a GUI module" (r.status.toCode, r.contentType)
      (200, "text/javascript; charset=utf-8")
  | .evaluate _ => check "server: a GUI module" false
  checkEq "server: an unknown path" (outcome (decide c (req "/etc/passwd" (cookie := cookie)))).1
    404
  checkEq "server: the evaluation route carries the what-if"
    (outcome (decide c (req "/api/evaluation" [("whatif", "O2=checked")] cookie)))
    (0, some "O2=checked", "")
  checkEq "server: cookie parsing" (cookieValue " a=1;b=2 ; c=3" "b") (some "2")
  checkEq "server: cookie absent" (cookieValue "a=1" "b") none
  check "server: equal secrets match" (sameSecret token token)
  check "server: unequal secrets differ" (!sameSecret token near && !sameSecret token "")

def body (r : Reply) : Option Json.Value := (Json.parse r.body.toUTF8).toOption

def problemKind (r : Reply) : Option String :=
  match body r with
  | some (.obj [("problem", .obj ps)]) => match ps.lookup "kind" with
    | some (.str k) => some k
    | _ => none
  | _ => none

/-- The evaluation route against a real project folder (SHA-256 over FFI: native suite). -/
def nativeTests : TestM Unit := do
  IO.FS.withTempDir fun dir => do
    let c := cfgAt dir
    let cache ← IO.mkRef ({} : Receipt.Cache)
    let ask := fun (w : Option String) => respond c cache (req "/api/evaluation"
      (w.toList.map fun v => ("whatif", v)) cookie)
    let r ← ask none
    checkEq "server: no trace yet" (r.status.toCode, problemKind r) (409, some "no-trace")
    IO.FS.writeBinFile c.target.trace (← IO.FS.readBinFile "tests/fixtures/synthetic.trace.json")
    let r ← ask none
    checkEq "server: the envelope" r.status.toCode 200
    match ← Session.load c.target false none false (← IO.mkRef {}) with
    | .ok l => check "server: the route serves the session's envelope" (body r == some
        (Session.envelope l))
    | .error _ => check "server: the route serves the session's envelope" false
    let r ← ask (some "O3=proved")
    checkEq "server: a what-if above the route" (r.status.toCode, problemKind r)
      (400, some "what-if")
    IO.FS.writeFile c.target.trace "{}"
    let r ← ask none
    checkEq "server: a trace that does not decode" (r.status.toCode, problemKind r)
      (409, some "invalid")

end Tests.Server
