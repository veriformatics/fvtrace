// DOM construction without HTML strings: elements, attributes and text nodes only (the server's
// Trusted Types policy makes every HTML-string sink throw).

/** @typedef {Node | string | null | undefined | false} Child */
/** Children nest freely; `null`, `undefined` + `false` drop out. */
/** @typedef {Child | Children[]} Children */

/** @param {Children[]} cs @returns {(Node | string)[]} */
function flatten(cs) {
  /** @type {(Node | string)[]} */
  const out = [];
  /** @param {Children} c */
  const walk = (c) => {
    if (Array.isArray(c)) c.forEach(walk);
    else if (c !== null && c !== undefined && c !== false) out.push(c);
  };
  cs.forEach(walk);
  return out;
}

/**
 * An element with attributes (`on…` keys = listeners; `false`/`undefined` values = absent) and
 * children (strings become text nodes).
 * @template {keyof HTMLElementTagNameMap} K
 * @param {K} tag
 * @param {Record<string, string | number | boolean | undefined | ((e: Event) => void)>} [attrs]
 * @param {...Children} children
 * @returns {HTMLElementTagNameMap[K]}
 */
export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (typeof v === "function") el.addEventListener(k.slice(2), v);
    else if (v === true) el.setAttribute(k, "");
    else if (v !== false && v !== undefined) el.setAttribute(k, String(v));
  }
  el.append(...flatten(children));
  return el;
}

const svgNs = "http://www.w3.org/2000/svg";

/**
 * An SVG element with attributes + children.
 * @param {string} tag @param {Record<string, string>} [attrs] @param {...SVGElement} children
 * @returns {SVGElement}
 */
export function s(tag, attrs = {}, ...children) {
  const el = document.createElementNS(svgNs, tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  el.append(...children);
  return el;
}

/** @param {string} id @returns {HTMLElement} */
export function byId(id) {
  const el = document.getElementById(id);
  if (!el) throw new Error(`missing #${id}`);
  return el;
}

/**
 * The element `#id`, checked to be a `cls`.
 * @template {HTMLElement} T
 * @param {string} id @param {new () => T} cls @returns {T}
 */
export function byIdAs(id, cls) {
  const el = byId(id);
  if (!(el instanceof cls)) throw new Error(`#${id} is not a ${cls.name}`);
  return el;
}

/** Replaces the children of `el`. @param {Element} el @param {...Children} children */
export function fill(el, ...children) {
  el.replaceChildren(...flatten(children));
}

/**
 * A container's click handler that opens its details, except when the click ends a text selection
 * or lands on a control inside it: text stays selectable for copying, the id button is the
 * keyboard + screen-reader route.
 * @param {() => void} open @returns {(e: Event) => void}
 */
export const clickToOpen = (open) => (e) => {
  if (document.getSelection()?.toString()) return;
  if (e.target instanceof Element && e.target.closest("button, summary, a")) return;
  open();
};

/**
 * An underlined id that opens its details; the readable text beside it stays plain.
 * @param {string} id @param {string} key @param {() => void} open @param {boolean} [pressed]
 */
export const idButton = (id, key, open, pressed) =>
  h(
    "button",
    {
      class: "ref",
      "data-key": key,
      type: "button",
      "aria-pressed": pressed === undefined ? undefined : String(pressed),
      onclick: open,
    },
    id,
  );
