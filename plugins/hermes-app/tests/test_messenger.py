"""Integration tests: real Hermes discovery, routing and SQLite persistence.

Run in a Hermes Python environment; nothing is sent to an external service.
"""

import asyncio
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

PLUGIN = Path(__file__).resolve().parents[1]


class MessengerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        home_patch = patch.object(Path, "home", return_value=Path(self.temp.name))
        home_patch.start()
        self.addCleanup(home_patch.stop)
        self.home = Path(self.temp.name) / "hermes"
        self.home.mkdir()
        self.env = patch.dict(os.environ, {
            "HERMES_HOME": str(self.home),
            "HERMES_BUNDLED_PLUGINS": str(self.home / "no-bundled-plugins"),
            "HERMES_ENABLE_PROJECT_PLUGINS": "0",
        })
        self.env.start()
        self.addCleanup(self.env.stop)
        from hermes_constants import set_hermes_home_override, reset_hermes_home_override
        token = set_hermes_home_override(self.home)
        self.addCleanup(reset_hermes_home_override, token)
        self.install(self.home)

        from hermes_cli.plugins import discover_plugins
        from gateway.config import Platform, load_gateway_config
        from gateway.platform_registry import platform_registry
        discover_plugins()
        self.entry = platform_registry.get("hermes_app")
        self.assertIsNotNone(self.entry, "Plugin discovery must register the platform")
        self.platform = Platform("hermes_app")
        self.config = load_gateway_config().platforms[self.platform]

    def install(self, home, enabled=True):
        home.mkdir(parents=True, exist_ok=True)
        shutil.copytree(PLUGIN, home / "plugins" / "hermes-app", ignore=shutil.ignore_patterns("__pycache__"))
        # JSON is valid YAML, and avoids depending on a second YAML serializer.
        (home / "config.yaml").write_text(json.dumps({
            "plugins": {"enabled": ["hermes-app"]},
            "platforms": {"hermes_app": {
                "enabled": enabled,
                "gateway_restart_notification": False,
                "home_channel": {
                    "platform": "hermes_app", "chat_id": "inbox", "name": "Hermes App inbox",
                },
            }},
        }), encoding="utf-8")

    def sessions(self, home=None):
        from hermes_state import SessionDB
        with SessionDB(db_path=(home or self.home) / "state.db") as db:
            return db.list_sessions_rich(limit=100)

    def assert_delivery(self, result, text, home=None):
        from hermes_state import SessionDB
        self.assertTrue(result.get("success"), result)
        with SessionDB(db_path=(home or self.home) / "state.db") as db:
            session = db.get_session(result["session_id"])
            self.assertEqual(session["source"], "hermes_app")
            self.assertTrue(session["title"].startswith("Message: "))
            messages = db.get_messages(result["session_id"])
            self.assertEqual([(m["role"], m["content"]) for m in messages], [("assistant", text)])
            self.assertTrue(db.session_unread(session))

    def send(self, text="Hello", target="hermes_app:inbox"):
        from tools.send_message_tool import send_message_tool
        return json.loads(send_message_tool({"action": "send", "target": target, "message": text}))

    def test_send_engine_creates_replyable_saved_chat_without_gateway(self):
        text = "## Your update\n\nCafé ☕ — $HOME, `literal`, $(literal)."
        result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", text))
        self.assert_delivery(result, text)
        # No model invocation: just a user reply, as the app will later persist.
        from hermes_state import SessionDB
        with SessionDB(db_path=self.home / "state.db") as db:
            db.append_message(result["session_id"], role="user", content="Tell me more")
            self.assertEqual(db.get_messages(result["session_id"])[-1]["content"], "Tell me more")

    def test_message_is_the_last_write_so_a_visible_delivery_is_complete(self):
        from hermes_state import SessionDB
        calls = []
        for name in ("create_session", "set_session_read", "set_auto_title", "append_message"):
            original = getattr(SessionDB, name)

            def wrapper(db, *args, _name=name, _original=original, **kwargs):
                calls.append(_name)
                return _original(db, *args, **kwargs)

            patcher = patch.object(SessionDB, name, wrapper)
            patcher.start()
            self.addCleanup(patcher.stop)
        result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "Hi"))
        self.assertTrue(result.get("success"), result)
        self.assertEqual(
            calls, ["create_session", "set_session_read", "set_auto_title", "append_message"])

    def test_delivery_uses_the_shared_session_db_and_releases_it(self):
        import hermes_state_registry as registry
        with patch.object(registry, "acquire", wraps=registry.acquire) as acquire:
            result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "Hi"))
        self.assertTrue(result.get("success"), result)
        acquire.assert_called_once()
        self.assertEqual(registry.stats()["total_refcounts"], 0)

    def test_repeated_titles_get_short_numbers_then_a_random_suffix(self):
        titles = []
        for _ in range(22):
            result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "Daily report"))
            self.assertTrue(result.get("success"), result)
            from hermes_state import SessionDB
            with SessionDB(db_path=self.home / "state.db") as db:
                titles.append(db.get_session(result["session_id"])["title"])
        self.assertEqual(titles[0], "Message: Daily report")
        self.assertEqual(titles[1:3], ["Message: Daily report (2)", "Message: Daily report (3)"])
        self.assertEqual(titles[19], "Message: Daily report (20)")
        for title in titles[20:]:
            self.assertRegex(title, r"^Message: Daily report \[[0-9a-f]{8}\]$")
        self.assertEqual(len(set(titles)), 22)

    def test_cli_send_engine_routes_explicit_and_home_targets(self):
        for target in ("hermes_app:inbox", "hermes_app"):
            result = self.send("A routed message", target)
            self.assertTrue(result.get("success"), result)
        self.assertEqual(len(self.sessions()), 2)

    def test_long_message_preserved_and_deliveries_do_not_edit_other_chats(self):
        text = "Very long Markdown\n" * 2000
        first = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", text))
        second = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "Second"))
        self.assertNotEqual(first["session_id"], second["session_id"])
        self.assert_delivery(first, text)
        self.assert_delivery(second, "Second")

    def test_invalid_target_thread_empty_and_media_save_nothing(self):
        for target, text, kwargs in (
            ("another-profile", "text", {}),
            ("inbox", "text", {"thread_id": "some-session"}),
            ("inbox", "  \n", {}),
            ("inbox", "  \n", {"media_files": [("/tmp/report.pdf", False)]}),
        ):
            result = asyncio.run(self.entry.standalone_sender_fn(self.config, target, text, **kwargs))
            self.assertIn("error", result)
        self.assertFalse((self.home / "state.db").exists())

    def test_media_tags_deliver_the_text_and_say_what_was_left_out(self):
        files = []
        for name in ("report.pdf", "chart.png"):
            path = Path(self.temp.name) / name
            path.write_bytes(b"data")
            files.append(path)
        one = self.send(f"Here is the report.\nMEDIA:{files[0]}")
        self.assertTrue(one.get("success"), one)
        two = self.send(f"Both files.\nMEDIA:{files[0]}\nMEDIA:{files[1]}")
        self.assertTrue(two.get("success"), two)
        self.assert_delivery(
            {"success": True, "session_id": one["session_id"]},
            "Here is the report.\n\n(1 attachment was not delivered: Hermes App messages are text only.)",
        )
        self.assert_delivery(
            {"success": True, "session_id": two["session_id"]},
            "Both files.\n\n(2 attachments were not delivered: Hermes App messages are text only.)",
        )

    def test_messages_over_the_size_cap_are_rejected_with_a_clear_error(self):
        result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "x" * 100_001))
        self.assertIn("100,000", result["error"])
        self.assertFalse((self.home / "state.db").exists())
        at_cap = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "x" * 100_000))
        self.assertTrue(at_cap.get("success"), at_cap)

    def test_title_drops_leading_markdown_markers(self):
        for text, expected in (
            ("## Daily report\nbody", "Message: Daily report"),
            ("> - * quoted item", "Message: quoted item"),
            ("# \n\nSecond line", "Message: Second line"),
        ):
            result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", text))
            from hermes_state import SessionDB
            with SessionDB(db_path=self.home / "state.db") as db:
                self.assertEqual(db.get_session(result["session_id"])["title"], expected)

    def test_unknown_target_rejected_by_shared_send_engine(self):
        self.assertIn("error", self.send(target="hermes_app:some-session"))
        self.assertEqual(self.sessions(), [])

    def test_adapter_discovers_inbox_and_saves_in_its_own_profile(self):
        adapter = self.entry.adapter_factory(self.config)
        from hermes_constants import set_hermes_home_override, reset_hermes_home_override
        other = Path(self.temp.name) / "other"
        token = set_hermes_home_override(other)
        try:
            async def run():
                self.assertTrue(await adapter.connect())
                channels = await adapter.list_channels()
                self.assertEqual(channels[0]["id"], "inbox")
                result = await adapter.send("inbox", "Adapter delivery")
                self.assertTrue(result.success, result.error)
                self.assertFalse((await adapter.send_image("inbox", "/tmp/pic.png")).success)
                await adapter.disconnect()
            asyncio.run(run())
        finally:
            reset_hermes_home_override(token)
        self.assertEqual(len(self.sessions()), 1)
        self.assertFalse((other / "state.db").exists())

    def test_standalone_sender_uses_current_context_local_profile(self):
        from hermes_constants import set_hermes_home_override, reset_hermes_home_override
        other = Path(self.temp.name) / "other"
        other.mkdir()
        token = set_hermes_home_override(other)
        try:
            result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "Scoped"))
        finally:
            reset_hermes_home_override(token)
        self.assert_delivery(result, "Scoped", home=other)
        self.assertFalse((self.home / "state.db").exists())

    def test_disabled_sender_refuses_delivery(self):
        self.config.enabled = False
        result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "no"))
        self.assertIn("error", result)
        self.assertFalse((self.home / "state.db").exists())

    def hint(self, session_info):
        from hermes_cli.plugins import get_plugin_manager
        sections = get_plugin_manager().render_system_prompt_sections(session_info)
        return "\n".join(section.content for section in sections)

    def test_hint_is_limited_to_the_owners_direct_surfaces(self):
        for platform in ("hermes_app", "cli", "tui", "desktop"):
            self.assertIn("hermes-app:messaging", self.hint({"platform": platform}), platform)
        for platform in ("cron", "telegram", "discord", "slack", "email", "api_server", ""):
            self.assertEqual(self.hint({"platform": platform}), "", platform)

    def test_hint_follows_the_gateways_own_config_loading(self):
        config = self.home / "config.yaml"
        data = json.loads(config.read_text(encoding="utf-8"))
        data["platforms"]["hermes_app"]["enabled"] = False
        config.write_text(json.dumps(data), encoding="utf-8")
        self.assertEqual(self.hint({"platform": "cli"}), "")
        # The gateway also reads platform blocks nested under `gateway:`.
        del data["platforms"]
        data["gateway"] = {"platforms": {"hermes_app": {"enabled": True}}}
        config.write_text(json.dumps(data), encoding="utf-8")
        self.assertIn("hermes-app:messaging", self.hint({"platform": "cli"}))

    def test_plugin_makes_destination_and_skill_known_to_new_sessions(self):
        from hermes_cli.plugins import get_plugin_manager
        manager = get_plugin_manager()
        self.assertIsNotNone(manager.find_plugin_skill("hermes-app:messaging"))
        text = self.hint({"platform": "cli"})
        self.assertIn("hermes send --to hermes_app:inbox", text)
        self.assertIn("hermes-app:messaging", text)

    def test_persistence_failure_reports_error_and_removes_partial_chat(self):
        from hermes_state import SessionDB
        with patch.object(SessionDB, "append_message", side_effect=OSError("disk error")):
            result = asyncio.run(self.entry.standalone_sender_fn(self.config, "inbox", "Not saved"))
        self.assertIn("error", result)
        self.assertIn("OSError", result["error"])
        self.assertNotIn("disk error", result["error"])
        self.assertEqual(self.sessions(), [])

    def test_cron_recognizes_inbox_and_resolves_home_from_yaml(self):
        try:
            from cron.scheduler_delivery import _resolve_delivery_targets, cron_delivery_targets
            from cron.scheduler_preflight import _preflight_check_delivery
        except ImportError:
            # Older Hermes releases keep these functions in the scheduler.
            from cron.scheduler import _preflight_check_delivery, _resolve_delivery_targets, cron_delivery_targets
        for target in ("hermes_app", "hermes_app:inbox"):
            job = {"id": "test", "deliver": target}
            self.assertIsNone(_preflight_check_delivery(job))
            resolved = _resolve_delivery_targets(job)
            self.assertEqual(len(resolved), 1)
            self.assertEqual({key: resolved[0][key] for key in ("platform", "chat_id", "thread_id")}, {
                "platform": "hermes_app", "chat_id": "inbox", "thread_id": None,
            })
        self.assertTrue(any(row["id"] == "hermes_app" for row in cron_delivery_targets()))


if __name__ == "__main__":
    unittest.main()
