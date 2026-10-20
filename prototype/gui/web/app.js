// Claim circuits. The GUI displays what the fvTrace engine computed (the evaluation envelope)
// and derives no verdict itself. Served (`fvtrace serve`): a what-if goes to the engine and may
// stack. Exported (`fvtrace export --html`): the page carries the recorded envelope + one
// precomputed envelope per one-click action, so a what-if applies alone. The address hash holds
// the view, so a scenario can be shared or reloaded.

import { circuit, lamp, switchSvg } from "./circuit.js";
import { byId, byIdAs, fill, h } from "./dom.js";
import { DecodeError, decodeEnvelope, decodeExported, decodeProblem } from "./envelope.js";
import { blockerList, checkList, experimentList, inspector, textView, workList } from "./panels.js";
import { startTour } from "./tour.js";
import { count, statuses, verdicts, word } from "./words.js";

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {{ kind: "fact" | "claim" | "experiment", id: string }} Selection */

/** The view: what-if (served: the spec sent to the engine + the overrides it accepted) or action
(exported), question, layout, selection, experiment filter. */
const view = {
  spec: "",
  /** @type {Map<string, string>} */
  whatif: new Map(),
  /** @type {string | undefined} */
  action: undefined,
  question: "",
  layout: /** @type {"circuits" | "text"} */ ("circuits"),
  /** @type {Selection | undefined} */
  selection: undefined,
  filter: /** @type {"all" | "dry" | "wet"} */ ("all"),
};

/** @type {Envelope | undefined} */
let env;
let requested = "";

const island = document.getElementById("fvtrace-data");
/** @type {unknown} */
const islandJson = island ? JSON.parse(island.textContent ?? "null") : undefined;
const exported = island ? decodeExported(islandJson) : undefined;

/** @param {Map<string, string>} w */
function whatifSpec(w) {
  return [...w].map(([f, st]) => `${f}=${st}`).join(",");
}

/** @param {string | undefined} k @returns {k is Selection["kind"]} */
function isKind(k) {
  return k === "fact" || k === "claim" || k === "experiment";
}

// The engine judges a linked what-if as written: duplicates or malformed entries come back as a
// what-if problem, shown to the user, never repaired here.
function readHash() {
  const p = new URLSearchParams(location.hash.slice(1));
  view.spec = p.get("whatif") ?? "";
  view.action = p.get("action") ?? undefined;
  view.question = p.get("q") ?? "";
  view.layout = p.get("view") === "text" ? "text" : "circuits";
  const sel = /^(fact|claim|experiment):(.+)$/.exec(p.get("select") ?? "");
  const kind = sel?.[1];
  view.selection = sel?.[2] && isKind(kind) ? { kind, id: sel[2] } : undefined;
  const f = p.get("filter");
  view.filter = f === "dry" || f === "wet" ? f : "all";
}

function writeHash() {
  const p = new URLSearchParams();
  if (view.spec) p.set("whatif", view.spec);
  if (view.action) p.set("action", view.action);
  if (view.question) p.set("q", view.question);
  if (view.layout === "text") p.set("view", "text");
  if (view.selection) p.set("select", `${view.selection.kind}:${view.selection.id}`);
  if (view.filter !== "all") p.set("filter", view.filter);
  const hash = p.toString();
  if (hash !== location.hash.slice(1)) history.pushState(null, "", hash ? `#${hash}` : "#");
}

/** @param {string} message */
function showError(message) {
  const el = byId("error");
  el.textContent = message;
  el.hidden = false;
}

/** @type {import("./envelope.js").Action[] | undefined} */
let recordedCache;

/** An exported page's one-click actions (those of its recorded envelope). */
function recordedActions() {
  if (!recordedCache && exported) recordedCache = decodeEnvelope(exported.recorded).actions;
  return recordedCache ?? [];
}

/** An exported page: the precomputed envelope of the current action. */
function loadExported(/** @type {NonNullable<typeof exported>} */ ex) {
  const raw = view.action === undefined ? ex.recorded : ex.actions.get(view.action);
  try {
    if (raw === undefined || view.spec) {
      showError(
        view.spec
          ? "This page holds one-click what-ifs only, so it shows the recorded evidence."
          : `This page holds no what-if "${view.action}", so it shows the recorded evidence.`,
      );
      view.action = undefined;
      view.spec = "";
      writeHash();
      env = decodeEnvelope(ex.recorded);
    } else {
      byId("error").hidden = true;
      env = decodeEnvelope(raw);
    }
    render();
  } catch (e) {
    showError(e instanceof DecodeError ? `This page is damaged (${e.message}).` : String(e));
  }
}

async function load() {
  if (exported) {
    loadExported(exported);
    return;
  }
  const spec = view.spec;
  requested = spec;
  document.body.setAttribute("aria-busy", "true");
  try {
    const res = await fetch(`/api/evaluation${spec ? `?whatif=${encodeURIComponent(spec)}` : ""}`);
    /** @type {unknown} */
    const json = await res.json();
    if (spec !== requested) return;
    const problem = decodeProblem(json);
    if (problem) {
      // A refused what-if falls back to the recorded evidence; the message outlives that load.
      if (problem.kind === "what-if" && spec) {
        view.spec = "";
        writeHash();
        await load();
        showError(`${problem.message}. This page shows the recorded evidence instead.`);
      } else showError(problem.message);
      return;
    }
    env = decodeEnvelope(json);
    view.whatif = new Map(env.overrides.map((o) => [o.fact, o.status]));
    byId("error").hidden = true;
    render();
  } catch (e) {
    showError(
      e instanceof DecodeError
        ? `This page does not understand the server's answer (${e.message}). Update fvtrace.`
        : "The server did not answer. Is fvtrace serve still running?",
    );
  } finally {
    if (spec === requested) document.body.removeAttribute("aria-busy");
  }
}

/** Sets the what-if, then asks the engine. @param {Map<string, string>} w */
function setWhatif(w) {
  view.spec = whatifSpec(w);
  writeHash();
  void load();
}

/** Exported page: shows one action's envelope (`undefined` = recorded). @param {string} [a] */
function setAction(a) {
  view.action = a;
  writeHash();
  void load();
}

/** @type {import("./panels.js").Handlers} */
const on = {
  select(kind, id) {
    view.selection = { kind, id };
    if (kind === "claim" && env) {
      const q = env.claims.find((c) => c.id === id)?.question;
      if (q) view.question = q;
    }
    writeHash();
    render();
    byId("inspector").focus();
  },
  // Exported one-click what-ifs apply alone: a switch undoes only its own action, so a fact that
  // another action supposes stays as it is until Reset.
  canToggle(fact) {
    if (exported) {
      const supposed = env?.facts.find((f) => f.id === fact)?.supposed ?? false;
      return view.action === `suppose:${fact}` || (!supposed && on.hasAction(`suppose:${fact}`));
    }
    return view.whatif.has(fact) || on.hasAction(`suppose:${fact}`);
  },
  toggle(fact) {
    if (exported) setAction(view.action === `suppose:${fact}` ? undefined : `suppose:${fact}`);
    else if (view.whatif.has(fact)) {
      const w = new Map(view.whatif);
      w.delete(fact);
      setWhatif(w);
    } else on.apply(`suppose:${fact}`);
  },
  supposeStatus(fact) {
    const actions = exported ? recordedActions() : (env?.actions ?? []);
    const a = actions.find((x) => x.id === `suppose:${fact}`);
    return a?.overrides.find((o) => o.fact === fact)?.status;
  },
  hasAction(action) {
    if (exported) return exported.actions.has(action);
    return env?.actions.some((a) => a.id === action) ?? false;
  },
  apply(action) {
    if (exported) {
      if (exported.actions.has(action)) setAction(action);
      return;
    }
    const a = env?.actions.find((x) => x.id === action);
    if (a) setWhatif(new Map(a.overrides.map((o) => [o.fact, o.status])));
  },
};

/** Claims of the question, grouped by the engine's verdict; overlooked + new-data apart. */
/** @param {Envelope} e @returns {[string, Claim[]][]} */
function groups(e) {
  const prospective = new Set(e.subjects.filter((s) => s.kind === "prospective").map((s) => s.id));
  const mine = e.claims.filter((c) => c.question === view.question);
  const existing = mine.filter((c) => !prospective.has(c.subject));
  /** @type {[string, Claim[]][]} */
  const out = ["can", "conditional", "open", "cannot"].map((st) => {
    const cs = existing.filter((c) => !c.latent && c.final === st);
    return [cs[0]?.verdict ?? st, cs];
  });
  out.push(["Overlooked directions", existing.filter((c) => c.latent)]);
  for (const s of e.subjects.filter((x) => prospective.has(x.id))) {
    out.push([`On new data: ${s.title}`, mine.filter((c) => c.subject === s.id)]);
  }
  return out.filter(([, cs]) => cs.length > 0);
}

function renderScenario(/** @type {Envelope} */ e) {
  const bar = byId("scenario");
  bar.classList.toggle("hypothetical", e.mode === "what-if");
  fill(
    byId("scenario-text"),
    e.mode === "what-if"
      ? [
          h("strong", {}, "What-if: "),
          e.overrides.map((o) => `${o.fact} ${o.status}`).join(", "),
          ". Supposed, not recorded: no new evidence.",
        ]
      : "Recorded evidence.",
  );
  byIdAs("reset", HTMLButtonElement).disabled = e.mode !== "what-if";
  // The tag names the review state; each verdict carries it too ("(draft)"), so the why is for
  // screen readers + the tooltip.
  const [tag, why] =
    e.review.state === "reviewed"
      ? [
          `Reviewed by ${e.review.reviewer ?? "a reviewer"}`,
          ` on ${e.review.date ?? "a recorded date"}.`,
        ]
      : e.review.state === "stale"
        ? ["Stale review", ": the trace changed since its review, so every verdict is provisional."]
        : ["Draft", ": every verdict is provisional until a reviewer signs the trace off."];
  const review = byId("review");
  fill(review, [tag, h("span", { class: "visually-hidden" }, why)]);
  review.title = tag + why;
  review.className = `review ${e.review.state}`;
}

/** The focused re-rendered control, so a render can hand focus back to its successor. */
function focusKey() {
  const el = document.activeElement;
  return el instanceof HTMLElement ? (el.dataset["key"] ?? undefined) : undefined;
}

/** @param {string | undefined} key */
function refocus(key) {
  if (
    !key ||
    (document.activeElement instanceof HTMLElement && document.activeElement.dataset["key"] === key)
  )
    return;
  const el = document.querySelector(`[data-key="${CSS.escape(key)}"]`);
  if (el instanceof HTMLElement) el.focus();
}

function render() {
  if (!env) return;
  const key = focusKey();
  draw(env);
  refocus(key);
}

/** @param {Envelope} e */
function draw(e) {
  if (!e.questions.some((q) => q.id === view.question)) view.question = e.questions[0]?.id ?? "";
  byId("analysis-title").textContent = e.analysis.title;
  byId("analysis-summary").textContent = e.analysis.summary;
  renderScenario(e);
  fill(
    byId("overview"),
    /** @type {const} */ (["can", "conditional", "open", "cannot"]).map((st) =>
      h(
        "div",
        { class: "stat" },
        lamp(st),
        h("b", { class: "stat-count" }, String(e.counts[st])),
        h("span", { class: "stat-label" }, word(verdicts, st)),
      ),
    ),
  );
  fill(
    byId("questions"),
    e.questions.map((q) =>
      h(
        "button",
        {
          class: "question-tab",
          "data-key": `question:${q.id}`,
          type: "button",
          "aria-current": q.id === view.question ? "true" : "false",
          onclick: () => {
            view.question = q.id;
            writeHash();
            render();
          },
        },
        q.title,
        h(
          "small",
          { class: "question-count" },
          count(e.claims.filter((c) => c.question === q.id).length, "claim", "claims"),
        ),
      ),
    ),
  );
  const select = byIdAs("question-select", HTMLSelectElement);
  fill(
    select,
    e.questions.map((q) => h("option", { value: q.id, selected: q.id === view.question }, q.title)),
  );
  const q = e.questions.find((x) => x.id === view.question);
  byId("question-title").textContent = q?.text ?? "";
  for (const b of document.querySelectorAll("[data-layout]")) {
    b.setAttribute("aria-pressed", String(b.getAttribute("data-layout") === view.layout));
  }
  const gs = groups(e);
  const sel = view.selection;
  fill(
    byId("board"),
    view.layout === "text"
      ? textView(e, gs, on)
      : gs.map(([title, cs]) =>
          h(
            "section",
            { class: "group" },
            h(
              "h3",
              { class: "group-title" },
              title,
              h("span", { class: "group-count" }, ` ${cs.length}`),
            ),
            cs.map((c) => circuit(c, e, on, sel?.kind === "claim" && sel.id === c.id)),
          ),
        ),
  );
  fill(byId("inspector"), inspector(e, sel, on));
  for (const b of document.querySelectorAll("[data-filter]")) {
    b.setAttribute("aria-pressed", String(b.getAttribute("data-filter") === view.filter));
  }
  fill(
    byId("experiment-list"),
    experimentList(e, view.filter, sel?.kind === "experiment" ? sel.id : undefined, on),
  );
  fill(byId("work-list"), workList(e, on));
  const blockers = blockerList(e, on);
  byId("blockers").hidden = blockers.length === 0;
  fill(byId("blocker-list"), blockers);
  const checks = checkList(e, on);
  byId("checks").hidden = checks.length === 0;
  fill(byId("check-list"), checks);
}

function wire() {
  byId("reset").addEventListener("click", () => {
    if (exported) setAction(undefined);
    else setWhatif(new Map());
  });
  byId("export-note").hidden = !exported;
  byId("question-select").addEventListener("change", (ev) => {
    if (ev.target instanceof HTMLSelectElement) view.question = ev.target.value;
    writeHash();
    render();
  });
  for (const b of document.querySelectorAll("[data-layout]")) {
    b.addEventListener("click", () => {
      view.layout = b.getAttribute("data-layout") === "text" ? "text" : "circuits";
      writeHash();
      render();
    });
  }
  for (const b of document.querySelectorAll("[data-filter]")) {
    b.addEventListener("click", () => {
      const f = b.getAttribute("data-filter");
      view.filter = f === "dry" || f === "wet" ? f : "all";
      writeHash();
      render();
    });
  }
  window.addEventListener("popstate", () => {
    const before = `${view.spec}|${view.action ?? ""}`;
    readHash();
    if (`${view.spec}|${view.action ?? ""}` === before) render();
    else void load();
  });
}

readHash();
wire();
void load();

// "How this works": the switch key, drawn with the circuits' own switches.
fill(
  byId("how-key"),
  ["proved", "assumed", "open", "violated"].map((st) =>
    h(
      "li",
      {},
      h("span", { class: `switch ${st}`, "aria-hidden": "true" }, switchSvg(st)),
      h("span", {}, st === "proved" ? "Verified" : word(statuses, st)),
      h(
        "small",
        {},
        st === "proved"
          ? "Closed: proved, or accepted by a proved checker"
          : st === "assumed"
            ? "Closed on condition: the claim holds only if this is true"
            : st === "open"
              ? "Not closed: a gap that keeps the lamp off"
              : "Broken: the claim cannot be made as written",
      ),
    ),
  ),
);

for (const id of ["tour-start", "tour-start-how"]) {
  const b = byId(id);
  b.addEventListener("click", () => startTour(b));
}
