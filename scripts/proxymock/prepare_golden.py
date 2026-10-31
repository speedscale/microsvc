#!/usr/bin/env python3
"""Prepare a checked-in golden snapshot for an offline, deterministic proxymock replay.

Service-agnostic: run it against any backend/<service>/proxymock/recorded-golden tree
(see backend/api-gateway/proxymock/README.md). It normalizes captured traffic in place and
is idempotent (re-running is a no-op). It does four things:

1. Strips the DLP artifact. The capture's DLP rule injects a synthetic {"$api_key":
   "REDACTED-..."} field into request bodies (and the request-body match signature). The
   real app forwards requests without it, so a downstream mock keyed on the synthetic body
   never matches. We drop $api_key from the body block AND from the INTERNAL json
   signature.http:requestBodyJSON (base64) that proxymock actually matches on.

2. Redacts auth tokens. No usable credential is committed: every JWT keeps its header and
   claims but its SIGNATURE is replaced with "REDACTED", so the token cannot authenticate
   anywhere. This covers every copy -- the readable request/response blocks, the INTERNAL
   json (including the DLP tokenList whose base64 replacementValue holds the ORIGINAL
   captured token), and any base64 request/response body. Tokens are refreshed at replay
   time instead, by the service's proxymock blueprint
   (scripts/proxymock/services/<service>.blueprint.json): a jwt_resign transform chain
   re-signs each redacted bearer with the replay's test key and a fresh expiry. jwt_resign
   reads the header + claims without verifying the old signature, which is why the claims
   (userId, roles, ...) are kept and only the signature is redacted.

3. Relocates known gaps. Inbound requests that cannot be served offline (downstream
   fan-out not captured, or an environment-specific status) are moved to known-gaps/ so the
   replay gate stays 100% on coverable traffic. Configure with --known-gap-pattern (a regex
   matched against the inbound rrpair text, repeatable) and --known-gap-status URL:STATUS.
   known-gaps/ is git-ignored: parked recordings are not consumed by any test, so they stay
   local for inspection and are never committed (the service README documents each gap).

4. Prunes unused mocks. The pull holds many redundant/large downstream variants; only one
   representative (smallest file) per needed (method,url,query,body) signature is kept.

No signing key is used or needed here; the replay key lives with the harness/blueprint.

Usage:
  prepare_golden.py --golden <recorded-golden-dir>
                    [--downstream-dir banking-user ...]       # default: auto-detect
                    [--known-gap-pattern 'http:queryparams:accountId is' ...]
                    [--known-gap-status /api/transactions:503 ...]
                    [--check]   # verify the golden is already normalized (idempotent);
                                # make no changes and exit non-zero if any would be made.
"""
import argparse
import base64
import json
import os
import re
import sys

RESERVED_DIRS = {"localhost", "known-gaps", "results"}

# A JWT is header.claims.signature, each base64url; header and claims are JSON objects, so
# both start with "eyJ" ('{"'). Only the signature is the credential.
REDACTED_SIG = "REDACTED"
_JWT = re.compile(r"(eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+")


def redact_jwts(text: str) -> str:
    """Replace the signature of every JWT in text with REDACTED (idempotent)."""
    return _JWT.sub(lambda m: f"{m.group(1)}.{REDACTED_SIG}", text)


def _redact_b64(value: str):
    """Redact JWTs inside a std-base64 string; return the new value or None if unchanged."""
    try:
        decoded = base64.b64decode(value).decode("utf-8")
    except Exception:
        return None
    redacted = redact_jwts(decoded)
    if redacted == decoded:
        return None
    return base64.b64encode(redacted.encode()).decode()


def redact_tokens(txt: str) -> str:
    """Redact every copy of every auth token in an rrpair so none is a usable credential.

    Plain-text copies (readable headers/bodies, tokenList keys) are handled by a text-wide
    substitution; base64 copies (tokenList replacementValue, bodyBase64) are decoded,
    redacted and re-encoded inside the INTERNAL json.
    """
    txt = redact_jwts(txt)
    m = _INTERNAL_JSON.search(txt)
    if not m:
        return txt
    try:
        doc = json.loads(m.group(2))
    except Exception:
        return txt
    changed = False
    for entry in (doc.get("tokenList") or {}).values():
        for tok in entry.get("tokens", []):
            inner = tok.get("token", {})
            if "replacementValue" in inner:
                new = _redact_b64(inner["replacementValue"])
                if new is not None:
                    inner["replacementValue"] = new
                    changed = True
    for side in ("req", "res"):
        part = doc.get("http", {}).get(side, {})
        if part.get("bodyBase64"):
            new = _redact_b64(part["bodyBase64"])
            if new is not None:
                part["bodyBase64"] = new
                changed = True
    if not changed:
        return txt
    new_json = json.dumps(doc, separators=(",", ":"))
    return txt[: m.start()] + m.group(1) + new_json + m.group(3) + txt[m.end():]


# The request section holds two fenced blocks: the request headers then the request body.
_REQUEST_SECTION = re.compile(r"(### REQUEST ###\n)(.*?)(\n### RESPONSE ###)", re.DOTALL)
_FENCED = re.compile(r"```\n(.*?)\n```", re.DOTALL)
# The signature line carrying the (DLP-polluted) request body JSON.
_SIG_LINE = re.compile(r"^http:requestBodyJSON is (\{.*\})\s*$", re.MULTILINE)


def _strip_api_key_json(blob: str):
    """Drop the synthetic $api_key field from a JSON object string.

    Returns (new_blob, changed). An object that was ONLY $api_key becomes empty,
    which the caller renders as a blank body so a GET with no body matches.
    """
    try:
        obj = json.loads(blob)
    except Exception:
        return blob, False
    if not isinstance(obj, dict) or "$api_key" not in obj:
        return blob, False
    obj.pop("$api_key", None)
    return obj, True


def strip_dlp(txt: str) -> str:
    # 1) Request body block: remove $api_key, preserving the pretty 2-space style.
    def fix_section(m):
        section = m.group(2)
        fences = list(_FENCED.finditer(section))
        if len(fences) < 2:
            return m.group(0)  # no body block present
        body_fence = fences[-1]
        body = body_fence.group(1)
        obj, changed = _strip_api_key_json(body)
        if not changed:
            return m.group(0)
        if obj:
            new_body = json.dumps(obj, indent=2)
        else:
            new_body = ""  # body was only $api_key -> empty body
        new_section = section[: body_fence.start(1)] + new_body + section[body_fence.end(1):]
        return m.group(1) + new_section + m.group(3)

    txt = _REQUEST_SECTION.sub(fix_section, txt)

    # 2) Signature line: drop $api_key from the recorded request-body signature so
    #    proxymock recomputes/matches against the real forwarded body.
    def fix_sig(m):
        obj, changed = _strip_api_key_json(m.group(1))
        if not changed:
            return m.group(0)
        if obj:
            return "http:requestBodyJSON is " + json.dumps(obj, separators=(",", ":"), sort_keys=True)
        return "http:requestBodyJSON is -NONE-"

    txt = _SIG_LINE.sub(fix_sig, txt)

    # 3) INTERNAL json: proxymock matches on signature.http:requestBodyJSON (base64),
    #    NOT the human-readable block, so patch it there too. Decode, drop $api_key,
    #    re-encode; an object that becomes empty gets an empty signature value.
    txt = _fix_internal_json(txt)
    return txt


_INTERNAL_JSON = re.compile(r"(\njson: )(\{.*\})(\s*\n```)", re.DOTALL)


def _fix_internal_json(txt: str) -> str:
    m = _INTERNAL_JSON.search(txt)
    if not m:
        return txt
    try:
        doc = json.loads(m.group(2))
    except Exception:
        return txt
    sig = doc.get("signature")
    if not isinstance(sig, dict) or "http:requestBodyJSON" not in sig:
        return txt
    try:
        decoded = base64.b64decode(sig["http:requestBodyJSON"]).decode("utf-8")
    except Exception:
        return txt
    obj, changed = _strip_api_key_json(decoded)
    if not changed:
        return txt
    if obj:
        new_val = json.dumps(obj, separators=(",", ":"), sort_keys=True)
        sig["http:requestBodyJSON"] = base64.b64encode(new_val.encode()).decode()
    else:
        sig["http:requestBodyJSON"] = ""
    new_json = json.dumps(doc, separators=(",", ":"))
    return txt[: m.start()] + m.group(1) + new_json + m.group(3) + txt[m.end():]


# A "known gap" is an inbound request that cannot be replayed faithfully offline, so it is
# relocated to known-gaps/ and excluded from the pass/fail gate. Two kinds, both config'd
# per service (defaults are empty -> nothing is parked unless asked):
#   - downstream fan-out not captured (no mock can serve it) -> match by --known-gap-pattern
#   - environment-specific status (e.g. a load-dependent 503) -> match by --known-gap-status

def _recorded_status(txt: str):
    m = re.search(r'"res":\{[^}]*"statusCode":(\d+)', txt)
    return int(m.group(1)) if m else None


def _is_known_gap(txt, gap_patterns, gap_status) -> bool:
    if any(p.search(txt) for p in gap_patterns):
        return True
    status = _recorded_status(txt)
    for url_sub, code in gap_status:
        if status == code and f"http:url is {url_sub}" in txt:
            return True
    return False


def relocate_known_gaps(golden, gap_patterns, gap_status) -> int:
    localhost = os.path.join(golden, "localhost")
    if not os.path.isdir(localhost):
        return 0
    if not gap_patterns and not gap_status:
        return 0
    gap_dir = os.path.join(golden, "known-gaps", "localhost")
    moved = 0
    for name in sorted(os.listdir(localhost)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(localhost, name)
        with open(path) as f:
            txt = f.read()
        if _is_known_gap(txt, gap_patterns, gap_status):
            os.makedirs(gap_dir, exist_ok=True)
            os.replace(path, os.path.join(gap_dir, name))
            moved += 1
    return moved


def detect_downstream_dirs(golden):
    """Every top-level dir under golden/ except the inbound set and bookkeeping dirs."""
    return sorted(
        d for d in os.listdir(golden)
        if os.path.isdir(os.path.join(golden, d)) and d not in RESERVED_DIRS
    )


def _sig_tuple(txt: str):
    """(method, url, queryparams, requestBody) from an rrpair's SIGNATURE block.

    Must mirror proxymock's HTTP match dimensions: method, url, query params AND the
    request body (POST bodies distinguish /login and /transactions/create variants), so
    pruning keeps a mock that actually matches the inbound request the gateway forwards.
    """
    method = re.search(r"^http:method is (.+)$", txt, re.MULTILINE)
    url = re.search(r"^http:url is (.+)$", txt, re.MULTILINE)
    qps = sorted(re.findall(r"^http:queryparams(?::\w+)? is (.+)$", txt, re.MULTILINE))
    qps = [q for q in qps if q != "-NONE-"]
    body = re.search(r"^http:requestBodyJSON is (.+)$", txt, re.MULTILINE)
    body_val = body.group(1).strip() if body else "-NONE-"
    if body_val == "-NONE-":
        body_val = ""
    return (
        method.group(1).strip() if method else "",
        url.group(1).strip() if url else "",
        "&".join(qps),
        body_val,
    )


def prune_unused_mocks(golden, downstream_dirs) -> tuple:
    """Keep only the downstream mocks the inbound set actually drives.

    The app under test is a path-through proxy, so each inbound request produces a
    downstream request with the same (method, url, queryparams, body). The pulled snapshot
    holds many redundant and very large mock variants that are never hit. We keep one
    representative mock -- the smallest file -- per needed signature in each downstream dir
    and drop the rest, shrinking the committed golden without changing what the replay
    exercises.
    """
    # Only the inbound TEST SET drives what is kept. Parked known-gaps are not replayed, so
    # mocks that only they would need are unconsumed fixtures and are dropped; known-gaps/ is
    # also git-ignored, so counting it would make pruning differ between machines.
    needed = set()
    for sub in ("localhost",):
        d = os.path.join(golden, sub)
        if not os.path.isdir(d):
            continue
        for name in os.listdir(d):
            if name.endswith(".md"):
                with open(os.path.join(d, name)) as f:
                    needed.add(_sig_tuple(f.read()))

    kept = dropped = 0
    for dd in downstream_dirs:
        ddir = os.path.join(golden, dd)
        if not os.path.isdir(ddir):
            continue
        by_sig = {}
        for name in os.listdir(ddir):
            if not name.endswith(".md"):
                continue
            path = os.path.join(ddir, name)
            with open(path) as f:
                sig = _sig_tuple(f.read())
            by_sig.setdefault(sig, []).append(path)
        keep_paths = set()
        for sig, paths in by_sig.items():
            if sig in needed:
                keep_paths.add(min(paths, key=lambda p: os.path.getsize(p)))
        for name in os.listdir(ddir):
            if not name.endswith(".md"):
                continue
            path = os.path.join(ddir, name)
            if path in keep_paths:
                kept += 1
            else:
                os.remove(path)
                dropped += 1
    return kept, dropped


def _parse_gap_status(values):
    out = []
    for v in values or []:
        url, _, code = v.rpartition(":")
        if not url or not code.isdigit():
            raise SystemExit(f"--known-gap-status must be URL:STATUS, got {v!r}")
        out.append((url, int(code)))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--golden", required=True, help="path to a recorded-golden dir")
    ap.add_argument("--downstream-dir", action="append", default=[],
                    help="downstream mock dir name (repeatable); default: auto-detect")
    ap.add_argument("--known-gap-pattern", action="append", default=[],
                    help="regex matched against inbound rrpair text; matches -> known-gaps/ (repeatable)")
    ap.add_argument("--known-gap-status", action="append", default=[],
                    help="URL:STATUS; an inbound rrpair recording that status for that url -> known-gaps/ (repeatable)")
    ap.add_argument("--check", action="store_true",
                    help="verify the golden is already normalized; make NO changes and exit "
                         "non-zero if any normalization (DLP/token) would still apply")
    args = ap.parse_args()

    golden = args.golden
    if not os.path.isdir(golden):
        print(f"golden dir not found: {golden}", file=sys.stderr)
        return 1

    gap_patterns = [re.compile(p) for p in args.known_gap_pattern]
    gap_status = _parse_gap_status(args.known_gap_status)
    downstream_dirs = args.downstream_dir or detect_downstream_dirs(golden)

    # --check: snapshot-consistency / repeatability gate. prepare_golden is idempotent, so a
    # committed golden must already be a fixed point -- re-running it changes nothing. In
    # check mode we compute what WOULD change without writing, and fail if anything would.
    # This is how "the golden is normalized and stable" becomes a verifiable claim in CI/hooks
    # rather than an assumption.
    if args.check:
        dirty = []
        for root, _dirs, files in os.walk(golden):
            for name in files:
                if not name.endswith(".md"):
                    continue
                path = os.path.join(root, name)
                with open(path) as f:
                    txt = f.read()
                if redact_tokens(strip_dlp(txt)) != txt:
                    dirty.append(os.path.relpath(path, golden))
        if dirty:
            print(f"SNAPSHOT NOT NORMALIZED: {len(dirty)} rrpair(s) would change if prepared:")
            for rel in sorted(dirty):
                print(f"  - {rel}")
            print("Run `make proxymock-prepare-golden` (or prepare_golden.py without --check) "
                  "and commit the result.")
            return 1
        print(f"snapshot consistency: golden at {golden} is already normalized (idempotent) -- "
              "re-preparing would change nothing.")
        return 0

    changed_dlp = 0
    changed_tok = 0
    for root, _dirs, files in os.walk(golden):
        for name in files:
            if not name.endswith(".md"):
                continue
            path = os.path.join(root, name)
            with open(path) as f:
                txt = f.read()
            before = txt
            t2 = strip_dlp(txt)
            if t2 != txt:
                changed_dlp += 1
            txt = t2
            t3 = redact_tokens(txt)
            if t3 != txt:
                changed_tok += 1
            txt = t3
            if txt != before:
                with open(path, "w") as f:
                    f.write(txt)

    moved = relocate_known_gaps(golden, gap_patterns, gap_status)
    kept, dropped = prune_unused_mocks(golden, downstream_dirs)
    print(f"prepared golden snapshot at {golden}")
    print(f"  downstream dirs: {', '.join(downstream_dirs) or '(none)'}")
    print(f"  stripped DLP $api_key body in {changed_dlp} rrpair(s)")
    print(f"  redacted auth token signatures in {changed_tok} rrpair(s)")
    print(f"  relocated {moved} inbound request(s) to known-gaps/")
    print(f"  kept {kept} downstream mock(s), dropped {dropped} unused/redundant")
    return 0


if __name__ == "__main__":
    sys.exit(main())
