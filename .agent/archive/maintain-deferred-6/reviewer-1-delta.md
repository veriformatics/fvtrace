# reviewer-1 — delta review, sixth sweep (958a956..66553cc + uncommitted close edits)

Fixed D1–D6 check set loaded before target read. Target HEAD = `66553ccb33b4fe60ea0a3e260a83837048657361`; close edits = units/spec/release rule + `.agent/archive/maintain-deferred-6.md` as read. Primary source read-only; scratch = `/tmp/reviewer-1/`; no dispatch, push, rerun or other remote mutation.

| row | lens | check | verdict | evidence (file:line + exact matched bytes) |
|---|---|---|---|---|
| D1 | correctness | Trigger paths: jobs, `TAG`, checkout ref, download source + checked version agree with header/rule | pass | `.github/workflows/release.yml:28` `if: github.event_name != 'workflow_dispatch'`; `:95` `github.event_name == 'workflow_dispatch'`; `:114` `TAG: ${{ inputs.tag || (github.ref_type == 'tag' && github.ref_name) || '' }}`; `:127` `ref: ${{ env.TAG || github.sha }}`. Trigger table below. Actual branch dry run + valid dispatch match; malformed input tested by executing the file's validation shell, not by dispatching. |
| D2 | correctness | Tag-push behavior preserved: publish guard/permissions, installed ordering, tag-derived version | pass | `.github/workflows/release.yml:36` `if: github.ref_type == 'tag'`; `:94` `needs: [build, publish]`; `:148` `version="${TAG#v}"`. Entire `publish` job byte-identical to 958a956 (`cmp` rc 0); new build condition is true on push. Installed retains the prior `needs.build.result == 'success' && needs.publish.result != 'failure'` branch for pushes. No new tag push run after 778a0da; parity conclusion = source/diff, not a claimed live tag test. |
| D3 | claims | Changed docs/state/archive statements + every cited run result agree with code/evidence | pass | `.agent/archive/maintain-deferred-6.md:9` `re-check 41317969385` + `v0.1.0 published`; `:14` `plant 41364207052`; `.agent/contracts/units.md:130` `gh attestation verify`. All 13 cited run IDs exist with the stated result pattern; release has the expected 8 assets; tag peels to 958a956. Saved `maintain-deferred-6/attestations.txt:6–9` records 4 positive verifications at source 958a956 + `:10` `tampered.tar.gz rc=1`; counts checked. Verifier CLI itself not independently rerun. |
| D4 | consistency | macOS floor 15.0 consistently feeds builder/checker/README/runner/rule | pass | `tools/release.sh:17` `macos_min=15.0`; `:113` `version_le "$minos" "$macos_min"`; `.github/workflows/build.yml:70` `MACOSX_DEPLOYMENT_TARGET=$(sed -n 's/^macos_min=//p' tools/release.sh)`; `README.md:44` `macOS 15 or later on Apple silicon`; release.yml `:105` `- os: macos-15`; release.md `:15` `macos-15`. Real CI floor log = `release: macOS ≥ 15.0 (floor 15.0)` + archive passed; planted 26.0 run fails with named floor error. |
| D5 | cleanup | Active stale floor-14 text/dead clauses/comment density in changed files | pass | `.claude/rules/release.md:15` `the system table README Install carries, moved together`; dead “once a release exists” clause removed. Active-source search (excluding history/caches) finds floor 15 references + spec Task's historical `macos-14 retired` explanation, no active 14.0 promise. Workflow comments explain tag-tree checkout + deleted-branch guard; no dead per-step TAG copies remain. |
| D6 | security facts (MAIN rules) | `inputs.tag` flow, validation order, installed permissions + dispatchers; facts only | note (D6-N1) | `.github/workflows/release.yml:19–20` `permissions:` / `contents: read`; `:114` `inputs.tag`; `:120` `[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]`; `:127` `ref: ${{ env.TAG || github.sha }}`. Flow/permissions/source excerpts below; security verdict reserved for MAIN. |

## D1 — trigger-path evidence

| trigger/context | build | publish | installed | TAG / checkout / download / version |
|---|---|---|---|---|
| `push`, `refs/tags/vX.Y.Z` | runs from-scratch reusable build | runs after build; original guards + permissions | after successful build + nonfailed publish, unless cancelled | pushed tag / tag / published release / tag without first `v` |
| `push`, `refs/heads/ci/release-*` | runs | skipped (`ref_type != tag`) | runs after successful build despite skipped publish (`!cancelled()` status condition) | empty / event commit SHA / current run's artifacts / checked-out `Fvtrace/Version.lean` |
| `workflow_dispatch`, main, input `v0.1.0` | skipped | skipped | runs alone unless cancelled | input tag / tag / published release / `0.1.0` |
| `workflow_dispatch`, main, malformed input | skipped | skipped | job starts, first validation step fails; later checkout/download/check steps skipped | raw input read only by validation before those steps |

- Header `release.yml:1–5` describes the three modes; rule `release.md:14` explicitly says dispatch from main + installed alone. Actual run 41316953453 = dry run, 8 successful jobs + skipped publish; actual 41317969385 = dispatch on main, 4 successful installed jobs + 2 skipped jobs. No new workflow run started by this review.
- Actual validation snippet run locally: `v0.1.0` rc 0; `0.1.0`, `v0.1.0-rc1`, `v0.1`, empty → rc 1, `release: <input> is not vX.Y.Z`. The stated input contract = `vX.Y.Z`, not prerelease SemVer. Source order asserts validation → checkout → release download. Malformed remote dispatch itself not run.
- Deleted branch regression: 41315202647 fails installed checkout with exact `fatal: couldn't find remote ref refs/heads/ci/release-recheck`; target uses `github.sha` when TAG empty. Fixed dry run 41316953453 successful. Native CI evidence, not a locally simulated Actions scheduler.

## D3 — claim/evidence index

- Code/state consistency: README floor = current release/check constants; Artifacts names the implemented dispatch; units rows describe the cache/timeout evidence this reviewer already ran, archive-name repair already re-reviewed, and release/floor workflows now inspected. Deferred queue no longer carries the completed release/floor rows; its two retained entries are unchanged by the close. Archive accurately distinguishes original release's macOS cancellation from its successful re-check.
- `gh run view <id> -R veriformatics/fvtrace --json …` individually fetched all 13 named runs, every fetch rc 0. Full saved JSON = `/tmp/reviewer-1/delta-runs/<id>.json`; summary `/tmp/reviewer-1/delta-read-runs.log`.

| claim / run ids | independently observed result |
|---|---|
| gates 41311138460, 41311597781, 41313052479, 41313479163, 41316953493, 41364223577 | all success; each 7 successful jobs (3 shards + 4 portability builds) |
| release dry runs 41313052542, 41316953453, 41364223613 | each success; 8 successful jobs + skipped publish |
| original tag release 41313866322 | overall cancelled; 4 builds + publish + 3 installed jobs success, macOS installed cancelled |
| published-archive re-check 41317969385 | workflow_dispatch/main, success; installed ×4 success, build/publish skipped |
| deleted-branch red 41315202647 | failure; 4 builds success, installed ×4 fail, publish skipped |
| macOS floor plant 41364207052 | failure; macOS portability build fails, 6 other jobs succeed |

- Original-release annotation read directly: `This job failed because of a scheduled macOS 14 runner image brownout.` (`gh run view 41313866322`, rc 0). Deleted-branch log names `fatal: couldn't find remote ref refs/heads/ci/release-recheck`. Floor logs confirm macOS 15 runner + 15.0 floor, and planted 26.0 failure, so claimed failure causes are not inferred solely from run conclusions.
- `gh release view v0.1.0 -R veriformatics/fvtrace --json …` → rc 0, non-draft/non-prerelease, exactly Linux x86_64/arm64, macOS arm64, Windows x86_64 archives + their four `.sha256` files. Local annotated tag peel → `958a956c6be5b129a55f67d337e214a45cefe582`. These confirm publication/asset inventory, not archive bytes or attestations.
- Manual-verification record = `.agent/archive/maintain-deferred-6/attestations.txt`: lines 2–5 = four named archives `: OK`; lines 6–9 = each named archive `rc=0`, signer `https://github.com/veriformatics/fvtrace/.github/workflows/release.yml@refs/tags/v0.1.0`, source `958a956c6be5b129a55f67d337e214a45cefe582`; line 10 = `tampered.tar.gz rc=1` + `Error: HTTP 404: Not Found`. Expected counts 4 checksum positives / 4 verification positives / 1 tampered negative all match (each search rc 0). This saved MAIN-produced record closes the manual-evidence gap; it is not a reviewer-run verifier invocation or a full independent attestation parse.

## D6-N1 — data-flow + permission facts for MAIN

- Input declaration = required string `on.workflow_dispatch.inputs.tag` (`release.yml:14–17`); job env `TAG` (`:114`) chooses input, else pushed-tag name, else empty. Header/rule's dispatch path uses main as workflow ref; the tag input chooses checkout/data, not a remote workflow launch.
- Dispatch validation (`:115–120`) runs before checkout (`:123–128`), downloads (`:130–143`) + check (`:145–152`). Regex verifies shape only; tag/release existence is left to checkout/download. Input reaches shell through `$TAG`, not `${{ inputs.tag }}` embedded in shell text.
- Every use downstream: checkout `ref: env.TAG || github.sha`; release/build download conditions (`env.TAG != ''` / `== ''`); quoted argument `gh release download "$TAG"`; shell `version="${TAG#v}"`; quoted version argument to `bash tools/release.sh check dist "$TARGET" "$version"`. Validation refusal prints `$TAG` through a quoted echo argument.
- Installed has no job-level permission override; inherits top-level `contents: read` (`:19–20`). Download step passes `github.token` as `GH_TOKEN`. Publish alone retains `contents: write`, `actions: read`, `id-token: write`, `attestations: write` (`:39–43`); observed dispatch on main skips it. No permission change in the compared publish bytes.
- GitHub primary source read in own Neo tab: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow. Exact excerpts: “To trigger the `workflow_dispatch` event, your workflow must be in the default branch.”; “Write access to the repository is required to perform these steps.” These establish platform-level dispatcher access; actual repository collaborator memberships not enumerated.
- Proposed fix = none from this facts-only review. MAIN adjudicates any security consequence; this note gives no security all-clear.

## Checks / limits

- `.tools/bin/actionlint -config-file .github/actionlint.yaml .github/workflows/release.yml` → rc 0; `pnpm exec prettier --check .github/workflows/release.yml` → rc 0 (`All matched files use Prettier code style!`). Logs = `/tmp/reviewer-1/delta-actionlint.log`, `delta-prettier.log`.
- Publish-job extracted bytes compared with 958a956 → `cmp` rc 0. Tag validation + source order checks rc 0. Extracted actual `floor_macos` + `die`/`version_le`, mocked `otool`: minos 15.0 → rc 0, `release: macOS ≥ 15.0 (floor 15.0)`; minos 26.0 → rc 1, `release: fvtrace needs macOS 26.0, newer than the floor 15.0`. Mock checks do not substitute for the real CI logs.
- Real CI log reads (`gh run view … --job … --log`, all rc 0): planted macOS job 125020807524; floor-15 installed job 125023761462; published-release recheck macOS job 124881953279; deleted-branch failure job 124876672695. Files = `/tmp/reviewer-1/delta-runs/{plant,floor15,recheck,checkout-red}.log`.
- 41364223577 + 41364223613 run at commit dc351a6; its tree = 66553cc's = `69d2c98b186a865c9716f790b4edd2431886bfa6` (body's “this tree, 69d2c98” correctly names the tree, not the commit).
- No build/full gate, native macOS execution, workflow dispatch or remote rerun performed here. Current tag-push path reviewed statically; malformed dispatch validated locally. Full CI metadata read = the individually named runs, not a sampled run-list page.

## Register

None outside the fixed set so far.

## MAIN rulings

- D1, D2, D4, D5: pass, accepted (D2 tag path: source parity alone; no tag after 778a0da, so the next tag = its first live run).
- D3-N1: closed by evidence — `attestations.txt` (this folder) = MAIN's rerun 2026-11-02: `sha256sum -c` OK ×4, `gh attestation verify` rc 0 ×4 (signer `release.yml@refs/tags/v0.1.0`, source 958a956), tampered copy rc 1 (HTTP 404). reviewer-1 checked the transcript, did not rerun the verifier.
- D6 (security, MAIN): pass. `inputs.tag` reaches the job only through `env.TAG`; the shape check `^v[0-9]+\.[0-9]+\.[0-9]+$` runs before checkout + download and admits no shell or ref metacharacters; every later use is quoted (`gh release download "$TAG"`, `version="${TAG#v}"`). Dispatch needs repository write access (GitHub docs), and such a user can already push the tags + workflow files the re-check reads, so the input grants no new reach. `installed` = `contents: read` + `github.token` for a release download; `publish` (the one write job) is skipped on dispatch and byte-identical to 958a956.
