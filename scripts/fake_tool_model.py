"""A scripted OpenAI-compatible model that makes Hermes call tools.

For checking tool-call rendering in the running app without a real model:
point a throwaway Hermes home at it (see the verify-in-app skill) and send any
prompt. Each request plays the next turn of MAIN: two terminal commands, a
todo list, a patch of $SANDBOX/backup.timer, a command that exits 3, and a
chmod Hermes holds for approval, then a closing answer. A prompt containing
"slow" runs `sleep 60` instead, for stopping a reply mid-call.

    python3 scripts/fake_tool_model.py [port]   # default 18555

Arguments stream slowly so "Preparing…" shows. Hermes' own side calls (titles,
approval checks) send no tools and get a short plain answer.
"""
import json
import os
import sys
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SANDBOX = os.environ.get("SANDBOX", "/tmp/hermes-verify")


def call(name, args):
    return {"id": "call_" + uuid.uuid4().hex[:10], "name": name, "args": args}


MAIN = [
    ("Checking the box first.", [
        call("terminal", {"command": "sleep 3; echo first"}),
        call("terminal", {"command": "echo second"}),
    ]),
    ("", [call("todo_list", {"todos": [
        {"id": "1", "content": "Read the logs", "status": "completed"},
        {"id": "2", "content": "Fix the timer", "status": "in_progress"},
        {"id": "3", "content": "Open a PR", "status": "pending"},
    ]})]),
    ("", [call("patch", {"path": f"{SANDBOX}/backup.timer",
                         "old_string": "OnCalendar=*-*-* 02:00",
                         "new_string": "OnCalendar=*-*-* 03:30"})]),
    ("", [call("terminal", {"command": "sleep 2; echo failing >&2; exit 3"})]),
    ("", [call("terminal", {"command": f"chmod -R 777 {SANDBOX}/sandbox"})]),
    ("All done: the timer now runs at 03:30.", []),
]

SLOW = [
    ("", [call("terminal", {"command": "sleep 60; echo late"})]),
    ("Finished waiting.", []),
]


def pick(messages):
    users = [m for m in messages if m.get("role") == "user"]
    last = users[-1]["content"] if users else ""
    if isinstance(last, list):
        last = " ".join(p.get("text", "") for p in last if isinstance(p, dict))
    script = SLOW if "slow" in str(last).lower() else MAIN
    # Count tool-calling turns since the last user message.
    tail = messages[max(i for i, m in enumerate(messages) if m.get("role") == "user"):] if users else messages
    step = sum(1 for m in tail if m.get("role") == "assistant" and m.get("tool_calls"))
    return script[min(step, len(script) - 1)]


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("fake-llm " + fmt % args + "\n")

    def _json(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.rstrip("/").endswith("/models"):
            return self._json(200, {"object": "list", "data": [
                {"id": "fake-tools", "object": "model", "owned_by": "verify",
                 "context_length": 131072}]})
        self._json(404, {"error": "not found"})

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or b"{}")
        if not self.path.rstrip("/").endswith("/chat/completions"):
            return self._json(404, {"error": "not found"})
        text, calls = pick(body.get("messages", []))
        # Hermes' own side calls (titles, summaries) carry no tools.
        if not body.get("tools"):
            text, calls = "Tool call check", []
        cid = "chatcmpl-" + uuid.uuid4().hex[:8]
        finish = "tool_calls" if calls else "stop"
        if not body.get("stream"):
            msg = {"role": "assistant", "content": text or None}
            if calls:
                msg["tool_calls"] = [{"id": c["id"], "type": "function", "function": {
                    "name": c["name"], "arguments": json.dumps(c["args"])}} for c in calls]
            return self._json(200, {"id": cid, "object": "chat.completion", "model": "fake-tools",
                                    "choices": [{"index": 0, "message": msg, "finish_reason": finish}],
                                    "usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}})
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("cache-control", "no-cache")
        self.send_header("connection", "close")
        self.end_headers()

        def chunk(delta, finish_reason=None):
            payload = {"id": cid, "object": "chat.completion.chunk", "model": "fake-tools",
                       "choices": [{"index": 0, "delta": delta, "finish_reason": finish_reason}]}
            self.wfile.write(f"data: {json.dumps(payload)}\n\n".encode())
            self.wfile.flush()

        chunk({"role": "assistant", "content": ""})
        for word in text.split(" ") if text else []:
            chunk({"content": word + " "})
            time.sleep(0.05)
        for i, c in enumerate(calls):
            chunk({"tool_calls": [{"index": i, "id": c["id"], "type": "function",
                                   "function": {"name": c["name"], "arguments": ""}}]})
            args = json.dumps(c["args"])
            # Stream the arguments slowly so "Preparing…" has time to show.
            for j in range(0, len(args), 12):
                chunk({"tool_calls": [{"index": i, "function": {"arguments": args[j:j + 12]}}]})
                time.sleep(0.15)
        chunk({}, finish)
        usage = {"id": cid, "object": "chat.completion.chunk", "model": "fake-tools", "choices": [],
                 "usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}}
        self.wfile.write(f"data: {json.dumps(usage)}\n\ndata: [DONE]\n\n".encode())
        self.wfile.flush()
        self.close_connection = True


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18555
    ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
