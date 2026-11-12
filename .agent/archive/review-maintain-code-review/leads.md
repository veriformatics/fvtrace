# Leads (cross-slice; route to the owning row's reviewer brief; MAIN rules)

| lead | from | target row | note |
|---|---|---|---|
| L1 | reviewer-5, reviewer-6 | C-cli, F-cli | `Fvtrace/Cli.lean:764` `plan` prints `{c.id} {verdict}: {sentence}` without `A.qualifiers` (claimsCmd :648–650 prints them); Decisions Review: every surface shows the engine label incl. prospective qualifier |
| L2 | MAIN B4 | C-cli, S-readme | `fvtrace <command> --help` → rc 2 "unknown option --help"; `fvtrace schema --help` → "unknown command 'schema'"; data errors (no claim C99, what-if refusals) print the whole 4.5 KB usage after the message | → per-command `--help` = user ruling, 8cad80c (F16 = schema); usage after a data error = closing question
| L3 | MAIN B4 | S-readme | README Commands table lacks `fvtrace eval` (spec Artifacts + `--help` list it) |

Security pointers (MAIN alone): `Fvtrace/Check.lean:17` (`Artifact.pathSafe`; reviewer-3, reviewer-4) · `c/fvtrace_digest.c:19-20` (reviewer-9, reviewer-10) · `Fvtrace/Session.lean:65` (reviewer-12).
