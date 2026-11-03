// fvtrace serve behind a login proxy (`--token-file`): the proxy asks for its own login (HTTP
// Basic), serves the GUI under a path and adds the token to each request it passes on. The page
// holds no token, so it sends no `Authorization` header and the browser's login reaches the proxy;
// a token from the address that the proxy refuses (401) is not kept, a stored one is forgotten.
import http from "node:http";
import { randomBytes } from "node:crypto";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { test, expect } from "@playwright/test";
import { serveFvtrace } from "./fvtrace-server.js";

const login = { username: "reader", password: randomBytes(16).toString("hex") };
const basic = `Basic ${Buffer.from(`${login.username}:${login.password}`).toString("base64")}`;

/**
 * A login proxy in front of the fvtrace server at `upstream` (Basic login, the GUI under
 * `/fvtrace/`, the token added); `seen` = the `Authorization` scheme of each data request that
 * reached it (`none` = no header).
 * @param {string} upstream @param {string} token
 */
async function loginProxy(upstream, token) {
  const port = new URL(upstream).port;
  /** @type {string[]} */
  const seen = [];
  const server = http.createServer((req, res) => {
    const path = req.url ?? "/";
    if (path.endsWith("/api/answer"))
      seen.push((req.headers.authorization ?? "none").split(" ")[0] ?? "");
    if (req.headers.authorization !== basic) {
      res.writeHead(401, { "WWW-Authenticate": 'Basic realm="fvtrace test"' }).end();
      return;
    }
    if (!path.startsWith("/fvtrace/")) {
      res.writeHead(404).end();
      return;
    }
    const up = http.request(
      {
        host: "127.0.0.1",
        port,
        method: req.method,
        path: path.slice("/fvtrace".length),
        headers: { ...req.headers, host: `127.0.0.1:${port}`, authorization: `Bearer ${token}` },
      },
      (answer) => {
        res.writeHead(answer.statusCode ?? 502, answer.headers);
        answer.pipe(res);
      },
    );
    up.on("error", () => res.writeHead(502).end());
    req.pipe(up);
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", () => resolve(undefined)));
  const address = server.address();
  const own = typeof address === "object" && address ? address.port : 0;
  return { url: `http://127.0.0.1:${own}/fvtrace/`, seen, close: () => server.close() };
}

/** The board, or the page's error in its place (so a failure names the error, not a timeout).
 * @param {import("@playwright/test").Page} page */
async function shown(page) {
  const board = page.locator("article.circuit").first();
  await board.or(page.getByRole("alert")).waitFor();
  await expect(page.getByRole("alert")).toBeHidden();
  await expect(board).toBeVisible();
}

test("behind a login proxy, the page needs the proxy's login alone", async ({ browser }) => {
  const token = randomBytes(32).toString("hex");
  const web = await serveFvtrace("synthetic", undefined, async (dir) => {
    const file = join(dir, "token");
    await writeFile(file, `${token}\n`, { mode: 0o600 });
    return ["--token-file", file];
  });
  const proxy = await loginProxy(web.base, token);
  const context = await browser.newContext({ httpCredentials: login });
  try {
    const page = await context.newPage();
    await page.goto(proxy.url);
    await shown(page);
    await expect(page.locator("#scenario-text")).toContainText("Showing the facts as recorded.");
    expect(proxy.seen).toContain("Basic");
    expect(proxy.seen).not.toContain("Bearer");
    expect(await page.evaluate(() => localStorage.getItem("fvtrace-token"))).toBeNull();

    // A token in the address replaces the login on its request, so the proxy refuses it (401):
    // the page asks again without it and keeps no token.
    proxy.seen.length = 0;
    const linked = await context.newPage();
    await linked.goto(`${proxy.url}#token=${"0".repeat(64)}`);
    await shown(linked);
    expect(proxy.seen[0]).toBe("Bearer");
    expect(proxy.seen).toContain("Basic");
    expect(await linked.evaluate(() => localStorage.getItem("fvtrace-token"))).toBeNull();
    expect(new URL(linked.url()).hash).not.toContain("token");

    // A stored token (an earlier direct run on this origin) also replaces the login: refused, it
    // is forgotten, and the page asks again without it.
    await linked.evaluate(() => localStorage.setItem("fvtrace-token", "1".repeat(64)));
    proxy.seen.length = 0;
    await linked.reload();
    await shown(linked);
    expect(proxy.seen[0]).toBe("Bearer");
    expect(proxy.seen).toContain("Basic");
    expect(await linked.evaluate(() => localStorage.getItem("fvtrace-token"))).toBeNull();
    proxy.seen.length = 0;
    await linked.reload();
    await shown(linked);
    expect(proxy.seen).not.toContain("Bearer");
  } finally {
    await context.close();
    proxy.close();
    await web.close();
  }
});
