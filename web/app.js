// Claim circuits. The GUI displays what the fvTrace engine computed (the evaluation envelope)
// and derives no verdict itself. A what-if goes to the engine and may stack: served
// (`fvtrace serve`), the engine is the server; exported (`fvtrace export --html`), it is the
// engine compiled to WebAssembly inside the page (`engine.js`), which starts in the background
// while the precomputed recorded envelope shows. The address hash holds the view, so a scenario
// can be shared or reloaded.

import { circuit, claimSig, lamp, markCard, switchSvg } from "./circuit.js";
import { byId, byIdAs, fill, h } from "./dom.js";
import { EngineError } from "./engine.js";
import {
  DecodeError,
  decodeDetails,
  decodeEnvelope,
  decodeExported,
  decodeProblem,
} from "./envelope.js";
import { entriesOf, results, search } from "./find.js";
import { LazyList } from "./lazy.js";
import { lookupsOf } from "./lookups.js";
import {
  blockerRow,
  checkRow,
  experimentRow,
  groupTitle,
  inspector,
  markRow,
  noExperiments,
  noWork,
  openFactRow,
  openFactSig,
  textRow,
  workRow,
  workSig,
} from "./panels.js";
import { startTour } from "./tour.js";
import { count, statuses, supposedAs, verdictMeanings, verdicts, word } from "./words.js";

/** @typedef {import("./envelope.js").Envelope} Envelope */
/** @typedef {import("./envelope.js").Claim} Claim */
/** @typedef {import("./envelope.js").State} State */
/** @typedef {import("./lazy.js").Row} Row */
/** @typedef {{ kind: "fact" | "claim" | "experiment", id: string }} Selection */
/** @typedef {{ whatif: string, action?: string, details?: string }} Request */
/** The selection's details for the shown view (kernel.md V-details): pending, ready, refused, or
 * unavailable (the page's engine cannot run).
 * @typedef {{ item: string, spec: string, state: "pending" | "ready" | "problem" | "off",
 *   value?: import("./envelope.js").Details, message?: string }} DetailsView */

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
/** The shown envelope's lookups, built once when the page adopts it (U-lookups). */
/** @type {import("./lookups.js").Lookups | undefined} */
let ix;
/** Request numbers (U-coalesce): an answer older than the newest request of its kind is dropped. */
let evaluations = 0;
let detailsAsked = 0;
/** One evaluation in flight; the newest one waiting behind it resumes when it settles. */
let flying = false;
/** @type {(() => void) | undefined} */
let queued;
/** The view the shown envelope read (served: `X-Fvtrace-View`), sent with each details request. */
/** @type {string | undefined} */
let shownView;
/** @type {DetailsView | undefined} */
let details;
/** The excluded pairs of the shown claims that have some (claim details, kernel.md V-details),
 * asked for once a card that has some is on screen. */
/** @type {Map<string, string[]>} */
let excludedPairs = new Map();
/** @type {Set<string>} */
let pairsAsked = new Set();
const island = document.getElementById("fvtrace-data");

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
/** @type {Promise<{ request: (text: string) => Promise<string> }> | undefined} */
let engineStart;
/** The page engine's requests, in order (`ask`). @type {Promise<void>} */
let engineQueue = Promise.resolve();
let engineDead = false;
/** An older export's `#action=…` link, translated once the recorded envelope is known. */
/** @type {string | undefined} */
let legacyAction;

/** The snapshot as the engine reads it: its block's text (kernel.md E-page). */
const snapshotText = document.getElementById("fvtrace-snapshot")?.textContent ?? "";

/** The engine's Worker, made from the page's own worker block through the one Trusted Types
 * policy the page's CSP names; the policy accepts that URL alone (kernel.md E-page, E-sec). */
function makeWorker() {
  // A page without WebAssembly has no worker that runs it: no worker is started.
  if (typeof WebAssembly !== "object" || typeof DecompressionStream !== "function")
    throw new EngineError("this browser lacks WebAssembly or DecompressionStream");
  const made = URL.createObjectURL(
    new Blob([document.getElementById("fvtrace-worker")?.textContent ?? ""], {
      type: "text/javascript",
    }),
  );
  /** @type {unknown} */
  let url = made;
  /** @type {unknown} */
  const tt = Reflect.get(globalThis, "trustedTypes");
  /** @type {unknown} */
  const create =
    typeof tt === "object" && tt !== null ? Reflect.get(tt, "createPolicy") : undefined;
  if (typeof create === "function") {
    /** @type {unknown} */
    const policy = Reflect.apply(create, tt, [
      "fvtrace-engine",
      {
        createScriptURL: (/** @type {string} */ u) => {
          if (u !== made) throw new TypeError("only the page's own worker runs");
          return u;
        },
      },
    ]);
    /** @type {unknown} */
    const toUrl =
      typeof policy === "object" && policy !== null
        ? Reflect.get(policy, "createScriptURL")
        : undefined;
    if (typeof toUrl === "function") url = Reflect.apply(toUrl, policy, [made]);
  }
  /** @type {unknown} */
  const worker = Reflect.construct(Worker, [url]);
  if (!(worker instanceof Worker)) throw new EngineError("the engine's worker did not start");
  return worker;
}

/** The page's engine in its Worker (user ruling): started, loaded with the page's snapshot once
 * (kernel.md E-state), then answering requests by message; any failure ends it. */
function engine() {
  engineStart ??= (async () => {
    const worker = makeWorker();
    let next = 0;
    /** @type {Map<number, { resolve: (v: string | null) => void, reject: (e: Error) => void }>} */
    const waiting = new Map();
    /** @param {Error} e */
    const failAll = (e) => {
      for (const w of waiting.values()) w.reject(e);
      waiting.clear();
    };
    worker.addEventListener("message", (/** @type {MessageEvent} */ event) => {
      /** @type {unknown} */
      const data = event.data;
      if (typeof data !== "object" || data === null) return;
      /** @type {unknown} */
      const id = Reflect.get(data, "id");
      const w = typeof id === "number" ? waiting.get(id) : undefined;
      if (!w || typeof id !== "number") return;
      waiting.delete(id);
      /** @type {unknown} */
      const failed = Reflect.get(data, "failed");
      /** @type {unknown} */
      const value = Reflect.get(data, "value");
      if (typeof failed === "string") w.reject(new EngineError(failed));
      else if (typeof value === "string" || value === null) w.resolve(value);
      else w.reject(new EngineError("the engine answered no text"));
    });
    worker.addEventListener("error", () => failAll(new EngineError("the engine's worker failed")));
    worker.addEventListener("messageerror", () =>
      failAll(new EngineError("the engine's worker failed")),
    );
    /** @param {"start" | "load" | "request"} op @param {string} arg
     * @returns {Promise<string | null>} */
    const call = (op, arg) =>
      new Promise((resolve, reject) => {
        const id = next++;
        waiting.set(id, { resolve, reject });
        worker.postMessage({ id, op, arg }, []);
      });
    // Both posted at once: the worker takes them in order, and the snapshot's load need not wait
    // for this thread to read the start's reply (it is busy with the page's first view).
    const started = call("start", document.getElementById("fvtrace-engine")?.textContent ?? "");
    const loaded = call("load", snapshotText);
    await started;
    const problem = await loaded;
    if (problem !== null) throw new EngineError("the engine refused the page's snapshot");
    return {
      /** @param {string} text */
      request: async (text) => {
        const answer = await call("request", text);
        if (answer === null) throw new EngineError("the engine answered no text");
        return answer;
      },
    };
  })();
  return engineStart;
}

// Exported: the engine starts before this page parses its data block, so its start-up runs beside
// the page's first view (a click during start-up waits for both, U-time).
if (island)
  engine().catch(() => {
    engineDead = true;
    if (!view.spec) showError(engineFailed);
  });
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

/** The find route's entries for the shown envelope, made on its first search. */
/** @type {import("./find.js").Entry[] | undefined} */
let entries;

/** Makes `e` the shown envelope, its lookups built once (U-lookups). */
function adopt(/** @type {Envelope} */ e) {
  env = e;
  ix = lookupsOf(e);
  entries = undefined;
}

/** An exported page's recorded view: its first paint, and its view after any engine failure. */
function showRecorded(/** @type {NonNullable<typeof exported>} */ ex) {
  adopt(decodeEnvelope(ex.recorded));
  view.whatif = new Map();
  excludedPairs = new Map();
  pairsAsked = new Set();
  render();
}

/** The page's engine failed: the recorded view for the rest of the session. */
function engineFailure(/** @type {NonNullable<typeof exported>} */ ex) {
  engineDead = true;
  view.spec = "";
  writeHash();
  showRecorded(ex);
  showError(engineFailed);
}

/** Requests still running (U-busy): the page reads as busy from a request's start, and shows that
 * it is working once a request runs past 1 s (Nielsen: past 1 s, flow of thought needs a sign). */
let running = 0;
/** @type {ReturnType<typeof setTimeout> | undefined} */
let workingTimer;
/** @param {1 | -1} delta */
function busy(delta) {
  running += delta;
  if (running > 0) document.body.setAttribute("aria-busy", "true");
  else document.body.removeAttribute("aria-busy");
  if (running > 0 && workingTimer === undefined)
    workingTimer = setTimeout(() => {
      byId("working").hidden = false;
    }, 1000);
  if (running === 0) {
    clearTimeout(workingTimer);
    workingTimer = undefined;
    byId("working").hidden = true;
  }
}

/**
 * The answer to `request` (kernel.md V-request: envelope, details or problem) + the view it read:
 * from the page's engine, or the server's answer route (`shown` = the view the page shows).
 * @param {Request} request @param {string} [shown]
 * @returns {Promise<{ json: unknown, view: string | undefined }>}
 */
async function ask(request, shown) {
  busy(1);
  try {
    return await answerOf(request, shown);
  } finally {
    busy(-1);
  }
}

/** @param {Request} request @param {string} [shown]
 * @returns {Promise<{ json: unknown, view: string | undefined }>} */
async function answerOf(request, shown) {
  if (exported) {
    // One request at a time, each checked after the one before it settled: a request queued
    // behind a failing one never enters the engine (several can wait on one start-up).
    const run = async () => {
      const e = await engine();
      if (engineDead) throw new EngineError("the engine stopped earlier");
      try {
        /** @type {unknown} */
        const json = JSON.parse(await e.request(JSON.stringify(request)));
        return { json, view: /** @type {string | undefined} */ (undefined) };
      } catch (err) {
        engineDead = true;
        throw err;
      }
    };
    const out = engineQueue.then(run, run);
    engineQueue = out.then(
      () => undefined,
      () => undefined,
    );
    return out;
  }
  const send = (/** @type {string} */ token) =>
    fetch("/api/answer", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        ...(shown === undefined ? {} : { "X-Fvtrace-View": shown }),
      },
      body: JSON.stringify(request),
    });
  const stored = storedToken();
  let res = await send(offered ?? stored ?? "");
  if (offered !== undefined) {
    // Any answer but 403 accepts it: a refused what-if counts, since access is decided first.
    if (res.status !== 403) keepToken(offered);
    else if (stored !== undefined) res = await send(stored);
    offered = undefined;
  }
  /** @type {unknown} */
  const json = await res.json();
  return { json, view: res.headers.get("X-Fvtrace-View") ?? undefined };
}

/**
 * One evaluation request (U-coalesce): at most one in flight; a newer one waits behind it and
 * replaces any older waiting one. Undefined = a newer evaluation superseded it.
 * @param {number} n its request number @param {Request} request
 */
async function evaluation(n, request) {
  if (flying) {
    queued?.();
    busy(1);
    try {
      await new Promise((resume) => {
        queued = () => resume(undefined);
      });
    } finally {
      busy(-1);
    }
    if (n !== evaluations) return undefined;
  }
  flying = true;
  try {
    return await ask(request);
  } finally {
    flying = false;
    const next = queued;
    queued = undefined;
    next?.();
  }
}

/** A problem the page's engine may answer without failing (kernel.md E-gui). */
const recoverable = new Set(["what-if", "action", "item"]);

// The newest request wins (`evaluations`): a slower earlier answer, or the engine's start-up,
// never overwrites a later what-if, action, reset or click.
/** Evaluates the shown what-if, or the action `action` from it (kernel.md V-action); `link` = the
 * action came from an older export's link, whose address keeps its other parts.
 * @param {string} [action] @param {boolean} [link] */
async function load(action, link = false) {
  if (exported && !action) {
    try {
      // The recorded view paints first, with no engine: alone, or until the answer.
      if (!view.spec || !env) showRecorded(exported);
    } catch (e) {
      showError(e instanceof DecodeError ? `This page is damaged (${e.message}).` : String(e));
      return;
    }
    if (legacyAction !== undefined) {
      // An older export's `#action=X` link: the engine expands X from the recorded view.
      const id = legacyAction;
      legacyAction = undefined;
      return legacy(id);
    }
    if (!view.spec) {
      evaluations++;
      void loadDetails();
      return;
    }
  }
  const spec = view.spec;
  const n = ++evaluations;
  try {
    const got = await evaluation(n, action ? { whatif: spec, action } : { whatif: spec });
    if (!got || n !== evaluations) return;
    const { json, view: read } = got;
    const problem = decodeProblem(json);
    if (problem && exported && !recoverable.has(problem.kind)) {
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
    const e = decodeEnvelope(json);
    adopt(e);
    shownView = read;
    view.whatif = new Map(e.overrides.map((o) => [o.fact, o.status]));
    if (action) {
      view.spec = whatifSpec(view.whatif);
      if (link) {
        const p = new URLSearchParams(location.hash.slice(1));
        p.delete("action");
        p.set("whatif", view.spec);
        history.replaceState(null, "", `#${p.toString()}`);
      } else writeHash();
    }
    byId("error").hidden = true;
    excludedPairs = new Map();
    pairsAsked = new Set();
    render();
    void loadDetails();
  } catch (e) {
    // Exported: any failure (start-up, a trap, an answer that is no envelope) ends the engine;
    // the notice shows whichever view is current, the view resets when this load is the latest.
    if (exported) {
      engineDead = true;
      if (n === evaluations) engineFailure(exported);
      else showError(engineFailed);
    } else
      showError(
        e instanceof DecodeError
          ? `This page does not understand the server's answer (${e.message}). Update fvtrace.`
          : "The server did not answer. Is fvtrace serve still running?",
      );
  }
}
/** An older export's `#action=X`: the engine's expansion of X from the recorded view, or a notice
 * over the recorded view when it suggests no such what-if. */
async function legacy(/** @type {string} */ id) {
  if (engineDead) {
    showError(engineFailed);
    return;
  }
  view.spec = "";
  await load(id, true);
  if (!view.spec) {
    showError(`This page holds no what-if "${id}", so it shows the facts as recorded.`);
    writeHash();
  }
}

/** The excluded pairs a card on screen names (user ruling: lists on request), asked once per card
 * and view as the card mounts; an answer for an older view is dropped. @param {Claim} c */
function askPairs(c) {
  const spec = view.spec;
  if (c.incompatibleCount === 0 || pairsAsked.has(c.id)) return;
  pairsAsked.add(c.id);
  void (async () => {
    try {
      const { json } = await ask({ whatif: spec, details: `claim:${c.id}` }, shownView);
      if (spec !== view.spec || decodeProblem(json)) return;
      excludedPairs.set(c.id, decodeDetails(json).incompatible ?? []);
      renderBoard();
    } catch {
      // The card keeps its other lines.
    }
  })();
}

/** The selection's details for the shown view (kernel.md V-details); the inspector shows the
 * summary meanwhile. */
async function loadDetails() {
  const sel = view.selection;
  if (!sel || !env) {
    details = undefined;
    return;
  }
  const item = `${sel.kind}:${sel.id}`;
  const spec = view.spec;
  if (exported && engineDead) {
    details = { item, spec, state: "off" };
    renderInspector();
    return;
  }
  details = { item, spec, state: "pending" };
  renderInspector();
  const n = ++detailsAsked;
  try {
    const { json } = await ask({ whatif: spec, details: item }, shownView);
    if (n !== detailsAsked || spec !== view.spec) return;
    const problem = decodeProblem(json);
    if (problem?.kind === "view") {
      // The claims or their evidence changed since this page's answer: show them again first.
      await load();
      return;
    }
    details = problem
      ? { item, spec, state: "problem", message: problem.message }
      : { item, spec, state: "ready", value: decodeDetails(json) };
  } catch {
    if (n !== detailsAsked) return;
    details = exported
      ? { item, spec, state: "off" }
      : { item, spec, state: "problem", message: "The server did not answer." };
  }
  renderInspector();
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

/** @param {Selection | undefined} sel @param {Selection["kind"]} kind @param {string} id */
const selects = (sel, kind, id) => sel?.kind === kind && sel.id === id;

/** @type {import("./panels.js").Handlers} */
const on = {
  select(kind, id) {
    view.selection = { kind, id };
    const q = kind === "claim" ? ix?.claims.get(id)?.question : undefined;
    writeHash();
    if (q && q !== view.question) {
      // Another question's claim: its board replaces this one.
      view.question = q;
      renderQuestions();
      renderBoard();
    }
    // U-select: the highlight moves and the details panel fills; no card is rebuilt.
    drawSelection();
    renderInspector();
    byId("inspector").focus();
    void loadDetails();
  },
  canToggle(fact) {
    return view.whatif.has(fact) || on.hasAction(`suppose:${fact}`);
  },
  toggle(fact) {
    // A symbol stacks or removes its fact within the shown what-if (kernel.md E-gui), at the status
    // the engine names for it.
    const status = on.supposeStatus(fact);
    if (view.whatif.has(fact)) {
      const w = new Map(view.whatif);
      w.delete(fact);
      setWhatif(w);
    } else if (status) {
      // The new fact first, as the expansion orders it (the action's keys, then the rest).
      setWhatif(new Map([[fact, status], ...view.whatif]));
    }
  },
  supposeStatus(fact) {
    return on.hasAction(`suppose:${fact}`) ? ix?.facts.get(fact)?.ceiling : undefined;
  },
  pairsOf(claim) {
    return excludedPairs.get(claim);
  },
  hasAction(action) {
    return ix?.actions.has(action) ?? false;
  },
  apply(action) {
    if (exported && engineDead) {
      showError(engineFailed);
      return;
    }
    void load(action);
  },
};

/**
 * The find route's choice: selected like a click, its card or row mounted (U-access: the route
 * reaches rows not mounted), scrolled into view and focused; a fact, which has no row, focuses
 * the inspector. @param {Selection["kind"]} kind @param {string} id
 */
function reveal(kind, id) {
  view.selection = { kind, id };
  const q = kind === "claim" ? ix?.claims.get(id)?.question : undefined;
  writeHash();
  if (q && q !== view.question) {
    view.question = q;
    renderQuestions();
    renderBoard();
  }
  /** @type {HTMLElement | undefined} */
  let row;
  if (kind === "claim") for (const g of boardGroups.values()) row ??= g.list.show(`claim:${id}`);
  else if (kind === "experiment") row = experimentList.show(`experiment:${id}`);
  drawSelection();
  renderInspector();
  void loadDetails();
  const button = row?.querySelector(".tag-id .ref, .experiment-meta .ref");
  if (row && button instanceof HTMLElement) {
    row.scrollIntoView({ block: "center" });
    button.focus();
  } else byId("inspector").focus();
}

/** Shows the matches of the find field's text (none for an empty field). */
function find() {
  const input = byIdAs("find", HTMLInputElement);
  const list = byId("find-results");
  const line = byId("find-count");
  if (!env || !ix || !input.value.trim()) {
    list.hidden = true;
    line.hidden = true;
    fill(list);
    return [];
  }
  entries ??= entriesOf(env);
  const found = search(entries, input.value);
  const e = env;
  const shown = results(
    input.value,
    found,
    (q) => (q === view.question ? undefined : e.questions.find((x) => x.id === q)?.title),
    (m) => reveal(m.kind, m.id),
  );
  line.textContent = shown.line;
  line.hidden = false;
  fill(list, shown.rows);
  list.hidden = shown.rows.length === 0;
  return found.matches;
}

/** The selection drawn on the mounted cards + rows (a kept element keeps its marks). */
/** @type {Selection | undefined} */
let drawn;

/** Moves the drawn selection to `view.selection`. */
function drawSelection() {
  mark(drawn, false);
  mark(view.selection, true);
  drawn = view.selection;
}

/** Draws `sel` on its card or experiment row, where one is mounted.
 * @param {Selection | undefined} sel @param {boolean} selected */
function mark(sel, selected) {
  if (sel?.kind === "claim") {
    for (const g of boardGroups.values()) {
      const n = g.list.node(`claim:${sel.id}`);
      if (n?.classList.contains("circuit")) markCard(n, selected);
    }
  } else if (sel?.kind === "experiment") {
    const n = experimentList.node(`experiment:${sel.id}`);
    if (n) markRow(n, selected);
  }
}

/** Claims of the question in the engine's verdict order, untitled (each card names its verdict);
 * overlooked + new-data apart, titled. */
/** @param {Envelope} e @param {import("./lookups.js").Lookups} x @returns {[string, Claim[]][]} */
function groups(e, x) {
  const mine = x.byQuestion.get(view.question) ?? [];
  const existing = mine.filter((c) => !x.prospective.has(c.subject));
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
  for (const s of e.subjects.filter((y) => x.prospective.has(y.id))) {
    out.push([`On new data: ${s.title}`, mine.filter((c) => c.subject === s.id)]);
  }
  return out.filter(([, cs]) => cs.length > 0);
}

function renderScenario(
  /** @type {Envelope} */ e,
  /** @type {import("./lookups.js").Lookups} */ x,
) {
  const bar = byId("scenario");
  bar.classList.toggle("hypothetical", e.mode === "what-if");
  fill(
    byId("scenario-text"),
    e.mode === "what-if"
      ? [
          h("strong", { class: "what-if-lead" }, "Showing a what-if: "),
          "suppose ",
          e.overrides
            .filter((o) => x.facts.has(o.fact))
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

/** The question + layout the board's groups show. */
let boardShows = "";
/** The board's groups by layout + title: each a section with its own feed (U-long). */
/** @type {Map<string, { section: HTMLElement, head: string, list: LazyList }>} */
const boardGroups = new Map();
/** @param {string} id @param {[string, string]} noun */
const rowList = (id, noun) => new LazyList(byId(id), { posinset: true, sentinel: "li", noun });
const experimentList = rowList("experiment-list", ["experiment", "experiments"]);
const workList = rowList("work-list", ["fact", "facts"]);
const blockerList = rowList("blocker-list", ["fact", "facts"]);
const checkList = rowList("check-list", ["check", "checks"]);
/** The first board drawn: `tools/scale-gui.mjs` times the first view to the frame after it. */
let boardShown = false;

/** Every part of the page from the shown envelope. */
function render() {
  if (!env || !ix) return;
  const key = focusKey();
  const e = env;
  if (!e.questions.some((q) => q.id === view.question)) view.question = e.questions[0]?.id ?? "";
  byId("analysis-title").textContent = e.analysis.title;
  byId("analysis-summary").textContent = e.analysis.summary;
  renderScenario(e, ix);
  fill(byId("how-key"), factKey(e.counts));
  renderQuestions();
  renderBoard();
  renderInspector();
  renderExperiments();
  renderWork();
  const x = ix;
  blockerList.set(
    e.blockers.map((b) => ({
      key: `blocker:${b.fact}`,
      sig: () => JSON.stringify([b, x.facts.get(b.fact)?.text]),
      make: () => blockerRow(b, x, on),
    })),
  );
  byId("blockers").hidden = e.blockers.length === 0;
  const checks = e.lints.filter((l) => l.waived === undefined);
  checkList.set(
    checks.map((l, i) => ({
      key: `check:${i}`,
      sig: () => JSON.stringify(l),
      make: () => checkRow(l, on),
    })),
  );
  byId("checks").hidden = checks.length === 0;
  refocus(key);
  if (!boardShown) {
    boardShown = true;
    performance.mark("fvtrace:board");
    requestAnimationFrame(() => performance.mark("fvtrace:painted"));
  }
}

function renderQuestions() {
  if (!env || !ix) return;
  const x = ix;
  fill(
    byId("questions"),
    env.questions.map((q) =>
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
            renderQuestions();
            renderBoard();
          },
        },
        q.title,
        h(
          "small",
          { class: "question-count" },
          count(x.byQuestion.get(q.id)?.length ?? 0, "claim", "claims"),
        ),
      ),
    ),
  );
  const select = byIdAs("question-select", HTMLSelectElement);
  fill(
    select,
    env.questions.map((q) =>
      h("option", { value: q.id, selected: q.id === view.question }, q.title),
    ),
  );
  byId("question-title").textContent =
    env.questions.find((q) => q.id === view.question)?.text ?? "";
  for (const b of document.querySelectorAll("[data-layout]")) {
    b.setAttribute("aria-pressed", String(b.getAttribute("data-layout") === view.layout));
  }
}

/**
 * The board for the shown question + layout: one section per group, each a feed whose cards keep
 * their elements while their inputs stay the same (U-update); the selected card is mounted first
 * on the first board.
 */
function renderBoard() {
  if (!env || !ix) return;
  const x = ix;
  const gs = groups(env, x);
  // Another question or layout: other rows, so the lists start at their tops.
  const shows = `${view.layout}|${view.question}`;
  if (shows !== boardShows) {
    boardGroups.clear();
    boardShows = shows;
  }
  /** @type {[string, string, Row[]][]} */
  const parts = gs.map(([title, cs]) => [
    title,
    `${title}|${cs.length}`,
    cs.map((c) =>
      view.layout === "text"
        ? {
            key: `claim:${c.id}`,
            sig: () => claimSig(c, x, on),
            make: () => {
              askPairs(c);
              return textRow(c, x, on);
            },
          }
        : {
            key: `claim:${c.id}`,
            sig: () => claimSig(c, x, on),
            make: () => {
              askPairs(c);
              const card = circuit(c, x, on);
              markCard(card, selects(view.selection, "claim", c.id));
              return card;
            },
          },
    ),
  ]);
  if (view.layout === "text") {
    // Each open fact once, under the claims: what the text view asks to verify.
    const open = [...new Set(gs.flatMap(([, cs]) => cs.flatMap((c) => c.gaps.concat(c.premises))))];
    if (open.length)
      parts.push([
        "Facts to verify",
        `Facts to verify|${open.length}`,
        open.map((id) => ({
          key: `fact:${id}`,
          sig: () => openFactSig(id, x),
          make: () => openFactRow(id, x, on),
        })),
      ]);
  }
  /** @type {HTMLElement[]} */
  const sections = [];
  const seen = new Set();
  for (const [title, head, rows] of parts) {
    const name = `${view.layout}|${title}`;
    seen.add(name);
    let g = boardGroups.get(name);
    if (!g) {
      const feed =
        view.layout === "text"
          ? h("ul", { class: "text-list", "aria-label": title || "Claims" })
          : h("div", { class: "feed", role: "feed", "aria-label": title || "Claims" });
      const section = h("section", { class: "group" }, feed);
      const list = new LazyList(feed, {
        posinset: true,
        sentinel: view.layout === "text" ? "li" : "div",
        noun: title === "Facts to verify" ? ["fact", "facts"] : ["claim", "claims"],
      });
      g = { section, head: "", list };
      boardGroups.set(name, g);
    }
    if (g.head !== head) {
      const n = Number(head.slice(head.lastIndexOf("|") + 1));
      g.section.querySelector(".group-title")?.remove();
      const t = groupTitle(title, n);
      if (t) g.section.prepend(t);
      g.head = head;
    }
    g.list.set(rows);
    sections.push(g.section);
  }
  for (const name of boardGroups.keys()) if (!seen.has(name)) boardGroups.delete(name);
  const board = byId("board");
  if (sections.length !== board.children.length || sections.some((s, i) => board.children[i] !== s))
    board.replaceChildren(...sections);
  // A linked selection past the first rows renders first, in view (U-long).
  const sel = view.selection;
  if (!boardShown && sel?.kind === "claim")
    for (const g of boardGroups.values())
      if (!g.list.node(`claim:${sel.id}`)) g.list.show(`claim:${sel.id}`)?.scrollIntoView();
  drawSelection();
}

function renderInspector() {
  if (!ix) return;
  const sel = view.selection;
  const shown = details && sel && details.item === `${sel.kind}:${sel.id}` ? details : undefined;
  fill(byId("inspector"), inspector(ix, sel, on, shown));
  // `aria-busy` takes "true" (an empty value reads as false).
  if (shown?.state === "pending") byId("inspector").setAttribute("aria-busy", "true");
  else byId("inspector").removeAttribute("aria-busy");
}

function renderExperiments() {
  if (!env) return;
  for (const b of document.querySelectorAll("[data-filter]")) {
    b.setAttribute("aria-pressed", String(b.getAttribute("data-filter") === view.filter));
  }
  const shown = env.experiments.filter((e) => view.filter === "all" || e.kind === view.filter);
  experimentList.set(
    shown.length
      ? shown.map((e) => ({
          key: `experiment:${e.id}`,
          sig: () => JSON.stringify(e),
          make: () => {
            const row = experimentRow(e, on);
            markRow(row, selects(view.selection, "experiment", e.id));
            return row;
          },
        }))
      : [{ key: "none", sig: () => "", make: noExperiments }],
  );
  drawSelection();
}

function renderWork() {
  if (!env || !ix) return;
  const x = ix;
  // A count shows only above 0; a zero row keeps the column when another row has a count.
  const counted = env.work.some((w) => w.unlocks.length > 0);
  workList.set(
    env.work.length
      ? env.work.map((w) => ({
          key: `work:${w.fact}`,
          sig: () => workSig(w, x, counted),
          make: () => workRow(w, x, on, counted),
        }))
      : [{ key: "none", sig: () => "", make: noWork }],
  );
}

function wire() {
  const findInput = byIdAs("find", HTMLInputElement);
  findInput.addEventListener("input", () => void find());
  findInput.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter") {
      // Focus moves to the match: the key's own activation must not press the button it lands on.
      ev.preventDefault();
      const [first] = find();
      if (first) reveal(first.kind, first.id);
    } else if (ev.key === "Escape") {
      findInput.value = "";
      find();
    }
  });
  byId("reset").addEventListener("click", () => setWhatif(new Map()));
  byId("export-note").hidden = !exported;
  byId("question-select").addEventListener("change", (ev) => {
    if (ev.target instanceof HTMLSelectElement) view.question = ev.target.value;
    writeHash();
    renderQuestions();
    renderBoard();
  });
  for (const b of document.querySelectorAll("[data-layout]")) {
    b.addEventListener("click", () => {
      view.layout = b.getAttribute("data-layout") === "text" ? "text" : "circuits";
      writeHash();
      renderQuestions();
      renderBoard();
    });
  }
  for (const b of document.querySelectorAll("[data-filter]")) {
    b.addEventListener("click", () => {
      const f = b.getAttribute("data-filter");
      view.filter = f === "dry" || f === "wet" ? f : "all";
      writeHash();
      renderExperiments();
    });
  }
  window.addEventListener("popstate", () => {
    const before = view.spec;
    const selected = view.selection;
    readHash();
    if (view.spec === before && legacyAction === undefined) {
      render();
      if (`${selected?.kind}:${selected?.id}` !== `${view.selection?.kind}:${view.selection?.id}`)
        void loadDetails();
    } else void load();
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
  h("b", { class: "stat-count" }, counts[st].toLocaleString("en-US")),
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

// Start last: an exported page renders during this module's evaluation, so everything `render`
// reads (the key table, the lists above) must already be initialized.
if (!exported) takeToken();
readHash();
wire();
void load();
