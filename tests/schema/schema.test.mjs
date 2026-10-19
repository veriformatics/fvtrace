// The JSON Schema printed by `fvtrace schema` must give the decoder's verdict on the shared corpus
// (Tests/Schema.lean holds the decoder to the same file names): `valid-*` validate, `invalid-*`
// fail; `decoder-only-*` = rules JSON Schema cannot express (1.0 == 1), decoder-rejected alone.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { Ajv2020 } from "ajv/dist/2020.js";

const root = join(import.meta.dirname, "..", "..");
/** @type {unknown} */
const schema = JSON.parse(readFileSync(join(root, "schema", "trace.schema.json"), "utf8"));
if (typeof schema !== "object" || schema === null) throw new Error("the schema is not an object");
const validate = new Ajv2020({ allErrors: true, strict: true }).compile(schema);
const dir = join(import.meta.dirname, "cases");
const files = readdirSync(dir)
  .filter((f) => f.endsWith(".json"))
  .toSorted();

void test("the corpus covers every verdict", () => {
  assert.ok(files.length >= 30, `${files.length} files`);
  assert.ok(files.some((f) => f.startsWith("valid-")));
  assert.ok(files.some((f) => f.startsWith("invalid-")));
});

for (const file of files) {
  if (file.startsWith("decoder-only-")) continue;
  const want = file.startsWith("valid-");
  void test(`schema ${want ? "accepts" : "rejects"} ${file}`, () => {
    /** @type {unknown} */
    const doc = JSON.parse(readFileSync(join(dir, file), "utf8"));
    assert.equal(validate(doc), want, JSON.stringify(validate.errors));
  });
}
