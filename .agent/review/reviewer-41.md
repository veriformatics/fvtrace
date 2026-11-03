# reviewer-41 — V-lean-shell @ 48bc51d

Check set fixed: verification integrity per BRIEF.md + LENSES.md § V; target tests vs kernel.md Receipts / Replay / V-* / E-*, README Commands / exit codes, server.md. Target read-only; probes + copies under `.scratch/review/reviewer-41/`.

| row | target | verdict | basis |
|---|---|---|---|
| V-lean-shell | Receipt + Replay + Notices tests | pass (known F4/F5/F8 gaps) | Contract-derived file/receipt metamorphisms, raw stdout hash, opt-in marker, notice outcome × prior-notice matrix, concurrent/log/write-refusal boundaries; existing F4/F5/F8 remain uncaught. Native baseline pending. |
| V-lean-shell | Evaluate + Snapshot tests | pass | Counts/flags/ordering expected from S-state + V-env; snapshot same-definition parity legitimately checks E-request transport + state transparency, supplemented by fixed expected counts/labels + malformed shapes. Native baseline pending. |
| V-lean-shell | Cli + CliStore + Args + Assets tests | unknown | unknown |
| V-lean-shell | Server tests | pass (known F19/F20 gaps) | Fixed status/body-cap/request-shape/rehash/view expectations + CLI-byte parity; injected I/O fault runs on root/Windows too. Native baseline 1834/1834. Base tests do not pin F19 framing or F20 refused-item view header. |
| V-lean-shell | Export + Wasm tests | unknown | unknown |
| V-lean-shell | tests/cli/smoke.sh (incl. the empty-folder lead) | reviewer-41-F1 | Exact source predicate tested: added file → rc 1; added empty directory → rc 0. Full smoke execution withheld pending fake-opener exception; predicate witness needs no server. |
| V-lean-shell | wiring + history | unknown | unknown |

## Evidence / coverage

Pending per-row reads + targeted checks. No nested agents, target mutation, full gate or mutation campaign.
