import base64
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import re
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from unittest.mock import patch
import demo


class RequestTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        self.source = self.root / "source.md"
        self.original = demo.SOURCE_REQUEST.read_bytes()
        self.source.write_bytes(self.original)
        self.addCleanup(self.directory.cleanup)

    def prepare(self):
        with patch.object(demo, "HERE", self.root), patch.object(demo, "SOURCE_REQUEST", self.source), \
                patch("demo.time.time", return_value=1924992000):
            demo.prepare_request(self.root / "phase/request")
        return (self.root / "phase/request/localhost/deposit.md").read_bytes()

    def test_only_request_authentication_changes(self):
        fresh = self.prepare()
        pattern = rb"(?m)^Authorization: Bearer [^\r\n]+"
        self.assertEqual(re.sub(pattern, b"Authorization: [auth]", fresh),
                         re.sub(pattern, b"Authorization: [auth]", self.original))
        self.assertEqual(self.source.read_bytes(), self.original)
        self.assertEqual((self.root / "traffic/localhost/deposit.md").read_bytes(), self.original)
        jwt = re.search(pattern, fresh).group().split(b"Bearer ")[1]
        payload = jwt.split(b".")[1]
        claims = json.loads(base64.urlsafe_b64decode(payload + b"=" * (-len(payload) % 4)))
        self.assertEqual(claims["exp"], 1924995600)

    def test_response_and_body_header_lookalikes_are_unchanged(self):
        self.source.write_bytes(self.original.replace(b'"accountId": 70668,',
            b'"accountId": 70668,\nAuthorization: Bearer body-text', 1)
            + b"\nAuthorization: Bearer response-text\n")
        fresh = self.prepare()
        self.assertIn(b"Authorization: Bearer body-text", fresh)
        self.assertTrue(fresh.endswith(b"Authorization: Bearer response-text\n"))

    def test_modified_business_fixture_is_rejected(self):
        saved = self.root / "traffic/localhost/deposit.md"
        saved.parent.mkdir(parents=True)
        saved.write_bytes(self.original.replace(b"3.33", b"4.44"))
        with self.assertRaisesRegex(RuntimeError, "differs"):
            self.prepare()

    def test_missing_header_is_rejected(self):
        self.source.write_bytes(re.sub(rb"(?m)^Authorization:[^\r\n]+", b"", self.original))
        with self.assertRaisesRegex(RuntimeError, "exactly one"):
            self.prepare()

    def test_duplicate_header_is_rejected(self):
        self.source.write_bytes(self.original.replace(b"Accept: */*", b"Accept: */*\nAuthorization: Bearer duplicate"))
        with self.assertRaisesRegex(RuntimeError, "exactly one"):
            self.prepare()

    def test_expired_recording_becomes_authenticated_http_request(self):
        now = 1924992000

        class AuthEndpoint(BaseHTTPRequestHandler):
            def do_POST(self):
                jwt = self.headers.get("Authorization", "").removeprefix("Bearer ")
                header, payload, signature = jwt.split(".")
                claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
                expected = base64.urlsafe_b64encode(hmac.new(demo.SECRET.encode(),
                    (header + "." + payload).encode(), hashlib.sha256).digest()).decode().rstrip("=")
                valid = hmac.compare_digest(signature, expected) and claims["exp"] > now
                self.send_response(201 if valid else 401)
                self.end_headers()

            def log_message(self, *args):
                pass

        server = HTTPServer(("127.0.0.1", 0), AuthEndpoint)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            def send(recording):
                bearer = re.search(rb"(?m)^Authorization: (Bearer [^\r\n]+)", recording).group(1).decode()
                request = urllib.request.Request(f"http://127.0.0.1:{server.server_port}/api/transactions/deposit",
                    data=b'{"accountId":70668,"amount":3.33}', headers={"Authorization": bearer})
                return urllib.request.urlopen(request, timeout=3)

            with self.assertRaises(urllib.error.HTTPError) as error:
                send(self.original)
            self.assertEqual(error.exception.code, 401)
            error.exception.close()
            with send(self.prepare()) as response:
                self.assertEqual(response.status, 201)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)


if __name__ == "__main__":
    unittest.main()
