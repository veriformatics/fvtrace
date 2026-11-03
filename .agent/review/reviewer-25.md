# reviewer-25 — C-release

Target = frozen `48bc51d`, `/home/eturkes/Projects/fvtrace/.scratch/review-base`. Lens = Correctness. Contract + check set fixed by assignment + shared BRIEF before target reads.

| row | target | verdict | basis |
|---|---|---|---|
| C-release | gate.yml (matrix, shards, triggers, cache, permissions) | pass | Every job/step read with `gate.sh` STAGES + `fanout`; three shards match; cache key/scope + scheduled bypass fit law; SHA pins, permissions, credentials + bounded Lean install fit; actionlint rc 0. |
| C-release | build.yml (platforms, cache, package, check) | pass | Four platform matrix + bash shells + macOS floor + Windows compiler read through package/check; cache bypasses release + schedule; base main run 41551780111 passed all four portability jobs; native package/check rc 0. |
| C-release | release.yml (refusals, attestation, publish, installed, re-check, dry run) | pass | Job/needs/if graph + refusal order + attestation + four installed targets read; dispatch pins tag tree, dry run pins SHA. Existing dispatch 41317969385 + dry run 41364223613 passed installed ×4 (build/publish skip states as intended); no new dispatch/publish. |
| C-release | codeql.yml | pass | Three languages/build modes + manual C compilation ↔ gate c-analyze read; triggers + permissions + checkout + pinned actions fit ops; actionlint + offline zizmor rc 0 (no security ruling). |
| C-release | tools/release.sh + NOTICES + libuv.txt | reviewer-25-F1 | Native package + check + `sha256sum -c` rc 0; release/locks/fanout probes 12/12; seven archived license texts byte-equal their sources, libuv text matches upstream v1.48.0 with a blank separator; quoted TMPDIR red: check rc 2 after reporting pass, extraction folder remains. |
| C-release | renovate.json + tests/renovate | pass | All four regex managers + package rules read against actual lock/toolchain lines; npm/Actions defaults retained, Lean runtime grouped by package name, minimumReleaseAge = 7 days; extraction test 1/1; half-bump locks controls fire. |
| C-release | README Install ↔ release.sh floors + archive names | pass | Four archive names match archive_of + both matrices; glibc 2.17 + macOS 15 match constants/build env/floor runner; documented sha256sum -c succeeds on generated archive; provenance/Windows hash commands consistent with published asset format. |

## reviewer-25-F1 — minor — quoted TMPDIR breaks check + cleanup

- Location: `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/release.sh:144` (`48bc51d`).
- Contract: `CLAUDE.md` Engineering Correctness — quoting, error paths + resource cleanup; `.claude/rules/release.md` check must accept a valid archive and run the two native checks.
- Cause: the EXIT trap embeds `mktemp` output inside literal single quotes. A valid `TMPDIR` containing an apostrophe makes the trap syntactically invalid. The valid archive passes its digest/floor/version/synthetic checks, then `check` returns 2 + leaves its extracted folder. `package` shares this trap.
- Red command: `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/red-tmpdir.py` (script verifies copied release.sh bytes = frozen base).
- Failing output (red test rc 1):

```text
release: fvtrace-0.1.0-linux-x86_64.tar.gz passed
/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/tree/tools/release.sh: exit trap: line 1: unexpected EOF while looking for matching `''
check rc=2; expected leftover temporary directories=0; actual=1
AssertionError: FAIL: a valid TMPDIR containing an apostrophe makes a passing release check fail at its EXIT trap
```
- Fix direction: escape the fixed cleanup argument with shell-safe quoting (e.g. `printf -v ... %q`) or preserve the path for a cleanup function without eval-interpolated bytes. Re-run plain + quoted TMPDIR cases; both rc 0 + no extraction folder.

## Checks + coverage

- Private copy = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/tree`; frozen target + primary implementation untouched. Only deliverable + own scratch written. No commit, branch, push, dispatch, rerun, install or server start.
- Native smoke: `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/home TMPDIR=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/tmp bash tools/release.sh package linux-x86_64`, then `check dist linux-x86_64 0.1.0`: both rc 0 (version + synthetic strict check included; script's internal temporary data home stays under scratch). Log = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/release.log`.
- `node --test tests/renovate/`: 1/1, rc 0. `bash tools/gate-probe.sh fanout release locks`: 12/12, rc 0; log = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/probes.log`.
- `.tools/bin/actionlint .github/workflows/{gate,build,release,codeql}.yml`: rc 0. `.tools/bin/zizmor --no-progress .github/`: rc 0, offline mode; online-only audits unconfirmed. Security adjudication = MAIN.
- `python3 -I /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/check-action-pins.py`: nine distinct action repository/tag→commit identities all match, rc 0; annotated tags dereferenced through GitHub API. Log = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-25/action-pins.log`.
- Tar members inspected: binary + README + LICENSE + substituted NOTICES + seven named license texts. Seven `tar -xOf | cmp` checks rc 0. Bundled libuv = upstream v1.48.0 LICENSE + blank separator + LICENSE-extra (`cmp` rc 0); raw concatenation differs by that one harmless newline.
- Existing GitHub evidence, read-only: base `48bc51da577813891fc189be52d70e6ced24f951` main gate 41551780111 = all three gate + four portability jobs green; CodeQL 41551779966 green. Dispatch 41317969385 = installed ×4 green, build/publish skipped; dry run 41364223613 = build ×4 + installed ×4 green, publish skipped. The latter two are earlier commits, not a newly driven frozen-base release run. Initial `gh run list --commit 48bc51d` returned no runs; the full SHA / main branch queries found the base run above (short-SHA lookup was not used as negative evidence).
- Not run: full gate (brief boundary); cross-OS executables locally; fresh release dry run or dispatch; publish/attestation; strict Renovate option validator or local lookup (no config edit). Windows 10 version 1903 execution remains unconfirmed: inspected base Windows-2025 package/check log + system-DLL list, not that older OS. Tag-tree re-check and floor-runner behavior judged by the workflow graph + historical runs above. No claim of new cross-OS execution.

## Register

None.

reviewer-25-DONE-1
