# scientist-2 — F88 + growth-grader appraisal

**Recommendation: (e), three counterbalanced pairs of whole runs, wall growth = median of the three within-pair ratios. Keep fastest-of-3 for absolute times + the existing RSS/bytes checks; keep every failure.** This addresses time-window confounding + a single extreme ratio without dropping GUI growth coverage or adding repetitions. It requires a new user ruling: F83 explicitly selected fastest-of-3 over median-of-3. Recommend the design, **not a promised green or a calibrated false-red rate**. Pilot it before spending another full run on an untested statistical assumption.

F88's arithmetic is sound; its exclusive attribution to the statistic is not established. The 0.345 s half-size measurement may be a genuinely less-contended run. The full browser path is not bounded by its standalone server/Node controls. Changing all rows to medians would introduce other reds in every completed modern log; “median fixes B8” is false as a retrospective arithmetic claim.

Scope = logs + source + local recomputation; no timing runs, builds, browsers, offload or nixbox access. Only this validator input + `.scratch/scientist-2/` written; unstaged; MAIN commits. Paths below relative to `/home/eturkes/Projects/fvtrace` unless absolute. Findings keyed T1–T6.

| id | claim | verdict | evidence (numbers + file:line or log line) |
|---|---|---|---|
| T1 | F88 = class `gate` (the statistic, not the product): the path grows 1.86–2.11 (server, page engine) while fastest-of-3 reads 2.70 | overstated | F88 = 0.933/0.345 = **2.70435**, median ratio **1.89940**; standalone server **1.86207**, Node page engine **2.11364** (`.scratch/bench/b8k/b8g-1.log:124–137,151–154`). Gate-design weakness supported; exclusion of browser/runtime scaling not supported. Fast half-size session also has much less recorded competing CPU (T6). |
| T2 | (a) interleaving alone would have prevented F88 | unsupported | Reordering the same six walls leaves min/min **2.70435** exactly. Interleaving can change which host states each size encounters; no observed counterfactual establishes prevention. Existing b8d tests experiments, not deep. |
| T3 | (b)/(c) median-based grading keeps detection of a true 3× regression at 3 runs | overstated | Conditional, centered-noise model: median-of-3 detection on F88's row **80.8–100%**, F87's row **100%**; worst modeled row **54.9%**. Neither min nor median guarantees detection. Applying medians to recorded GUI walls removes their three reds, but creates other timing reds (T3). |
| T4 | false-red rate per full run: current vs each candidate | open | Actual rate not identifiable: **3 completed modern runs, all red, + 1 partial**, not four full runs; no known-truth noise-free baseline. Under an explicit size-specific empirical-noise model, full-family false-red rates span **48–79% current**, **74–87% median-3**, **68–81% paired-median-3**. Pooling noise across sizes reverses parts of the ranking. These are sensitivity calculations, not host forecasts (T4). |
| T5 | recommended option + why; what the F83 ruling (fastest of 3) rested on and whether the recommendation keeps it | supported | Recommend **(e), three pairs**, for growth; same attempt count, local matching + one-ratio resistance, all bounds/rows retained. F83 addressed observed ×1.32–1.36 timing spread; its user chose minimum over MAIN's median recommendation (`git show -s 3274786`, `.agent/review.md:310`). Proposed growth statistic **supersedes** that part, preserves absolute minima. |
| T6 | rival explanations for F88 not yet excluded + the cheapest discriminating test | open | Host probe: fast half-size session top-listed Python CPU mean **0.325 cores**, other half sessions **1.112/1.179**, cap **1.362/1.610/1.569**; no sampler tick inside the 0.345 s event's wrapper. New evidence favors mismatched host windows but does not identify the sub-second cause. Next: fixed paired deep + experiments pilot with phase breakdown, not another undiagnosed full run. |

## T1 — what the evidence actually carries

### Recomputed measurements

L = N_cap/2; H = N_cap. Ratios below use the harness's `exp(log(H/L time) × log(2)/log(n_H/n_L))`, not rounded print values. Deep is an exact doubling.

| Log / run | Deep served details: L walls (s) | H walls (s) | min/min | median/median |
|---|---|---|---:|---:|
| g, e28518c | .359, .523, .589 | .830, .906, .945 | 2.31198 | 1.73231 |
| h, fb7490b | .377, .483, .345 | .810, .837, 1.027 | 2.34783 | 2.22016 |
| i, 1738cbf, partial | .565, .406, .515 | .900, .916, .910 | 2.21675 | 1.76699 |
| k, 1738cbf, F88 | .345, .497, .576 | .933, .970, .944 | **2.70435** | **1.89940** |

Sources: g `.scratch/bench/b8g-1.log:152–153`; h `.scratch/bench/b8h/b8g-1.log:151–152`; i `.scratch/bench/b8i/b8g-1.log:151–152`; k `.scratch/bench/b8k/b8g-1.log:151–152`. All four print native binary SHA-256 `a991edbad3212be9865b098201bbfacd628d6bbbef1420b12262ea5e7b8ea75f` at line 4. Same native bytes exclude a newly changed native binary, not browser variation, latent path sensitivity, input/session history or environment changes.

F88's L minimum is 30.6% below its median; H minimum only 1.2% below its median. H's full range = 4.0%. This asymmetric selection magnifies growth. But .345 also occurs in h, and .359 in g: “the fast member of this triple” is established; “an invalid/statistical outlier” is not. Three observations cannot diagnose a tail distribution.

Controls in k: `serve:details:claim` .29→.54 = 1.862; `page:details:claim` .44→.93 = 2.114; `gui:page:details` .454→.867 = 1.910. These are useful rival checks, **not components that sum to or upper-bound `gui:served:details`**. Node page engine ≠ Chromium Worker; standalone server excludes concurrent browser work, network response consumption + rendering. GUI deep reselects its sole claim; the complete click→ready→paint interval includes more work than the standalone timing.

Static check of the obvious stale-answer rival: `scale-gui.mjs:73–129` requires the click's pending→ready transition; `:245–263` waits for the preceding request to stop being busy; `web/app.js:424–430` brackets each request with busy, `:707–756` numbers detail requests. This rules out the *old, known stale-ready predicate* as the current source-level mechanism; it does not prove every runtime interval correct. No new harness defect was reproduced here.

**Ruling:** `gate` is defensible as the recorded *sampling-design finding*. Amend its explanatory strength: size/window confounding + asymmetric order-statistic sensitivity are present; the red is not yet proved to be exclusively external noise. Do not erase F88 or claim the GUI meets its current growth contract because its components or medians pass.

## T2 — scheduling and aggregation solve different problems

Current schedule = LLLHHH for each command or whole session (`tools/scale.sh:168–183,238–280`). Minimum uses one observation from each size independently (`:82–94`); more samples do not create environmental matching.

Use LH | HL | LH, alternating the initial order by a predefined shape/batch schedule. Three pairs cannot balance LH/HL exactly within one row; counterbalance the extra order across batches. Keep whole fresh sessions + all their steps; do not splice steps between live sessions. No cross-size concurrent timing.

| Candidate | F88: one fast denominator member | F87: a whole slow size window | Principal limitation |
|---|---|---|---|
| Current minimum-3, grouped | Vulnerable | Vulnerable | Independent extrema + size/time confounding |
| (a) Interleave, minimum-3 | **No statistical protection**; may expose H to the same quiet window | Reduces slow drift confounding | A lone L minimum still decides the ratio; arbitrary drift/carryover remain |
| (b) Grouped median-3 | Resists one exceptional member | **No** if ≥2 H observations share the slow window | Changes estimand, leaves design confounded |
| (c) Interleave, median-3 | Resists one exceptional member | Reduces window confounding | Separately selected marginal medians are not matched contrasts |
| (d) Interleave, five per size | Median helps; minimum can worsen asymmetric fast-tail selection | More temporal coverage, not guaranteed balance | +67% repetitions; five grouped-like slow H states still biased; changed thermal history |
| (e) Interleave, median of three pair ratios | One extreme ratio cannot alone determine median | Common multiplicative block cost cancels **if sufficiently stable within pair** | Residual between-pairing delay, size-dependent heat/GC, two contaminated pairs |
| (f) GUI absolute bounds only | Removes this kind of failure by removing its check | Same | Loses GUI scaling coverage; not an equal-strength repair |

In the model `T(n,r)=W(n)×C_r×E(n,r)`, a pair ratio cancels C_r. Grouped L/H do not observe a shared C_r. Interleaving makes a common C_r more plausible; it does not prove it. GUI sessions last about 15–34 s on deep, and a late page step has different offsets within L/H sessions, so even adjacent whole sessions may meet different states. Heat *caused by H's work* is part of workload performance, not automatically a nuisance to remove.

Counterfactual limits: b8d alternated drivers/sizes on experiments. Its new-driver page what-if min ratio = 1.959, median ratio = 1.983, median batch ratio = 1.993 (4 batches; `.scratch/bench/b8d-1.log:29,55,68,94,120,146,185,211`). This weakens a large consistent driver-carryover explanation there; it neither establishes equivalence nor validates deep's sampling distribution. Reordering k's fixed six numbers leaves the current ratio unchanged. With those numbers, any one-to-one pairing yields a median in **1.877–1.952**; that is arithmetic sensitivity, not an interleaved measurement.

## T3 — detection, changed estimands, and displaced reds

### Historical arithmetic is not validation of the replacement

All 83 GUI growth rows in each completed modern log pass on median-of-3; GUI absolute medians also stay within their bounds. But a global median change produces:

| Log | New non-GUI growth failures, median/median |
|---|---|
| g | wide `gaps` **2.5338** (`:28–29`) |
| h | deep `check` **2.6400** (`:94–95`) |
| k | wide `check` **2.5066** (`:7–8`); outcomes `serve:details:claim` **2.9374** (`:693–694`); outcomes `serve:action` **2.6190** (`:699–700`) |

Ordinally pairing existing grouped samples is **not actual matched pairing**. That sensitivity gives h deep check 2.64; k the three rows above + outcomes `serve:details:experiment` 2.5666. Thus neither an all-green GUI retrospective nor a single target-row green justifies “the new method fixes the suite.” Selecting a rule because it greens these discovered failures would overfit the grader.

### Conditional power, not a guarantee

T4's simulation assigns each row **true central growth 3× per doubling**, holds its empirical relative spread fixed, then counts detection of **that row**, not a red elsewhere. No product mutation was timed. All-row means average heterogeneous rows uniformly, not the distribution of future defects.

| Statistic | Mean detection across 414 row×epoch cases (h+k; 207 rows each) | Worst row | Deep served-details detection, g/h/k | Experiments page-what-if, g/h/k |
|---|---:|---:|---|---|
| Minimum-3; current/(a) under order-free model | 97.2% | **28.5%** | 97.4 / 96.4 / 100% | 100 / 100 / 100% |
| Median-3; (b)/(c) | 96.9% | **54.9%** | 93.3 / 80.8 / 100% | 100 / 100 / 100% |
| Minimum-5; (d) | 97.2% | **13.1%** | 99.6 / 99.6 / 100% | 100 / 100 / 100% |
| Median-5; (d) | 97.5% | **62.4%** | 95.6 / 83.4 / 100% | 100 / 100 / 100% |
| Median paired ratio, 3; (e), independent residual model | 97.4% | **41.7%** | 96.6 / 87.4 / 100% | 100 / 100 / 100% |

Worst case here = prereqs `gui:served:details`; other weak minimum cases are frame-scale select/busy intervals. A 3× central change is not necessarily a 3× lower-tail change when relative distributions differ by size. This is why minimum and median powers differ even with an unchanged threshold. “Keep power” needs the estimand named: lower-envelope throughput, median experienced latency, or matched growth are different claims.

For (f), there is **0% growth-check detection** by construction. Absolute bounds sometimes rescue it: in this model, deep served details detects 3× with 100%, experiments page what-if with 0%. Across 83 GUI rows, average absolute-only detection = **9.1–10.2%**, with **69–70 rows at 0%**. A client-only quadratic scan taking .15→.60 s for details, or .5→2 s for a first view, passes the absolute bound while CLI/Node rows remain linear. Thus (f) misses exactly the regressions a GUI growth check owns.

## T4 — estimated rates, assumptions, and why no host forecast is justified

### Data units + coverage

Full modern logs g/h/k each contain 586 successful numeric rows across all shapes; 207 positive paired timing rows on the seven graded shapes, of which 83 are GUI. i contains 325 successful numeric rows, 120 paired graded rows / 46 GUI pairs; it stops before all graded shapes. F86's g first-view protocol differs. For the primary current-driver rate comparison use **h and k** (83 GUI + 124 other pairs each). g informs unchanged-row spread + sensitivity only; exclude its served-first rows from its bootstrap.

The observed record is **3/3 completed runs red**, with different failed GUI rows; i is censored, not a green full run. Excluding the older first-view protocol leaves 2/2 completed current-driver runs red. Neither proportion estimates a *false*-red rate: the causal status of each red and the long-run noise distribution are not established. Older r/f1/f2 are single-sample runs, with changed product bytes; they substantiate F83's motivation but cannot supply three-run resampling blocks for the current product.

### Reproducible empirical-noise model

1. For each timing row, define central growth G as the median across available modern runs of that row's median/median ratio. Exclude g for served-first; use i only where complete pairs exist. Every resulting G is below 2.5; this is a **model assignment**, not proof of true growth.
2. Within each source epoch h or k, divide each size's three walls by that size's median. These two three-point distributions become size-specific multiplicative noise. This preserves the observed asymmetric spread but removes between-size median shifts.
3. Assign synthetic H/L central growth G; redraw r observations with replacement from each size's three residuals. Preserve each GUI/serve/page session's cross-row dependence by using one draw index for all its steps. CLI commands are separate families. Enumerate every **3^(2r)** ordered redraw: 729 for r=3, 59,049 for r=5.
4. Family false-red = any ratio >2.5. Combine independent families as `1−∏(1−p_family)`. This assumes independence across shapes/command families, exchangeability inside triples, stationary future noise, no unobserved tails, no new order/thermal effect, and fixed G. None is demonstrated by three measurements. No RSS, bytes, missing-row, exit-code or absolute-bound uncertainty is modeled.
5. For power replace G by 3. Pair-ratio calculations under this model use independent residuals; **no interleaving benefit is invented**. Existing grouped logs cannot identify a paired correlation or cancellation rate. Consequently (a) = current and (b) = (c) in this order-free model.

| Candidate / wall-growth statistic | Model false-red per full 207-row timing family, h–k span | GUI 83-row contribution alone, h–k span | Added runtime |
|---|---:|---:|---|
| Current / (a), minimum-3 | **48.2–79.0%** | 8.7–74.6% | Current ≈64 min; (a) same attempts |
| (b)/(c), median-3 | **74.4–87.3%** | 35.5–64.2% | Same attempts |
| (d), minimum-5 | **23.4–87.4%** | 1.1–87.1% | All repetitions: ≈105–107 min total, +41–43 min |
| (d), median-5 | **65.2–79.5%** | 27.8–54.6% | Same +41–43 min |
| (e), median of 3 pair ratios | **68.5–81.5%** | 30.9–56.9% | Same attempts |
| (f), no GUI growth; other rows minimum-3 | **17.5–43.3%** | 0%, because removed | No saving if absolute GUI checks retained |

**These large percentages are not predictions for nixbox.** They show that a fitted three-point model can make many near-bound rows fail; they do not identify which method has the smallest real false-red rate. Literal resampling of the *un-centered* current walls instead gives full-family exceedance probabilities ≈92–93% minimum-3, ≈98–99% median-3, ≈97–98% paired-3: conditional re-selection instability, not false-red estimates. They inherit each epoch's size-window shift.

A different plausible assumption changes the answer sharply. Pool L/H median-normalized session residuals into one six-point distribution and draw both sizes from it (20,000 draws/shape, seed 88123): GUI false-red contribution becomes **5.0–26.5% minimum-3**, **16.9–24.5% median-3**, **10.4–16.5% paired-3**; at five: **0.7–24.1% minimum**, **9.1–11.9% median**, **3.4–5.9% paired**. Pooling assumes equal relative noise by size and removes the very asymmetry at issue in F88; neither pooling nor retaining it is identified as the future truth. Monte Carlo error is small beside this structural uncertainty. Likewise, perfect common multiplicative pair noise would cancel exactly, yielding 0 false reds/100% 3× detection absent residual noise; treating that idealization as observed would be unjustified.

Simple exact sensitivity at F88: under literal redraw of its triples, any occurrence of .345 among three L draws makes min/min fail → **1−(2/3)^3 = 70.37%**. At five minima it is **86.83%**. Median-3 fails when .345 occupies at least two draws → **25.93%**; median-5 requires three → **20.99%**. This establishes that “more minimum samples always stabilizes growth” is false under size-asymmetric noise. It does not establish the population probability of .345 or that it is erroneous.

Multiplicity matters: 83 GUI growth opportunities + 124 other modeled timing opportunities, plus absolute/non-time checks outside this calculation. Even an independent per-row error probability .01 gives `1−.99^83 = 56.6%` for the GUI family. This is an illustration, not a fitted common p. A single-row success does not calibrate the suite. Correlated load can also cluster failures, so the independence product is a model assumption, not a theorem about this host.

Runtime extrapolation: k's host marks total **3720.878 s** in repeated invocations, including **2106.188 s GUI** (`host.py` output). All rows 3→5 adds ≈2480.6 s (41.3 min) if cost stays linear in count; using the brief's 64 min total gives ≈105–107 min including fixed work. GUI-only 3→5 adds ≈1404.1 s (23.4 min), total ≈87 min. Interleaving changes cache/thermal history, so no exact runtime promise.

## T5 — recommendation, F83, and established methodological knowledge

### Recommended ruling

Choose **(e) for wall growth**, three whole-run pairs per size/command or session. Calculate every pair's per-doubling ratio, then its median; keep the same 2.5 bound, graded rows/shapes, input caps, and fail-closed behavior. Keep per-size fastest-of-3 for absolute times and retain current RSS/bytes checks: this appraisal does not calibrate alternative memory/bytes statistics. Print all walls + pair identities + ratios + final growth statistic so the two different estimands remain explicit.

Reason: matching addresses the known size/time confounding; median of matched contrasts addresses a one-pair extreme. No extra run cost, no dropped GUI detection, no thermal exclusion. It is a principled design improvement that does not depend on declaring .345 invalid. **No claim that it beats current minimum in every modeled noise regime, or that three pairs are enough for a reliable whole-suite error rate.** T4 does not establish that. A higher-run option should follow evidence about residual paired spread, not a desire for another minimum.

F83's source evidence: same-tree ratio flips + same-binary GUI spread ×1.32 and unchanged-path spread up to ×1.36 (`.agent/review.md:310`, commit `3274786`). User selected “fastest of 3” over MAIN's recommended median; no evidence in that record establishes its ratio as a statistically calibrated estimator under size-specific tails or grouped windows. The proposed hybrid **keeps F83's absolute-time rule but changes its growth rule**. Seek that explicit amendment; do not present it as merely reordering F83's existing calculation. Changing all absolute times to medians is a separate, unrequested strengthening and could reverse F81 acceptance near 1 s.

Calibration plan before another full B8: predeclare a small fixed paired pilot on deep + experiments, plus outcomes served details (near-bound control). Retain all observations; report pair differences, order sensitivity and uncertainty. Three pairs suffice to exercise the protocol; more independent fixed batches are needed to estimate rare full-family errors. A historical green after changing the statistic does not count as a new timing pass. Once the user rules the method and its implementation/probes are green, one full acceptance run under that protocol decides acceptance; any red remains recorded + classified, not an invitation to harvest a lower minimum.

### Knowledge lens — source fit, not authority by analogy

- Python `timeit` docs, `Timer.repeat` note: **“In a typical case, the lowest value gives a lower bound for how fast your machine can run the given code snippet; higher values in the result vector are typically not caused by variability in Python’s speed, but by other processes interfering with your timing accuracy.”** Source: <https://docs.python.org/3/library/timeit.html>, full extracted text `.scratch/scientist-2/sources-timeit/text.txt`. This supports minima for a *lower-envelope snippet time under mostly delay noise*. It does not guarantee the ratio of two finite minima sees the same quiet state, nor that end-to-end browser latency should estimate that envelope. The same page says GC may be an important component of the function's performance; do not remove workload-induced GC/heat by default.
- NIST/SEMATECH, randomized block designs: **“The basic concept is to create homogeneous blocks in which the nuisance factors are held constant and the factor of interest is allowed to vary.”** Also **“Block what you can, randomize what you cannot.”** Source: <https://www.itl.nist.gov/div898/handbook/pri/section3/pri332.htm>, full extracted text `.scratch/scientist-2/sources-nist/text.txt`. This supports matched size blocks rather than LLLHHH. It also names the assumption we cannot verify: adjacent sessions must be sufficiently homogeneous. Counterbalancing alone does not create that homogeneity.
- Order-statistic + multiplicity results above are direct arithmetic, reproduced by the scripts; no borrowed numerical claim. Median-of-three resists a single extreme member but has only one observation of protection; it supplies no confidence level by itself. A future inferential pass/uncertain/fail rule would require a separate contract decision, not hidden error bars that turn reds green.

## T6 — rivals, telemetry corrections, highest-information next work

### Targeted factual probe

Read every k host-log line, associate marks with six deep GUI sessions, summarize samples inside each session. Python CPU below = sum of Python entries in the **three busiest recorded processes**, averaged across samples; a lower bound on all Python CPU, not an exact host-total attribution.

| Deep GUI session | Recorded details (s) | Listed Python mean (cores) | Busy CPUs mean | Busy-weighted instantaneous MHz mean | Zero package-throttle samples / samples |
|---|---:|---:|---:|---:|---:|
| L1 | .345 | **.325** | 1.82 | 3359 | 0 / 15 |
| L2 | .497 | 1.112 | 2.94 | 3369 | 0 / 16 |
| L3 | .576 | 1.179 | 2.95 | 3167 | 0 / 17 |
| H1 | .933 | 1.362 | 3.34 | 2945 | 18 / 32 |
| H2 | .970 | 1.610 | 3.73 | 3002 | 28 / 34 |
| H3 | .944 | 1.569 | 3.73 | 3001 | 27 / 34 |

Sources: `.scratch/bench/b8k/b8g-1.log:2012–2279`, exact summaries `.scratch/scientist-2/host.txt:3–8`. L1's whole session has less competing CPU; other compute-heavy steps are also relatively fast. This strengthens a host-window explanation and weakens calling the denominator a spurious timer reading. A lower-contention measurement can be valid and still be mismatched to all H measurements.

MAIN's follow-up uses session start→end+1 s rather than this table's start→end. Independent arithmetic rematch (`.scratch/scientist-2/rematch.py`, rc 0; output `rematch.txt`) confirms all six summaries within reporting precision: L Python means **.3150 / 1.1306 / 1.1878 CPU**, H **1.3794 / 1.6094 / 1.5837**; positive-throttle counts L **16/16, 17/17, 18/18**, H **14/33, 6/35, 7/35**; mean MHz **3354 / 3359 / 3144 / 2938 / 3005 / 3004**. The differing boundary convention explains the small numerical differences, not a disagreement. The extra tick can partly cover the next session; neither convention localizes the sub-second event. This is a rematch of the same observations, not independent replication.

Implication for T1/T2: **F88 plausibly shares F87's mechanism class, mismatched host windows.** The anomaly relative to its triple may be a valid quiet-state observation. Interleaving (a) therefore has a concrete F88-specific rationale too, not merely an F87 rationale. Prevention remains unconfirmed; these logs do not establish that median aggregation is necessary or superior once interleaving aligns exposure. Recommendation (e) remains a matched-contrast design choice, not a conclusion that this telemetry proves the minimum statistic wrong.

Requested analogous host rematches for g's wide first view + h's experiments page what-if are **unavailable in the supplied logs**: all 1,066 g lines and 1,154 h lines contain zero host sample lines, zero host marks and zero host-log sections. Positive control k = 3,752 sample lines (`rg` rc 0); g/h sample queries emit nothing, rc 1; parser counts agree. Their timing/phase observations remain usable, but a retrospective contemporaneous host-state attribution cannot be reconstructed from them.

Corrections for MAIN to rule in F88/spec:
- g/h/k = **three completed runs + i partial**, not “four full runs.” i has no final performance verdict; later graded shapes were not covered.
- Deep's six-session window has **148 host samples, 73 with zero package throttle events**, package **89–100 °C**, busy-weighted instantaneous frequency **1795–4260 MHz**, and listed Python aggregate **13–217% of one CPU**. Thus “thermal throttle events in every 1 s sample” + “foreign python 15–60%” do not describe the full deep window. Individual cap Python entries approach 100% too.
- All deep samples show zero swap activity + memory-pressure stall, available memory ≥56,121 MiB. This weakens gross system memory-pressure/swapping, not Chromium GC or local allocation stalls.
- `scale-host.mjs` reads instantaneous `scaling_cur_freq` weighted by busy share, not an APERF/MPERF effective-service measurement. Package throttle counts are events, not lost seconds. Fewer cap throttle events while cap is slower are compatible with lower sustained frequency or changed competing work; not proof against heat/power effects.
- L1 details wrapper marks are at `11:28:08.106–11:28:08.639` UTC (`:2020–2021`), **no sampler tick inside**. Bracketing ticks show 3454/4260 MHz, CPU-pressure 163/99 ms, different top processes. Wrapper duration .533 s includes Playwright click preparation; graded .345 s starts at the event. Do not substitute wrapper duration or assign a 1 s host reading exactly to the click.

| Live explanation | Fit to current evidence | Cheapest separating observation |
|---|---|---|
| Quiet L1 vs busier H window | Strongest new lead: CPU contrast above; group scheduling confounds size/time | Counterbalanced size pairs; per-pair state overlap + ratio/order relation, all samples retained |
| Size-dependent browser work, GC/JIT/cache boundary | Standalone engine controls omit browser phases; H spread can be stable at a real threshold | Same paired deep sessions with request/response, decode, render and GC phases separated; a repeatable H/L excess localized to browser work at matched host state strengthens it |
| Thermal/power restriction induced by workload | Host is hot; H has lower clocks, but throttle count alone is non-monotone with slowdown | Same phase breakdown + effective CPU service/history; distinguish prior-size carryover from H's own sustained work |
| Detail-timer/endpoint prehistory | Earlier F21 proved this class possible; current pending→ready guard + busy wait remove that specific bug | Event/pending/request/response/ready/paint timestamps + request identity in a targeted diagnostic; compare observed interval to its actual payload, no shorter surrogate |
| Browser/runtime version drift | Native binary pinned, actual Chromium/runtime identity not printed in these logs | Record exact browser/Node/driver identities before future runs; no version-equivalence claim from native SHA alone |
| System memory pressure | Current deep telemetry argues against it | Existing zero swap/pressure + ample available memory already separate gross pressure; browser-local memory behavior still needs phase evidence |

Next analyses/experiments ranked by information value:
1. **Fixed targeted paired pilot, not full B8 first.** Deep + experiments + outcomes serve-details; browser/runtime pinned, counterbalanced order, all phase marks + existing host telemetry; no thermal settle/discard rule. Compute current, marginal-median and paired-median statistics descriptively on the same prespecified data, without selecting a winner by whether this one batch passes. Check pair-state comparability and residual spread.
2. **Localize deep's served interval** in that pilot (response wait vs consumption/render; one diagnostic instrumented run's overhead reported). This directly separates remaining product/browser scaling from unmatched service speed. Existing telemetry cannot do it at .345 s resolution.
3. **Validate grader mechanics independently:** exact pair membership/count, scaled doubling, odd-count median, failures/timeout/missing wall outranking every success; a true planted >2.5 ratio still fires. Preserve F21's pending→ready and F86's browser-before-server interval. No retrospective acceptance from this arithmetic.
4. **Estimate whole-suite reliability only from independent future batches** after the protocol is fixed, including reds and interrupted coverage. Three source epochs cannot calibrate a small full-family false-red probability. If adequate reliability needs materially more measurement, a predeclared uncertainty/confirmation policy is a user-level contract choice; no ad-hoc retries.

Implication: this is not merely a choice of minimum versus median. The scientific object is **growth under comparable conditions**, while the current procedure compares two small, differently exposed groups. Matching improves the experiment; robust aggregation limits one-observation leverage; neither supplies absent causal identification or a reliable population error rate. Absolute UX bounds and scaling guards protect different failure modes, so dropping GUI growth is not an equivalent fix.

## Reproduction + checks

All paths absolute in these commands; outputs retained beside the scripts. Python scripts use `-I`; no project code executes a timing workload.

```sh
python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/analyze.py > /home/eturkes/Projects/fvtrace/.scratch/scientist-2/summary.txt
OPENBLAS_NUM_THREADS=1 python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/analyze.py --bootstrap > /home/eturkes/Projects/fvtrace/.scratch/scientist-2/bootstrap.txt
OPENBLAS_NUM_THREADS=1 python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/extra.py > /home/eturkes/Projects/fvtrace/.scratch/scientist-2/extra.txt
python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/host.py > /home/eturkes/Projects/fvtrace/.scratch/scientist-2/host.txt
python3 -I /home/eturkes/Projects/fvtrace/.scratch/scientist-2/rematch.py > /home/eturkes/Projects/fvtrace/.scratch/scientist-2/rematch.txt
```

Observed rc = **0 for each**. Controls: 586 successful numeric rows in each g/h/k; identical printed native SHA for g/h/i/k; 83 graded GUI pairs per completed run; i explicitly incomplete; host parser = 716 completed repetition intervals, 588 GUI step intervals, 3752 samples; diagnostic parser = 208 successful rows (16 sessions ×13 steps). `bootstrap.json` carries per-row powers + family rates; `summary.txt`, `bootstrap.txt`, `extra.txt`, `host.txt` carry numeric outputs. No acceptance timing was run. Full logs parsed; only pertinent source/log regions manually inspected, all scale scripts + prior appraisal read. Browser identities + sub-second causal phases unconfirmed where logs lack them. Old single-sample product revisions excluded from statistical resampling, F86's old first-view setup excluded where its changed interval matters. No claim of a calibrated confidence interval or a validated population false-red rate.

Seed validator positive control: expected **6 matching rows / 12 seeded cells**, observed 6 / 12, rc 0. Final seed-token grep = no output, rc 1; six anchored verdict rows + marker-last assertions pass, rc 0. An auxiliary broad `count('| T') == 6` assertion initially failed (7 hits, including a non-verdict table cell); the corrected anchored `^\| T[1-6] \|` check reads 6. Coverage control: all successful graded command keys = 207 in each g/h/k, none omitted from their paired positive-time analysis. MAIN owns all acceptance/rule/ledger changes; none made here.

scientist-2-DONE-1
