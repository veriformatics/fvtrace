# Deferred

Off-path findings; one entry + acceptance check each.

- Update automation never ran (ops.md: Renovate = npm, Actions digests, `lean-toolchain` + `tools/wasm.lock`, `tools/tools.lock`): the veriformatics org holds no GitHub App (`gh api orgs/veriformatics/installations` → `total_count` 0) and the repo has had no Renovate PR or issue ⇒ no update is ever proposed. Config side done: the current `renovate.json` passes `renovate-config-validator --strict` under RE2, the hosted app's regex engine (`pnpm dlx --allow-build=re2 --package renovate@44.176.3 renovate-config-validator --strict` → rc 0; a planted lookbehind → rc 1, "Invalid regExp"; without `--allow-build=re2` it falls back to JS `RegExp`). Owed (user): install the Renovate GitHub App on veriformatics/fvtrace (a browser flow granting a third party write access). Acceptance: `gh issue list -R veriformatics/fvtrace --state all --search 'Dependency Dashboard in:title' --json number --jq length` ≥ 1.
