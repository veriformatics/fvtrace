| row | target | verdict | basis |
|---|---|---|---|
| C-release | gate.yml (matrix, shards, triggers, cache, permissions) | pass | STAGES = checks/e2e/lean; one shard step; required build/Python/Node tools; weekly cache bypass + pin/toolchain/runtime/build-tool key; read-only permissions + SHA pins; actionlint rc 0; five fanout controls fired. |
| C-release | build.yml (platforms, cache, package, check) | pass | Four runner/target pairs; bash on Windows; C compiler + macOS floor set before build; Python + bounded Lean install; no cache on release/weekly; package calls check. Target gate run 41551780111: all four portability jobs success. |
| C-release | release.yml (refusals, attestation, publish, installed, re-check, dry run) | reviewer-24-F1 | Job graph, green-main refusal + attestation ordering, tag-tree re-check, per-OS installed + dry run fit; archive-version guard proves only required-file presence, accepts an extra mismatched archive that later globs attest/publish. Red script rc 1. |
| C-release | codeql.yml | pass | main/PR/weekly triggers; actions + javascript-typescript + manually built c-cpp; security-extended; shim/bridge compile flags align with gate; SHA pins + read/upload-only permissions + no persisted checkout credentials. Target run 41551779966: all three jobs success. |
| C-release | tools/release.sh + NOTICES + libuv.txt | pass | Native package + standalone check rc 0; digest OK; binary/README/LICENSE/expanded NOTICES + seven license texts byte-equal via cmp; four release negative controls fire. Linux glibc 2.17 measured; macOS/Windows floors + zip inspected statically and covered by target portability CI. |
| C-release | renovate.json + tests/renovate | pass | Four custom managers extract correct package identities/versions for Lean, four tools, Emscripten + runtime; npm/Actions managers inherited; 7-day age; Lean package rule matches shared package identity; node extraction test rc 0 + both half-bumped-lock controls fire. No config edit; hosted lookup/RE2 validator not rerun. |
| C-release | README Install ↔ release.sh floors + archive names | pass | All four names/extensions match archive_of + matrices; glibc 2.17 and macOS 15 agree with script/build/installed; SHA256 format verified locally; optional attestation command names this repository; Windows filename + DLL/run rules align. Lower-OS execution limits stated below. |

## reviewer-24-F1 — minor

- Target: `/home/eturkes/Projects/fvtrace/.scratch/review-base/.github/workflows/release.yml:67-69` (48bc51d); consumers: lines 78-80 + 88.
- Contract: `.claude/rules/release.md` release workflow bullet: refuses unless **every** archive is named for the tag version, before attestation.
- Defect: loop checks presence of eight expected files only. Eight expected files plus `fvtrace-9.9.9-linux-x86_64.tar.gz` pass with TAG=v0.1.0. Subsequent attestation/publication globs include the mismatched archive. This is an incomplete guard, not a demonstrated failure of the current four-job producer.
- Red command: `python -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-24/release-archive-guard.py`; rc 1. Test executes the unchanged guard extracted from the base; positive control = eight files passes, missing required archive refuses.

```text
controls: expected eight files rc=0; missing archive rc=1
extra mismatched archive: guard rc=0
FAIL: v0.1.0 guard accepted dist/fvtrace-9.9.9-linux-x86_64.tar.gz
```

- Fix direction: validate the complete downloaded artifact set against the eight expected names before attesting or publishing; keep both missing-file and extra-mismatched-file controls.

## Checks + coverage limits

- Target: frozen `48bc51da577813891fc189be52d70e6ced24f951`; all seven fixed C-release rows adjudicated. Target files remain unchanged. Scratch copy + local Git metadata only supported the checks; no commit, branch, push, dispatch or rerun.
- Local commands (private copy cwd `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-24/tree`; parent environment `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-24/home`): `bash tools/release.sh package linux-x86_64`; standalone `bash tools/release.sh check dist linux-x86_64 0.1.0`; `sha256sum -c fvtrace-0.1.0-linux-x86_64.tar.gz.sha256`; `node --test tests/renovate/` (1 test); `.tools/bin/actionlint`; `.tools/bin/zizmor --no-progress .github/workflows`; `bash tools/gate-probe.sh fanout release locks` (12 passed, 0 failed). All rc 0.
- Archive inspection: member list inspected; `cmp` proved archive binary, README, LICENSE, version-expanded NOTICES + all seven license texts equal their sources.
- Initial actionlint before private `git init -q`: rc 1, two reusable-workflow call-format messages; it selected outer-repository workflow paths (`../../../../.github/workflows/...`). With the copy recognized as its own repository, the unchanged target/config passed, rc 0. This setup failure is not a target finding.
- Existing remote runs read only: target gate `41551780111` = three shards + four portability jobs success; target CodeQL `41551779966` = all three languages success. Historical dry run `41364223613` = four builds + four installed jobs success, publish skipped; historical dispatch `41317969385` = four installed jobs success, build/publish skipped. Historical runs establish those revisions only; no new remote run was started.
- History sampling: latest 12 gate runs, latest 8 release runs, target CodeQL query capped at 3 (one returned). The first abbreviated-SHA gate query returned no runs (rc 0); a recent-history positive control located the full target SHA and successful run. No all-history claim.
- Unconfirmed/not run: native arm64/macOS/Windows checks locally; minimum-OS execution (including Windows 10 1903 and glibc 2.17) independently, beyond symbol/DLL checks + inspected CI; live Renovate hosted lookup or current RE2 config validation; release publishing/attestation and a new tag-tree dispatch; full gate and mutation campaigns (outside this brief). Offline zizmor warned some online audits were unavailable; its checked audits passed.
- Finding witness + log retained under `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-24/`; disposable full copy + extracted archive removed after checks.

## Register

None.

reviewer-24-DONE-1
