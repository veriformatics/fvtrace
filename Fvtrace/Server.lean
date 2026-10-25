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
that; the claims (`POST /api/answer`) answer only a request carrying the run's random token as
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

/-- What the server keeps between requests (`kernel.md` P-cache): the last checked trace, by the
SHA-256 of its bytes, and the last answer's answers + its envelope text once printed, by its view
(`Session.viewOf`: the trace's content + review, the bindings with their reasons, the what-if).
Answers read from it equal fresh ones, byte for byte; the launch evaluation's text answers the
page's first request. -/
structure Kept where
  trace : Option (String × Trace) := none
  last : Option (String × Answers × Option String) := none

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
  /-- `X-Fvtrace-View`: the view the page shows (`kernel.md` V-serve). -/
  view : Option String := none

/-- Equal strings, compared in time independent of where they differ. -/
def sameSecret (a b : String) : Bool :=
  a.utf8ByteSize == b.utf8ByteSize &&
    (a.toUTF8.toList.zip b.toUTF8.toList).foldl (fun acc (x, y) => acc ||| (x ^^^ y)) 0 == 0

/-- The token of an `Authorization: Bearer <token>` header. -/
def bearer (header : String) : Option String :=
  if header.startsWith "Bearer " then some (header.drop 7).toString else none

inductive Action where
  | reply (r : Reply)
  /-- `POST /api/answer`: its body (a request) is read only now, after access passed. -/
  | answer (view : Option String)

/-- The largest request body: a what-if naming every fact of the largest trace fits. -/
def bodyCap : Nat := maxTraceBytes + 1024

def text (status : Std.Http.Status) (body : String) : Action :=
  .reply { status, body := body ++ "\n" }

def json (status : Std.Http.Status) (v : Value) : Reply :=
  { status, contentType := "application/json", body := v.pretty }

def problemJson (status : Std.Http.Status) (kind message : String) : Reply :=
  json status (.obj [("problem", .obj [("kind", .str kind), ("message", .str message)])])

/-- Method, host, route + access, decided from the request alone: no request without the token
reaches `Overrides.parse` or the trace. -/
def decide (cfg : Config) (req : Req) : Action :=
  let api := req.path == "/api/answer"
  if req.method != (if api then .post else .get) then
    let only := if api then "POST" else "GET"
    .reply { status := .methodNotAllowed, body := s!"Only {only} is served.\n",
             headers := [("Allow", only)] }
  else if !(req.host.any cfg.hosts.contains) then
    text .misdirectedRequest "This server answers its own address only."
  else if api then
    if (req.authorization.bind bearer).any (sameSecret · cfg.token) then .answer req.view
    else
      .reply (problemJson .forbidden "access" ("This page has no access to the claims. Use the " ++
        "link that fvtrace serve prints, or run fvtrace serve again."))
  else
    match FvtraceWeb.files.find? (·.1 == req.path) with
    | some (_, contentType, body) => .reply { status := .ok, contentType, body }
    | none => text .notFound "Not found."

/-- A problem in the GUI's words. -/
def problemReply : Session.Problem → Reply
  | .noTrace p =>
    problemJson .conflict "no-trace" s!"No trace for the project {p} yet. Run fvtrace init."
  | .unreadable f why => problemJson .conflict "unreadable" s!"Cannot read {f}: {why}"
  | .undecodable f _ => problemJson .conflict "invalid" s!"{f} does not decode. Run fvtrace check."
  | .illFormed f _ =>
    problemJson .conflict "invalid" s!"{f} is not well-formed. Run fvtrace check."
  | .badWhatif m => problemJson .badRequest "what-if" m
  | .badAction m => problemJson .badRequest "action" m
  | .badItem m => problemJson .badRequest "item" m

/-- `POST /api/answer` (`kernel.md` V-serve, V-request): the envelope at the action's what-if, the
details of an item there, or a problem; the view the answer reads travels in `X-Fvtrace-View`, and
a request naming another view gets 409 (the files changed since the page's answer). -/
def answer (cfg : Config) (cache : IO.Ref Receipt.Cache) (kept : Std.Mutex Kept)
    (view : Option String) (body : String) : IO Reply := kept.atomically do
  match Request.parse body with
  | .error m => return problemJson .badRequest "invalid" m
  | .ok r =>
    let raw ← Session.readRawWithin maxTraceBytes cfg.target cfg.explicit
    let bytes ← match raw with
      | .ok (.ok b) => pure b
      | .ok (.error ds) => set ({} : Kept); return problemReply (.undecodable cfg.target.trace ds)
      | .error p => set ({} : Kept); return problemReply p
    let key ← Digest.ofBytes bytes
    let st ← get
    let fresh := fun _ : Unit => Session.checked cfg.target (decodeTraceWithin maxTraceBytes bytes)
    let tr ← match st.trace with
      | some (k, tr) => if k == key then pure tr else match fresh () with
        | .ok tr => pure tr
        | .error p => set ({} : Kept); return problemReply p
      | none => match fresh () with
        | .ok tr => pure tr
        | .error p => set ({} : Kept); return problemReply p
    set { st with trace := some (key, tr) }
    let loaded ← Session.bindChecked cfg.target tr (some r.whatif) (!cfg.cached) cache
    Session.closeCache cfg.target cache
    let l ← match loaded with
      | .ok l => pure l
      | .error p => return problemReply p
    -- The answers at a view: the kept ones when it is the last answer's view.
    let answersAt := fun (l : Session.Loaded) (v : String) => match st.last with
      | some (v', A, _) => if v' == v then A else Answers.fast l.scenario
      | none => Answers.fast l.scenario
    let v0 ← Session.viewOf l
    let l' ← match r.action with
      | some a => match Evaluate.expandWith tr (answersAt l v0) a with
        | .ok o => pure { l with scenario := { l.scenario with overrides := o } }
        | .error m => return problemReply (.badAction m)
      | none => pure l
    let v ← Session.viewOf l'
    let A := answersAt l' v
    let text := match st.last with
      | some (v', _, t) => if v' == v then t else none
      | none => none
    set { st with trace := some (key, tr), last := some (v, A, text) }
    let tagged := fun (rep : Reply) =>
      { rep with headers := rep.headers ++ [("X-Fvtrace-View", v)] }
    if view.any (· != v) then
      return tagged (problemJson .conflict "view"
        "The claims or their evidence changed, so this page shows them again.")
    match r.details with
    | some item => return match Evaluate.detailsWith l'.scenario A l'.digest l'.review item with
      | .ok d => tagged (json .ok d)
      | .error m => problemReply (.badItem m)
    | none =>
      let body := text.getD
        (Evaluate.envelopeWith l'.scenario A l'.bindings l'.digest l'.review).pretty
      set { st with trace := some (key, tr), last := some (v, A, some body) }
      return tagged { status := .ok, contentType := "application/json", body }

/-- A read request body (none = past `bodyCap`): its answer, an I/O failure as a problem. -/
def answerBody (cfg : Config) (cache : IO.Ref Receipt.Cache) (kept : Std.Mutex Kept)
    (view : Option String) (body : Option ByteArray) : IO Reply := do
  let some b := body
    | return problemJson .payloadTooLarge "invalid"
        "The request is larger than any what-if on the largest trace."
  let some text := String.fromUTF8? b | return problemJson .badRequest "invalid" Request.malformed
  try answer cfg cache kept view text
  catch e =>
    return problemJson .internalServerError "io" s!"fvtrace could not read the project: \
      {(toString e).replace "\n" " "}"

def reqOf (r : Std.Http.Request Body.Stream) : Req :=
  let header := fun (n : String) => (r.line.headers.get? (Header.Name.ofString! n)).map toString
  { method := r.line.method, path := toString r.line.uri.path,
    query := fun k => r.line.uri.query.get k, host := header "host",
    authorization := header "authorization", view := header "x-fvtrace-view" }

def toResponse (r : Reply) : Async (Response Body.Full) := do
  let b := (fixedHeaders ++ [("Content-Type", r.contentType)] ++ r.headers).foldl
    (fun b (k, v) => b.header! k v) (Response.withStatus r.status)
  b.fromBytes r.body.toUTF8

/-- The configuration sits in a reference: the port (hence the hosts) is known only once bound,
and a request before that meets no allowed host. -/
def handler (cfg : IO.Ref Config) (cache : IO.Ref Receipt.Cache) (kept : Std.Mutex Kept) :
    Server.StatelessHandler :=
  Server.Handler.ofFn fun req => do
    let c ← cfg.get
    let reply ← match decide c (reqOf req) with
      | .answer view => do
        let body ← try
            some <$> (Body.Stream.readAll (α := ByteArray) req.body (some bodyCap.toUInt64))
          catch _ => pure none
        (answerBody c cache kept view body : IO Reply)
      | .reply r => pure r
    let resp ← toResponse reply
    return (resp : Response Body.Any)

def httpConfig : Std.Http.Config :=
  { maxConnections := 64, serverName := some (.mk "fvtrace"), maxBodySize := bodyCap }

/-- Binds `addr` (port 0 = any free port) and serves in the background; returns the server + the
bound port. -/
def start (cfg : IO.Ref Config) (addr : Net.SocketAddress) (cache : IO.Ref Receipt.Cache)
    (kept : Std.Mutex Kept) :
    IO (Std.Http.Server × UInt16) := do
  let server ← Async.block (Std.Http.Server.serve addr (handler cfg cache kept) httpConfig)
  return (server, match server.localAddr with
    | some (.v4 a) => a.port
    | some (.v6 a) => a.port
    | none => 0)

def stop (server : Std.Http.Server) : IO Unit := Async.block server.shutdownAndWait

end Fvtrace.Server
