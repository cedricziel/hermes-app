import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

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


if __name__ == "__main__":
    unittest.main()
