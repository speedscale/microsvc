"""Locale-aware message preparation for downstream consumers.

Notifications, statements, and the legacy core consume assistant replies
in the user's preferred regional encoding. This module owns that conversion
so callers can hand off a ``(message, locale)`` pair and trust the result
is ready for the downstream pipeline.
"""

LOCALE_CHARSET = {
    "en-US": "cp1252", "en-GB": "cp1252",
    "fr-FR": "cp1252", "de-DE": "cp1252", "es-ES": "cp1252", "es-MX": "cp1252",
    "ja-JP": "utf-8", "zh-CN": "utf-8", "ko-KR": "utf-8",
}
DEFAULT_CHARSET = "cp1252"


def prepare_for_delivery(message: str, locale: str) -> bytes:
    """Return ``message`` ready for downstream delivery in ``locale``'s charset."""
    charset = LOCALE_CHARSET.get(locale, DEFAULT_CHARSET)
    return message.encode(charset)
