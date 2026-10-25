// The find route (kernel.md U-access): any claim, fact or experiment by its id or the words of
// its text, mounted or not. Entries are made once per envelope, on the first search.

import { clickToOpen, h, idButton } from "./dom.js";
import { count } from "./words.js";

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {"claim" | "fact" | "experiment"} Kind */
/** @typedef {{ kind: Kind, id: string, text: string, question: string, idLower: string,
 *   lower: string }} Entry */

/** Results shown at once. */
const shown = 20;

/** Every claim, fact + experiment, with the words a search reads. @param {Envelope} env */
export function entriesOf(env) {
  /** @type {Entry[]} */
  const out = [];
  /** @param {Kind} kind @param {string} id @param {string} text @param {string} words
   * @param {string} [question] */
  const add = (kind, id, text, words, question = "") =>
    out.push({ kind, id, text, question, idLower: id.toLowerCase(), lower: words.toLowerCase() });
  for (const c of env.claims)
    add("claim", c.id, c.headline ?? c.text, `${c.headline ?? ""} ${c.text}`, c.question);
  for (const f of env.facts) add("fact", f.id, f.text, f.text);
  for (const e of env.experiments) add("experiment", e.id, e.title, e.title);
  return out;
}

/**
 * The entries matching `query`: an id equal to it first, then ids that start with it, then the
 * entries whose words hold it (letter case aside), each group in envelope order.
 * @param {Entry[]} entries @param {string} query
 * @returns {{ matches: Entry[], total: number }}
 */
export function search(entries, query) {
  const q = query.trim().toLowerCase();
  if (!q) return { matches: [], total: 0 };
  /** @type {Entry[][]} */
  const groups = [[], [], []];
  for (const e of entries) {
    if (e.idLower === q) groups[0]?.push(e);
    else if (e.idLower.startsWith(q)) groups[1]?.push(e);
    else if (e.lower.includes(q)) groups[2]?.push(e);
  }
  const all = groups.flat();
  return { matches: all.slice(0, shown), total: all.length };
}

/** @type {Record<Kind, string>} */
const kindWords = { claim: "Claim", fact: "Fact", experiment: "Experiment" };

/**
 * The count line + one row per match; a claim of another question says which.
 * @param {string} query @param {{ matches: Entry[], total: number }} found
 * @param {(questionId: string) => string | undefined} otherQuestion the title of `questionId` when
 *   it is not the shown question
 * @param {(e: Entry) => void} choose
 */
export function results(query, found, otherQuestion, choose) {
  const q = query.trim();
  const line =
    found.total === 0
      ? `No claim, fact or experiment matches “${q}”.`
      : found.total > found.matches.length
        ? `${count(found.total, "match", "matches")}. Showing the first ${found.matches.length}.`
        : `${count(found.total, "match", "matches")}.`;
  const rows = found.matches.map((e) => {
    const other = e.kind === "claim" ? otherQuestion(e.question) : undefined;
    return h(
      "li",
      { class: "find-row", onclick: clickToOpen(() => choose(e)) },
      h(
        "span",
        { class: "find-id" },
        idButton(e.id, `find:${e.kind}:${e.id}`, () => choose(e)),
      ),
      h("span", { class: "find-kind" }, kindWords[e.kind]),
      h(
        "span",
        { class: "find-text" },
        e.text,
        other ? h("small", { class: "find-question" }, `In another question: ${other}`) : null,
      ),
    );
  });
  return { line, rows };
}
