---
paths:
  - "renovate.json"
  - "tests/renovate/**"
  - "tools/renovate.sh"
---

# Renovate config

- Gate `js-test` (`tests/renovate/`) holds what a static read decides: each custom manager extracts its file's dependencies (under JS `RegExp`), every regex avoids the syntax RE2 refuses (the hosted app compiles with RE2; the test names JS-accepted constructs from RE2's "NOT SUPPORTED" table: lookaround, backreferences, possessives, escapes such as `\v` + `\cK`), `minimumReleaseAge` ≥ 7 days (`deps.md`); probe `renovate`.
- Option validity = `bash tools/renovate.sh check`, recorded rc 0 in the commit body of each `renovate.json` edit: Renovate's validator, strict, at its newest release ≥ 7 days old (`deps.md`), regexes under RE2 (the script fails on the "RE2 not usable" fallback). It stays out of the gate: the validator = Renovate's whole package tree (hundreds of packages + a native build) fetched per run, for a file edited a few times a year.
- What Renovate would propose (a packageRules change's effect) = `bash tools/renovate.sh lookup <managers>` (comma list, e.g. `regex,npm`): a local dry-run lookup under Node 24 (Renovate refuses 26), GitHub token from `GITHUB_COM_TOKEN` else `gh auth token`; prints the "packageFiles with updates" record.
