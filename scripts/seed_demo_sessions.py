"""Fills a throwaway Hermes home with demo chats, for store and README screenshots.

    HERMES_HOME=<throwaway home> \
      ~/.hermes/hermes-agent/venv/bin/python scripts/seed_demo_sessions.py

Writes through Hermes's own SessionDB, so the dashboard serves the sessions the
way it serves real ones. Refuses to run without HERMES_HOME or against the real
~/.hermes. The chats are invented; no real data goes in.
"""

import json
import os
import sys
import time
from pathlib import Path

AGENT_DIR = Path(os.environ.get("HERMES_AGENT_DIR", Path.home() / ".hermes" / "hermes-agent"))
MINUTE, HOUR, DAY = 60, 3600, 86400


def tool(name: str, **arguments: str) -> dict:
    return {
        "id": f"call_{abs(hash((name, tuple(arguments.items())))) % 10**8:08d}",
        "type": "function",
        "function": {"name": name, "arguments": json.dumps(arguments)},
    }


BACKUP_ANALYSIS = """The 02:00 run stopped after 41 minutes with a network timeout, so no snapshot was written.

```
error: connection reset by peer (nas-02:8000)
retry 3/3 failed after 30s
```

Restic gave up because its retry limit is 30 seconds and the NAS was busy scrubbing a disk pool at that time.

**What I would change**
- Move the backup to 04:00, after the scrub has finished
- Raise the retry limit to 120 seconds

Want me to update the timer and run it once now?"""

BACKUP_DONE = (
    "Done. The timer now fires at 04:00 and the retry limit is 120 seconds. "
    "A manual run finished in 6 minutes and wrote a fresh snapshot (`a41f9c2`)."
)

RELEASE_NOTES = """Here is a draft for 0.1.11:

**New**
- Apple Watch companion: browse your chats and dictate a reply from your wrist
- Notifications when a reply finishes or the agent needs you

**Fixed**
- Sign-in no longer spins forever if the browser redirect is missed

Want it shorter for the TestFlight changelog?"""

# (id, title, age of the last message, pinned, [(role, content, tool_calls)])
SESSIONS = [
    (
        "demo-backup-failure",
        "Why did last night's backup fail?",
        6 * MINUTE,
        False,
        [
            ("user", "The nightly backup on the NAS did not finish. Can you check what happened?", None),
            (
                "assistant",
                BACKUP_ANALYSIS,
                [
                    tool("terminal", command='journalctl -u restic-backup --since 02:00 | tail -n 30'),
                    tool("read_file", path="/etc/systemd/system/restic-backup.timer"),
                ],
            ),
            ("user", "Yes, please do that.", None),
            (
                "assistant",
                BACKUP_DONE,
                [
                    tool("edit_file", path="/etc/systemd/system/restic-backup.timer", change="OnCalendar=*-*-* 04:00"),
                    tool("terminal", command="systemctl restart restic-backup.timer && restic-backup run"),
                ],
            ),
        ],
    ),
    (
        "demo-release-notes",
        "Draft release notes for 0.1.11",
        2 * HOUR,
        True,
        [
            ("user", "Draft release notes for 0.1.11 from what changed since 0.1.10.", None),
            ("assistant", RELEASE_NOTES, [tool("terminal", command="git log v0.1.10..HEAD --oneline")]),
        ],
    ),
    (
        "demo-tls-rotation",
        "Rotate the staging TLS certificate",
        5 * HOUR,
        False,
        [
            ("user", "The staging certificate expires next week. Rotate it.", None),
            ("assistant", "Rotated. The new certificate is valid until December and nginx reloaded cleanly.", None),
        ],
    ),
    (
        "demo-weekly-alerts",
        "Summarize this week's alerts",
        1 * DAY + 2 * HOUR,
        False,
        [
            ("user", "Summarize this week's alerts.", None),
            ("assistant", "Eleven alerts, nine of them the same disk warning on nas-02. Nothing else needs you.", None),
        ],
    ),
    (
        "demo-pkce",
        "Explain the PKCE flow to a new hire",
        2 * DAY + 4 * HOUR,
        False,
        [
            ("user", "Explain the PKCE flow to a new hire in five sentences.", None),
            ("assistant", "The app makes up a secret, sends only its hash, and keeps the secret to itself.", None),
        ],
    ),
    (
        "demo-nas-plan",
        "Plan the NAS disk replacement",
        4 * DAY,
        False,
        [
            ("user", "Plan the replacement of the failing disk in nas-02.", None),
            ("assistant", "Order a matching 8 TB drive, resilver overnight, and keep the old disk until Monday.", None),
        ],
    ),
]


def main() -> None:
    home = os.environ.get("HERMES_HOME", "").strip()
    if not home:
        sys.exit("HERMES_HOME is not set; point it at a throwaway home.")
    if Path(home).resolve() == (Path.home() / ".hermes").resolve():
        sys.exit("Refusing to write demo chats into the real ~/.hermes.")

    sys.path.insert(0, str(AGENT_DIR))
    from hermes_state import SessionDB

    db = SessionDB()
    now = time.time()
    for session_id, title, age, pinned, messages in SESSIONS:
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
    print(f"seeded {len(SESSIONS)} demo chats into {home}")


if __name__ == "__main__":
    main()
