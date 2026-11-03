# reviewer-49 — L rules-a

Target = `48bc51d` frozen base; check set = assigned bullets + Authoring per file.

| row | bullet | verdict | basis |
|---|---|---|---|
| L-ops1 | unknown | unknown | unknown |
| L-ops2 | unknown | unknown | unknown |
| L-ops3 | unknown | unknown | unknown |
| L-ops4 | unknown | unknown | unknown |
| L-ops5 | unknown | unknown | unknown |
| L-ops6 | Probes | finding F29, F30, F35 | `gate-probe.sh` inventory read; own copy: 28 controls pass (probes.log); known dispatch/audit gaps retained, not re-reported. |
| L-ops7 | Timing + parity | finding F21 | `scale.sh`, `compare.sh` contracts + existing red witnesses in F21; no reference-host timing run. |
| L-ops8 | CI | finding F32 | All four workflows + Renovate read: triggers/platforms/SHA permissions/Python/cache agree; download hard bound gap = F32. |
| L-lean1 | Layout + trust | finding F30, F35 | `TrustMain.lean` claims/proof/audit/allowlist read; constructor closure + reducible Prop alias gaps = known F30/F35; further layout check pending. |
| L-lean2 | unknown | unknown | unknown |
| L-lean3 | Total kernel | finding F30 | `partial` direct closure probe in trust group; inductive-constructor reach gap already F30. |
| L-lean4 | unknown | unknown | unknown |
| L-lean5 | unknown | unknown | unknown |
| L-lean6 | Lake names | pass | `lakefile.lean`, gate/probe build calls use guillemet names; Lake parsing/build rejects a bare hyphenated name (compiler enforcement). |
| L-lean7 | unknown | unknown | unknown |
| L-lean8 | unknown | unknown | unknown |
| L-lean9 | Mutation credit | finding F3, F31, F51 | `mutate.mjs` read: operators/timeouts/build→suite classification agree; known help/raw-string/list-write defects cited, no campaign run. |
| L-deps1 | unknown | unknown | unknown |
| L-deps2 | unknown | unknown | unknown |
| L-deps3 | unknown | unknown | unknown |
| L-deps4 | Lock consistency | pass | Own `gate-probe.sh locks`: tools one-line 99.0.0 + wasm one-line 99.0.0 both fire rc 1 with version mismatch (probes.log). |
| L-deps5 | Runner label table | pass | `actionlint.yaml` declares only ubuntu-26.04(-arm); pinned actionlint 1.7.12 + release date read; unrelated-label firing test pending. |
| L-ren1 | unknown | unknown | unknown |
| L-ren2 | unknown | unknown | unknown |
| L-rel1 | Platform build | pass | `build.yml` all four target pairs → build/test/package (package checks at once); gate portability reusable call; release input disables cache. |
| L-rel2 | Publish + installed | finding F23 | release.yml job order/permissions/green-main gate/attest/download OS matrix/read-only dispatch/dry branch agree; archive-name guard gap = F23. |
| L-rel3 | unknown | unknown | unknown |
| L-rel4 | Notices | pass | release.sh package copies seven named texts from pinned toolchain/HACL/Emscripten + libuv; release-license plant fires rc 1 (probes.log). |
| L-rel5 | unknown | unknown | unknown |
| L-rel6 | Release probe | pass | Own release group: package control passes, digest/version/license/glibc plants fire (28/28 combined controls). macOS/Windows plants not run on Linux. |
| L-ex1 | Example strict checks | pass | Gate examples function resolves own/synthetic project roots + check --strict; stale-receipt plant fires rc 1; baseline release synthetic strict check passes. |
| L-ex2 | unknown | unknown | unknown |
| L-ex3 | unknown | unknown | unknown |
| L-ex4 | unknown | unknown | unknown |
| L-ex5 | Stale receipt probe | pass | Own gate-probe.sh examples: examples-stale-receipt fires rc 1 on appended Plan.lean line, restored by checksum. |
| A-ops | Authoring: ops.md | pass | Repo-wide gate law stays bare; compact live invocation/stage contract + rationale; implementation recipes delegated to committed scripts. |
| A-lean | Authoring: lean.md | pass | Quoted paths frontmatter + concise live Lean constraints/pitfalls/why; repeated command is invocation, not an origin story. |
| A-deps | unknown | unknown | unknown |
| A-renovate | unknown | unknown | unknown |
| A-release | Authoring: release.md | pass | Quoted area paths; live platforms/floors/attestation + upstream quirks explain constraints; executable package/check/probe scripts own recipes. |
| A-examples | Authoring: examples.md | pass | Quoted area paths; live receipt/replay + consistency obligations, commands already committed CLI/scripts; no dated origin story. |

## Findings

## Register

