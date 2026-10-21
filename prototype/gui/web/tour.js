// Guided tour: one step per part of the page, a spotlight on that part + a card that explains it.
// Own code, not driver.js: driver.js 1.10.2 writes its popover through innerHTML, which the
// server's Trusted Types CSP rejects. The tour explains the page; it states no verdict itself.

import { lamp } from "./circuit.js";
import { fill, h } from "./dom.js";
import { verdictMeanings, verdicts, word } from "./words.js";

/** @typedef {{ target: string[], title: string, body: () => (Node | string)[] }} Step */

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
    ],
  },
  {
    target: ["#review"],
    title: "Review",
    body: () => [
      p(
        "A person should check that the claims and facts here match what the study actually did. Until someone records a review (with the command fvtrace review), every verdict is provisional.",
      ),
      p("One review covers the whole page. If anything here changes after it, this line says so."),
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
        "Each card is one claim. The symbol beside it and the words under its headline give its verdict.",
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
      p("The last fact says that the facts before it really support the claim as worded."),
      p("Press a fact’s name to read the fact and its evidence."),
    ],
  },
  {
    target: ["article.circuit .switch.open", "article.circuit .switch.assumed"],
    title: "Ask “what if?”",
    body: () => [
      p(
        "Press a fact’s symbol to suppose it were verified. Every verdict on the page is then recomputed under that supposition.",
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
    title: "Where verification pays",
    body: () => [
      p(
        "Facts ranked by how many claims verifying each one alone would make available. This is where formal verification work pays most.",
      ),
    ],
  },
  {
    target: ["#blockers"],
    title: "Violated facts",
    body: () => [
      p(
        "Facts shown to be false. A claim that needs one must be reworded, or new data must be collected.",
      ),
    ],
  },
  {
    target: ["#checks"],
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

const spot = h("div", { class: "tour-spot", "aria-hidden": "true" });
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
  document.body.append(spot, card);
  document.addEventListener("keydown", onKey);
  addEventListener("resize", place);
  addEventListener("scroll", place, { passive: true });
  go(0);
}

function end() {
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
  const el = st.target.length ? find(st.target) : null;
  const behavior = matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth";
  // Narrow screens dock the card at the bottom, so the element goes to the top, above it.
  if (el && innerWidth <= 760)
    scrollTo({ top: scrollY + el.getBoundingClientRect().top - 16, behavior });
  else el?.scrollIntoView({ block: "center", behavior });
  place();
  card.focus({ preventScroll: true });
}

/** Keeps the spotlight on the step's element + the card beside it, inside the viewport. */
function place() {
  const st = shown[at];
  const el = st?.target.length ? find(st.target) : null;
  card.classList.toggle("centered", !el);
  spot.hidden = !el;
  if (!el) {
    card.style.removeProperty("top");
    card.style.removeProperty("left");
    return;
  }
  const r = el.getBoundingClientRect();
  const pad = 6;
  spot.style.top = `${r.top - pad}px`;
  spot.style.left = `${r.left - pad}px`;
  spot.style.width = `${r.width + 2 * pad}px`;
  spot.style.height = `${r.height + 2 * pad}px`;
  if (innerWidth <= 760) {
    // the card docks at the bottom (CSS)
    card.style.removeProperty("top");
    card.style.removeProperty("left");
    return;
  }
  const c = card.getBoundingClientRect();
  const gap = 16;
  const below = r.bottom + pad + gap;
  const above = r.top - pad - gap - c.height;
  const top =
    below + c.height <= innerHeight
      ? below
      : above >= 0
        ? above
        : Math.max(gap, innerHeight - c.height - gap);
  const left = Math.min(Math.max(gap, r.left), innerWidth - c.width - gap);
  card.style.top = `${top}px`;
  card.style.left = `${left}px`;
}
