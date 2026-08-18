#!/usr/bin/env python3
"""Read business workflows and data classes out of captured API traffic.

Input is a proxymock RRPair directory (--rrpair-dir) or a Speedscale snapshot
(--actions, optionally --reactions for downstream response bodies). Output is
classification.json plus a markdown report. Standard library only. To name the
workflows with a model, run name_workflows.py on the output afterwards.
"""
import argparse, base64, gzip, hashlib, json, os, re
from collections import Counter, defaultdict
from datetime import datetime, timezone

# ---- reading records ---------------------------------------------------------

INTERNAL_RE = re.compile(r"^json:\s*(\{.*\})\s*$")
FENCE_RE = re.compile(r"```\n(.*?)\n```", re.S)


def read_jsonl(path):
    with (gzip.open if path.endswith(".gz") else open)(path, "rt") as f:
        for line in f:
            if line.strip():
                yield json.loads(line)


def read_rrpair(text):
    """proxymock keeps headers and bodies only in the fenced REQUEST and RESPONSE
    blocks, not in the INTERNAL record, so merge them back or there is no identity
    and nothing to classify."""
    m = next((INTERNAL_RE.match(l.strip()) for l in text.split("\n") if l.startswith("json:")), None)
    if not m:
        return None
    rec = json.loads(m.group(1))
    req = rec.setdefault("http", {}).setdefault("req", {})
    res = rec["http"].setdefault("res", {})

    def blocks(name):
        i = text.find(f"### {name} ###")
        j = text.find("\n### ", i + 1)
        return [b.group(1) for b in FENCE_RE.finditer(text[i:j if j > 0 else None])] if i >= 0 else []

    b = blocks("REQUEST")
    if b:
        head, *hdrs = b[0].split("\n")
        parts = head.split()
        if len(parts) >= 2:
            path = re.sub(r"^https?://[^/]+", "", parts[1])
            req.setdefault("method", parts[0]); req.setdefault("uri", path); req.setdefault("url", path.split("?")[0])
        req.setdefault("headers", {k.strip(): [v.strip().replace("\\,", ",")] for k, _, v in (h.partition(":") for h in hdrs) if _})
        if len(b) > 1:
            req.setdefault("body", b[1])
    b = blocks("RESPONSE")
    if len(b) > 1:
        res.setdefault("body", b[1])
    return rec


def read_rrpair_dir(root):
    for d, dirs, files in os.walk(root):
        dirs[:] = [x for x in dirs if x != "results"]
        for name in sorted(files):
            if name.endswith(".md"):
                rec = read_rrpair(open(os.path.join(d, name)).read())
                if rec:
                    yield rec


# ---- one call ---------------------------------------------------------------

UUID_RE = re.compile(r"^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$", re.I)
IDENTITY_KEYS = ("usernameOrEmail", "username", "userName", "login", "email", "user_id", "userId")
IDENTITY_HEADERS = ("ss-api-key", "x-api-key", "api-key", "x-tenant-id", "tenant-id", "x-correlation-id", "x-session-id")
WRITE = {"POST", "PUT", "PATCH", "DELETE"}
RPC_WRITE = re.compile(r"^(create|update|delete|upload|send|put|set|post|add|remove|analyze|mutate|start|stop|run|apply|save|register)", re.I)


def template(url):
    segs = url.split("?")[0].split("/")
    return "/".join("{uuid}" if UUID_RE.match(s) else "{id}" if s.isdigit() else "{hash}" if re.fullmatch(r"[0-9a-f]{16,}", s, re.I) else s for s in segs) or "/"


def parse_ts(s):
    if not s:
        return None
    head, _, frac = s.rstrip("Z").partition(".")
    try:
        return datetime.fromisoformat(f"{head}.{frac[:6]}" if frac else head).replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def as_json(raw):
    try:
        v = json.loads(raw) if raw else None
        return v if isinstance(v, (dict, list)) else None
    except ValueError:
        return None


def identity(headers, body, query):
    """JWT subject, else a username/email in the body or query (so a login's anonymous
    prefix stitches to the authenticated calls after it), else a hashed API key or
    tenant header for machine callers."""
    auth = headers.get("authorization", "")
    if auth.startswith("Bearer ") and auth.count(".") >= 2:
        pl = auth.split(".")[1]
        try:
            c = json.loads(base64.urlsafe_b64decode(pl + "=" * (-len(pl) % 4)))
            if c.get("sub") or c.get("userId"):
                return str(c.get("sub") or c.get("userId")), "token"
        except Exception:
            pass
    vals = [body[k] for k in IDENTITY_KEYS if isinstance(body, dict) and isinstance(body.get(k), str)]
    vals += [m.group(1) for k in IDENTITY_KEYS for m in re.finditer(rf"[?&]{k}=([^&]+)", query, re.I)]
    for v in vals:
        if v.strip():
            return v.strip().split("@")[0], "payload"
    for h in IDENTITY_HEADERS:
        if headers.get(h):
            return f"{h}:{hashlib.sha256(headers[h].encode()).hexdigest()[:12]}", "header"
    return "", "none"


def to_call(rec):
    req = rec.get("http", {}).get("req") or {}
    res = rec.get("http", {}).get("res") or {}
    headers = {k.lower(): (v[0] if isinstance(v, list) and v else v) for k, v in (req.get("headers") or {}).items()}
    url = req.get("url") or rec.get("location") or ""
    method = (req.get("method") or rec.get("command") or "").upper()
    query = (req.get("uri") or "") + "".join(f"&{k}={v}" for k, vs in (req.get("queryParams") or {}).items() for v in (vs if isinstance(vs, list) else [vs]))
    body = as_json(req.get("body"))
    user, source = identity(headers, body, query)
    tags = rec.get("tags") or {}
    grpc = "grpc" in f"{rec.get('tech', '')}{rec.get('l7protocol', '')}".lower()
    rpc = url.rstrip("/").split("/")[-1]
    return {
        "ts": parse_ts(rec.get("ts")), "cluster": rec.get("cluster") or tags.get("k8sClusterName") or "unknown",
        "direction": rec.get("direction"), "method": method, "endpoint": f"{method} {template(url)}",
        "status": str(res.get("statusCode") or rec.get("status") or ""),
        "user": user, "identity_source": source, "req_body": body, "res_body": as_json(res.get("body")),
        # gRPC calls are all POST, so intent has to come from the RPC name.
        "write": bool(RPC_WRITE.match(rpc)) if grpc else method in WRITE,
    }


# ---- sessions, units of work, workflows ------------------------------------

def sessionize(calls, gap):
    """Per (cluster, identity), split on an idle gap. Cluster is in the key because one
    tenant can carry two environments running the same seeded users."""
    by = defaultdict(list)
    for c in calls:
        if c["user"]:
            by[(c["cluster"], c["user"])].append(c)
    out = []
    for (cluster, user), items in by.items():
        items.sort(key=lambda c: c["ts"] or datetime.min.replace(tzinfo=timezone.utc))
        cur = []
        for c in items:
            if cur and c["ts"] and cur[-1]["ts"] and (c["ts"] - cur[-1]["ts"]).total_seconds() > gap:
                out.append({"user": user, "cluster": cluster, "calls": cur}); cur = []
            cur.append(c)
        if cur:
            out.append({"user": user, "cluster": cluster, "calls": cur})
    return out


def segment(calls, read_gap):
    """A write plus the reads that verify it is one unit of work. Read-only stretches
    have no such anchor, so they split on a pause: a screen fires a burst, then a
    person sits still for an order of magnitude longer."""
    units, cur = [], []
    for c in calls:
        read_only = cur and not any(x["write"] for x in cur)
        paused = cur and c["ts"] and cur[-1]["ts"] and (c["ts"] - cur[-1]["ts"]).total_seconds() > read_gap
        if cur and (c["write"] or (read_only and paused)):
            units.append(cur); cur = []
        cur.append(c)
    return units + [cur] if cur else units


def collapse(seq, max_cycle=4):
    """Fold adjacent repeats and repeating cycles, so a poll of A>B>A>B reads as one thing."""
    out = [x for i, x in enumerate(seq) if i == 0 or x != seq[i - 1]]
    changed = True
    while changed:
        changed = False
        for n in range(1, max_cycle + 1):
            i = 0
            while i + 2 * n <= len(out):
                if out[i:i + n] == out[i + n:i + 2 * n]:
                    del out[i + n:i + 2 * n]; changed = True
                else:
                    i += 1
    return out


def cluster(sessions, read_gap, min_share=0.5):
    """Group units by (anchoring write, set of reads). Around a write, reads seen in
    a minority of that action's units are dropped from the key so one optional
    lookup does not fork a pattern. Read-only units key on exactly what they touched."""
    units = []
    for s in sessions:
        for u in segment(s["calls"], read_gap):
            anchor = next((c["endpoint"] for c in u if c["write"]), None)
            units.append((anchor, [c["endpoint"] for c in u if not c["write"]], u))
    freq, count = defaultdict(Counter), Counter()
    for anchor, reads, _ in units:
        count[anchor] += 1
        for e in set(reads):
            freq[anchor][e] += 1
    groups = defaultdict(list)
    for anchor, reads, u in units:
        key = frozenset(e for e in set(reads) if not anchor or freq[anchor][e] / count[anchor] >= min_share)
        groups[(anchor, key)].append(u)
    out = []
    for (anchor, _), members in groups.items():
        orderings = Counter(tuple(collapse([c["endpoint"] for c in u])) for u in members)
        calls = sum(len(u) for u in members)
        endpoints = sorted({c["endpoint"] for u in members for c in u})
        kind = ("action" if anchor else "polling" if len(endpoints) <= 2 and calls / len(members) > 3
                else "journey" if len(endpoints) > 1 else "single-read")
        out.append({"anchor": anchor, "steps": list(orderings.most_common(1)[0][0]), "endpoints": endpoints,
                    "kind": kind, "instances": len(members), "calls": calls,
                    "error_rate": round(sum(c["status"][:1] in "45" for u in members for c in u) / calls, 4)})
    return sorted(out, key=lambda w: (-w["instances"], -w["calls"]))


def fallback_name(w):
    def label(ep):
        method, _, path = ep.partition(" ")
        segs = [s for s in path.split("/") if s and not s.startswith("{") and s not in ("api", "v1", "v2")]
        if not segs:
            return method.lower()
        if len(segs) == 1:
            return f"{ {'POST': 'create', 'PUT': 'update', 'PATCH': 'update', 'DELETE': 'delete'}.get(method, 'list') } {segs[0]}"
        return f"{segs[-1]} {segs[0]}" if method in WRITE else f"view {segs[0]} {segs[-1]}"
    if w["anchor"]:
        reads = list(dict.fromkeys(label(s).split()[-1] for s in w["steps"] if s != w["anchor"]))
        return label(w["anchor"]) + (f", then check {', '.join(reads[:2])}" if reads else "")
    return "browse " + ", ".join(dict.fromkeys(label(s).split()[-1] for s in w["steps"]))


# ---- data classes -------------------------------------------------------------

KEY_RULES = [(c, re.compile(p)) for c, p in [
    ("credential", r"password|passwd|pwd|secret|api_?key|client_?secret|cvv|\bpin\b"),
    ("auth_token", r"token|bearer|jwt|session_?id|refresh"),
    ("government_id", r"\bssn\b|social_?security|tax_?id|national_?id|passport|driver_?licen"),
    ("payment_card", r"card_?number|\bpan\b|credit_?card|expiry|exp_?month|exp_?year"),
    ("bank_account", r"account_?number|iban|routing|swift|sort_?code"),
    ("person_name", r"first_?name|last_?name|full_?name|middle_?name|^name$|surname|holder"),
    ("email", r"email|e_?mail"), ("phone", r"phone|mobile|msisdn"),
    ("postal_address", r"address|street|city|state|zip|postal|country"),
    ("date_of_birth", r"birth|\bdob\b"), ("money", r"amount|balance|currency|price|total|fee|interest"),
    ("credentials_hint", r"username|user_?name|login"),
    ("free_text", r"description|notes?|comment|memo|message|reason|remarks?"),
    ("identifier", r"_?id$|^id$|uuid|guid|reference|number"), ("timestamp", r"_?at$|date|time|timestamp")]]
STRONG = [("government_id", re.compile(r"^\d{3}-\d{2}-\d{4}$")), ("auth_token", re.compile(r"^(Bearer\s+)?eyJ[\w-]+\.[\w-]+\.")),
          ("email", re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$"))]
WEAK = [("phone", re.compile(r"^(\+\d[\d\-\s().]{7,}|\(?\d{3}\)?[-\s.]\d{3}[-\s.]\d{4})$")),
        ("ip_address", re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")), ("date_of_birth", re.compile(r"^(19|20)\d\d-\d\d-\d\d$"))]
TIER = {"credential": "restricted", "government_id": "restricted", "payment_card": "restricted", "bank_account": "restricted",
        "auth_token": "confidential", "person_name": "confidential", "email": "confidential", "phone": "confidential",
        "postal_address": "confidential", "date_of_birth": "confidential", "money": "confidential", "free_text": "confidential"}
TIERS = ["restricted", "confidential", "internal", "public"]


def luhn(d):
    return sum(int(x) * (2 if i % 2 else 1) // 10 + int(x) * (2 if i % 2 else 1) % 10 for i, x in enumerate(reversed(d))) % 10 == 0


def classify_leaf(key, value):
    """Unambiguous value formats win, then the field name, then formats that only mean
    something without a name. Any other order tags a 12 digit account number as a phone."""
    text = value if isinstance(value, str) else ""
    digits = re.sub(r"[\s-]", "", text)
    if digits.isdigit() and 13 <= len(digits) <= 19 and luhn(digits):
        return "payment_card", False
    for cls, rx in STRONG:
        if text and rx.match(text.strip()):
            return cls, False
    for cls, rx in KEY_RULES:
        if rx.search(key.lower()):
            return cls, cls == "free_text" and len(text.split()) >= 3
    for cls, rx in WEAK:
        if text and rx.match(text.strip()):
            return cls, False
    return ("free_text", True) if len(text.split()) >= 5 else ("unclassified", False)


def walk(obj, prefix=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from walk(v, f"{prefix}.{k}" if prefix else k)
    elif isinstance(obj, list):
        for v in obj[:3]:
            yield from walk(v, prefix + "[]")
    else:
        yield prefix, obj


def classify_fields(calls):
    """Field-level data classes per endpoint and side. A prose field that only ever
    holds a handful of distinct strings is a status message, not user text."""
    seen = defaultdict(lambda: {"class": "unclassified", "n": 0, "prose": 0, "vals": set()})
    for c in calls:
        for side, body in (("request", c["req_body"]), ("response", c["res_body"])):
            for path, v in walk(body) if body is not None else []:
                if v in (None, ""):
                    continue
                cls, prose = classify_leaf(path.split(".")[-1].replace("[]", ""), v)
                e = seen[(c["endpoint"], side, path)]
                e["n"] += 1; e["prose"] += prose
                if len(e["vals"]) < 200:
                    e["vals"].add(str(v)[:120])
                if TIERS.index(TIER.get(cls, "internal")) < TIERS.index(TIER.get(e["class"], "internal")) or e["class"] == "unclassified":
                    e["class"] = cls
    rows = []
    for (ep, side, path), e in sorted(seen.items()):
        boilerplate = e["prose"] and len(e["vals"]) <= 20 and len(e["vals"]) < max(2, min(e["n"], 200) * 0.1)
        rows.append({"endpoint": ep, "side": side, "field": path, "class": e["class"], "tier": TIER.get(e["class"], "internal"),
                     "observations": e["n"], "unstructured_hits": 0 if boilerplate else e["prose"]})
    return rows


# ---- report -----------------------------------------------------------------

def render(m, path):
    s = m["source"]
    L = ["# Traffic classifier run", "", f"Source: `{s['input']}`  ", f"Window: {s['window_start']} to {s['window_end']}  ",
         f"Calls: {s['calls']} across {s['endpoints']} endpoints, {s['users']} identities, {s['sessions']} sessions  ",
         "Identity from: " + ", ".join(f"{k} {v}" for k, v in sorted(s["identity_sources"].items(), key=lambda kv: -kv[1])), ""]
    if len(s["clusters"]) > 1:
        L += ["## Source clusters", "", "More than one cluster reported into this capture; scope with `--cluster` or one "
              "environment's errors read as another's.", "", "| Cluster | Calls | Errors |", "| --- | ---: | ---: |"]
        L += [f"| `{c['cluster']}` | {c['calls']} | {c['errors']} |" for c in s["clusters"]] + [""]
    L += ["## Workflows", "", "| # | Workflow | Kind | Sessions | Calls | Steps | Errors | Data tier | Priority |",
          "| - | --- | --- | ---: | ---: | ---: | ---: | --- | --- |"]
    L += [f"| {i} | {w['name']} | {w['kind']} | {w['instances']} | {w['calls']} | {len(w['steps'])} | "
          f"{w['error_rate'] * 100:.1f}% | {w['tier']} | {w.get('priority', '')} |" for i, w in enumerate(m["workflows"], 1)]
    L += ["", "## Workflow detail", ""]
    for i, w in enumerate(m["workflows"], 1):
        L += [f"### {i}. {w['name']}", ""] + ([w["description"], ""] if w.get("description") else [])
        L += [f"{n}. `{st}`" for n, st in enumerate(w["steps"], 1)]
        if w["data_classes"]:
            L.append("\nData classes: " + ", ".join(f"`{c}` ({TIER.get(c, 'internal')})" for c in w["data_classes"]))
        L.append("")
    L += ["## Endpoint health", "", "| Endpoint | Calls | Errors | Status codes | Tier |", "| --- | ---: | ---: | --- | --- |"]
    L += [f"| `{e['endpoint']}` | {e['calls']} | {e['error_rate'] * 100:.1f}% | "
          f"{', '.join(f'{k} x{v}' for k, v in e['statuses'].items())} | {e['tier']} |" for e in m["endpoint_health"]]
    L += ["", "## Data classes by field", "", "| Endpoint | Side | Field | Class | Tier | Free text hits |", "| --- | --- | --- | --- | --- | ---: |"]
    L += [f"| `{r['endpoint']}` | {r['side']} | `{r['field']}` | {r['class']} | {r['tier']} | {r['unstructured_hits'] or ''} |"
          for r in m["fields"] if r["class"] != "unclassified"]
    L += ["", "## Coverage", ""]
    L += [f"- `{e}` seen in traffic but in no workflow" for e in m["uncovered_endpoints"]] or ["Every observed endpoint appears in a workflow."]
    open(path, "w").write("\n".join(L) + "\n")


# ---- main -------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--rrpair-dir", help="proxymock RRPair directory")
    ap.add_argument("--actions", help="snapshot action.jsonl (inbound), plain or .gz")
    ap.add_argument("--reactions", help="snapshot reaction.jsonl (downstream), for response bodies")
    ap.add_argument("--out-dir", default="out")
    ap.add_argument("--cluster", help="keep one k8s cluster when the capture holds several")
    ap.add_argument("--gap-seconds", type=float, default=120, help="idle time that ends a session")
    ap.add_argument("--read-gap-seconds", type=float, default=15, help="pause that ends a read-only unit of work")
    ap.add_argument("--min-sessions", type=int, default=2, help="drop patterns seen fewer times than this")
    a = ap.parse_args()
    if not (a.rrpair_dir or a.actions):
        ap.error("pass --rrpair-dir or --actions")

    recs = read_rrpair_dir(a.rrpair_dir) if a.rrpair_dir else read_jsonl(a.actions)
    calls = [c for c in map(to_call, recs) if c["direction"] != "OUT" and c["endpoint"].strip()]
    extra = [c for c in map(to_call, read_jsonl(a.reactions)) if c["res_body"] is not None] if a.reactions else []
    if a.rrpair_dir:  # downstream calls in a recording carry the response bodies
        extra = [c for c in map(to_call, read_rrpair_dir(a.rrpair_dir)) if c["direction"] == "OUT" and c["res_body"] is not None]
    clusters = Counter(c["cluster"] for c in calls)
    errors = Counter(c["cluster"] for c in calls if c["status"][:1] in "45")
    if a.cluster:
        calls = [c for c in calls if c["cluster"] == a.cluster]
        extra = [c for c in extra if c["cluster"] == a.cluster]
        if not calls:
            ap.error(f"no traffic from cluster {a.cluster!r}; saw {sorted(clusters)}")

    sessions = sessionize(calls, a.gap_seconds)
    workflows = [w for w in cluster(sessions, a.read_gap_seconds) if w["instances"] >= a.min_sessions]
    fields = classify_fields(calls + extra)
    tier_of, classes_of = {}, defaultdict(set)
    for r in fields:
        if r["class"] != "unclassified":
            classes_of[r["endpoint"]].add(r["class"])
        tier_of[r["endpoint"]] = min(tier_of.get(r["endpoint"], "public"), r["tier"], key=TIERS.index)
    for w in workflows:
        w["name"] = fallback_name(w)
        w["data_classes"] = sorted({c for e in w["endpoints"] for c in classes_of[e]})
        w["tier"] = min((tier_of.get(e, "public") for e in w["endpoints"]), key=TIERS.index)
    health = defaultdict(Counter)
    for c in calls:
        health[c["endpoint"]][c["status"] or "?"] += 1
    endpoint_health = sorted(({"endpoint": e, "calls": sum(st.values()), "statuses": dict(st.most_common(5)),
                               "error_rate": round(sum(n for k, n in st.items() if k[:1] in "45") / sum(st.values()), 4),
                               "tier": tier_of.get(e, "public")} for e, st in health.items()),
                             key=lambda e: (-e["error_rate"], -e["calls"]))
    times = [c["ts"] for c in calls if c["ts"]]
    model = {
        "source": {"input": a.rrpair_dir or a.actions, "window_start": min(times).isoformat() if times else "",
                   "window_end": max(times).isoformat() if times else "", "calls": len(calls),
                   "endpoints": len(health), "users": len({c["user"] for c in calls if c["user"]}), "sessions": len(sessions),
                   "identity_sources": dict(Counter(c["identity_source"] for c in calls)), "cluster_filter": a.cluster or "",
                   "clusters": [{"cluster": k, "calls": n, "errors": errors[k]} for k, n in clusters.most_common()]},
        "workflows": workflows, "endpoint_health": endpoint_health, "fields": fields,
        "uncovered_endpoints": sorted(set(health) - {e for w in workflows for e in w["endpoints"]}),
    }
    os.makedirs(a.out_dir, exist_ok=True)
    json.dump(model, open(os.path.join(a.out_dir, "classification.json"), "w"), indent=2, default=str)
    render(model, os.path.join(a.out_dir, "report.md"))
    print(f"{len(calls)} calls, {len(sessions)} sessions, {len(workflows)} workflow patterns -> {a.out_dir}/report.md")


if __name__ == "__main__":
    main()
