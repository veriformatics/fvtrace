// Renovate's regex managers compile each matchString with the `g` flag alone (no `m`): `^` anchors
// at the file start only. Each custom manager must extract the dependencies of the file it names.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const root = new URL("../../", import.meta.url);
/** @type {unknown} */
const raw = JSON.parse(readFileSync(new URL("renovate.json", root), "utf8"));

/** @param {unknown} v @returns {string[]} */
function strings(v) {
  return Array.isArray(v) ? v.filter((x) => typeof x === "string") : [];
}

/** The regex custom managers, narrowed from the parsed JSON. */
const managers = (
  typeof raw === "object" &&
  raw !== null &&
  "customManagers" in raw &&
  Array.isArray(raw.customManagers)
    ? raw.customManagers
    : []
).map((/** @type {unknown} */ m) =>
  typeof m === "object" && m !== null
    ? {
        managerFilePatterns: strings("managerFilePatterns" in m ? m.managerFilePatterns : []),
        matchStrings: strings("matchStrings" in m ? m.matchStrings : []),
      }
    : { managerFilePatterns: [], matchStrings: [] },
);

/** @type {Record<string, string[]>} file → dependency names its managers must find */
const expected = {
  "lean-toolchain": [""],
  "tools/tools.lock": ["actionlint", "betterleaks", "zizmor"],
  "tools/wasm.lock": ["emsdk", "lean-runtime"],
};

void test("the regex custom managers extract the dependencies of each file", () => {
  for (const [file, deps] of Object.entries(expected)) {
    const mine = managers.filter((m) =>
      m.managerFilePatterns.some((p) => new RegExp(p.slice(1, -1)).test(file)),
    );
    assert.ok(mine.length > 0, `no custom manager for ${file}`);
    const text = readFileSync(new URL(file, root), "utf8");
    const found = mine.flatMap((manager) =>
      manager.matchStrings.flatMap((s) =>
        [...text.matchAll(new RegExp(s, "g"))].map((m) => m.groups?.["depName"] ?? ""),
      ),
    );
    for (const d of deps)
      assert.ok(found.includes(d), `${file}: no match for "${d}" (got ${JSON.stringify(found)})`);
  }
});
