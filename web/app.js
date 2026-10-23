// Claim circuits. The GUI displays what the fvTrace engine computed (the evaluation envelope)
// and derives no verdict itself. A what-if goes to the engine and may stack: served
// (`fvtrace serve`), the engine is the server; exported (`fvtrace export --html`), it is the
// engine compiled to WebAssembly inside the page (`engine.js`), which starts in the background
// while the precomputed recorded envelope shows. The address hash holds the view, so a scenario
// can be shared or reloaded.

import { circuit, lamp, switchSvg } from "./circuit.js";
import { byId, byIdAs, fill, h } from "./dom.js";
import { EngineError, startEngine } from "./engine.js";
import { DecodeError, decodeEnvelope, decodeExported, decodeProblem } from "./envelope.js";
import {
  blockerList,
  checkList,
  experimentList,
  groupTitle,
  inspector,
  textView,
  workList,
} from "./panels.js";
import { startTour } from "./tour.js";
import { count, statuses, supposedAs, verdictMeanings, verdicts, word } from "./words.js";

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {import("./envelope.js").State} State */
/** @typedef {{ kind: "fact" | "claim" | "experiment", id: string }} Selection */

/** The view: what-if (the spec sent to the engine + the overrides it accepted), question,
layout, selection, experiment filter. */
const view = {
  spec: "",
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

const island = document.getElementById("fvtrace-data");
/** @type {unknown} */
const islandJson = island ? JSON.parse(island.textContent ?? "null") : undefined;
const exported = island ? decodeExported(islandJson) : undefined;

const engineFailed =
  "This browser cannot run the what-ifs on this page, so it shows the facts as recorded.";

// Served: the run's token, offered once in the address (`#token=…`), then kept in this origin's
// storage. An origin includes the port, so no other server on this computer reads it (a cookie
// would reach every one of them).
const tokenKey = "fvtrace-token";
/** A token from the address, until the server accepts it (another site may link `#token=junk`).
 * @type {string | undefined} */
let offered;
/** The token where storage is off. @type {string | undefined} */
let kept;

function storedToken() {
  try {
    return localStorage.getItem(tokenKey) ?? kept;
  } catch {
    return kept;
  }
}

/** @param {string} token */
function keepToken(token) {
  kept = token;
  try {
    localStorage.setItem(tokenKey, token);
  } catch {
    // Storage off: the token lasts for this page alone.
  }
}

/** Takes the token out of the address before anything reads or pushes the hash, so no history
 * entry keeps it. */
function takeToken() {
  const p = new URLSearchParams(location.hash.slice(1));
  const token = p.get("token");
  if (token === null) return;
  offered = token;
  p.delete("token");
  const rest = p.toString();
  history.replaceState(null, "", rest ? `#${rest}` : `${location.pathname}${location.search}`);
}
/** The exported page's engine, started once; after any failure it is never called again. */
/** @type {Promise<import("./engine.js").Engine> | undefined} */
let engineStart;
let engineDead = false;
/** An older export's `#action=…` link, translated once the recorded envelope is known. */
/** @type {string | undefined} */
let legacyAction;

/** The snapshot as the engine reads it (JSON text). */
const snapshotText = exported ? JSON.stringify(exported.snapshot) : "";

function engine() {
  engineStart ??= startEngine(document.getElementById("fvtrace-engine")?.textContent ?? "");
  return engineStart;
}

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
  legacyAction = p.has("whatif") ? undefined : (p.get("action") ?? undefined);
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

/** An exported page's recorded view: its first paint, and its view after any engine failure. */
function showRecorded(/** @type {NonNullable<typeof exported>} */ ex) {
  env = decodeEnvelope(ex.recorded);
  view.whatif = new Map();
  render();
}

/** An older export's `#action=X` link: X's complete what-if from the recorded envelope, or a
 * notice over the recorded view when it holds no such action. */
function translateLegacy(/** @type {NonNullable<typeof exported>} */ ex) {
  const id = legacyAction;
  legacyAction = undefined;
  if (id === undefined) return;
  const a = decodeEnvelope(ex.recorded).actions.find((x) => x.id === id);
  if (a) view.spec = whatifSpec(new Map(a.overrides.map((o) => [o.fact, o.status])));
  else showError(`This page holds no what-if "${id}", so it shows the facts as recorded.`);
  writeHash();
}

/** The page's engine failed: the recorded view for the rest of the session. */
function engineFailure(/** @type {NonNullable<typeof exported>} */ ex) {
  engineDead = true;
  view.spec = "";
  writeHash();
  showRecorded(ex);
  showError(engineFailed);
}

/** The envelope or problem for `spec`: from the page's engine, or the server's route. */
/** @param {string} spec @returns {Promise<unknown>} */
async function evaluate(spec) {
  if (exported) {
    const e = await engine();
    // Checked after the await + decided before returning: a request queued behind a failing one
    // never enters the instance (several loads can wait on one start-up).
    if (engineDead) throw new EngineError("the engine stopped earlier");
    try {
      /** @type {unknown} */
      const json = JSON.parse(e.answer(snapshotText, spec));
      const problem = decodeProblem(json);
      if (problem ? problem.kind !== "what-if" : !decodeEnvelope(json))
        throw new EngineError("the engine answered neither an envelope nor a what-if problem");
      return json;
    } catch (err) {
      engineDead = true;
      throw err;
    }
  }
  const url = `/api/evaluation${spec ? `?whatif=${encodeURIComponent(spec)}` : ""}`;
  const ask = (/** @type {string} */ token) =>
    fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  const stored = storedToken();
  let res = await ask(offered ?? stored ?? "");
  if (offered !== undefined) {
    // Any answer but 403 accepts it: a refused what-if counts, since access is decided first.
    if (res.status !== 403) keepToken(offered);
    else if (stored !== undefined) res = await ask(stored);
    offered = undefined;
  }
  /** @type {unknown} */
  const json = await res.json();
  return json;
}

// The latest request wins (`requested`): a slower earlier answer, or the engine's start-up, never
// overwrites a later what-if, reset or click.
async function load() {
  if (exported) {
    try {
      translateLegacy(exported);
      // The recorded view paints first, with no engine: alone, or until the what-if's answer.
      if (!view.spec || !env) showRecorded(exported);
    } catch (e) {
      showError(e instanceof DecodeError ? `This page is damaged (${e.message}).` : String(e));
      return;
    }
    if (!view.spec) {
      requested = "";
      document.body.removeAttribute("aria-busy");
      return;
    }
  }
  const spec = view.spec;
  requested = spec;
  document.body.setAttribute("aria-busy", "true");
  try {
    const json = await evaluate(spec);
    if (spec !== requested) return;
    const problem = decodeProblem(json);
    if (problem && exported && problem.kind !== "what-if") {
      engineFailure(exported);
      return;
    }
    if (problem) {
      // A refused what-if falls back to the recorded evidence; the message outlives that load.
      if (problem.kind === "what-if" && spec) {
        view.spec = "";
        writeHash();
        await load();
        showError(`${problem.message}. This page shows the facts as recorded instead.`);
      } else showError(problem.message);
      return;
    }
    env = decodeEnvelope(json);
    view.whatif = new Map(env.overrides.map((o) => [o.fact, o.status]));
    byId("error").hidden = true;
    render();
  } catch (e) {
    // Exported: any failure (start-up, a trap, an answer that is no envelope) ends the engine;
    // the notice shows whichever view is current, the view resets when this load is the latest.
    if (exported) {
      engineDead = true;
      if (spec === requested) engineFailure(exported);
      else showError(engineFailed);
    } else
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
  if (exported && engineDead && w.size > 0) {
    showError(engineFailed);
    return;
  }
  view.spec = whatifSpec(w);
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
  supposeStatus(fact) {
    const a = (env?.actions ?? []).find((x) => x.id === `suppose:${fact}`);
    return a?.overrides.find((o) => o.fact === fact)?.status;
  },
  hasAction(action) {
    return env?.actions.some((a) => a.id === action) ?? false;
  },
  apply(action) {
    const a = env?.actions.find((x) => x.id === action);
    if (a) setWhatif(new Map(a.overrides.map((o) => [o.fact, o.status])));
  },
};

/** Claims of the question in the engine's verdict order, untitled (each card names its verdict);
 * overlooked + new-data apart, titled. */
/** @param {Envelope} e @returns {[string, Claim[]][]} */
function groups(e) {
  const prospective = new Set(e.subjects.filter((s) => s.kind === "prospective").map((s) => s.id));
  const mine = e.claims.filter((c) => c.question === view.question);
  const existing = mine.filter((c) => !prospective.has(c.subject));
  /** @type {[string, Claim[]][]} */
  const out = [
    [
      "",
      ["can", "conditional", "open", "cannot"].flatMap((st) =>
        existing.filter((c) => !c.latent && c.final === st),
      ),
    ],
  ];
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
          h("strong", { class: "what-if-lead" }, "Showing a what-if: "),
          "suppose ",
          e.overrides
            .filter((o) => e.facts.some((f) => f.id === o.fact))
            .map((o) => `${o.fact} ${word(supposedAs, o.status)}`)
            .join(", "),
          ". Nothing has been recorded.",
        ]
      : [
          h("strong", { class: "scenario-head" }, "Showing the facts as recorded."),
          " Press a fact's symbol to see what would change if it were verified.",
        ],
  );
  byId("reset").hidden = e.mode !== "what-if";
  // The review state, once for the page: it qualifies every verdict alike.
  const who = e.review.reviewer ?? "A reviewer";
  const when = e.review.date ?? "a recorded date";
  fill(
    byId("review"),
    e.review.state === "reviewed"
      ? `Reviewed by ${who} on ${when}.`
      : e.review.state === "stale"
        ? [
            h("strong", {}, "Changed since the last review."),
            ` ${who} reviewed the claims and facts on ${when}. Check the changes before you rely on the verdicts.`,
          ]
        : h("strong", {}, "Not reviewed yet."),
  );
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
  fill(byId("how-key"), factKey(e.counts));
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
            groupTitle(title, cs),
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
    const before = view.spec;
    readHash();
    if (view.spec === before && legacyAction === undefined) render();
    else void load();
  });
}

/** @type {[string, State][]} */
const pairs = [
  ["proved", "can"],
  ["assumed", "conditional"],
  ["open", "open"],
  ["violated", "cannot"],
];

/** @type {Record<string, string>} */
const factMeanings = {
  proved: "Proved, or accepted by a proved checker",
  assumed: "Taken as true: the claim holds only if it is",
  open: "Neither verified nor assumed yet",
  violated: "Shown to be false",
};

/** @param {string} st */
const factCell = (st) => [
  h("span", { class: `switch ${st}`, "aria-hidden": "true" }, switchSvg(st)),
  h(
    "span",
    { class: "key-text" },
    h("span", {}, st === "proved" ? "Verified" : word(statuses, st)),
    h("small", {}, word(factMeanings, st)),
  ),
];

/** @param {Record<State, number>} counts @param {State} st */
const verdictCell = (counts, st) => [
  lamp(st),
  h("b", { class: "stat-count" }, String(counts[st])),
  h(
    "span",
    { class: "key-text" },
    h("span", {}, word(verdicts, st)),
    h("small", { class: "verdict-meaning" }, word(verdictMeanings, st)),
  ),
];

/** The key: each kind of fact beside the verdict it gives as a claim's weakest + its count. */
/** @param {Record<State, number>} counts */
const factKey = (counts) =>
  h(
    "table",
    { class: "key-pairs" },
    h(
      "thead",
      {},
      h(
        "tr",
        {},
        h("th", { scope: "col", colspan: "2" }, "Facts"),
        h("th", { scope: "col", colspan: "3" }, "Claims"),
      ),
    ),
    h(
      "tbody",
      {},
      pairs.map(([sw, st]) =>
        h(
          "tr",
          {},
          factCell(sw).map((c) => h("td", {}, c)),
          verdictCell(counts, st).map((c) => h("td", {}, c)),
        ),
      ),
    ),
  );

for (const id of ["tour-start", "tour-start-how"]) {
  const b = byId(id);
  b.addEventListener("click", () => startTour(b));
}

// Start last: an exported page renders during this module's evaluation, so everything `draw`
// reads (the key table above) must already be initialized. Its engine starts in the background;
// a start-up failure shows the notice at once (what-ifs need it).
if (!exported) takeToken();
readHash();
wire();
void load();
if (exported)
  engine().catch(() => {
    engineDead = true;
    if (!view.spec) showError(engineFailed);
  });
