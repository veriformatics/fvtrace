# Manuscript check (shelved)

Shelved in ITERATE round 3 (user ruling; may return as a separate project). Recover: `git checkout prototype-lint -- prototype/gui/web/variants/lint` + fixture `draft` block + engine `sentences` evaluation from tag `prototype-lint`.

- Variant C = draft results paragraph, per-sentence verdict marks, margin notes, stub rewrite, "what would make this sentence true" + what-if.
- Verdict rule = `overstated` (cites open|cannot claim) | `needs-premise` (cites conditional) | `supported`.
- Open rows at shelving:
  - Sentence kind: a definitional sentence (S1 "We defined …") is flagged overstated because its claim (C1) awaits spec review. Acceptance: user ruling on whether definitions carry claims; engine verdict follows the ruling for S1.
  - Mobile length: lint mobile page runs long (every gap expanded). Acceptance: at 390px, each question/sentence fits its verdict + top reason in one screen with detail on demand.
