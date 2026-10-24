"""Outbound-only platform: persist a delivery as a normal, replyable app chat.

Both gateway and separate-process sends use SessionDB's public API. No direct
SQL, dashboard credentials, app listener, or changes to Hermes core are needed.
"""

from __future__ import annotations

import asyncio
import logging
from pathlib import Path
from uuid import uuid4

from gateway.config import Platform
from gateway.platforms.base import BasePlatformAdapter, SendResult
from hermes_constants import get_hermes_home

log = logging.getLogger(__name__)
UNSUPPORTED_MEDIA = "Hermes App messenger currently accepts text only."


def configured(config) -> bool:
    return config.enabled is True


def parse_target(target: str):
    return ("inbox", None) if target == "inbox" else None


def _persist(home: Path, message: str) -> dict:
    from hermes_state import SessionDB

    session_id = f"hermes-app-{uuid4().hex}"
    title = next(line.strip() for line in message.splitlines() if line.strip())
    title = "Message: " + title[:70]
    # A fresh session avoids editing a live agent's cached conversation and
    # keeps repeated deliveries out of a transcript of consecutive assistants.
    with SessionDB(db_path=home / "state.db") as db:
        db.create_session(session_id, source="hermes_app")
        try:
            # Unread from the start: a client listing sessions between the
            # writes below must not see a read delivery and skip it for good.
            db.set_session_read(session_id, False)
            row_id = db.append_message(session_id, role="assistant", content=message)
            try:
                db.set_auto_title(session_id, title, source="derived")
            except ValueError:
                # Hermes enforces unique titles. Repeated reports still need
                # independent deliveries, including concurrent sends.
                db.set_auto_title(session_id, f"{title} [{uuid4().hex}]", source="derived")
        except Exception:
            # Never leave a visible empty/partially delivered chat on failure.
            db.delete_session(session_id)
            raise
    return {
        "success": True,
        "platform": "hermes_app",
        "chat_id": "inbox",
        "session_id": session_id,
        "message_id": str(row_id),
    }


async def _deliver(home, chat_id, message, *, thread_id=None, media_files=None):
    if chat_id != "inbox" or thread_id:
        return {"error": "Use hermes_app:inbox; existing chats and threads are not delivery targets."}
    if media_files:
        return {"error": UNSUPPORTED_MEDIA}
    if not isinstance(message, str) or not message.strip():
        return {"error": "A non-empty text message is required."}
    try:
        return await asyncio.to_thread(_persist, home, message)
    except Exception:
        log.exception("Hermes App delivery could not be saved")
        return {"error": "Could not save the Hermes App message; check the Hermes logs."}


async def standalone_send(
    pconfig, chat_id, message, *, thread_id=None, media_files=None, force_document=False,
):
    if not configured(pconfig):
        return {"error": "Hermes App messaging is disabled in this profile."}
    # Capture the profile before handing work to another thread. The canonical
    # resolver honours context-local homes in multiplexed gateways.
    home = get_hermes_home()
    return await _deliver(home, chat_id, message, thread_id=thread_id, media_files=media_files)


class HermesAppAdapter(BasePlatformAdapter):
    splits_long_messages = True

    def __init__(self, config):
        super().__init__(config=config, platform=Platform("hermes_app"))
        self._home = get_hermes_home()

    async def connect(self, *, is_reconnect=False):
        if not configured(self.config):
            return False
        self._mark_connected()
        return True

    async def disconnect(self):
        self._running = False
        self._mark_disconnected()

    async def send(self, chat_id, content, reply_to=None, metadata=None):
        if not configured(self.config):
            return SendResult(success=False, error="Hermes App messaging is disabled in this profile.")
        result = await _deliver(
            self._home, chat_id, content,
            thread_id=(metadata or {}).get("thread_id"),
        )
        return SendResult(
            success=result.get("success", False),
            message_id=result.get("message_id"),
            error=result.get("error"),
        )

    async def list_channels(self):
        return [{"id": "inbox", "name": "Hermes App inbox", "type": "dm"}]

    async def get_chat_info(self, chat_id):
        if chat_id != "inbox":
            raise ValueError("Unknown Hermes App inbox")
        return {"chat_id": "inbox", "name": "Hermes App inbox", "type": "dm"}

    async def send_image(self, *args, **kwargs):
        return SendResult(success=False, error=UNSUPPORTED_MEDIA)

    send_image_file = send_image
    send_document = send_image
    send_voice = send_image
    send_video = send_image
    send_animation = send_image
