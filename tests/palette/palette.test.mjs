// The GUI palette (custom properties in web/style.css), computed: every text color readable on
// the surfaces it sits on, every state mark visible against the panel, and the four state hues
// told apart with and without protan + deutan color vision (Machado simulation, OKLab distance).
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { converter, differenceEuclidean, parse, wcagContrast } from "culori";

const css = readFileSync(
  process.env["FVTRACE_PALETTE_CSS"] ?? new URL("../../web/style.css", import.meta.url),
  "utf8",
);
/** @type {Record<string, string>} */
const palette = Object.fromEntries(
  [...css.matchAll(/--([a-z-]+):\s*(#[0-9a-f]{3,6})/g)].map((m) => [m[1] ?? "", m[2] ?? ""]),
);

/** @param {string} name */
function color(name) {
  const hex = palette[name];
  assert.ok(hex, `--${name} is defined`);
  const c = parse(hex);
  assert.ok(c, `--${name} parses`);
  return c;
}

const okDistance = differenceEuclidean("oklab");

/** Text color → the surfaces it is drawn on. */
const text = {
  ink: ["paper", "panel", "wash", "assumption-wash", "verified-wash"],
  conductor: ["paper", "panel", "assumption-wash", "wash"],
  verified: ["paper", "panel", "verified-wash"],
  assumption: ["paper", "panel", "assumption-wash"],
  panel: ["ink", "verified"],
};

void test("text contrast ≥ 4.5:1 (WCAG AA)", () => {
  for (const [fg, bgs] of Object.entries(text)) {
    for (const bg of bgs) {
      const ratio = wcagContrast(color(fg), color(bg));
      assert.ok(ratio >= 4.5, `--${fg} on --${bg}: ${ratio.toFixed(2)}:1 < 4.5:1`);
    }
  }
});

const states = ["verified", "assumption", "conductor", "ink"];

void test("state marks ≥ 3:1 against the panel", () => {
  for (const s of states) {
    const ratio = wcagContrast(color(s), color("panel"));
    assert.ok(ratio >= 3, `--${s} on --panel: ${ratio.toFixed(2)}:1 < 3:1`);
  }
});

// Machado, Oliveira + Fernandes (2009) at severity 1. The matrices act on linear RGB (ColorAide's
// `filters/cvd.py`: `ALLOWED_SPACES = ('srgb-linear',)`); Culori's `filterDeficiency*` applies them
// to gamma-encoded sRGB, which overstated the protan separation of the verified + assumption hues.
const PROTAN = [
  [0.152286, 1.052583, -0.204868],
  [0.114503, 0.786281, 0.099216],
  [-0.003882, -0.048116, 1.051998],
];
const DEUTAN = [
  [0.367322, 0.860646, -0.227968],
  [0.280085, 0.672501, 0.047413],
  [-0.01182, 0.04294, 0.968881],
];
const toLinear = converter("lrgb");
/** @param {number[][]} m @returns {(c: import("culori").Color) => import("culori").Color} */
const machado = (m) => (c) => {
  const { r, g, b } = toLinear(c);
  const row = (/** @type {number} */ i) => {
    const [x = 0, y = 0, z = 0] = m[i] ?? [];
    return x * r + y * g + z * b;
  };
  return { mode: "lrgb", r: row(0), g: row(1), b: row(2) };
};

void test("state hues differ: OKLab ΔE×100 ≥ 15 unsimulated, ≥ 8 under protan + deutan", () => {
  /** @type {[string, (c: import("culori").Color) => import("culori").Color, number][]} */
  const views = [
    ["unsimulated", (c) => c, 15],
    ["protan", machado(PROTAN), 8],
    ["deutan", machado(DEUTAN), 8],
  ];
  for (const [view, simulate, floor] of views) {
    for (const [i, a] of states.entries()) {
      for (const b of states.slice(i + 1)) {
        const d = okDistance(simulate(color(a)), simulate(color(b))) * 100;
        assert.ok(d >= floor, `${view}: --${a} vs --${b} ΔE ${d.toFixed(1)} < ${floor}`);
      }
    }
  }
});
