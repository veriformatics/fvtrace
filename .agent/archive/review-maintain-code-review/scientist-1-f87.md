# scientist-1 — F87 appraisal

Recommendation = **size-interleaved, counterbalanced whole runs + contemporaneous host telemetry; fastest of 3 unchanged; no thermal result-discard rule yet**. The data support a GUI-session/size-associated slowdown. Thermal throttling is plausible, not identified. A green older run + unchanged binary do not establish that the new red is false.

Scope = existing files + local arithmetic only. Root = `/home/eturkes/Projects/fvtrace`. Deliverable = validator input; only this file written; unstaged; MAIN commits. Confidence describes the appraisal, not a probability assigned to a cause.

| id | question | verdict | confidence | reason (≤ 3 lines; detail below by id) |
|---|---|---|---|---|
| T1 | The red row (`experiments gui:page:whatif` 2.51) = host state, not a product or driver change | overstated | High | Binary hashes match; cap what-if rises 3.179→4.091 s (+28.7%), half stays 1.613→1.629 (+1.0%). Several cap GUI phases slow together, but changed served setup precedes the exported page in the same Chromium process. Run epoch, runtime state and driver carryover are confounded. |
| T2 | Mechanism: thermal throttling of the laptop host vs rivals (Chromium GC/heap variance, a background process on nixbox, memory pressure, driver order change) | open | Moderate plausibility; low attribution | Later +744 throttle counts/10 s and one 95 °C reading make thermal restriction credible on this host. Neither was measured during the failing 04:32–04:34 GUI window. Common slowing fits thermal/power limits, contention and session carryover; GC/working-set effects remain possible. |
| T3 | Fix (a) size-interleaved runs (run r: N_cap/2 then N_cap, order alternating per r), fastest of 3 kept: absorbs window drift? weakens detection of a true super-linear growth? | supported | Moderate | Reduces size/time confounding without removing samples or relaxing 2.5×. Current groups occupy separate 42 s / 90 s GUI windows. Interleaving does not cancel arbitrary drift, size-induced heating, or independently selected minima; retain whole sessions + every failure. |
| T4 | Fix (b) thermal settle before each timed run (package temperature ≤ T, bounded wait; T?) | unsupported | High for choosing a threshold now | No defensible T follows from a later 95 °C reading and a later 45–46 °C zone reading. Cooling before a whole GUI session may not control temperature at its later page step. Cold-start-only grading changes the workload; discarding a run heated by its own work biases it. |
| T5 | Fix (c) per-run host record (package temperature at start + end, throttle-count delta, mean MHz): telemetry only vs a validity rule (run invalid past X) | supported | High for telemetry; low for an X | Record the state during each session/phase, not only afterward; start/end alone miss within-run peaks. No temperature/throttle cutoff is validated. Mean 2337 MHz without active-core weighting and sensor identities cannot quantify lost performance. |
| T6 | Recommended option set for the user's ruling + its forecast for the next B8 + what confirms it | open | Moderate for design; low for a numerical forecast | Choose (a)+(c), telemetry-only. Expect less order dependence if slow window drift dominates; no promised green or return to 1.97. Existing min ratios 1.971/2.511 and median ratios 2.019/2.318 are descriptive, not a prediction interval. Next B8 must retain three sessions per size and all original bounds. |
| T7 | Any option that turns a red into a re-run (validity rule) vs the law "never rerun to green; each red classified before any rerun" | supported | High | Record and classify every red before another attempt; distinguish a predeclared environmental invalidity from a performance failure. Never discard a slow/hot completed run after inspecting its result. A bounded readiness timeout gives no performance verdict, not green. |

## T1 — measured effect versus attribution

### Verified data and source scope

- Both logs print SHA-256 `a991edbad3212be9865b098201bbfacd628d6bbbef1420b12262ea5e7b8ea75f` (`.scratch/bench/b8g-1.log:4`, `.scratch/bench/b8h/b8g-1.log:4`). Recomputed: 586 successful matched rows; no input-byte-count or output-byte-count differences. Counts are not byte-equality proofs of generated artifacts.
- `git diff e28518c fb7490b -- Fvtrace web tools/scale.mjs tools/scale.sh tools/scale-page.mjs tools/scale-gui.mjs .node-version package.json pnpm-lock.yaml` changes only `tools/scale-gui.mjs` among these surfaces. This excludes a new shipped-source change in this comparison; it does not exclude pre-existing product/runtime sensitivity. Actual browser/runtime versions were not printed by these logs.
- Native + Node page-engine action rows are useful controls, not the GUI contract: `actionOf("experiments", n)` = `success:R0` (`tools/scale.mjs:377–378`), whereas the GUI clicks its first enabled fact symbol (`tools/scale-gui.mjs:264–269`) and includes browser response handling + rendering. Even identical final engine answers would not equate these intervals.
- The changed served setup + new telemetry precede page mode in the same browser (`tools/scale-gui.mjs:233–241,334–349`). Served context closes after its heap collection, then a new page context starts; the Chromium process/host persist. “Page timing code unchanged” is narrower than “measurement conditions unchanged.” The old/new driver is perfectly confounded with run epoch here.

### Effect size and threshold sensitivity

| Quantity | Earlier B8 | F87 B8 |
|---|---|---|
| Half-size what-if, all three seconds | 1.613, 1.728, 1.657 | 1.810, 1.629, 1.795 |
| Cap what-if, all three seconds | 3.362, 3.346, 3.179 | 4.161, 4.277, 4.091 |
| Ruled minimum ratio, per doubling | 1.9708 | **2.5112** |
| Median ratio, sensitivity only | 2.0192 | 2.3180 |

Sources = old `:272–273`, new `:271–274`. The cap shift is material: even the new minimum 4.091 exceeds the old maximum 3.362. The *bound excess* is small: −18.320 ms on the numerator or +7.328 ms on the denominator alone reaches 2.5. This makes the verdict sensitive; it does not authorize a tolerance, deletion, median substitution or rerun-to-green. Three dependent sessions per size cannot estimate a false-red probability or establish equivalence.

Cap heavy GUI new/old minima: served what-if 1.1604, exported first 1.2995, exported what-if 1.2869, exported startup 1.2189. This is broader than one page operation. It is not literally “1.16–1.30 in all three runs”: ordinal new/old served what-if ratios are 1.2406, **1.0788**, **1.3133**; ordinal pairs are not matched environments. Some light rows also move: served experiment minimum +23.8%, served details +14.3%, while page selection/details/busy are nearly unchanged. Frame-quantized short intervals are weak controls for CPU-intensive work.

This is not demonstrated to be one isolated transient window. Heavy unchanged GUI cap medians also rise on wide (1.120), exclusions (1.163), hub (1.125), prereqs (1.119); prereqs' half-size rises more (1.207). Such a pattern fits size/session duration interacting with host state or browser working set, as well as slow external drift.

### Corrections to the diagnostic interpretation

- The original comparison script put `gui:served:first` into `cli` rather than excluding it. MAIN's current script fixes that. Independently recomputed with rc=0 + old wall≥0.3 s: CLI-like rows 215, median new/old **0.9779**; experiments cap CLI-like median **0.9294**, unchanged GUI median **1.2529**. The central GUI contrast survives the correction. The script's numeric-time parser also admits nonzero-rc rows (e.g. non-graded invalid `serve`); this appraisal excludes them. No finding depends on those rows.
- `SCALE_GUI_PHASES` **wait is not the server's internal launch duration**. It is request→response-start, mixing remaining launch wait, request processing and transport setup. Standalone `serve` includes process start→a complete response, with no concurrent browser. New cap ratios min(wait)/min(standalone serve) are 1.1008 experiments and 1.2016 exclusions (`b8h/b8g-1.log:212,1082–1084,1088–1090`). This is compatible with broader CPU contention or host effects, but compares different work and different times; it is not a contemporaneous same-work control that identifies an external host cause.
- F87's “the product meets P-time on this row” is too strong. It meets the 10 s absolute bound here; it **fails the current 2.5× growth bound** (`kernel.md:133,147,169`). Engine ≈2× and an earlier GUI green do not discharge the GUI's new red. Gate classification may name the sampling-design defect as the lead; the specific failure's cause remains open.

## T2 — thermal hypothesis and separating observations

Thermal/power restriction is a credible mechanism: several compute-heavy GUI phases slow while short interactions scarcely move, and the laptop later shows throttling. But the host readings came during another workload after B8, not during the red. No direct thermal effect size can be calculated. The 18.2 M cumulative count reflects history, not the failing interval; counter increments need their per-CPU/package semantics and cannot be translated into time lost. One 95 °C package reading versus a later 45–46 °C zone reading needs matching sensor path/type + timestamps before treating it as cooling. A performance governor/profile + PL1 22 W does not imply constant realized CPU speed.

| Live explanation | Observation that would strengthen it | Observation that would weaken/separate it |
|---|---|---|
| Thermal or package-power restriction | Same operation slower when its occupied cores have lower effective frequency, contemporaneous limit/throttle activity and appropriate temperature/power history; repeatable within the same driver with size/order controlled | Slow rows recur with comparable active frequency, temperatures and no applicable limit activity, while browser/GC or scheduler delays explain their excess; a throttling counter alone is insufficient |
| Unrelated CPU contention | Non-benchmark CPU use, scheduling delay/run-queue pressure or context-switch changes coincide with slow phases | Exclusive ownership + process CPU records show no competing work and little scheduling delay; load average alone cannot establish this |
| Memory pressure, page faults, swapping | Low available memory, memory/I/O pressure or faults/swap activity coincide with delay | Comparable memory pressure/fault records and worker/browser memory trajectories across fast and slow sessions |
| Chromium GC, compilation/tiering or heap thresholds | Slowdown localizes to worker/JS/GC/compile phases, associated with larger working sets, persists under similar host conditions | Unchanged browser work phases at stable host state; a simultaneous independent fixed-work CPU control slows similarly. End-of-session live heap is not a GC/peak-memory trace |
| Driver-induced carryover | Under matched host state, old/new served setup changes later page timing; or page-only fresh-browser sessions remove the difference | Counterbalanced old/new-driver diagnostic shows no reproducible difference after accounting for host state |

High-information follow-up, once the reference host is exclusively available: a fixed-binary, fixed-browser targeted experiments test, logging both sizes and order; contrast old/new driver only if the carryover question persists. If testing thermal causality, compare predefined matched starting-state regimes and retain all outcomes. A correlation supports a lead; a repeatable controlled change of thermal history with work/order held fixed strengthens causal attribution. Do not infer that a larger run's own heating is external contamination: `size → sustained work → heat/limit → latency` can be a real product-on-host scaling path.

## T3 — what interleaving fixes and what it does not

Current scheduling (`tools/scale.sh:168–183,238–280`) exhausts three whole sessions at one n before the other n. For experiments, the standalone page rows finish 04:32:00; half-size GUI finishes 04:32:42; cap GUI finishes 04:34:12. Each reported GUI step's timestamp is printed after the session group, **not its actual event time**. Minute load samples cannot locate the page what-if or associate a specific row with a temperature.

Use paired, alternating whole-session blocks: `L H | H L | L H`, with the starting order counterbalanced across predefined shapes/batches. L/H = cap/2 and cap. Keep three per size, all within-session steps in their current order, and fresh per-session state. For CLI commands, interleave the three command invocations analogously. Do not interleave individual steps from distinct live server/page sessions: that changes cache/state contracts. No cross-size parallel timing on this host.

Assumption model: `time(n,r) = work(n) × host_cost(r)`. The minimum ratio is `work(H)/work(L) × min(host_cost at H)/min(host_cost at L)`. Interleaving tends to expose both sizes to nearby host states, but independent minima do not cancel the host factor exactly. With three pairs one order occurs twice; deterministic counterbalancing of the starting order limits that residual. Pairing is a design improvement, not permission to replace the existing minimum-ratio grade with a paired or median statistic.

Arithmetic illustration only, **not measurements**: host cost drifts 1.0,1.1,…,1.5. Intrinsic 2× growth appears 2.6× under `LLLHHH`, 2.2× under `LHHLLH`; intrinsic 4× still appears 5.2×/4.4×. Thus drift can manufacture a red and interleaving can reduce it without removing real super-linear work. No guarantee holds for arbitrary oscillation, carryover or n-dependent heating. Reordering can change sustained-use behavior; if that is the claimed workload, retain a separate explicitly sustained diagnostic instead of declaring it irrelevant.

## T4 — thermal settling

Do not select a temperature T from these data. They contain no temperatures during B8, no calibrated baseline distribution, no sensor consistency, no duration-to-settle relation, and no link from T to stable frequency. A cool package can still be power-limited; a hot package can run consistently.

A bounded **pre-run** readiness rule could eventually define a reproducible cold-start regime, with sensor identities, a stability window and a limit established in a pilot. Apply it before observing the result, symmetrically to both sizes, and report waiting/failure to become ready. Cold-start selection is not automatically more representative than steady-state laptop use. Choosing an arbitrary 50/60/70 °C cutoff now would encode a guess as the oracle.

For GUI runs, a “run” is the whole served + exported session. Cooling before it does not ensure matched temperature when its page what-if occurs tens of seconds later; cap sessions are longer. Pausing between individual clicks would change the timed workload's history. Rejecting a completed run because *its workload* raised temperature/throttle counts conditions on an effect of n and can systematically remove the slower large-size samples. Thermal settling is therefore optional investigation/explicit workload definition, not the preferred immediate fix.

## T5 — what the next B8 must record

Telemetry first; no automatic exclusion threshold X. Record one synchronized low-overhead stream plus exact run/phase boundaries; validate collection overhead separately before making it part of an official timing claim.

- **Identity:** commit + driver/generator hashes, binary hash, Node/Playwright/Chromium versions + flags, generated trace/export identities, kernel, online CPUs/affinity, governor/profile, AC/power state and package power limits. Same native binary does not pin the browser or environment.
- **Every run:** shape, n, kind, repetition index, assigned order, actual monotonic + UTC start/end, exit/timeout status, all measured walls. Preserve session boundaries and the actual served/page step boundaries, not just delayed output timestamps. Keep F86's spawn/link/navigation/response phases.
- **Thermal/power:** labeled sensor path/type, package/core temperature at start/end **and during**, throttle counters before/after per identified CPU/package, available thermal/power-limit indicators, power/energy and fan state if available. Summarize peak and history; preserve raw observations. Do not count duplicated per-core package counters as independent events.
- **Effective CPU service:** active-core frequency/residency counters where available (APERF/MPERF-derived effective frequency with busy utilization, not an unweighted mean of instantaneous per-core MHz), benchmark versus other-process CPU usage, scheduler/CPU-pressure information. Nominal governor and instantaneous MHz alone do not explain latency.
- **Memory/I/O:** available memory, swap activity, memory/I/O pressure, faults and relevant process RSS. Stable post-GC page heap (cap ~163 MiB in both runs) does not rule out transient GC/working-set effects.
- **Browser phase evidence:** at minimum, distinguish worker answer time from receiving/decoding/rendering it for the target what-if in a diagnostic. Heavy Chrome tracing/GC profiling belongs in a separate targeted run unless its timing overhead is measured; do not silently change the official interval.

A proposed continuous cadence around 0.5–1 s is an engineering starting point, not a calibrated requirement; longer GUI phases are the target, while short phases still need boundary marks. Sensor read failure = explicit missing telemetry, never an inferred zero. The sensor stream should not fail an otherwise valid timing row unless a separately approved, tested validity contract requires it.

## T6 — recommendation, forecast and confirmation

For the user's ruling: **(a) + (c), with (c) descriptive only; defer (b) and any post-run validity filter.** Rationale = improve exposure to time-varying conditions and make the next red interpretable without requiring the thermal story to be true. Keep 2.5×, each absolute bound, fastest of 3, every failure and the reference host's exclusive ownership.

Forecast: if slow external drift across the separate n windows dominates, interleaving should reduce order sensitivity and the target ratio may move toward its earlier ≈2×. If cap sessions themselves heat the laptop, cross a GC/working-set threshold, or inherit changed browser state, the red may persist. I cannot justify a narrow numerical prediction interval or promise a green B8 from these two epochs. F86 held here (wide minimum ratio ≈1.93; confirmation batches ≈2.02,2.00,1.98), but those first-view-only sessions do not validate experiments' later exported what-if path.

Acceptance and information value, in order:
1. Mechanically validate the reordered harness: every otherwise successful size/kind has exactly three complete attempts, their run ids retained; every nonzero exit, timeout, missing row/time continues to outrank faster successes. Fail-fast remains permitted only with a failed result, never a minimum from an incomplete successful set. The same planted growth >2.5× and other original failures still fire. No extra repetitions until a favorite minimum appears.
2. Next full B8 at the fixed commit, exclusively on the reference host, with predefined counterbalancing + the telemetry above. A green is the operational acceptance at that protocol, not proof that thermal throttling caused the prior red. A red stays a red pending diagnosis.
3. Judge the design by state overlap/order dependence as well as its color: did both sizes sample comparable histories; did any late step heat itself; does the slowdown track effective frequency/limits, unrelated contention, or browser work? Retain all three walls per row and supplemental within-block contrasts.
4. If attribution remains necessary, targeted counterbalanced sessions distinguish thermal history from old/new-driver carryover (T2), with an unaltered product and exact browser revision. Predefine counts/conditions; reports from these diagnostics do not replace the B8 aggregate.

## T7 — validity rules without rerun-to-green

- Current red = durable failed check at fb7490b. Record/classify it before another attempt. With the grader changed between the earlier green and this red, that pair alone is not an unchanged-tree red→green flake demonstration. A sampling-design gate finding can be recorded while its causal thermal explanation remains provisional.
- A future readiness condition must be set before timing, independently of the observed wall/ratio. If the condition never holds within its bound, report “environment not ready; timing not performed,” with no green performance verdict. Keep the wait and reason.
- A post-start external validity violation (e.g. another pool job actually began or affinity changed) needs a predeclared objective rule, raw evidence and an explicit invalid attempt. Classify/retain it before any replacement; define the retry limit in advance. This is a separate grading-rule change, requiring the user's ruling and a planted invalid-state check.
- A slow wall, a ratio >2.5, or workload-induced heating is **not** by itself invalidity. Selecting cool/fast outcomes after seeing them is outcome-dependent censoring, especially when larger inputs cause heat. Never pool repeats to harvest a lower minimum or relabel an ordinary red using a threshold chosen afterward.
- Consistent thermal restriction under this laptop's sustained benchmark may be part of the reference performance envelope. If that makes the stated bound unattainable, the options are product/host investigation or an explicit change in what workload is claimed—not hidden sample deletion.

## Coverage and uncertainty

Only existing logs/source and local arithmetic were used. Full comparison script/text, graded GUI driver/diff, session-order code, target log window, load/phase/confirmation sections read; the arithmetic parser visited all log lines and selected all 586 successful matched rows. The ≥0.3 s filter follows the supplied summary and conditions on the earlier run; those heterogeneous rows are descriptive, not independent replications or a causal estimator. The target was selected after a large multi-row check; no multiplicity-adjusted inference, power estimate or confidence interval is warranted. Source checks establish common committed product code, not identical runtime/hardware state. Thermal readings are MAIN's noncontemporaneous observations, not measurements independently reproduced here. No nixbox access, timing, builds or browsers ran.

## Reproducible probe

Local command below recomputes the decisive rows and corrected summaries. Positive controls: two identical printed binary hashes; 586 successful rows in each log; 22 served-phase groups × 3 sessions. Model rows are labeled hypothetical.

```sh
python3 -I - <<'PY'
from pathlib import Path
from collections import defaultdict
from statistics import median
from math import log
import re
root=Path('/home/eturkes/Projects/fvtrace')
paths=[root/'.scratch/bench/b8g-1.log',root/'.scratch/bench/b8h/b8g-1.log']
def load(p):
    out={}; hashes=[]
    for line in p.read_text().splitlines():
        if ' sha256 ' in line: hashes.append(line.split(' sha256 ',1)[1])
        f=line.split()
        if len(f)==11 and re.fullmatch(r'\d\d:\d\d:\d\d',f[0]) and f[2].isdigit() and f[5]=='0' and re.fullmatch(r'\d+(?:\.\d+)?',f[6]):
            key=f[1],int(f[2]),f[4]
            assert key not in out
            out[key]=(float(f[6]),list(map(float,f[10].split(','))),int(f[3]),int(f[9]))
    return out,hashes
a,ha=load(paths[0]); b,hb=load(paths[1]); assert ha==hb and len(ha)==1
assert len(a)==len(b)==586 and set(a)==set(b)
print('CONTROL: 586 matched successful rows; printed binary hashes equal')
print('input/output byte-count differences',sum(a[x][2:]!=b[x][2:] for x in a))
k=log(2)/log(29919/14959)
for tag,d in [('old',a),('new',b)]:
    lo,hi=[d['experiments',n,'gui:page:whatif'][1] for n in (14959,29919)]
    print(tag,'min ratio',f'{(min(hi)/min(lo))**k:.6f}','median ratio',f'{(median(hi)/median(lo))**k:.6f}')
lo,hi=[b['experiments',n,'gui:page:whatif'][0] for n in (14959,29919)]
print('threshold: high decrease ms',f'{1000*(hi-lo*2.5**(1/k)):.3f}',
      'or low increase ms',f'{1000*(hi/2.5**(1/k)-lo):.3f}')
g=defaultdict(list)
for x in a:
    shape,n,c=x
    if a[x][0]<.3 or c=='gui:served:first': continue
    kind='gui' if c.startswith('gui:') else ('page' if c.startswith('page') else 'cli')
    g[shape,n,kind].append(b[x][0]/a[x][0])
for kind in ('cli','page','gui'):
    vals=[v for (s,n,c),vs in g.items() if c==kind for v in vs]
    print('corrected',kind,'rows',len(vals),'median',f'{median(vals):.4f}')
for n in (14959,29919):
    for c in ('gui:page:first','gui:page:whatif','gui:page:startup','gui:served:whatif'):
        x=('experiments',n,c)
        print(n,c,'min new/old',f'{b[x][0]/a[x][0]:.4f}')
ph=defaultdict(list)
for line in paths[1].read_text().splitlines():
    f=line.split()
    if len(f)==7 and re.fullmatch(r'[a-z]+-\d+',f[0]) and all(x.isdigit() for x in f[1:]):
        s,n=f[0].rsplit('-',1); ph[s,int(n)].append(list(map(int,f[1:])))
assert len(ph)==22 and all(len(v)==3 for v in ph.values())
print('CONTROL: 22 served-phase groups x 3 sessions')
for s,n in [('experiments',29919),('exclusions',25597)]:
    print(s,'GUI wait/standalone serve minima',f'{min(x[2] for x in ph[s,n])/1000/b[s,n,"serve"][0]:.4f}')
for schedule in ('LLLHHH','LHHLLH'):
    cost=[1+.1*i for i in range(6)]
    l=min(v for n,v in zip(schedule,cost) if n=='L')
    h=min(v for n,v in zip(schedule,cost) if n=='H')
    print('HYPOTHETICAL',schedule,'true 2x ->',f'{2*h/l:.3f}','true 4x ->',f'{4*h/l:.3f}')
PY
rc=$?; printf 'probe rc=%s\n' "$rc"
```

Output from the exact code block, rc 0:

```text
CONTROL: 586 matched successful rows; printed binary hashes equal
input/output byte-count differences 0
old min ratio 1.970797 median ratio 2.019244
new min ratio 2.511245 median ratio 2.318012
threshold: high decrease ms 18.320 or low increase ms 7.328
corrected cli rows 215 median 0.9779
corrected page rows 60 median 0.9533
corrected gui rows 88 median 1.0240
14959 gui:page:first min new/old 1.0063
14959 gui:page:whatif min new/old 1.0099
14959 gui:page:startup min new/old 0.9703
14959 gui:served:whatif min new/old 0.9685
29919 gui:page:first min new/old 1.2995
29919 gui:page:whatif min new/old 1.2869
29919 gui:page:startup min new/old 1.2189
29919 gui:served:whatif min new/old 1.1604
CONTROL: 22 served-phase groups x 3 sessions
experiments GUI wait/standalone serve minima 1.1008
exclusions GUI wait/standalone serve minima 1.2016
HYPOTHETICAL LLLHHH true 2x -> 2.600 true 4x -> 5.200
HYPOTHETICAL LHHLLH true 2x -> 2.200 true 4x -> 4.400
probe rc=0
```

Seed validator positive control = 7 matching rows / 21 seeded cells, as expected (rc 0). Final completeness check at delivery requires zero seed tokens, T1–T7 each with verdict/confidence/reason, and the marker below last. All requested questions adjudicated; causal findings explicitly open where unmeasured. No timing acceptance was run.

scientist-1-DONE-2
