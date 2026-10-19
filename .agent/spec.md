## Intent

fvTrace is a tool to help analyzers of scientific data understand what claims they can and cannot make. In this context, "fv" is short for "formal verification". We take the stance that a claim can only be made if it is formally verified. In any existing analysis, where no formal verification work has been performed yet, this tool can identify where such work can be applied, and if verified, what resultant claims can be made. This is the basic premise but it can be extended. In general, the tool should help users navigate what their scientific questions are, what gaps that need filling in order to answer those questions, and help ensure nothing is overstated. It can also be used to help identify directions and associated relationships that a user might have overlooked or understated, which become relevant if certain facts about the current analysis are true (or can be verified to be true).

Users will interact with fvTrace through a CLI and web-accessible GUI. If fvTrace will use LLM-inference to help accomplish its goals, it should come with instructions so that it can be used from within a user's existing coding agent session.

## Artifacts

- `prototype/gui/` = PROTOTYPE GUI: stdlib server + engine + fixture + claim circuits GUI. Run: `uv run prototype/gui/serve.py` → http://127.0.0.1:8642/ (redirects to claim circuits) (`--port N` overrides).
  - `prototype/gui/fixture/tau-amyloid.json` = hand-written trace of the tau × amyloid study (structure from veriformatics `studies/naoto` docs; private, no data).
  - `prototype/gui/engine.py` = deterministic claim-state engine; `GET /api/trace`, `POST /api/evaluate {"overrides":{Oid:status}}` (what-if).
  - `prototype/gui/web/variants/graph/` = claim circuits (sole design): claims grouped by verdict per question (circuit | text view) + suggested dry/wet experiments per gap (ranked list, per-claim plan, success/failure what-if).

## Decisions

- PROTOTYPE set = GUI first over a hard-coded fixture; CLI + agent instructions follow later (user ruling).
- Stack = Python via `uv` (stdlib `http.server`, no deps) + vanilla HTML/CSS/JS, no build step (user ruling).
- Fixture = the tau × amyloid study from veriformatics `studies/naoto` alone (user ruling) ⇒ repo stays private.
- GUI = claim circuits alone. Ledger retired (user ruling, round 2: redundant with circuits); its verdict grouping + "Assuming …" conditional phrasing + linear reading carried into circuits (group headings, text view listing each open fact once per question).
- Trace model = questions → claims → obligations. Obligation = one fact a claim needs + `status` + `route` (how it could be verified: `lean`, `runtime-checker`, `refinement`, `human-ruling`, `empirical`) + evidence + trusted base.
- FV stance in the engine: verified = `proved` | `checked` (proved checker accepted the actual object). `assumed` = declared premise ⇒ claim allowed only in conditional form. `tested` | `open` = gaps. `violated` ⇒ claim cannot be made as written.
- Claim state = `cannot` (any violated) > `can` (all verified) > `conditional` (rest assumed) > `open`.
- Where FV pays = per unverified obligation: claims it gates + claims verifying it alone unlocks; ranked by unlocks. `latent` claims = overlooked directions that become live when their obligations verify.
- Experiments (user request, round 1; graph variant) = trace `experiments[]`: `kind` `dry` (existing data, code, proofs) | `wet` (new samples, bench), `effort` hours < days < weeks < months, `success` + `failure` = obligation → status maps replayed as what-ifs, `scope: new` = creates new data. Engine per experiment: `lights` (claims raised into can|conditional), `clears` (cannot → open), `breaks` (failure → cannot); ranked lights > clears > cheaper. Per claim `plan` = cheapest experiment raising each unverified need (prototype default; selection rule = open user ruling, `.agent/deferred.md`) + `uncovered` gaps (ruling | new approach) + plan-success state.
- Experiment outcome honesty (scientist-1 rulings): `checked` only via a proved checker on the actual data, `proved` only via a completed proof; empirical support → `assumed` at most; failure = established counterexample, inconclusive → `{}`; `scope: new` = intent: a new-data outcome never closes a gap in the existing analysis. Prototype shortcut: the engine ignores `scope` + reuses existing fact ids as stand-ins, disclosed in the UI; modeling = open user ruling (`.agent/deferred.md`).
- ITERATE closed (user ruling): claim circuits = approved direction for IMPLEMENT; open model questions (new-data experiments, plan selection) stay unruled → `.agent/deferred.md`.
- Manuscript check shelved (user ruling, round 3; possible separate project): variant, draft-sentence verdicts + fixture `draft` removed; recoverable from tag `prototype-lint` (`.agent/archive/manuscript-check.md`).

## Tasks

- Deferred queue → `.agent/deferred.md`; PROTOTYPE + ITERATE history → `.agent/archive/`

## Phase

IMPLEMENT — whole product
