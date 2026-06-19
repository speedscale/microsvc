import re

import httpx
import respx
from fastapi.testclient import TestClient

from main import PROVIDER_URLS, app


LLM_REPLY = "Balance looks healthy 💰"


def _anthropic_body(text: str) -> dict:
    return {"content": [{"text": text}]}


def _openai_body(text: str) -> dict:
    return {"choices": [{"message": {"content": text}}]}


def _gemini_body(text: str) -> dict:
    return {"candidates": [{"content": {"parts": [{"text": text}]}}]}


def _mock_providers_with_reply(text: str):
    respx.post(PROVIDER_URLS["anthropic"]).mock(return_value=httpx.Response(200, json=_anthropic_body(text)))
    respx.post(PROVIDER_URLS["openai"]).mock(return_value=httpx.Response(200, json=_openai_body(text)))
    respx.post(url__regex=re.compile(re.escape(PROVIDER_URLS["gemini_base"]) + r"\?key=.*")).mock(
        return_value=httpx.Response(200, json=_gemini_body(text))
    )
    respx.post(PROVIDER_URLS["xai"]).mock(return_value=httpx.Response(200, json=_openai_body(text)))
    respx.post(PROVIDER_URLS["openrouter"]).mock(return_value=httpx.Response(200, json=_openai_body(text)))


@respx.mock
def test_chat_western_locale_allows_model_emoji():
    _mock_providers_with_reply(LLM_REPLY)
    client = TestClient(app, raise_server_exceptions=False)

    response = client.post(
        "/api/chat",
        json={
            "message": "What is my checking balance?",
            "accountContext": "Account: checking, balance: 1234.56",
            "locale": "en-US",
        },
    )

    assert response.status_code == 200
    assert response.json()["results"][0]["message"] == LLM_REPLY


@respx.mock
def test_chat_korean_locale_keeps_delivery_error():
    _mock_providers_with_reply("잔액이 안정적입니다 💰")
    client = TestClient(app, raise_server_exceptions=False)

    response = client.post(
        "/api/chat",
        json={
            "message": "내 계좌 잔액을 알려 주세요.",
            "accountContext": "Account: checking, balance: 1234.56",
            "locale": "ko-KR",
        },
    )

    assert response.status_code == 500
    assert response.text == "Internal Server Error"
