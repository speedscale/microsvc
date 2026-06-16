import asyncio
import logging
import os
import time

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="AI Service")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

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

# Provider endpoints — overridable so the service can be pointed at a proxymock/test
# double instead of the real models (the real ones are non-deterministic and can't be
# driven to a specific edge case on demand).
PROVIDER_URLS = {
    "anthropic": os.environ.get("ANTHROPIC_URL", "https://api.anthropic.com/v1/messages"),
    "openai": os.environ.get("OPENAI_URL", "https://api.openai.com/v1/chat/completions"),
    "gemini_base": os.environ.get("GEMINI_URL", "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"),
    "xai": os.environ.get("XAI_URL", "https://api.x.ai/v1/chat/completions"),
    "openrouter": os.environ.get("OPENROUTER_URL", "https://openrouter.ai/api/v1/chat/completions"),
}

# Downstream delivery (notifications, statements, legacy core) consumes the assistant reply in
# the user's locale-specific encoding. Asian locales were forced to UTF-8 long ago (shift_jis /
# gb2312 are too narrow for the language) so emoji and rare characters survive. Western locales
# are still on legacy cp1252 for downstream compatibility — a model reply with an emoji blows it
# up. Same response payload, the outcome diverges purely by the request's locale.
LOCALE_CHARSET = {
    "en-US": "cp1252", "en-GB": "cp1252",
    "fr-FR": "cp1252", "de-DE": "cp1252", "es-ES": "cp1252", "es-MX": "cp1252",
    "ja-JP": "utf-8", "zh-CN": "utf-8", "ko-KR": "utf-8",
}
DEFAULT_CHARSET = "cp1252"


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
    # Encode each reply in the user's locale charset for downstream delivery. If the model
    # replied in a language outside that charset (the "model drifted to another language"
    # case), this raises UnicodeEncodeError -> 500. Intermittent, per-locale, and invisible
    # in status/latency metrics until you see the actual reply bytes + the locale.
    charset = LOCALE_CHARSET.get(req.locale, DEFAULT_CHARSET)
    for r in results:
        if r.message:
            r.message.encode(charset)
    return ChatResponse(results=list(results))


@app.get("/api/providers")
async def providers():
    return PROVIDERS


@app.get("/health")
async def health():
    return {"status": "ok"}
