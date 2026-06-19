#!/usr/bin/env node

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");
const proxymockRoot = path.join(repoRoot, "backend", "ai-service", "proxymock");

function usage() {
  console.error("Usage: scripts/demo-story-traffic-check.mjs [capture-dir]");
}

function newestCaptureDir() {
  if (!fs.existsSync(proxymockRoot)) {
    return null;
  }

  const candidates = fs.readdirSync(proxymockRoot)
    .map((name) => path.join(proxymockRoot, name))
    .filter((entry) => fs.statSync(entry).isDirectory())
    .filter((entry) => /^(live|imported-s3)-/.test(path.basename(entry)))
    .map((entry) => ({ entry, mtime: fs.statSync(entry).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);

  return candidates[0]?.entry || null;
}

function walk(dir, files = []) {
  for (const name of fs.readdirSync(dir)) {
    const file = path.join(dir, name);
    const stat = fs.statSync(file);
    if (stat.isDirectory()) {
      walk(file, files);
    } else if (name.endsWith(".md") || name.endsWith(".json")) {
      files.push(file);
    }
  }
  return files;
}

function parseRRPair(file) {
  const text = fs.readFileSync(file, "utf8");
  if (file.endsWith(".json")) {
    return JSON.parse(text);
  }

  const line = text.split("\n").reverse().find((entry) => entry.startsWith("json: "));
  if (!line) {
    return null;
  }
  return JSON.parse(line.slice("json: ".length));
}

function increment(map, key) {
  map.set(key, (map.get(key) || 0) + 1);
}

function top(map, limit = 12) {
  return [...map.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([name, count]) => ({ name, count }));
}

const requestedDir = process.argv[2] || process.env.PROXYMOCK_CAPTURE_DIR;
if (process.argv.includes("-h") || process.argv.includes("--help")) {
  usage();
  process.exit(0);
}

const captureDir = requestedDir ? path.resolve(requestedDir) : newestCaptureDir();
if (!captureDir || !fs.existsSync(captureDir)) {
  console.error("No proxymock capture directory found.");
  usage();
  process.exit(2);
}

const files = walk(captureDir);
const byHost = new Map();
const byService = new Map();
const byTech = new Map();
const endpointSamples = [];
let parsed = 0;

for (const file of files) {
  let rrpair;
  try {
    rrpair = parseRRPair(file);
  } catch {
    continue;
  }
  if (!rrpair) {
    continue;
  }

  parsed += 1;
  const host = path.basename(path.dirname(file));
  increment(byHost, host);
  increment(byService, rrpair.service || "unknown");
  increment(byTech, rrpair.tech || rrpair.l7protocol || "unknown");

  if (endpointSamples.length < 20 && rrpair.command && rrpair.location) {
    endpointSamples.push({
      host,
      service: rrpair.service || "unknown",
      command: rrpair.command,
      location: rrpair.location,
      status: rrpair.status || "unknown",
    });
  }
}

const hosts = new Set(byHost.keys());
const services = new Set(byService.keys());
const requiredEvidence = [
  ["frontend traffic", services.has("banking-frontend")],
  ["gateway traffic", services.has("banking-gateway") || hosts.has("banking-gateway")],
  ["accounts traffic", services.has("banking-accounts") || hosts.has("banking-accounts")],
  ["transactions traffic", services.has("banking-transactions") || hosts.has("banking-transactions")],
  ["user traffic", services.has("banking-user") || hosts.has("banking-user")],
  ["fraud gRPC traffic", hosts.has("banking-fraud")],
  ["notification traffic", services.has("banking-notification") || hosts.has("banking-notification")],
  ["database traffic", [...hosts].some((host) => host.includes("postgres"))],
  ["cache traffic", [...hosts].some((host) => host.includes("redis"))],
  ["kafka traffic", [...hosts].some((host) => host.includes("kafka"))],
  ["external API traffic", [...hosts].some((host) => !host.startsWith("banking-") && host !== "localhost")],
];

const failures = [];
if (parsed < 50) {
  failures.push(`expected at least 50 parsed RRPairs, got ${parsed}`);
}
for (const [label, ok] of requiredEvidence) {
  if (!ok) {
    failures.push(`missing ${label}`);
  }
}

const result = {
  ok: failures.length === 0,
  captureDir,
  files: files.length,
  parsed,
  topHosts: top(byHost),
  topServices: top(byService),
  topTech: top(byTech),
  endpointSamples,
  failures,
};

console.log(JSON.stringify(result, null, 2));
if (failures.length > 0) {
  process.exit(1);
}
