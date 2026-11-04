// Renovate's regex managers compile each matchString with the `g` flag alone (no `m`): `^` anchors
// at the file start only. Each custom manager must extract the dependencies of the file it names.
// The hosted app compiles every regex with RE2, the tests here with JS RegExp: `re2Rejects` names
// what JS accepts + RE2 refuses (github.com/google/re2/wiki/Syntax, "NOT SUPPORTED" rows), so a
// pattern passing here + failing in the app fails here. Option validity = `tools/renovate.sh check`.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const root = new URL("../../", import.meta.url);
const config = process.env["FVTRACE_RENOVATE_JSON"] ?? new URL("renovate.json", root);
/** @type {unknown} */
const raw = JSON.parse(readFileSync(config, "utf8"));

/** @param {unknown} v @returns {string[]} */
function strings(v) {
  return Array.isArray(v) ? v.filter((x) => typeof x === "string") : [];
}

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
  "tools/tools.lock": ["actionlint", "betterleaks", "elan-init", "zizmor"],
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

/** @param {unknown} v @param {string} key @returns {[string, string][]} every string + its key */
function entries(v, key = "") {
  if (typeof v === "string") return [[key, v]];
  if (Array.isArray(v)) return v.flatMap((x) => entries(x, key));
  if (typeof v === "object" && v !== null)
    return Object.entries(v).flatMap(([k, x]) => entries(x, k));
  return [];
}

/** Renovate's regex strings: `matchStrings`, `extractVersionTemplate` + every `/…/flags` pattern. */
const regexes = entries(raw).flatMap(([key, s]) => {
  const slashed = /^\/(.+)\/[a-z]*$/s.exec(s);
  if (slashed?.[1] !== undefined) return [slashed[1]];
  return key === "matchStrings" || key === "extractVersionTemplate" ? [s] : [];
});

/** @param {string} re @returns {string | undefined} the first construct RE2 refuses */
function re2Rejects(re) {
  let inClass = false;
  for (let i = 0; i < re.length; i++) {
    const c = re[i];
    if (c === "\\") {
      const n = re[i + 1] ?? "";
      i++;
      if (/[0-9A-Za-z]/.test(n) && !/[dDsSwWfnrtxpP]/.test(n) && !(!inClass && /[bBAz]/.test(n)))
        return `\\${n}`;
    } else if (inClass) inClass = c !== "]";
    else if (c === "[") {
      inClass = true;
      if (re[i + 1] === "^") i++;
      if (re[i + 1] === "]") i++;
    } else if (c === "(" && (re[i + 1] === "?" || re[i + 1] === "*")) {
      const head = re.slice(i, i + 4);
      if (!/^\(\?(:|<[A-Za-z_]|P<|[imsU-]+[:)])/.test(head)) return head;
      i++;
    } else if ("*+?}".includes(c ?? "") && re[i + 1] === "+") return `${c}+`;
  }
  return undefined;
}

void test("every regex compiles under RE2's syntax", () => {
  assert.ok(regexes.length >= 6, `found ${regexes.length} regexes in renovate.json`);
  for (const re of regexes) {
    const bad = re2Rejects(re);
    assert.equal(bad, undefined, `RE2 refuses ${JSON.stringify(bad)} in ${JSON.stringify(re)}`);
    assert.doesNotThrow(() => new RegExp(re), re);
  }
});

void test("re2Rejects names lookaround, backreferences, possessives + escapes RE2 lacks", () => {
  for (const re of [
    "(?<!x)y",
    "(?=x)",
    "(?!x)",
    "(?<=x)",
    "(?>x)",
    "(x)\\1",
    "(?<n>x)\\k<n>",
    "x*+",
    "\\v",
    "\\cK",
    "[\\b]",
  ])
    assert.notEqual(re2Rejects(re), undefined, re);
  for (const re of ["(?<v>\\S+)", "(?:^|\\n)x", "[^/]+\\.", "\\bx\\b", "(?i)x", "a+?b{2}"])
    assert.equal(re2Rejects(re), undefined, re);
});

void test("minimumReleaseAge holds the 7-day floor (deps.md)", () => {
  const age =
    typeof raw === "object" && raw !== null && "minimumReleaseAge" in raw
      ? raw.minimumReleaseAge
      : undefined;
  const m = typeof age === "string" ? /^(\d+) (day|week)s?$/.exec(age) : null;
  const days = m ? Number(m[1]) * (m[2] === "week" ? 7 : 1) : 0;
  assert.ok(days >= 7, `minimumReleaseAge ${JSON.stringify(age)} is under 7 days`);
});
