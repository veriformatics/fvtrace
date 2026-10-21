// The inspector, the ranked lists and the text view: each shows envelope fields as they are.

import { claimTag, claimWords, conditions, exactStatement, headline, lamp } from "./circuit.js";
import { clickToOpen, h, idButton, s } from "./dom.js";
import { count, efforts, kinds, routes, statuses, verdicts, word } from "./words.js";

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {import("./envelope.js").Experiment} Experiment */
/** @typedef {import("./envelope.js").Move} Move */
/** @typedef {import("./envelope.js").Override} Override */

/**
 * @typedef {{ select: (kind: "fact" | "claim" | "experiment", id: string) => void,
 *   toggle: (fact: string) => void, canToggle: (fact: string) => boolean,
 *   supposeStatus: (fact: string) => string | undefined,
 *   apply: (action: string) => void, hasAction: (action: string) => boolean }} Handlers
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

/** `O1, O2` as selectable references. @param {string[]} ids @param {Handlers} on */
function refs(/** @type {"fact" | "claim" | "experiment"} */ kind, ids, on) {
  return ids.flatMap((id, i) => (i ? [", ", ref(kind, id, on)] : [ref(kind, id, on)]));
}

/** @param {Envelope} env @param {string} id */
function factText(env, id) {
  return env.facts.find((f) => f.id === id)?.text ?? id;
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

/** @param {Move[]} ms @param {Envelope} env @param {Handlers} on @param {string} none */
function moveList(ms, env, on, none) {
  if (!ms.length) return h("p", { class: "note" }, none);
  return h(
    "ul",
    { class: "moves" },
    ms.map((m) => {
      const c = env.claims.find((x) => x.id === m.claim);
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
    }),
  );
}

/** @param {Override[]} os @param {Envelope} env @param {Handlers} on */
function changeList(os, env, on) {
  return h(
    "ul",
    { class: "changes" },
    os.map((o) =>
      h(
        "li",
        {},
        ref("fact", o.fact, on),
        ` becomes ${word(statuses, o.status).toLowerCase()}: `,
        h("span", { class: "quote" }, factText(env, o.fact)),
      ),
    ),
  );
}

/** @param {Envelope} env @param {string} id @param {Handlers} on */
function inspectFact(env, id, on) {
  const f = env.facts.find((x) => x.id === id);
  if (!f) return [h("p", {}, `No fact ${id}.`)];
  const neededBy = env.claims.filter((c) => c.needs.includes(id) || c.entailment === id);
  const raisedBy = env.experiments.filter((e) => e.raises.some((o) => o.fact === id));
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
          f.derivedFrom.flatMap((d, i) => [
            i ? "; " : "",
            ref("fact", d.source, on),
            ` is verified and exclusion ${d.exclusion} rules out both.`,
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
            ? h(
                "ul",
                {},
                f.evidence.artifacts.map((a) =>
                  h("li", {}, h("code", {}, a.path), a.role ? ` (${a.role})` : ""),
                ),
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
    f.trusts.length
      ? [
          h("h3", {}, "Trusted base"),
          h(
            "ul",
            {},
            f.trusts.map((t) => h("li", {}, t)),
          ),
        ]
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
    raisedBy.length
      ? [
          h("h3", {}, "Experiments that raise it"),
          h(
            "p",
            {},
            refs(
              "experiment",
              raisedBy.map((e) => e.id),
              on,
            ),
          ),
        ]
      : null,
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
/** @param {Claim["plan"]} p @param {Handlers} on */
function alternatives(p, on) {
  if (!p.alternatives.length) return null;
  const needs = [...new Set(p.alternatives.map((a) => a.need))];
  return [
    h("h3", {}, "Experiments for each fact"),
    h(
      "ul",
      { class: "changes" },
      needs.map((n) =>
        h(
          "li",
          {},
          ref("fact", n, on),
          ": ",
          p.alternatives
            .filter((a) => a.need === n)
            .flatMap((a, i) => [
              i ? ", " : "",
              ref("experiment", a.experiment, on),
              ` sets ${a.status}`,
            ]),
        ),
      ),
    ),
  ];
}

/** @param {Claim} c @param {Handlers} on @param {Envelope} env */
function planSection(c, on, env) {
  const p = c.plan;
  const closable = (/** @type {string} */ id) => env.facts.some((f) => f.id === id && f.closable);
  const raisable = p.uncovered.filter(closable);
  const settled = p.uncovered.filter((id) => !closable(id));
  const uncovered = [
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

/** @param {Envelope} env @param {string} id @param {Handlers} on */
function inspectClaim(env, id, on) {
  const c = env.claims.find((x) => x.id === id);
  if (!c) return [h("p", {}, `No claim ${id}.`)];
  /** @type {[string, string[]][]} */
  const parts = [
    ["Verified", c.verified],
    ["Assumed", c.premises],
    ["Gaps", c.gaps],
    ["Violated", c.blockers],
  ];
  return [
    claimTag(c),
    h("h2", {}, claimWords(c)),
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
    c.incompatible.length
      ? h("p", { class: "warning" }, `Needs both sides of exclusion ${c.incompatible.join(", ")}.`)
      : null,
    c.conflicts.length
      ? h(
          "p",
          { class: "warning" },
          `The what-if conflicts on this subject (${c.conflicts.join(", ")}).`,
        )
      : null,
    c.final === "can" ? null : [h("h3", {}, "Plan"), planSection(c, on, env)],
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

/** @param {Envelope} env @param {string} id @param {Handlers} on */
function inspectExperiment(env, id, on) {
  const e = env.experiments.find((x) => x.id === id);
  if (!e) return [h("p", {}, `No experiment ${id}.`)];
  const first = e.closure.filter((x) => x !== e.id);
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
    first.length ? h("p", {}, "Runs after ", refs("experiment", first, on), ".") : null,
    h("h3", {}, "Method"),
    h("p", {}, e.method),
    h("h3", {}, "Resources"),
    h("p", {}, e.resources),
    h("h3", {}, e.contingent ? "If it succeeds and the result is observed" : "If it succeeds"),
    e.raises.length
      ? changeList(e.raises, env, on)
      : h("p", {}, "No fact rises: each one already has this status or a stronger one."),
    moveList(e.wins, env, on, "No claim changes."),
    actionButton("Suppose it succeeds", `success:${e.id}`, on),
    e.failure.length
      ? [
          h("h3", {}, "If it fails"),
          changeList(e.failure, env, on),
          moveList(e.losses, env, on, "No claim changes."),
          actionButton("Suppose it fails", `failure:${e.id}`, on, false),
        ]
      : null,
    h("h3", {}, "Limits"),
    h("p", {}, e.caveat),
  ];
}

/**
 * @param {Envelope} env
 * @param {{ kind: "fact" | "claim" | "experiment", id: string } | undefined} sel
 * @param {Handlers} on
 */
export function inspector(env, sel, on) {
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
  if (sel.kind === "fact") return inspectFact(env, sel.id, on);
  if (sel.kind === "claim") return inspectClaim(env, sel.id, on);
  return inspectExperiment(env, sel.id, on);
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

/** @param {Envelope} env @param {"all" | "dry" | "wet"} filter @param {string | undefined} selected @param {Handlers} on */
export function experimentList(env, filter, selected, on) {
  const shown = env.experiments.filter((e) => filter === "all" || e.kind === filter);
  if (!shown.length) return [h("p", {}, "No suggested experiment of this kind.")];
  return shown.map((e) =>
    h(
      "div",
      {
        class: `experiment-row${selected === e.id ? " selected" : ""}`,
        onclick: clickToOpen(() => on.select("experiment", e.id)),
      },
      kindTag(e),
      h("span", { class: "experiment-title" }, e.title),
      h(
        "small",
        { class: "experiment-meta" },
        idButton(
          e.id,
          `experiment:${e.id}`,
          () => on.select("experiment", e.id),
          selected === e.id,
        ),
        ` / ${word(efforts, e.effort)}${e.creates ? " / creates new data" : e.prospective ? " / on new data" : ""}`,
      ),
      h("span", { class: `impact${e.lights ? " lit" : ""}` }, impact(e)),
    ),
  );
}

/** @param {Envelope} env @param {Handlers} on */
export function workList(env, on) {
  if (!env.work.length) {
    return [
      h(
        "p",
        {},
        "No fact that a claim needs can rise further: each one is violated or has the strongest status that its route allows.",
      ),
    ];
  }
  return env.work.map((w) =>
    h(
      "div",
      { class: "work-item", onclick: clickToOpen(() => on.select("fact", w.fact)) },
      h("span", { class: "work-count", "aria-hidden": "true" }, String(w.unlocks.length)),
      h(
        "span",
        {},
        h(
          "strong",
          {},
          idButton(w.fact, `work:${w.fact}`, () => on.select("fact", w.fact)),
        ),
        ` ${factText(env, w.fact)}`,
        h(
          "small",
          { class: "list-meta" },
          `Makes ${count(w.unlocks.length, "claim", "claims")} available alone. Needed by ${count(w.gates.length, "claim", "claims")}.`,
        ),
      ),
    ),
  );
}

/** @param {Envelope} env @param {Handlers} on */
export function blockerList(env, on) {
  return env.blockers.map((b) =>
    h(
      "li",
      { class: "plain-row" },
      ref("fact", b.fact, on),
      ` ${factText(env, b.fact)} `,
      h("small", { class: "list-meta" }, "Blocks ", refs("claim", b.claims, on), "."),
    ),
  );
}

/** @param {Envelope} env @param {Handlers} on */
export function checkList(env, on) {
  return env.lints.map((l) =>
    h(
      "li",
      { class: "plain-row" },
      ref("claim", l.claim, on),
      ` ${l.message}`,
      l.waived ? h("small", { class: "list-meta" }, `Waived: ${l.waived}`) : null,
    ),
  );
}

/** A group's heading + count; an untitled group has none. @param {string} title @param {Claim[]} cs */
export const groupTitle = (title, cs) =>
  title
    ? h("h3", { class: "group-title" }, title, h("span", { class: "group-count" }, ` ${cs.length}`))
    : null;

/**
 * The text view of one question: each group's sentences, then each open fact once.
 * @param {Envelope} env @param {[string, Claim[]][]} groups @param {Handlers} on
 */
export function textView(env, groups, on) {
  const claims = groups.flatMap(([, cs]) => cs);
  const open = [...new Set(claims.flatMap((c) => c.gaps.concat(c.premises)))];
  return [
    groups.map(([title, cs]) => [
      groupTitle(title, cs),
      h(
        "ul",
        { class: "text-list" },
        cs.map((c) =>
          h(
            "li",
            { class: "text-row", onclick: clickToOpen(() => on.select("claim", c.id)) },
            lamp(c.final, "small"),
            h(
              "span",
              {},
              claimTag(c, () => on.select("claim", c.id), `text:${c.id}`),
              h(
                "span",
                { class: "text-sentence" },
                claimWords(c, () => on.select("claim", c.id), `text:${c.id}`),
              ),
              exactStatement(c),
              conditions(c, env, on),
            ),
          ),
        ),
      ),
    ]),
    open.length
      ? [
          h(
            "h3",
            { class: "group-title" },
            "Facts to verify",
            h("span", { class: "group-count" }, ` ${open.length}`),
          ),
          h(
            "ul",
            { class: "text-list" },
            open.map((id) => {
              const f = env.facts.find((x) => x.id === id);
              const raisers = env.experiments.filter((e) =>
                e.success.some((o) => o.fact === id),
              ).length;
              return h(
                "li",
                {
                  class: "text-row stacked",
                  onclick: clickToOpen(() => on.select("fact", id)),
                },
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
            }),
          ),
        ]
      : null,
  ];
}
