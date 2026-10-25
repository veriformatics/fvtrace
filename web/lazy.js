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
/** Lists this long or shorter are drawn whole; a longer nested list starts with this many rows. */
const short = 40;
/** How near the viewport (px) an unmounted end starts mounting. */
const margin = 1500;

export class LazyList {
  /**
   * @param {HTMLElement} root the list element (its children = the mounted rows)
   * @param {{ posinset?: boolean, sentinel?: "li" | "div" | "span", noun?: [string, string],
   *   tail?: HTMLElement, itemRole?: string, endClass?: string, first?: number }} [opts]
   *   `posinset`: rows carry `aria-posinset` + `aria-setsize`; `sentinel`: the element type of the
   *   end markers; `noun`: what a row is (singular, plural), for the end markers' words; `tail`: an
   *   element that stays after the rows (a circuit's lamp); `itemRole`: each row's role;
   *   `endClass`: a class the end markers add; `first`: the rows an empty window mounts at once
   *   (default: one time step's worth)
   */
  constructor(root, opts = {}) {
    this.root = root;
    this.posinset = opts.posinset ?? false;
    this.noun = opts.noun ?? ["item", "items"];
    this.tail = opts.tail;
    this.itemRole = opts.itemRole;
    this.first = opts.first;
    owners.set(root, this);
    const tag = opts.sentinel ?? "div";
    // Rows come by position, made on demand: a long nested list (a claim's needs in its details)
    // makes only the rows it mounts, so opening it costs the same at any length (kernel.md U-select).
    this.count = 0;
    /** @type {(i: number) => Row | undefined} */
    this.rowAt = () => undefined;
    /** Positions by key, built on the first lookup after each `set`.
     * @type {Map<string, number> | undefined} */
    this.keys = undefined;
    /** Each mounted node's position. @type {WeakMap<Node, number>} */
    this.positions = new WeakMap();
    /** Mounted window `[lo, hi)`: nodes by key, with the signature each was made from.
     * @type {Map<string, { node: HTMLElement, sig: string }>} */
    this.mounted = new Map();
    this.lo = 0;
    this.hi = 0;
    this.top = document.createElement(tag);
    this.bottom = document.createElement(tag);
    for (const s of [this.top, this.bottom]) {
      s.className = opts.endClass ? `lazy-end ${opts.endClass}` : "lazy-end";
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
      const row = rowNode(e.target, root);
      const i = row ? this.positions.get(row) : undefined;
      if (i === undefined) return;
      if (i >= this.hi - 3) this.grow(this.hi + around);
      if (i <= this.lo + 2) this.grow(this.hi, Math.max(0, this.lo - around));
    });
  }

  /** The rows' count. */
  get size() {
    return this.count;
  }

  /**
   * Replaces the rows. Mounted rows whose key + signature stay keep their nodes; the window keeps
   * its place (`keep` = a key it must hold, mounted first), else it starts at the top.
   * @param {Row[]} rows @param {{ keep?: string }} [opts]
   */
  set(rows, opts = {}) {
    this.setEach(rows.length, (i) => rows[i], opts);
  }

  /**
   * `set` over `n` rows that `rowAt` makes on demand (the row at a position keeps its key +
   * content until the next `set`). @param {number} n
   * @param {(i: number) => Row | undefined} rowAt @param {{ keep?: string }} [opts]
   */
  setEach(n, rowAt, opts = {}) {
    const old = this.mounted;
    this.count = n;
    this.rowAt = rowAt;
    this.keys = undefined;
    const want = opts.keep === undefined ? undefined : this.indexOf(opts.keep);
    let lo = Math.min(this.lo, n);
    let hi = Math.min(Math.max(this.hi, lo), n);
    if (want !== undefined && (want < lo || want >= hi)) {
      lo = Math.max(0, want - around);
      hi = Math.min(n, want + around);
    }
    this.mounted = new Map();
    /** @type {HTMLElement[]} */
    const nodes = [];
    for (let i = lo; i < hi; i++) {
      const row = rowAt(i);
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
    if (hi === lo) {
      if (this.first === undefined) this.step(["bottom"]);
      else this.grow(hi + this.first);
    }
  }

  /** The position of the row `key`. @param {string} key */
  indexOf(key) {
    if (!this.keys) {
      this.keys = new Map();
      for (let i = 0; i < this.count; i++) {
        const row = this.rowAt(i);
        if (row) this.keys.set(row.key, i);
      }
    }
    return this.keys.get(key);
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
    const i = this.indexOf(key);
    if (i === undefined) return undefined;
    if (i < this.lo || i >= this.hi) {
      if (i >= this.hi && i < this.hi + around * 4) this.grow(i + around);
      else if (i < this.lo && i >= this.lo - around * 4)
        this.grow(this.hi, Math.max(0, i - around));
      else this.setEach(this.count, this.rowAt, { keep: key });
    }
    return this.node(key);
  }

  /**
   * Extends the window to `[lo, hi)`. Rows mounted above the viewport keep the visible ones in
   * place (the page scrolls by their height). @param {number} hi @param {number} [lo]
   */
  grow(hi, lo = this.lo) {
    hi = Math.min(hi, this.count);
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
      while (this.hi + after.length < this.count && !spent())
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
    const row = this.rowAt(i);
    if (!row) throw new RangeError(`no row ${i}`);
    const node = row.make();
    this.mark(node, row.key, i);
    this.mounted.set(row.key, { node, sig: row.sig() });
    return node;
  }

  /** @param {HTMLElement} node @param {string} key @param {number} i */
  mark(node, key, i) {
    node.dataset["row"] = key;
    this.positions.set(node, i);
    if (this.itemRole) node.setAttribute("role", this.itemRole);
    if (this.posinset) {
      node.setAttribute("aria-posinset", String(i + 1));
      node.setAttribute("aria-setsize", String(this.count));
    }
  }

  /** Watches an end only while rows lie beyond it; each such end says how many. */
  observe() {
    this.below.disconnect();
    this.above.disconnect();
    this.top.hidden = this.lo === 0;
    this.bottom.hidden = this.hi >= this.count;
    const [one, many] = this.noun;
    if (!this.top.hidden)
      this.top.textContent = `${count(this.lo, `earlier ${one}`, `earlier ${many}`)} ${this.lo === 1 ? "appears" : "appear"} as you scroll up.`;
    if (!this.bottom.hidden)
      this.bottom.textContent = `Showing ${(this.hi - this.lo).toLocaleString("en-US")} of ${count(this.count, one, many)}. More appear as you scroll.`;
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

/** Each list element's lazy list (a re-render mounts a focused row through it). */
/** @type {WeakMap<HTMLElement, LazyList>} */
const owners = new WeakMap();

/** Mounts the row `key` of the lazy list at `root`, when `root` is one; returns its node.
 * @param {Element} root @param {string} key */
export function showIn(root, key) {
  return root instanceof HTMLElement ? owners.get(root)?.show(key) : undefined;
}

/** The mounted row holding `target`. @param {EventTarget | null} target @param {HTMLElement} root */
function rowNode(target, root) {
  let el = target instanceof Element ? target : null;
  while (el && el.parentElement !== root) el = el.parentElement;
  return el ?? undefined;
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

/**
 * A list element holding `items`: drawn whole when short, else mounted as it nears the viewport
 * (`LazyList`, rows naming their position + the list's size: an inline list takes the list roles).
 * @template T @param {HTMLElement} el the empty list element
 * @param {T[]} items @param {(item: T, i: number) => HTMLElement} make
 * @param {{ noun?: [string, string], tail?: HTMLElement, keyOf?: (item: T) => string,
 *   endClass?: string }} [opts] `noun`: what an item is (singular, plural); `tail`: an element
 *   after the items; `keyOf`: an item's key (default its position), so a re-render can mount a
 *   focused one (`showIn`); `endClass`: a class for the end markers
 * @returns {HTMLElement}
 */
export function listOf(el, items, make, opts = {}) {
  if (items.length <= short) {
    el.append(...items.map(make), ...(opts.tail ? [opts.tail] : []));
    return el;
  }
  const inline = !(el instanceof HTMLUListElement);
  if (inline) el.setAttribute("role", "list");
  const lazy = new LazyList(el, {
    sentinel: inline ? "span" : "li",
    posinset: true,
    ...(inline ? { itemRole: "listitem" } : {}),
    ...(opts.noun ? { noun: opts.noun } : {}),
    ...(opts.tail ? { tail: opts.tail } : {}),
    ...(opts.endClass ? { endClass: opts.endClass } : {}),
    first: short,
  });
  const keyOf = opts.keyOf;
  lazy.setEach(items.length, (i) => {
    const x = items[i];
    return x === undefined
      ? undefined
      : { key: keyOf ? keyOf(x) : String(i), sig: () => "", make: () => make(x, i) };
  });
  return el;
}
