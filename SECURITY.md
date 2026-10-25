# Security policy

## Report a vulnerability

Report a vulnerability privately. Do not open a public issue for it.

1. On the page of this repository, click the **Security and quality** tab.
2. Click **Report a vulnerability**.
3. Write the version that you used, what happens, and the steps that show it.

## Supported versions

Security fixes go to the newest version on the `main` branch.

## Scope

These parts of fvTrace read data that can come from other people:

- `fvtrace serve`: the web server and the secret token that its link carries. With `--host`,
  other computers on your network can reach it. The page asks for answers with requests that
  carry the token; the server reads a request's body only after it accepts the token, and it
  refuses a body larger than 16 MiB and 1 KiB.
- The page that `fvtrace export --html` writes and the folder that `fvtrace export --bundle`
  writes. The page runs the fvTrace engine, compiled to WebAssembly, in the browser, in a
  background worker that the page makes from its own copy of the engine's code. Its content
  security policy allows only the page's own script and style, the compilation of WebAssembly,
  and that one worker: one Trusted Types policy accepts the address of the page's own worker
  and refuses every other. The page loads nothing from the network. A link to the page can carry a what-if;
  the engine reads it as text.
- Trace files and the evidence files that they name.
- The build: `lake build` downloads Emscripten and the Lean runtime sources, and refuses each
  download whose SHA-256 digest differs from the one in `tools/wasm.lock`.

A replay command runs only when you add `--run` or `--replay`, and it runs with your rights. Read
the commands with `fvtrace verify` before you use `--run` or `--replay` on a trace from someone
else.
