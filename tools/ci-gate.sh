#!/usr/bin/env bash
# CI gate (.claude/rules/ops.md): the full gate on GitHub for the committed HEAD. Pushes it to
# ci/<unit>, waits for that commit's gate run (every shard + portability), prints the run, the
# tree it tested and each job's wall-clock, then deletes the branch when green.
# Usage: tools/ci-gate.sh <unit>. rc 0 = green, 1 = red (branch kept), 2 = no run to judge.
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$root" || exit 2
[[ $# -eq 1 && -n "$1" ]] || {
    printf 'usage: tools/ci-gate.sh <unit>\n' >&2
    exit 2
}
branch="ci/$1"
# CI checks out the commit alone: an uncommitted edit would go untested yet look tested.
if [[ -n "$(git status --porcelain)" ]]; then
    printf 'ci-gate: uncommitted changes; commit (or amend) first\n' >&2
    exit 2
fi
sha="$(git rev-parse HEAD)" || exit 2
git push -f -q origin "HEAD:refs/heads/$branch" || exit 2

id=""
for _ in $(seq 60); do
    id="$(gh run list -b "$branch" -c "$sha" -w gate -L 1 --json databaseId --jq '.[0].databaseId // empty')"
    [[ -n "$id" ]] && break
    sleep 5
done
if [[ -z "$id" ]]; then
    printf 'ci-gate: no gate run for %s on %s within 5 min\n' "${sha:0:7}" "$branch" >&2
    exit 2
fi
printf 'ci-gate: run %s · commit %s · tree %s\n' "$id" "${sha:0:7}" "$(git rev-parse 'HEAD^{tree}')"

gh run watch "$id" --exit-status --interval 15 >/dev/null
rc=$?
gh run view "$id" --json jobs --jq '
    def secs: (.completedAt | fromdate) - (.startedAt | fromdate);
    (.jobs[] | "\(.name) \(.conclusion) \(secs)s"),
    ([.jobs[] | select(.name | startswith("gate"))] |
        "gate fan-out \((map(.completedAt | fromdate) | max) - (map(.startedAt | fromdate) | min))s")'
if [[ $rc -ne 0 ]]; then
    printf 'ci-gate: run %s red; %s kept (gh run view %s --log-failed)\n' "$id" "$branch" "$id" >&2
    exit 1
fi
if git push -q origin --delete "$branch"; then
    printf 'ci-gate: green; %s deleted\n' "$branch"
else
    printf 'ci-gate: green, but %s was not deleted\n' "$branch" >&2
fi
