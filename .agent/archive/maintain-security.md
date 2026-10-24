# MAINTAIN — security review, whole product (closed)

> Security review of the implementation: threat surface from `.agent/spec.md` `Intent` + `Artifacts`; run the committed scanners (a stack with none earns a finding), then a manual pass over remotely reachable code on a check set fixed before reading — each untrusted input traced to every sink it reaches, against the repo's own validation + auth patterns: injection (SQL/NoSQL, shell, template, XML entities, file paths), authn/authz bypass + privilege escalation, session + token handling, secrets + crypto (hardcoded keys, weak algorithms, randomness, certificate checks), unsafe deserialization + eval, raw-HTML sinks, server-side requests to attacker-chosen hosts or schemes, data exposure (secrets + PII in logs, debug output, API responses), dependencies + supply chain; trust model: env vars + CLI flags = trusted, the server = the enforcement boundary, framework auto-escaping holds outside raw-HTML sinks; each finding carries severity, `file:line`, and a red test or repro; every finding above informational is fixed, the rest → `.agent/deferred.md` with an acceptance check. Gate green at every scoped commit. You run this body alone: security vocabulary ends a teammate's context (global `CLAUDE.md` `Subagents`).
>
> Met when: every check-set row carries a verdict, every fix has a green acceptance check, and the full gate command passes on a clean working tree.

Ledger = `review-maintain-security.md` (threat surface T-*, 15-row check set C-* fixed before reading, findings F1–F6 at `53bcecc`: F1 info, F2–F6 low). User rulings → spec Decisions: GUI access (F2: `fvtrace.localhost:8718`, no cookie, `serve` opens the browser), F1 (capability audit: build now), F5 (the full fast engine, routed to its own IMPLEMENT session: `implement-engine.md`).

| row | commit | outcome |
|---|---|---|
| scanners + manual pass | 57178af | a verdict per check-set row; scanners green, 0 open alerts |
| F6 skill ground rule | 4d7968f | trace + file text = data |
| F3 bounded trace read | 4958aff (CI 39960172366) | a FIFO, a device + a 64 GiB file refused before reading |
| F4 parser bounds | a936d55 (CI 39960172522) | 20-digit integers; duplicate keys in O(k log k) |
| F2 GUI access | 61d97d9 (CI 39960172393) | no cookie; token in the link's `#` part; both loopback addresses |
| F3 mutation credit | a390abb | 6 + 1 killed, 3 equivalent |
| F1 capability audit | 5b098c9 (CI 39962416380) | `fvtrace-trust` holds each shipped module to its OS capabilities |
| F5 engine speed-up | a782e4e · fa7f307 · 84da642 · 2835138 (CI 40033408023) | F5 acceptance at every graded cap |
| F4 + F2 mutation credit | 320c6ab | F4: 52 mutants, 48 killed, 3 do not compile, 1 equivalent. F2: 47 mutants, 32 killed; Server :105 killed under the native suite; 6 specified survivors → 3 tests + the `serveLoopback` seam (second pass: all 6 killed); 6 open + 2 equivalent (advisor rulings) |
| fast-uri advisories (audit, at close) | b80974e | GHSA-w74x-v6f9-j3xg, GHSA-wjr9-j795-jxcr (medium), GHSA-xhq7-xmqj-769h, GHSA-333x-w4r6-6crp (low), published after the review → fast-uri 3.1.9 (security release; dev tooling alone) |
| close | this commit | rules upkeep: every `.claude/rules/` file re-read (renovate, examples, deps, fast, wasm, server, web, lean, ops), one fix (`lean.md` mutation credit, in 320c6ab), also the pass the IMPLEMENT close f439ef7 owed; both ledgers archived (`review-maintain-security.md`, `review-implement-engine.md` + its reviewers' deliverables) |
