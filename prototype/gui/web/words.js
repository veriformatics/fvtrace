// Display words for the engine's codes. Wording only: every state, rank and sentence these label
// comes from the envelope.

/** @type {Record<string, string>} */
export const verdicts = {
  can: "Can claim",
  conditional: "On assumption",
  open: "Not yet",
  cannot: "Cannot claim",
};

/** Lamp symbols: each state has its own shape + symbol, never color alone. */
/** @type {Record<string, string>} */
export const symbols = { can: "✓", conditional: "≈", open: "○", cannot: "×" };

/** @type {Record<string, string>} */
export const statuses = {
  proved: "Verified by proof",
  checked: "Verified by a checker",
  assumed: "Assumption",
  tested: "Tested, not verified",
  open: "Open",
  violated: "Violated",
  stale: "Changed since it was pinned",
};

/** A supposed status, as the end of "suppose O2 …". */
/** @type {Record<string, string>} */
export const supposedAs = {
  proved: "is proved",
  checked: "is verified by a checker",
  assumed: "is assumed",
  tested: "is tested",
  open: "is open",
  violated: "is false",
};

/** @type {Record<string, string>} */
export const routes = {
  lean: "Lean proof",
  refinement: "Refinement proof",
  "runtime-checker": "Proved checker on the actual data",
  "human-ruling": "Human ruling",
  empirical: "Empirical evidence",
};

/** @type {Record<string, string>} */
export const kinds = {
  entailment: "Entailment",
  result: "Result",
  estimand: "Estimand",
  statistical: "Statistics",
  numerical: "Numerics",
  implementation: "Implementation",
  dataflow: "Data flow",
  provenance: "Provenance",
  interpretation: "Interpretation",
  release: "Release",
  "spec-review": "Question review",
  instantiation: "Instantiation",
};

/** @type {Record<string, string>} */
export const efforts = { hours: "Hours", days: "Days", weeks: "Weeks", months: "Months" };

/** @param {Record<string, string>} table @param {string} code */
export function word(table, code) {
  return table[code] ?? code;
}

/** `1 claim`, `2 claims`. @param {number} n @param {string} one @param {string} many */
export function count(n, one, many) {
  return `${n} ${n === 1 ? one : many}`;
}

/**
 * A verdict + its qualifiers, minus the review state (shown once per page, not per verdict).
 * @param {{ verdict: string, qualifiers: string[] }} c
 */
export function verdictText(c) {
  const q = c.qualifiers.filter((x) => x !== "draft" && x !== "stale review");
  return q.length ? `${c.verdict} (${q.join(", ")})` : c.verdict;
}
