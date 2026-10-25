// Runs the built `fvtrace serve` for one test: a temporary data folder + project folder holding a
// study (pinned), a free port, and the token link the server prints (`--no-browser`: the test opens
// it; the link ends in `#token=…`, so view parameters append with `&`). Studies: `synthetic` = the
// shipped example (examples/synthetic); `fixture` = the feature-rich test trace (exclusions,
// prerequisites, waivers) with the example's proof files.
import { spawn, spawnSync } from "node:child_process";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = join(import.meta.dirname, "..", "..");
const bin = join(root, ".lake", "build", "bin", "fvtrace");

/** @type {Record<string, string>} */
const traces = {
  synthetic: join(root, "examples", "synthetic", "trace.json"),
  fixture: join(root, "tests", "fixtures", "synthetic.trace.json"),
};

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
  const dir = await mkdtemp(join(tmpdir(), "fvtrace-e2e-"));
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
 * @param {string} [study] @param {(trace: Record<string, unknown>) => void} [edit]
 * @returns {Promise<{ url: string, base: string, project: string, close: () => Promise<void> }>}
 */
export async function serveFvtrace(study = "synthetic", edit) {
  const { dir, project, env } = await prepareStudy(study, edit);
  const server = spawn(bin, ["serve", "--port", "0", "--no-browser"], { cwd: project, env });
  const url = await new Promise(
    /** @param {(link: string) => void} resolve */ (resolve, reject) => {
      let out = "";
      server.stdout.on("data", (/** @type {Buffer} */ chunk) => {
        out += chunk.toString();
        const link = /^Open (http:\/\/\S+)$/m.exec(out);
        if (link?.[1]) resolve(link[1]);
      });
      server.on("exit", (code) => reject(new Error(`fvtrace serve exited ${code}: ${out}`)));
    },
  );
  return {
    url,
    base: new URL(url).origin,
    project,
    close: async () => {
      server.kill();
      await rm(dir, { recursive: true, force: true });
    },
  };
}
