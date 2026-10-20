// Claim circuits: a claim is a lamp fed through one switch per fact it needs, in series. Every
// switch must close for the lamp to light; one broken switch blocks it.

import { h, s } from "./dom.js";
import { kinds, statuses, symbols, word } from "./words.js";

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
function switchSvg(status) {
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
 * A claim's circuit card.
 * @param {Claim} c @param {Envelope} env @param {Handlers} on @param {boolean} selected
 */
export function circuit(c, env, on, selected) {
  const facts = new Map(env.facts.map((f) => [f.id, f]));
  const needs = [...c.needs, c.entailment].flatMap((id) => {
    const f = facts.get(id);
    return f ? [f] : [];
  });
  const qualifiers = c.qualifiers.length ? ` (${c.qualifiers.join(", ")})` : "";
  return h(
    "article",
    {
      class: `circuit${c.latent ? " latent" : ""}${selected ? " selected" : ""}${
        needs.length > 6 ? " tall" : ""
      }`,
    },
    h(
      "button",
      {
        class: "claim-head",
        "data-key": `claim:${c.id}`,
        type: "button",
        "aria-pressed": selected ? "true" : "false",
        onclick: () => on.select("claim", c.id),
      },
      lamp(c.final, "large"),
      h(
        "span",
        {},
        h(
          "span",
          { class: "claim-meta" },
          `${c.id} / ${c.level}${c.latent ? " / overlooked direction" : ""}`,
        ),
        h("span", { class: "sentence" }, c.sentence),
        h("span", { class: `claim-state ${c.final}` }, `${c.verdict}${qualifiers}`),
      ),
    ),
    h(
      "ul",
      { class: "contacts", "aria-label": `Facts that ${c.id} needs` },
      needs.map((f) => contact(f, on, c.id)),
      h(
        "li",
        { class: "terminal", "aria-hidden": "true" },
        lamp(c.final),
        h("small", { class: "terminal-label" }, c.verdict),
      ),
    ),
  );
}
