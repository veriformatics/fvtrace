// An envelope's lookups (kernel.md U-lookups), built once when the page adopts the envelope: no
// card, contact or row scans a whole envelope list (v1: each card rebuilt a fact map and each
// contact scanned every action, so 5,000 claims took 2.2 GiB of heap).

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {import("./envelope.js").Fact} Fact */
/** @typedef {import("./envelope.js").Experiment} Experiment */
/** @typedef {import("./envelope.js").Exclusion} Exclusion */
/** @typedef {Envelope["subjects"][number]} Subject */
/** @typedef {Envelope["lints"][number]} Lint */

/**
 * @typedef {{ facts: Map<string, Fact>, claims: Map<string, Claim>,
 *   experiments: Map<string, Experiment>, exclusions: Map<string, Exclusion>,
 *   subjects: Map<string, Subject>, actions: Set<string>, neededBy: Map<string, Claim[]>,
 *   raiserCount: Map<string, number>, byQuestion: Map<string, Claim[]>,
 *   lintsOf: Map<string, Lint[]>, prospective: Set<string> }} Lookups
 */

/**
 * Each item by id (the first one where a list repeats an id, as `Array.find` would).
 * @template {{ id: string }} T @param {T[]} items @returns {Map<string, T>}
 */
function byId(items) {
  /** @type {Map<string, T>} */
  const m = new Map();
  for (const x of items) if (!m.has(x.id)) m.set(x.id, x);
  return m;
}

/**
 * Appends `v` to the list at `k`.
 * @template K, V @param {Map<K, V[]>} m @param {K} k @param {V} v
 */
function push(m, k, v) {
  const list = m.get(k);
  if (list) list.push(v);
  else m.set(k, [v]);
}

/** @param {Envelope} env @returns {Lookups} */
export function lookupsOf(env) {
  /** @type {Map<string, Claim[]>} */
  const neededBy = new Map();
  /** @type {Map<string, Claim[]>} */
  const byQuestion = new Map();
  for (const c of env.claims) {
    push(byQuestion, c.question, c);
    const needs = new Set(c.entailment === undefined ? c.needs : [...c.needs, c.entailment]);
    for (const f of needs) push(neededBy, f, c);
  }
  /** @type {Map<string, number>} */
  const raiserCount = new Map();
  for (const e of env.experiments) {
    for (const f of new Set(e.success.map((o) => o.fact)))
      raiserCount.set(f, (raiserCount.get(f) ?? 0) + 1);
  }
  /** @type {Map<string, Lint[]>} */
  const lintsOf = new Map();
  for (const l of env.lints) push(lintsOf, l.claim, l);
  return {
    facts: byId(env.facts),
    claims: byId(env.claims),
    experiments: byId(env.experiments),
    exclusions: byId(env.exclusions),
    subjects: byId(env.subjects),
    actions: new Set(env.actions.map((a) => a.id)),
    neededBy,
    raiserCount,
    byQuestion,
    lintsOf,
    prospective: new Set(env.subjects.filter((s) => s.kind === "prospective").map((s) => s.id)),
  };
}
