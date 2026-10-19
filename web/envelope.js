// Decodes the engine's evaluation envelope (fvtrace.evaluation/1). Fetched JSON stays `unknown`
// until it passes here; a shape the GUI does not know is an error, never a guess.

/** @typedef {"can" | "conditional" | "open" | "cannot"} State */
/** @typedef {{ fact: string, status: string }} Override */
/** @typedef {{ claim: string, from: State, to: State }} Move */
/** @typedef {{ path: string, sha256?: string, role?: string }} Artifact */
/**
 * @typedef {{ summary: string, artifacts: Artifact[], verifier?: string, statement?: string,
 *   statementDigest?: string }} Evidence
 */
/**
 * @typedef {{ id: string, subject: string, kind: string, text: string, route: string,
 *   recorded: string, effective: string, closable: boolean, supposed: boolean,
 *   derivedFrom: { exclusion: string, source: string }[], trusts: string[],
 *   evidence?: Evidence, receipt?: { current: boolean, reasons: string[] } }} Fact
 */
/**
 * @typedef {{ need: string, experiment: string, status: string }} Alternative
 * @typedef {{ result: "planned" | "noImprovement" | "inconsistent" | "tooLarge",
 *   experiments: string[], state?: State, planPremises: string[], planGaps: string[],
 *   contingent: boolean, premises: string[], gaps: string[], uncovered: string[],
 *   alternatives: Alternative[] }} Plan
 */
/**
 * @typedef {{ id: string, question: string, subject: string, level: string, text: string,
 *   latent: boolean, needs: string[], entailment: string, final: State, intrinsic: State,
 *   sentence: string, verdict: string, qualifiers: string[], verified: string[],
 *   premises: string[], gaps: string[], blockers: string[], incompatible: string[],
 *   conflicts: string[], hypothetical: boolean, provisional: boolean, plan: Plan,
 *   variantOf?: string }} Claim
 */
/**
 * @typedef {{ id: string, subject: string, kind: "dry" | "wet", effort: string, title: string,
 *   method: string, resources: string, caveat: string, success: Override[],
 *   failure: Override[], requires: string[], closure: string[], applied: boolean,
 *   contingent: boolean, prospective: boolean, wins: Move[], losses: Move[], lights: number,
 *   clears: number, breaks: number }} Experiment
 */
/**
 * @typedef {{ id: string, kind: "suppose" | "success" | "failure" | "plan", target: string,
 *   overrides: Override[] }} Action
 */
/**
 * @typedef {{ mode: "recorded" | "what-if", overrides: Override[],
 *   review: { state: "draft" | "stale" | "reviewed", reviewer?: string, date?: string },
 *   analysis: { id: string, title: string, summary: string },
 *   subjects: { id: string, title: string, kind: string, valid: boolean }[],
 *   counts: Record<State, number>, questions: { id: string, title: string, text: string }[],
 *   facts: Fact[], claims: Claim[], work: { fact: string, unlocks: string[], gates: string[] }[],
 *   blockers: { fact: string, claims: string[] }[], experiments: Experiment[],
 *   lints: { rule: string, claim: string, message: string, waived?: string }[],
 *   actions: Action[] }} Envelope
 */

export class DecodeError extends Error {}

/** @param {string} path @param {string} want @returns {never} */
function fail(path, want) {
  throw new DecodeError(`${path || "the response"}: expected ${want}`);
}

/** @param {unknown} v @returns {v is Record<string, unknown>} */
function isRecord(v) {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

/** @param {unknown} v @param {string} path @returns {Record<string, unknown>} */
function obj(v, path) {
  return isRecord(v) ? v : fail(path, "an object");
}

/** @param {unknown} v @param {string} path */
function str(v, path) {
  return typeof v === "string" ? v : fail(path, "a string");
}

/** @param {unknown} v @param {string} path */
function num(v, path) {
  return typeof v === "number" && Number.isInteger(v) ? v : fail(path, "an integer");
}

/** @param {unknown} v @param {string} path */
function bool(v, path) {
  return typeof v === "boolean" ? v : fail(path, "true or false");
}

/**
 * @template T
 * @param {unknown} v @param {string} path @param {(item: unknown, at: string) => T} item
 * @returns {T[]}
 */
function arr(v, path, item) {
  if (!Array.isArray(v)) fail(path, "an array");
  return v.map((x, i) => item(x, `${path}/${i}`));
}

/** @param {unknown} v @param {string} path */
function strs(v, path) {
  return arr(v, path, str);
}

/**
 * @template {string} T
 * @param {readonly T[]} allowed @param {string} s @returns {s is T}
 */
function isOneOf(allowed, s) {
  return allowed.some((a) => a === s);
}

/**
 * @template {string} T
 * @param {unknown} v @param {string} path @param {readonly T[]} allowed @returns {T}
 */
function oneOf(v, path, allowed) {
  const s = str(v, path);
  return isOneOf(allowed, s) ? s : fail(path, allowed.join(" | "));
}

const states = /** @type {const} */ (["can", "conditional", "open", "cannot"]);

/** @param {unknown} v @param {string} path @returns {State} */
function state(v, path) {
  return oneOf(v, path, states);
}

/** @param {unknown} v @param {string} path @returns {Override[]} */
function overrides(v, path) {
  return arr(v, path, (o, at) => {
    const r = obj(o, at);
    return { fact: str(r["fact"], `${at}/fact`), status: str(r["status"], `${at}/status`) };
  });
}

/** An outcome object `{fact: status}` as overrides. @param {unknown} v @param {string} path */
function outcome(v, path) {
  return Object.entries(obj(v, path)).map(([id, s]) => ({
    fact: id,
    status: str(s, `${path}/${id}`),
  }));
}

/** @param {unknown} v @param {string} path @returns {Move[]} */
function moves(v, path) {
  return arr(v, path, (m, at) => {
    const r = obj(m, at);
    return {
      claim: str(r["claim"], `${at}/claim`),
      from: state(r["from"], `${at}/from`),
      to: state(r["to"], `${at}/to`),
    };
  });
}

/** The optional string `key` of `r`. @param {Record<string, unknown>} r @param {string} key @param {string} path */
function opt(r, key, path) {
  return key in r ? str(r[key], `${path}/${key}`) : undefined;
}

/** @param {unknown} v @param {string} path @returns {Evidence} */
function evidence(v, path) {
  const r = obj(v, path);
  const verifier = opt(r, "verifier", path);
  const statement = opt(r, "statement", path);
  const statementDigest = opt(r, "statementDigest", path);
  return {
    summary: str(r["summary"], `${path}/summary`),
    artifacts: arr(r["artifacts"] ?? [], `${path}/artifacts`, (a, at) => {
      const x = obj(a, at);
      const sha256 = opt(x, "sha256", at);
      const role = opt(x, "role", at);
      return {
        path: str(x["path"], `${at}/path`),
        ...(sha256 === undefined ? {} : { sha256 }),
        ...(role === undefined ? {} : { role }),
      };
    }),
    ...(verifier === undefined ? {} : { verifier }),
    ...(statement === undefined ? {} : { statement }),
    ...(statementDigest === undefined ? {} : { statementDigest }),
  };
}

/** @param {unknown} v @param {string} path @returns {Fact} */
function fact(v, path) {
  const r = obj(v, path);
  /** @type {Fact} */
  const f = {
    id: str(r["id"], `${path}/id`),
    subject: str(r["subject"], `${path}/subject`),
    kind: str(r["kind"], `${path}/kind`),
    text: str(r["text"], `${path}/text`),
    route: str(r["route"], `${path}/route`),
    recorded: str(r["recorded"], `${path}/recorded`),
    effective: str(r["effective"], `${path}/effective`),
    closable: bool(r["closable"], `${path}/closable`),
    supposed: bool(r["supposed"], `${path}/supposed`),
    derivedFrom: arr(r["derivedFrom"], `${path}/derivedFrom`, (d, at) => {
      const x = obj(d, at);
      return {
        exclusion: str(x["exclusion"], `${at}/exclusion`),
        source: str(x["source"], `${at}/source`),
      };
    }),
    trusts: strs(r["trusts"], `${path}/trusts`),
  };
  if ("evidence" in r) f.evidence = evidence(r["evidence"], `${path}/evidence`);
  if ("receipt" in r) {
    const x = obj(r["receipt"], `${path}/receipt`);
    f.receipt = {
      current: bool(x["current"], `${path}/receipt/current`),
      reasons: strs(x["reasons"], `${path}/receipt/reasons`),
    };
  }
  return f;
}

/** @param {unknown} v @param {string} path @returns {Plan} */
function plan(v, path) {
  const r = obj(v, path);
  const result = oneOf(r["result"], `${path}/result`, [
    "planned",
    "noImprovement",
    "inconsistent",
    "tooLarge",
  ]);
  const planned = result === "planned";
  /** @type {Plan} */
  const p = {
    result,
    experiments: planned ? strs(r["experiments"], `${path}/experiments`) : [],
    planPremises: planned ? strs(r["planPremises"], `${path}/planPremises`) : [],
    planGaps: planned ? strs(r["planGaps"], `${path}/planGaps`) : [],
    contingent: planned ? bool(r["contingent"], `${path}/contingent`) : false,
    premises: strs(r["premises"], `${path}/premises`),
    gaps: strs(r["gaps"], `${path}/gaps`),
    uncovered: strs(r["uncovered"], `${path}/uncovered`),
    alternatives: arr(r["alternatives"], `${path}/alternatives`, (a, at) => {
      const x = obj(a, at);
      return {
        need: str(x["need"], `${at}/need`),
        experiment: str(x["experiment"], `${at}/experiment`),
        status: str(x["status"], `${at}/status`),
      };
    }),
  };
  if (planned) p.state = state(r["state"], `${path}/state`);
  return p;
}

/** @param {unknown} v @param {string} path @returns {Claim} */
function claim(v, path) {
  const r = obj(v, path);
  const label = obj(r["label"], `${path}/label`);
  /** @type {Claim} */
  const c = {
    id: str(r["id"], `${path}/id`),
    question: str(r["question"], `${path}/question`),
    subject: str(r["subject"], `${path}/subject`),
    level: str(r["level"], `${path}/level`),
    text: str(r["text"], `${path}/text`),
    latent: bool(r["latent"], `${path}/latent`),
    needs: strs(r["needs"], `${path}/needs`),
    entailment: str(r["entailment"], `${path}/entailment`),
    final: state(r["final"], `${path}/final`),
    intrinsic: state(r["intrinsic"], `${path}/intrinsic`),
    sentence: str(r["sentence"], `${path}/sentence`),
    verdict: str(label["verdict"], `${path}/label/verdict`),
    qualifiers: strs(label["qualifiers"], `${path}/label/qualifiers`),
    verified: strs(r["verified"], `${path}/verified`),
    premises: strs(r["premises"], `${path}/premises`),
    gaps: strs(r["gaps"], `${path}/gaps`),
    blockers: strs(r["blockers"], `${path}/blockers`),
    incompatible: strs(r["incompatible"], `${path}/incompatible`),
    conflicts: strs(r["conflicts"], `${path}/conflicts`),
    hypothetical: bool(r["hypothetical"], `${path}/hypothetical`),
    provisional: bool(r["provisional"], `${path}/provisional`),
    plan: plan(r["plan"], `${path}/plan`),
  };
  if ("variantOf" in r) c.variantOf = str(r["variantOf"], `${path}/variantOf`);
  return c;
}

/** @param {unknown} v @param {string} path @returns {Experiment} */
function experiment(v, path) {
  const r = obj(v, path);
  return {
    id: str(r["id"], `${path}/id`),
    subject: str(r["subject"], `${path}/subject`),
    kind: oneOf(r["kind"], `${path}/kind`, ["dry", "wet"]),
    effort: str(r["effort"], `${path}/effort`),
    title: str(r["title"], `${path}/title`),
    method: str(r["method"], `${path}/method`),
    resources: str(r["resources"], `${path}/resources`),
    caveat: str(r["caveat"], `${path}/caveat`),
    success: outcome(r["success"], `${path}/success`),
    failure: outcome(r["failure"], `${path}/failure`),
    requires: strs(r["requires"], `${path}/requires`),
    closure: strs(r["closure"], `${path}/closure`),
    applied: bool(r["applied"], `${path}/applied`),
    contingent: bool(r["contingent"], `${path}/contingent`),
    prospective: bool(r["prospective"], `${path}/prospective`),
    wins: moves(r["wins"], `${path}/wins`),
    losses: moves(r["losses"], `${path}/losses`),
    lights: num(r["lights"], `${path}/lights`),
    clears: num(r["clears"], `${path}/clears`),
    breaks: num(r["breaks"], `${path}/breaks`),
  };
}

/** @param {unknown} json @returns {Envelope} */
export function decodeEnvelope(json) {
  const r = obj(json, "");
  if (r["schema"] !== "fvtrace.evaluation/1") fail("/schema", '"fvtrace.evaluation/1"');
  const trace = obj(r["trace"], "/trace");
  const review = obj(trace["review"], "/trace/review");
  /** @type {Envelope["review"]} */
  const rv = {
    state: oneOf(review["state"], "/trace/review/state", ["draft", "stale", "reviewed"]),
  };
  if ("reviewer" in review) rv.reviewer = str(review["reviewer"], "/trace/review/reviewer");
  if ("date" in review) rv.date = str(review["date"], "/trace/review/date");
  const analysis = obj(r["analysis"], "/analysis");
  const counts = obj(r["counts"], "/counts");
  return {
    mode: oneOf(r["mode"], "/mode", ["recorded", "what-if"]),
    overrides: overrides(r["overrides"], "/overrides"),
    review: rv,
    analysis: {
      id: str(analysis["id"], "/analysis/id"),
      title: str(analysis["title"], "/analysis/title"),
      summary: str(analysis["summary"], "/analysis/summary"),
    },
    subjects: arr(r["subjects"], "/subjects", (s, at) => {
      const x = obj(s, at);
      return {
        id: str(x["id"], `${at}/id`),
        title: str(x["title"], `${at}/title`),
        kind: str(x["kind"], `${at}/kind`),
        valid: bool(x["valid"], `${at}/valid`),
      };
    }),
    counts: {
      can: num(counts["can"], "/counts/can"),
      conditional: num(counts["conditional"], "/counts/conditional"),
      open: num(counts["open"], "/counts/open"),
      cannot: num(counts["cannot"], "/counts/cannot"),
    },
    questions: arr(r["questions"], "/questions", (q, at) => {
      const x = obj(q, at);
      return {
        id: str(x["id"], `${at}/id`),
        title: str(x["title"], `${at}/title`),
        text: str(x["text"], `${at}/text`),
      };
    }),
    facts: arr(r["facts"], "/facts", fact),
    claims: arr(r["claims"], "/claims", claim),
    work: arr(r["work"], "/work", (w, at) => {
      const x = obj(w, at);
      return {
        fact: str(x["fact"], `${at}/fact`),
        unlocks: strs(x["unlocks"], `${at}/unlocks`),
        gates: strs(x["gates"], `${at}/gates`),
      };
    }),
    blockers: arr(r["blockers"], "/blockers", (b, at) => {
      const x = obj(b, at);
      return { fact: str(x["fact"], `${at}/fact`), claims: strs(x["claims"], `${at}/claims`) };
    }),
    experiments: arr(r["experiments"], "/experiments", experiment),
    lints: arr(r["lints"], "/lints", (l, at) => {
      const x = obj(l, at);
      /** @type {{ rule: string, claim: string, message: string, waived?: string }} */
      const out = {
        rule: str(x["rule"], `${at}/rule`),
        claim: str(x["claim"], `${at}/claim`),
        message: str(x["message"], `${at}/message`),
      };
      if ("waived" in x) out.waived = str(x["waived"], `${at}/waived`);
      return out;
    }),
    actions: arr(r["actions"], "/actions", (a, at) => {
      const x = obj(a, at);
      return {
        id: str(x["id"], `${at}/id`),
        kind: oneOf(x["kind"], `${at}/kind`, ["suppose", "success", "failure", "plan"]),
        target: str(x["target"], `${at}/target`),
        overrides: overrides(x["overrides"], `${at}/overrides`),
      };
    }),
  };
}

/**
 * The server's `{problem: {kind, message}}` reply, if `json` is one.
 * @param {unknown} json @returns {{ kind: string, message: string } | undefined}
 */
export function decodeProblem(json) {
  if (typeof json !== "object" || json === null || !("problem" in json)) return undefined;
  const p = obj(json.problem, "/problem");
  return { kind: str(p["kind"], "/problem/kind"), message: str(p["message"], "/problem/message") };
}
