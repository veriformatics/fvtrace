// ITERATE prototype of the GUI: serves prototype/gui/web/ (a working copy of web/) and proxies
// /api/evaluation to a real `fvtrace serve` it starts, so every verdict still comes from the engine.
// Usage: node prototype/gui/serve.mjs [fvtrace serve args, e.g. --trace T --project P]
// Loopback only, no token: a throwaway viewer for ITERATE rounds, never shipped.
import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, join } from "node:path";

const root = join(import.meta.dirname, "..", "..");
const web = join(import.meta.dirname, "web");
const csp =
  "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; " +
  "base-uri 'none'; form-action 'none'; frame-ancestors 'none'; " +
  "require-trusted-types-for 'script'; trusted-types 'none'";
// Stub: per-fact "why it is needed" text the trace format lacks yet, merged into the envelope.
const why = JSON.parse(await readFile(join(import.meta.dirname, "why.json"), "utf8"));
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

const up = spawn(
  join(root, ".lake/build/bin/fvtrace"),
  ["serve", "--port", "0", ...process.argv.slice(2)],
  {
    stdio: ["ignore", "pipe", "inherit"],
  },
);
process.on("exit", () => up.kill());
for (const s of ["SIGINT", "SIGTERM"]) process.on(s, () => process.exit(0));
const link = await new Promise((resolve, reject) => {
  let out = "";
  up.stdout.on("data", (c) => {
    out += c;
    const m = /^Open (http:\/\/\S+)$/m.exec(out);
    if (m) resolve(m[1]);
  });
  up.on("exit", (code) => reject(new Error(`fvtrace serve exited ${code}`)));
});
const origin = new URL(link).origin;
const cookie = (await fetch(link, { redirect: "manual" })).headers.get("set-cookie").split(";")[0];

createServer(async (req, res) => {
  const url = new URL(req.url, "http://x");
  const head = { "Content-Security-Policy": csp, "Cache-Control": "no-store" };
  if (url.pathname === "/api/evaluation") {
    const r = await fetch(origin + url.pathname + url.search, { headers: { cookie } });
    res.writeHead(r.status, { ...head, "Content-Type": "application/json" });
    const body = await r.json();
    for (const f of body.facts ?? []) if (why[f.id]) f.why = why[f.id];
    res.end(JSON.stringify(body));
    return;
  }
  const name = url.pathname === "/" ? "index.html" : url.pathname.slice(1);
  if (!(name in { "index.html": 1 }) && !/^[a-z]+\.(js|css)$/.test(name))
    return res.writeHead(404).end();
  try {
    const body = await readFile(join(web, name));
    res.writeHead(200, { ...head, "Content-Type": types[extname(name)] }).end(body);
  } catch {
    res.writeHead(404).end();
  }
}).listen(Number(process.env.PORT ?? 0), "127.0.0.1", function () {
  console.log(`Open http://127.0.0.1:${this.address().port}/`);
});
