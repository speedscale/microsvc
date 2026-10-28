#!/usr/bin/env python3
"""Schema-validate replayed api-gateway responses against the golden snapshot.

proxymock replay asserts routing and status codes; it does not, on its own, assert the
SHAPE of the JSON the gateway proxies back. This tool adds that layer: it derives a JSON
schema per (method, url-pattern, status) from the recorded golden responses, then checks
that each replayed observed response still conforms -- same fields, same types, structure
intact -- while letting volatile values (ids, timestamps, balances) vary freely.

What counts as a schema break (exit 1):
  - a required field present in every golden example is missing from the observed response
  - a field's JSON type changed incompatibly (e.g. object -> array, string -> number;
    int<->float are both "number" and OK; null is allowed only where golden showed null)
  - the top-level JSON kind changed (object vs array vs scalar)

What is allowed (not a break):
  - different values
  - ADDITIVE fields the observed response gained (reported as info, not a failure)
  - empty arrays/objects in golden (treated as permissive -- no element/field constraints)

Contract coverage (--require-coverage):
  Validation only inspects responses the replay actually produced. On its own it cannot
  tell you that an operation the golden documents went UNtested -- a replay that exercised
  zero endpoints would "pass" vacuously. The coverage report closes that gap: it treats the
  golden as the contract and reports, explicitly,
    - MISSING OPERATIONS: a (method, url-pattern, status) the golden documents that the
      replay never produced,
    - MISSING FIELDS: a response field present in the golden schema for a covered operation
      that no observed response for it carried.
  With --require-coverage, any missing operation (and, with --strict-field-coverage, any
  missing field) fails the run, so the gate asserts the contract is fully exercised, not
  just that whatever ran conformed.

Dependency-free (stdlib only) so it runs in a pre-commit hook and CI without `pip install`.

Usage:
  schema_validate.py --golden <recorded-golden-dir> --replay <replay-out-dir>
  schema_validate.py --golden <dir> --print-schemas      # dump derived schemas and exit
  schema_validate.py --golden <dir> --replay <dir> --require-coverage
      # additionally fail if any golden operation was not exercised by the replay
  schema_validate.py --golden <dir> --replay <dir> --require-coverage --strict-field-coverage
      # also fail if a covered operation left any golden field unobserved
"""
import argparse
import json
import os
import re
import sys


# ---- rrpair parsing -------------------------------------------------------

def _read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def _internal_json(txt):
    """Return the parsed INTERNAL 'json: {...}' doc, or None."""
    m = re.search(r"\njson: (\{.*\})\s*\n```", txt, re.DOTALL)
    if not m:
        return None
    try:
        return json.loads(m.group(1))
    except Exception:
        return None


def _response_body(txt, doc):
    """Extract the response body as a parsed JSON value, or None if absent/non-JSON.

    Prefer the INTERNAL json's res.bodyBase64 (authoritative); fall back to the second
    fenced block of the human-readable RESPONSE section.
    """
    import base64

    if doc is not None:
        res = doc.get("http", {}).get("res", {})
        b64 = res.get("bodyBase64")
        if b64:
            try:
                raw = base64.b64decode(b64).decode("utf-8", "replace")
                return json.loads(raw)
            except Exception:
                return None
    # Fallback: human-readable RESPONSE section, 2nd fenced block (headers then body).
    m = re.search(r"### RESPONSE ###\n(.*?)\n### (?:SIGNATURE|METADATA) ###", txt, re.DOTALL)
    if not m:
        return None
    fences = re.findall(r"```\n(.*?)\n```", m.group(1), re.DOTALL)
    if len(fences) < 2:
        return None
    body = fences[1].strip()
    if not body:
        return None
    try:
        return json.loads(body)
    except Exception:
        return None


def _meta(txt, doc):
    """(method, url, status) for an rrpair."""
    method = url = status = None
    if doc is not None:
        method = doc.get("http", {}).get("req", {}).get("method")
        url = doc.get("http", {}).get("req", {}).get("url")
        sc = doc.get("http", {}).get("res", {}).get("statusCode")
        status = str(sc) if sc is not None else None
    if not method:
        m = re.search(r"^http:method is (.+)$", txt, re.MULTILINE)
        method = m.group(1).strip() if m else "?"
    if not url:
        m = re.search(r"^http:url is (.+)$", txt, re.MULTILINE)
        url = m.group(1).strip() if m else "?"
    return method, url, status


_NUM_SEG = re.compile(r"^\d+$")


def url_pattern(url):
    """Collapse numeric path segments so /api/accounts/226722/balance and .../589223/...
    share one schema: -> /api/accounts/{id}/balance. Query string is dropped."""
    path = url.split("?", 1)[0]
    segs = [("{id}" if _NUM_SEG.match(s) else s) for s in path.split("/")]
    return "/".join(segs)


def endpoint_key(method, url, status):
    return f"{method} {url_pattern(url)} [{status}]"


# ---- schema inference -----------------------------------------------------

# JSON type tags. int/float both map to "number"; null tracked separately as nullability.
def _type_tag(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "bool"
    if isinstance(v, (int, float)):
        return "number"
    if isinstance(v, str):
        return "string"
    if isinstance(v, list):
        return "array"
    if isinstance(v, dict):
        return "object"
    return "unknown"


def infer(value):
    """Infer a schema node from one example value."""
    tag = _type_tag(value)
    node = {"types": {tag}}
    if tag == "object":
        node["props"] = {k: infer(v) for k, v in value.items()}
    elif tag == "array":
        elem = None
        for item in value:
            elem = merge(elem, infer(item)) if elem is not None else infer(item)
        node["elem"] = elem  # None => empty array seen (permissive)
    return node


def merge(a, b):
    """Merge two schema nodes (union of types; props required only if in BOTH)."""
    if a is None:
        return b
    if b is None:
        return a
    out = {"types": a["types"] | b["types"]}
    if "object" in out["types"]:
        pa, pb = a.get("props", {}), b.get("props", {})
        props = {}
        for k in set(pa) | set(pb):
            if k in pa and k in pb:
                props[k] = merge(pa[k], pb[k])
                props[k]["_required"] = pa[k].get("_required", True) and pb[k].get("_required", True)
            else:
                # present in only one example -> optional
                props[k] = (pa.get(k) or pb.get(k))
                props[k] = dict(props[k])
                props[k]["_required"] = False
        out["props"] = props
    if "array" in out["types"]:
        ea, eb = a.get("elem"), b.get("elem")
        out["elem"] = merge(ea, eb)
    return out


def build_schemas(golden_dir):
    """endpoint_key -> schema node, inferred from every golden response with a JSON body."""
    schemas = {}
    inbound = os.path.join(golden_dir, "localhost")
    roots = [inbound] if os.path.isdir(inbound) else [golden_dir]
    for root in roots:
        for name in sorted(os.listdir(root)):
            if not name.endswith(".md"):
                continue
            txt = _read(os.path.join(root, name))
            doc = _internal_json(txt)
            method, url, status = _meta(txt, doc)
            body = _response_body(txt, doc)
            if body is None:
                continue  # empty/non-JSON (e.g. 401) -> no schema
            key = endpoint_key(method, url, status)
            node = infer(body)
            schemas[key] = merge(schemas.get(key), node)
    return schemas


# ---- validation -----------------------------------------------------------

def _compatible(expected_types, observed_tag):
    # If golden only ever showed null for a field, its real type is unknown, so accept
    # anything (null or a concrete value) rather than pin it to null.
    if expected_types == {"null"}:
        return True
    # A nullable field (null seen alongside a concrete type) accepts null or that type.
    return observed_tag in expected_types


def validate(node, value, path, errors):
    tag = _type_tag(value)
    if not _compatible(node["types"], tag):
        # Allow null only where golden saw null.
        errors.append(f"{path}: type {tag} not in golden types {sorted(node['types'])}")
        return
    if tag == "object" and "object" in node["types"]:
        props = node.get("props", {})
        for k, child in props.items():
            if child.get("_required", True) and k not in value:
                errors.append(f"{path}.{k}: required field missing")
            elif k in value:
                validate(child, value[k], f"{path}.{k}", errors)
        # extra keys: additive, reported by caller separately (not here)
    elif tag == "array" and "array" in node["types"]:
        elem = node.get("elem")
        if elem is not None:
            for i, item in enumerate(value):
                validate(elem, item, f"{path}[{i}]", errors)


def extra_fields(node, value, path, extras):
    tag = _type_tag(value)
    if tag == "object" and node and "props" in node:
        for k in value:
            if k not in node["props"]:
                extras.append(f"{path}.{k}")
            else:
                extra_fields(node["props"][k], value[k], f"{path}.{k}", extras)
    elif tag == "array" and node and node.get("elem") is not None and value:
        extra_fields(node["elem"], value[0], f"{path}[0]", extras)


# ---- contract coverage ----------------------------------------------------

def schema_field_paths(node, prefix="$"):
    """Flatten a schema node to the set of REQUIRED field paths it documents.

    Only required fields count toward field coverage (optional/additive fields are not part
    of the contract every response must carry). Arrays descend into their element schema
    with a [] marker so object fields inside a list are reported once, not per index.
    """
    paths = set()
    if "object" in node.get("types", set()):
        for k, child in node.get("props", {}).items():
            if not child.get("_required", True):
                continue
            cp = f"{prefix}.{k}"
            paths.add(cp)
            paths |= schema_field_paths(child, cp)
    if "array" in node.get("types", set()) and node.get("elem") is not None:
        paths |= schema_field_paths(node["elem"], f"{prefix}[]")
    return paths


def observed_field_paths(value, prefix="$"):
    """Flatten an observed response body to the set of field paths actually present."""
    paths = set()
    tag = _type_tag(value)
    if tag == "object":
        for k, v in value.items():
            cp = f"{prefix}.{k}"
            paths.add(cp)
            paths |= observed_field_paths(v, cp)
    elif tag == "array":
        for item in value:
            paths |= observed_field_paths(item, f"{prefix}[]")
    return paths


def iter_replay(replay_dir):
    """Yield (endpoint_key, body-or-None) for every observed replayed response."""
    for root, _d, files in os.walk(replay_dir):
        for name in files:
            if not name.endswith(".md"):
                continue
            txt = _read(os.path.join(root, name))
            doc = _internal_json(txt)
            method, url, status = _meta(txt, doc)
            body = _response_body(txt, doc)
            yield endpoint_key(method, url, status), body, os.path.join(root, name)


# ---- cli ------------------------------------------------------------------

def _print_schema(node, indent=0):
    pad = "  " * indent
    types = "|".join(sorted(node["types"]))
    if "object" in node["types"] and node.get("props"):
        print(f"{pad}object")
        for k, child in sorted(node["props"].items()):
            req = "" if child.get("_required", True) else "?"
            print(f"{pad}  {k}{req}:", end=" ")
            if "object" in child["types"] or "array" in child["types"]:
                print()
                _print_schema(child, indent + 2)
            else:
                print("|".join(sorted(child["types"])))
    elif "array" in node["types"]:
        print(f"{pad}array of:")
        if node.get("elem"):
            _print_schema(node["elem"], indent + 1)
        else:
            print(f"{pad}  (empty in golden - permissive)")
    else:
        print(f"{pad}{types}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--golden", required=True)
    ap.add_argument("--replay")
    ap.add_argument("--print-schemas", action="store_true")
    ap.add_argument("--require-coverage", action="store_true",
                    help="fail if any golden operation (method, url, status) was not "
                         "exercised by the replay")
    ap.add_argument("--strict-field-coverage", action="store_true",
                    help="with --require-coverage, also fail if a covered operation left any "
                         "required golden field unobserved")
    args = ap.parse_args()

    schemas = build_schemas(args.golden)

    if args.print_schemas or not args.replay:
        for key in sorted(schemas):
            print(f"\n=== {key} ===")
            _print_schema(schemas[key])
        return 0

    checked = failed = no_schema = 0
    all_extras = []
    failures = []
    observed_ops = set()               # endpoint keys the replay actually produced
    observed_fields = {}               # endpoint key -> set of field paths seen across responses
    for key, body, path in iter_replay(args.replay):
        if body is None:
            continue  # empty/non-JSON observed response (e.g. 401) -> nothing to validate
        node = schemas.get(key)
        if node is None:
            no_schema += 1
            continue
        observed_ops.add(key)
        observed_fields.setdefault(key, set()).update(observed_field_paths(body))
        checked += 1
        errs = []
        validate(node, body, "$", errs)
        extras = []
        extra_fields(node, body, "$", extras)
        if extras:
            all_extras.append((key, extras))
        if errs:
            failed += 1
            failures.append((key, os.path.basename(path), errs))

    print(f"schema validation: {checked} response(s) checked against {len(schemas)} schema(s)")
    if no_schema:
        print(f"  ({no_schema} observed response(s) had no golden schema and were skipped)")
    for key, extras in all_extras:
        print(f"  INFO additive field(s) in {key}: {', '.join(sorted(set(extras)))}")

    # --- contract coverage -------------------------------------------------------------
    # The golden is the contract. Report operations/fields it documents that the replay did
    # not exercise. Always printed (visibility); only gates when --require-coverage.
    golden_ops = {k for k, n in schemas.items()}
    missing_ops = sorted(golden_ops - observed_ops)
    missing_fields = []  # (op, [paths])
    for key in sorted(observed_ops):
        want = schema_field_paths(schemas[key])
        got = observed_fields.get(key, set())
        gap = sorted(want - got)
        if gap:
            missing_fields.append((key, gap))

    print(f"\ncontract coverage: {len(observed_ops)}/{len(golden_ops)} golden operation(s) "
          "exercised by the replay")
    if missing_ops:
        print(f"  MISSING OPERATIONS ({len(missing_ops)}): golden operations not exercised:")
        for k in missing_ops:
            print(f"      - {k}")
    if missing_fields:
        print("  MISSING FIELDS: golden fields never present in any observed response:")
        for key, gap in missing_fields:
            print(f"      {key}: {', '.join(gap)}")
    if not missing_ops and not missing_fields:
        print("  full contract coverage: every golden operation and field was observed.")

    coverage_failed = False
    if args.require_coverage and missing_ops:
        coverage_failed = True
    if args.require_coverage and args.strict_field_coverage and missing_fields:
        coverage_failed = True

    if failures:
        print(f"\nSCHEMA VALIDATION FAILED ({failed} response(s)):")
        for key, fname, errs in failures:
            print(f"  {key}  ({fname})")
            for e in errs:
                print(f"      - {e}")
        return 1
    if coverage_failed:
        print("\nCONTRACT COVERAGE FAILED: golden operations/fields were not exercised "
              "(see above). Re-record the missing traffic or park it as a known-gap.")
        return 1
    print("schema validation PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
