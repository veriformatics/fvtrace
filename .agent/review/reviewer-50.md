# reviewer-50 — L rules-b conformance

Target = `48bc51d`, frozen `.scratch/review-base`; check set = L-srv1…9, L-wasm1…9, L-web1…15, L-fast1…4 + Authoring per rule file. Read-only target; planted inputs only in `.scratch/review/reviewer-50/tree`.

| row | bullet | verdict | basis |
|---|---|---|---|
| L-srv1 | server.md Routes | F19, F20 | Server.decide/answer + Tests.Server.answerTests: routes + CLI byte equality + problem copy agree; known framing-cap + untagged item-error exceptions. |
| L-srv2 | server.md I/O | unknown | unknown |
| L-srv3 | server.md Access order | F19 | Server.decide + Cli.tokenOf/serveCmd agree; framing-limit ordering already F19; pure/native server tests pass in native suite. |
| L-srv4 | server.md Bind | unknown | unknown |
| L-srv5 | server.md Link + opener | unknown | unknown |
| L-srv6 | server.md GUI token | unknown | unknown |
| L-srv7 | server.md Fixed headers | F19 | Server.toResponse appends fixedHeaders; known framing response bypass = F19 (no new security analysis). |
| L-srv8 | server.md Config Ref | unknown | unknown |
| L-srv9 | server.md e2e harness | unknown | unknown |
| L-wasm1 | wasm.md Pipeline | unknown | unknown |
| L-wasm2 | wasm.md Closure | unknown | unknown |
| L-wasm3 | wasm.md Pins | unknown | unknown |
| L-wasm4 | wasm.md Runtime patch | unknown | unknown |
| L-wasm5 | wasm.md Allocator | unknown | unknown |
| L-wasm6 | wasm.md Link contract | unknown | unknown |
| L-wasm7 | wasm.md Determinism | unknown | unknown |
| L-wasm8 | wasm.md CI cache | unknown | unknown |
| L-wasm9 | wasm.md Probes | unknown | unknown |
| L-web1 | web.md Display only | unknown | unknown |
| L-web2 | web.md Request law | F24, F37–F41 | app.js ask/evaluation/load/loadDetails/readHash + worker reviewed; known idle error, fatal shape, action pending-view, hash question, detail-view gaps. |
| L-web3 | web.md Record problem | F27, F42 | cannotShow + .unavailable + gui.spec.js: active tour stays; history can restore old envelope before a new one (known). |
| L-web4 | web.md Responsiveness | F26, F43–F45, F50 | app.js/renderBoard/find + lazy.js + panels.js + responsive.spec.js: known eager Needed-by, text highlight, duplicate titles, focus window + find lookup gaps. |
| L-web5 | web.md DOM sinks | unknown | unknown |
| L-web6 | web.md No build + types | unknown | unknown |
| L-web7 | web.md Chromium | unknown | unknown |
| L-web8 | web.md e2e limits | unknown | unknown |
| L-web9 | web.md Palette | unknown | unknown |
| L-web10 | web.md Selectors | unknown | unknown |
| L-web11 | web.md Selectable text | unknown | unknown |
| L-web12 | web.md Startup | unknown | unknown |
| L-web13 | web.md Verdict words | unknown | unknown |
| L-web14 | web.md Fonts | unknown | unknown |
| L-web15 | web.md Tour | unknown | unknown |
| L-fast1 | fast.md Equality proofs | unknown | unknown |
| L-fast2 | fast.md Cost traps | F47 | Receipt.BindingIndex, ClaimMemo.needs, forest closures + plan memoAt reviewed; known Snapshot.answer rebuilds immutable binding index on cached details (F47). |
| L-fast3 | fast.md Pair projections | pass | Judgment: rewrite-sensitive pair lambdas in Spec.Fast + Proofs.Agree/Answers/Lookups/Positions + Json use projections or rewrite locally; native build proof artifacts + 1834-check suite green. |
| L-fast4 | fast.md Evidence | unknown | unknown |
| L-author-server | server.md Authoring | unknown | unknown |
| L-author-wasm | wasm.md Authoring | unknown | unknown |
| L-author-web | web.md Authoring | unknown | unknown |
| L-author-fast | fast.md Authoring | unknown | unknown |

## Details

## Register

## Coverage

Pending rows retain their seed values. Commands + planted-input witnesses will be recorded below.
