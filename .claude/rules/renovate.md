---
paths:
  - "renovate.json"
  - "tests/renovate/**"
---

# Renovate config

- An edit to `renovate.json` records `pnpm dlx --allow-build=re2 --package renovate@<latest> renovate-config-validator --strict` → rc 0 in its commit body. The hosted app compiles every regex with RE2; without `--allow-build=re2` (re2's native build) the validator warns "RE2 not usable, falling back to RegExp" and checks under JS `RegExp` instead. A lookbehind planted in a `matchStrings` entry fails it under RE2 (rc 1, "Invalid regExp"). `tests/renovate/` (gate `js-test`) checks what the managers extract, not option validity.
