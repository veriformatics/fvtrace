---
paths:
  - "Fvtrace/Server.lean"
  - "Fvtrace/Session.lean"
  - "FvtraceWeb.lean"
  - "web/**"
  - "tests/e2e/**"
---

# Server (`fvtrace serve`)

- Routes = the embedded GUI files (`FvtraceWeb.files`, byte-equal to `web/`, every `web/*.{html,js,css}` listed — `Tests/Assets.lean`) + `GET /api/evaluation[?whatif=…]` (the engine's envelope, or `{problem: {kind, message}}`). No route serves project files: evidence reaches the GUI as receipts inside the envelope; a file-reading route would turn a token leak into a project-folder leak.
- Access, decided by the pure `Server.decide` before any I/O: GET only (405); `Host` ∈ the bound address + `localhost` for loopback (421: DNS rebinding); the per-run token in `/?token=` trades for an `HttpOnly; SameSite=Strict` cookie named per port (cookies ignore ports, so two servers would overwrite one name); compare secrets with `sameSecret` (length + byte-xor fold, no early exit). `--host` takes one concrete address (a wildcard has no single `Host` name to allow).
- Every response carries `fixedHeaders`: CSP `default-src 'none'` + `'self'` scripts/styles/connect, `frame-ancestors 'none'`, `require-trusted-types-for 'script'; trusted-types 'none'` (HTML-string sinks throw), `nosniff`, `no-referrer`, COOP/CORP same-origin, `no-store`.
- The port (so cookie + hosts) is known only after binding (`--port 0`), so `Server.Config` sits in an `IO.Ref` filled after `Server.start`; a request before that meets an empty host list.
- e2e (`tests/e2e/fvtrace-server.js`) runs the built binary: temp `FVTRACE_HOME` + project with the synthetic study pinned, `serve --port 0`, the printed link. `lean-build` must precede `e2e`.
