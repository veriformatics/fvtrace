# Trace format (`"fvtrace": 1`)

`fvtrace schema` prints the full JSON Schema. Ids match `^[A-Za-z][A-Za-z0-9_.-]{0,63}$` and are unique across the trace. Texts are non-empty and contain no control characters except newlines. The arrays `experiments`, `exclusions`, `waivers`, `artifacts`, `trusts` and `requires` may be absent. An absent array is empty. Every other array is required. Never write `null`.

```
{
  "fvtrace": 1,
  "analysis": {"id", "title", "summary", "source"?},
  "subjects": [{"id", "title", "kind": "existing" | "prospective", "createdBy"?}],
  "questions": [{"id", "title", "text"}],
  "facts": [{"id", "subject", "kind", "text", "status", "route", "evidence"?, "trusts"?, "instantiates"?, "why"?}],
  "claims": [{"id", "question", "subject", "level", "text", "headline"?, "needs": [fact ids], "entailment"?: fact id, "restates"?: true, "latent"?, "variantOf"?}],
  "experiments"?: [{"id", "subject", "kind": "dry" | "wet", "effort": "hours" | "days" | "weeks" | "months", "title", "method", "resources", "success": {fact: status}, "failure"?: {fact: "violated"}, "requires"?: [experiment ids], "caveat"}],
  "exclusions"?: [{"id", "subject", "between": [fact, fact], "text", "status", "route", "evidence"?}],
  "waivers"?: [{"rule", "claim", "reason"}],
  "review"?: written by fvtrace review only
}
```

## Parts

- **subject**: what the facts are about. `existing` = the analysis as it is (at least one). `prospective` = data an experiment would create. It names that experiment in `createdBy`. Its facts stay `open`.
- **fact kind**: `result` (the observed value or pattern a claim asserts), `estimand`, `statistical`, `numerical`, `implementation`, `dataflow`, `provenance`, `interpretation`, `release`, `spec-review`, `instantiation` (reuses a fact of another subject: name it in `instantiates`), `entailment` (one per claim, only as its `entailment`).
- **claim level**: `estimand`, `descriptive`, `inferential`, `causal`, `release`. `fvtrace check` warns when a level lacks the facts it usually needs (for example, a causal claim without an `interpretation` fact). A waiver records why one is absent.
- **evidence**: `{"summary", "artifacts": [{"path", "sha256"?, "role"?}], "verifier"?, "statement"?, "statementDigest"?, "replay"?: {"command": [arg, ...], "output"?, "failed"?: {"date", "reason"}}}`. `summary` = what the evidence is (for example, the name of the proof). For a `proved` or `checked` fact, it also holds the plain reading of the statement (`references/faithfulness.md`). `failed` = the notice of a failed replay (date + reason). `fvtrace pin --replay` and `fvtrace verify --run` write it. They remove it when a replay passes. Never write it yourself. Paths are relative to the project folder, `/`-separated, without `.` or `..`. `fvtrace pin` fills `sha256` and `statementDigest`. `replay.command` = a verifier that checks the fact again (program, then arguments; no shell). `fvtrace verify --run` runs it in the project folder. `fvtrace pin --replay` fills `output` (the SHA-256 of its output). A replay never changes a verdict. Write one only when the user asks for it. Never run `--run` or `--replay` without the user's consent. A `proved` or `checked` fact needs artifacts, a verifier, a statement and pinned digests.
- **trusts**: what the verification itself relies on (a compiler, a kernel, a library).
- **claim text + headline**: `text` is the exact statement, the sentence the proofs cover. `headline` is an optional plain form for readers. It never says more than `text`. The user confirms that at review. It stays outside every statement digest. The review digest covers it.
- **entailment + restates**: every claim names one `entailment` fact, except a claim that restates one result. For that claim, mark `"restates": true`. Set `needs` to that one `result` fact. Name no `entailment`. Pinning that result binds the claim's text. Rewording the claim then makes the receipt stale.
- **why**: optional on a fact: why a claim needs it, in plain words (what goes wrong without it). Display text, outside the statement digest.
- **latent** claim: an overlooked direction that becomes possible if its facts hold.
- **exclusion**: two facts that cannot both hold on one subject. It has its own status and route. fvtrace uses it only when it is verified or assumed.
- **requires**: experiments that must run first (listed earlier, same subject).
