// Long lists (kernel.md U-long, U-access): a list mounts the rows its time budget holds, the rest
// as an end of the mounted window nears the viewport or keyboard focus reaches it; every row stays
// reachable by scrolling. A row keeps its node while its key + signature stay the same (U-update:
// an unchanged card is the same element after a what-if). An end with rows beyond it says how many.

import { count } from "./words.js";

/**
 * A row: its key, a signature of everything its node shows (computed for mounted rows alone), and
 * the node it makes.
 * @typedef {{ key: string, sig: () => string, make: () => HTMLElement }} Row
 */

/** Milliseconds one mounting step may take before it yields to the browser. */
const budget = 8;
/** Rows mounted around a row that must show (a selection, a found item). */
const around = 20;
/** How near the viewport (px) an unmounted end starts mounting. */
const margin = 1500;

export class LazyList {
  /**
   * @param {HTMLElement} root the list element (its children = the mounted rows)
   * @param {{ posinset?: boolean, sentinel?: "li" | "div" | "span", noun?: [string, string],
   *   tail?: HTMLElement }} [opts] `posinset`: rows carry `aria-posinset` + `aria-setsize`;
   *   `sentinel`: the element type of the end markers; `noun`: what a row is (singular, plural),
   *   for the end markers' words; `tail`: an element that stays after the rows (a circuit's lamp)
   */
  constructor(root, opts = {}) {
    this.root = root;
    this.posinset = opts.posinset ?? false;
    this.noun = opts.noun ?? ["item", "items"];
    this.tail = opts.tail;
    const tag = opts.sentinel ?? "div";
    /** @type {Row[]} */
    this.rows = [];
    /** @type {Map<string, number>} */
    this.at = new Map();
    /** Mounted window `[lo, hi)`: nodes by key, with the signature each was made from.
     * @type {Map<string, { node: HTMLElement, sig: string }>} */
    this.mounted = new Map();
    this.lo = 0;
    this.hi = 0;
    this.top = document.createElement(tag);
    this.bottom = document.createElement(tag);
    for (const s of [this.top, this.bottom]) {
      s.className = "lazy-end";
      s.setAttribute("aria-hidden", "true");
    }
    // Each end looks one way: the bottom one below the viewport, the top one above it. An end
    // the reader has scrolled past stays still (a symmetric margin kept the board's bottom end in
    // range under scroll anchoring while the reader stood below it: every row mounted).
    this.below = new IntersectionObserver((entries) => this.near(entries), {
      rootMargin: `0px 0px ${margin}px 0px`,
    });
    this.above = new IntersectionObserver((entries) => this.near(entries), {
      rootMargin: `${margin}px 0px 0px 0px`,
    });
    // Keyboard: focus inside the last (first) mounted rows mounts the next (earlier) ones before
    // the next Tab looks for them.
    root.addEventListener("focusin", (e) => {
      const key = rowKey(e.target, root);
      const i = key === undefined ? undefined : this.at.get(key);
      if (i === undefined) return;
      if (i >= this.hi - 3) this.grow(this.hi + around);
      if (i <= this.lo + 2) this.grow(this.hi, Math.max(0, this.lo - around));
    });
  }

  /** The rows' count. */
  get size() {
    return this.rows.length;
  }

  /**
   * Replaces the rows. Mounted rows whose key + signature stay keep their nodes; the window keeps
   * its place (`keep` = a key it must hold, mounted first), else it starts at the top.
   * @param {Row[]} rows @param {{ keep?: string }} [opts]
   */
  set(rows, opts = {}) {
    const old = this.mounted;
    this.rows = rows;
    this.at = new Map(rows.map((r, i) => [r.key, i]));
    const want = opts.keep === undefined ? undefined : this.at.get(opts.keep);
    let lo = Math.min(this.lo, rows.length);
    let hi = Math.min(Math.max(this.hi, lo), rows.length);
    if (want !== undefined && (want < lo || want >= hi)) {
      lo = Math.max(0, want - around);
      hi = Math.min(rows.length, want + around);
    }
    this.mounted = new Map();
    /** @type {HTMLElement[]} */
    const nodes = [];
    for (let i = lo; i < hi; i++) {
      const row = rows[i];
      if (!row) continue;
      const sig = row.sig();
      const had = old.get(row.key);
      const node = had && had.sig === sig ? had.node : row.make();
      this.mark(node, row.key, i);
      this.mounted.set(row.key, { node, sig });
      nodes.push(node);
    }
    this.lo = lo;
    this.hi = hi;
    place(this.root, [this.top, ...nodes, this.bottom, ...(this.tail ? [this.tail] : [])]);
    this.observe();
    if (hi === lo) this.step(["bottom"]);
  }

  /** The mounted node of a row, when it is mounted. @param {string} key */
  node(key) {
    return this.mounted.get(key)?.node;
  }

  /**
   * Mounts the row `key` (and the rows around it when it lies far from the window); returns its
   * node. @param {string} key
   */
  show(key) {
    const i = this.at.get(key);
    if (i === undefined) return undefined;
    if (i < this.lo || i >= this.hi) {
      if (i >= this.hi && i < this.hi + around * 4) this.grow(i + around);
      else if (i < this.lo && i >= this.lo - around * 4)
        this.grow(this.hi, Math.max(0, i - around));
      else this.set(this.rows, { keep: key });
    }
    return this.node(key);
  }

  /**
   * Extends the window to `[lo, hi)`. Rows mounted above the viewport keep the visible ones in
   * place (the page scrolls by their height). @param {number} hi @param {number} [lo]
   */
  grow(hi, lo = this.lo) {
    hi = Math.min(hi, this.rows.length);
    lo = Math.max(lo, 0);
    /** @type {HTMLElement[]} */
    const after = [];
    for (let i = this.hi; i < hi; i++) after.push(this.mount(i));
    /** @type {HTMLElement[]} */
    const before = [];
    for (let i = lo; i < this.lo; i++) before.push(this.mount(i));
    this.insert(before, after);
  }

  /**
   * Mounts rows past each end in `ends` until the step's time is spent: the first view's rows, then
   * each step an end comes near the viewport. @param {("top" | "bottom")[]} ends
   */
  step(ends) {
    const start = performance.now();
    /** @type {HTMLElement[]} */
    const after = [];
    /** @type {HTMLElement[]} */
    const before = [];
    const spent = () => after.length + before.length > 0 && performance.now() - start >= budget;
    if (ends.includes("bottom"))
      while (this.hi + after.length < this.rows.length && !spent())
        after.push(this.mount(this.hi + after.length));
    if (ends.includes("top"))
      while (this.lo - before.length > 0 && !spent())
        before.unshift(this.mount(this.lo - before.length - 1));
    this.insert(before, after);
  }

  /** Puts freshly mounted rows at the window's ends, keeping the visible rows in place.
   * @param {HTMLElement[]} before @param {HTMLElement[]} after */
  insert(before, after) {
    if (after.length) {
      this.bottom.before(...after);
      this.hi += after.length;
    }
    if (before.length) {
      const anchor = this.top.nextElementSibling;
      const was = anchor?.getBoundingClientRect().top ?? 0;
      this.top.after(...before);
      this.lo -= before.length;
      // Browsers without scroll anchoring would jump by the new rows' height.
      const shift = (anchor?.getBoundingClientRect().top ?? 0) - was;
      if (anchor && shift !== 0) window.scrollBy(0, shift);
    }
    this.observe();
  }

  /** @param {number} i */
  mount(i) {
    const row = this.rows[i];
    if (!row) throw new RangeError(`no row ${i}`);
    const node = row.make();
    this.mark(node, row.key, i);
    this.mounted.set(row.key, { node, sig: row.sig() });
    return node;
  }

  /** @param {HTMLElement} node @param {string} key @param {number} i */
  mark(node, key, i) {
    node.dataset["row"] = key;
    if (this.posinset) {
      node.setAttribute("aria-posinset", String(i + 1));
      node.setAttribute("aria-setsize", String(this.rows.length));
    }
  }

  /** Watches an end only while rows lie beyond it; each such end says how many. */
  observe() {
    this.below.disconnect();
    this.above.disconnect();
    this.top.hidden = this.lo === 0;
    this.bottom.hidden = this.hi >= this.rows.length;
    const [one, many] = this.noun;
    if (!this.top.hidden)
      this.top.textContent = `${count(this.lo, `earlier ${one}`, `earlier ${many}`)} ${this.lo === 1 ? "appears" : "appear"} as you scroll up.`;
    if (!this.bottom.hidden)
      this.bottom.textContent = `Showing ${(this.hi - this.lo).toLocaleString("en-US")} of ${count(this.rows.length, one, many)}. More appear as you scroll.`;
    if (!this.top.hidden) this.above.observe(this.top);
    if (!this.bottom.hidden) this.below.observe(this.bottom);
  }

  /** An end near the viewport: mount rows there within the budget; the fresh observation that
   * follows reports at once whether that end is still near. @param {IntersectionObserverEntry[]} entries */
  near(entries) {
    /** @type {("top" | "bottom")[]} */
    const ends = [];
    for (const e of entries)
      if (e.isIntersecting) ends.push(e.target === this.top ? "top" : "bottom");
    if (ends.length) this.step(ends);
  }
}

/** The row key of the mounted row holding `target`. @param {EventTarget | null} target
 * @param {HTMLElement} root */
function rowKey(target, root) {
  let el = target instanceof Element ? target : null;
  while (el && el.parentElement !== root) el = el.parentElement;
  return el instanceof HTMLElement ? el.dataset["row"] : undefined;
}

/**
 * Makes `nodes` the children of `root`, in order, moving only the nodes out of place (a node that
 * stays where it was keeps focus and selection).
 * @param {HTMLElement} root @param {Node[]} nodes
 */
function place(root, nodes) {
  const keep = new Set(nodes);
  for (let child = root.firstChild; child;) {
    const next = child.nextSibling;
    if (!keep.has(child)) child.remove();
    child = next;
  }
  let cursor = root.firstChild;
  for (const n of nodes) {
    if (cursor === n) cursor = cursor.nextSibling;
    else root.insertBefore(n, cursor);
  }
}

/** Lists this long or shorter are drawn whole. */
const short = 40;

/**
 * A list element holding `items`: drawn whole when short, else mounted as it nears the viewport
 * (`LazyList`). @template T @param {HTMLElement} el the empty list element
 * @param {T[]} items @param {(item: T, i: number) => HTMLElement} make
 * @param {[string, string]} [noun] what an item is (singular, plural)
 * @param {HTMLElement} [tail] an element after the items @returns {HTMLElement}
 */
export function listOf(el, items, make, noun, tail) {
  if (items.length <= short) {
    el.append(...items.map(make), ...(tail ? [tail] : []));
    return el;
  }
  const lazy = new LazyList(el, {
    sentinel: el instanceof HTMLUListElement ? "li" : "span",
    ...(noun ? { noun } : {}),
    ...(tail ? { tail } : {}),
  });
  lazy.set(items.map((x, i) => ({ key: String(i), sig: () => "", make: () => make(x, i) })));
  return el;
}
