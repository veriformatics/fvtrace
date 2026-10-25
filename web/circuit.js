// Claim circuits: a claim is a lamp fed through one switch per fact it needs, in series. Every
// switch must close for the lamp to light; one broken switch blocks it.

import { clickToOpen, h, idButton, s } from "./dom.js";
import { listOf } from "./lazy.js";
import { kinds, levels, qualifiers, statuses, symbols, word } from "./words.js";

/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {import("./envelope.js").Fact} Fact */
/** @typedef {import("./lookups.js").Lookups} Lookups */

/**
 * What a circuit can ask the app to do.
 * @typedef {{ select: (kind: "fact" | "claim" | "experiment", id: string) => void,
 *   toggle: (fact: string) => void, canToggle: (fact: string) => boolean,
 *   supposeStatus: (fact: string) => string | undefined,
 *   pairsOf: (claim: string) => string[] | undefined }} Handlers
 */

/** @param {string} state @param {string} [size] */
export function lamp(state, size) {
  return h(
    "span",
    { class: `lamp ${state}${size ? ` ${size}` : ""}`, "aria-hidden": "true" },
    symbols[state] ?? "",
  );
}

/** The switch drawing: closed (verified), dashed (assumed), open, or broken (violated). */
/** @param {string} status */
export function switchSvg(status) {
  const arm =
    status === "violated"
      ? s("path", { d: "M19 21L27 17M33 25L41 21M27 12L34 29M34 12L27 29" })
      : status === "proved" || status === "checked"
        ? s("path", { d: "M19 21H41" })
        : status === "assumed"
          ? s("path", { d: "M19 21H41", "stroke-dasharray": "3 3" })
          : s("path", { d: "M19 19L40 7" });
  return s(
    "svg",
    { viewBox: "0 0 60 42", "aria-hidden": "true", focusable: "false" },
    s("path", { d: "M0 21H15M45 21H60" }),
    s("circle", { cx: "16", cy: "21", r: "3" }),
    s("circle", { cx: "44", cy: "21", r: "3" }),
    arm,
  );
}

/**
 * One contact of a circuit: the switch (suppose / restore) + its fact label (inspect).
 * @param {Fact} f @param {Handlers} on @param {string} claim
 */
function contact(f, on, claim) {
  const toggleable = on.canToggle(f.id);
  const verb = f.supposed
    ? `Restore the recorded status of ${f.id}`
    : `Suppose ${f.id} ${on.supposeStatus(f.id) ?? "verified"}`;
  return h(
    "li",
    { class: "contact" },
    h(
      "button",
      {
        class: `switch ${f.effective}`,
        "data-key": `switch:${claim}:${f.id}`,
        type: "button",
        "aria-pressed": f.supposed ? "true" : "false",
        "aria-label": toggleable ? verb : `${f.id}: ${word(statuses, f.effective)}`,
        "aria-disabled": toggleable ? undefined : "true",
        title: toggleable ? verb : word(statuses, f.effective),
        onclick: () => {
          if (on.canToggle(f.id)) on.toggle(f.id);
        },
      },
      switchSvg(f.effective),
    ),
    h(
      "button",
      {
        class: "contact-label",
        "data-key": `label:${claim}:${f.id}`,
        type: "button",
        onclick: () => on.select("fact", f.id),
      },
      h("strong", {}, f.id),
      h("span", { class: "contact-kind" }, word(kinds, f.kind)),
      f.supposed ? h("span", { class: "supposed" }, "supposed") : null,
      h("span", { class: "visually-hidden" }, `: ${f.text}`),
    ),
  );
}

/**
 * The label row over a claim's words: its id (the button that opens it, given `open` + `key`), then
 * its kind joined to its verdict in the verdict's color, then its qualifiers, quiet.
 * @param {Claim} c @param {() => void} [open] @param {string} [key] @param {boolean} [pressed]
 */
export const claimTag = (c, open, key, pressed) => {
  const q = qualifiers(c);
  return h(
    "span",
    { class: "claim-tag" },
    h("span", { class: "tag-id" }, open && key ? idButton(c.id, key, open, pressed) : c.id),
    h(
      "span",
      { class: "tag-pair" },
      h("span", { class: "tag-kind" }, h("span", { class: "cap-trim" }, word(levels, c.level))),
      h(
        "span",
        { class: `tag-soft ${c.final}` },
        lamp(c.final, "mini"),
        h("span", { class: "cap-trim" }, c.verdict),
      ),
    ),
    q.length ? h("span", { class: `tag-qualifier ${c.final}` }, q.join(", ")) : null,
    c.latent ? h("span", {}, "Overlooked direction") : null,
  );
};

/** A claim's plain headline, or its exact statement when it has none. @param {Claim} c */
export const headline = (c) => c.headline ?? c.text;

/**
 * The exact statement behind a headline, folded until asked for: the sentence the proofs cover.
 * @param {Claim} c
 */
export function exactStatement(c) {
  if (!c.headline || c.headline === c.text) return null;
  return h(
    "details",
    { class: "exact" },
    h("summary", {}, "Show the exact statement"),
    h("p", {}, c.text),
  );
}

/** The facts a claim's diagram draws: its needs, then its entailment. @param {Claim} c */
const drawn = (c) => (c.entailment === undefined ? c.needs : [...c.needs, c.entailment]);

/**
 * A claim's circuit card. Its selection is drawn apart (`markCard`), so selecting another claim
 * keeps every card's element.
 * @param {Claim} c @param {Lookups} ix @param {Handlers} on
 */
export function circuit(c, ix, on) {
  const open = () => on.select("claim", c.id);
  const needs = drawn(c).flatMap((id) => {
    const f = ix.facts.get(id);
    return f ? [f] : [];
  });
  return h(
    "article",
    { class: `circuit${c.latent ? " latent" : ""}${needs.length > 6 ? " tall" : ""}` },
    h(
      "div",
      { class: "claim-head", onclick: clickToOpen(open) },
      h(
        "span",
        { class: "claim-words" },
        claimTag(c, open, `claim:${c.id}`, false),
        h("span", { class: "sentence" }, headline(c)),
      ),
    ),
    exactStatement(c),
    conditions(c, ix, on),
    listOf(
      h("ul", { class: "contacts", "aria-label": `Facts that ${c.id} needs` }),
      needs,
      (f) => contact(f, on, c.id),
      {
        noun: ["fact", "facts"],
        keyOf: (f) => f.id,
        // The wire runs on past an end line, toward the lamp.
        endClass: "wire-end",
        tail: h(
          "li",
          { class: "terminal" },
          lamp(c.final),
          h(
            "button",
            {
              class: "contact-label",
              "data-key": `terminal:${c.id}`,
              type: "button",
              onclick: () => on.select("claim", c.id),
            },
            h("strong", {}, c.id),
            h("span", { class: "contact-kind" }, word(levels, c.level)),
          ),
        ),
      },
    ),
  );
}

/** Draws a card selected or not: its border + its id button's pressed state.
 * @param {HTMLElement} card @param {boolean} selected */
export function markCard(card, selected) {
  card.classList.toggle("selected", selected);
  card.querySelector(".claim-head .tag-id .ref")?.setAttribute("aria-pressed", String(selected));
}

/**
 * Everything a claim's card and text row show, as one string: equal strings, equal elements
 * (kernel.md U-update: the claim, each fact it names, their what-if controls, the exclusions it
 * names + its excluded pairs).
 * @param {Claim} c @param {Lookups} ix @param {Handlers} on
 */
export function claimSig(c, ix, on) {
  const facts = [...new Set([...drawn(c), ...c.blockers, ...c.gaps, ...c.premises])].map((id) => {
    const f = ix.facts.get(id);
    return f
      ? [
          f.id,
          f.effective,
          f.supposed,
          f.kind,
          f.text,
          f.why,
          on.canToggle(id),
          on.supposeStatus(id),
        ]
      : [id];
  });
  const pairs = on.pairsOf(c.id) ?? [];
  const conflicts = ix.subjects.get(c.subject)?.conflicts ?? [];
  const exclusions = [...pairs, ...conflicts].map((id) => {
    const x = ix.exclusions.get(id);
    return x ? [x.id, x.text, x.between] : [id];
  });
  return JSON.stringify([c, facts, pairs, conflicts, exclusions]);
}

/**
 * What a claim waits on, from the engine's lists: violated facts, open facts, then assumptions,
 * one fact per line with its switch drawing. The claim's own words stay the headline.
 * @param {Claim} c @param {Lookups} ix @param {Pick<Handlers, "select" | "pairsOf">} on
 */
export function conditions(c, ix, on) {
  /** @param {string} id */
  const factRef = (id) =>
    h(
      "button",
      {
        class: "ref",
        type: "button",
        "data-key": `cond:${c.id}:${id}`,
        onclick: () => on.select("fact", id),
      },
      id,
    );
  /** @param {string} id */
  const factLine = (id) => {
    const f = ix.facts.get(id);
    return h(
      "li",
      {},
      h(
        "span",
        { class: `switch ${f?.effective ?? "open"}`, "aria-hidden": "true" },
        switchSvg(f?.effective ?? "open"),
      ),
      factRef(id),
      h("span", {}, f?.text ?? id),
      f?.why ? h("span", { class: "conditions-why" }, `Why it is needed: ${f.why}`) : null,
    );
  };
  // A claim is also not possible with no false fact: the engine names the exclusions it needs both
  // sides of (`incompatible`) and the ones a what-if supposes both sides of (`conflicts`).
  /** @param {string} id @param {string} who */
  const exclusionLine = (id, who) => {
    const x = ix.exclusions.get(id);
    const [a = "", b = ""] = x?.between ?? [];
    return h(
      "li",
      {},
      h("span", { class: "switch", "aria-hidden": "true" }),
      h("strong", { class: "exclusion-id" }, id),
      h("span", {}, x?.text ?? id),
      h(
        "span",
        { class: "conditions-why" },
        `${who} `,
        factRef(a),
        " and ",
        factRef(b),
        ", which exclude each other.",
      ),
    );
  };
  // The excluded pairs a claim needs arrive with its details (kernel.md V-details; user ruling:
  // lists on request); the subject's conflicts sit on the subject (one copy per subject).
  const pairs = on.pairsOf(c.id) ?? [];
  const paired = new Set(pairs);
  const conflicts = (ix.subjects.get(c.subject)?.conflicts ?? []).filter((id) => !paired.has(id));
  /** @typedef {{ fact: string } | { pair: string } | { conflict: string }} Line */
  /** @type {[string, Line[]][]} */
  const parts = [
    [
      "Cannot stand because",
      [
        ...c.blockers.map((fact) => ({ fact })),
        ...pairs.map((pair) => ({ pair })),
        ...conflicts.map((conflict) => ({ conflict })),
      ],
    ],
    ["Still open", c.gaps.map((fact) => ({ fact }))],
    [
      c.final === "conditional" ? "Holds only if" : "Also assumes",
      c.premises.map((fact) => ({ fact })),
    ],
  ];
  const shown = parts.filter(([, lines]) => lines.length);
  if (!shown.length) return null;
  return h(
    "div",
    { class: "conditions" },
    shown.map(([label, lines]) => [
      h("p", { class: "conditions-label" }, label),
      listOf(
        h("ul", { class: "conditions-list" }),
        lines,
        (l) =>
          "fact" in l
            ? factLine(l.fact)
            : "pair" in l
              ? exclusionLine(l.pair, `${c.id} needs`)
              : exclusionLine(l.conflict, "The what-if supposes"),
        {
          noun: ["fact", "facts"],
          keyOf: (l) => ("fact" in l ? l.fact : "pair" in l ? l.pair : l.conflict),
        },
      ),
    ]),
  );
}
