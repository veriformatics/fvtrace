// Mutation credit for Lean code (Lean ships no mutation tool): applies the default operators below
// to one source file, one site at a time, rebuilds, runs the tests, and lists every survivor.
// Usage: node tools/mutate.mjs <file.lean> [--lines A-B[,C-D…]] [--test "<cmd>"] [--timeout <s>] [--list]
// `--list` prints the mutant sites + their count and runs nothing (campaign sizing).
// Outcome per mutant: killed (tests fail) · survived (tests pass) · incompetent (build fails).
// Default operators: == ↔ !=, < ↔ ≤ (<=), > ↔ ≥ (>=), && ↔ ||, true ↔ false, binary + ↔ -,
// removal of a prefix `!` (before a name, `(` or the `·` placeholder), integer literal n → n + 1. Comments, strings + chars are never mutated.
import { execFileSync, spawn } from "node:child_process";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { parseArgs } from "node:util";

const usage =
  "usage: node tools/mutate.mjs <file.lean> [--lines A-B[,C-D…]] [--test CMD] [--build CMD] [--timeout S] [--list] [--help]\n";
const args = () => {
  try {
    return parseArgs({
      allowPositionals: true,
      options: {
        lines: { type: "string" },
        // The interpreter skips the native compile + link of the test binary (about 10× faster).
        test: { type: "string", default: "lake env lean --run TestPure.lean" },
        timeout: { type: "string", default: "120" },
        // The rebuild before each suite run; a stand-in lets the classifier be probed cheaply.
        build: { type: "string", default: "lake build Fvtrace Tests" },
        list: { type: "boolean", default: false },
        help: { type: "boolean", default: false },
      },
    });
  } catch {
    process.stderr.write(usage);
    return process.exit(2);
  }
};
const { values, positionals } = args();
if (values.help) {
  process.stdout.write(usage);
  process.exit(0);
}
const file = positionals[0];
if (!file || positionals.length !== 1) {
  process.stderr.write(usage);
  process.exit(2);
}
// `--lines A-B[,C-D…]`: the line ranges to mutate (default: the whole file).
const ranges = (values.lines ?? "1-999999").split(",").map((r) => {
  const [a = 1, b = a] = r.split("-").map(Number);
  return [a, b];
});
const inRanges = (/** @type {number} */ line) =>
  ranges.some(([a = 1, b = a]) => a <= line && line <= b);
const timeoutMs = Number(values.timeout) * 1000;
const original = readFileSync(file, "utf8");
const backup = `${file}.mutate-backup`;
const restore = () => {
  writeFileSync(file, original);
  rmSync(backup, { force: true });
};
/** @type {import("node:child_process").ChildProcess | undefined} */
let current;
const killCurrent = () => {
  if (current?.pid !== undefined) {
    try {
      process.kill(-current.pid, "SIGKILL");
    } catch {
      // already exited
    }
  }
};

/**
 * Byte ranges of comments, strings + chars, which are never mutated.
 * @param {string} src
 */
function protectedMask(src) {
  const mask = new Uint8Array(src.length);
  let i = 0;
  let depth = 0;
  while (i < src.length) {
    if (depth > 0) {
      if (src.startsWith("/-", i)) {
        depth++;
        mask[i] = mask[i + 1] = 1;
        i += 2;
      } else if (src.startsWith("-/", i)) {
        depth--;
        mask[i] = mask[i + 1] = 1;
        i += 2;
      } else mask[i++] = 1;
    } else if (src.startsWith("/-", i)) {
      depth = 1;
      mask[i] = mask[i + 1] = 1;
      i += 2;
    } else if (src.startsWith("--", i)) {
      while (i < src.length && src[i] !== "\n") mask[i++] = 1;
    } else if (
      src[i] === "r" &&
      (i === 0 || !/[\p{ID_Continue}'.]/u.test(src[i - 1] ?? "")) &&
      /^r#*"/.test(src.slice(i))
    ) {
      const prefix = /^r(#*)"/.exec(src.slice(i));
      const start = i + (prefix?.[0].length ?? 0);
      const terminator = `"${prefix?.[1] ?? ""}`;
      const end = src.indexOf(terminator, start);
      const next = end < 0 ? src.length : end + terminator.length;
      mask.fill(1, i, next);
      i = next;
    } else if (src[i] === '"') {
      mask[i++] = 1;
      while (i < src.length && src[i] !== '"') {
        if (src[i] === "\\") mask[i++] = 1;
        mask[i++] = 1;
      }
      mask[i++] = 1;
    } else if (src[i] === "'" && /^'(\\.[^']*|[^'\\])'/.test(src.slice(i, i + 12))) {
      const m = /^'(\\.[^']*|[^'\\])'/.exec(src.slice(i, i + 12));
      for (let k = 0; k < (m?.[0].length ?? 1); k++) mask[i++] = 1;
    } else i++;
  }
  return mask;
}

/** @type {{ re: RegExp, to: (m: string) => string }[]} */
const operators = [
  { re: /==/g, to: () => "!=" },
  { re: /!=/g, to: () => "==" },
  // `<|` + `|>` are pipes, not comparisons: mutating them only breaks the build.
  { re: /(?<![<=-])<(?![=|-])/g, to: () => "<=" },
  { re: /<=/g, to: () => "<" },
  { re: /≤/g, to: () => "<" },
  { re: /(?<![=|-])>(?![=>])/g, to: () => ">=" },
  { re: />=/g, to: () => ">" },
  { re: /≥/g, to: () => ">" },
  { re: /&&/g, to: () => "||" },
  { re: /\|\|/g, to: () => "&&" },
  { re: /\btrue\b/g, to: () => "false" },
  { re: /\bfalse\b/g, to: () => "true" },
  { re: /(?<= )\+(?= )/g, to: () => "-" },
  { re: /(?<= )-(?= )/g, to: () => "+" },
  { re: /!(?=[A-Za-z(·])/g, to: () => "" },
  { re: /(?<![\w.'])\d+(?![\w.])/g, to: (m) => String(BigInt(m) + 1n) },
];

const mask = protectedMask(original);
const lineStarts = [0];
for (let i = 0; i < original.length; i++) if (original[i] === "\n") lineStarts.push(i + 1);
/** @param {number} pos */
const lineOf = (pos) => {
  let l = 0;
  while (l + 1 < lineStarts.length && (lineStarts[l + 1] ?? Infinity) <= pos) l++;
  return l + 1;
};

/** @type {{ pos: number, len: number, from: string, to: string, line: number }[]} */
const sites = [];
for (const op of operators) {
  for (const m of original.matchAll(op.re)) {
    const pos = m.index;
    const line = lineOf(pos);
    if (mask[pos] || !inRanges(line)) continue;
    // Lean `#[`/`#guard`, arrows and attribute brackets carry no operator semantics.
    const before = original.slice(Math.max(0, pos - 1), pos);
    if (m[0] === "<" && before === "@") continue;
    sites.push({ pos, len: m[0].length, from: m[0], to: op.to(m[0]), line });
  }
}
sites.sort((a, b) => a.pos - b.pos);
if (values.list) {
  for (const s of sites) process.stdout.write(`${file}:${s.line} ${s.from} → ${s.to}\n`);
  process.stdout.write(`mutants: ${sites.length}\n`);
  process.exit(0);
}
// A campaign: a copy on disk + signal handlers restore the target even when it is interrupted.
writeFileSync(backup, original);
// The loop awaits each child, so these handlers run mid-campaign.
for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(signal, () => {
    killCurrent();
    restore();
    process.exit(130);
  });
}

/**
 * Runs `cmd` in its own process group; a timeout kills the whole group (bash → lake → lean).
 * @param {string} cmd
 * @returns {Promise<number>}
 */
const run = (cmd) =>
  new Promise((resolve) => {
    const child = spawn("bash", ["-c", cmd], { stdio: "ignore", detached: true });
    current = child;
    const timer = setTimeout(killCurrent, timeoutMs);
    child.on("exit", (code) => {
      clearTimeout(timer);
      current = undefined;
      resolve(code ?? 1);
    });
  });
// A failing unmutated suite would count every mutant as killed: check the baseline first.
if (
  (await run(`${values.build} >/dev/null 2>&1`)) !== 0 ||
  (await run(`${values.test} >/dev/null 2>&1`)) !== 0
) {
  restore();
  process.stderr.write("mutate: the unmutated build or suite fails; fix it first\n");
  process.exit(2);
}

/** @type {{ killed: number, survived: string[], incompetent: number }} */
const results = { killed: 0, survived: [], incompetent: 0 };
try {
  for (const [n, s] of sites.entries()) {
    writeFileSync(file, original.slice(0, s.pos) + s.to + original.slice(s.pos + s.len));
    const label = `${file}:${s.line} ${s.from} → ${s.to}`;
    // Mutants share one build tree, so they run strictly in sequence.
    // oxlint-disable-next-line no-await-in-loop
    if ((await run(`${values.build} >/dev/null 2>&1`)) !== 0) {
      results.incompetent++;
      process.stdout.write(`[${n + 1}/${sites.length}] incompetent ${label}\n`);
      // oxlint-disable-next-line no-await-in-loop
    } else if ((await run(`${values.test} >/dev/null 2>&1`)) !== 0) {
      results.killed++;
      process.stdout.write(`[${n + 1}/${sites.length}] killed ${label}\n`);
    } else {
      const text = original.slice(lineStarts[s.line - 1], lineStarts[s.line] ?? undefined).trim();
      results.survived.push(`${label}   | ${text}`);
      process.stdout.write(`[${n + 1}/${sites.length}] SURVIVED ${label}\n`);
    }
  }
} finally {
  restore();
  execFileSync("bash", ["-c", `${values.build} >/dev/null 2>&1 || true`]);
}
process.stdout.write(
  `\nmutants: ${sites.length} · killed ${results.killed} · survived ${results.survived.length}` +
    ` · incompetent ${results.incompetent}\n`,
);
for (const s of results.survived) process.stdout.write(`survivor ${s}\n`);
process.exit(results.survived.length === 0 ? 0 : 1);
