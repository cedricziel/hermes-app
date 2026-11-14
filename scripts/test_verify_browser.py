"""Tests for scripts/verify_browser.py: credentials go only to the exact
dashboard origin, and the code only to the app's 127.0.0.1 listener.

    python3 -I scripts/test_verify_browser.py
"""

import importlib.util
import json
import pathlib
import threading
import unittest
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "verify_browser", ROOT / "scripts" / "verify_browser.py"
)
browser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(browser)


def serve(handler):
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


class Recorder:
    def __init__(self):
        self.requests = []
        self.cookies = []


def dashboard(record, redirect_to=None, next_url=None):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            record.requests.append(("GET", self.path))
            if self.path.startswith("/auth/native/authorize"):
                self.send_response(302)
                self.send_header("Location", redirect_to or "/login")
                self.end_headers()
            else:
                self.send_response(200)
                self.send_header("Set-Cookie", "hermes_session=SESSIONSECRET; Path=/")
                self.send_header("Content-Length", "0")
                self.end_headers()

        def do_POST(self):
            length = int(self.headers.get("Content-Length") or 0)
            record.requests.append(("POST", self.path, self.rfile.read(length)))
            body = json.dumps({"ok": True, "next": next_url()}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


def listener(record):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            record.requests.append(("GET", self.path))
            record.cookies.append(self.headers.get("Cookie"))
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()

    return Handler


class VerifyBrowserTest(unittest.TestCase):
    def setUp(self):
        self.app = Recorder()
        self.app_server = serve(listener(self.app))
        self.app_port = self.app_server.server_address[1]
        self.backend = Recorder()
        self.next_url = f"http://127.0.0.1:{self.app_port}/callback?code=c&state=s"
        self.redirect_uri = urllib.parse.quote(
            f"http://127.0.0.1:{self.app_port}/callback", safe=""
        )
        self.servers = [self.app_server]

    def tearDown(self):
        for server in self.servers:
            server.shutdown()
            server.server_close()

    def start_dashboard(self, **kwargs):
        server = serve(dashboard(self.backend, next_url=lambda: self.next_url, **kwargs))
        self.servers.append(server)
        return f"http://127.0.0.1:{server.server_address[1]}"

    def authorize(self, origin):
        return f"{origin}/auth/native/authorize?redirect_uri={self.redirect_uri}"

    def run_browser(self, url, origin):
        opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}),
            urllib.request.HTTPCookieProcessor(),
            browser.NoRedirect(),
        )
        browser.sign_in(url, origin, "verify", "synthetic", opener)

    def posted(self):
        return [r for r in self.backend.requests if r[0] == "POST"]

    def test_signs_in_and_hands_the_code_to_the_listener(self):
        origin = self.start_dashboard()
        self.run_browser(self.authorize(origin), origin)
        self.assertEqual(len(self.posted()), 1)
        self.assertEqual(self.app.requests, [("GET", "/callback?code=c&state=s")])
        self.assertEqual(self.app.cookies, [None])

    def test_refuses_a_url_on_another_port(self):
        origin = self.start_dashboard()
        with self.assertRaises(browser.Refused):
            self.run_browser(f"http://127.0.0.1:{self.app_port}/auth/native/authorize", origin)
        self.assertEqual(self.app.requests, [])
        self.assertEqual(self.posted(), [])

    def test_refuses_localhost_for_a_127_origin(self):
        origin = self.start_dashboard()
        port = origin.rsplit(":", 1)[1]
        with self.assertRaises(browser.Refused):
            self.run_browser(f"http://localhost:{port}/auth/native/authorize", origin)
        self.assertEqual(self.backend.requests, [])

    def test_refuses_a_redirect_off_the_origin(self):
        origin = self.start_dashboard(
            redirect_to=f"http://127.0.0.1:{self.app_port}/login"
        )
        with self.assertRaises(browser.Refused):
            self.run_browser(self.authorize(origin), origin)
        self.assertEqual(self.posted(), [])
        self.assertEqual(self.app.requests, [])

    def test_refuses_a_non_http_scheme(self):
        origin = self.start_dashboard()
        port = origin.rsplit(":", 1)[1]
        for url in (
            f"https://127.0.0.1:{port}/auth/native/authorize",
            f"file:///etc/passwd",
        ):
            with self.subTest(url=url), self.assertRaises(browser.Refused):
                self.run_browser(url, origin)
        self.assertEqual(self.backend.requests, [])

    def test_refuses_a_login_redirect_that_is_not_the_listener(self):
        origin = self.start_dashboard()
        for url in (
            f"http://localhost:{self.app_port}/callback?code=c",
            "https://127.0.0.1/callback?code=c",
            "http://198.51.100.7:8080/callback?code=c",
        ):
            self.next_url = url
            with self.subTest(url=url), self.assertRaises(browser.Refused):
                self.run_browser(self.authorize(origin), origin)
        self.assertEqual(self.app.requests, [])

    def test_refuses_a_listener_other_than_the_redirect_uri(self):
        origin = self.start_dashboard()
        other = serve(listener(Recorder()))
        self.servers.append(other)
        for url in (
            f"http://127.0.0.1:{other.server_address[1]}/callback?code=c",
            f"http://127.0.0.1:{self.app_port}/elsewhere?code=c",
        ):
            self.next_url = url
            with self.subTest(url=url), self.assertRaises(browser.Refused):
                self.run_browser(self.authorize(origin), origin)
        self.assertEqual(self.app.requests, [])


if __name__ == "__main__":
    unittest.main()
