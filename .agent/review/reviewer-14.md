# reviewer-14 — C-cli / Correctness

Target = frozen `48bc51d`, `/home/eturkes/Projects/fvtrace/.scratch/review-base`.
Check set fixed by assigned C-cli brief before target reads.

| row | target | verdict | basis |
|---|---|---|---|
| C-cli | Args.lean + Cli.lean argument parsing + exit codes | unknown | unknown |
| C-cli | Store.lean: data folder + entries + writes | unknown | unknown |
| C-cli | init / path / check / pin / review | unknown | unknown |
| C-cli | verify (list, --run, --log) | unknown | unknown |
| C-cli | claims / gaps / experiments / plan / eval text + --json (L1) | unknown | unknown |
| C-cli | export --html / --bundle | unknown | unknown |
| C-cli | skills install / show, schema, --help, --version (L2) | unknown | unknown |
| C-cli | serve: bind, link, opener, token file | pass | Read serveCmd + Server.start/stop call boundary; helper suite covers opener selection + busy-port retry; 15 native checks: dual-loopback equality, readiness, no-browser/token-file output, both PIDs reaped + ports refused. |
| C-cli | Assets + Version + embedded files | pass | All assigned files + Main→Cli wiring + Lake `needs` read; assigned FFI-free suite 115/115, schema/skill bytes and version checked through native binary. |
| C-cli | tests (setup/teardown, asserts) | unknown | unknown |

## Findings

Pending.

## Register

Pending.
