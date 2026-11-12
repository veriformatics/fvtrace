# Lens notes for waves 3–5 (read after BRIEF.md)

## K — Cleanup + Altitude (two passes over your slice, one per lens)

- Cleanup: an existing helper re-implemented (grep the repo before calling a block new); derivable state stored twice; near-duplicate blocks (same shape, a parameter apart) that one function would serve; dead code — unused definitions, exports, parameters, branches, CSS rules, config keys, probe or test helpers nothing calls (prove deadness: `rg -n '<name>' <base>` over every tree that could reference it, incl. `tools/`, `tests/`, `web/`, proofs, Lakefile, workflows); independent steps run serially where order does not matter; startup + hot paths doing work their result does not need; closures capturing more than they use.
- Altitude: a special case added to shared infrastructure (one caller's quirk inside a common helper; a flag that exists for one call site; a workaround that a fix in the mechanism would remove) = a finding naming the mechanism fix.
- A finding needs anchor bytes (`rg -Fn`) + the evidence of the claim (e.g. the `rg` that finds no caller, the two blocks' line ranges); fix direction in one line. Proof bodies (`Fvtrace/Proofs/*`): only unused lemmas (a theorem no other proof, no Spec claim, `TrustMain.lean` and no `simp` set names; `@[simp]` lemmas count as used only where a `simp` call could reach them — say how you decided).
- Behavior must stay the same: a cleanup that changes output is a correctness question → Register.

## S — claim soundness + guarantee-vs-claim

- Every statement in the surface (sentence, table row, help line, comment, docstring) says what the code, proofs + tests establish, no more; "proved" vs "tested" stated right; numbers (limits, sizes, counts, versions, times) match the code + measurements; examples run as written (run them under your own `FVTRACE_HOME`).
- A finding = the anchor bytes + the behavior or source that contradicts them (command + output, or `file:line` of the code).

## V — verification integrity

- A test asserts values the contract owns (kernel.md, Decisions, README) — not values copied from the implementation's output; a fixture's expected value returned by the code under test = defect.
- No case skipped, `xfail`ed, `.only`/`.skip`, commented out, deleted or demoted without a `.agent/deferred.md` row; thresholds, limits + timeouts as the rules state (`web.md` e2e limits; `fast.md` bounds).
- Each purpose-built check can fail: name the planted input that makes it fail (the probe in `tools/gate-probe.sh`, or one you build in your copy) and run it where cheap.
- Each test file is wired into a runner the gate runs (`Tests.lean` pure/native, `node --test` globs, Playwright `testDir`/`testMatch`).

## F — spec fit

- Behavior vs each `Intent` sentence + `Decisions` entry in your scope: drive the real program (CLI under your own `FVTRACE_HOME`; `serve --port 0 --no-browser` + Playwright Chromium from the base `node_modules`; exported pages on file://). Quote the Decisions words you test against; a departure = finding with the command + output or a screenshot path (inspect every screenshot you take).

## L — `CLAUDE.md` conformance (lens × clause)

- Per clause: does it bind a tracked file? If not → `n/a <reason>`. Tool-decidable (a deterministic program could decide every instance)? → name the gate check that decides it (stage + tool + config line), then plant one bad input in your copy and run that check: it must fail naming the cause (`pass`), else finding "no firing check" (fix = wire one). Judgment clause → adjudicate it over the files it binds (sample is fine when the file set is large: state the sample + how chosen).
