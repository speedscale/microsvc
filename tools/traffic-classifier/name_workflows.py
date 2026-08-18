#!/usr/bin/env python3
"""Name the workflows in a classification.json with a model, then rewrite the report.

The model sees endpoint sequences and field names only, never a field value.
Works with any OpenAI-compatible server (Ollama, LM Studio, vLLM) or Anthropic.
"""
import argparse, json, os, re, sys, urllib.request
from classify import render

PROMPT = """You are labeling API traffic captured from a running system so QA engineers can see which business workflows the capture covers.

Below are workflow patterns. Each is an ordered sequence of API endpoints observed in one unit of work, plus the request/response field NAMES touched (no values). For each pattern, return a short business workflow name, a one-sentence description of what the caller is doing, and a regression-test priority (high/medium/low) with a brief reason.

Return JSON only: {"workflows": [{"index": <int>, "name": <str>, "description": <str>, "priority": <str>, "priority_reason": <str>}]}

Patterns:
%s
"""


def build_prompt(model):
    names = {}
    for r in model["fields"]:
        names.setdefault(r["endpoint"], set()).add(r["field"])
    blocks = []
    for i, w in enumerate(model["workflows"]):
        lines = [f"[{i}] {w['instances']} units, {w['calls']} calls, kind={w['kind']}"]
        lines += [f"  {s}" + (f"   fields: {', '.join(sorted(names[s])[:12])}" if names.get(s) else "") for s in w["steps"]]
        blocks.append("\n".join(lines))
    return PROMPT % "\n\n".join(blocks)


def ask_openai_compatible(prompt, base_url, model):
    body = json.dumps({"model": model, "temperature": 0.2, "max_tokens": 12000, "response_format": {"type": "json_object"},
                       "messages": [{"role": "system", "content": "Reply with a single JSON object and nothing else."},
                                    {"role": "user", "content": prompt}]}).encode()
    req = urllib.request.Request(f"{base_url.rstrip('/')}/chat/completions", data=body, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)["choices"][0]["message"]["content"]


def ask_anthropic(prompt, model):
    from anthropic import Anthropic
    r = Anthropic().messages.create(model=model, max_tokens=16000, output_config={"effort": "medium"},
                                    messages=[{"role": "user", "content": prompt}])
    return next(b.text for b in r.content if b.type == "text")


def parse(text):
    """Pull the workflow object out of a reply that may carry prose or fences."""
    m = re.search(r"```(?:json)?\s*(.*?)```", text, re.S)
    text = m.group(1) if m else text
    for start in (x.start() for x in re.finditer(r"\{", text)):
        depth = 0
        for i in range(start, len(text)):
            depth += (text[i] == "{") - (text[i] == "}")
            if depth == 0:
                try:
                    obj = json.loads(text[start:i + 1])
                    if isinstance(obj, dict) and "workflows" in obj:
                        return {w["index"]: w for w in obj["workflows"]}
                except ValueError:
                    pass
                break
    raise ValueError("no workflow JSON object in reply")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out_dir", help="directory holding classification.json from classify.py")
    ap.add_argument("--provider", choices=["local", "anthropic"], default="local")
    ap.add_argument("--base-url", default="http://localhost:11434/v1", help="OpenAI-compatible endpoint for --provider local")
    ap.add_argument("--model", help="model id (required for local; default claude-opus-5 for anthropic)")
    a = ap.parse_args()
    path = os.path.join(a.out_dir, "classification.json")
    model = json.load(open(path))
    if not model["workflows"]:
        sys.exit("no workflows to name")
    prompt = build_prompt(model)
    if a.provider == "local":
        if not a.model:
            ap.error("--model is required for --provider local")
        raw = ask_openai_compatible(prompt, a.base_url, a.model)
    else:
        raw = ask_anthropic(prompt, a.model or "claude-opus-5")
    named = parse(raw)
    for i, w in enumerate(model["workflows"]):
        if i in named:
            w.update({k: named[i][k] for k in ("name", "description", "priority", "priority_reason") if k in named[i]})
    json.dump(model, open(path, "w"), indent=2, default=str)
    render(model, os.path.join(a.out_dir, "report.md"))
    print(f"named {len(named)} of {len(model['workflows'])} workflows -> {a.out_dir}/report.md")


if __name__ == "__main__":
    main()
