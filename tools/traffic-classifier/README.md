# Traffic classifier

Reads captured API traffic and works out the business workflows in it, without anyone writing them down first. For each workflow it reports the steps in order, how often it runs, its error rate, and the data classes it touches, with a sensitivity tier on the fields.

It is a few hundred lines of standard-library Python. There is nothing to install for the default run.

## Try it on the sample

```bash
python3 classify.py --rrpair-dir sample --out-dir out
```

`sample/` is a proxymock recording: ten minutes of traffic through this banking demo, 1,158 inbound calls and 97 sessions, one readable markdown file per call. The run finishes in a couple of seconds. Open `out/report.md`. A model-named version of the same run is checked in as [`sample-report.md`](sample-report.md).

## Run it on your own traffic

Record with [proxymock](https://docs.speedscale.com/proxymock/) from the directory of the app you are capturing, keep the payloads, then point the classifier at the RRPair directory:

```bash
proxymock record -- ./your-app
python3 classify.py --rrpair-dir proxymock/recorded-<timestamp> --out-dir out
```

Or export a snapshot from Speedscale and pass its `action.jsonl` (inbound) and `reaction.jsonl` (downstream, for response bodies) with `--actions` and `--reactions`. Gzipped files work.

## How it works

Four stages.

1. **Identity.** Each call is attributed to whoever made it: the subject in a JWT, then a username or email in the body or query string (so the anonymous start of a login stitches onto the authenticated remainder), then a hashed API key or tenant header for machine callers. Sessions are keyed on cluster plus identity, because one capture can carry more than one environment.
2. **Sessions and cuts.** Calls per identity are split on an idle gap into sessions. Inside a session, a state-changing call anchors a unit of work: the write plus the reads that verify it. Read-only stretches are cut on a short pause instead, since a screen fires a burst of calls and a person then sits still. Polling loops are folded, so `A>B>A>B` reads as one thing.
3. **Clustering.** Units with the same anchoring write and roughly the same reads around it are the same workflow. Reads that appear in a minority of an action's units are ignored, so one optional lookup does not fork a pattern. Read-only units key on exactly what they touched. Each pattern is labelled `action`, `journey`, `polling` or `single-read`.
4. **Data classes.** Every request and response field is walked and tagged. Unambiguous value formats win first (a valid card number, a JWT, an email), then the field name, then formats that only mean something without a name. Classes roll up to `restricted`, `confidential` or `internal`, and each workflow carries the highest tier it touches. Free-text fields with only a handful of distinct values are treated as status messages, not prose worth scanning.

For gRPC the HTTP method is always POST, so intent is read from the RPC name instead (`Retrieve*` reads, `Create*` / `Upload*` / `Send*` writes).

## Naming workflows with a model

Names like `create transactions, then check accounts, balance` are the built-in fallback. For readable names, pass `--namer`. The model sees endpoint sequences and field **names** only, never a single field value.

```bash
# any OpenAI-compatible server: Ollama, LM Studio, vLLM, oMLX
python3 classify.py ... --namer local --base-url http://localhost:11434/v1 --model llama3.1

# Anthropic (needs ANTHROPIC_API_KEY and `pip install anthropic`)
python3 classify.py ... --namer anthropic
```

## Useful flags

| Flag | Meaning |
| --- | --- |
| `--cluster NAME` | keep one Kubernetes cluster when a capture holds several; the report warns when it does |
| `--gap-seconds` | idle time that ends a session (default 120) |
| `--read-gap-seconds` | pause that ends a read-only unit of work (default 15) |
| `--min-sessions` | drop patterns seen fewer times than this (default 2; use 1 for a thin capture) |

## What it does not do yet

- The unstructured free-text detector is written but unproven, because the sample has no real prose in it.
- Field classification reads JSON only. Protobuf and other binary payloads classify as nothing.
- Workflows are per service. Cross-service journeys stitched on a trace or work-order id are not implemented.

## Where the sample came from

`sample/localhost/` is ten minutes of inbound traffic to `banking-gateway`, driven by the simulation client in this repo and captured by Speedscale, then exported with `proxymock import`. `sample/banking-*/` holds up to ten of the gateway's downstream calls per endpoint, enough to classify response fields. Three edits were made to the files: the cluster name was replaced, password values were masked to `<redacted>` (consistently across the visible body, the signature and the internal record), and list responses over 20 KB were cut to five elements, which the classifier never reads past. All users, accounts and amounts are synthetic.
