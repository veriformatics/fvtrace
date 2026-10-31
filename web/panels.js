// The inspector, the ranked lists and the text view: each shows envelope fields as they are.

import { claimTag, conditions, exactStatement, headline, lamp } from "./circuit.js";
import { clickToOpen, h, idButton, s } from "./dom.js";
import { listOf } from "./lazy.js";
import {
  andList,
  count,
  efforts,
  failEnding,
  kinds,
  lintNeeds,
  routes,
  statuses,
  verdicts,
  word,
} from "./words.js";

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {import("./envelope.js").Experiment} Experiment */
/** @typedef {import("./envelope.js").Move} Move */
/** @typedef {import("./envelope.js").Override} Override */
/** @typedef {import("./envelope.js").Plan} Plan */
/** @typedef {import("./envelope.js").Alternative} Alternative */
/** @typedef {import("./dom.js").Children} Children */
/** @typedef {import("./envelope.js").Details} Details */
/** @typedef {import("./app.js").DetailsView} DetailsView */
/** @typedef {import("./lookups.js").Lookups} Lookups */

/**
 * @typedef {{ select: (kind: "fact" | "claim" | "experiment", id: string) => void,
 *   toggle: (fact: string) => void, canToggle: (fact: string) => boolean,
 *   supposeStatus: (fact: string) => string | undefined,
 *   apply: (action: string) => void, hasAction: (action: string) => boolean,
 *   pairsOf: (claim: string) => string[] | undefined }} Handlers
 */

/** A link-styled button that selects `id`. @param {Handlers} on */
function ref(/** @type {"fact" | "claim" | "experiment"} */ kind, /** @type {string} */ id, on) {
  return h(
    "button",
    {
      class: "ref",
      "data-key": `ref:${kind}:${id}`,
      type: "button",
      onclick: () => on.select(kind, id),
    },
    id,
  );
}

/** Each kind's word, singular + plural. */
const nouns = {
  fact: /** @type {[string, string]} */ (["fact", "facts"]),
  claim: /** @type {[string, string]} */ (["claim", "claims"]),
  experiment: /** @type {[string, string]} */ (["experiment", "experiments"]),
};

/** `O1, O2` as selectable references (a long run mounts as it nears the viewport).
 * @param {string[]} ids @param {Handlers} on */
function refs(/** @type {"fact" | "claim" | "experiment"} */ kind, ids, on) {
  return listOf(
    h("span", { class: "refs" }),
    ids,
    (id, i) => h("span", {}, i ? ", " : "", ref(kind, id, on)),
    { noun: nouns[kind] },
  );
}

/** @param {Lookups} ix @param {string} id */
function factText(ix, id) {
  return ix.facts.get(id)?.text ?? id;
}

/** @param {string} label @param {string} action @param {Handlers} on @param {boolean} [primary] */
function actionButton(label, action, on, primary = true) {
  return on.hasAction(action)
    ? h(
        "button",
        {
          class: primary ? "action" : "action secondary",
          "data-key": `action:${action}`,
          type: "button",
          onclick: () => on.apply(action),
        },
        label,
      )
    : null;
}

/** @param {Move[]} ms @param {Lookups} ix @param {Handlers} on @param {string} none */
function moveList(ms, ix, on, none) {
  if (!ms.length) return h("p", { class: "note" }, none);
  return listOf(
    h("ul", { class: "moves" }),
    ms,
    (m) => {
      const c = ix.claims.get(m.claim);
      return h(
        "li",
        {},
        lamp(m.to, "small"),
        h(
          "span",
          {},
          ref("claim", m.claim, on),
          ` changes from ${word(verdicts, m.from)} to ${word(verdicts, m.to)}`,
          c ? h("small", { class: "move-text" }, headline(c)) : null,
        ),
      );
    },
    { noun: nouns.claim },
  );
}

/** @param {Override[]} os @param {Lookups} ix @param {Handlers} on */
function changeList(os, ix, on) {
  return listOf(
    h("ul", { class: "changes" }),
    os,
    (o) =>
      h(
        "li",
        {},
        ref("fact", o.fact, on),
        ` becomes ${word(statuses, o.status).toLowerCase()}: `,
        h("span", { class: "quote" }, factText(ix, o.fact)),
      ),
    { noun: nouns.fact },
  );
}

/** The line in place of a detail section the page's engine cannot answer (user ruling). */
const detailsOff =
  "This browser cannot run the what-ifs on this page, so it cannot show these details.";

/**
 * A detail section from the selection's details (kernel.md V-details): its content once ready,
 * the engine-off line or the refusal, nothing while pending (the inspector reads as busy).
 * @param {DetailsView | undefined} d @param {(v: Details) => Children} show
 * @returns {Children}
 */
function detailed(d, show) {
  if (d?.state === "ready" && d.value) return show(d.value);
  if (d?.state === "off") return h("p", { class: "note" }, detailsOff);
  if (d?.state === "problem") return h("p", { class: "note" }, d.message ?? "");
  return null;
}

/**
 * The page line under the review line: every replay notice (kernel.md § Replay, Notice), facts as
 * references, exclusions as plain ids (they have no details).
 * @param {import("./envelope.js").Notice[]} ns @param {Lookups} ix @param {Handlers} on
 * @returns {Children}
 */
export function noticeLine(ns, ix, on) {
  const ids = ns.map((n) => (ix.facts.has(n.id) ? ref("fact", n.id, on) : n.id));
  const facts = ns.filter((n) => ix.facts.has(n.id));
  const lone = ns.length === 1 ? facts[0] : undefined;
  const open = lone
    ? ` Open ${lone.id} to see when and why.`
    : facts.length
      ? " Open a fact to see when and why."
      : "";
  return ns.length === 1
    ? [h("strong", {}, ids[0] ?? "", "'s check was run again and failed."), open]
    : [h("strong", {}, "The checks of ", ...andList(ids), " were run again and failed."), open];
}

/** @param {Lookups} ix @param {string} id @param {Handlers} on @param {DetailsView} [d] */
function inspectFact(ix, id, on, d) {
  const f = ix.facts.get(id);
  if (!f) return [h("p", {}, `No fact ${id}.`)];
  const neededBy = ix.neededBy.get(id) ?? [];
  const status =
    f.effective === f.recorded
      ? word(statuses, f.effective)
      : `${word(statuses, f.effective)} (recorded: ${word(statuses, f.recorded).toLowerCase()})`;
  return [
    h("span", { class: "reference" }, `Fact ${f.id} / ${word(kinds, f.kind)}`),
    h("h2", { class: "fact" }, f.text),
    h("span", { class: `status-label ${f.effective}` }, status),
    f.why ? h("p", {}, `Why it is needed: ${f.why}`) : null,
    f.supposed ? h("p", { class: "note" }, "Supposed in the current what-if, not recorded.") : null,
    f.derivedFrom.length
      ? h(
          "p",
          {},
          "Violated because ",
          f.derivedFrom.flatMap((w, i) => [
            i ? "; " : "",
            ref("fact", w.source, on),
            ` is verified and exclusion ${w.exclusion} rules out both.`,
          ]),
        )
      : null,
    f.instantiates
      ? h("p", {}, "It carries fact ", ref("fact", f.instantiates, on), " over to this subject.")
      : null,
    h("h3", {}, "How it can be established"),
    h("p", {}, word(routes, f.route)),
    f.evidence
      ? [
          h("h3", {}, "Evidence"),
          h("p", {}, f.evidence.summary),
          f.evidence.artifacts.length
            ? listOf(h("ul", {}), f.evidence.artifacts, (a) =>
                h("li", {}, h("code", {}, a.path), a.role ? ` (${a.role})` : ""),
              )
            : null,
          f.evidence.verifier ? h("p", {}, `Verifier: ${f.evidence.verifier}`) : null,
          f.evidence.statement ? h("p", {}, `Statement: ${f.evidence.statement}`) : null,
        ]
      : null,
    f.receipt
      ? h(
          "p",
          { class: f.receipt.current ? "note" : "warning" },
          f.receipt.current
            ? "The receipt matches the project folder."
            : `The receipt no longer matches: ${f.receipt.reasons.join(", ")}.`,
        )
      : null,
    f.evidence?.replay?.failed
      ? h(
          "p",
          { class: "warning" },
          `Its check was run again on ${f.evidence.replay.failed.date} and failed: `,
          failEnding(f.evidence.replay.failed.reason),
        )
      : null,
    f.trusts.length
      ? [h("h3", {}, "Trusted base"), listOf(h("ul", {}), f.trusts, (t) => h("li", {}, t))]
      : null,
    h("h3", {}, "Needed by"),
    neededBy.length
      ? h(
          "p",
          {},
          refs(
            "claim",
            neededBy.map((c) => c.id),
            on,
          ),
        )
      : h("p", {}, "No claim."),
    detailed(d, (v) =>
      v.raisedBy?.length
        ? [h("h3", {}, "Experiments that raise it"), h("p", {}, refs("experiment", v.raisedBy, on))]
        : null,
    ),
    on.canToggle(f.id)
      ? h(
          "button",
          {
            class: "action",
            "data-key": "action:toggle",
            type: "button",
            onclick: () => on.toggle(f.id),
          },
          f.supposed
            ? "Restore the recorded status"
            : `Suppose it is ${on.supposeStatus(f.id) ?? "verified"}`,
        )
      : null,
  ];
}

/** Every suggested experiment that raises each unverified need (the plan picks among them). */
/** @param {Plan} p @param {Handlers} on */
function alternatives(p, on) {
  if (!p.alternatives.length) return null;
  /** @type {Map<string, Alternative[]>} */
  const byNeed = new Map();
  for (const a of p.alternatives) {
    const list = byNeed.get(a.need);
    if (list) list.push(a);
    else byNeed.set(a.need, [a]);
  }
  return [
    h("h3", {}, "Experiments for each fact"),
    listOf(
      h("ul", { class: "changes" }),
      [...byNeed],
      ([n, alts]) =>
        h(
          "li",
          {},
          ref("fact", n, on),
          ": ",
          alts.flatMap((a, i) => [
            i ? ", " : "",
            ref("experiment", a.experiment, on),
            ` sets ${a.status}`,
          ]),
        ),
      { noun: nouns.fact },
    ),
  ];
}

/** @param {Claim} c @param {Plan} p @param {Handlers} on @param {Lookups} ix */
function planSection(c, p, on, ix) {
  const closable = (/** @type {string} */ id) => ix.facts.get(id)?.closable === true;
  const isViolated = (/** @type {string} */ id) => ix.facts.get(id)?.effective === "violated";
  const violated = p.uncovered.filter(isViolated);
  const raisable = p.uncovered.filter(closable);
  const settled = p.uncovered.filter((id) => !closable(id) && !isViolated(id));
  const uncovered = [
    violated.length
      ? h(
          "p",
          { class: "note" },
          "Violated: ",
          refs("fact", violated, on),
          ". Reword the claim, or collect new data.",
        )
      : null,
    raisable.length
      ? h(
          "p",
          { class: "note" },
          "No suggested experiment raises ",
          refs("fact", raisable, on),
          raisable.length === 1
            ? ". It needs a new experiment or a ruling."
            : ". They need a new experiment or a ruling.",
        )
      : null,
    settled.length
      ? h(
          "p",
          { class: "note" },
          "Stays as it is: ",
          refs("fact", settled, on),
          " (no route allows a stronger status).",
        )
      : null,
  ];
  if (p.result === "planned") {
    return [
      h(
        "p",
        {},
        "Run ",
        refs("experiment", p.experiments, on),
        `. If the plan succeeds, the claim reads ${word(verdicts, p.state ?? "")}.`,
      ),
      h("p", { class: "note" }, "The plan shows coverage, not scientific priority."),
      p.contingent
        ? h("p", { class: "note" }, "It holds only if the planned result is observed.")
        : null,
      p.planPremises.length
        ? h("p", {}, "Still assumed after the plan: ", refs("fact", p.planPremises, on), ".")
        : null,
      p.planGaps.length
        ? h("p", {}, "Still open after the plan: ", refs("fact", p.planGaps, on), ".")
        : null,
      alternatives(p, on),
      uncovered,
      actionButton("Suppose the plan succeeds", `plan:${c.id}`, on),
    ];
  }
  if (p.result === "noImprovement") {
    return [h("p", {}, "No set of suggested experiments raises this claim."), uncovered];
  }
  if (p.result === "inconsistent") {
    return [h("p", {}, "The what-if conflicts on this subject, so no plan applies.")];
  }
  return [h("p", {}, "Too many suggested experiments apply: no best plan is claimed.")];
}

/** @param {Lookups} ix @param {string} id @param {Handlers} on @param {DetailsView} [d] */
function inspectClaim(ix, id, on, d) {
  const c = ix.claims.get(id);
  if (!c) return [h("p", {}, `No claim ${id}.`)];
  const conflicts = ix.subjects.get(c.subject)?.conflicts ?? [];
  const waivers = (ix.lintsOf.get(c.id) ?? []).filter((l) => l.waived !== undefined);
  /** @type {[string, string[]][]} */
  const parts = [
    ["Verified", c.verified],
    ["Assumed", c.premises],
    ["Gaps", c.gaps],
    ["Violated", c.blockers],
  ];
  return [
    claimTag(c),
    h("h2", {}, headline(c)),
    c.headline && c.headline !== c.text
      ? h("p", { class: "exact-text" }, h("strong", {}, "Exact statement: "), c.text)
      : null,
    h(
      "dl",
      { class: "breakdown" },
      parts.flatMap(([label, ids]) =>
        ids.length ? [h("dt", {}, label), h("dd", {}, refs("fact", ids, on))] : [],
      ),
    ),
    detailed(d, (v) =>
      v.incompatible?.length
        ? h(
            "p",
            { class: "warning" },
            `Needs both sides of exclusion ${v.incompatible.join(", ")}.`,
          )
        : null,
    ),
    conflicts.length
      ? h(
          "p",
          { class: "warning" },
          `The what-if conflicts on this subject (${conflicts.join(", ")}).`,
        )
      : null,
    waivers.length
      ? [
          h("h3", {}, "Not needed"),
          waivers.map((l) =>
            h(
              "p",
              {},
              h("strong", {}, lintNeeds[l.rule] ? `Not needed: ${lintNeeds[l.rule]}.` : l.message),
              ` Reason: ${l.waived ?? ""}`,
            ),
          ),
        ]
      : null,
    c.final === "can"
      ? null
      : [h("h3", {}, "Plan"), detailed(d, (v) => (v.plan ? planSection(c, v.plan, on, ix) : null))],
  ];
}

/** Dry = a monitor (existing data, code, proofs); wet = a flask (new samples, bench work). */
const kindIcons = {
  dry: () =>
    s(
      "svg",
      { viewBox: "0 0 20 20", "aria-hidden": "true", focusable: "false" },
      s("rect", { x: "2.5", y: "3.5", width: "15", height: "10", rx: "1" }),
      s("path", { d: "M7 17.5h6M10 13.5v4M6 7l2 1.5L6 10M10 10h3" }),
    ),
  wet: () =>
    s(
      "svg",
      { viewBox: "0 0 20 20", "aria-hidden": "true", focusable: "false" },
      s("path", {
        d: "M7.5 2.5h5M8.5 2.5v5L4 16a1.2 1.2 0 0 0 1 1.5h10a1.2 1.2 0 0 0 1-1.5L11.5 7.5v-5M6 12.5h8",
      }),
    ),
};

/** @param {Experiment} e */
export function kindTag(e) {
  return h(
    "span",
    { class: `kind ${e.kind}` },
    kindIcons[e.kind](),
    e.kind === "dry" ? "Dry experiment" : "Wet experiment",
  );
}

/** @param {Lookups} ix @param {string} id @param {Handlers} on @param {DetailsView} [d] */
function inspectExperiment(ix, id, on, d) {
  const e = ix.experiments.get(id);
  if (!e) return [h("p", {}, `No experiment ${id}.`)];
  return [
    h("span", { class: "reference" }, `Experiment ${e.id}`),
    h("p", { class: "inspector-kind" }, kindTag(e)),
    h("h2", {}, e.title),
    h("p", { class: "effort" }, `${word(efforts, e.effort)} of work.`),
    e.prospective
      ? h(
          "p",
          { class: "new-data" },
          e.creates
            ? "It creates new data: claims about that data can rise; the existing analysis keeps its gaps."
            : "It works on new data that another experiment creates; the existing analysis keeps its gaps.",
        )
      : null,
    detailed(d, (v) => {
      const first = (v.closure ?? []).filter((x) => x !== e.id);
      return first.length ? h("p", {}, "Runs after ", refs("experiment", first, on), ".") : null;
    }),
    h("h3", {}, "Method"),
    h("p", {}, e.method),
    h("h3", {}, "Resources"),
    h("p", {}, e.resources),
    h("h3", {}, e.contingent ? "If it succeeds and the result is observed" : "If it succeeds"),
    detailed(d, (v) => [
      v.raises?.length
        ? changeList(v.raises, ix, on)
        : h("p", {}, "No fact rises: each one already has this status or a stronger one."),
      moveList(v.wins ?? [], ix, on, "No claim changes."),
    ]),
    actionButton("Suppose it succeeds", `success:${e.id}`, on),
    e.failure.length
      ? [
          h("h3", {}, "If it fails"),
          changeList(e.failure, ix, on),
          detailed(d, (v) => moveList(v.losses ?? [], ix, on, "No claim changes.")),
          actionButton("Suppose it fails", `failure:${e.id}`, on, false),
        ]
      : null,
    h("h3", {}, "Limits"),
    h("p", {}, e.caveat),
  ];
}

/**
 * @param {Lookups} ix
 * @param {{ kind: "fact" | "claim" | "experiment", id: string } | undefined} sel
 * @param {Handlers} on
 * @param {DetailsView} [d] the selection's details for the shown view
 */
export function inspector(ix, sel, on, d) {
  if (!sel) {
    return [
      h("h2", {}, "Select a claim, a fact or an experiment"),
      h(
        "p",
        {},
        "Pressing a fact's symbol supposes it at the best status that its route allows. Pressing its name shows the fact, its evidence and how it can be established.",
      ),
    ];
  }
  if (sel.kind === "fact") return inspectFact(ix, sel.id, on, d);
  if (sel.kind === "claim") return inspectClaim(ix, sel.id, on, d);
  return inspectExperiment(ix, sel.id, on, d);
}

/** @param {Experiment} e */
function impact(e) {
  const parts = [];
  if (e.lights) parts.push(`lights ${count(e.lights, "claim", "claims")}`);
  if (e.clears) parts.push(`clears ${count(e.clears, "block", "blocks")}`);
  if (e.lowers) parts.push(`lowers ${count(e.lowers, "claim", "claims")}`);
  if (e.breaks) parts.push(`can break ${count(e.breaks, "claim", "claims")}`);
  const text = parts.length ? parts.join(", ") : "no claim changes if it succeeds";
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** One experiment's card in the experiments list (its selection is drawn apart: `markRow`).
 * @param {Experiment} e @param {Handlers} on */
export function experimentRow(e, on) {
  return h(
    "li",
    {
      class: "experiment-row",
      onclick: clickToOpen(() => on.select("experiment", e.id)),
    },
    kindTag(e),
    h("span", { class: "experiment-title" }, e.title),
    h(
      "small",
      { class: "experiment-meta" },
      idButton(e.id, `experiment:${e.id}`, () => on.select("experiment", e.id), false),
      ` / ${word(efforts, e.effort)}${e.creates ? " / creates new data" : e.prospective ? " / on new data" : ""}`,
    ),
    h("span", { class: `impact${e.lights ? " lit" : ""}` }, impact(e)),
  );
}

/** Draws an experiment card selected or not. @param {HTMLElement} row @param {boolean} selected */
export function markRow(row, selected) {
  row.classList.toggle("selected", selected);
  row.querySelector(".experiment-meta .ref")?.setAttribute("aria-pressed", String(selected));
}

/** The line in place of an empty experiments list. */
export const noExperiments = () => h("li", {}, "No suggested experiment of this kind.");

/** The line in place of an empty work list. */
export const noWork = () =>
  h(
    "li",
    {},
    "No fact that a claim needs can rise further: each one is violated or has the strongest status that its route allows.",
  );

/**
 * One fact's row in "Facts that make the most claims available"; `counted` = some row shows a
 * count (a zero row keeps the column).
 * @param {import("./envelope.js").Envelope["work"][number]} w @param {Lookups} ix
 * @param {Handlers} on @param {boolean} counted
 */
export function workRow(w, ix, on, counted) {
  return h(
    "li",
    { class: "work-item", onclick: clickToOpen(() => on.select("fact", w.fact)) },
    counted
      ? h(
          "span",
          { class: `work-count${w.unlocks.length ? "" : " none"}`, "aria-hidden": "true" },
          w.unlocks.length ? String(w.unlocks.length) : "",
        )
      : null,
    h(
      "span",
      {},
      h(
        "strong",
        {},
        idButton(w.fact, `work:${w.fact}`, () => on.select("fact", w.fact)),
      ),
      ` ${factText(ix, w.fact)}`,
      h(
        "small",
        { class: "list-meta" },
        w.unlocks.length
          ? `Makes ${count(w.unlocks.length, "claim", "claims")} available alone.`
          : null,
        togetherWith(ix, w, on),
      ),
    ),
  );
}

/** What a work row shows (its fact's text, each gated claim's gaps + final state).
 * @param {import("./envelope.js").Envelope["work"][number]} w @param {Lookups} ix
 * @param {boolean} counted */
export function workSig(w, ix, counted) {
  const gates = w.gates.map((id) => {
    const c = ix.claims.get(id);
    return c ? [c.final, c.gaps] : [];
  });
  return JSON.stringify([w, factText(ix, w.fact), gates, counted]);
}

/**
 * Each claim that needs a work fact without being made available by it alone, with what that
 * claim needs together with it (its other gaps, from the engine's lists).
 * @param {Lookups} ix @param {import("./envelope.js").Envelope["work"][number]} w
 * @param {Handlers} on
 */
function togetherWith(ix, w, on) {
  const unlocks = new Set(w.unlocks);
  return w.gates
    .filter((id) => !unlocks.has(id))
    .map((id, i) => {
      const c = ix.claims.get(id);
      const others = (c?.gaps ?? []).filter((f) => f !== w.fact);
      // A long run mounts as it comes near (U-long), commas alone.
      const together = others.length
        ? [
            ", together with ",
            others.length > 40
              ? refs("fact", others, on)
              : andList(others.map((f) => ref("fact", f, on))),
          ]
        : null;
      const tail =
        c?.final === "cannot"
          ? together
            ? [together, `, but ${id} is not possible as worded`]
            : ", which is not possible as worded"
          : c?.final === "conditional"
            ? ", which holds only if it is true"
            : together;
      return [i || w.unlocks.length ? " " : "", "Needed by ", ref("claim", id, on), tail, "."];
    });
}

/** @param {import("./envelope.js").Envelope["blockers"][number]} b @param {Lookups} ix
 * @param {Handlers} on */
export function blockerRow(b, ix, on) {
  return h(
    "li",
    { class: "plain-row" },
    ref("fact", b.fact, on),
    ` ${factText(ix, b.fact)} `,
    h("small", { class: "list-meta" }, "Blocks ", refs("claim", b.claims, on), "."),
  );
}

/** @param {import("./envelope.js").Envelope["lints"][number]} l @param {Handlers} on */
export function checkRow(l, on) {
  // The engine's message opens with its claim's id: that id becomes the link, once.
  const rest = l.message.startsWith(`${l.claim} `)
    ? l.message.slice(l.claim.length)
    : ` ${l.message}`;
  return h("li", { class: "plain-row" }, ref("claim", l.claim, on), rest);
}

/** A group's heading + count; an untitled group has none. @param {string} title @param {number} n */
export const groupTitle = (title, n) =>
  title
    ? h("h3", { class: "group-title" }, title, h("span", { class: "group-count" }, ` ${n}`))
    : null;

/**
 * One claim's row in the text view: its label, headline, exact statement + what it waits on.
 * @param {Claim} c @param {Lookups} ix @param {Handlers} on
 */
export function textRow(c, ix, on) {
  return h(
    "li",
    { class: "text-row", onclick: clickToOpen(() => on.select("claim", c.id)) },
    h(
      "span",
      { class: "claim-words" },
      claimTag(c, () => on.select("claim", c.id), `text:${c.id}`),
      h("span", { class: "text-sentence" }, headline(c)),
      exactStatement(c),
      conditions(c, ix, on),
    ),
  );
}

/**
 * One open fact's row under "Facts to verify" in the text view.
 * @param {string} id @param {Lookups} ix @param {Handlers} on
 */
export function openFactRow(id, ix, on) {
  const f = ix.facts.get(id);
  const raisers = ix.raiserCount.get(id) ?? 0;
  return h(
    "li",
    { class: "text-row stacked", onclick: clickToOpen(() => on.select("fact", id)) },
    h(
      "span",
      { class: "text-sentence" },
      idButton(id, `text:${id}`, () => on.select("fact", id)),
      ` ${f?.text ?? ""}`,
    ),
    h(
      "small",
      { class: "list-meta" },
      `${word(statuses, f?.effective ?? "open")}. ${word(routes, f?.route ?? "")}. ${count(raisers, "suggested experiment", "suggested experiments")}.`,
    ),
  );
}

/** What an open fact's row shows. @param {string} id @param {Lookups} ix */
export function openFactSig(id, ix) {
  const f = ix.facts.get(id);
  return JSON.stringify([id, f?.text, f?.effective, f?.route, ix.raiserCount.get(id) ?? 0]);
}
