import Std.Http
import FvtraceWeb
import Fvtrace.Session

/-!
# `fvtrace serve`: the GUI over local HTTP

Serves the embedded GUI and one JSON route, the evaluation envelope (under a what-if). The GUI
displays it and computes no verdict. The server reads the project and writes nothing but its own
digest cache.

Access: every request must use GET and name an allowed `Host` (a page on another site that rebinds
its DNS name to this address is refused). The GUI files, open source, answer anyone who passes
that; the claims (`/api/evaluation`) answer only a request carrying the run's random token as
`Authorization: Bearer`. The page keeps the token in its own origin's storage: no cookie, since
cookies ignore ports and would reach every server on the host. Responses forbid framing, sniffing,
inline script and HTML-string DOM sinks (Trusted Types).
-/

namespace Fvtrace.Server
open Std Std.Async Std.Http Fvtrace.Json

structure Config where
  target : Store.Target
  /-- The user named the trace file (`--trace`). -/
  explicit : Bool
  token : String
  /-- `Host` header values the server answers. -/
  hosts : List String
  /-- Reuse an evidence digest while the file keeps its size + mtime (`serve --cached`). -/
  cached : Bool := false

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
  authorization : Option String

/-- Equal strings, compared in time independent of where they differ. -/
def sameSecret (a b : String) : Bool :=
  a.utf8ByteSize == b.utf8ByteSize &&
    (a.toUTF8.toList.zip b.toUTF8.toList).foldl (fun acc (x, y) => acc ||| (x ^^^ y)) 0 == 0

/-- The token of an `Authorization: Bearer <token>` header. -/
def bearer (header : String) : Option String :=
  if header.startsWith "Bearer " then some (header.drop 7).toString else none

inductive Action where
  | reply (r : Reply)
  | evaluate (whatif : Option String)

def text (status : Std.Http.Status) (body : String) : Action :=
  .reply { status, body := body ++ "\n" }

def json (status : Std.Http.Status) (v : Value) : Reply :=
  { status, contentType := "application/json", body := v.pretty }

def problemJson (status : Std.Http.Status) (kind message : String) : Reply :=
  json status (.obj [("problem", .obj [("kind", .str kind), ("message", .str message)])])

/-- Method, host, route + access, decided from the request alone: no request without the token
reaches `Overrides.parse` or the trace. -/
def decide (cfg : Config) (req : Req) : Action :=
  if req.method != .get then
    .reply { status := .methodNotAllowed, body := "Only GET is served.\n",
             headers := [("Allow", "GET")] }
  else if !(req.host.any cfg.hosts.contains) then
    text .misdirectedRequest "This server answers its own address only."
  else if req.path == "/api/evaluation" then
    if (req.authorization.bind bearer).any (sameSecret · cfg.token) then
      .evaluate (req.query "whatif")
    else
      .reply (problemJson .forbidden "access" ("This page has no access to the claims. Use the " ++
        "link that fvtrace serve prints, or run fvtrace serve again."))
  else
    match FvtraceWeb.files.find? (·.1 == req.path) with
    | some (_, contentType, body) => .reply { status := .ok, contentType, body }
    | none => text .notFound "Not found."

/-- The evaluation route: the envelope, or the problem in the GUI's words. -/
def evaluation (cfg : Config) (cache : IO.Ref Receipt.Cache) (whatif : Option String) :
    IO Reply := do
  let r ← Session.load cfg.target cfg.explicit whatif (!cfg.cached) cache
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
  | .evaluate w =>
    try evaluation cfg cache w
    catch e =>
      return problemJson .internalServerError "io" s!"fvtrace could not read the project: \
        {(toString e).replace "\n" " "}"

def reqOf (r : Request Body.Stream) : Req :=
  let header := fun (n : String) => (r.line.headers.get? (Header.Name.ofString! n)).map toString
  { method := r.line.method, path := toString r.line.uri.path,
    query := fun k => r.line.uri.query.get k, host := header "host",
    authorization := header "authorization" }

def toResponse (r : Reply) : Async (Response Body.Full) := do
  let b := (fixedHeaders ++ [("Content-Type", r.contentType)] ++ r.headers).foldl
    (fun b (k, v) => b.header! k v) (Response.withStatus r.status)
  b.fromBytes r.body.toUTF8

/-- The configuration sits in a reference: the port (hence the hosts) is known only once bound,
and a request before that meets no allowed host. -/
def handler (cfg : IO.Ref Config) (cache : IO.Ref Receipt.Cache) : Server.StatelessHandler :=
  Server.Handler.ofFn fun req => do
    let reply ← (do respond (← cfg.get) cache (reqOf req) : IO Reply)
    let resp ← toResponse reply
    return (resp : Response Body.Any)

def httpConfig : Std.Http.Config :=
  { maxConnections := 64, serverName := some (.mk "fvtrace") }

/-- Binds `addr` (port 0 = any free port) and serves in the background; returns the server + the
bound port. -/
def start (cfg : IO.Ref Config) (addr : Net.SocketAddress) (cache : IO.Ref Receipt.Cache) :
    IO (Std.Http.Server × UInt16) := do
  let server ← Async.block (Std.Http.Server.serve addr (handler cfg cache) httpConfig)
  return (server, match server.localAddr with
    | some (.v4 a) => a.port
    | some (.v6 a) => a.port
    | none => 0)

def stop (server : Std.Http.Server) : IO Unit := Async.block server.shutdownAndWait

end Fvtrace.Server
