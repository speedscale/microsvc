import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("AI_API_KEY", "test-key")
os.environ.setdefault("OPENAI_API_KEY", "test-key")
os.environ.setdefault("GEMINI_API_KEY", "test-key")
os.environ.setdefault("XAI_API_KEY", "test-key")
os.environ.setdefault("OPENROUTER_API_KEY", "test-key")
os.environ.setdefault("OTEL_SDK_DISABLED", "true")
