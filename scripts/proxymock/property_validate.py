#!/usr/bin/env python3
"""Property-test replayed responses against agreed BUSINESS INVARIANTS.

schema_validate.py asserts response SHAPE (fields + types) and contract coverage. It does
not assert that values make business sense: a balance schema-validates as a number whether
it is 698.35 or -1. This tool adds that layer -- declarative, per-service invariants that
must hold across every replayed response for an operation, letting the specific values vary.

An invariant is a property, not an example. "balance is a non-negative number" and "a
listed account's id matches the {id} in the URL it was fetched by" are properties that hold
for ALL valid responses; they are the business contract the recorded examples happen to
satisfy. Keeping them declarative (a JSON rules file per service) means the invariants are
reviewed and agreed, not buried in code, and the same engine runs for every service.

Rules file (scripts/proxymock/services/<service>.invariants.json), a list of rules:
  {
    "match": {"method": "GET", "url": "/api/accounts/{id}/balance", "status": "200"},
    "assert": [
      {"field": "$.balance",   "type": "number", "min": 0},
      {"field": "$.accountId", "type": "number", "required": true},
      {"field": "$.accountNumber", "type": "string", "pattern": "^[0-9]+$"}
    ]
  }
  - match: any of method/url/status may be omitted to match more broadly; url is matched as
    a url-pattern (numeric path segments collapse to {id}, same as schema_validate).
  - field: a dotted path from $ (root). A [] segment maps over every element of an array,
    so "$[].balance" asserts the property for each item in a list response.
  - assert checks (all optional, combine freely):
      required   bool   -- the field MUST be present (default: checked only if present)
      type       str    -- number|string|bool|object|array|null (JSON type, int/float=number)
      min / max  number -- numeric bounds (inclusive)
      enum       list   -- value must be one of these
      pattern    regex  -- string must fully match
      non_empty  bool   -- string/array/object must be non-empty

Dependency-free (stdlib only) so it runs in a pre-commit hook and CI without `pip install`.

Usage:
  property_validate.py --golden <recorded-golden-dir> --replay <replay-out-dir> \
                       --rules scripts/proxymock/services/<service>.invariants.json
  property_validate.py --rules <file> --lint     # validate the rules file itself and exit
"""
import argparse
import json
import os
import re
import sys

# Reuse the shared rrpair parsing + url canonicalization so property and schema gates see
# identical (method, url-pattern, status) keys and bodies.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from schema_validate import (  # noqa: E402
    _read, _internal_json, _meta, _response_body, _type_tag, url_pattern,
)


def _match(rule_match, method, url, status):
    if "method" in rule_match and rule_match["method"] != method:
        return False
    if "status" in rule_match and str(rule_match["status"]) != str(status):
        return False
    if "url" in rule_match and url_pattern(rule_match["url"]) != url_pattern(url):
        return False
    return True


def _resolve(value, field):
    """Yield every value the dotted field path selects. '[]' maps over array elements.

    Returns a list of (present, value) tuples -- present=False when the path dead-ends on a
    missing object key (so 'required' can distinguish absent from null).
    """
    # Normalize "$.a.b[].c" -> ["a", "b", "[]", "c"]
    body = field[1:] if field.startswith("$") else field
    tokens = []
    for part in body.split("."):
        if not part:
            continue
        while part.endswith("[]"):
            part = part[:-2]
            if part:
                tokens.append(part)
                part = ""
            tokens.append("[]")
        if part:
            tokens.append(part)

    def walk(node, idx):
        if idx == len(tokens):
            return [(True, node)]
        tok = tokens[idx]
        if tok == "[]":
            if not isinstance(node, list):
                return [(False, None)]
            out = []
            for item in node:
                out.extend(walk(item, idx + 1))
            return out
        if isinstance(node, dict):
            if tok not in node:
                return [(False, None)]
            return walk(node[tok], idx + 1)
        return [(False, None)]

    return walk(value, 0)


def _check_value(present, value, chk, where, errors):
    field = where
    if not present:
        if chk.get("required"):
            errors.append(f"{field}: required but missing")
        return
    tag = _type_tag(value)
    if "type" in chk and tag != chk["type"]:
        errors.append(f"{field}: type {tag}, expected {chk['type']}")
        return  # further checks assume the expected type
    if "min" in chk and isinstance(value, (int, float)) and not isinstance(value, bool):
        if value < chk["min"]:
            errors.append(f"{field}: {value} < min {chk['min']}")
    if "max" in chk and isinstance(value, (int, float)) and not isinstance(value, bool):
        if value > chk["max"]:
            errors.append(f"{field}: {value} > max {chk['max']}")
    if "enum" in chk and value not in chk["enum"]:
        errors.append(f"{field}: {value!r} not in enum {chk['enum']}")
    if "pattern" in chk and isinstance(value, str):
        if not re.fullmatch(chk["pattern"], value):
            errors.append(f"{field}: {value!r} does not match /{chk['pattern']}/")
    if chk.get("non_empty"):
        if isinstance(value, (str, list, dict)) and len(value) == 0:
            errors.append(f"{field}: must be non-empty")


def load_rules(path):
    with open(path, encoding="utf-8") as f:
        rules = json.load(f)
    if not isinstance(rules, list):
        raise SystemExit(f"rules file must be a JSON list of rules: {path}")
    return rules


def lint_rules(rules):
    valid_types = {"number", "string", "bool", "object", "array", "null"}
    errs = []
    for i, rule in enumerate(rules):
        if "match" not in rule or "assert" not in rule:
            errs.append(f"rule[{i}]: must have 'match' and 'assert'")
            continue
        for j, chk in enumerate(rule["assert"]):
            if "field" not in chk:
                errs.append(f"rule[{i}].assert[{j}]: missing 'field'")
            if "type" in chk and chk["type"] not in valid_types:
                errs.append(f"rule[{i}].assert[{j}]: bad type {chk['type']!r}")
            if "pattern" in chk:
                try:
                    re.compile(chk["pattern"])
                except re.error as e:
                    errs.append(f"rule[{i}].assert[{j}]: bad pattern: {e}")
    return errs


def iter_replay(replay_dir):
    for root, _d, files in os.walk(replay_dir):
        for name in files:
            if not name.endswith(".md"):
                continue
            txt = _read(os.path.join(root, name))
            doc = _internal_json(txt)
            method, url, status = _meta(txt, doc)
            body = _response_body(txt, doc)
            yield method, url, status, body, os.path.join(root, name)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rules", required=True)
    ap.add_argument("--golden")      # accepted for a uniform CLI; not required here
    ap.add_argument("--replay")
    ap.add_argument("--lint", action="store_true",
                    help="validate the rules file structure and exit")
    args = ap.parse_args()

    rules = load_rules(args.rules)
    lint_errs = lint_rules(rules)
    if lint_errs:
        print("INVARIANTS RULES FILE INVALID:")
        for e in lint_errs:
            print(f"  - {e}")
        return 1
    if args.lint:
        print(f"invariants rules file OK: {len(rules)} rule(s) in {args.rules}")
        return 0

    if not args.replay:
        ap.error("--replay is required unless --lint")

    checked = failed = 0
    applied_rules = set()
    failures = []
    for method, url, status, body, path in iter_replay(args.replay):
        if body is None:
            continue
        for ri, rule in enumerate(rules):
            if not _match(rule["match"], method, url, status):
                continue
            applied_rules.add(ri)
            errs = []
            for chk in rule["assert"]:
                for present, value in _resolve(body, chk["field"]):
                    _check_value(present, value, chk, chk["field"], errs)
            checked += 1
            if errs:
                failed += 1
                key = f"{method} {url_pattern(url)} [{status}]"
                failures.append((key, os.path.basename(path), errs))

    print(f"property validation: {checked} response-rule application(s) checked against "
          f"{len(rules)} invariant rule(s)")
    unused = [i for i in range(len(rules)) if i not in applied_rules]
    if unused:
        # An invariant that never matched any replayed response is dead weight or a sign the
        # traffic it guards is missing -- report it, but it is not a failure by itself.
        print(f"  INFO {len(unused)} invariant rule(s) matched no replayed response: "
              + ", ".join(str(i) for i in unused))
    if failures:
        print(f"\nPROPERTY VALIDATION FAILED ({failed} response(s) violated an invariant):")
        for key, fname, errs in failures:
            print(f"  {key}  ({fname})")
            for e in errs:
                print(f"      - {e}")
        return 1
    print("property validation PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
