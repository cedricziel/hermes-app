"""Fills a throwaway Hermes home with demo chats, for store and README screenshots.

    HERMES_HOME=<throwaway home> \
      ~/.hermes/hermes-agent/venv/bin/python scripts/seed_demo_sessions.py

The chats live in demo_sessions.json, which the README screenshot test also reads.
Writes through Hermes's own SessionDB, so the dashboard serves the sessions the
way it serves real ones. Refuses to run without HERMES_HOME or against the real
~/.hermes. The chats are invented; no real data goes in.
"""

import json
import os
import re
import sys
import time
from urllib.request import Request, urlopen
from pathlib import Path

AGENT_DIR = Path(os.environ.get("HERMES_AGENT_DIR", Path.home() / ".hermes" / "hermes-agent"))
MINUTE = 60
DEMO_SESSIONS = Path(__file__).with_name("demo_sessions.json")
DEMO_KANBAN = Path(__file__).with_name("demo_kanban.json")


def seed_kanban(home: str, url: str) -> None:
    headers = {"Content-Type": "application/json"}

    def request(path: str, body: dict | None = None, method: str = "GET") -> dict:
        data = json.dumps(body).encode() if body is not None else None
        call = Request(url + path, data=data, method=method, headers=headers)
        with urlopen(call, timeout=15) as response:
            return json.load(response)

    status = request("/api/status")
    if Path(status.get("hermes_home", "")).resolve() != Path(home).resolve():
        sys.exit("Refusing to seed Kanban outside the throwaway Hermes home.")
    with urlopen(url + "/", timeout=15) as response:
        page = response.read().decode()
    token = re.search(r'__HERMES_SESSION_TOKEN__\s*=\s*"([^"]+)"', page)
    if not token:
        sys.exit("The demo dashboard page has no session token.")
    headers["X-Hermes-Session-Token"] = token.group(1)
    tasks = json.loads(DEMO_KANBAN.read_text())["tasks"]
    for index, task in enumerate(tasks):
        created = request(
            "/api/plugins/kanban/tasks",
            {
                "title": task["title"],
                "body": task["body"],
                "priority": task["priority"],
                "idempotency_key": f"store-screenshot-task-{index}",
            },
            "POST",
        )
        task_id = created.get("id") or created.get("task", {}).get("id")
        if not task_id:
            sys.exit("Kanban task creation returned no task ID.")
        if created.get("task", {}).get("status") == task["status"]:
            continue
        request(
            f"/api/plugins/kanban/tasks/{task_id}",
            {"status": task["status"], "summary": task.get("summary")},
            "PATCH",
        )
    print(f"seeded {len(tasks)} demo Kanban tasks into {home}")


def tool(name: str, arguments: dict) -> dict:
    return {
        "id": f"call_{abs(hash((name, tuple(arguments.items())))) % 10**8:08d}",
        "type": "function",
        "function": {"name": name, "arguments": json.dumps(arguments)},
    }


def load_sessions() -> list[tuple]:
    """(id, title, age of the last message, pinned, [(role, content, tool_calls)])"""
    data = json.loads(DEMO_SESSIONS.read_text())
    return [
        (
            session["id"],
            session["title"],
            session["age_seconds"],
            session["pinned"],
            [
                (
                    message["role"],
                    message["content"],
                    [tool(call["name"], call["arguments"]) for call in message["tool_calls"]]
                    if "tool_calls" in message
                    else None,
                )
                for message in session["messages"]
            ],
        )
        for session in data["sessions"]
    ]


def main() -> None:
    home = os.environ.get("HERMES_HOME", "").strip()
    if not home:
        sys.exit("HERMES_HOME is not set; point it at a throwaway home.")
    if Path(home).resolve() == (Path.home() / ".hermes").resolve():
        sys.exit("Refusing to write demo chats into the real ~/.hermes.")

    sys.path.insert(0, str(AGENT_DIR))
    try:
        # Newer installs keep their dependencies outside the interpreter.
        import hermes_bootstrap  # noqa: F401
    except ImportError:
        pass
    from hermes_state import SessionDB

    sessions = load_sessions()
    db = SessionDB()
    now = time.time()
    for session_id, title, age, pinned, messages in sessions:
        last = now - age
        first = last - 5 * MINUTE * len(messages)
        db.create_session(session_id, "api_server", model="demo")
        for offset, (role, content, tool_calls) in enumerate(messages):
            db.append_message(
                session_id,
                role,
                content,
                tool_calls=tool_calls,
                timestamp=first + (last - first) * offset / max(len(messages) - 1, 1),
            )
        db.set_session_title(session_id, title)
        db._write_sql(
            "UPDATE sessions SET started_at = ?, last_activity_at = ?, pinned = ? WHERE id = ?",
            (first, last, 1 if pinned else 0, session_id),
        )
    print(f"seeded {len(sessions)} demo chats into {home}")
    demo_url = os.environ.get("DEMO_SERVER_URL", "").strip()
    if demo_url:
        seed_kanban(home, demo_url)


if __name__ == "__main__":
    main()
