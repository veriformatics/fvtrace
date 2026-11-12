# scientist-2 — F89 + the next step on B8's growth check

Recommendation: **C, qualified: ask the user to accept an explicitly unfinished B8 as deferred, then close the rest only after its closing gate passes. Keep fastest-of-3, every bound, and every red.** This is a scope/acceptance decision, not a scientific finding that the product passed. The user already ruled the growth statistic; call the new decision **whether to defer unfinished timing acceptance**, not a missing growth-check ruling. If the user requires the original full-run timing finish line, leave B8 open; no option establishes it from the present data.

For *resolving the scientific growth question*, B remains the strongest design candidate among A–D, preferably preceded by a targeted pilot. It is not authorized under the user's renewed “Keep fastest of 3” ruling, and b8l does not prove that its median statistic is necessary or that it will pass. Do not adopt it by default or re-present it as a minor implementation detail. A buys another operational attempt, not a diagnosis; D produces a post-hoc summary, not the required green run.

Scope = existing logs/source + local arithmetic only. No timing, builds, browsers, offload, SSH or nixbox access. Only this validator input + `.scratch/scientist-2/` written; unstaged; MAIN commits. Root = `/home/eturkes/Projects/fvtrace`; paths below relative to it unless absolute. g/h/k/l = `.scratch/bench/b8g-1.log`, `b8h/b8g-1.log`, `b8k/b8g-1.log`, `b8l/b8g-1.log` respectively.

| id | claim | verdict | evidence (numbers + file:line or log line) |
|---|---|---|---|
| U1 | F89 = class `gate` (sampling design: each size's 3 runs in its own window; the half size's two fastest samples ran under the lightest foreign load); a product cause not excluded | supported | **Provisional design classification**, not a proved false alarm. F89 **2.552670**, median-of-3 ratio **2.601786** (l:360–363); phase Python **.60/.58/1.59 → 1.577/1.567/1.560 CPU**, only **1/2/1 → 3/3/4** host samples (l:3240–3447). Product × load interaction/browser scaling remains live. |
| U2 | The four reds since F83 (b8g-1, b8h, b8k, b8l: 4 of 828 graded row-runs, a different row each time, each red row ≤ 2.27 in the other runs) fit a family-wise false red of the current grader under this host's noise; no graded row shows consistent growth past 2.5 | overstated | **4/828**, four distinct rows, no row >2.5 in every run: confirmed. “False” not identified; **4/4 complete runs failed** the stipulated rule. The ≤2.27 clause is false: deep served details reads **2.312/2.348/2.431** in g/h/l (g:152–153, h:151–152, l:150–151). Correct to “<2.5 in the other runs.” |
| U3 | Option A = B8 again, tool unchanged: what a pass or a red would establish; the chance of a pass on this record | open | A future pass establishes **one full observed pass of the chosen protocol**, not the cause of four prior failures or stable performance over host states. Pass probability not identifiable; observed **0/4**, or **0/3 current driver / 0/2 driver+sampler**. Rerun needs the user's fresh decision; no in-run confirmation. |
| U4 | Option B = paired growth (your T5 design) in its own unit, then B8: what b8l adds; still the recommendation? | supported | Still the **strongest candidate design for a comparable-growth measurement**, not the next action under the settled minimum ruling. F89 adds **two** quiet L measurements; marginal medians still fail at **2.602**. Post-hoc ordinal pair median **2.483**, but **4/6** possible pairings fail: actual matched collection matters, not rearranging old numbers (l:360–361). Benefit/power not prospectively validated. |
| U5 | Option C = close the review now: F81 + F82 accepted on their own bounds (b8l: deep details 0.868 / 0.627 s ≤ 1 s; exports at N_cap ≤ 5.54 s ≤ 10 s); F83 + F86–F89 → one `.agent/deferred.md` row blocked on the user's growth-check ruling; the GUI growth bound not claimed as met | overstated | Time-bound limbs supported: F81 **.868/.627 s** (l:151,166); F82 max **5.54 s**, outcomes (l:684). Closure **now** and “blocked on the growth-check ruling” are not established: that ruling already exists, and B8 is red (l:999). Corrected C requires **explicit deferral/acceptance-scope ruling + closing full gate**, while preserving fixed F83/F86 mechanics separately from outstanding timing acceptance. |
| U6 | Option D = grade growth on the runs of the same binary pooled (per row: the median of its run ratios; b8g-1..b8l max 2.39, b8h..b8l max 2.43): what it supports; post-hoc + like-for-like limits | unsupported | As replacement acceptance: post-hoc + contradicts current rule. As description: exact maxima **2.389599** (g/h/k/l), **2.431373** (h/k/l), both deep served details. Closest like-for-like **k+l** gives **2.567860**, still red. Same native SHA does not equate driver/sampler/runtime/host histories. |
| U7 | The option the evidence best supports + why (science, not taste) | supported | **Corrected C for the next user decision under “Keep fastest of 3”; B for future causal measurement only if that ruling is reopened.** C permits honest partial closure without converting 4 failed full runs into a pass. No scientific evidence makes all-green closure available now or makes a lucky fifth attempt a diagnostic. Cost/scope remain the user's judgment, not a probability inferred from 4/828. |

## U1 — F89's measured failure and causal limits

L/H = 12,798/25,597. Wall triples = **1.212, 1.246, 1.428 → 3.242, 3.094, 3.277 s**. Recomputed per-doubling ratio, using `scale.sh:75–78`'s exponent: **2.5526704449**; median/median = **2.6017859388**. The supplied `ratios.py` uses raw H/L, whereas the grader normalizes to one doubling; difference small here, exact grader arithmetic used for all rulings. F89 is a genuine recorded violation of the chosen statistic; its failure is not a rounding artifact. At the exact n ratio, −**63.84 ms** on H's minimum or +**25.54 ms** on L's alone reaches 2.5. Sensitivity is not a tolerance.

### Targeted host probe

Independent parser matches each `gui:page:whatif` start/end to its enclosing exclusions session, fails if a requested phase is absent, then selects sampler ticks within the marks. Python = sum of the entries named `python` among the top three recorded processes; a **lower bound on Python CPU**, not complete unrelated-process CPU. Percentages divided by 100 = CPUs' worth. `mhz` is busy-weighted instantaneous frequency, not measured service cycles. Phase marks include ~31–34 ms of driver work before/after the event interval; graded walls remain the event→paint values above.

| Size/run | Graded wall (s) | Host ticks | Listed Python mean (CPU) | Host busy mean (CPU) | Instantaneous MHz mean | Host-log mark lines |
|---|---:|---:|---:|---:|---:|---|
| L1 | 1.212 | 1 | .600 | 1.85 | 2649 | l:3240–3242 |
| L2 | 1.246 | 2 | .580 | 2.53 | 3181 | l:3272–3275 |
| L3 | 1.428 | 1 | 1.590 | 3.42 | 2701 | l:3306–3308 |
| H1 | 3.242 | 3 | 1.577 | 3.84 | 2563 | l:3348–3352 |
| H2 | 3.094 | 3 | 1.567 | 3.90 | 3033 | l:3395–3399 |
| H3 | 3.277 | 4 | 1.560 | 3.78 | 3071 | l:3442–3447 |

This is consistent with different exposures at the two sizes. Whole-session Python means = **.571/1.046/1.576 → 1.633/1.550/1.481 CPU**. The second small session illustrates why a session average is not the event exposure: its selected page-what-if ticks show .58 CPU while its entire session averages 1.05.

Sensitivity to the coarse 1 s cadence: extend phase windows by 1 s at both ends → Python means **.593/1.003/1.570 → 1.566/1.552/1.577**. The clean .58 reading is window-sensitive, but the broad quiet-small/heavier-large pattern survives. No exact sub-second treatment effect follows from 1–4 ticks. Exclusions sessions show no swap or memory-pressure stalls and ≥56,587 MiB available memory; gross memory pressure is less plausible, browser-local GC is not excluded.

Post-hoc matching L3's listed Python load to H gives **2.167–2.295** per doubling. Useful sensitivity, **not a new grade**: L3 was selected after inspecting timing/load; one telemetry dimension does not equate scheduler, cache, thermal, browser or frequency histories. Do not discard the valid faster L1/L2 observations or invalidate the cap's real-world background load. The user expressly includes that work in the reference condition.

Independent near-limit row: wide page what-if = **2.4750** minimum ratio, **2.5435** median ratio (l:87–88). Its phase Python means **.615/.185/.695 → 1.270/1.568/1.568 CPU**, clocks **3.55–3.76 → 2.83–2.95 GHz** (l:1481–1685). This is a second within-run exposure contrast, not an independent randomized experiment or proof that every red has one cause.

### Controls, assumptions, rivals

- Exclusions standalone `serve:action` = 1.11→2.26, **2.03595**; Node `page:action` = .90→1.83, **2.03325** (l:318–331). These are **controls, not upper bounds on the browser's engine component**. They occur earlier, in different processes/load conditions. `scale.mjs:371–383` chooses `suppose:E0` here; the GUI clicks its first enabled fact symbol (`scale-gui.mjs:280–285`), so identical action/payload should be established before treating them as the same work. No phase-level engine time inside the failing browser operation was recorded.
- Native SHA matches across g/h/k/l. It excludes newly changed product bytes, not latent browser/runtime thresholds, real product×contention interactions, or different host histories. A correct implementation may still violate a performance bound in some allowed host states.
- Main rivals: unmatched background load (strong lead); size-dependent browser/GC/JIT/rendering; prior session or size-induced heat/power state. A thermal story is not identified: L's short phases have more throttle events while the slower H phases have few/none. Counters are not lost CPU time. Browser/runtime versions are not printed by these logs.
- Therefore `gate` can name the **sampling-design problem** provisionally. It must not mean “product exonerated” or “the current grader computed the wrong verdict.” Given its chosen min/min rule, it computed red correctly. The open question is whether that comparison establishes intrinsic/comparable product growth, which the observations do not isolate.

## U2 — four scattered exceedances are not four proved false alarms

Recomputed all **207 graded timing pairs/run**, **828 row-runs total**; 83 GUI pairs/run. All four literal FAIL lines match exact ratios:

| Row | g | h | k | l |
|---|---:|---:|---:|---:|
| wide `gui:served:first` | **2.63817** | 1.93095 | 2.20849 | 2.19009 |
| experiments `gui:page:whatif` | 1.97080 | **2.51125** | 1.86139 | 2.27029 |
| deep `gui:served:details` | 2.31198 | 2.34783 | **2.70435** | 2.43137 |
| exclusions `gui:page:whatif` | 1.92025 | 2.27390 | 2.11301 | **2.55267** |

Sources: g:61–64,152–153,272–273,362–363; h:61–62,151–152,271–274,362–363; k:61–62,151–154,272–273,362–363; l:60–61,150–151,270–271,360–363.

Correction for MAIN: `.agent/review.md:316` / U2's seed **“each red row ≤2.27 in the other three” is false**. Deep reaches **2.43137** without crossing the bound; exclusions h also equals **2.27390**, slightly above literal 2.27 when unrounded. Use **“each red row <2.5 in the other three.”** “No graded row exceeded 2.5 in all four runs” is a descriptive fact. “No graded row truly grows above 2.5” is not established.

The pattern is compatible with many noisy comparisons occasionally crossing a bound. It is also compatible with intermittent genuine performance violations in allowed conditions, mixed causes, or one or more ratios with little true margin. F86 additionally involved a known driver interval defect; do not treat all four as exchangeable draws from one fixed valid grader. Only k/l have both the current first-view driver and the host sampler.

**4/828 = .483% is an observed row-exceedance fraction, not a false-positive rate.** Rows differ in work, noise, margin and measurement granularity; many share a session and one load history. False-positive classification needs the reference truth against which the check errs. No such noise-free or matched-state truth was measured for all rows. The stronger direct observation is **four full attempts, four failures**, not “99.5% of the timing contract passed.” Most rows did pass individually, but acceptance is their conjunction.

Multiplicity explains plausibility, not attribution. If 207 independent identical rows each had exceedance probability 4/828, a plug-in all-green probability would be **36.70%** and four consecutive red runs would have probability **16.06%**. Those assumptions are unsupported here; this arithmetic must not be presented to the user as the chance the next B8 passes. The F88 resampling model rates likewise remain sensitivity results, not calibrated forecasts for F89.

## U3 — A: another unchanged B8

Allowed only after the user chooses it; “Every failure to you” is not standing permission for another try or an in-run confirmation. No additional timing was run here.

- **Green:** all current checks were within their bounds in that specific complete run, on its recorded host conditions, fastest-of-3. It supplies the operational acceptance witness requested by the current method. It does not establish that F87–F89 were false, a stable small false-red probability, or performance across every allowed background workload. Preserve the failed attempts beside the green.
- **Red:** another genuine failure of the current chosen statistic, recorded/classified and returned to the user. Which row failed + phase/host evidence may add information; without a change designed to separate explanations, another 64-minute run may mostly reproduce the existing ambiguity.
- **Pass chance:** not identifiable from this record. Observed 0/4 full passes is not proof of probability zero. Even under an *illustrative* independent identical whole-run model, 0/4 yields a one-sided 95% upper bound **52.7%**; for the current driver 0/3 → **63.2%**, current driver+sampler 0/2 → **77.6%**. Protocol/state differences make these illustrations, not valid calibrated bounds for the next run. No justified expected number of attempts follows.

Repeated attempts with “stop on the first green” select a favorable outcome even when every failure is retained. For a fixed pass probability p, chance of at least one green in K tries is `1−(1−p)^K`; as K grows, a green becomes likely without changing the product or explaining the failures. The user may intentionally choose an operational witness, but the report must not turn that stopping rule into evidence of repeatable stability.

A therefore remains a transparent option, not the recommended scientific diagnosis. A pass should not be promised, described as due, or predicted from 4/828.

## U4 — B: prospective paired growth

B = three counterbalanced whole-run pairs per size, growth = median of the three normalized pair ratios; absolute times/RSS/bytes retain F83's minima. It changes the approved growth statistic. The user's renewed choice **keeps that choice settled until the user explicitly changes it**.

What F89 adds:
1. The previous interpretation “a lone fast minimum caused the red” is insufficient. Here the two fastest L observations share lighter load. Both minimum and marginal median fail. This strengthens the case for **comparable temporal exposure**, not merely replacing minimum with median.
2. Original-order ratios of these grouped triples have median **2.48302**, but permuting which H is paired with which L produces **2.48302–2.62987**, with **4 of 6 permutations >2.5**. None is an actual matched counterfactual. Pairing old observations to obtain a pass is not B.
3. Paired collection can attenuate a slowly changing common host factor without excluding the background workload. It cannot guarantee cancellation across 12–27 s sessions, a late browser step at different offsets, size-induced heating or two contaminated pairs. The added datum is not a validation of three pairs' detection power or whole-suite reliability.

My F88 *methodological* preference survives: B is the strongest of A–D for learning a comparable-growth relationship. My *next-step* recommendation now respects the explicit rejection: **do not implement B or treat reconsideration as necessary consent.** If the user wants to reopen it, first predeclare a focused pilot (exclusions + deep, plus wide as a near-limit control), then the separate grading-check unit + unchanged failure guards + full B8. No guaranteed green. A scheduler-only interleaving pilot can keep the minimum statistic for diagnosis, but it is still a new experiment/protocol decision, not permission implicit in “Keep fastest of 3.”

Knowledge lens: NIST randomized-block guidance states **“The basic concept is to create homogeneous blocks in which the nuisance factors are held constant and the factor of interest is allowed to vary.”** <https://www.itl.nist.gov/div898/handbook/pri/section3/pri332.htm> (full retained text `.scratch/scientist-2/sources-nist/text.txt`). This supports matching; it also names the assumption the current logs cannot confirm. Python's `timeit` note says **“In a typical case, the lowest value gives a lower bound for how fast your machine can run the given code snippet”** and attributes higher values typically to interfering processes: <https://docs.python.org/3/library/timeit.html> (full text `sources-timeit/text.txt` in the same scratch directory). That motivates minima for a lower-envelope estimand; it does not guarantee two separate triples observed the same lower-envelope conditions. These are methodological analogies, not authorities that override the user's chosen contract.

## U5 — C: an honest deferral, not an inferred pass

### Supported acceptance limbs

In l, deep at cap has served-details **.870/.868/.922 s**, page-details **.627/.739/.836 s**, all individual samples <1 s (l:150–151,165–166); the ruled minima are .868/.627. F81's time-bound limb is supported in this run. Every graded export minimum at cap is ≤**5.54 s**, a **4.46 s** margin below 10 s at the maximum (outcomes, l:684); F82's time-bound limb is supported. These are benchmark observations on specified shapes/host, not formal runtime guarantees or universal “under load” claims.

F81 additionally requires byte parity + retained proof; F82 requires exported-page parity (`.agent/review.md:308–309`). The ledger records earlier evidence; this appraisal does not rerun those checks or certify a future closing tree. Taking the absolute limbs separately is valid if stated separately. It does not make the full B8 command pass: l:999 explicitly reports **one bound exceeded**.

### Required correction to C

1. **User scope decision:** “Close the code review with B8 timing acceptance still outstanding and recorded as deferred,” rather than “growth choice blocked on the user.” The user has already chosen fastest-of-3. Deferral/closure is the new decision; until it is made, the original finish line remains in force. The review body's `Met when` permits findings blocked on the user as deferred rows, but this must not manufacture an unresolved choice out of a settled ruling.
2. **Durable state:** one entry may consolidate the unfinished B8 acceptance and F87–F89's sampling/cause questions, retaining all red witnesses and accepted limits. Keep **F83's implemented statistic** and **F86's fixed start interval** distinguishable from their outstanding whole-run acceptance; grouping them must not relabel fixed code as unfixed or silently mark the statistical issue resolved.
3. **Claim boundary:** “The absolute details/export limits were met in the named measurements. The full timing acceptance has not passed; GUI growth remains unresolved.” No “all gates green,” “performance bounds verified,” or “noise alone caused the failures.” Product interaction with legitimate background work remains possible.
4. **Restoration check:** under the still-current method, a complete `bash tools/scale.sh --assert` at the relevant committed state with every bound satisfied; preserve every prior red. Any future protocol amendment requires the user's ruling + its own unit + planted breaches still firing. A deferred row should not merely say “rerun until green.”
5. **Closing gate:** the separate full gate must still pass on a clean tree at the closing commit. No closing gate was run or verified in this appraisal. The current draft archive's `PENDING` B8 row cannot become “pass” by wording alone (`.agent/archive/maintain-code-review.md:23`).

Corrected C preserves the scientifically supported absolute results and makes the remaining uncertainty explicit. Its acceptability as a product/review milestone is the user's scope decision, not something the numbers prove. If that limited closure is unacceptable, keep the review open; do not replace the missing witness with an attractive summary.

## U6 — D: what pooling actually says

Independent raw-wall recomputation, normalized per doubling (not the supplied helper's two-decimal ratios):

| Epochs included | Largest per-row median of run ratios | Row | Does this descriptive summary exceed 2.5? |
|---|---:|---|---|
| g/h/k/l | **2.389599** | deep `gui:served:details` | No |
| h/k/l | **2.431373** | same | No |
| k/l | **2.567860** | same | **Yes** |

For deep the run ratios are **2.311978, 2.347826, 2.704348, 2.431373**. With four observations, the reported median averages the two middle ratios; with three, it chooses the middle; neither is an upper bound on any individual run, a confidence bound, or the current min/min grade. Pooling cannot undo each full run's failure.

Like-for-like limits:
- g used the older served-first start order; F86 changed it. That does not invalidate every other g row, but excludes treating the full g vector as generated by the current protocol.
- h has the new start order but no host sampler; k/l include the sampler. Its overhead/state influence is not quantified away by common native SHA. Actual runtime/browser identities and external load histories remain additional variation.
- `git diff 1738cbf a15ddfc` on scale scripts, product GUI/Lean sources + Node/package pins shows **no changes**; positive control `e28518c..fb7490b` shows the expected one driver change (`tools/scale-gui.mjs`). Thus k/l are the closest source-protocol pair in these four logs, yet their deep median remains **2.56786**. This is a sensitivity check, not a claim that only two runs are scientifically valid. Selecting whichever epoch set gives green is precisely the problem.

D supports the narrow historical statement **“each row's median across these chosen 3 or 4 observed runs is below 2.5.”** It does not establish all runs below 2.5, comparable-state growth below 2.5, the next run's outcome, or a bound on the population median/tail. Three or four heterogeneous epochs give weak uncertainty information, particularly over 207 rows.

A prospectively fixed between-run aggregate could be a legitimate *different* acceptance contract if its estimand, run count, inclusion/protocol rules, failure handling and detection of planted regressions were justified before grading new data. Here the rule and grouping are proposed **after four reds and after a minimum ruling was reaffirmed**. Adopting them to close this same check is a grading-rule change selected on its result, not independent evidence the original check errs. Reject D as current acceptance; retain its descriptive numbers with scope.

## U7 — next decision + ranked information value

**Primary next decision: corrected C.** It honors the settled statistic and the requirement to bring each failure back, acknowledges the absolute fixes' evidence, and refuses to invent a green performance claim. The empirical conclusion is limited; the user's decision determines whether that limited conclusion is enough to close this review. Science does not uniquely dictate a release milestone or budget, but it does rule out claiming B8 passed on these data.

For a user who instead requires resolving the growth claim now, the highest-information work is not another untargeted attempt:
1. **Target the mechanism with the same fixed binary/browser:** prespecified exclusions + deep sessions, size order controlled/counterbalanced, phase-level engine/receive/render timings + existing host log. Keep the minimum-based acceptance separate from diagnostics; all results retained, no hot/slow discard, no background-job removal. This distinguishes a changing host window from size-induced browser work better than a fifth full suite. It requires the user's decision; not run here.
2. **Only if reconsidered, test B prospectively.** Keep fixed pair counts, all error/timeout precedence, bounds and shape coverage; pilot estimates residual order/state dependence before any claim about superior reliability. Data now strengthen matching, not certainty about a particular median.
3. **A, if the user explicitly wants another unchanged operational attempt.** Describe its outcome as one run, preserve all four earlier failures, make no pass-probability promise. No in-run extra samples or automatic retries.
4. **D for descriptive history only.** It cannot replace acceptance; the k/l sensitivity already demonstrates why the apparently reassuring maximum depends on epoch choice.

Rivals + decisive observations: host-confounding lead → ratio tracks exposure after size/order controlled; browser/runtime scaling → excess localizes to browser phases despite comparable host state; workload-induced power/heat → excess follows the larger workload's history rather than unrelated CPU; timer issue → event/request/answer/paint identities disagree. Current controls leave all but gross system memory pressure materially open. If a stable product-on-reference-host excess persists under the accepted conditions, the honest path is a product fix or an explicit contract change, not relabeling legitimate background load as invalid.

## Checks, source limits, reproduction

Requested seed positive control = **8 matching lines / 15 cells**, observed 8 / 15 (rc 0). Final seed-token validator = no output, rc 1; **7/7 anchored verdict rows**, filled recommendation + marker-last assertions pass, rc 0.

Copied supplied helpers into the permitted scratch directory, then executed the copies; each `cmp` = rc 0. Commands used:

```sh
python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/f89-ratios.py /home/eturkes/Projects/fvtrace/.scratch/bench/b8g-1.log /home/eturkes/Projects/fvtrace/.scratch/bench/b8h/b8g-1.log /home/eturkes/Projects/fvtrace/.scratch/bench/b8k/b8g-1.log /home/eturkes/Projects/fvtrace/.scratch/bench/b8l/b8g-1.log
python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/f89-pooled.py /home/eturkes/Projects/fvtrace/.scratch/bench/b8g-1.log /home/eturkes/Projects/fvtrace/.scratch/bench/b8h/b8g-1.log /home/eturkes/Projects/fvtrace/.scratch/bench/b8k/b8g-1.log /home/eturkes/Projects/fvtrace/.scratch/bench/b8l/b8g-1.log
python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/f89-sess.py /home/eturkes/Projects/fvtrace/.scratch/bench/b8l/b8g-1.log exclusions gui:page:whatif
python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/f89.py
```

Each observed rc = **0**; full outputs retained as `.scratch/scientist-2/f89-{ratios,pooled,sess}.txt` + `f89.txt`. Independent script recomputes exact ratios, threshold deltas, all 6 pair permutations, pooled subset sensitivity, absolute-bound witnesses, illustrative probabilities, and host summaries at exact/±1 s windows. Controls: **586 successful numeric rows + 207 graded pairs in each of four complete logs**, matching native SHA `a991edbad3212be9865b098201bbfacd628d6bbbef1420b12262ea5e7b8ea75f`; exact exceedances **4/828** agree with four literal FAIL lines; l host = **3729 samples, 716 repetition intervals, 588 GUI phase intervals**, six page-what-if phases found for each exclusions/wide shape. All log lines parsed; relevant target/host intervals manually inspected. No cap on parsed rows or pagination; g's interval change + h's absent telemetry retained as comparability limits. Partial i excluded from full-run frequencies, not counted green.

The supplied pooled helper reads rounded printed ratios; independent arithmetic supplies the decision numbers. The supplied session helper falls back to a whole session if a requested phase is absent; independent parser verifies all requested phase marks instead. No current helper failure affected these results. No timing run, functional gate, byte-parity test or browser was executed. Product causal attribution, future false-red/pass rates, exact browser/runtime equivalence and future closing-tree checks remain unconfirmed; where the logs do not contain them, no estimate substitutes for measurement.

scientist-2-DONE-2
