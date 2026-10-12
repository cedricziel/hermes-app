import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.request import Request

from PIL import Image

from finish_screenshots import tidy
from seed_demo_sessions import seed_kanban


class StoreScreenshots(unittest.TestCase):
    def test_task_sheet_keeps_button_shadow_when_window_handle_is_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "kanban-task.png"
            image = Image.new("RGB", (2064, 2752), (117, 117, 117))
            image.putpixel((2004, 2690), (90, 90, 90))
            image.putpixel((2050, 2730), (140, 140, 140))
            image.save(source)

            finished = tidy("ipad", "kanban-task", source)

            self.assertEqual(finished.getpixel((2004, 2690)), (90, 90, 90))
            self.assertEqual(finished.getpixel((2050, 2730)), (117, 117, 117))

    def test_kanban_seeding_refuses_an_unexpected_backend_home(self):
        status = io.BytesIO(json.dumps({"hermes_home": "/unexpected/home"}).encode())
        with patch("seed_demo_sessions.urlopen", return_value=status):
            with self.assertRaisesRegex(SystemExit, "Refusing to seed Kanban"):
                seed_kanban("/throwaway/home", "http://127.0.0.1:9119")

    def test_existing_demo_task_copy_changes_without_repeating_done_transition(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "kanban.json"
            task = {
                "title": "Verify the backup",
                "body": "Check the updated schedule.",
                "priority": 2,
                "status": "done",
            }
            fixture.write_text(json.dumps({"tasks": [task]}))
            responses = [
                io.BytesIO(json.dumps({"hermes_home": directory}).encode()),
                io.BytesIO(b'__HERMES_SESSION_TOKEN__="demo-token"'),
                io.BytesIO(json.dumps({"task": {
                    "id": "demo-task", "status": "done", "title": "Old title",
                    "body": "Old description", "priority": 1,
                }}).encode()),
                io.BytesIO(b'{}'),
            ]
            with patch("seed_demo_sessions.DEMO_KANBAN", fixture), patch(
                "seed_demo_sessions.urlopen", side_effect=responses
            ) as opened:
                seed_kanban(directory, "http://127.0.0.1:9119")

            patches = [
                json.loads(call.args[0].data)
                for call in opened.call_args_list
                if isinstance(call.args[0], Request) and call.args[0].get_method() == "PATCH"
            ]
            self.assertEqual(patches, [{
                "title": task["title"], "body": task["body"], "priority": task["priority"],
            }])


if __name__ == "__main__":
    unittest.main()
