"""Turns the raw captures from scripts/store-screenshots.sh into store and README images.

    python3 scripts/finish_screenshots.py [--readme-only]

Reads build/screenshots/<device>-<light|dark>/<screen>.png and writes

- fastlane/screenshots/<ios|mac>/en-US/  the App Store sizes, flattened (the
  store rejects transparency), in listing order. Not committed.
- docs/screenshots/                       smaller copies for the README.

--readme-only writes docs/screenshots/ and nothing else, for captures that must
not reach the App Store (the README images rendered in a test). Devices with no
raw capture keep their current README image.

Two things are erased from the raw captures, never added: the address of the
throwaway dev backend that the account row shows when nobody is signed in
(where the test reports it), and the window handle iPadOS draws in a corner.
"""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "build" / "screenshots"
STORE = ROOT / "fastlane" / "screenshots"
DOCS = ROOT / "docs" / "screenshots"

# (appearance, screen), in the order they appear on the listing.
LISTING = {
    "iphone": [("light", "chat"), ("light", "threads"), ("light", "welcome"), ("dark", "chat")],
    "ipad": [("light", "chat"), ("light", "welcome"), ("dark", "chat")],
    "watch": [("light", "threads")],
    "mac": [("light", "chat"), ("light", "welcome"), ("dark", "chat")],
}
PLATFORM = {"iphone": "ios", "ipad": "ios", "watch": "ios", "mac": "mac"}
README_WIDTH = {"iphone": 540, "ipad": 1000, "watch": 422, "mac": 1600}
MAC_CANVAS = (2880, 1800)
MAC_MAX_WINDOW = (2720, 1700)

# Areas to flatten, per device and screen (None means every screen), each with
# a pixel that has the colour of the empty space around it: the window handle
# iPadOS draws in a corner. Where the app shows the dev address, the test says
# itself, in <screen>.erase next to the capture.
ERASE = {
    "ipad": {None: [((1985, 2668, 2064, 2752), (1977, 2710))]},
}


def erase(image: Image.Image, box: tuple[int, int, int, int], sample: tuple[int, int]) -> None:
    ImageDraw.Draw(image).rectangle(box, fill=image.getpixel(sample))


def reported(source: Path) -> list[tuple[tuple[int, int, int, int], tuple[int, int]]]:
    """The areas the test reported, each sampled just above its top left."""
    sidecar = source.with_suffix(".erase")
    if not sidecar.exists():
        return []
    areas = []
    for part in filter(None, sidecar.read_text().strip().split(";")):
        left, top, right, bottom = (int(value) for value in part.split(","))
        areas.append(((left, top, right, bottom), (left, max(0, top - 2))))
    return areas


def tidy(device: str, screen: str, source: Path) -> Image.Image:
    image = Image.open(source)
    areas = [area for key in (None, screen) for area in ERASE.get(device, {}).get(key, [])]
    for box, sample in areas + reported(source):
        erase(image, box, sample)
    return image


def mac_canvas(window: Image.Image, appearance: str) -> Image.Image:
    window = window.convert("RGBA")
    scale = min(1, MAC_MAX_WINDOW[0] / window.width, MAC_MAX_WINDOW[1] / window.height)
    if scale < 1:
        window = window.resize((round(window.width * scale), round(window.height * scale)), Image.LANCZOS)

    top, bottom = ((226, 231, 244), (196, 205, 226)) if appearance == "light" else ((52, 58, 76), (24, 27, 38))
    canvas = Image.new("RGB", MAC_CANVAS)
    draw = ImageDraw.Draw(canvas)
    for y in range(MAC_CANVAS[1]):
        t = y / (MAC_CANVAS[1] - 1)
        draw.line([(0, y), (MAC_CANVAS[0], y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

    x = (MAC_CANVAS[0] - window.width) // 2
    y = (MAC_CANVAS[1] - window.height) // 2
    shadow = Image.new("RGBA", MAC_CANVAS, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 110), (x, y + 30, x + window.width, y + window.height + 30), window.getchannel("A"))
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow)
    canvas.alpha_composite(window, (x, y))
    return canvas.convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description="Turns raw screenshot captures into store and README images.")
    parser.add_argument("--readme-only", action="store_true", help="write docs/screenshots/ only")
    readme_only = parser.parse_args().readme_only

    made = 0
    for device, screens in LISTING.items():
        store_dir = STORE / PLATFORM[device] / "en-US"
        cleared = False
        for index, (appearance, screen) in enumerate(screens, start=1):
            # The Mac is captured wide, or compact with `mac compact`.
            variant = device
            source = RAW / f"{device}-{appearance}" / f"{screen}.png"
            if device == "mac" and not source.exists():
                variant = "mac-compact"
                source = RAW / f"{variant}-{appearance}" / f"{screen}.png"
            if not source.exists():
                continue
            if not cleared:
                # A screen dropped from the listing must not linger and get uploaded.
                for folder in (DOCS,) if readme_only else (store_dir, DOCS):
                    for old in folder.glob(f"{device}-*.png"):
                        old.unlink()
                cleared = True
            image = tidy(variant, screen, source)
            image = mac_canvas(image, appearance) if device == "mac" else image.convert("RGB")

            suffix = "" if appearance == "light" else "-dark"
            if not readme_only:
                store_dir.mkdir(parents=True, exist_ok=True)
                image.save(store_dir / f"{device}-{index:02d}-{screen}{suffix}.png", optimize=True)

            DOCS.mkdir(parents=True, exist_ok=True)
            width = README_WIDTH[device]
            small = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
            small.save(DOCS / f"{device}-{screen}{suffix}.png", optimize=True)
            made += 1
    targets = DOCS.relative_to(ROOT) if readme_only else f"{STORE.relative_to(ROOT)} and {DOCS.relative_to(ROOT)}"
    print(f"finished {made} screenshots -> {targets}")


if __name__ == "__main__":
    main()
