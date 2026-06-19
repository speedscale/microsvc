"""Locale-aware message preparation for downstream consumers.

Notifications, statements, and the legacy core consume assistant replies
in the user's preferred regional encoding. This module owns that conversion
so callers can hand off a ``(message, locale)`` pair and trust the result
is ready for the downstream pipeline.
"""

LOCALE_CHARSET = {
    "ko-KR": "cp949",
}
DEFAULT_CHARSET = "utf-8"


def prepare_for_delivery(message: str, locale: str) -> bytes:
    """Return ``message`` ready for downstream delivery in ``locale``'s charset."""
    charset = LOCALE_CHARSET.get(locale, DEFAULT_CHARSET)
    return message.encode(charset)
