import base64
import hashlib
import hmac
import json
import unittest
from unittest.mock import patch
from demo import SECRET, token


class TokenTest(unittest.TestCase):
    def test_expiration_is_relative_even_after_2030(self):
        now = 1924992000
        with patch("demo.time.time", return_value=now):
            value = token()
        header, payload, signature = value.split(".")
        claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
        self.assertEqual(claims["exp"], now + 3600)
        self.assertEqual(claims["roles"], "USER")
        expected = base64.urlsafe_b64encode(hmac.new(SECRET.encode(), (header + "." + payload).encode(), hashlib.sha256).digest()).decode().rstrip("=")
        self.assertEqual(signature, expected)


if __name__ == "__main__":
    unittest.main()
