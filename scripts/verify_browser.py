"""Stands in for the system browser during the app's sign-in under
scripts/verify.sh: given the authorize URL the app opened, it signs in to the
throwaway dashboard's password form and follows the loopback redirect back to
the app, as a person in a browser would.

    python3 -I scripts/verify_browser.py <url>

HERMES_VERIFY_ORIGIN is the throwaway dashboard's exact origin
(http://127.0.0.1:<port>). The authorize URL and every redirect must stay on
that origin, and the login's redirect must go to the listener the authorize
URL's redirect_uri names (http://127.0.0.1:<port>/<path>), without the
dashboard's cookies; anything else is refused before credentials are
sent, or before the code is handed on. Credentials come from
HERMES_VERIFY_USER and HERMES_VERIFY_PASSWORD (synthetic values verify.sh
sets). One line per step, never the credentials, goes to
$HERMES_VERIFY_BROWSER_LOG.
"""

import http.cookiejar
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

MAX_REDIRECTS = 5


class Refused(Exception):
    pass


def log(message):
    path = os.environ.get("HERMES_VERIFY_BROWSER_LOG")
    if path:
        with open(path, "a") as f:
            f.write(message + "\n")


def origin_of(url):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "http" or parts.port is None:
        return None
    return f"http://{parts.hostname}:{parts.port}"


def check_origin(url, expected):
    if origin_of(url) != expected:
        raise Refused(
            f"{urllib.parse.urlsplit(url).scheme}:// URL off the dashboard origin"
        )


def check_listener(url, redirect_uri):
    """The code may only go to the listener the app named in its authorize
    URL: same http scheme, 127.0.0.1, port and path."""
    want = urllib.parse.urlsplit(redirect_uri)
    got = urllib.parse.urlsplit(url)
    if (
        want.scheme != "http"
        or want.hostname != "127.0.0.1"
        or want.port is None
        or (got.scheme, got.hostname, got.port, got.path)
        != (want.scheme, want.hostname, want.port, want.path)
    ):
        raise Refused("login redirect is not the app's listener from redirect_uri")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


def sign_in(url, expected, user, password, opener):
    check_origin(url, expected)
    redirect_uri = urllib.parse.parse_qs(urllib.parse.urlsplit(url).query).get(
        "redirect_uri", [""]
    )[0]
    for _ in range(MAX_REDIRECTS + 1):
        try:
            with opener.open(url, timeout=30):
                break
        except urllib.error.HTTPError as e:
            if e.code not in (301, 302, 303, 307, 308):
                raise
            url = urllib.parse.urljoin(url, e.headers.get("Location", ""))
            check_origin(url, expected)
    else:
        raise Refused("too many redirects")
    log(f"opened authorize url, landed on {urllib.parse.urlsplit(url).path}")
    body = json.dumps(
        {"provider": "basic", "username": user, "password": password, "next": ""}
    ).encode()
    request = urllib.request.Request(
        f"{expected}/auth/password-login",
        data=body,
        method="POST",
        headers={"Content-Type": "application/json", "Origin": expected},
    )
    with opener.open(request, timeout=30) as response:
        target = json.load(response)["next"]
    check_listener(target, redirect_uri)
    log("password login accepted, following the loopback redirect")
    # Cookies are not scoped by port: the dashboard's session cookie must not
    # go along to the app's listener.
    plain = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with plain.open(target, timeout=30) as done:
            status = done.status
    except urllib.error.HTTPError as e:
        status = e.code  # a redirect to a "done" page is not followed
    log(f"app listener answered {status}")


def main():
    expected = os.environ.get("HERMES_VERIFY_ORIGIN", "")
    if origin_of(expected) != expected.rstrip("/") or not expected:
        log("refused: HERMES_VERIFY_ORIGIN is not an http://host:port origin")
        return 2
    # The proxy must not see loopback traffic.
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()),
        NoRedirect(),
    )
    try:
        sign_in(
            sys.argv[1],
            expected.rstrip("/"),
            os.environ["HERMES_VERIFY_USER"],
            os.environ["HERMES_VERIFY_PASSWORD"],
            opener,
        )
    except Refused as e:
        log(f"refused: {e}")
        print(f"verify_browser: refused: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
