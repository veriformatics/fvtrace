import { test, expect } from "@playwright/test";
import { AxeBuilder } from "@axe-core/playwright";
import { spawnSync } from "node:child_process";
import { copyFile, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const root = join(import.meta.dirname, "..", "..");
const bin = join(root, ".lake", "build", "bin", "fvtrace");

/**
 * @param {string[]} args @param {string} cwd @param {NodeJS.ProcessEnv} env
 * @returns {string}
 */
function fvtrace(args, cwd, env) {
  const run = spawnSync(bin, args, { cwd, env, encoding: "utf8" });
  if (run.status !== 0) throw new Error(`fvtrace ${args.join(" ")}: ${run.stderr}`);
  return run.stdout.trim();
}

/** @type {{ dir: string, page: string }} */
let fixture;

test.beforeAll(async () => {
  const dir = await mkdtemp(join(tmpdir(), "fvtrace-export-"));
  const project = join(dir, "proj");
  await mkdir(join(project, "proofs"), { recursive: true });
  await writeFile(
    join(project, "proofs", "Contrast.lean"),
    "theorem contrast_correct : True := trivial\n",
  );
  const env = { ...process.env, FVTRACE_HOME: join(dir, "home") };
  fvtrace(["init"], project, env);
  await copyFile(
    join(root, "tests", "fixtures", "synthetic.trace.json"),
    fvtrace(["path"], project, env),
  );
  fvtrace(["pin"], project, env);
  const page = join(dir, "claims.html");
  fvtrace(["export", "--html", page], project, env);
  fixture = { dir, page };
});

test.afterAll(async () => {
  await rm(fixture.dir, { recursive: true, force: true });
});

test("the exported page works offline under its own CSP", async ({ page }) => {
  /** @type {string[]} */
  const errors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") errors.push(msg.text());
  });
  page.on("pageerror", (err) => errors.push(err.message));
  await page.goto(pathToFileURL(fixture.page).href);
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("Synthetic study");
  await expect(page.getByText("This page was exported: each what-if applies alone.")).toBeVisible();
  const c2 = page.locator("article.circuit").filter({ hasText: "C2 /" });
  await expect(c2.locator(".claim-state")).toHaveText("Not yet (draft)");
  await c2.getByRole("button", { name: "Suppose EN2 proved" }).click();
  await expect(page.getByRole("status")).toContainText("What-if: EN2 proved");
  await expect(
    c2.getByRole("button", { name: "Restore the recorded status of EN2" }),
  ).toBeVisible();
  await c2.getByRole("button", { name: "Suppose O2 checked" }).click();
  await expect(page.getByRole("status")).toContainText("What-if: O2 checked");
  await expect(page.getByRole("status")).not.toContainText("EN2");
  expect(new URL(page.url()).hash).toContain("action=suppose%3AO2");
  await page.getByRole("button", { name: "Restore the recorded evidence" }).click();
  await expect(page.getByRole("status")).toHaveText("Recorded evidence.");
  const axe = await new AxeBuilder({ page }).analyze();
  expect(axe.violations.map((v) => v.id)).toEqual([]);
  expect(errors).toEqual([]);
});
