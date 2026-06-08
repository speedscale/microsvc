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


class ChatRequest(BaseModel):
    message: str
    accountContext: str = ""


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
            "https://api.anthropic.com/v1/messages",
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
            "https://api.openai.com/v1/chat/completions",
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
            f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={key}",
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
            "https://api.x.ai/v1/chat/completions",
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
            "https://openrouter.ai/api/v1/chat/completions",
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
    async with httpx.AsyncClient(timeout=30.0) as client:
        results = await asyncio.gather(
            call_anthropic(client, req.message, req.accountContext),
            call_openai(client, req.message, req.accountContext),
            call_gemini(client, req.message, req.accountContext),
            call_xai(client, req.message, req.accountContext),
            call_openrouter(client, req.message, req.accountContext),
        )
    for r in results:
        if r.error:
            logger.warning("provider=%s error=%s duration=%dms", r.provider, r.error, r.durationMs)
        else:
            logger.info("provider=%s duration=%dms", r.provider, r.durationMs)
    return ChatResponse(results=list(results))


@app.get("/api/providers")
async def providers():
    return PROVIDERS


@app.get("/health")
async def health():
    return {"status": "ok"}
