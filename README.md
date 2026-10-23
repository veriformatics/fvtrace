# fvTrace

fvTrace shows which claims your analysis can make and which it cannot.

fvTrace takes one stance: you can make a claim only when every fact that the claim needs is
formally verified. A fact is verified when a proof covers it, or when a proved checker accepted
the actual data or code. If an analysis has no verification yet, fvTrace shows where verification
would make the most claims available. It also shows which experiments could fill each gap, and
which claims an assumption or a violated fact holds back.

You describe the analysis in a *trace*: the scientific questions, the claims, the facts that each
claim needs, and how each fact could be verified. Your coding agent can draft the trace for you.
fvTrace checks the trace and decides every verdict. fvTrace never calls a language model.

## The four verdicts

| Verdict | Meaning |
|---|---|
| **Fully supported** | Every fact that the claim needs is verified, and its evidence is unchanged since it was pinned. |
| **Conditional** | No fact is violated, and the facts that must be verified are verified. Each other fact is verified or assumed. You can state the claim only with its assumptions: "Assuming …: claim". |
| **Pending verification** | At least one fact is open, only tested, or its evidence changed. |
| **Claim not possible** | A fact is violated, the claim needs two facts that a verified or assumed exclusion rules out together, or a what-if conflicts. |

Each claim also needs one *entailment* fact, its reasoning: "these facts entail the claim as
worded". A claim that only restates one result needs no entailment fact. Only background conditions can be assumed, for example how the samples were collected,
or that they are independent. A reasoning, result, measurement, calculation, implementation or
data-flow fact must be verified: if the trace records one as `assumed`, `fvtrace check` reports
an error. Thus a claim whose reasoning is a person's judgment reads **Pending verification** at
best. Some conditions hold for every claim: the records are honest, the instruments work, and the
labels are correct. Do not list these universal premises as facts of each claim: the review
vouches for them once. Until a reviewer signs off the trace, every verdict is provisional.

## Install

fvTrace is one program, `fvtrace`. To build it from source:

1. Install [elan](https://github.com/leanprover/elan) (the Lean toolchain manager) and a C
   compiler (`cc`). On Windows, the build uses MinGW `gcc` (set `CC=gcc`). The build also needs
   Python 3.10 or later, `curl`, `tar` and `git`, because it compiles the engine of the exported
   page (see [Sharing](#sharing)). CI builds and tests fvTrace on Linux, macOS and Windows.
2. In this folder, run `lake build fvtrace`. The first build downloads Emscripten (about 300 MB;
   700 MB on Windows) and the Lean runtime sources, and checks each download against the SHA-256
   digest in `tools/wasm.lock`. Then it compiles the engine, which takes several minutes. Later
   builds reuse these files.
3. Copy `.lake/build/bin/fvtrace` to a folder on your `PATH`.
4. Run `fvtrace --version` to check the installation.

## Quick start

1. Go to the folder of your analysis: `cd my-analysis`.
2. Create the trace: `fvtrace init`. The command shows where the trace is.
3. Describe the analysis in that file. To let your coding agent draft it, run
   `fvtrace skills install` once, then ask the agent to set up fvTrace for the analysis.
4. If a fact is verified, name its evidence files (a proof, a checker log) in the trace, then
   pin them: `fvtrace pin` records the digests of the files, so that a later change shows.
5. Check the trace: `fvtrace check`. Correct each error that it shows.
6. Read the verdicts: `fvtrace claims`. To use the browser view, run `fvtrace serve` and open
   the link that it prints.
7. When the trace is correct, sign it off: `fvtrace review --reviewer "Your Name"`.

The folder `examples/synthetic` holds a small made-up study: three claims about a treatment and a
marker. To see it, go to `examples/synthetic/project` and run `fvtrace serve --trace ../trace.json`.

## The browser view

`fvtrace serve` shows the claims of each scientific question in a browser. To learn the page,
press **Take the tour**.

- Each claim shows a plain headline. To read the exact statement that the proofs cover, open
  **Show the exact statement**.
- Below the headline, each line names a fact that holds the claim back or that the claim
  assumes, with the reason that the claim needs it.
- A diagram under the claim shows each fact that the claim needs, one symbol for each fact. To
  suppose that a fact has the best status that its route allows, press its symbol. fvTrace then
  shows every verdict under that supposition, and the address of the page keeps it. To return,
  press **Show the facts as recorded**.
- To see the details of a claim, a fact or an experiment, press its name. You can select and
  copy any text: a drag selects the text and does not open the details.
- **Text** shows the same claims as plain sentences.
- Below the claims, the page shows the suggested experiments, the facts whose verification makes
  the most claims available, the violated facts, and what each claim may be missing.

## Commands

| Command | What it does |
|---|---|
| `fvtrace init` | Creates the trace of the project and shows where it is. |
| `fvtrace path` | Prints the location of the trace. |
| `fvtrace check [--strict]` | Checks the trace and the evidence of each verified fact. With `--strict`, a warning without a waiver or changed evidence also fails. |
| `fvtrace pin [--replay]` | Records the SHA-256 of each evidence file and statement. With `--replay`, it first runs each replay command and records the SHA-256 of its output. |
| `fvtrace verify [--run]` | Lists the replay command of each fact. With `--run`, it runs each command and checks that it exits with 0 and prints the same output as when it was pinned. |
| `fvtrace review --reviewer NAME` | Records that NAME reviewed the current trace. The review vouches that the claims and facts match the study, that each headline says no more than its exact statement, and that the universal premises hold. |
| `fvtrace claims` | Shows each claim with its verdict, by question. |
| `fvtrace gaps` | Shows the facts whose verification makes the most claims available. |
| `fvtrace experiments` | Shows the suggested experiments and what each one changes. |
| `fvtrace plan CLAIM` | Shows the set of suggested experiments that raises the claim as far as they allow, the cheapest among those. |
| `fvtrace serve` | Shows the claims in a browser. |
| `fvtrace export --html FILE` | Writes one page that opens in any browser, also offline, and computes what-ifs there. |
| `fvtrace export --bundle DIR` | Writes the trace and copies of its evidence files. |
| `fvtrace skills install` | Installs the skill for coding agents. |
| `fvtrace schema` | Prints the JSON Schema of the trace format. |

A command works on the project in the current folder. To use another folder, add
`--project DIR`. To read a trace file directly, for example a draft, add `--trace FILE`. To
suppose other statuses, add `--whatif FACT=STATUS,...` to `claims`, `gaps`, `experiments` or
`plan`. A what-if is a supposition, not evidence: fvTrace marks each verdict that depends on it.

`claims`, `gaps`, `experiments`, `plan` and `check` accept `--json` for scripts and agents.
`fvtrace eval` prints the full evaluation as JSON.

The exit status is 0 for success, 1 for an invalid or failing trace, and 2 for a usage or read
error.

## The trace

A trace is one JSON file. `fvtrace schema` prints its full format. The main parts are:

- **Questions**: the scientific questions of the analysis.
- **Claims**: the sentences that the analysis wants to state. fvTrace shows them word for word.
  A claim's `text` is its exact statement. An optional `headline` gives a plain form for
  readers; it must not say more than the exact statement, and the reviewer checks that. A claim
  that only restates one result needs no entailment fact: mark it `"restates": true`.
- **Facts**: one statement each. A fact has a **status** (`proved`, `checked`, `assumed`,
  `tested`, `open`, `violated`) and a **route**: how it could be verified (`lean`,
  `refinement`, `runtime-checker`, `human-ruling`, `empirical`). A route limits the status: a
  human ruling or empirical evidence makes a fact `assumed` at best, or `tested` at best when
  the fact must be verified. An optional `why` says in plain words why a claim needs the fact.
- **Evidence**: the files behind a verified fact (a proof, a checker log). `fvtrace pin` records
  their digests. If a file or the wording of the fact changes later, the fact is no longer
  verified until you pin again. fvTrace checks that the files are unchanged, not that they prove
  the fact. Each command reads every evidence file again. For large files, add `--cached` to
  `claims`, `gaps`, `experiments`, `plan` or `serve`: it reuses the digest of a file that kept
  its size and modification time, which is faster but misses an edit that keeps both.
- **Replay**: a fact's evidence can also name a command that checks the fact again, for example
  a build that prints the statement that a proof covers: `"replay": {"command": ["lake",
  "build"]}`. The digests cannot see a change outside the pinned files, for example a definition
  that the statement uses. A replay can: `fvtrace pin --replay` records the SHA-256 of the
  command's output, and `fvtrace verify --run` runs the command again and fails when it exits
  with another code than 0 or prints another output. A replay never changes a verdict. The
  command runs in the project folder with your rights, and it can write there, for example its
  build files. Nothing runs without `--run` or `--replay`. Before you use them on a trace from
  someone else, for example a bundle, run `fvtrace verify` to read the commands. Use `--run` only
  when you trust them.
- **Subjects**: what the facts are about. The existing analysis is one subject. Data that an
  experiment would create is another subject: such an experiment can raise claims about the new
  data, never the claims of the existing analysis.
- **Experiments**: suggested work to fill gaps. A *dry* experiment uses existing data, code or
  proofs; a *wet* experiment needs new samples or bench work. List an experiment after the
  experiments that it requires.

### Results, exclusions and violated facts

- A **result** fact states the value or pattern that a claim reports. `fvtrace check` warns when a
  claim lacks a kind of fact that its level usually needs, for example a causal claim without an
  interpretation fact. If the fact does not apply, record a **waiver** with the reason.
- An **exclusion** records two facts that cannot both hold. An exclusion has its own status, and
  fvTrace uses it only when it is verified or assumed. Then a claim that needs both sides cannot
  be made. If the exclusion is verified and one side is verified, fvTrace marks the other side
  violated, unless that side is verified or assumed too. Two sides that are both verified or
  assumed contradict each other: `fvtrace check` reports an error for the recorded trace, and a
  what-if that supposes both sides makes every claim on that subject **Claim not possible**.
- A **violated** fact is false as worded. fvTrace lists it apart, with the claims that it
  blocks: reword those claims, or collect new data.

## Where fvTrace keeps its files

fvTrace keeps its own files in its data folder: one folder for each project, with the trace, the
project location and a cache of file digests. It writes into your project folder only where you
point it: `--trace` at a file there, or `FVTRACE_HOME` or `skills install --dir` at a folder in
it. The data folder is
`FVTRACE_HOME` if you set it. Otherwise it is the data folder of your platform plus `fvtrace`:
`~/.local/share/fvtrace` on Linux, `~/Library/Application Support/fvtrace` on macOS, and
`%LOCALAPPDATA%\fvtrace` on Windows. The project folders are keyed by their full path, so a
moved project gets a new folder. After you move a project, run `fvtrace init` in its new
location, then copy the old trace file to the path that `fvtrace path` prints.

## Sharing

- `fvtrace export --html ../claims.html` writes one page outside the project folder. The page
  needs no server and no network. It holds the fvTrace engine, compiled to WebAssembly: when you
  press a fact's symbol, the engine computes every verdict in your browser, and you can combine
  what-ifs as in `fvtrace serve`. The page contains the whole trace, as `--bundle` does, but no
  evidence files. It shows the evidence as it was when you exported it: it cannot check the
  evidence files again. A browser that cannot run WebAssembly (for example,
  Safari in Lockdown Mode) shows the facts as recorded, without what-ifs. The engine adds about
  400 KB to the page.
- `fvtrace export --bundle DIR` writes the trace and copies of its evidence files. `DIR` must be
  outside the project folder. On another computer, go to `DIR/project` and run
  `fvtrace serve --trace ../trace.json`.
- `fvtrace serve` answers on this computer only. Each run makes a new secret link. With
  `--host ADDRESS`, computers on your network can open the page at that address. The page is
  not encrypted, so use `--host` only on a network that you trust.

## Use fvTrace with a coding agent

`fvtrace skills install` installs the fvTrace skill for Claude Code (`~/.claude/skills`) and for
agents that read `~/.agents/skills` (Codex, Gemini CLI, GitHub Copilot, Cursor). To install it
in another folder, add `--dir DIR`. `fvtrace skills show` prints the instructions.

The skill tells the agent to read the analysis, draft the trace honestly, run `fvtrace check`,
and show you the verdicts. The agent never marks a fact verified without evidence, and it never
signs off the trace: the review is yours.

## How fvTrace verifies itself

The rules that decide each verdict are Lean 4 definitions. The guarantees that the verdicts
rely on are Lean theorems, stated in `Fvtrace/Spec` and proved in `Fvtrace/Proofs`. Examples:
"Fully supported" holds only when every fact is verified with current evidence; "Conditional"
holds only when the facts that must be verified are verified; a claim with a human ruling for its
entailment reads neither of the two; a suggested plan is the best that the suggested experiments
allow. `bash tools/trust.sh` checks every proof again with independent
kernels (lean4lean and nanoda). It skips the check only when the same proofs, compiled by the same
toolchain, already passed it. The well-formedness check that `fvtrace check` applies to a
decoded trace is proved to accept exactly the well-formed traces; the JSON decoding before it is
tested, not proved.

`examples/fvtrace/trace.json` applies fvTrace to itself. Six of its claims read **Fully
supported**: each claim says what one or two Lean theorems prove, and its entailment fact is that
proof. Two claims read **Pending verification**, because facts that they need are tested but not
proved:

- The receipt claim ("Fully supported" means unchanged evidence) needs the file check of the
  receipts and the call of the verified HACL* SHA-256 code.
- An overlooked direction (no other site can read what `fvtrace serve` shows) needs the access
  check of the server.

Each proof fact of the self-trace also has a replay: `tools/statement.sh` builds fvTrace and
prints every definition that the theorem's statement uses. If one of these definitions changes
while the pinned proof files stay the same, `fvtrace verify --run` fails for that fact.

The exported page runs the same Lean definitions: `lake build` compiles them, with the Lean
runtime, to WebAssembly. A test gives the page's engine and the native engine (the code that the
`fvtrace` program runs) the same inputs: hundreds of what-ifs on several traces, invalid ones too.
It requires the same answers, byte for byte, in Node and in Chromium. This is a test, not a proof.

Like every analysis, the self-trace takes its instruments on trust: it does not list them for each
claim. fvTrace trusts these parts without verifying them: the Lean kernel and compiler, the C
compiler, the proofs of the HACL* SHA-256 code that fvTrace uses, the evidence files that you pin
(fvTrace checks their digests, not their content), every human ruling in the trace, and the
reading of each proved Lean statement in English. For an exported page, it also trusts
Emscripten, the browser, and the small program in the page that connects the engine to the page.
A reviewer checks that each sentence says what its theorem proves.

## Limits

- fvTrace does not run your analysis or prove anything about your data. It records what is
  verified and shows what follows.
- A plan shows coverage by the suggested experiments, not scientific priority.
- A what-if is a supposition. A review covers the recorded trace, never a what-if.

## Development

- `bash tools/gate.sh` runs every check: build, proofs and their independent replay, tests,
  the browser tests, the scanners and the format checks. CI runs the same command in parallel
  jobs, one for each group of checks.
- `bash tools/fast-gate.sh` runs the quick checks while you work.
- `bash tools/gate-probe.sh` shows that each purpose-built check fails on a planted error.
- `bash tools/pin-wasm.sh emsdk VERSION` or `bash tools/pin-wasm.sh lean VERSION` updates the
  pinned downloads of the engine build (`tools/wasm.lock`).

## License

Apache License 2.0 with LLVM exception. See `LICENSE`.
