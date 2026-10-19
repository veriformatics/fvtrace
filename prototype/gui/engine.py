"""fvTrace prototype engine: deterministic claim states from a trace.

FV stance: only `proved` + `checked` obligations count as verified. `assumed` =
a declared premise ⇒ the claim stands in conditional form. `tested` + `open` =
gaps. `violated` = evidence against ⇒ the claim cannot be made as written.
"""

VERIFIED = {"proved", "checked"}
STATUSES = ("proved", "checked", "assumed", "tested", "open", "violated")


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
        "draft": {**trace.get("draft", {}), "sentences": sentences},
        "counts": counts,
        "overrides": overrides,
    }
