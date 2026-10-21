// Claim circuits: a claim is a lamp fed through one switch per fact it needs, in series. Every
// switch must close for the lamp to light; one broken switch blocks it.

import { clickToOpen, h, idButton, s } from "./dom.js";
import { kinds, levels, qualifiers, statuses, symbols, word } from "./words.js";

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {import("./envelope.js").Fact} Fact */

/**
 * What a circuit can ask the app to do.
 * @typedef {{ select: (kind: "fact" | "claim" | "experiment", id: string) => void,
 *   toggle: (fact: string) => void, canToggle: (fact: string) => boolean,
 *   supposeStatus: (fact: string) => string | undefined }} Handlers
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

/**
 * A claim's circuit card.
 * @param {Claim} c @param {Envelope} env @param {Handlers} on @param {boolean} selected
 */
export function circuit(c, env, on, selected) {
  const facts = new Map(env.facts.map((f) => [f.id, f]));
  const open = () => on.select("claim", c.id);
  const needs = [...c.needs, c.entailment].flatMap((id) => {
    const f = facts.get(id);
    return f ? [f] : [];
  });
  return h(
    "article",
    {
      class: `circuit${c.latent ? " latent" : ""}${selected ? " selected" : ""}${
        needs.length > 6 ? " tall" : ""
      }`,
    },
    h(
      "div",
      { class: "claim-head", onclick: clickToOpen(open) },
      h(
        "span",
        { class: "claim-words" },
        claimTag(c, open, `claim:${c.id}`, selected),
        h("span", { class: "sentence" }, headline(c)),
      ),
    ),
    exactStatement(c),
    conditions(c, env, on),
    h(
      "ul",
      { class: "contacts", "aria-label": `Facts that ${c.id} needs` },
      needs.map((f) => contact(f, on, c.id)),
      h(
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
    ),
  );
}

/**
 * What a claim waits on, from the engine's lists: violated facts, open facts, then assumptions,
 * one fact per line with its switch drawing. The claim's own words stay the headline.
 * @param {Claim} c @param {Envelope} env @param {Pick<Handlers, "select">} on
 */
export function conditions(c, env, on) {
  const facts = new Map(env.facts.map((f) => [f.id, f]));
  /** @type {[string, string[]][]} */
  const parts = [
    ["Cannot stand because", c.blockers],
    ["Still open", c.gaps],
    [c.final === "conditional" ? "Holds only if" : "Also assumes", c.premises],
  ];
  const shown = parts.filter(([, ids]) => ids.length);
  if (!shown.length) return null;
  return h(
    "div",
    { class: "conditions" },
    shown.map(([label, ids]) => [
      h("p", { class: "conditions-label" }, label),
      h(
        "ul",
        { class: "conditions-list" },
        ids.map((id) => {
          const f = facts.get(id);
          return h(
            "li",
            {},
            h(
              "span",
              { class: `switch ${f?.effective ?? "open"}`, "aria-hidden": "true" },
              switchSvg(f?.effective ?? "open"),
            ),
            h(
              "button",
              {
                class: "ref",
                type: "button",
                "data-key": `cond:${c.id}:${id}`,
                onclick: () => on.select("fact", id),
              },
              id,
            ),
            h("span", {}, f?.text ?? id),
            f?.why ? h("span", { class: "conditions-why" }, `Why it is needed: ${f.why}`) : null,
          );
        }),
      ),
    ]),
  );
}
