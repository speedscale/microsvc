#!/usr/bin/env python3
"""Classify captured API traffic into user sessions, business workflows, and data classes.

Input is either a Speedscale snapshot's action.jsonl (inbound RRPairs) or a
directory of proxymock RRPair .md files. Output is a JSON model plus a markdown
report. LLM naming is optional and only ever sees field names, never values.
"""

import argparse
import base64
import binascii
import gzip
import hashlib
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone

# --- parsing -----------------------------------------------------------------

UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.I)
HEX_RE = re.compile(r"^[0-9a-f]{16,}$", re.I)
INTERNAL_RE = re.compile(r"^json:\s*(\{.*\})\s*$")


def parse_ts(s):
    if not s:
        return None
    s = s.rstrip("Z")
    if "." in s:
        head, frac = s.split(".", 1)
        s = f"{head}.{frac[:6]}"
    try:
        return datetime.fromisoformat(s).replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def load_actions(path):
    """Read a snapshot action.jsonl (one RRPair object per line), plain or gzipped."""
    opener = gzip.open if path.endswith(".gz") else open
    with opener(path, "rt") as f:
        for line in f:
            line = line.strip()
            if line:
                yield json.loads(line)


FENCE_RE = re.compile(r"```\n(.*?)\n```", re.S)


def parse_rrpair_md(text):
    """Turn one proxymock RRPair markdown file into the snapshot record shape.

    The INTERNAL block carries the envelope (service, direction, timestamps,
    signature) but not headers or bodies; those live only in the fenced blocks
    under REQUEST and RESPONSE. Without reading them there is no identity and
    nothing to classify, so both are merged back into the record.
    """
    rec = None
    for line in text.split("\n"):
        m = INTERNAL_RE.match(line.strip())
        if m:
            rec = json.loads(m.group(1))
            break
    if rec is None:
        return None
    http = rec.setdefault("http", {})
    req = http.setdefault("req", {})
    res = http.setdefault("res", {})

    def section(name):
        start = text.find(f"### {name} ###")
        if start < 0:
            return []
        end = text.find("\n### ", start + 1)
        return [b.group(1) for b in FENCE_RE.finditer(text[start:end if end > 0 else len(text)])]

    def headers_of(block):
        out = {}
        for hl in block.split("\n")[1:]:
            k, sep, v = hl.partition(":")
            if sep:
                out.setdefault(k.strip(), []).append(v.strip().replace("\\,", ","))
        return out

    blocks = section("REQUEST")
    if blocks:
        first = blocks[0].split("\n", 1)[0].split()
        if len(first) >= 2:
            req.setdefault("method", first[0])
            target = first[1]
            path = re.sub(r"^https?://[^/]+", "", target)
            req.setdefault("uri", path)
            req.setdefault("url", path.split("?")[0])
        req.setdefault("headers", headers_of(blocks[0]))
        if len(blocks) > 1 and "body" not in req:
            req["body"] = blocks[1]
    blocks = section("RESPONSE")
    if blocks and len(blocks) > 1 and "body" not in res:
        res["body"] = blocks[1]
    return rec


def load_rrpair_dir(root):
    """Read proxymock RRPair .md files, merging headers and bodies from the visible blocks."""
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != "results"]
        for name in sorted(filenames):
            if not name.endswith(".md"):
                continue
            with open(os.path.join(dirpath, name)) as f:
                rec = parse_rrpair_md(f.read())
            if rec is not None:
                yield rec


def template(url):
    """Collapse identifier path segments so endpoints group across users."""
    parts = []
    for seg in url.split("?")[0].split("/"):
        if UUID_RE.match(seg):
            parts.append("{uuid}")
        elif seg.isdigit():
            parts.append("{id}")
        elif HEX_RE.match(seg):
            parts.append("{hash}")
        else:
            parts.append(seg)
    return "/".join(parts) or "/"


def jwt_claims(auth_header):
    if not auth_header.startswith("Bearer "):
        return {}
    parts = auth_header.split(".")
    if len(parts) < 2:
        return {}
    payload = parts[1] + "=" * (-len(parts[1]) % 4)
    try:
        return json.loads(base64.urlsafe_b64decode(payload))
    except (ValueError, binascii.Error, UnicodeDecodeError):
        return {}


def body_json(raw):
    if not raw:
        return None
    try:
        parsed = json.loads(raw)
    except ValueError:
        return None
    return parsed if isinstance(parsed, (dict, list)) else None


IDENTITY_KEYS = ("usernameOrEmail", "username", "userName", "login", "email", "user_id", "userId")

# Machine-to-machine traffic has no user subject. An API key identifies the
# calling tenant or agent and is the closest thing to a session key, so it is
# hashed (never stored or reported in the clear) and used as the identity.
IDENTITY_HEADERS = ("ss-api-key", "x-api-key", "api-key", "x-tenant-id", "tenant-id",
                    "x-correlation-id", "x-session-id")


def identity_from_headers(headers):
    for name in IDENTITY_HEADERS:
        value = headers.get(name)
        if value:
            digest = hashlib.sha256(value.encode()).hexdigest()[:12]
            return f"{name}:{digest}"
    return ""


def identity_from_body(body, query):
    """Correlation key for calls made before a token exists (login, signup).

    Emails are reduced to the local part because the demo issues tokens whose
    subject is the username and whose email is username@domain -- the same rule
    is what lets a pre-auth prefix stitch onto the authenticated remainder.
    """
    candidates = []
    if isinstance(body, dict):
        candidates += [body[k] for k in IDENTITY_KEYS if isinstance(body.get(k), str)]
    for k in IDENTITY_KEYS:
        for m in re.finditer(rf"[?&]{k}=([^&]+)", query or "", re.I):
            candidates.append(m.group(1))
    for value in candidates:
        value = value.strip()
        if value:
            return value.split("@")[0]
    return ""


def to_call(rec):
    http = rec.get("http") or {}
    req = http.get("req") or {}
    res = http.get("res") or {}
    headers = {k.lower(): (v[0] if isinstance(v, list) and v else v)
               for k, v in (req.get("headers") or {}).items()}
    claims = jwt_claims(headers.get("authorization", "") or "")
    url = req.get("url") or rec.get("location") or ""
    req_body = body_json(req.get("body"))
    # url drops the query string; uri and queryParams keep it, and pre-auth
    # lookups such as check-username carry their identity there.
    query = req.get("uri") or ""
    for key, values in (req.get("queryParams") or {}).items():
        for value in values if isinstance(values, list) else [values]:
            query += f"&{key}={value}"
    subject = str(claims.get("sub") or claims.get("userId") or "")
    fallback = identity_from_body(req_body, query) or identity_from_headers(headers)
    tags = rec.get("tags") or {}
    return {
        "ts": parse_ts(rec.get("ts")),
        "service": rec.get("service"),
        # gRPC records carry l7protocol "https" and tech "gRPC", so the
        # transport field alone would hide it.
        "protocol": ("grpc" if "grpc" in f"{rec.get('tech','')}{rec.get('l7protocol','')}".lower()
                     else (rec.get("l7protocol") or "").lower()),
        "cluster": rec.get("cluster") or tags.get("k8sClusterName") or "unknown",
        "namespace": rec.get("namespace") or tags.get("k8sAppPodNamespace") or "",
        "direction": rec.get("direction"),
        "method": (req.get("method") or rec.get("command") or "").upper(),
        "url": url,
        "endpoint": f"{(req.get('method') or rec.get('command') or '').upper()} {template(url)}",
        "status": str(res.get("statusCode") or rec.get("status") or ""),
        "duration_ms": rec.get("duration"),
        "user": subject or fallback,
        "identity_source": ("token" if subject
                            else ("header" if fallback.split(":")[0] in IDENTITY_HEADERS
                                  else ("payload" if fallback else "none"))),
        "trace": (headers.get("traceparent") or "").split("-")[1] if headers.get("traceparent") else "",
        "request_id": headers.get("x-request-id", ""),
        "req_body": req_body,
        "res_body": body_json(res.get("body")),
        "has_auth": bool(claims),
    }


# --- sessions and workflows ---------------------------------------------------

def sessionize(calls, gap_seconds):
    """Group a user's calls into sessions, splitting on an idle gap.

    Keyed on (cluster, identity): one tenant can receive traffic from several
    clusters, and identities are only unique within one of them. Without the
    cluster in the key, two environments running the same seeded user pool
    braid into a single fictitious session.
    """
    by_user = defaultdict(list)
    anonymous = []
    for c in calls:
        (by_user[(c["cluster"], c["user"])] if c["user"] else anonymous).append(c)

    sessions = []
    for (cluster, user), items in by_user.items():
        items.sort(key=lambda c: c["ts"] or datetime.min.replace(tzinfo=timezone.utc))
        current = []
        for call in items:
            if current and call["ts"] and current[-1]["ts"]:
                if (call["ts"] - current[-1]["ts"]).total_seconds() > gap_seconds:
                    sessions.append({"user": user, "cluster": cluster, "calls": current})
                    current = []
            current.append(call)
        if current:
            sessions.append({"user": user, "cluster": cluster, "calls": current})
    return sessions, anonymous


WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

# gRPC sends every call as POST, so the HTTP method carries no read/write
# signal and method-based segmentation collapses to one call per workflow.
# The RPC name is where the intent lives.
RPC_READ_RE = re.compile(r"^(retrieve|get|list|describe|fetch|read|watch|listen|query|search|count)",
                         re.I)
RPC_WRITE_RE = re.compile(r"^(create|update|delete|upload|send|put|set|post|add|remove|"
                          r"analyze|mutate|start|stop|run|apply|save|register)", re.I)


def is_write(call):
    """Whether a call changes state, for protocols where the method says so and for gRPC."""
    if call.get("protocol") == "grpc":
        rpc = call["url"].rstrip("/").split("/")[-1]
        if RPC_WRITE_RE.match(rpc):
            return True
        if RPC_READ_RE.match(rpc):
            return False
        return False  # unknown RPCs read rather than anchor a spurious workflow
    return call["method"] in WRITE_METHODS


def collapse(seq, max_cycle=4):
    """Drop consecutive repeats and repeating cycles.

    Collapsing only adjacent duplicates leaves A>B>A>B>A>B intact, so a client
    polling two endpoints reads as a long workflow. Cycles up to max_cycle long
    are folded to a single occurrence.
    """
    out = []
    for item in seq:
        if not out or out[-1] != item:
            out.append(item)

    changed = True
    while changed:
        changed = False
        for size in range(1, max_cycle + 1):
            i = 0
            while i + 2 * size <= len(out):
                if out[i:i + size] == out[i + size:i + 2 * size]:
                    del out[i + size:i + 2 * size]
                    changed = True
                else:
                    i += 1
    return out


def segment(calls, read_gap_seconds=15.0):
    """Split a session into units of work.

    Two rules, because two kinds of work look nothing alike. A state-changing
    call anchors a unit: the write plus the reads that verify it. Read-only
    stretches have no such anchor, and a browsing session would otherwise
    collapse into one shapeless blob, so they are split on a short pause. A
    person reading a screen, then clicking through to another, leaves a gap an
    order of magnitude longer than the burst of calls each screen fires.
    """
    segments, current = [], []
    for call in calls:
        boundary = False
        if current:
            if is_write(call):
                boundary = True
            elif not any(is_write(c) for c in current):
                previous, now = current[-1]["ts"], call["ts"]
                if previous and now and (now - previous).total_seconds() > read_gap_seconds:
                    boundary = True
        if boundary:
            segments.append(current)
            current = []
        current.append(call)
    if current:
        segments.append(current)
    return segments


def classify_kind(cluster_entry):
    """Label what a pattern is, so browsing and polling are not read as the same thing."""
    if cluster_entry["anchor"]:
        return "action"
    distinct = len(set(cluster_entry["endpoints"]))
    if distinct <= 2 and cluster_entry["calls"] / max(1, cluster_entry["instances"]) > 3:
        return "polling"
    return "journey" if distinct > 1 else "single-read"


def cluster(sessions, min_share=0.5, read_gap_seconds=15.0):
    """Group segments by their anchoring write plus the set of reads around it.

    Exact sequence matching over-splits: the same business action shows up with
    the reads in different orders and with optional extra lookups. Keying on
    (anchor, read set) collapses those variants; rare reads below min_share are
    dropped from the key so one extra lookup does not fork a pattern.
    """
    segments = []
    for s in sessions:
        for seg in segment(s["calls"], read_gap_seconds):
            anchor = next((c["endpoint"] for c in seg if is_write(c)), None)
            segments.append({"user": s["user"], "anchor": anchor, "calls": seg,
                             "reads": [c["endpoint"] for c in seg if not is_write(c)]})

    # First pass keys on the full read set, then prunes reads that only appear
    # in a minority of an anchor's segments before re-keying.
    read_freq = defaultdict(Counter)
    anchor_count = Counter()
    for seg in segments:
        key = seg["anchor"] or "read-only"
        anchor_count[key] += 1
        for endpoint in set(seg["reads"]):
            read_freq[key][endpoint] += 1

    groups = defaultdict(list)
    for seg in segments:
        if seg["anchor"]:
            # Around a write, an occasional extra lookup is noise, so reads seen
            # in a minority of that action's segments are dropped from the key.
            core = frozenset(e for e in set(seg["reads"])
                             if read_freq[seg["anchor"]][e] / anchor_count[seg["anchor"]] >= min_share)
        else:
            # Read-only work has no anchor to group around, and the same pruning
            # would strip every endpoint of a varied browsing session and merge
            # unrelated screens into one empty-keyed cluster. Key on what the
            # segment actually touched.
            core = frozenset(seg["reads"])
        groups[(seg["anchor"], core)].append(seg)

    clusters = []
    for (anchor, core), members in groups.items():
        orderings = Counter(tuple(collapse([c["endpoint"] for c in m["calls"]])) for m in members)
        calls = sum(len(m["calls"]) for m in members)
        clusters.append({
            "steps": list(orderings.most_common(1)[0][0]),
            "endpoints": sorted({c["endpoint"] for m in members for c in m["calls"]}),
            "anchor": anchor,
            "instances": len(members),
            "calls": calls,
            "users": len({m["user"] for m in members}),
            "variants": len(orderings),
            "entry_endpoint": members[0]["calls"][0]["endpoint"],
            "steps_seen": len({tuple(collapse([c["endpoint"] for c in m["calls"]])) for m in members}),
            "median_calls": sorted(len(m["calls"]) for m in members)[len(members) // 2],
            "error_rate": round(
                sum(1 for m in members for c in m["calls"] if c["status"][:1] in ("4", "5"))
                / max(1, calls), 4),
        })
    for entry in clusters:
        entry["kind"] = classify_kind(entry)
    clusters.sort(key=lambda c: (-c["instances"], -c["calls"]))
    return clusters


# --- data classification ------------------------------------------------------

KEY_RULES = [
    ("credential", r"password|passwd|pwd|secret|api_?key|client_?secret|cvv|\bpin\b"),
    ("auth_token", r"token|bearer|jwt|session_?id|refresh"),
    ("government_id", r"\bssn\b|social_?security|tax_?id|national_?id|passport|driver_?licen"),
    ("payment_card", r"card_?number|\bpan\b|credit_?card|expiry|exp_?month|exp_?year"),
    ("bank_account", r"account_?number|iban|routing|swift|sort_?code"),
    ("person_name", r"first_?name|last_?name|full_?name|middle_?name|^name$|surname|holder"),
    ("email", r"email|e_?mail"),
    ("phone", r"phone|mobile|msisdn"),
    ("postal_address", r"address|street|city|state|zip|postal|country"),
    ("date_of_birth", r"birth|\bdob\b"),
    ("money", r"amount|balance|currency|price|total|fee|interest"),
    ("credentials_hint", r"username|user_?name|login"),
    ("free_text", r"description|notes?|comment|memo|message|reason|remarks?"),
    ("identifier", r"_?id$|^id$|uuid|guid|reference|number"),
    ("timestamp", r"_?at$|date|time|timestamp"),
]

# Unambiguous formats: these win over whatever the field is called.
STRONG_VALUE_RULES = [
    ("government_id", re.compile(r"^\d{3}-\d{2}-\d{4}$")),
    ("auth_token", re.compile(r"^(Bearer\s+)?eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.")),
    ("email", re.compile(r"^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$")),
]

# Ambiguous formats: only consulted when the field name says nothing. A bare
# digit run is a phone number or an account number depending on the key, which
# is why these run after KEY_RULES.
WEAK_VALUE_RULES = [
    ("phone", re.compile(r"^(\+\d[\d\-\s().]{7,}|\(?\d{3}\)?[-\s.]\d{3}[-\s.]\d{4})$")),
    ("ip_address", re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")),
    ("date_of_birth", re.compile(r"^(19|20)\d\d-\d\d-\d\d$")),
]

TIER = {
    "credential": "restricted",
    "government_id": "restricted",
    "payment_card": "restricted",
    "bank_account": "restricted",
    "auth_token": "confidential",
    "person_name": "confidential",
    "email": "confidential",
    "phone": "confidential",
    "postal_address": "confidential",
    "date_of_birth": "confidential",
    "money": "confidential",
    "free_text": "confidential",
    "credentials_hint": "internal",
    "identifier": "internal",
    "timestamp": "internal",
    "ip_address": "internal",
    "unclassified": "internal",
}
TIER_ORDER = ["restricted", "confidential", "internal", "public"]


def luhn(digits):
    total, alt = 0, False
    for ch in reversed(digits):
        n = int(ch)
        if alt:
            n *= 2
            if n > 9:
                n -= 9
        total += n
        alt = not alt
    return total % 10 == 0


def classify_leaf(key, value):
    """Return (class, unstructured) for one field.

    Unambiguous value formats win outright, then the field name, then formats
    that only mean something absent a name. Without that order a 12-digit
    account number reads as a phone number.
    """
    text = value if isinstance(value, str) else ""
    if isinstance(value, str):
        digits = re.sub(r"[\s-]", "", value)
        if digits.isdigit() and 13 <= len(digits) <= 19 and luhn(digits):
            return "payment_card", False
        for cls, pattern in STRONG_VALUE_RULES:
            if pattern.match(value.strip()):
                return cls, False
    lowered = key.lower()
    for cls, pattern in KEY_RULES:
        if re.search(pattern, lowered):
            unstructured = cls == "free_text" and len(text.split()) >= 3
            return cls, unstructured
    for cls, pattern in WEAK_VALUE_RULES:
        if text and pattern.match(text.strip()):
            return cls, False
    if len(text.split()) >= 5:
        return "free_text", True
    return "unclassified", False


def walk(obj, prefix=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from walk(v, f"{prefix}.{k}" if prefix else k)
    elif isinstance(obj, list):
        for v in obj[:3]:
            yield from walk(v, f"{prefix}[]")
    else:
        yield prefix, obj


BOILERPLATE_SAMPLE = 200
BOILERPLATE_MAX_DISTINCT = 20


def classify_calls(calls):
    """Field-level data classes per endpoint, split by request and response."""
    fields = defaultdict(lambda: {"class": "unclassified", "count": 0,
                                  "unstructured": 0, "values": set()})
    for call in calls:
        for side, body in (("request", call["req_body"]), ("response", call["res_body"])):
            if body is None:
                continue
            for path, value in walk(body):
                if value is None or value == "":
                    continue
                leaf = path.split(".")[-1].replace("[]", "")
                cls, unstructured = classify_leaf(leaf, value)
                key = (call["endpoint"], side, path)
                entry = fields[key]
                entry["count"] += 1
                entry["unstructured"] += int(unstructured)
                if len(entry["values"]) < BOILERPLATE_SAMPLE:
                    entry["values"].add(str(value)[:120])
                if TIER_ORDER.index(TIER[cls]) < TIER_ORDER.index(TIER[entry["class"]]):
                    entry["class"] = cls
                elif entry["class"] == "unclassified":
                    entry["class"] = cls
    out = []
    for (endpoint, side, path), entry in sorted(fields.items()):
        # A prose field that only ever holds a handful of distinct strings is a
        # status message, not user-entered text -- don't report it as free text
        # that could hide PII.
        sampled = min(entry["count"], BOILERPLATE_SAMPLE)
        boilerplate = (entry["unstructured"] > 0
                       and len(entry["values"]) <= BOILERPLATE_MAX_DISTINCT
                       and len(entry["values"]) < max(2, sampled * 0.1))
        out.append({
            "endpoint": endpoint, "side": side, "field": path,
            "class": entry["class"], "tier": TIER[entry["class"]],
            "observations": entry["count"],
            "distinct_values_sampled": len(entry["values"]),
            "unstructured_hits": 0 if boilerplate else entry["unstructured"],
            "boilerplate": boilerplate,
        })
    return out


def endpoint_tiers(field_rows):
    tiers = {}
    for row in field_rows:
        current = tiers.get(row["endpoint"], "public")
        if TIER_ORDER.index(row["tier"]) < TIER_ORDER.index(current):
            tiers[row["endpoint"]] = row["tier"]
        else:
            tiers.setdefault(row["endpoint"], current)
    return tiers


# --- naming -------------------------------------------------------------------

def heuristic_name(steps, anchor=None):
    """Readable fallback name when no model is used: the action, then what it reads."""
    def label(endpoint):
        method, _, path = endpoint.partition(" ")
        segs = [x for x in path.split("/") if x and not x.startswith("{") and x not in ("api", "v1", "v2")]
        if not segs:
            return method.lower()
        if len(segs) == 1:
            verb = {"POST": "create", "PUT": "update", "PATCH": "update", "DELETE": "delete", "GET": "list"}
            return f"{verb.get(method, method.lower())} {segs[0]}"
        return f"{segs[-1]} {segs[0]}" if method in WRITE_METHODS else f"view {segs[0]} {segs[-1]}"

    if anchor:
        reads = []
        for step in steps:
            if step != anchor:
                word = label(step).split()[-1]
                if word not in reads:
                    reads.append(word)
        return label(anchor) + (f", then check {', '.join(reads[:2])}" if reads else "")
    return "browse " + ", ".join(dict.fromkeys(label(s).split()[-1] for s in steps))


NAMING_PROMPT = """You are labeling API traffic captured from a running system so QA engineers can see which business workflows the capture covers.

Below are workflow patterns. Each is an ordered sequence of API endpoints observed in one user session, plus the request/response field NAMES touched (no values). For each pattern, return a short business workflow name, a one-sentence description of what the user is doing, and a regression-test priority (high/medium/low) with a brief reason.

Return JSON only: {"workflows": [{"index": <int>, "name": <str>, "description": <str>, "priority": <str>, "priority_reason": <str>}]}

Patterns:
%s
"""


def naming_blocks(clusters, fields_by_endpoint):
    blocks = []
    for i, c in enumerate(clusters):
        lines = [f"[{i}] {c['instances']} sessions, {c['calls']} calls"]
        for step in c["steps"]:
            names = sorted(fields_by_endpoint.get(step, set()))[:12]
            lines.append(f"  {step}" + (f"   fields: {', '.join(names)}" if names else ""))
        blocks.append("\n".join(lines))
    return "\n\n".join(blocks)


WORKFLOW_SCHEMA = {
    "type": "object",
    "properties": {"workflows": {"type": "array", "items": {
        "type": "object",
        "properties": {
            "index": {"type": "integer"},
            "name": {"type": "string"},
            "description": {"type": "string"},
            "priority": {"type": "string", "enum": ["high", "medium", "low"]},
            "priority_reason": {"type": "string"},
        },
        "required": ["index", "name", "description", "priority", "priority_reason"],
        "additionalProperties": False,
    }}},
    "required": ["workflows"],
    "additionalProperties": False,
}


def name_with_anthropic(prompt, model):
    from anthropic import Anthropic

    client = Anthropic()
    response = client.messages.create(
        model=model,
        max_tokens=16000,
        output_config={"effort": "medium",
                       "format": {"type": "json_schema", "schema": WORKFLOW_SCHEMA}},
        messages=[{"role": "user", "content": prompt}],
    )
    return next(b.text for b in response.content if b.type == "text")


def name_with_local(prompt, model, base_url):
    """Name workflows on a local OpenAI-compatible server (oMLX / ds4)."""
    import urllib.request

    payload = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": "Reply with a single JSON object and nothing else. "
                                          "No preamble, no reasoning, no code fences."},
            {"role": "user", "content": prompt},
        ],
        "max_tokens": 12000,
        "temperature": 0.2,
        "response_format": {"type": "json_object"},
    }).encode()
    req = urllib.request.Request(f"{base_url.rstrip('/')}/chat/completions", data=payload,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as resp:
        return json.load(resp)["choices"][0]["message"]["content"]


def parse_names(text):
    """Pull the workflow object out of a reply that may carry prose or fences."""
    fence = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    if fence:
        text = fence.group(1)
    for start in (m.start() for m in re.finditer(r"\{", text)):
        depth = 0
        for i in range(start, len(text)):
            depth += (text[i] == "{") - (text[i] == "}")
            if depth == 0:
                try:
                    parsed = json.loads(text[start:i + 1])
                except ValueError:
                    break
                if isinstance(parsed, dict) and "workflows" in parsed:
                    return {w["index"]: w for w in parsed["workflows"]}
                break
    raise ValueError("no workflow JSON object in reply")


# --- reporting ----------------------------------------------------------------

def render(model, out_path):
    m = model
    src = m["source"]
    lines = [
        "# Traffic classifier run",
        "",
        f"Source: `{src['input']}`  ",
        f"Window: {src['window_start']} to {src['window_end']}  ",
        f"Calls: {src['calls']} across {src['endpoints']} endpoints, "
        f"{src['users']} distinct identities, {src['sessions']} sessions  ",
        (f"Cluster filter: `{src['cluster_filter']}`  " if src['cluster_filter'] else ""),
        f"Identity resolved from: " + ", ".join(
            f"{k} {v}" for k, v in sorted(src['identity_sources'].items(), key=lambda kv: -kv[1]))
        + f" ({src['anonymous_calls']} uncorrelated calls excluded from sessions)",
        "",
        "## Workflows",
        "",
        "| # | Workflow | Kind | Sessions | Calls | Steps | Errors | Data tier | Test priority |",
        "| - | -------- | ---- | -------: | ----: | ----: | -----: | --------- | ------------- |",
    ]
    for i, w in enumerate(m["workflows"], 1):
        lines.append(
            f"| {i} | {w['name']} | {w['kind']} | {w['instances']} | {w['calls']} | {len(w['steps'])} | "
            f"{w['error_rate'] * 100:.1f}% | {w['tier']} | {w['priority']} |")

    lines += ["", "## Workflow detail", ""]
    for i, w in enumerate(m["workflows"], 1):
        lines += [f"### {i}. {w['name']}", "", w["description"], ""]
        if w.get("priority_reason"):
            lines += [f"Test priority **{w['priority']}** — {w['priority_reason']}", ""]
        lines.append("Steps:")
        lines += [f"{n}. `{s}`" for n, s in enumerate(w["steps"], 1)]
        if w["data_classes"]:
            lines += ["", "Data classes touched: " + ", ".join(
                f"`{c}` ({TIER[c]})" for c in w["data_classes"])]
        lines.append("")

    if len(src["clusters"]) > 1:
        lines += ["## Source clusters", "",
                  "This tenant received traffic from more than one cluster in the window. "
                  "Errors from one environment read as another's unless the run is scoped "
                  "with `--cluster`.", "",
                  "| Cluster | Calls | Errors |", "| ------- | ----: | -----: |"]
        lines += [f"| `{c['cluster']}` | {c['calls']} | {c['errors']} "
                  f"({c['errors'] / max(1, c['calls']) * 100:.1f}%) |" for c in src["clusters"]]
        lines.append("")

    lines += ["## Endpoint health", "",
              "| Endpoint | Calls | Errors | Status codes | Data tier |",
              "| -------- | ----: | -----: | ------------ | --------- |"]
    for e in m["endpoint_health"]:
        codes = ", ".join(f"{c} x{n}" for c, n in e["statuses"].items())
        lines.append(f"| `{e['endpoint']}` | {e['calls']} | {e['error_rate'] * 100:.1f}% | "
                     f"{codes} | {e['tier']} |")

    lines += ["", "## Data classification by endpoint", "",
              "| Endpoint | Side | Field | Class | Tier |",
              "| -------- | ---- | ----- | ----- | ---- |"]
    for row in m["fields"]:
        if row["class"] == "unclassified":
            continue
        lines.append(f"| `{row['endpoint']}` | {row['side']} | `{row['field']}` | "
                     f"{row['class']} | {row['tier']} |")

    unstructured = [r for r in m["fields"] if r["unstructured_hits"]]
    lines += ["", "## Unstructured fields (free text that may carry PII)", ""]
    if unstructured:
        lines += ["| Endpoint | Field | Observations with free text |",
                  "| -------- | ----- | --------------------------: |"]
        lines += [f"| `{r['endpoint']}` | `{r['field']}` | {r['unstructured_hits']} |"
                  for r in unstructured]
    else:
        lines.append("None found in this capture.")

    lines += ["", "## Coverage gaps", ""]
    if m["uncovered_endpoints"]:
        lines.append("Endpoints seen in traffic but not part of any named workflow:")
        lines += [f"- `{e}`" for e in m["uncovered_endpoints"]]
    else:
        lines.append("Every observed endpoint appears in at least one workflow.")

    with open(out_path, "w") as f:
        f.write("\n".join(lines) + "\n")


# --- main ---------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--actions", help="snapshot action.jsonl")
    ap.add_argument("--rrpair-dir", help="directory of proxymock RRPair .md files")
    ap.add_argument("--reactions", help="snapshot reaction.jsonl, for downstream response bodies")
    ap.add_argument("--out-dir", default="out")
    ap.add_argument("--cluster", help="restrict to one k8s cluster (a tenant can receive several)")
    ap.add_argument("--gap-seconds", type=float, default=120.0)
    ap.add_argument("--read-gap-seconds", type=float, default=15.0,
                    help="pause that ends a read-only unit of work within a session")
    ap.add_argument("--min-sessions", type=int, default=2,
                    help="drop workflow patterns seen fewer times than this")
    ap.add_argument("--namer", choices=["none", "anthropic", "local"], default="none",
                    help="label workflows with an LLM; only field names are sent, never values")
    ap.add_argument("--model", help="model id (defaults per namer)")
    ap.add_argument("--base-url", default="http://localhost:11434/v1",
                    help="OpenAI-compatible endpoint for --namer local (Ollama, LM Studio, oMLX, vLLM)")
    args = ap.parse_args()

    if not args.actions and not args.rrpair_dir:
        ap.error("pass --actions or --rrpair-dir")

    records = load_actions(args.actions) if args.actions else load_rrpair_dir(args.rrpair_dir)
    calls = [to_call(r) for r in records]
    calls = [c for c in calls if c["direction"] != "OUT" and c["endpoint"].strip()]

    # A tenant can receive traffic from more than one cluster. Mixing them makes
    # one environment's failures look like another's, so report the split and
    # let --cluster narrow to the environment actually under study.
    cluster_totals = Counter(c["cluster"] for c in calls)
    cluster_errors = Counter(c["cluster"] for c in calls if c["status"][:1] in ("4", "5"))
    if args.cluster:
        calls = [c for c in calls if c["cluster"] == args.cluster]
        if not calls:
            ap.error(f"no traffic from cluster {args.cluster!r}; saw {sorted(cluster_totals)}")

    # Reactions carry the downstream response bodies that inbound capture dropped;
    # join them at endpoint level so response fields still get classified.
    reaction_calls = []
    if args.reactions:
        for rec in load_actions(args.reactions):
            call = to_call(rec)
            if call["res_body"] is not None and (not args.cluster or call["cluster"] == args.cluster):
                reaction_calls.append(call)

    sessions, anonymous = sessionize(calls, args.gap_seconds)
    clusters = [c for c in cluster(sessions, read_gap_seconds=args.read_gap_seconds)
                if c["instances"] >= args.min_sessions]

    field_rows = classify_calls(calls + reaction_calls)
    tiers = endpoint_tiers(field_rows)
    classes_by_endpoint = defaultdict(set)
    names_by_endpoint = defaultdict(set)
    for row in field_rows:
        if row["class"] != "unclassified":
            classes_by_endpoint[row["endpoint"]].add(row["class"])
        names_by_endpoint[row["endpoint"]].add(row["field"])

    named = {}
    if args.namer != "none" and clusters:
        prompt = NAMING_PROMPT % naming_blocks(clusters, names_by_endpoint)
        try:
            if args.namer == "anthropic":
                raw = name_with_anthropic(prompt, args.model or "claude-opus-5")
            else:
                if not args.model:
                    ap.error("--namer local needs --model <name served by --base-url>")
                raw = name_with_local(prompt, args.model, args.base_url)
            named = parse_names(raw)
        except Exception as exc:  # naming is optional; heuristics still produce a report
            print(f"{args.namer} naming failed ({exc}); using heuristic names", file=sys.stderr)

    workflows = []
    for i, c in enumerate(clusters):
        label = named.get(i, {})
        classes = sorted({cls for step in c["endpoints"] for cls in classes_by_endpoint.get(step, ())})
        tier = min((tiers.get(s, "public") for s in c["endpoints"]), key=TIER_ORDER.index, default="public")
        workflows.append({
            **c,
            "name": label.get("name") or heuristic_name(c["steps"], c.get("anchor")),
            "description": label.get("description") or
                           f"Session pattern entering at {c['entry_endpoint']}.",
            "priority": label.get("priority", "unrated"),
            "priority_reason": label.get("priority_reason", ""),
            "data_classes": classes,
            "tier": tier,
            "kind": c["kind"],
        })

    health = defaultdict(Counter)
    for call in calls:
        health[call["endpoint"]][call["status"] or "?"] += 1
    endpoint_health = []
    for endpoint, statuses in health.items():
        total = sum(statuses.values())
        errors = sum(n for code, n in statuses.items() if code[:1] in ("4", "5"))
        endpoint_health.append({
            "endpoint": endpoint, "calls": total,
            "error_rate": round(errors / total, 4),
            "statuses": dict(statuses.most_common(5)),
            "tier": tiers.get(endpoint, "public"),
        })
    endpoint_health.sort(key=lambda e: (-e["error_rate"], -e["calls"]))

    covered = {s for w in workflows for s in w["endpoints"]}
    all_endpoints = {c["endpoint"] for c in calls}
    times = [c["ts"] for c in calls if c["ts"]]

    model = {
        "source": {
            "input": args.actions or args.rrpair_dir,
            "window_start": min(times).isoformat() if times else "",
            "window_end": max(times).isoformat() if times else "",
            "calls": len(calls),
            "endpoints": len(all_endpoints),
            "users": len({c["user"] for c in calls if c["user"]}),
            "sessions": len(sessions),
            "anonymous_calls": len(anonymous),
            "identity_sources": dict(Counter(c["identity_source"] for c in calls)),
            "cluster_filter": args.cluster or "",
            "clusters": [{"cluster": name, "calls": n, "errors": cluster_errors.get(name, 0)}
                         for name, n in cluster_totals.most_common()],
        },
        "workflows": workflows,
        "endpoint_health": endpoint_health,
        "fields": field_rows,
        "uncovered_endpoints": sorted(all_endpoints - covered),
    }

    os.makedirs(args.out_dir, exist_ok=True)
    with open(os.path.join(args.out_dir, "classification.json"), "w") as f:
        json.dump(model, f, indent=2, default=str)
    render(model, os.path.join(args.out_dir, "report.md"))

    print(f"{len(calls)} calls, {len(sessions)} sessions, {len(workflows)} workflow patterns")
    print(f"wrote {args.out_dir}/report.md and {args.out_dir}/classification.json")


if __name__ == "__main__":
    main()
