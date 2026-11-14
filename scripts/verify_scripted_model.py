"""A scripted OpenAI-compatible model that answers every turn with one fixed
reply and calls no tools, so a throwaway Hermes can finish a chat turn without
a provider key or a paid call. Used by scripts/verify.sh.

    python3 -I scripts/verify_scripted_model.py <port-file>

Listens on 127.0.0.1 on a port the OS picks and writes that port to
<port-file> once it accepts connections.
"""

import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODEL = "verify-scripted"
REPLY = "Scripted reply: the verify check reached the model."
USAGE = {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def _json(self, payload):
        body = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.rstrip("/").endswith("/models"):
            self._json(
                {
                    "object": "list",
                    "data": [
                        {"id": MODEL, "object": "model", "context_length": 131072}
                    ],
                }
            )
        else:
            self.send_error(404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        request = json.loads(self.rfile.read(length) or b"{}")
        if not request.get("stream"):
            self._json(
                {
                    "id": "chatcmpl-verify",
                    "object": "chat.completion",
                    "model": MODEL,
                    "choices": [
                        {
                            "index": 0,
                            "finish_reason": "stop",
                            "message": {"role": "assistant", "content": REPLY},
                        }
                    ],
                    "usage": USAGE,
                }
            )
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Connection", "close")
        self.end_headers()
        base = {
            "id": "chatcmpl-verify",
            "object": "chat.completion.chunk",
            "model": MODEL,
        }
        chunks = [
            {
                "index": 0,
                "delta": {"role": "assistant", "content": REPLY},
                "finish_reason": None,
            },
            {"index": 0, "delta": {}, "finish_reason": "stop"},
        ]
        for choice in chunks:
            self.wfile.write(
                f"data: {json.dumps({**base, 'choices': [choice]})}\n\n".encode()
            )
        self.wfile.write(
            f"data: {json.dumps({**base, 'choices': [], 'usage': USAGE})}\n\n".encode()
        )
        self.wfile.write(b"data: [DONE]\n\n")
        self.wfile.flush()
        self.close_connection = True


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    with open(sys.argv[1], "w") as f:
        f.write(f"{server.server_address[1]}\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
