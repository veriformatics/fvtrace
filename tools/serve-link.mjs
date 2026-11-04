// `fvtrace serve` as a child for the e2e harness + the GUI timing driver: started on a free port
// without a browser, its link read from its output, stopped on demand. Signals, browsers + folders
// stay with the callers.
import { spawn } from "node:child_process";
import { once } from "node:events";

/**
 * Starts `bin serve --port 0 --no-browser …args`. `link` = the printed link (`Open <link>`) or, with
 * `--token-file`, the address (`Serving <address> with the token in …`); it rejects when the server
 * exits first or cannot start (watched from the spawn on: an early exit has no later listener).
 * `stop` sends TERM, KILL after `force` ms, and waits for the exit (it may still write until then).
 * @param {string} bin @param {string[]} args
 * @param {{ cwd?: string, env?: NodeJS.ProcessEnv }} options @param {number} [force]
 */
export function serve(bin, args, options, force = 5000) {
  const server = spawn(bin, ["serve", "--port", "0", "--no-browser", ...args], {
    ...options,
    stdio: ["ignore", "pipe", "ignore"],
  });
  let out = "";
  /** @type {Promise<string>} */
  const link = new Promise((resolve, reject) => {
    server.stdout.on("data", (/** @type {Buffer} */ chunk) => {
      out += chunk.toString();
      const m = /^(?:Open (http:\/\/\S+)|Serving (http:\/\/\S+) with the token in .+)$/m.exec(out);
      const found = m?.[1] ?? m?.[2];
      if (found) resolve(found);
    });
    server.on("exit", (code) => reject(new Error(`fvtrace serve exited ${code}: ${out}`)));
    server.on("error", reject);
  });
  link.catch(() => {}); // the caller awaits it; a rejection before that is handled there
  const stop = async () => {
    if (server.pid === undefined || server.exitCode !== null || server.signalCode !== null) return;
    const exited = once(server, "exit");
    server.kill();
    const kill = setTimeout(() => server.kill("SIGKILL"), force);
    await exited;
    clearTimeout(kill);
  };
  return { server, link, stop };
}
