# F-serve — spec fit at `48bc51d`

| row | target | verdict | basis |
|---|---|---|---|
| F-serve | GUI access (bind, opener, redirect page, link lines, Host, --host) | pass | `node …/reviewer-47/native.mjs` rc 0: same ephemeral port answers IPv4 + IPv6; four allowed Hosts 200, other Host 421; assets without credential; fake opener success/failure + private 0700 redirect + fallback lines; SSH/WSL/no-display suppress opener; concrete `--host` link + Host. Default 8718 = `Cli.lean:935`. |
| F-serve | login proxy (--token-file, output, credential order, relative route, JSON only) | pass | `native.mjs` + `proxy.mjs` rc 0: whitespace + invalid token files; output redaction; token before JSON type; real token-file upstream at `/fvtrace/`; 401/403 credential order + dedup + stored-token removal; address retention on 200/400/409, not 500; real HTTP Basic login alone. |
| F-serve | Sharing (export --html offline, --bundle round trip) | pass | `sharing.mjs` rc 0: file:// + network-off Chromium, recorded envelope = native; 2 stacked what-ifs + details, 0 HTTP requests; screenshot inspected. Bundle's 2 pinned artifact references match SHA-256; `check --strict` rc 0; second `serve` envelope = original + details 200. |
| F-serve | Engine speed + Capability first (named limits, on-request computation) | pass | `fast-fit.lean` rc 0: 3 equality proof types + central 20/16 MiB constants; caller wiring read. `capability.mjs` rc 0: 18 native/server/page-engine request payloads equal; outcomes lists, 45 excluded pairs + sentence, exact prerequisite plan, 80-entry expansion available on request; complete item payloads retained. No timing assertion. |
| F-serve | Response time + GUI responsiveness (functional half) | F26, F43, F45, F50 (known) | `responsive.mjs` rc 0: served + exported busy/Working…, node identity, long-list counts/end lines, positional reachability 1..300, find order/20 cap/Enter + all item kinds. `cache.mjs` rc 0. Existing nested-list, Text highlight, focus-on-reorder + lookup deviations remain; no duplicate finding. |
| F-serve | Prerequisite chains + Memory (scope of graded shapes) | pass | Scope matches: `scale.mjs:315–338` chain/star/creator cycle; `scale.sh:49–52,171–195,269–283` 7 graded shapes, F5 reference, 2.5× doubling + 1.5× RSS comparisons; `scale-gui.mjs:157–165` GC + live heap. Small chain plan/closure passes across 3 engines. Numerical compliance unconfirmed here; MAIN/B8 owns idle reference-host run. Existing F21 covers grader-failure detection, outside this scope-only row. |

Fixed scope = Decisions clauses named by MAIN. Security strength + reference-host timing excluded; MAIN owns both. Native binary = `/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/bin/fvtrace`; isolated data + probes = `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/`.

## Evidence → Decisions

Commands below run at `48bc51d`, target read-only; every child `fvtrace` sets `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/home`.

### GUI access

> "holds one port on both loopback addresses (`127.0.0.1` + `::1`)"; "opens the user's browser itself, through a private redirect page"; "after an open, as a fallback line"; "`--host` opts into LAN with the same token (printed link)".

`node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/native.mjs` → rc 0 (`native.log`). Real ephemeral socket at both loopbacks; all four Host spellings answer assets without a credential; other Host → 421. Default 8718 read at `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:935`; default fixed port not bound. Fake `xdg-open` receives one file path, never a URL; its redirect points to the fragment link; folder mode 0700. Opener exit 0 → address + fallback; exit 1 → `Open` link. SSH_CONNECTION, SSH_TTY, WSL + no display → no opener. `--host 127.0.0.1` → IP link + allowed Host, no opener. Real desktop browser never opened.

### Login proxy

> "its text without surrounding white space: ≥ 32 letters, digits, `-` or `_`"; "a token fvtrace did not make stays out of its output"; "each credential once per request, in order: its address token, its stored token, none"; "an address token is kept only on an answer … (200, 400, 409)"; "`api/answer` relative to its own address"; "JSON … alone (415 otherwise, decided after the token)".

`native.mjs` → trimmed token accepted; short/internal-space/invalid-character files rc 2; token-file output excludes secret + fragment + opener; wrong credential + plain type → 403, correct credential + plain/form type → 415; case-insensitive JSON + parameters → 200.

`node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/proxy.mjs` → rc 0 (`proxy.log`). Real token-file upstream; own HTTP proxy mounts `/fvtrace/`. Ten browser cases: 401 + 403 sequences A→B→none; duplicate A tried once; accepted address replaces stored B; refused address preserves accepted B; no token sends no Authorization; 400 refused what-if still keeps admitted A; 409 keeps A; 500 does not keep A; real HTTP Basic login reaches proxy without Bearer/local storage. Proxy 409 + 500 payloads deliberately supplied; 400/200 come from the native server.

### Sharing

> "one self-contained page: the recorded verdicts precomputed + the engine compiled to WebAssembly, so any stacked what-if evaluates in the page"; "`--bundle` = trace + copies of its pinned evidence for a colleague's own `fvtrace serve`".

`node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/sharing.mjs` → rc 0 (`sharing.log`). Network-off bundled Chromium navigates exported file:// page; recorded JSON = native eval; O2 checked then O3 checked stack in-page; claim details arrive; HTTP requests = 0. Inspected `/home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/offline-stacked.png`: nonblank C2 selected; both checked facts + exact statement + plan visible. Bundle copies satisfy both pinned artifact references' SHA-256; `check --strict` rc 0; second server returns original evaluation JSON + claim details 200. Worker/record-damage exceptional paths remain F-gui's slice (known F24/F37/F38), not re-reported.

### Fast engine + on-request computation

> "sorted indexes + memos, each proved equal to the definitions"; "anything that leaves the envelope stays computable on request (CLI, server, page engine)"; "local limits stay named constants".

`(cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/fast-fit.lean)` → rc 0; three agreement declarations typecheck; constants print `20` + `16777216` (`fast-fit.log`). Central definitions `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Engine.lean:288`, `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Decode.lean:392`; `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean:97` derives bodyCap from maxTraceBytes. Runtime plan implementations reference maxRelevant. Checked call wiring through Evaluate.envelope, CLI projections, Session preparation, Server.answer + Snapshot.Engine.answer. No independent-kernel replay performed by this slice.

`node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/capability.mjs` → rc 0 (`capability.log`). Generated outcomes 30, prereqs 12, whatif 40 + own all-pairs exclusion trace n=10: 18 native/server/page-engine request payloads compare equal. Counts/ref actions omit large lists; on-request details compute 30 raises + 30 wins, 45 excluded pairs + sentence, exact chain closure + plan, 80-entry stacked expansion. `eval --complete` returns every item (91/52/120/30). Bounded functionality only; neither cap-scale performance nor all-domain compiled parity claimed.

### Response time + GUI responsiveness

> "past [1 s], show that the computer is working"; "a selection moves the highlight + fills the details"; "a what-if replaces only the cards whose content changed"; "long lists show their size above them … an end line"; "Find a claim, fact or experiment … exact id, then id prefix, then words; up to 20 matches; Enter takes the first".

Server/cache clause: "keeps the loaded trace + the last answer … reloaded when the trace or its evidence changes". `node /home/eturkes/Projects/fvtrace/.scratch/review/reviewer-47/cache.mjs` → rc 0 (`cache.log`): repeat response bytes + view equal; artifact edit changes O1 to stale + changes view; restoring bytes restores answer; trace title edit reloads; every stage = fresh native evaluation. Source launch evaluation = `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Cli.lean:1066`; retained server state = `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Server.lean:39–43,163–209`; decoded-once snapshot + last answers = `/home/eturkes/Projects/fvtrace/.scratch/review-base/Fvtrace/Snapshot.lean:75–110`. Reuse counts not instrumented; cache transparency + source wiring checked.

### Prerequisite + memory scope

> "aiming at linear time on chains + stars, graded on `tools/scale.mjs prereqs` at its cap"; "general prerequisite structures may stay super-linear (ungraded)"; "RSS ≤ 2.5× per doubling … ≤ 1.5 × the worst `eval` RSS among the F5 shapes … `eval` + one `serve` … outcomes + prereqs and `eval` … whatif"; "GUI's memory = its live JS memory after a collection".

Generator `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/scale.mjs:315–338`: first third chain; second third star; final third self-creator cycles. Small chain: closure + exact plan R0..R3, 4 overrides, conditional final state; 3 engines agree. `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/scale.sh:49–52` → seven graded shapes + five report-only shapes; lines 171–195 → actions, every present item kind, served/page/GUI paths; lines 269–283 → same-run F5 eval reference + five required cap-RSS rows. `/home/eturkes/Projects/fvtrace/.scratch/review-base/tools/scale-gui.mjs:157–165` collects garbage + reads live heap/backing storage. Numerical cap/doubling compliance unconfirmed here: `tools/scale.sh --assert` deliberately not run; MAIN/B8 owns the idle reference host. Known F21's grader-failure detection remains open; this row checks shape/metric scope only.

## Coverage + probe history

- Native/opening branches = this Linux host + fake opener only; Windows/macOS opener behavior + unsupported/busy IPv6 OS branches not driven. Native socket checks cover working IPv4 + IPv6.
- Sharing = synthetic study. On-request differential = four small traces, 18 requests; no exhaustive all-domain or cap-scale compiled parity claim.
- Timing/RSS/byte-doubling gates, full gate, mutation, axiom audit + independent-kernel replay not run; MAIN owns the relevant baseline rows. Browser functional probes use bundled Chromium + reduced motion, not the live desktop browser.
- Preliminary probe failures = harness mismatches, not findings: schema identifier, inspector wording, refusal-triggered second evaluation, broad `C` query's 900 matches, and requiring all rows mounted at once after a window-moving find. Oracle corrected to positional reachability (the contract), not simultaneous mounting. One navigation timed out at 30 s under load ≈ 30–34; functional probe navigation then uses 90 s, without a performance claim. A pre-1 s hidden-indicator assertion raced the loaded host; functional test instead holds the request, observes busy + Working…, releases it, and observes both clear. The source's 1 s timer is read separately.
