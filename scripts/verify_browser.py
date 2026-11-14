"""Stands in for the system browser during the app's sign-in under
scripts/verify.sh: given the authorize URL the app opened, it signs in to the
throwaway dashboard's password form and follows the loopback redirect back to
the app, as a person in a browser would.

    python3 -I scripts/verify_browser.py <url>

Credentials come from HERMES_VERIFY_USER and HERMES_VERIFY_PASSWORD (synthetic
values verify.sh sets). It only talks to loopback addresses and writes one
line per step, never the credentials, to $HERMES_VERIFY_BROWSER_LOG.
"""

import http.cookiejar
import ipaddress
import json
import os
import sys
import urllib.parse
import urllib.request


def log(message):
    path = os.environ.get("HERMES_VERIFY_BROWSER_LOG")
    if path:
        with open(path, "a") as f:
            f.write(message + "\n")


def loopback(url):
    host = urllib.parse.urlsplit(url).hostname or ""
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return host == "localhost"


def main():
    url = sys.argv[1]
    if not loopback(url):
        log("refused: not a loopback address")
        return 1
    # The proxy must not see loopback traffic.
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}),
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()),
    )
    with opener.open(url, timeout=30) as page:
        landed = page.geturl()
    log(f"opened authorize url, landed on {urllib.parse.urlsplit(landed).path}")
    origin = "{0.scheme}://{0.netloc}".format(urllib.parse.urlsplit(landed))
    body = json.dumps(
        {
            "provider": "basic",
            "username": os.environ["HERMES_VERIFY_USER"],
            "password": os.environ["HERMES_VERIFY_PASSWORD"],
            "next": "",
        }
    ).encode()
    request = urllib.request.Request(
        f"{origin}/auth/password-login",
        data=body,
        method="POST",
        headers={"Content-Type": "application/json", "Origin": origin},
    )
    with opener.open(request, timeout=30) as response:
        target = json.load(response)["next"]
    if not loopback(target):
        log("refused: login redirect is not a loopback address")
        return 1
    log("password login accepted, following the loopback redirect")
    with opener.open(target, timeout=30) as done:
        log(f"app listener answered {done.status}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
