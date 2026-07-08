#!/usr/bin/env python3
"""Craft account-matched dependency mocks for a pulled incident snapshot.

A failing request usually dies before fanning out, so the incident export has
no dependency traffic for that account and a post-fix replay would have nothing
to answer the accounts-service calls. This derives them from the committed
mocks/localhost recordings: swap the account id and set the balance PUT to
base-balance + deposit amount (the exact body is part of the mock signature).

The INTERNAL json block carries base64-encoded signature fields, so a plain
sed is not enough - the signature is decoded, patched, and re-encoded here.

Usage: craft-mocks.py <incident-dir> <mocks-out-dir>
"""
import base64
import json
import os
import re
import shutil
import sys

TEMPLATES = {
    "get-account": "2026-06-25_18-26-02.244952Z.md",
    "get-balance": "2026-06-25_18-26-02.26794Z.md",
    "put-balance": "2026-06-25_18-26-02.307187Z.md",
}
TEMPLATE_ACCOUNT = "70668"
TEMPLATE_BASE_BALANCE = 1000.00
TEMPLATE_PUT_BALANCE = "1003.33"


def inbound_deposits(incident_dir):
    """Yield (accountId, amount) for each exported failing deposit."""
    seen = set()
    localhost = os.path.join(incident_dir, "localhost")
    for name in sorted(os.listdir(localhost)):
        if not name.endswith(".md"):
            continue
        txt = open(os.path.join(localhost, name)).read()
        m = re.search(r"json: (\{.*\})", txt)
        if not m:
            continue
        rec = json.loads(m.group(1))
        if rec.get("location") != "/api/transactions/deposit":
            continue
        req = re.search(r"### REQUEST ###.*?```\n(\{.*?\})\n```", txt, re.S)
        if not req:
            continue
        body = json.loads(req.group(1))
        key = (body.get("accountId"), body.get("amount"))
        if None in key or key in seen:
            continue
        seen.add(key)
        yield key


def craft(template_path, out_path, swaps):
    txt = open(template_path).read()
    m = re.search(r"json: (\{.*\})", txt)
    rec = json.loads(m.group(1))
    for old, new in swaps:
        rec["location"] = rec["location"].replace(old, new)
        req = rec["http"]["req"]
        for k in ("url", "uri"):
            req[k] = req[k].replace(old, new)
        if "bodyJSON" in req:
            req["bodyJSON"] = req["bodyJSON"].replace(old, new)
    sig = rec.get("signature", {})
    for k, v in list(sig.items()):
        plain = base64.b64decode(v).decode() if v else ""
        for old, new in swaps:
            plain = plain.replace(old, new)
        if plain:
            sig[k] = base64.b64encode(plain.encode()).decode()
    for old, new in swaps:
        txt = txt.replace(old, new)
    fixed = json.dumps(rec, separators=(",", ":"))
    txt = re.sub(r"json: \{.*\}", "json: " + fixed.replace("\\", "\\\\"), txt)
    open(out_path, "w").write(txt)


def main():
    incident_dir, out_dir = sys.argv[1], sys.argv[2]
    demo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = os.path.join(demo, "mocks")

    # start from the committed mocks (payment/compliance hosts stay as-is)
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    shutil.copytree(src, out_dir)

    deposits = list(inbound_deposits(incident_dir))
    if not deposits:
        print("no failing deposits found in", incident_dir)
        sys.exit(1)

    for account_id, amount in deposits:
        account = str(account_id)
        # repr() gives the shortest round-trip decimal, matching Jackson's
        # Double serialization for these sums; keep base balance at 1000.00
        new_balance = repr(float(TEMPLATE_BASE_BALANCE) + float(amount))
        for kind, fname in TEMPLATES.items():
            swaps = [(TEMPLATE_ACCOUNT, account)]
            if kind == "put-balance":
                swaps.append((TEMPLATE_PUT_BALANCE, new_balance))
            out = os.path.join(
                out_dir, "localhost", fname.replace(".md", f"-{account}.md")
            )
            craft(os.path.join(src, "localhost", fname), out, swaps)
        print(f"crafted accounts mocks: account {account}, deposit {amount}, "
              f"balance {TEMPLATE_BASE_BALANCE} -> {new_balance}")


if __name__ == "__main__":
    main()
