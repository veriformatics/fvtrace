# Reviewer brief (shared) — MAINTAIN code review of fvTrace at `48bc51d`

Intent: the definitive code review of the whole implementation (code, tests, gates, config, docs). You audit one lens × slice; MAIN (the lead) reruns every proof you give, rules, fixes. Findings you miss stay in the product; findings you invent cost MAIN a rerun each ⇒ evidence bar below, no speculation.

## Read first

- `/home/eturkes/Projects/fvtrace/.agent/review.md` = the check set (your rows' full `asks` + the module table) + the evidence bar.
- Law: `CLAUDE.md` (`Engineering` = the code diff lenses + verification integrity), `.claude/rules/*.md`, `.agent/spec.md` (`Intent` + `Decisions` bind), `.agent/contracts/kernel.md` (the kernel contract; ids D-*, WF-*, S-*, V-*, P-*, E-*, U-*), `.agent/contracts/units.md` (tiers + recorded evidence).
- Target = the frozen base `/home/eturkes/Projects/fvtrace/.scratch/review-base` (git worktree at `48bc51d`, fully built: `.lake/build/bin/{fvtrace,fvtrace-tests,fvtrace-trust}`, `node_modules`, `.tools/bin`). Cite `file:line` there (= `git show 48bc51d:<file>`).

## Deliverable

- `/home/eturkes/Projects/fvtrace/.agent/review/<your name>.md`: seed it first with the table your brief gives (every `unknown` cell), then fill it row by row (a stop leaves it readable). Validator: `rg -c unknown <deliverable>` → 0. Last line: your marker `<name>-DONE-1`.
- Shape: verdict table (one row per check × target: `pass` | finding ids | `n/a <reason>`, plus a one-line basis: what you read or ran) over detail sections keyed by finding id. An all-`pass` table is a complete review.
- Finding id `<name>-F<n>`; each = severity (`blocker` · `major` · `minor`), `file:line` at `48bc51d`, the contract clause it breaks (kernel.md id, Decisions entry, rule bullet, `CLAUDE.md` clause, or the claim it contradicts), proof, one-line fix direction.
  - Behavior → a red test: the exact command + its failing output on the base (a script under your scratch dir, absolute paths).
  - Text → the anchor: short, distinctive bytes that `rg -Fn '<bytes>' <file>` matches in the base.
- Outside the contract (taste, a defect no clause covers) → a `Register` section (one line each, `file:line` + why); never a finding.
- Security-relevant observations: one line `file:line` + `security → MAIN` in `Register`, no analysis.

## Hard lines

- Write only your deliverable + `/home/eturkes/Projects/fvtrace/.scratch/review/<your name>/` (scratch: red tests, copies, logs). The base + the primary tree's other files stay untouched.
- Git: leave it alone — no commit, branch, stash, worktree, checkout, push. MAIN commits.
- Every `fvtrace` run sets `FVTRACE_HOME=/home/eturkes/Projects/fvtrace/.scratch/review/<your name>/home` (the default data folder holds private data: never touch it).
- `fvtrace skills install` always with `--dir <your scratch>/skills`; `export` destinations under your scratch; `serve` always `--port 0 --no-browser`, every server you start killed by PID before you finish (confirm with `pgrep -af`).
- A planted input, an edit or a build → your own copy: `cp -a --reflink=auto /home/eturkes/Projects/fvtrace/.scratch/review-base /home/eturkes/Projects/fvtrace/.scratch/review/<your name>/tree && rm /home/eturkes/Projects/fvtrace/.scratch/review/<your name>/tree/.git` (a tool that needs git there: `git init -q && git add -A && git commit -qm base` inside the copy). Incremental builds there only (`nice -n 10 lake build <target>`); no mutation campaigns (`tools/mutate.mjs` beyond `--list` = MAIN's); no full gate.
- FFI-free Lean snippets run against the base without building: `cd /tmp && LEAN_PATH=/home/eturkes/Projects/fvtrace/.scratch/review-base/.lake/build/lib/lean lean --run <your scratch>/x.lean`. Native behavior → drive the built binaries.
- No nested subagents. Mid-run directives from MAIN: `/home/eturkes/Projects/fvtrace/.agent/review/LEAD-DIRECTIVES.txt`, re-read at each checkpoint (after each row).
- Search: `rg <pattern> <path>` always names a path.
