#!/usr/bin/env bash
# CI gate (.claude/rules/ops.md): the full gate on GitHub for the committed HEAD. Pushes it to
# ci/<unit>, waits for that commit's gate run (every shard + portability), prints the run, the
# tree it tested and each job's wall-clock, appends each job to the step ledger
# (tools/gate-ledger.sh), then deletes the branch when green.
# Usage: tools/ci-gate.sh <unit>. rc 0 = green, 1 = red (branch kept), 2 = no run to judge.
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# jq: a job's wall-clock, "-" while it has no finish (GitHub's unset time = year 1).
jq_secs='def secs: if (.startedAt // "") != "" and ((.completedAt // "0001") | startswith("0001") | not)
    then (.completedAt | fromdate) - (.startedAt | fromdate) else "-" end;'

# The run (`gh run view --json createdAt,conclusion,jobs` on stdin) → one line per job + the
# gate fan-out. A job cancelled before any step ran never got a runner (GitHub capacity, e.g.
# macOS arm64): named `no runner`, so its class (flake) needs no log read.
summary() {
    jq -r "$jq_secs"'
        (.jobs[] | "\(.name) \(.conclusion) \(secs)s" +
            (if .conclusion == "cancelled" and (.steps | length) == 0 then " no runner" else "" end)),
        ([.jobs[] | select(.name | startswith("gate"))] |
            "gate fan-out \((map(.completedAt | fromdate) | max) - (map(.startedAt | fromdate) | min))s")'
}

# One ledger row per job (stdin = the run), so a CI red has a row to classify; its stages stay in
# the CI history.
rows() {
    jq -r --arg tree "$1" --arg run "ci:$2" "$jq_secs"'
        .createdAt as $date | .jobs[] |
        [$date, $tree, $run, .name, secs,
            (if .conclusion == "success" then "green" elif .conclusion == "skipped" then "skipped"
             else "red" end)] | @tsv'
}

# Waits until run $1 completes: `gh run watch` also returns on an API error, and a run read then
# lists jobs still running as red with no finish.
wait_run() {
    local _
    for _ in $(seq 240); do
        gh run watch "$1" --interval 15 >/dev/null 2>&1
        [[ "$(gh run view "$1" --json status --jq .status)" == completed ]] && return 0
        sleep 15
    done
    return 1
}

main() {
    local branch sha id tree run
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
    # The pushed commit's tree: HEAD may move while the run is watched in the background.
    tree="$(git rev-parse "$sha^{tree}")"
    printf 'ci-gate: run %s · commit %s · tree %s\n' "$id" "${sha:0:7}" "$tree"

    if ! wait_run "$id"; then
        printf 'ci-gate: run %s did not complete within an hour of watching\n' "$id" >&2
        exit 2
    fi
    run="$(gh run view "$id" --json createdAt,conclusion,jobs)" || run='{}'
    summary <<<"$run"
    rows "$tree" "$id" <<<"$run" | bash tools/gate-ledger.sh append ||
        printf 'ci-gate: the ledger lacks run %s\n' "$id" >&2
    if [[ "$(jq -r '.conclusion // empty' <<<"$run")" != success ]]; then
        printf 'ci-gate: run %s red; %s kept (gh run view %s --log-failed); classify each red job: bash tools/gate-ledger.sh classify JOB product|gate|flake|planted ci:%s\n' \
            "$id" "$branch" "$id" "$id" >&2
        exit 1
    fi
    if git push -q origin --delete "$branch"; then
        printf 'ci-gate: green; %s deleted\n' "$branch"
    else
        printf 'ci-gate: green, but %s was not deleted\n' "$branch" >&2
    fi
}

# Sourcing exposes summary + rows without pushing (tools/gate-probe.sh).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
