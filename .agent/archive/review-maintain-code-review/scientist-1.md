# First-view measurement appraisal

Recommendation = **(b), plus per-session timing decomposition**. Keep cold-start first-view coverage + the ruled fastest-of-3 aggregate. A warm-only replacement weakens coverage. The driver has a demonstrated uncontrolled prehistory; **that prehistory causing the original 1.689 s sample remains unconfirmed**. F86's categorical causal language exceeds the evidence.

Scope = existing logs + drivers only; no timing workloads, builds, browsers or offload jobs. Repo read-only except this validator input; unstaged; MAIN commits. Root = `/home/eturkes/Projects/fvtrace`. Findings keyed S1–S7; `open` = proposal unmeasured, not a reported failure.

| Id | Question | Verdict | Reason (numbers from the logs) |
|----|----------|---------|------|
| S1 | Does the diagnostic support "the red is the measurement (navigation lands at an uncontrolled point d inside the launch evaluation)" over "the GUI's own first-view work grows > 2.5× per doubling"? | overstated | Supports a measurement vulnerability + evidence against excessive downstream growth in these sessions: race first min ratio 2.032; warm 1.737; race/warm after-response min ratios 1.939/1.905. Does not identify the original red's cause: original d absent; diagnostic race d = 69–191 ms, original low sample 426 ms below every diagnostic race session. |
| S2 | Under the current interval, is "fastest of 3" a sound aggregate (sign of each noise source)? Does it explain 1.689 s? | unsupported | Not a correction for this changing prehistory: later navigation can lower measured time; server/page delays raise it. Original min ratio 2.6382 vs median 2.0810; +93.3 ms to the denominator alone reaches 2.5. These sensitivities establish fragility, not that d caused 1.689 s. Keep the user's aggregate after controlling start state. |
| S3 | Option (a): faithful to kernel.md's first view (navigation → painted)? What coverage does it lose or keep? | overstated | Faithful to a *warm-server* first view only: 0.467–0.725 → 0.811–1.137 s. Drops the actual launch-wait path (race wait 1.648–1.905 → 3.492–4.232 s). Separate launch ≤10 s and warm page ≤10 s do not establish cold navigation → paint ≤10 s. |
| S4 | Option (b): does it remove the offset? Residual variance sources? Risk against the 10 s bound at N_cap (use b8g-1's worst `gui:served:first` + `serve` launch rows)? | open | Removes Chromium/context/page creation from the overlap; does not make d zero. No (b) sessions yet. Among graded caps, worst individual original first = 5.398 s and worst launch = 5.720 s (both outcomes): useful headroom, not a guarantee. Adding them as 11.118 s double-counts the launch already inside first. |
| S5 | Option (c) or another design: viable? | supported | Prefer (b) + report d, pre-request, wait, transfer, after-response. (c) retains an uncontrolled denominator; recording d alone makes it diagnosable, not controlled. Diagnostic approximate spawn → paint min ratio = 1.996 vs navigation → paint 2.032; useful extra observation, not a replacement U-time metric. |
| S6 | Recommended option + the acceptance run that would confirm it (sessions, expected ratio range). | open | (b) + decomposition; focused confirmation = 3 independent three-session batches per size (18 sessions total), then full B8 at the fixed commit with the unchanged fastest-of-3 rule. Expect wide near 2×, roughly 1.8–2.2 as a forecast, not a new bound/CI. Existing race's all 100 combinations of independent 3-of-5 subsets span 1.857–2.066; (b) still needs measurement. |
| S7 | Limits of this evidence (host load ≈ 3 during the diagnostic, n of sessions, single host) + rival explanations not yet excluded. | supported | 20 sessions = 5 × 2 sizes × 2 conditions, one host, fixed order; diagnostic load 3.41 → 2.95. Original = 3 per size. No original d or response decomposition; no direct launch-completion time. Thermal/frequency/cache/order effects + server/page variance remain live rivals. No claim of universal linearity or original-cause identification follows. |

## S1 — what the diagnostic establishes

Primary evidence:
- `tools/scale-gui.mjs:284–295`: server starts, then Chromium launches; `steps` creates context + page (`:191–198`) before `first`. The interval itself starts at navigation (`:149–166`). Thus browser creation changes server age at the timed start.
- `Fvtrace/Cli.lean:1157–1180`: `IO.asTask (Server.answer …)` precedes the link/opener; `Fvtrace/Server.lean:153–154`: `answer` holds `kept.atomically`. Contract `kernel.md:146`: “a request arriving meanwhile waits for it (no second evaluation)”. This establishes the possible offset mechanism without needing a timing inference.
- `.scratch/b8g/diag-1.log:5–24`: wait consumes **76.1–81.3%** of race first (F86's “78–81%” misses the lower tail). Warm wait consumes 8.4–11.8%. `after_ms` is small and approximately doubles.

| Component, ms | Race low min / median / max | Race high min / median / max | Warm low min / median / max | Warm high min / median / max |
|---|---|---|---|---|
| d: spawn → before goto | 72 / 80 / 191 | 69 / 79 / 105 | 1854 / 1982 / 2372 | 3683 / 3803 / 4791 |
| Navigation → request (derived) | 81 / 94 / 105 | 82 / 88 / 112 | 67 / 73 / 116 | 61 / 78 / 90 |
| Request → response start | 1648 / 1761 / 1905 | 3492 / 3531 / 4232 | 41 / 47 / 71 | 81 / 85 / 128 |
| Response transfer | 52 / 59 / 73 | 84 / 96 / 120 | 53 / 55 / 68 | 80 / 89 / 111 |
| Response end → paint | 327 / 345 / 392 | 634 / 670 / 778 | 304 / 328 / 470 | 579 / 642 / 808 |
| Navigation → paint | 2115 / 2314 / 2474 | 4298 / 4370 / 5242 | 467 / 508 / 725 | 811 / 908 / 1137 |

Interpretation limits:
- `after_ms` is not all page work. It omits the pre-request work + transfer. Warm first covers those too, under a different server/browser prehistory. Neither shows >2.5× in these samples.
- Warm d is **not pure launch duration**: it includes browser launch, link delivery, an answered POST + its full body, then context/page creation (`first.mjs:23–42`). The warm intervention also gives Chromium time to settle before the page is created. Its comparison does not isolate server waiting alone.
- F86's “H-product refuted (nothing grows past 2×)” is wrong in strength and literally: race first min ratio 2.032, race wait min ratio 2.119; ordinal-paired race after ratios reach 2.113. The relevant threshold is 2.5, not 2. No repeat here shows persistent >2.5× downstream growth, but absence of that repeat does not refute every product explanation of the earlier red.
- Original 1.689 s has no d in `.scratch/bench/b8g-1.log:61–62`; do not retroactively assign it the largest d. In the diagnostic, the fastest low race has d=75 ms, while the largest d=191 ms accompanies the **slowest** low race (2474 ms). Server/page variation can dominate the offset's sign.

Suggested F86 causal wording: “The driver leaves server age at navigation uncontrolled. The diagnostic shows launch waiting dominates cold first view and finds no >2.5× growth of the measured downstream work. This makes the offset a plausible explanation of the original ratio, not an identified cause of its 1.689 s denominator.” Gate-method defect = defensible; original run proved false positive = unconfirmed.

## S2 — the aggregate's assumptions

Let A = server launch answer-ready time after spawn; d = spawn → navigation; r = navigation → API request; h = cached request/revalidation/header cost; x = body transfer; p = response end → paint. Under the observed launch-lock path:

`F ≈ r + max(0, A − d − r) + h + x + p = max(r, A − d) + h + x + p`.

While the request waits for launch, `F ≈ A − d + h + x + p`. This is a conditional model, not a fitted proof: task scheduling and request processing can change A/h; diagnostic d ends before `goto`, not exactly at browser navigation start.

Noise directions:
- Slower Chromium/context/page creation **before** navigation → larger d → smaller measured F while launch remains pending.
- Slower server work → larger A → larger F. Slower transfer/JSON decode/render/frame scheduling → larger F.
- Pre-request browser delay r can be absorbed by the launch wait; it need not add to F until launch is done.
- Host contention can delay browser and server together: net sign depends on which is delayed more. Cold caches, frequency changes and browser startup competition likewise have no fixed combined sign.

Minimum-of-3 fits an intended best-case latency only after the starting state is held fixed. For the simple model `F = fixed_work + nonnegative_delay`, it tends to suppress delays. Here it can also select the least remaining work through a late navigation. Its ratio compares independent minima, potentially at different d and different server speeds. It is neither an estimator of typical latency nor a worst-case guarantee. This does not authorize changing the ruled aggregate (`kernel.md:147`); fix the state/measurement first.

Targeted sensitivity, **not alternative acceptance** (`b8g-1.log:61–62`):
- 4.456 / 1.689, normalized to the actual n ratio = **2.6382**.
- Median ratio = **2.0810**; omitting 1.689 only for sensitivity gives **2.0393**. Neither permits discarding the sample or changing the gate to median.
- Denominator increase **93.3 ms** reaches ratio 2.5. The observed diagnostic d span (122 ms across race sessions) is large enough *in principle* to change a near-bound ruling; it does not explain the original sample's **496 ms** deficit against its other low-n runs.
- The diagnostic never reproduces 1.689: its low race minimum is 2.115, **426 ms** later. A large original d, faster original server work, different browser work, or a mixture remain possible.

## S3 — warm-only coverage

(a) keeps a real navigation → board interval, cached trace/answer validation, response transport, JSON decode + rendering, and the existing later interactions. The separate `serve` row keeps a launch measurement (`tools/scale.sh:111–138`; it actually receives a full response, rather than instrumenting the internal task's completion). Exported-page rows remain untouched. For a shape with a linked what-if (`scale-gui.mjs:29–32,294`), a POST of the recorded view does not precompute that what-if: its evaluation still sits inside first. Thus “the page's own path” is not a pure frontend-only interval across all shapes; this diagnostic covers recorded wide alone.

It drops the browser's immediate-navigation path while launch is still pending. The product opens the browser during launch (`Cli.lean:1160–1170`; spec GUI access), so this is a normal user path, not a contrived worst case. The contract explicitly conditions *details* on the view already being held (`kernel.md:169`), but provides no such warm precondition for first view. Two individually ≤10 s components can take >10 s together. Independent component minima also need not co-occur. Warm-only therefore needs an explicit narrowed claim or a retained cold first-view row; it is not equal-strength coverage as proposed. Useful as a diagnostic/secondary row, not the sole first-view grade.

## S4 — fixed early navigation and cap risk

(b) is the strongest of the three for preserving the intended first-view path: browser + context + blank page exist before server spawn; navigate as soon as the printed link arrives, without an answered POST. This removes the large, unrelated browser-creation component from d and avoids its startup CPU competition with the evaluation. The blank browser does not pre-read the trace or prime its application answer.

Residual d = process/server setup, task scheduling, stdout/link delivery, driver scheduling and `goto` dispatch. Actual launch-task start is not instrumented; it can lag `IO.asTask`. Link-arrival navigation approximates an already-open user's browser, not every OS opener/browser startup. It does **not** make d exactly zero or guarantee constant d across n. Record spawn→link and link→navigation separately, plus the resource decomposition, so this claim becomes checkable. Keep navigation→paint as the graded interval; approximate d+F is additional context only.

Graded N_cap rows from `b8g-1.log`; ranges = all three original runs, not new measurements:

| Shape | Serve launch, s | Served first, s |
|---|---|---|
| wide | 4.060–4.270 | 4.456–4.734 |
| deep | 3.760–4.330 | 4.278–5.003 |
| experiments | 4.250–4.540 | 4.400–4.785 |
| exclusions | 4.600–5.060 | 4.339–4.567 |
| outcomes | 5.320–5.720 | 5.237–5.398 |
| prereqs | 3.900–4.580 | 4.305–4.466 |
| whatif | 0.370–0.410 | 0.726–0.759 |

Anchors = `b8g-1.log:38,62,123,147,213,243,312,336,688,718,778,808,865,895`. Worst graded individual first leaves 4.602 s to 10; launch leaves 4.280 s. These suggest useful headroom, but are separate sessions with no original d decomposition. No empirical upper bound for (b) follows. In particular, **5.720 + 5.398 = 11.118 is not a valid predicted (b) latency**: served first already includes most of launch. Conversely, “(b) cannot exceed 10 s” is unconfirmed. Measure it on every graded shape. Non-graded shapes remain reported, not silently promoted: questions' worst first = 6.106 s; invalid has no successful first-view row.

## S5 — alternatives and implications

(c) measures actual latency for its incidental start state, so its numbers are not fabricated. It is unsuitable as a controlled size-growth comparison without defining and measuring that state. Keeping it + merely rerunning until green would not repair the cause of instability.

Best refinement = (b) + decomposed telemetry in the same sessions. This retains cold startup overlap and makes a later red attributable to launch wait, transfer or page work. Do not subtract a launch from a *different* session, or select d-corrected samples after seeing the result. Do not replace the contract with spawn→paint silently: adding d changes its start event, although diagnostic d+F (low min 2190, high min 4372 ms; normalized ratio 1.996) is informative.

Broader implication = benchmark *state* is part of the measured quantity. Work moved before navigation can improve the reported first-view latency without making the whole user path faster. The right response is explicit cold/warm state and phase times, not a more favorable statistic.

## S6 — next checks, ranked by information value

1. **Preserve scope before the user's ruling:** narrow F86's inference as S1. Recommend (b) + telemetry, no threshold or fastest-of-3 change. This is a grading-method change, not a product fix proven by the diagnostic.
2. **Focused first-view-only confirmation after the ruling and implementation:** same fixed commit, exclusive reference host, 3 independent batches × 3 fresh server/browser sessions × both wide sizes = 18 sessions. Prepare the browser/context/page before each spawn; alternate size order between batches, preserve the first batch and every run. Log d split at link delivery, request wait, transfer, after-response, first; verify the first request still overlaps launch at both sizes. Compute each batch's existing minimum-of-3 ratio; do not pool all nine into a more favorable minimum. Forecast ≈2× (roughly 1.8–2.2); not a confidence interval or new gate limit. Existing race all independent 3-of-5 minima combinations = 1.857–2.066; ordinal single-session ratios = 1.832–2.228. Expect a smaller, more stable link→navigation delay; its observed size and trend decide whether the proposed control worked. An unexpected ratio/d pattern triggers diagnosis, not another unrecorded attempt.
3. **Full acceptance:** `bash tools/scale.sh --assert` on that commit, all graded shapes, fastest of 3 unchanged, both reference-host slots held as required. Every original bound remains; F81–F83 coverage stays. Product/kernel and grader integrity checks remain MAIN's work. No acceptance run was executed by this appraisal.
4. **Only if causal identification is still needed:** in a focused diagnostic, assign extra navigation delay 0 vs 500 ms in counterbalanced fresh sessions, recording the same phases. While launch remains pending, the model predicts F falls by about the imposed delay, while approximate spawn→paint stays similar; warm first should not fall in the same way. Server-load or page-work rivals predict different decompositions. This would establish the prospective offset mechanism's size, **not recover the original run's missing d**. Retain warm as a secondary diagnostic if needed.

## S7 — assumptions, rivals and coverage limits

- Replication = 5 fresh sessions per size/condition, not 20 independent hardware environments. Order is always low race → low warm → high race → high warm (`first.mjs:18–21`). Session number is not randomized pairing. Size, condition, cache warming and time can covary. First race sessions at both sizes are the slowest; thermal/cache/order explanations remain plausible.
- Host = nixbox alone; diagnostic load 3.41 at start, 2.95 at end, 8 CPUs, performance governor/profile, PL1 22 W (`diag-1.log:3,25`). Load averages include recent work and do not measure instantaneous competing CPU utilization; ≈3 neither proves foreign load nor certifies a quiescent processor. No per-session frequency, thermal, scheduler or cache telemetry.
- Provenance: `diag.txt:1` records e28518c; `b8g-1.log:4` records binary SHA-256 a991edbad3212be9865b098201bbfacd628d6bbbef1420b12262ea5e7b8ea75f. Diagnostic log prints no binary hash. Same intended commit is recorded; byte equality between the two measured binaries was not independently established here. No model/grader-lane comparison is involved; arithmetic uses a deterministic parser.
- Two sizes + selected wide shape cannot establish asymptotic complexity, bounds for all traces, or all-shape (b) timings. No power calculation or population effect estimate is warranted from these sessions. Numerous gate rows can expose a noisy ratio; the false-red probability is not estimated. Sensitivity analyses are post-red diagnostics, not independent acceptance.
- Exported first is useful corroboration (wide fastest 0.855 → 1.304 s, ratio 1.525; `b8g-1.log:77–78`) but not the served counterfactual: embedded data + a Worker differ from HTTP delivery + a server.
- Resource timing is at browser request/response boundaries, not a timestamp inside `Server.answer`; wait mixes queueing, server work and transport setup. Mark = the app's `fvtrace:painted` convention (`web/app.js:1068–1071`), not an external display measurement. No new claim about physical paint timing is made.
- Source coverage: full diagnostic log/driver, full graded GUI driver + scale shell/helper, relevant launch/server/app functions and contract sections; all 66 successful launch/first/page-first rows selected from B8, plus its load/closing lines. Earlier runs mentioned in F86 were **not independently reopened**. GUI own-work growth during the original anomalous session remains unconfirmed; looked in its preserved wall rows, which lack a phase breakdown.

## Reproducible data probe

Executed read-only with `python3 -I`; no timings. Probe authoring failure: first B8 parser assumed ≥12 fields and found no matching wide row (`KeyError`, rc 1). Inspected row format = 11 fields; corrected parser below, 66 selected rows asserted, rc 0. Diagnostic calculations from the first probe completed before that parser error; this compact reproduction preserves the decisive computations.

```sh
python3 -I - <<'PY'
from pathlib import Path
from collections import defaultdict
from statistics import median
from math import log
from itertools import combinations
root = Path('/home/eturkes/Projects/fvtrace')
g = defaultdict(list)
for line in (root/'.scratch/b8g/diag-1.log').read_text().splitlines():
    f = line.split()
    if len(f) == 8 and f[0].isdigit():
        n, cond = int(f[0]), f[1]
        i, d, w, x, a, first = map(int, f[2:])
        g[n, cond].append(dict(d=d, wait=w, after=a, first=first, total=d+first))
assert sorted((n,c,len(v)) for (n,c),v in g.items()) == [
    (23040,'race',5),(23040,'warm',5),(46081,'race',5),(46081,'warm',5)]
k = log(2)/log(46081/23040)
print('CONTROL: 20 diagnostic rows; 5 per size x condition')
for c in ('race','warm'):
    for metric in ('wait','after','first','total'):
        a = [r[metric] for r in g[23040,c]]
        b = [r[metric] for r in g[46081,c]]
        print(c, metric, 'min/median ratio',
              f'{(min(b)/min(a))**k:.4f}/{(median(b)/median(a))**k:.4f}')
    vals = [r['wait']/r['first'] for n in (23040,46081) for r in g[n,c]]
    print(c, 'wait fraction', f'{min(vals):.4f}-{max(vals):.4f}')
    ratios = [(min(g[46081,c][j]['first'] for j in y)/
               min(g[23040,c][j]['first'] for j in x))**k
              for x in combinations(range(5),3) for y in combinations(range(5),3)]
    print(c, '100 independent 3-of-5 ratios', f'{min(ratios):.4f}-{max(ratios):.4f}')
rows = {}
for line in (root/'.scratch/bench/b8g-1.log').read_text().splitlines():
    f = line.split()
    if len(f)==11 and f[2].isdigit() and f[5]=='0' and f[4] in (
            'serve','gui:served:first','gui:page:first'):
        rows[f[1],int(f[2]),f[4]] = list(map(float,f[-1].split(',')))
assert len(rows)==66
lo, hi = [rows['wide',n,'gui:served:first'] for n in (23040,46081)]
assert len(lo)==len(hi)==3
print('CONTROL: 66 successful selected B8 rows; wide has 3 runs per size')
print('B8 min/median ratio', f'{(min(hi)/min(lo))**k:.4f}/{(median(hi)/median(lo))**k:.4f}')
print('B8 denominator increase to threshold, ms', f'{1000*(min(hi)/2.5**(1/k)-min(lo)):.1f}')
print('B8 remove-low-sample sensitivity ratio', f'{(min(hi)/min(lo[1:]))**k:.4f}')
for s in ('wide','deep','experiments','exclusions','outcomes','prereqs','whatif'):
    n=max(n for shape,n,c in rows if shape==s and c=='serve')
    a,b=rows[s,n,'serve'],rows[s,n,'gui:served:first']
    print(s,n,'serve min/max',f'{min(a):.3f}/{max(a):.3f}',
          'first min/max',f'{min(b):.3f}/{max(b):.3f}')
PY
rc=$?; printf 'probe rc=%s\n' "$rc"
```

Output (executed from this exact code block; rc 0):

```text
CONTROL: 20 diagnostic rows; 5 per size x condition
race wait min/median ratio 2.1189/2.0051
race after min/median ratio 1.9388/1.9420
race first min/median ratio 2.0321/1.8885
race total min/median ratio 1.9963/1.8474
race wait fraction 0.7610-0.8125
race 100 independent 3-of-5 ratios 1.8574-2.0661
warm wait min/median ratio 1.9756/1.8085
warm after min/median ratio 1.9046/1.9573
warm first min/median ratio 1.7366/1.7874
warm total min/median ratio 1.9362/1.8324
warm wait fraction 0.0838-0.1181
warm 100 independent 3-of-5 ratios 1.5964-1.9443
CONTROL: 66 successful selected B8 rows; wide has 3 runs per size
B8 min/median ratio 2.6382/2.0810
B8 denominator increase to threshold, ms 93.3
B8 remove-low-sample sensitivity ratio 2.0393
wide 46081 serve min/max 4.060/4.270 first min/max 4.456/4.734
deep 134196 serve min/max 3.760/4.330 first min/max 4.278/5.003
experiments 29919 serve min/max 4.250/4.540 first min/max 4.400/4.785
exclusions 25597 serve min/max 4.600/5.060 first min/max 4.339/4.567
outcomes 43949 serve min/max 5.320/5.720 first min/max 5.237/5.398
prereqs 26825 serve min/max 3.900/4.580 first min/max 4.305/4.466
whatif 4936 serve min/max 0.370/0.410 first min/max 0.726/0.759
probe rc=0
```

Validation: seed positive control = expected 7 matching table rows / 14 seeded cells, observed 7 / 14, rc 0. Final seed-token search = no match, rc 1 as required. Exact-id structure check = 7/7 rows, allowed verdicts, nonempty reasons + final marker, rc 0. Auxiliary validator authoring failure = broad `| S` matcher included the `Shape` header; inspected its selected ids, narrowed to S1–S7, then passed. No formal acceptance, build, timing or browser workload was run. No source files changed.

scientist-1-DONE-1
