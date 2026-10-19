import Std.Http
import FvtraceWeb
import Fvtrace.Session

/-!
# `fvtrace serve`: the GUI over local HTTP

Serves the embedded GUI and one JSON route, the evaluation envelope (under a what-if). The GUI
displays it and computes no verdict. The server reads the project and writes nothing but its own
digest cache.

Access: a random token per run, printed in the link; the first load trades it for a cookie scoped
to this port. Every request must name an allowed `Host` (a page on another site that rebinds its
DNS name to this address is refused) and use GET. Responses forbid framing, sniffing, inline
script and HTML-string DOM sinks (Trusted Types).
-/

namespace Fvtrace.Server
open Std Std.Async Std.Http Fvtrace.Json

structure Config where
  target : Store.Target
  /-- The user named the trace file (`--trace`). -/
  explicit : Bool
  token : String
  port : UInt16
  /-- `Host` header values the server answers. -/
  hosts : List String

def cookieName (cfg : Config) : String := s!"fvtrace_{cfg.port}"

/-- A response before transport. -/
structure Reply where
  status : Std.Http.Status
  contentType : String := "text/plain; charset=utf-8"
  body : String := ""
  headers : List (String × String) := []

def csp : String :=
  "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; " ++
  "connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; " ++
  "require-trusted-types-for 'script'; trusted-types 'none'"

/-- Headers every response carries. -/
def fixedHeaders : List (String × String) :=
  [("Content-Security-Policy", csp), ("X-Content-Type-Options", "nosniff"),
   ("X-Frame-Options", "DENY"), ("Referrer-Policy", "no-referrer"),
   ("Cross-Origin-Opener-Policy", "same-origin"),
   ("Cross-Origin-Resource-Policy", "same-origin"), ("Cache-Control", "no-store")]

/-- The request facts a decision reads. -/
structure Req where
  method : Method
  /-- Percent-encoded path. -/
  path : String
  query : String → Option String
  host : Option String
  cookie : Option String

/-- Equal strings, compared in time independent of where they differ. -/
def sameSecret (a b : String) : Bool :=
  a.utf8ByteSize == b.utf8ByteSize &&
    (a.toUTF8.toList.zip b.toUTF8.toList).foldl (fun acc (x, y) => acc ||| (x ^^^ y)) 0 == 0

/-- The value of cookie `name` in a `Cookie` header. -/
def cookieValue (header name : String) : Option String :=
  (header.splitOn ";").findSome? fun part =>
    match (part.trimAscii.toString).splitOn "=" with
    | [k, v] => if k == name then some v else none
    | _ => none

inductive Action where
  | reply (r : Reply)
  | evaluate (whatif : Option String)

def text (status : Std.Http.Status) (body : String) : Action :=
  .reply { status, body := body ++ "\n" }

/-- Method, host, access + route, decided from the request alone. -/
def decide (cfg : Config) (req : Req) : Action :=
  if req.method != .get then
    .reply { status := .methodNotAllowed, body := "Only GET is served.\n",
             headers := [("Allow", "GET")] }
  else if !(req.host.any cfg.hosts.contains) then
    text .misdirectedRequest "This server answers its own address only."
  else
    let cookieOk := (req.cookie.bind (cookieValue · (cookieName cfg))).any (sameSecret · cfg.token)
    let tokenOk := (req.query "token").any (sameSecret · cfg.token)
    if req.path == "/" && tokenOk then
      .reply { status := .seeOther, headers := [("Location", "/"),
        ("Set-Cookie", s!"{cookieName cfg}={cfg.token}; Path=/; HttpOnly; SameSite=Strict")] }
    else if !cookieOk then
      text .forbidden "Open the link that fvtrace serve printed."
    else if req.path == "/api/evaluation" then .evaluate (req.query "whatif")
    else
      match FvtraceWeb.files.find? (·.1 == req.path) with
      | some (_, contentType, body) => .reply { status := .ok, contentType, body }
      | none => text .notFound "Not found."

def json (status : Std.Http.Status) (v : Value) : Reply :=
  { status, contentType := "application/json", body := v.pretty }

def problemJson (status : Std.Http.Status) (kind message : String) : Reply :=
  json status (.obj [("problem", .obj [("kind", .str kind), ("message", .str message)])])

/-- The evaluation route: the envelope, or the problem in the GUI's words. -/
def evaluation (cfg : Config) (cache : IO.Ref Receipt.Cache) (whatif : Option String) :
    IO Reply := do
  let r ← Session.load cfg.target cfg.explicit whatif false cache
  Session.closeCache cfg.target cache
  return match r with
  | .ok l => json .ok (Session.envelope l)
  | .error (.noTrace p) =>
    problemJson .conflict "no-trace" s!"No trace for the project {p} yet. Run fvtrace init."
  | .error (.unreadable f why) => problemJson .conflict "unreadable" s!"Cannot read {f}: {why}"
  | .error (.undecodable f _) =>
    problemJson .conflict "invalid" s!"{f} does not decode. Run fvtrace check."
  | .error (.illFormed f _) =>
    problemJson .conflict "invalid" s!"{f} is not well-formed. Run fvtrace check."
  | .error (.badWhatif m) => problemJson .badRequest "what-if" m

def respond (cfg : Config) (cache : IO.Ref Receipt.Cache) (req : Req) : IO Reply := do
  match decide cfg req with
  | .reply r => return r
  | .evaluate w => evaluation cfg cache w

def reqOf (r : Request Body.Stream) : Req :=
  let header := fun (n : String) => (r.line.headers.get? (Header.Name.ofString! n)).map toString
  { method := r.line.method, path := toString r.line.uri.path,
    query := fun k => r.line.uri.query.get k, host := header "host", cookie := header "cookie" }

def toResponse (r : Reply) : Async (Response Body.Full) := do
  let b := (fixedHeaders ++ [("Content-Type", r.contentType)] ++ r.headers).foldl
    (fun b (k, v) => b.header! k v) (Response.withStatus r.status)
  b.fromBytes r.body.toUTF8

/-- The configuration sits in a reference: the port (hence cookie + hosts) is known only once
bound, and a request before that meets no allowed host. -/
def handler (cfg : IO.Ref Config) (cache : IO.Ref Receipt.Cache) : Server.StatelessHandler :=
  Server.Handler.ofFn fun req => do
    let reply ← (do respond (← cfg.get) cache (reqOf req) : IO Reply)
    let resp ← toResponse reply
    return (resp : Response Body.Any)

def httpConfig : Std.Http.Config :=
  { maxConnections := 64, serverName := some (.mk "fvtrace") }

/-- Binds `addr` (port 0 = any free port) and serves in the background; returns the bound
port. -/
def start (cfg : IO.Ref Config) (addr : Net.SocketAddress) (cache : IO.Ref Receipt.Cache) :
    IO UInt16 := do
  let server ← Async.block (Std.Http.Server.serve addr (handler cfg cache) httpConfig)
  return match server.localAddr with
    | some (.v4 a) => a.port
    | some (.v6 a) => a.port
    | none => 0

end Fvtrace.Server
