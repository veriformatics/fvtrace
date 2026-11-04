// Runs the built `fvtrace serve` for one test: a temporary data folder + project folder holding a
// study (pinned), a free port, and the token link the server prints (`--no-browser`: the test opens
// it; the link ends in `#token=…`, so view parameters append with `&`). Studies: `synthetic` = the
// shipped example (examples/synthetic); `fixture` = the feature-rich test trace (exclusions,
// prerequisites, waivers) with the example's proof files.
import { spawnSync } from "node:child_process";
import { rmSync } from "node:fs";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { serve } from "../../tools/serve-link.mjs";

const root = join(import.meta.dirname, "..", "..");
const bin = join(root, ".lake", "build", "bin", "fvtrace");

/** @type {Record<string, string>} */
const traces = {
  synthetic: join(root, "examples", "synthetic", "trace.json"),
  fixture: join(root, "tests", "fixtures", "synthetic.trace.json"),
};

/**
 * Servers + temporary folders made here and not yet closed. A test past its time limit never
 * reaches its own `finally`, so the worker ends them as it exits (an `exit` handler runs
 * synchronously).
 * @type {Set<import("node:child_process").ChildProcess>}
 */
const servers = new Set();
/** @type {Set<string>} */
const folders = new Set();
process.on("exit", () => {
  for (const server of servers) server.kill();
  for (const dir of folders) rmSync(dir, { recursive: true, force: true });
});

/** A new temporary folder, removed when the worker exits at the latest. @param {string} prefix */
async function tempFolder(prefix) {
  const dir = await mkdtemp(join(tmpdir(), prefix));
  folders.add(dir);
  return dir;
}

/** @param {unknown} v @returns {v is Record<string, unknown>} */
export function isRecord(v) {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

/**
 * @param {string[]} args
 * @param {string} cwd
 * @param {NodeJS.ProcessEnv} env
 * @returns {string}
 */
export function fvtrace(args, cwd, env) {
  const run = spawnSync(bin, args, { cwd, env, encoding: "utf8" });
  if (run.status !== 0) throw new Error(`fvtrace ${args.join(" ")}: ${run.stderr}`);
  return run.stdout.trim();
}

/**
 * A temporary project holding `study`, its trace (optionally edited by `edit`) pinned in a
 * temporary data folder.
 * @param {string} study @param {(trace: Record<string, unknown>) => void} [edit]
 * @returns {Promise<{ dir: string, project: string, env: NodeJS.ProcessEnv }>}
 */
export async function prepareStudy(study, edit) {
  const dir = await tempFolder("fvtrace-e2e-");
  const project = join(dir, "proj");
  await mkdir(project, { recursive: true });
  await cp(join(root, "examples", "synthetic", "project", "proofs"), join(project, "proofs"), {
    recursive: true,
  });
  const env = { ...process.env, FVTRACE_HOME: join(dir, "home") };
  fvtrace(["init"], project, env);
  const source = traces[study];
  if (!source) throw new Error(`no study ${study}`);
  /** @type {unknown} */
  const trace = JSON.parse(await readFile(source, "utf8"));
  if (!isRecord(trace)) throw new Error(`${source} is not a JSON object`);
  edit?.(trace);
  await writeFile(fvtrace(["path"], project, env), JSON.stringify(trace, null, 2));
  fvtrace(["pin"], project, env);
  return { dir, project, env };
}

/**
 * `fvtrace serve` with `args` in `cwd` + `env`, once it prints its link (`--token-file`: its
 * address, which carries no token); `close` stops it, waits for its exit and removes `dir`.
 * @param {string[]} args @param {string} cwd @param {NodeJS.ProcessEnv} env @param {string} dir
 * @returns {Promise<{ url: string, close: () => Promise<void> }>}
 */
async function launch(args, cwd, env, dir) {
  const { server, link, stop } = serve(bin, args, { cwd, env });
  servers.add(server);
  server.on("exit", () => servers.delete(server));
  const url = await link;
  return {
    url,
    close: async () => {
      await stop();
      await rm(dir, { recursive: true, force: true });
      folders.delete(dir);
    },
  };
}

/**
 * @param {string} [study] @param {(trace: Record<string, unknown>) => void} [edit]
 * @param {(dir: string) => Promise<string[]>} [extra] more `serve` flags, made in the run's
 *   temporary folder (removed with it)
 * @returns {Promise<{ url: string, base: string, project: string, env: NodeJS.ProcessEnv,
 *   close: () => Promise<void> }>}
 */
export async function serveFvtrace(study = "synthetic", edit, extra) {
  const { dir, project, env } = await prepareStudy(study, edit);
  const run = await launch((await extra?.(dir)) ?? [], project, env, dir);
  return { ...run, base: new URL(run.url).origin, project, env };
}

/**
 * `fvtrace serve` over a generated trace (`tools/scale.mjs <shape> <n>`): its own data folder,
 * the token link it prints.
 * @param {string} shape @param {number} n
 * @returns {Promise<{ url: string, close: () => Promise<void> }>}
 */
export async function serveScale(shape, n) {
  const dir = await tempFolder("fvtrace-e2e-scale-");
  const made = spawnSync("node", [join(root, "tools", "scale.mjs"), shape, String(n), dir], {
    encoding: "utf8",
  });
  if (made.status !== 0) throw new Error(`tools/scale.mjs ${shape} ${n}: ${made.stderr}`);
  return launch(
    ["--trace", join(dir, "trace.json"), "--project", join(dir, "project")],
    dir,
    { ...process.env, FVTRACE_HOME: join(dir, "home") },
    dir,
  );
}
