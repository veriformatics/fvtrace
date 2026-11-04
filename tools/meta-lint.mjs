// Shape checks on the repo's own instruction + state files that spec-lint (the shared template's
// copy) leaves: rule frontmatter = `paths:` + quoted globs alone, each matching a tracked file;
// every path `.agent/spec.md` Artifacts names exists; each `.agent/deferred.md` entry carries its
// acceptance check; each retired prototype's tag exists and no prototype tree stays tracked.
// rc 1 + one line per problem. Run by gate stage `spec`.
import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync } from "node:fs";
import { matchesGlob } from "node:path";

const git = (/** @type {string[]} */ args) =>
  execFileSync("git", args, { encoding: "utf8" }).split("\n").filter(Boolean);
const files = git(["ls-files"]);
const tracked = (/** @type {string} */ glob) =>
  files.some((f) => f === glob || matchesGlob(f, glob.endsWith("/") ? `${glob}**` : glob));
/** @type {string[]} */
const problems = [];

// Rules: CC reads `paths:` alone; a richer YAML would need a parser the toolchain lacks, so any
// other shape fails here. Globs are quoted (a leading `*` or `{` would start a YAML alias or map).
for (const name of readdirSync(".claude/rules")
  .filter((n) => n.endsWith(".md"))
  .toSorted()) {
  const file = `.claude/rules/${name}`;
  const lines = readFileSync(file, "utf8").split("\n");
  if (lines[0] !== "---") continue;
  const end = lines.indexOf("---", 1);
  if (end < 0) {
    problems.push(`${file}: frontmatter never closes (---)`);
    continue;
  }
  if (lines[1] !== "paths:" || end < 3)
    problems.push(`${file}:2: frontmatter must be paths: + a list`);
  for (const [i, line] of lines.slice(2, end).entries()) {
    const m = /^ {2}- "([^"\\]+)"$/.exec(line);
    if (!m?.[1]) problems.push(`${file}:${i + 3}: not a quoted glob: ${line}`);
    else if (!tracked(m[1])) problems.push(`${file}:${i + 3}: "${m[1]}" matches no tracked file`);
  }
}

const spec = readFileSync(".agent/spec.md", "utf8");
// Artifacts: a backticked token with a `/` or a `.` whose first segment is a tracked top-level
// entry = a repo path (commands, flags, hosts + built outputs fall outside).
const artifacts = spec.split(/^## /m).find((s) => s.startsWith("Artifacts\n")) ?? "";
const tops = new Set(files.map((f) => f.split("/")[0] ?? ""));
for (const [, token = ""] of artifacts.matchAll(/`([^`\s]+)`/g)) {
  const first = token.split("/")[0] ?? "";
  if (/[/.]/.test(token) && tops.has(first) && !tracked(token))
    problems.push(`.agent/spec.md Artifacts: ${token} matches no tracked file`);
}

// Retired prototypes live in their tags alone.
for (const [, tag = ""] of spec.matchAll(/tag `(prototype-[a-z0-9-]+)`/g))
  if (git(["tag", "--list", tag]).length === 0)
    problems.push(`.agent/spec.md: tag ${tag} does not exist`);
for (const f of files.filter((p) => p.startsWith("prototype/")).slice(0, 1))
  problems.push(`${f}: a retired prototype tree stays tracked (its tag holds it)`);

// Deferred entries: a top-level `- ` item + its indented lines; each names its acceptance check.
const deferred = readFileSync(".agent/deferred.md", "utf8")
  .split(/^(?=- )/m)
  .slice(1);
for (const entry of deferred)
  if (!/Acceptance:/.test(entry))
    problems.push(`.agent/deferred.md: no "Acceptance:" in "${entry.slice(2, 62)}…"`);

for (const p of problems) console.error(`meta-lint: ${p}`);
process.exit(problems.length ? 1 : 0);
