# MAIN — baseline + own findings (security items worked alone)

| id | row | sev | `file:line` | finding | proof | status |
|---|---|---|---|---|---|---|
| M-1 | B1 | minor | `tests/e2e/access.spec.js:44` | code scanning alert #1 `js/remote-property-injection` open since 2026-10-23: `seen[k] = v` over request query keys (a `__proto__` key writes the prototype); B1 asks code scanning green | `gh api repos/{owner}/{repo}/code-scanning/alerts?state=open` → `1 js/remote-property-injection warning tests/e2e/access.spec.js:44` | open |
| M-2 | B7 | minor | `tools/mutate.mjs:12` | `node tools/mutate.mjs --help` throws `ERR_PARSE_ARGS_UNKNOWN_OPTION` with a stack trace (no usage line, rc 1) | `node tools/mutate.mjs --help` → `TypeError [ERR_PARSE_ARGS_UNKNOWN_OPTION]: Unknown option '--help'` | open |

Security pointers from reviewers (MAIN alone): reviewer-3 → `Fvtrace/Check.lean:17` (`Artifact.pathSafe`).

## Security pointers (MAIN alone)

| pointer | from | ruling |
|---|---|---|
| `c/fvtrace_digest.c:19-24` lazy `sha256_class` registration, unsynchronized | reviewer-9, reviewer-10 | retired: no concurrent first call — every command resolves its target first (`Store.lean:56` hashes the project path; `serve`: `Cli.lean:1029` before `Server.start`), single-threaded |
| `Fvtrace/Session.lean:65` metadata check then open (TOCTOU) | reviewer-12 | retired: prior security ruling (C-PATH, F3) holds — a swap needs write access to the trace's folder (that writer already controls the trace); the read stays bounded at limit + 1 |
| `Fvtrace/Check.lean:17` `Artifact.pathSafe` (drive letters, `:`, reserved names) | reviewer-3, reviewer-4 | retired: prior security ruling (C-PATH) holds — reads resolve real paths under the project (component prefix + regular file); bundle writes stay under the empty destination; no new evidence |
| `Fvtrace/Cli.lean:116` `replaceFile` temporary name | reviewer-13 | retired: the sibling is removed, then created `O_EXCL` (`.writeNew`); a link re-planted in between makes the create fail, nothing is written through |
| `Fvtrace/Export.lean:162` `licensesHtml` | reviewer-20 | retired: titles + texts pass `htmlText`; the texts come from the build's own toolchain + Emscripten trees (trusted base) |
| `web/engine.js:46` engine block decode | reviewer-20 | retired: `export` writes the block base64-checked (security review S.2); a page's author controls its own page (kernel.md E-sec) |
| `web/worker.js:26` `onmessage` without origin check | reviewer-20 | retired: a dedicated Worker receives messages only from the page that made it |
