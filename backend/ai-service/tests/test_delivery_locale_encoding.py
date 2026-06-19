import pytest

from delivery import prepare_for_delivery


def test_western_locale_accepts_model_emoji():
    assert prepare_for_delivery("Balance looks healthy 💰", "en-US")


@pytest.mark.parametrize("locale", ["ja-JP", "zh-CN"])
def test_other_eastern_locales_accept_model_emoji(locale):
    assert prepare_for_delivery("Balance looks healthy 💰", locale)


def test_korean_locale_keeps_legacy_delivery_failure():
    with pytest.raises(UnicodeEncodeError):
        prepare_for_delivery("잔액이 안정적입니다 💰", "ko-KR")
