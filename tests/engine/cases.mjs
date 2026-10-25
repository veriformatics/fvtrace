// The page engine's differential cases (`.agent/contracts/kernel.md` E-wasm): snapshots + what-if
// specs that the WebAssembly build (through `web/engine.js`) and the native engine
// (`fvtrace-tests --evaluate-snapshot`) both evaluate; every answer must match byte for byte.
// Built from trace JSON (a snapshot is the trace's text + bindings + review), so both sides read
// exactly the same input.
import { execFileSync } from "node:child_process";
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export const root = new URL("../../", import.meta.url);
const testsBin = new URL(".lake/build/bin/fvtrace-tests", root).pathname;
const bin = new URL(".lake/build/bin/fvtrace", root).pathname;

/** `fvtrace export --html` of the synthetic study, pinned in a temporary project + data folder:
 * the page a user gets. @returns {string} the page's HTML */
export function exportedPage() {
  const dir = mkdtempSync(join(tmpdir(), "fvtrace-engine-page-"));
  try {
    const project = join(dir, "proj");
    cpSync(new URL("examples/synthetic/project", root), project, { recursive: true });
    const env = { ...process.env, FVTRACE_HOME: join(dir, "home") };
    const run = (/** @type {string[]} */ args) =>
      execFileSync(bin, args, { cwd: project, env, encoding: "utf8" }).trim();
    run(["init"]);
    writeFileSync(run(["path"]), readFileSync(new URL("examples/synthetic/trace.json", root)));
    run(["pin"]);
    run(["export", "--html", join(dir, "claims.html")]);
    return readFileSync(join(dir, "claims.html"), "utf8");
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/** @typedef {Record<string, unknown>} Json */
/** @typedef {{ name: string, snapshot: string, specs: string[] }} Case */

export const statuses = ["proved", "checked", "assumed", "tested", "open", "violated"];

/** mulberry32: the same seed gives the same cases. @param {number} seed */
export function random(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** @param {unknown} v @returns {v is Json} */
const isJson = (v) => typeof v === "object" && v !== null && !Array.isArray(v);

/** A fresh parse of a trace file (cases edit it freely). @param {string} path @returns {Json} */
export function traceAt(path) {
  /** @type {unknown} */
  const v = JSON.parse(readFileSync(new URL(path, root), "utf8"));
  if (!isJson(v)) throw new Error(`${path}: no object`);
  return v;
}

/** @param {unknown} v @returns {Json[]} */
const records = (v) => (Array.isArray(v) ? v.filter(isJson) : []);

/** @param {Json} trace @returns {string[]} */
export const factIds = (trace) =>
  records(trace["facts"]).flatMap((f) => (typeof f["id"] === "string" ? [f["id"]] : []));

/**
 * A snapshot of `trace`: a binding per verified fact + exclusion (`stale` ids read changed).
 * @param {Json} trace @param {{ stale?: string[], review?: string }} [opts]
 */
export function snapshotOf(trace, { stale = [], review = "draft" } = {}) {
  const verified = [...records(trace["facts"]), ...records(trace["exclusions"])].filter(
    (x) => x["status"] === "proved" || x["status"] === "checked",
  );
  const bindings = verified.map((x) =>
    stale.includes(String(x["id"]))
      ? { id: x["id"], current: false, reasons: ["changed proofs/Contrast.lean"] }
      : { id: x["id"], current: true, reasons: [] },
  );
  return JSON.stringify({
    schema: "fvtrace.snapshot/1",
    trace: JSON.stringify(trace),
    bindings,
    digest: "ab".repeat(32),
    review,
  });
}

/** What a page's data block carries, as the page hands it to its engine. @param {string} html */
export function snapshotOfPage(html) {
  const block = html.split('id="fvtrace-data">')[1]?.split("</script>")[0] ?? "";
  /** @type {unknown} */
  const data = JSON.parse(block);
  const snapshot =
    typeof data === "object" && data !== null && "snapshot" in data ? data.snapshot : undefined;
  return JSON.stringify(snapshot);
}

/** The page's engine block (base64 gzip). @param {string} html */
export const engineOfPage = (html) =>
  html.split('id="fvtrace-engine">')[1]?.split("</script>")[0] ?? "";

/** The native engine's answers for `specs` on `snapshot`, in order. @param {string} snapshot
 * @param {string[]} specs @returns {string[]} */
export function nativeAnswers(snapshot, specs) {
  const dir = mkdtempSync(join(tmpdir(), "fvtrace-engine-"));
  try {
    writeFileSync(join(dir, "snapshot.json"), snapshot);
    writeFileSync(join(dir, "specs.json"), JSON.stringify(specs));
    const out = execFileSync(
      testsBin,
      ["--evaluate-snapshot", join(dir, "snapshot.json"), join(dir, "specs.json")],
      { encoding: "utf8", maxBuffer: 1 << 30 },
    );
    /** @type {unknown} */
    const answers = JSON.parse(out);
    if (!Array.isArray(answers) || !answers.every((a) => typeof a === "string"))
      throw new Error("fvtrace-tests --evaluate-snapshot printed no list of strings");
    return answers;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/** The native engine's answers to `requests` (`kernel.md` E-request), in order through one engine.
 * @param {string} snapshot @param {string[]} requests @returns {string[]} */
export function nativeRequests(snapshot, requests) {
  const dir = mkdtempSync(join(tmpdir(), "fvtrace-engine-"));
  try {
    writeFileSync(join(dir, "snapshot.json"), snapshot);
    writeFileSync(join(dir, "requests.json"), JSON.stringify(requests));
    const out = execFileSync(
      testsBin,
      ["--answer-snapshot", join(dir, "snapshot.json"), join(dir, "requests.json")],
      { encoding: "utf8", maxBuffer: 1 << 30 },
    );
    /** @type {unknown} */
    const answers = JSON.parse(out);
    if (!Array.isArray(answers) || !answers.every((a) => typeof a === "string"))
      throw new Error("fvtrace-tests --answer-snapshot printed no list of strings");
    return answers;
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

/** One request's JSON text. @param {Record<string, string>} r */
const req = (r) => JSON.stringify(r);

/** A request sequence for one case (`kernel.md` E-wasm): what-ifs, every one-click action, the
 * details of every item (a few on the large cases), refusals of each kind, and state carried
 * across (back to recorded, repeats). @param {Case} c @returns {string[]} */
export function requestsFor(c) {
  /** @type {unknown} */
  const env = JSON.parse(nativeAnswers(c.snapshot, [""])[0] ?? "null");
  const ids = (/** @type {string} */ key) =>
    isJson(env) ? records(env[key]).map((r) => String(r["id"])) : [];
  const large = c.name.startsWith("a 4 MB") || c.name.startsWith("12,000");
  const few = (/** @type {string[]} */ xs) => (large ? xs.slice(0, 3) : xs);
  const firstWhatif = c.specs.find((x) => x !== "") ?? "";
  return [
    req({ whatif: "" }),
    ...few(c.specs.slice(1, 6)).map((whatif) => req({ whatif })),
    ...few(ids("actions")).map((action) => req({ whatif: "", action })),
    ...few(ids("actions"))
      .slice(0, 2)
      .map((action) => req({ whatif: firstWhatif, action })),
    ...few(ids("experiments")).map((id) => req({ whatif: "", details: `experiment:${id}` })),
    ...few(ids("claims")).map((id) => req({ whatif: "", details: `claim:${id}` })),
    ...few(ids("facts")).map((id) => req({ whatif: firstWhatif, details: `fact:${id}` })),
    req({ whatif: "", action: "plan:C9" }),
    req({ whatif: "", details: "E9" }),
    req({ whatif: "", details: "experiment:E9" }),
    req({ whatif: "ZZ=proved", action: "x", details: "y" }),
    req({ whatif: "", action: "x", details: "y" }),
    '{"whatif":1}',
    "not json",
    req({ whatif: "" }),
  ];
}

/** The recorded envelope's one-click actions, as what-if specs. @param {string} snapshot */
function actionSpecs(snapshot) {
  /** @type {unknown} */
  const env = JSON.parse(nativeAnswers(snapshot, [""])[0] ?? "null");
  const actions =
    typeof env === "object" && env !== null && "actions" in env ? records(env.actions) : [];
  return actions.map((a) =>
    records(a["overrides"])
      .map((o) => `${String(o["fact"])}=${String(o["status"])}`)
      .join(","),
  );
}

/** Classes a random draw would rarely produce (`kernel.md` E-wasm). @param {string} f */
function fixedSpecs(f) {
  return [
    `${f}=checked\u0000`,
    "\u0000",
    `\u0000${f}=checked`,
    `${f}=chécked`,
    `${f}=checked\u{1F600}`,
    `${f}=checked\u0085`,
    `${f}=checked\u202e`,
    `${f}\u202e=checked`,
    `${f}=checked,${f}=checked`,
    `${f}=checked,${f}=open`,
    ",",
    `${f}=checked,,`,
    `,${f}=open`,
    f,
    "=",
    `${f}=`,
    `=${f}`,
    `${f}=checked=proved`,
    ` ${f}=checked`,
    "ZZ=proved",
    `${f}=checked,`.repeat(4000),
  ];
}

/** Seeded random stacks: 1-3 entries of a fact (sometimes none of the trace's) + any status,
 * now and then a malformed entry.
 * @param {string[]} facts @param {() => number} next @param {number} count */
function randomSpecs(facts, next, count) {
  const pick = (/** @type {string[]} */ xs) => xs[Math.floor(next() * xs.length)] ?? "";
  return Array.from({ length: count }, () => {
    const n = 1 + Math.floor(next() * 3);
    return Array.from({ length: n }, () => {
      const r = next();
      if (r < 0.05) return pick(["O2", "=open", "X=", "Q=Q=Q"]);
      const fact = r < 0.1 ? "ZZ" : pick(facts);
      return `${fact}=${pick(statuses)}`;
    }).join(",");
  });
}

/** The fixture with its exclusion verified (a receipt), so derived violations + exclusion
 * bindings reach the envelope. */
function verifiedExclusion() {
  const t = traceAt("tests/fixtures/synthetic.trace.json");
  for (const x of records(t["exclusions"]))
    Object.assign(x, {
      status: "proved",
      route: "lean",
      evidence: {
        summary: "A planted receipt.",
        artifacts: [{ path: "proofs/Contrast.lean", sha256: "cd".repeat(32) }],
        verifier: "Lean 4.35.0",
        statement: "planted",
        statementDigest: "ef".repeat(32),
      },
    });
  return t;
}

/** Twenty-one experiments on one claim: above the plan search's limit (`tooLarge`). */
function wide() {
  const ids = Array.from({ length: 21 }, (_, i) => i);
  const efforts = ["hours", "days", "weeks", "months"];
  return {
    fvtrace: 1,
    analysis: { id: "wide", title: "Wide", summary: "Twenty-one experiments, one claim." },
    subjects: [{ id: "S", title: "Wide", kind: "existing" }],
    questions: [{ id: "Q", title: "Q", text: "Does it hold?" }],
    facts: [
      ...ids.map((i) => ({
        id: `F${i}`,
        subject: "S",
        kind: "numerical",
        text: `F${i} holds.`,
        status: "open",
        route: "lean",
      })),
      {
        id: "EN",
        subject: "S",
        kind: "entailment",
        text: "They entail it.",
        status: "open",
        route: "lean",
      },
    ],
    claims: [
      {
        id: "C",
        question: "Q",
        subject: "S",
        level: "estimand",
        text: "They hold.",
        needs: ids.map((i) => `F${i}`),
        entailment: "EN",
      },
    ],
    experiments: ids.map((i) => ({
      id: `E${i + 10}`,
      subject: "S",
      kind: "dry",
      effort: efforts[i % 4],
      title: `Experiment ${i}`,
      method: "Run it.",
      resources: "None.",
      success: { [`F${i}`]: "proved", EN: "proved" },
      caveat: "None.",
    })),
  };
}

/** `n` claims, each needing its own premise + reasoning fact: past `n` ≈ 9,600 a recursion with one
 * frame per claim overflows V8's stack in the page engine (native threads have 8 MB). @param {number} n */
function manyClaims(n) {
  const ids = Array.from({ length: n }, (_, i) => i);
  return {
    fvtrace: 1,
    analysis: { id: "many", title: "Many claims", summary: "One claim per premise." },
    subjects: [{ id: "S", title: "Many", kind: "existing" }],
    questions: [{ id: "Q", title: "Q", text: "Does it hold?" }],
    facts: ids.flatMap((i) => [
      {
        id: `F${i}`,
        subject: "S",
        kind: "statistical",
        text: `F${i} holds.`,
        status: "assumed",
        route: "human-ruling",
      },
      {
        id: `E${i}`,
        subject: "S",
        kind: "entailment",
        text: `E${i} holds.`,
        status: "open",
        route: "lean",
      },
    ]),
    claims: ids.map((i) => ({
      id: `C${i}`,
      question: "Q",
      subject: "S",
      level: "inferential",
      text: `Claim ${i} holds.`,
      needs: [`F${i}`],
      entailment: `E${i}`,
    })),
  };
}

/** `trace` with the review record `fvtrace review` writes (a copy): its date decodes through
 * `String.toList` + `String.ofList`. @param {Json} trace @param {string} date @returns {Json} */
const withReview = (trace, date) => ({
  ...trace,
  review: { reviewer: "A. Reviewer", date, digest: "cd".repeat(32), note: "Read every claim." },
});

/** A snapshot whose trace text D-json refuses. @param {string} trace */
const refusedTrace = (trace) =>
  JSON.stringify({
    schema: "fvtrace.snapshot/1",
    trace,
    bindings: [],
    digest: "x",
    review: "draft",
  });

/** A trace text nested deeper than D-json allows. */
const tooDeep = () => `{"fvtrace":1,"analysis":${"[".repeat(70)}${"]".repeat(70)}}`;

/** Every differential case, deterministic for `seed` (printed by the tests). @param {number} seed
 * @returns {Case[]} */
export function cases(seed) {
  const next = random(seed);
  const synthetic = traceAt("examples/synthetic/trace.json");
  const big = traceAt("examples/synthetic/trace.json");
  const analysis = big["analysis"];
  if (isJson(analysis)) analysis["summary"] = "A long summary. ".repeat(250000);
  /** @type {[string, Json, { stale?: string[], review?: string }][]} */
  const traced = [
    ["synthetic", synthetic, {}],
    ["synthetic, a stale receipt + a stale review", synthetic, { stale: ["O1"], review: "stale" }],
    ["synthetic, reviewed", synthetic, { review: "reviewed" }],
    ["self-trace", traceAt("examples/fvtrace/trace.json"), {}],
    ["feature fixture", traceAt("tests/fixtures/synthetic.trace.json"), {}],
    ["restating fixture", traceAt("tests/fixtures/restates.trace.json"), {}],
    ["verified exclusion", verifiedExclusion(), {}],
    ["verified exclusion, stale receipt", verifiedExclusion(), { stale: ["X1"] }],
    ["twenty-one experiments (tooLarge)", wide(), {}],
    ["a 4 MB legal trace (memory growth)", big, {}],
    ["12,000 claims (past the wasm call depth)", manyClaims(12000), {}],
    [
      "synthetic, its review record (reviewed)",
      withReview(synthetic, "2026-10-23"),
      { review: "reviewed" },
    ],
    [
      "synthetic, its review record (stale) + a stale receipt",
      withReview(synthetic, "2026-01-31"),
      { stale: ["O1"], review: "stale" },
    ],
    [
      "feature fixture, its review record (reviewed)",
      withReview(traceAt("tests/fixtures/synthetic.trace.json"), "1999-12-01"),
      { review: "reviewed" },
    ],
  ];
  /** @type {Case[]} */
  const out = traced.map(([name, trace, opts]) => {
    const snapshot = snapshotOf(trace, opts);
    const facts = factIds(trace);
    const first = facts[0] ?? "O1";
    const conflicting = name.startsWith("verified exclusion") ? ["O4=assumed,O5=assumed"] : [];
    // Each call decodes the snapshot again (both sides): the 4 MB case keeps to a few.
    if (name.startsWith("a 4 MB"))
      return { name, snapshot, specs: ["", "O2=checked,EN2=proved", "ZZ=proved", ""] };
    if (name.startsWith("12,000 claims")) return { name, snapshot, specs: ["", "E0=proved"] };
    return {
      name,
      snapshot,
      specs: [
        "",
        ...actionSpecs(snapshot),
        ...conflicting,
        ...fixedSpecs(first),
        ...randomSpecs(facts, next, 40),
        "",
      ],
    };
  });
  /** @type {[string, string][]} */
  const refused = [
    ["a trace nested deeper than D-json allows", refusedTrace(tooDeep())],
    ["a trace above 16 MiB", refusedTrace(" ".repeat(16 * 1024 * 1024 + 1))],
    ["a damaged snapshot", '{"schema":"fvtrace.snapshot/1"}'],
    ["a review date outside the calendar", snapshotOf(withReview(synthetic, "2026-13-01"))],
  ];
  for (const [name, snapshot] of refused) out.push({ name, snapshot, specs: ["", "O1=proved"] });
  return out;
}
