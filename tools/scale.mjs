// Scale traces for the engine's time bounds (`.agent/contracts/kernel.md` § Performance):
//   node tools/scale.mjs <shape> <n> <dir>  — writes <dir>/trace.json (compact) + <dir>/project/
//                                             + <dir>/action.txt (the costliest one-click what-if)
//                                             + <dir>/items.txt (the costliest item of each kind)
//                                             (+ <dir>/whatif.txt: the `--whatif` argument, if any)
//   node tools/scale.mjs <shape> cap        — prints the largest n whose trace fits in 16 MiB (and
//                                             whose what-if fits in one argument)
// Graded shapes (S = the one subject, every claim inferential, F/E/G/H facts, C claims,
// R experiments, X exclusions):
//   wide        n claims C_i: needs [F_i] (statistical, assumed) + entailment E_i (open, lean)
//   deep        one claim: needs F_0..F_{n-1} (statistical; even i assumed, odd i open on lean)
//               + entailment E (open, lean)
//   experiments wide + R_i per claim: success {E_i: proved}, failure {E_i: violated} for even i,
//               effort hours / days / weeks / months by i mod 4
//   exclusions  wide, F_i open on lean for even i, + X_i between E_i and F_{i+1 mod n}: odd i
//               proved on lean with a current receipt (raising E_i derives F_{i+1} violated),
//               even i assumed (raising E_i makes the subject conflict)
//   outcomes    wide + one experiment whose success proves every E_i
//   prereqs     wide + R_i (success {E_i: proved}) requiring R_{i-1} (first third: a chain) or
//               R_t (second third: a star); last third: Y_i on prospective subject P_i, which it
//               creates (a creator cycle), proving K_i
//   whatif      wide, evaluated under a what-if naming every fact (F_i assumed, E_i tested: every
//               E_i stays closable, so each suppose action expands to the whole what-if)
// Reported, never graded:
//   hub         n claims C_i: needs [H, F_i] + E_i, all open on lean; X_i between H and G_i (G_i
//               open, needed by no claim), proved with a current receipt
//   questions   wide (F_i open), each claim on its own question Q_i + prospective subject P_i,
//               created by R_i (success {E_i: proved})
//   waivers     wide + one L-result waiver per claim
//   receipts    per i, current receipts of every bound kind: G_i proved (plain), E_i proved
//               (entailment of D_i, needs [G_i]), K_i proved on subject T (instantiation of G_i),
//               M_i checked (result restated by C_i)
//   invalid     wide with every fact + claim declared twice + R_i naming an undeclared fact U_i
// A proved receipt pins project/proof.txt + its statement digest (D-canon manifest).
import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const LIMIT = 16 * 1024 * 1024;
const PROOF = "The exclusion holds.\n";
const efforts = ["hours", "days", "weeks", "months"];

const sha256 = (/** @type {string} */ text) => createHash("sha256").update(text).digest("hex");

/**
 * An object with its keys sorted by code point (`JSON.stringify` replacer).
 * @param {string} _key
 * @param {unknown} value
 * @returns {unknown}
 */
const sortedKeys = (_key, value) =>
  value && typeof value === "object" && !Array.isArray(value)
    ? Object.fromEntries(Object.entries(value).toSorted(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)))
    : value;

/** D-canon: keys sorted by code point, no whitespace, `JSON.stringify` escaping. */
const canonical = (/** @type {unknown} */ v) => JSON.stringify(v, sortedKeys);

/**
 * @param {string} id
 * @param {string} kind
 * @param {string} status
 * @param {string} route
 */
const fact = (id, kind, status, route) => ({
  id,
  subject: "S",
  kind,
  text: `Fact ${id} holds.`,
  status,
  route,
});

/** @param {number} i */
const claim = (i, /** @type {string[]} */ needs, entailment = `E${i}`) => ({
  id: `C${i}`,
  question: "Q",
  subject: "S",
  level: "inferential",
  text: `Claim ${i} holds.`,
  needs,
  entailment,
});

/** @param {number} n */
const wide = (n) => {
  const facts = [];
  const claims = [];
  for (let i = 0; i < n; i++) {
    facts.push(fact(`F${i}`, "statistical", "assumed", "human-ruling"));
    facts.push(fact(`E${i}`, "entailment", "open", "lean"));
    claims.push(claim(i, [`F${i}`]));
  }
  return { facts, claims };
};

/**
 * Experiment R_i on `subject`, effort hours / days / weeks / months by i mod 4.
 * @param {number} i
 * @param {string} subject
 * @param {Record<string, string>} success
 * @param {Record<string, string>} [failure]
 * @returns {{id: string, subject: string, kind: string, effort: string, title: string, method: string, resources: string, success: Record<string, string>, failure?: Record<string, string>, caveat: string, requires?: string[]}}
 */
const experiment = (i, subject, success, failure) => ({
  id: `R${i}`,
  subject,
  kind: "dry",
  effort: efforts[i % 4] ?? "hours",
  title: `Prove ${i}`,
  method: "Write the proof.",
  resources: "One person.",
  success,
  ...(failure ? { failure } : {}),
  caveat: "None.",
});

/**
 * A receipt for project/proof.txt certifying `manifest` (`Receipt.factManifest` or
 * `Receipt.exclusionManifest`).
 * @param {string} statement
 * @param {object} manifest
 */
const receipt = (statement, manifest) => ({
  summary: "Generated proof.",
  artifacts: [{ path: "proof.txt", sha256: sha256(PROOF) }],
  verifier: "generator",
  statement,
  statementDigest: sha256(canonical(manifest)),
});

/** @param {{id: string, subject: string, kind: string, text: string}} f */
const brief = (f) => ({ id: f.id, subject: f.subject, kind: f.kind, text: f.text });

/** `Receipt.factManifest` without the bound part. @param {{id: string, subject: string, kind: string, text: string, route: string}} f */
const factBase = (f) => ({ ...brief(f), route: f.route });

/**
 * An exclusion; `proved` adds a receipt for project/proof.txt bound to both endpoints.
 * @param {number} i
 * @param {{id: string, subject: string, kind: string, text: string}} a
 * @param {{id: string, subject: string, kind: string, text: string}} b
 * @param {boolean} proved
 */
const exclusion = (i, a, b, proved) => {
  const x = {
    id: `X${i}`,
    subject: "S",
    between: [a.id, b.id],
    text: `${a.id} and ${b.id} exclude each other.`,
    status: proved ? "proved" : "assumed",
    route: proved ? "lean" : "human-ruling",
  };
  if (!proved) return x;
  const manifest = {
    id: x.id,
    subject: "S",
    text: x.text,
    route: "lean",
    between: [brief(a), brief(b)],
  };
  return { ...x, evidence: receipt(x.text, manifest) };
};

/** @type {Record<string, (n: number) => {facts: object[], claims: object[], subjects?: object[], questions?: object[], experiments?: object[], exclusions?: object[], waivers?: object[]}>} */
const shapes = {
  wide,
  deep(n) {
    const facts = [];
    for (let i = 0; i < n; i++) {
      facts.push(
        i % 2 === 0
          ? fact(`F${i}`, "statistical", "assumed", "human-ruling")
          : fact(`F${i}`, "statistical", "open", "lean"),
      );
    }
    facts.push(fact("E", "entailment", "open", "lean"));
    return {
      facts,
      claims: [
        claim(
          0,
          facts.slice(0, n).map((f) => f.id),
          "E",
        ),
      ],
    };
  },
  experiments(n) {
    const t = wide(n);
    const experiments = [];
    for (let i = 0; i < n; i++) {
      experiments.push(
        experiment(
          i,
          "S",
          { [`E${i}`]: "proved" },
          i % 2 === 0 ? { [`E${i}`]: "violated" } : undefined,
        ),
      );
    }
    return { ...t, experiments };
  },
  exclusions(n) {
    const facts = [];
    const claims = [];
    for (let i = 0; i < n; i++) {
      facts.push(
        i % 2 === 0
          ? fact(`F${i}`, "statistical", "open", "lean")
          : fact(`F${i}`, "statistical", "assumed", "human-ruling"),
      );
      facts.push(fact(`E${i}`, "entailment", "open", "lean"));
      claims.push(claim(i, [`F${i}`]));
    }
    const exclusions = [];
    for (let i = 0; i < n; i++) {
      const e = facts[2 * i + 1];
      const f = facts[2 * ((i + 1) % n)];
      if (e && f && n > 1) exclusions.push(exclusion(i, e, f, i % 2 === 1));
    }
    return { facts, claims, exclusions };
  },
  hub(n) {
    const hub = fact("H", "statistical", "open", "lean");
    const facts = [hub];
    const claims = [];
    const exclusions = [];
    for (let i = 0; i < n; i++) {
      facts.push(fact(`F${i}`, "statistical", "open", "lean"));
      facts.push(fact(`E${i}`, "entailment", "open", "lean"));
      const g = fact(`G${i}`, "statistical", "open", "lean");
      facts.push(g);
      claims.push(claim(i, ["H", `F${i}`]));
      exclusions.push(exclusion(i, hub, g, true));
    }
    return { facts, claims, exclusions };
  },
  questions(n) {
    const facts = [];
    const claims = [];
    const subjects = [];
    const questions = [];
    const experiments = [];
    for (let i = 0; i < n; i++) {
      const sub = `P${i}`;
      subjects.push({ id: sub, title: `Cohort ${i}`, kind: "prospective", createdBy: `R${i}` });
      questions.push({ id: `Q${i}`, title: `Question ${i}`, text: `Does ${i} hold?` });
      // A prospective subject's facts record open (its data does not exist yet).
      facts.push({ ...fact(`F${i}`, "statistical", "open", "lean"), subject: sub });
      facts.push({ ...fact(`E${i}`, "entailment", "open", "lean"), subject: sub });
      claims.push({ ...claim(i, [`F${i}`]), question: `Q${i}`, subject: sub });
      experiments.push(experiment(i, sub, { [`E${i}`]: "proved" }));
    }
    return { subjects, questions, facts, claims, experiments };
  },
  waivers(n) {
    const waivers = [];
    for (let i = 0; i < n; i++) {
      waivers.push({ rule: "L-result", claim: `C${i}`, reason: "Generated waiver." });
    }
    return { ...wide(n), waivers };
  },
  receipts(n) {
    const facts = [];
    const claims = [];
    for (let i = 0; i < n; i++) {
      const g = fact(`G${i}`, "statistical", "proved", "lean");
      const d = claim(i, [g.id], `E${i}`);
      d.id = `D${i}`;
      const e = fact(`E${i}`, "entailment", "proved", "lean");
      // An instantiation reuses a fact of another subject.
      const k = {
        ...fact(`K${i}`, "instantiation", "proved", "lean"),
        subject: "T",
        instantiates: g.id,
      };
      const m = fact(`M${i}`, "result", "checked", "runtime-checker");
      const c = {
        id: `C${i}`,
        question: "Q",
        subject: "S",
        level: "descriptive",
        text: `Result ${i} is observed.`,
        needs: [m.id],
        restates: true,
      };
      const claimBrief = { id: d.id, subject: "S", level: d.level, text: d.text };
      facts.push({ ...g, evidence: receipt(g.text, factBase(g)) });
      facts.push({
        ...e,
        evidence: receipt(e.text, {
          ...factBase(e),
          claim: { ...claimBrief, needs: [{ id: g.id, text: g.text }] },
        }),
      });
      facts.push({ ...k, evidence: receipt(k.text, { ...factBase(k), source: brief(g) }) });
      facts.push({
        ...m,
        evidence: receipt(m.text, {
          ...factBase(m),
          restatedBy: { id: c.id, subject: "S", level: c.level, text: c.text },
        }),
      });
      claims.push(d, c);
    }
    return { subjects: [{ id: "T", title: "Other study", kind: "existing" }], facts, claims };
  },
  outcomes(n) {
    /** @type {Record<string, string>} */
    const success = {};
    for (let i = 0; i < n; i++) success[`E${i}`] = "proved";
    return { ...wide(n), experiments: [experiment(0, "S", success)] };
  },
  prereqs(n) {
    const t = wide(n);
    const subjects = [];
    const experiments = [];
    const third = Math.floor(n / 3);
    for (let i = 0; i < n; i++) {
      if (i < 2 * third) {
        const x = experiment(i, "S", { [`E${i}`]: "proved" });
        if (i > 0 && i < third) x.requires = [`R${i - 1}`];
        if (i > third) x.requires = [`R${third}`];
        experiments.push(x);
      } else {
        // Y_i creates P_i, its own subject: closing Y_i adds Y_i again (a creator cycle).
        subjects.push({
          id: `P${i}`,
          title: `Cohort ${i}`,
          kind: "prospective",
          createdBy: `Y${i}`,
        });
        t.facts.push({ ...fact(`K${i}`, "statistical", "open", "lean"), subject: `P${i}` });
        experiments.push({ ...experiment(i, `P${i}`, { [`K${i}`]: "proved" }), id: `Y${i}` });
      }
    }
    return { ...t, subjects, experiments };
  },
  whatif: wide,
  invalid(n) {
    const t = wide(n);
    const experiments = [];
    for (let i = 0; i < n; i++) experiments.push(experiment(i, "S", { [`U${i}`]: "proved" }));
    return { facts: [...t.facts, ...t.facts], claims: [...t.claims, ...t.claims], experiments };
  },
};

/**
 * The `--whatif` argument of a shape, if it has one (`whatif`: every fact at its route's ceiling).
 * @param {string} shape
 * @returns {((n: number) => string) | undefined}
 */
const whatifOf = (shape) =>
  shape === "whatif"
    ? (n) => {
        const parts = [];
        for (let i = 0; i < n; i++) parts.push(`F${i}=assumed`, `E${i}=tested`);
        return parts.join(",");
      }
    : undefined;

/**
 * Each shape's costliest one-click what-if (kernel.md P-time `eval --action`): the action whose
 * expansion is largest.
 * @param {string} shape
 * @param {number} n
 */
const actionOf = (shape, n) => {
  const third = Math.floor(n / 3);
  switch (shape) {
    case "outcomes":
      return "success:R0";
    case "prereqs":
      return `success:R${third - 1}`;
    case "experiments":
      return "success:R0";
    case "deep":
      return "suppose:F1";
    default:
      return "suppose:E0";
  }
};

/**
 * Each shape's costliest item of each kind (kernel.md P-time `eval --details`): the experiment
 * with the longest lists, the claim with the deepest plan, the fact with the most raisers.
 * @param {string} shape
 * @param {number} n
 */
const itemsOf = (shape, n) => {
  const third = Math.floor(n / 3);
  const r = {
    prereqs: `R${third - 1}`,
    outcomes: "R0",
    experiments: "R0",
    questions: "R0",
    invalid: "R0",
  }[shape];
  const c = shape === "prereqs" ? `C${third - 1}` : "C0";
  const f = shape === "deep" ? "F1" : "E0";
  return [...(r ? [`experiment:${r}`] : []), `claim:${c}`, `fact:${f}`];
};

/** One argument's byte limit (Linux MAX_ARG_STRLEN = 32 pages), its NUL included. */
const ARG_LIMIT = 131072 - 1;

/** @param {string} shape @param {number} n */
const trace = (shape, n) => {
  const make = shapes[shape];
  if (!make) throw new Error(`unknown shape ${shape}: ${Object.keys(shapes).join(", ")}`);
  const { subjects = [], questions = [], ...rest } = make(n);
  return JSON.stringify({
    fvtrace: 1,
    analysis: { id: "A", title: "Scale", summary: `Generated ${shape} trace, n = ${n}.` },
    subjects: [{ id: "S", title: "Study", kind: "existing" }, ...subjects],
    questions: [{ id: "Q", title: "Question", text: "Does it hold?" }, ...questions],
    ...rest,
  });
};

const [shape, arg, dir] = process.argv.slice(2);
if (!shape || !arg) {
  process.stderr.write("usage: node tools/scale.mjs <shape> <n> <dir> | <shape> cap\n");
  process.exit(2);
}
if (arg === "cap") {
  const whatif = whatifOf(shape);
  /** The bytes of each bounded input at `n`, over its bound (fits = every share ≤ 1). */
  const shares = (/** @type {number} */ n) => [
    Buffer.byteLength(trace(shape, n)) / LIMIT,
    whatif ? Buffer.byteLength(whatif(n)) / ARG_LIMIT : 0,
  ];
  const fits = (/** @type {number} */ n) => shares(n).every((x) => x <= 1);
  // Sizes grow about linearly in n: a guess from n = 1000 + 2000, then a bracket of 1% steps
  // around it, then bisection (each probe renders a trace of up to 16 MiB).
  const [a, b] = [shares(1000), shares(2000)];
  const guess = Math.max(
    1,
    Math.min(...a.map((x, i) => 1000 + ((1 - x) * 1000) / Math.max((b[i] ?? 0) - x, 1e-12))),
  );
  const step = Math.max(1, Math.floor(guess / 100));
  let lo = Math.floor(guess);
  let hi = lo + step;
  while (fits(hi)) [lo, hi] = [hi, hi + step];
  while (lo > 1 && !fits(lo)) [hi, lo] = [lo, Math.max(1, lo - step)];
  while (hi - lo > 1) {
    const mid = Math.floor((lo + hi) / 2);
    if (fits(mid)) lo = mid;
    else hi = mid;
  }
  process.stdout.write(`${lo}\n`);
} else {
  const n = Number(arg);
  if (!Number.isInteger(n) || n < 1 || !dir) {
    process.stderr.write("usage: node tools/scale.mjs <shape> <n> <dir>\n");
    process.exit(2);
  }
  mkdirSync(join(dir, "project"), { recursive: true });
  writeFileSync(join(dir, "project", "proof.txt"), PROOF);
  writeFileSync(join(dir, "trace.json"), trace(shape, n));
  const whatif = whatifOf(shape);
  if (whatif) writeFileSync(join(dir, "whatif.txt"), whatif(n));
  writeFileSync(join(dir, "action.txt"), `${actionOf(shape, n)}\n`);
  writeFileSync(join(dir, "items.txt"), `${itemsOf(shape, n).join("\n")}\n`);
}
