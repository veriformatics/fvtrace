# F-serve — spec fit at `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| F-serve | GUI access (bind, opener, redirect page, link lines, Host, --host) | pass | `node …/reviewer-47/native.mjs` rc 0: same ephemeral port answers IPv4 + IPv6; four allowed Hosts 200, other Host 421; assets without credential; fake opener success/failure + private 0700 redirect + fallback lines; SSH/WSL/no-display suppress opener; concrete `--host` link + Host. Default 8718 = `Cli.lean:935`. |
| F-serve | login proxy (--token-file, output, credential order, relative route, JSON only) | pass | `native.mjs` + `proxy.mjs` rc 0: whitespace + invalid token files; output redaction; token before JSON type; real token-file upstream at `/fvtrace/`; 401/403 credential order + dedup + stored-token removal; address retention on 200/400/409, not 500; real HTTP Basic login alone. |
| F-serve | Sharing (export --html offline, --bundle round trip) | pass | `sharing.mjs` rc 0: file:// + network-off Chromium, recorded envelope = native; 2 stacked what-ifs + details, 0 HTTP requests; screenshot inspected. Bundle's 2 pinned artifact references match SHA-256; `check --strict` rc 0; second `serve` envelope = original + details 200. |
| F-serve | Engine speed + Capability first (named limits, on-request computation) | unknown | unknown |
| F-serve | Response time + GUI responsiveness (functional half) | unknown | unknown |
| F-serve | Prerequisite chains + Memory (scope of graded shapes) | unknown | unknown |

Fixed scope = Decisions clauses named by MAIN. Security strength + reference-host timing excluded; MAIN owns both. Native binary = `/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/bin/fvtrace`; isolated data + probes = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/`.
