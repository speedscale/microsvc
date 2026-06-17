import asyncio
import logging
import os
import time

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from prometheus_client import CONTENT_TYPE_LATEST, CollectorRegistry, Counter, Histogram, generate_latest
from pydantic import BaseModel

from delivery import prepare_for_delivery

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# OpenTelemetry — feed spans to the cluster otel-collector so ai-service shows
# up in Jaeger alongside the Java services. The collector address comes from
# OTEL_EXPORTER_OTLP_ENDPOINT (banking-ai-config ConfigMap, http/protobuf on
# :4318 — same as the frontend Node service uses).
_otel_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector.observability:4318")
_otel_service_name = os.environ.get("OTEL_SERVICE_NAME", "ai-service")
_tracer_provider = TracerProvider(resource=Resource.create({"service.name": _otel_service_name, "service.namespace": "banking-app"}))
_tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{_otel_endpoint.rstrip('/')}/v1/traces")))
trace.set_tracer_provider(_tracer_provider)
HTTPXClientInstrumentor().instrument()

app = FastAPI(title="AI Service")
FastAPIInstrumentor.instrument_app(app)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Match the Spring Boot Micrometer metric name + label set the banking-app dashboards use,
# so /api/chat shows up in the cross-service "Errors by Endpoint" / "Status Codes by Service"
# panels alongside the Java services. Histogram (not Counter) so the exposed series is named
# http_server_requests_seconds_count — without prometheus_client's automatic `_total` suffix.
_metrics_registry = CollectorRegistry()
_HTTP_REQUESTS = Histogram(
    "http_server_requests_seconds",
    "HTTP server requests (Micrometer-compatible)",
    ["method", "uri", "status", "outcome"],
    registry=_metrics_registry,
)

# Outbound calls to the 5 LLM providers — feeds the Errors-dashboard "AI Provider Calls" panel
# the same way fraud_external_requests_total used to feed the old fraud third-party panel.
_PROVIDER_REQUESTS = Counter(
    "ai_provider_requests_total",
    "Outbound calls to LLM providers from ai-service",
    ["provider", "status"],
    registry=_metrics_registry,
)


@app.middleware("http")
async def _record_http_metrics(request: Request, call_next):
    if request.url.path in ("/metrics", "/actuator/prometheus", "/health"):
        return await call_next(request)
    start = time.monotonic()
    status_code = 500
    try:
        response = await call_next(request)
        status_code = response.status_code
        return response
    finally:
        elapsed = time.monotonic() - start
        status = str(status_code)
        outcome = "SUCCESS" if status_code < 400 else "CLIENT_ERROR" if status_code < 500 else "SERVER_ERROR"
        _HTTP_REQUESTS.labels(request.method, request.url.path, status, outcome).observe(elapsed)


@app.get("/actuator/prometheus")
@app.get("/metrics")
def _metrics_endpoint() -> Response:
    return Response(generate_latest(_metrics_registry), media_type=CONTENT_TYPE_LATEST)

SYSTEM_PROMPT = (
    "You are a helpful banking assistant for Apex Banking. "
    "Answer questions about the user's accounts and transactions. "
    "Be concise and professional."
)

PROVIDERS = [
    {"provider": "anthropic", "name": "Anthropic Claude", "model": "claude-sonnet-4-20250514"},
    {"provider": "openai", "name": "OpenAI GPT-4o Mini", "model": "gpt-4o-mini"},
    {"provider": "gemini", "name": "Google Gemini", "model": "gemini-2.0-flash"},
    {"provider": "xai", "name": "xAI Grok", "model": "grok-3-mini"},
    {"provider": "openrouter", "name": "OpenRouter Mistral", "model": "mistralai/mistral-small-3.2-24b-instruct"},
]

# Provider endpoints — overridable via env for local development and staging.
PROVIDER_URLS = {
    "anthropic": os.environ.get("ANTHROPIC_URL", "https://api.anthropic.com/v1/messages"),
    "openai": os.environ.get("OPENAI_URL", "https://api.openai.com/v1/chat/completions"),
    "gemini_base": os.environ.get("GEMINI_URL", "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"),
    "xai": os.environ.get("XAI_URL", "https://api.x.ai/v1/chat/completions"),
    "openrouter": os.environ.get("OPENROUTER_URL", "https://openrouter.ai/api/v1/chat/completions"),
}

class ChatRequest(BaseModel):
    message: str
    accountContext: str = ""
    locale: str = "en-US"


class ProviderResult(BaseModel):
    provider: str
    name: str
    model: str
    message: str = ""
    error: str | None = None
    durationMs: int = 0


class ChatResponse(BaseModel):
    results: list[ProviderResult]


async def call_anthropic(client: httpx.AsyncClient, message: str, context: str) -> ProviderResult:
    info = PROVIDERS[0]
    start = time.monotonic()
    try:
        user_content = f"{context}\n\n{message}" if context else message
        resp = await client.post(
            PROVIDER_URLS["anthropic"],
            headers={
                "x-api-key": os.environ.get("AI_API_KEY", ""),
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": info["model"],
                "max_tokens": 1024,
                "system": SYSTEM_PROMPT,
                "messages": [{"role": "user", "content": user_content}],
            },
        )
        _PROVIDER_REQUESTS.labels(info["provider"], str(resp.status_code)).inc()
        resp.raise_for_status()
        data = resp.json()
        text = data["content"][0]["text"]
        return ProviderResult(**info, message=text, durationMs=_elapsed(start))
    except Exception as e:
        return ProviderResult(**info, error=str(e), durationMs=_elapsed(start))


async def call_openai(client: httpx.AsyncClient, message: str, context: str) -> ProviderResult:
    info = PROVIDERS[1]
    start = time.monotonic()
    try:
        resp = await client.post(
            PROVIDER_URLS["openai"],
            headers={
                "Authorization": f"Bearer {os.environ.get('OPENAI_API_KEY', '')}",
                "Content-Type": "application/json",
            },
            json={
                "model": info["model"],
                "max_tokens": 1024,
                "messages": _openai_messages(message, context),
            },
        )
        _PROVIDER_REQUESTS.labels(info["provider"], str(resp.status_code)).inc()
        resp.raise_for_status()
        data = resp.json()
        text = data["choices"][0]["message"]["content"]
        return ProviderResult(**info, message=text, durationMs=_elapsed(start))
    except Exception as e:
        return ProviderResult(**info, error=str(e), durationMs=_elapsed(start))


async def call_gemini(client: httpx.AsyncClient, message: str, context: str) -> ProviderResult:
    info = PROVIDERS[2]
    start = time.monotonic()
    try:
        key = os.environ.get("GEMINI_API_KEY", "")
        user_content = f"{context}\n\n{message}" if context else message
        resp = await client.post(
            f"{PROVIDER_URLS['gemini_base']}?key={key}",
            headers={"Content-Type": "application/json"},
            json={
                "system_instruction": {"parts": [{"text": SYSTEM_PROMPT}]},
                "contents": [{"role": "user", "parts": [{"text": user_content}]}],
            },
        )
        _PROVIDER_REQUESTS.labels(info["provider"], str(resp.status_code)).inc()
        resp.raise_for_status()
        data = resp.json()
        text = data["candidates"][0]["content"]["parts"][0]["text"]
        return ProviderResult(**info, message=text, durationMs=_elapsed(start))
    except Exception as e:
        return ProviderResult(**info, error=str(e), durationMs=_elapsed(start))


async def call_xai(client: httpx.AsyncClient, message: str, context: str) -> ProviderResult:
    info = PROVIDERS[3]
    start = time.monotonic()
    try:
        resp = await client.post(
            PROVIDER_URLS["xai"],
            headers={
                "Authorization": f"Bearer {os.environ.get('XAI_API_KEY', '')}",
                "Content-Type": "application/json",
            },
            json={
                "model": info["model"],
                "max_tokens": 1024,
                "messages": _openai_messages(message, context),
            },
        )
        _PROVIDER_REQUESTS.labels(info["provider"], str(resp.status_code)).inc()
        resp.raise_for_status()
        data = resp.json()
        text = data["choices"][0]["message"]["content"]
        return ProviderResult(**info, message=text, durationMs=_elapsed(start))
    except Exception as e:
        return ProviderResult(**info, error=str(e), durationMs=_elapsed(start))


async def call_openrouter(client: httpx.AsyncClient, message: str, context: str) -> ProviderResult:
    info = PROVIDERS[4]
    start = time.monotonic()
    try:
        resp = await client.post(
            PROVIDER_URLS["openrouter"],
            headers={
                "Authorization": f"Bearer {os.environ.get('OPENROUTER_API_KEY', '')}",
                "Content-Type": "application/json",
            },
            json={
                "model": info["model"],
                "max_tokens": 1024,
                "messages": _openai_messages(message, context),
            },
        )
        _PROVIDER_REQUESTS.labels(info["provider"], str(resp.status_code)).inc()
        resp.raise_for_status()
        data = resp.json()
        text = data["choices"][0]["message"]["content"]
        return ProviderResult(**info, message=text, durationMs=_elapsed(start))
    except Exception as e:
        return ProviderResult(**info, error=str(e), durationMs=_elapsed(start))


def _openai_messages(message: str, context: str) -> list[dict]:
    msgs: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
    user_content = f"{context}\n\n{message}" if context else message
    msgs.append({"role": "user", "content": user_content})
    return msgs


def _elapsed(start: float) -> int:
    return int((time.monotonic() - start) * 1000)


@app.post("/api/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    # Pass the user's locale through to the model so replies match their language/conventions.
    context = req.accountContext
    if req.locale:
        context = (f"{context}\n" if context else "") + (
            f"User locale: {req.locale}. Respond in the language and conventions for this locale."
        )
    async with httpx.AsyncClient(timeout=30.0) as client:
        results = await asyncio.gather(
            call_anthropic(client, req.message, context),
            call_openai(client, req.message, context),
            call_gemini(client, req.message, context),
            call_xai(client, req.message, context),
            call_openrouter(client, req.message, context),
        )
    for r in results:
        if r.error:
            logger.warning("provider=%s error=%s duration=%dms", r.provider, r.error, r.durationMs)
        else:
            logger.info("provider=%s duration=%dms", r.provider, r.durationMs)
    for r in results:
        if r.message:
            prepare_for_delivery(r.message, req.locale)
    return ChatResponse(results=list(results))


@app.get("/api/providers")
async def providers():
    return PROVIDERS


@app.get("/health")
async def health():
    return {"status": "ok"}
