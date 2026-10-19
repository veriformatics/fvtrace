"""fvTrace prototype engine: deterministic claim states from a trace.

FV stance: only `proved` + `checked` obligations count as verified. `assumed` =
a declared premise ⇒ the claim stands in conditional form. `tested` + `open` =
gaps. `violated` = evidence against ⇒ the claim cannot be made as written.
"""

VERIFIED = {"proved", "checked"}
STATUSES = ("proved", "checked", "assumed", "tested", "open", "violated")
RANK = {"cannot": 0, "open": 1, "conditional": 2, "can": 3}
EFFORT = ("hours", "days", "weeks", "months")
STRENGTH = {"violated": 0, "open": 1, "tested": 1, "assumed": 2, "checked": 3, "proved": 3}


def claim_state(needs, status):
    sts = [status[o] for o in needs]
    if "violated" in sts:
        return "cannot"
    if all(s in VERIFIED for s in sts):
        return "can"
    if all(s in VERIFIED or s == "assumed" for s in sts):
        return "conditional"
    return "open"


def evaluate(trace, overrides=None):
    """overrides = {obligation_id: status}: hypothetical what-if statuses."""
    overrides = {k: v for k, v in (overrides or {}).items() if v in STATUSES}
    obls = {o["id"]: o for o in trace["obligations"]}
    status = {i: overrides.get(i, o["status"]) for i, o in obls.items()}

    claims = []
    for c in trace["claims"]:
        needs = c["needs"]
        st = claim_state(needs, status)
        claims.append({
            **c,
            "state": st,
            "verified": [o for o in needs if status[o] in VERIFIED],
            "premises": [o for o in needs if status[o] == "assumed"],
            "gaps": [o for o in needs if status[o] in ("tested", "open")],
            "blockers": [o for o in needs if status[o] == "violated"],
        })
    by_id = {c["id"]: c for c in claims}

    # Where FV work pays: per unverified obligation, the claims that verifying it
    # alone would move to can/conditional (`unlocks`) + every live claim it gates.
    work = []
    for oid, o in obls.items():
        if status[oid] in VERIFIED:
            continue
        gated = [c["id"] for c in claims if oid in c["needs"]]
        trial = {**status, oid: "proved"}
        unlocks = [cid for cid in gated
                   if by_id[cid]["state"] in ("open", "cannot")
                   and claim_state(by_id[cid]["needs"], trial) in ("can", "conditional")]
        work.append({"id": oid, "status": status[oid], "route": o.get("route"),
                     "gates": gated, "unlocks": unlocks})
    work.sort(key=lambda w: (-len(w["unlocks"]), -len(w["gates"]), w["id"]))

    # Experiments: each outcome = a what-if on top of the current statuses.
    # `lights` = claims an outcome moves up into can|conditional; `clears` = cannot → open.
    def moves(outcome):
        trial = {**status, **outcome}
        out = []
        for c in claims:
            to = claim_state(c["needs"], trial)
            if to != c["state"]:
                out.append({"claim": c["id"], "from": c["state"], "to": to,
                            "remaining": [o for o in c["needs"] if trial[o] not in VERIFIED]})
        return out

    exps = trace.get("experiments", [])
    experiments = []
    for e in exps:
        win, lose = moves(e["success"]), moves(e["failure"])
        experiments.append({
            **e,
            "applied": all(overrides.get(o) == s for o, s in e["success"].items()),
            "wins": win, "losses": lose,
            "lights": sum(m["to"] in ("can", "conditional") and RANK[m["to"]] > RANK[m["from"]] for m in win),
            "clears": sum(m["from"] == "cannot" and m["to"] == "open" for m in win),
            "breaks": sum(m["to"] == "cannot" for m in lose),
        })
    experiments.sort(key=lambda e: (-e["lights"], -e["clears"], EFFORT.index(e["effort"]), int(e["id"][1:])))

    # Per-claim plan: the cheapest experiment raising each unverified need;
    # `uncovered` = gaps no experiment raises (a ruling or new method needed).
    cost = lambda e: (EFFORT.index(e["effort"]), int(e["id"][1:]))
    for c in claims:
        if c["state"] == "can":
            continue
        pick, uncovered = [], []
        for o in c["needs"]:
            if status[o] in VERIFIED:
                continue
            fits = [e for e in exps if STRENGTH[e["success"].get(o, "violated")] > STRENGTH[status[o]]]
            if fits:
                best = min(fits, key=cost)
                if best not in pick:
                    pick.append(best)
            elif status[o] != "assumed":
                uncovered.append(o)
        trial = {**status, **{o: s for e in pick for o, s in e["success"].items()}}
        c["plan"] = {"experiments": [e["id"] for e in sorted(pick, key=cost)], "uncovered": uncovered,
                     "state": claim_state(c["needs"], trial)}

    sentences = []
    for s in trace.get("draft", {}).get("sentences", []):
        states = [by_id[c]["state"] for c in s["claims"]]
        verdict = ("overstated" if any(x in ("open", "cannot") for x in states)
                   else "needs-premise" if "conditional" in states else "supported")
        sentences.append({**s, "verdict": verdict})

    counts = {k: sum(c["state"] == k for c in claims) for k in ("can", "conditional", "open", "cannot")}
    return {
        "analysis": trace["analysis"],
        "questions": trace["questions"],
        "obligations": [{**o, "status": status[o["id"]], "base_status": o["status"]} for o in obls.values()],
        "claims": claims,
        "work": work,
        "experiments": experiments,
        "draft": {**trace.get("draft", {}), "sentences": sentences},
        "counts": counts,
        "overrides": overrides,
    }
