# Deferred

Off-path findings; one entry + acceptance check each.

- CLI over the same engine (user ruling: GUI first, CLI later). Acceptance: `fvtrace claims|gaps|whatif|check <trace>` print the same states + counts as `GET /api/trace` / `POST /api/evaluate` for the tau-amyloid fixture (differential vs engine JSON).
- Coding-agent instructions (Intent: LLM inference ships as instructions for the user's own agent session): a skill/AGENTS doc that drafts a trace (questions, claims, obligations + routes, draft sentences + rewrites) from an analysis repo. Acceptance: an agent session following it on veriformatics `studies/naoto` yields a trace that the engine evaluates without error and that covers C1–C13 analogues.
- Trace extraction trust: claim/obligation wording + sentence→claim links come from an LLM ⇒ judgment-bearing input to a deterministic engine. Acceptance: a stated review step (human or adversarial reviewer) in the agent instructions before any verdict is shown as final.
