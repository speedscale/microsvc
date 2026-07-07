#!/usr/bin/env python3
"""Re-sign the bearer tokens in a pulled incident so replay never 401s on expiry.

Captured requests carry real staging JWTs with a ~24h expiry. Replayed against
the local service (which shares the demo JWT secret) they authenticate fine, but
a pull left overnight would expire. This rewrites each Authorization bearer with
the same claims and a far-future expiry, re-signed with the demo secret - the
local-demo equivalent of the capture-token blueprint a redacted BYOC replay uses
to swap in a live token. The request signature (host/method/url/body) is
unchanged, so proxymock still matches and replays exactly as captured.

Usage: refresh-tokens.py <dir-with-localhost-rrpairs>
"""
import base64
import hashlib
import hmac
import json
import os
import re
import sys

# The demo JWT secret, same value baked into run.sh / warmup.sh and the staging
# banking-jwt-secret. Not a real credential - a committed demo key.
SECRET = b"banking-app-super-secret-key-change-this-in-production-256-bit"
FAR_FUTURE = 1893456000  # 2030-01-01, matches the committed offline capture


def b64url_decode(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def b64url_encode(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def resign(token):
    """Return the token with exp bumped and re-signed, or None if not HS256 JWT."""
    parts = token.split(".")
    if len(parts) != 3:
        return None
    try:
        header = json.loads(b64url_decode(parts[0]))
        payload = json.loads(b64url_decode(parts[1]))
    except Exception:
        return None
    if header.get("alg") != "HS256":
        return None
    payload["exp"] = FAR_FUTURE
    h = b64url_encode(json.dumps(header, separators=(",", ":")).encode())
    p = b64url_encode(json.dumps(payload, separators=(",", ":")).encode())
    sig = b64url_encode(hmac.new(SECRET, f"{h}.{p}".encode(), hashlib.sha256).digest())
    return f"{h}.{p}.{sig}"


def main():
    localhost = os.path.join(sys.argv[1], "localhost")
    if not os.path.isdir(localhost):
        print(f"no localhost/ under {sys.argv[1]}", file=sys.stderr)
        sys.exit(1)
    refreshed = 0
    for name in sorted(os.listdir(localhost)):
        if not name.endswith(".md"):
            continue
        path = os.path.join(localhost, name)
        txt = open(path).read()
        changed = False
        for old in set(re.findall(r"Bearer ([A-Za-z0-9._-]+)", txt)):
            new = resign(old)
            if new and new != old:
                txt = txt.replace(old, new)
                changed = True
        if changed:
            open(path, "w").write(txt)
            refreshed += 1
    print(f"refreshed tokens in {refreshed} request(s) (exp -> 2030)")


if __name__ == "__main__":
    main()
