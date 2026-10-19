# Deferred

Off-path findings; one entry + acceptance check each.

- CLI over the same engine (user ruling: GUI first, CLI later). Acceptance: `fvtrace claims|gaps|whatif|check <trace>` print the same states + counts as `GET /api/trace` / `POST /api/evaluate` for the tau-amyloid fixture (differential vs engine JSON).
- Coding-agent instructions (Intent: LLM inference ships as instructions for the user's own agent session): a skill/AGENTS doc that drafts a trace (questions, claims, obligations + routes, draft sentences + rewrites) from an analysis repo. Acceptance: an agent session following it on veriformatics `studies/naoto` yields a trace that the engine evaluates without error and that covers C1–C13 analogues.
- Trace extraction trust: claim/obligation wording + sentence→claim links come from an LLM ⇒ judgment-bearing input to a deterministic engine. Acceptance: a stated review step (human or adversarial reviewer) in the agent instructions before any verdict is shown as final.
- Engine lacks obligation exclusion: two obligations can be jointly impossible (e.g. distinct animals per assay vs an animal crosswalk), yet a what-if can verify both and light a claim. Acceptance: trace format carries `excludes`; engine marks a what-if set that verifies an excluded pair as inconsistent; fixture case shows it.
- Sentence kind: a definitional sentence (S1 "We defined …") is flagged overstated because its claim (C1) awaits spec review. Acceptance: user ruling on whether definitions carry claims; engine verdict follows the ruling for S1.
- Mobile length: ledger + lint mobile pages run long (every gap expanded). Acceptance: at 390px, each question/sentence fits its verdict + top reason in one screen with detail on demand.
- Reduced motion unconfirmed: ChromiumFish CDP emulation reports `prefers-reduced-motion` false. Acceptance: a browser where emulation applies shows zero transitions with reduce on, all 3 variants.
