// Runs the built `fvtrace serve` for one test: a temporary data folder + project folder holding
// the synthetic study (pinned), a free port, and the token link the server prints.
import { spawn, spawnSync } from "node:child_process";
import { copyFile, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const root = join(import.meta.dirname, "..", "..");
const bin = join(root, ".lake", "build", "bin", "fvtrace");

/**
 * @param {string[]} args
 * @param {string} cwd
 * @param {NodeJS.ProcessEnv} env
 * @returns {string}
 */
function fvtrace(args, cwd, env) {
  const run = spawnSync(bin, args, { cwd, env, encoding: "utf8" });
  if (run.status !== 0) throw new Error(`fvtrace ${args.join(" ")}: ${run.stderr}`);
  return run.stdout.trim();
}

/** @returns {Promise<{ url: string, base: string, close: () => Promise<void> }>} */
export async function serveFvtrace() {
  const dir = await mkdtemp(join(tmpdir(), "fvtrace-e2e-"));
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
  const server = spawn(bin, ["serve", "--port", "0"], { cwd: project, env });
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
    close: async () => {
      server.kill();
      await rm(dir, { recursive: true, force: true });
    },
  };
}
