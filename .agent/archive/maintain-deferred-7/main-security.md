# Closing review — MAIN rows (security lens + fuzz slice; outside reviewer-3's scope)

| id | lens · slice | verdict | evidence |
|---|---|---|---|
| S1 | security · f03c3c7 moving link | pass | `PWD` is read only to name the data-folder entry (`keyOf` → `entryName`: sanitized basename + 12 hex of SHA-256); files are still read through the real path; whoever sets `PWD` already runs the binary |
| S2 | security · eb07121 proxied text | pass | `Config.shared` changes message text alone; `Server.decide` (access, Host, token, Content-Type) untouched; no file path enters a message |
| S3 | security · bf87c94 Lake cache | pass | restore scope = the run's own ref, then `main` (a fork PR cannot write `main`'s scope); weekly run cold; `build.yml` + `release.yml` never restore (provision check + probe); zizmor "No findings" |
| S4 | availability · 36349ab reuse rule | owed | one reuse chain costs depth × facts (measured ≈ 4.3× per doubling; ≈ 3.3 h `eval` at the 16 MiB cap) on a trace from someone else → `.agent/deferred.md`, the user's choice |
| S5 | security · 39f6756 fuzz | pass | `FvtraceFuzz` + `fvtrace-fuzz` dev-only (no import from `Main.lean` / `Fvtrace.lean`); `fuzz.yml` `contents: read`, `persist-credentials: false`, actions pinned by SHA; campaigns run sanitized (ASan + UBSan); CI campaign 45208133133 green |
| S6 | security · 77c0fce HACL* | pass | `tools/vendor-hacl.sh --verify` = the pinned rev byte for byte (gate `vendor`); only codegen style changed (KaRaMeL temporaries) |
