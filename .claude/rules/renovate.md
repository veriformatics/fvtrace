---
paths:
  - "renovate.json"
  - "tests/renovate/**"
---

# Renovate config

- An edit to `renovate.json` records `pnpm dlx --allow-build=re2 --package renovate@<newest release ≥ 7 days old> renovate-config-validator --strict` → rc 0 in its commit body (release age, `deps.md`: running a fresh release is the risk the floor quarantines). The hosted app compiles every regex with RE2; without `--allow-build=re2` (re2's native build) the validator warns "RE2 not usable, falling back to RegExp" and checks under JS `RegExp` instead. A lookbehind planted in a `matchStrings` entry fails it under RE2 (rc 1, "Invalid regExp"). `tests/renovate/` (gate `js-test`) checks what the managers extract, not option validity.
- What Renovate would propose (a packageRules change's effect) = a local lookup: `LOG_LEVEL=debug LOG_FORMAT=json pnpm dlx --allow-build=re2 --package node@24.<x> --package renovate@<version> renovate --platform=local --dry-run=lookup --enabled-managers=<managers>` (Renovate refuses Node 26: engines `^24.11`), its updates in the record whose `msg` = "packageFiles with updates" (`jq -R 'fromjson?'`: pnpm prints plain lines first).
