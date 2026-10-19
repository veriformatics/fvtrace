// Serves web/ for the GUI stub until `fvtrace serve` exists (U7 replaces this fixture).
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";

const root = join(import.meta.dirname, "..", "..", "web");
/** @type {Record<string, string>} */
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

/**
 * @param {string | undefined} url
 * @param {import("node:http").ServerResponse} res
 */
async function respond(url, res) {
  const path = normalize(new URL(url ?? "/", "http://x").pathname).replace(/^\/+/, "");
  const file = path === "" ? "index.html" : path;
  try {
    const body = await readFile(join(root, file));
    res.writeHead(200, { "Content-Type": types[extname(file)] ?? "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404).end();
  }
}

/** @returns {Promise<{ url: string, close: () => Promise<void> }>} */
export async function serveWeb() {
  const server = createServer((req, res) => {
    void respond(req.url, res);
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(undefined)));
  const address = server.address();
  if (address === null || typeof address === "string") throw new Error("no TCP address");
  return {
    url: `http://127.0.0.1:${address.port}/`,
    close: () => new Promise((resolve) => server.close(() => resolve())),
  };
}
