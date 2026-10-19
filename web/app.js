// Claim circuits over `fvtrace serve`. The GUI displays what the fvTrace engine computed (the
// evaluation envelope) and derives no verdict itself: a what-if is sent to the engine, never
// replayed here. The address hash holds the view, so a scenario can be shared or reloaded.

import { circuit, lamp } from "./circuit.js";
import { byId, byIdAs, fill, h } from "./dom.js";
import { DecodeError, decodeEnvelope, decodeProblem } from "./envelope.js";
import { blockerList, checkList, experimentList, inspector, textView, workList } from "./panels.js";
import { count, verdicts, word } from "./words.js";

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {{ kind: "fact" | "claim" | "experiment", id: string }} Selection */

/** The view: what-if (fact → status), question, layout, selection, experiment filter. */
const view = {
  /** @type {Map<string, string>} */
  whatif: new Map(),
  question: "",
  layout: /** @type {"circuits" | "text"} */ ("circuits"),
  /** @type {Selection | undefined} */
  selection: undefined,
  filter: /** @type {"all" | "dry" | "wet"} */ ("all"),
};

/** @type {Envelope | undefined} */
let env;
let requested = "";

/** @param {Map<string, string>} w */
function whatifSpec(w) {
  return [...w].map(([f, st]) => `${f}=${st}`).join(",");
}

/** `F=S` as `[F, S]`. @param {string} x @returns {[string, string]} */
function pair(x) {
  const i = x.indexOf("=");
  return [x.slice(0, i), x.slice(i + 1)];
}

/** @param {string | undefined} k @returns {k is Selection["kind"]} */
function isKind(k) {
  return k === "fact" || k === "claim" || k === "experiment";
}

function readHash() {
  const p = new URLSearchParams(location.hash.slice(1));
  view.whatif = new Map(
    (p.get("whatif") ?? "")
      .split(",")
      .filter((x) => x.includes("="))
      .map(pair),
  );
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
  if (view.whatif.size) p.set("whatif", whatifSpec(view.whatif));
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

async function load() {
  const spec = whatifSpec(view.whatif);
  requested = spec;
  document.body.setAttribute("aria-busy", "true");
  try {
    const res = await fetch(`/api/evaluation${spec ? `?whatif=${encodeURIComponent(spec)}` : ""}`);
    /** @type {unknown} */
    const json = await res.json();
    if (spec !== requested) return;
    const problem = decodeProblem(json);
    if (problem) {
      showError(problem.message);
      if (problem.kind === "what-if" && view.whatif.size) {
        view.whatif.clear();
        writeHash();
        await load();
      }
      return;
    }
    env = decodeEnvelope(json);
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
  view.whatif = w;
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
  canToggle(fact) {
    return view.whatif.has(fact) || on.hasAction(`suppose:${fact}`);
  },
  toggle(fact) {
    if (view.whatif.has(fact)) {
      const w = new Map(view.whatif);
      w.delete(fact);
      setWhatif(w);
    } else on.apply(`suppose:${fact}`);
  },
  hasAction(action) {
    return env?.actions.some((a) => a.id === action) ?? false;
  },
  apply(action) {
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
  const review = byId("review");
  review.textContent =
    e.review.state === "reviewed"
      ? `Reviewed by ${e.review.reviewer ?? "a reviewer"} on ${e.review.date ?? "a recorded date"}.`
      : e.review.state === "stale"
        ? "The trace changed since its review: every verdict is provisional."
        : "Draft: every verdict is provisional until a reviewer signs the trace off.";
  review.className = `review ${e.review.state}`;
}

function render() {
  if (!env) return;
  const e = env;
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
  byId("reset").addEventListener("click", () => setWhatif(new Map()));
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
    const before = whatifSpec(view.whatif);
    readHash();
    if (whatifSpec(view.whatif) === before) render();
    else void load();
  });
}

readHash();
wire();
void load();
