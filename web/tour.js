// Guided tour: one step per part of the page, a spotlight on that part + a card that explains it.
// Own code, not driver.js: driver.js 1.10.2 writes its popover through innerHTML, which the
// server's Trusted Types CSP rejects. The tour explains the page; it states no verdict itself.

import { lamp } from "./circuit.js";
import { fill, h } from "./dom.js";
import { verdictMeanings, verdicts, word } from "./words.js";

/**
 * `compact` = a smaller part of the target, spotlit when the target is too tall to share the
 * screen with the card (a long section on a phone).
 * @typedef {{ target: string[], compact?: string[], title: string, body: () => (Node | string)[] }} Step
 */

/** @param {string} t */
const p = (t) => h("p", {}, t);

/** @type {Step[]} */
const steps = [
  {
    target: [],
    title: "Welcome to fvTrace",
    body: () => [
      p("fvTrace shows which claims an analysis can make, and what is missing for the others."),
      p(
        "The rule is strict: a claim can be made only when every fact it needs is verified, by a proof or by a proved checker on the actual data.",
      ),
      p("This tour takes about a minute. Press Next, or use the arrow keys."),
    ],
  },
  {
    target: [".how-key"],
    title: "Four verdicts",
    body: () => [
      p(
        "Every claim gets one of four verdicts, set by its weakest fact. The key pairs each kind of fact with the verdict it gives and counts the claims in the whole analysis.",
      ),
      h(
        "ul",
        { class: "tour-verdicts" },
        /** @type {const} */ (["can", "conditional", "open", "cannot"]).map((st) =>
          h(
            "li",
            {},
            lamp(st),
            h("span", {}, h("strong", {}, `${word(verdicts, st)}: `), word(verdictMeanings, st)),
          ),
        ),
      ),
      p(
        "A claim is also not possible when two facts exclude each other: when it needs both, or when a what-if supposes both. Its card names them.",
      ),
    ],
  },
  {
    target: ["#review"],
    title: "Review",
    body: () => [
      p(
        "A person should check that the claims and facts here match what the study actually did. Until someone records a review (with the command fvtrace review), every verdict is provisional.",
      ),
      p(
        "One review covers the claims and facts on record. If they change after it, this line says so.",
      ),
    ],
  },
  {
    target: ["#questions", ".mobile-question"],
    title: "Scientific questions",
    body: () => [
      p(
        "Claims are grouped by the scientific question they answer. Choose a question to see its claims.",
      ),
    ],
  },
  {
    target: ["article.circuit .claim-head"],
    title: "A claim",
    body: () => [
      p(
        "Each card is one claim. The label above its headline gives its id, its kind and its verdict.",
      ),
    ],
  },
  {
    target: ["article.circuit .contacts"],
    title: "The facts it needs",
    body: () => [
      p(
        "The diagram under a claim shows each fact that the claim needs, one symbol for each. The claim's verdict comes from its weakest fact.",
      ),
      p(
        "Most claims end with a reasoning fact: it says that the facts before it really support the claim as worded.",
      ),
      p("Press a fact’s name to read the fact and its evidence."),
    ],
  },
  {
    // The diagram's buttons: the lines above the diagram repeat each symbol as an inert mark.
    target: ['article.circuit .contacts button.switch:not([aria-disabled="true"])'],
    title: "Ask “what if?”",
    body: () => [
      p(
        "Press a fact’s symbol to suppose it reaches the best status that its route allows: verified, where a proof or a checker can reach it. Every verdict on the page is then recomputed under that supposition.",
      ),
      p("Nothing is recorded. Press the symbol again to undo."),
    ],
  },
  {
    target: ["#scenario"],
    title: "Real or supposed",
    body: () => [
      p(
        "This bar says whether the verdicts use the facts as recorded, or a what-if. During a what-if it turns amber and lists what is supposed.",
      ),
      p("Show the facts as recorded removes every supposition at once."),
    ],
  },
  {
    target: ["#inspector"],
    title: "Details",
    body: () => [
      p(
        "Select a claim, a fact or an experiment to see its details here: the evidence, how a fact can be established, and which claims need it.",
      ),
    ],
  },
  {
    target: [".board-heading .filters"],
    title: "Diagrams or text",
    body: () => [
      p(
        "Text shows the same claims as plain sentences, with the facts that still need work listed below them.",
      ),
    ],
  },
  {
    target: [".experiments"],
    compact: [".experiments > div:first-child"],
    title: "Experiments that fill the gaps",
    body: () => [
      p(
        "Suggested experiments. Dry ones reuse existing data, code or proofs. Wet ones need new samples or bench work.",
      ),
      p(
        "Each card says which claims it would make available if it succeeds, and which it could break if it fails. Select one to suppose either outcome.",
      ),
    ],
  },
  {
    target: [".work"],
    compact: [".work > div:first-child"],
    title: "Where verification pays",
    body: () => [
      p(
        "Facts ranked by how many claims each one would make available alone, at the best status that its route allows. This is where formal verification work pays most.",
      ),
    ],
  },
  {
    target: ["#blockers"],
    compact: ["#blockers > div:first-child"],
    title: "Violated facts",
    body: () => [
      p(
        "Facts shown to be false. A claim that needs one must be reworded, or new data must be collected.",
      ),
    ],
  },
  {
    target: ["#checks"],
    compact: ["#checks > div:first-child"],
    title: "What may be missing",
    body: () => [
      p(
        "Kinds of facts that a claim of this level usually needs but this analysis does not list. A waiver records why one is absent.",
      ),
    ],
  },
  {
    target: [],
    title: "End of the tour",
    body: () => [p("Start it again at any time with “Take the tour” at the top of the page.")],
  },
];

/** The first rendered, visible element of `sels`. @param {string[]} sels */
function find(sels) {
  for (const sel of sels)
    for (const el of document.querySelectorAll(sel))
      if (el instanceof HTMLElement && el.getClientRects().length && !el.closest("[hidden]"))
        return el;
  return null;
}

const pad = 6;
const gap = 16;
/** A card shorter than this shows little more than its buttons. */
const minCard = 200;
/** Phones dock the card at the bottom of the screen (CSS). */
const docked = () => innerWidth <= 760;

const spot = h("div", { class: "tour-spot", "aria-hidden": "true" });
// Room below the page while the tour runs, so a target at the page end can scroll to the top.
const room = h("div", { class: "tour-room", "aria-hidden": "true" });
const card = h("div", {
  class: "tour-card",
  role: "dialog",
  "aria-modal": "false",
  "aria-labelledby": "tour-title",
  tabindex: "-1",
});
/** @type {Step[]} */
let shown = [];
let at = 0;
/** @type {HTMLElement | null} */
let opener = null;

/** Starts the tour; focus returns to `from` at its end. @param {HTMLElement} from */
export function startTour(from) {
  opener = from;
  shown = steps.filter((st) => !st.target.length || find(st.target));
  document.body.append(room, spot, card);
  document.addEventListener("keydown", onKey);
  addEventListener("resize", place);
  addEventListener("scroll", place, { passive: true });
  go(0);
}

function end() {
  room.remove();
  spot.remove();
  card.remove();
  document.removeEventListener("keydown", onKey);
  removeEventListener("resize", place);
  removeEventListener("scroll", place);
  opener?.focus();
}

/** @param {KeyboardEvent} e */
function onKey(e) {
  if (e.key === "Escape") end();
  else if (card.contains(document.activeElement) && e.key === "ArrowRight" && at < shown.length - 1)
    go(at + 1);
  else if (card.contains(document.activeElement) && e.key === "ArrowLeft" && at > 0) go(at - 1);
}

/** @param {number} i */
function go(i) {
  at = i;
  const st = shown[i];
  if (!st) return end();
  const last = i === shown.length - 1;
  fill(
    card,
    h("p", { class: "tour-count" }, `${i + 1} of ${shown.length}`),
    h("h2", { id: "tour-title" }, st.title),
    h("div", { class: "tour-body" }, st.body()),
    h(
      "div",
      { class: "tour-buttons" },
      h("button", { class: "tour-close", type: "button", onclick: end }, "End the tour"),
      i > 0
        ? h(
            "button",
            { class: "action secondary", type: "button", onclick: () => go(i - 1) },
            "Back",
          )
        : null,
      h(
        "button",
        { class: "action", type: "button", onclick: () => (last ? end() : go(i + 1)) },
        last ? "Finish" : "Next",
      ),
    ),
  );
  const el = target(st);
  if (el) {
    const behavior = matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth";
    scrollTo({ top: scrollY + el.getBoundingClientRect().top - pad - lead(el), behavior });
  }
  place();
  card.focus({ preventScroll: true });
}

/** The step's element: its compact part when the whole is too tall to share the screen. @param {Step} st */
function target(st) {
  const el = st.target.length ? find(st.target) : null;
  if (!el || !st.compact) return el;
  const tall = el.getBoundingClientRect().height + 2 * pad > innerHeight - 3 * gap - minCard;
  return (tall && find(st.compact)) || el;
}

/** The card's height without a height limit of its own. */
function naturalHeight() {
  card.style.removeProperty("max-height");
  return card.getBoundingClientRect().height;
}

/** Where the target's spotlight should start on screen so that the card fits beside or below it. @param {HTMLElement} el */
function lead(el) {
  if (docked()) return gap;
  const r = el.getBoundingClientRect();
  const t = r.height + 2 * pad;
  const ch = naturalHeight();
  if (t + gap + ch <= innerHeight - 2 * gap) return (innerHeight - t - gap - ch) / 2;
  return beside(r, card.getBoundingClientRect().width) === null
    ? gap
    : Math.max(gap, (innerHeight - t) / 2);
}

/** The left edge of a card beside the target (right side first), or null when neither side fits. @param {DOMRect} r @param {number} cw */
function beside(r, cw) {
  if (r.right + pad + gap + cw <= innerWidth - gap) return r.right + pad + gap;
  if (r.left - pad - gap - cw >= gap) return r.left - pad - gap - cw;
  return null;
}

/** Keeps the spotlight on the step's element + the card clear of it, inside the viewport. */
function place() {
  const st = shown[at];
  const el = st ? target(st) : null;
  card.classList.toggle("centered", !el);
  spot.hidden = !el;
  const ch = naturalHeight();
  if (!el) {
    card.style.removeProperty("top");
    card.style.removeProperty("left");
    return;
  }
  const r = el.getBoundingClientRect();
  spot.style.top = `${r.top - pad}px`;
  spot.style.left = `${r.left - pad}px`;
  spot.style.width = `${r.width + 2 * pad}px`;
  spot.style.height = `${r.height + 2 * pad}px`;
  const below = innerHeight - (r.bottom + pad + gap) - gap;
  const above = r.top - pad - gap - gap;
  if (docked()) {
    // Docked at the bottom (CSS): the card keeps to the room under the target.
    card.style.removeProperty("top");
    card.style.removeProperty("left");
    if (ch > below) card.style.maxHeight = `${Math.max(below, minCard)}px`;
    return;
  }
  const cw = card.getBoundingClientRect().width;
  const left = Math.min(Math.max(gap, r.left), innerWidth - cw - gap);
  const side = beside(r, cw);
  let top;
  if (ch <= below) top = r.bottom + pad + gap;
  else if (ch <= above) top = r.top - pad - gap - ch;
  else if (side !== null) {
    card.style.left = `${side}px`;
    card.style.top = `${Math.min(Math.max(gap, r.top - pad), innerHeight - ch - gap)}px`;
    return;
  } else if (below >= above) {
    card.style.maxHeight = `${Math.max(below, minCard)}px`;
    top = r.bottom + pad + gap;
  } else {
    card.style.maxHeight = `${Math.max(above, minCard)}px`;
    top = gap;
  }
  card.style.top = `${top}px`;
  card.style.left = `${left}px`;
}
