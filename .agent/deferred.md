# Deferred

Off-path findings; one entry + acceptance check each.

- Update automation never ran (ops.md: Renovate = npm, Actions digests, `lean-toolchain`, `tools/tools.lock`): the veriformatics org holds no GitHub App (`gh api orgs/veriformatics/installations` → `total_count` 0) and the repo has had no Renovate PR or issue ⇒ no update is ever proposed. Config side done: `renovate.json` passes Renovate 44.173.1 `renovate-config-validator --strict` (options; its regexes ran under JS `RegExp`, as `tests/renovate/` does). Owed (user): install the Renovate GitHub App on veriformatics/fvtrace (a browser flow granting a third party write access). Acceptance: `gh issue list -R veriformatics/fvtrace --state all --search 'Dependency Dashboard in:title' --json number --jq length` ≥ 1.
