"""Regenerate platform icons with `py tool/generate_app_icons.py` (Pillow required)."""

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/app_icon.png"


def save_png(image, path, size):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.Resampling.LANCZOS).save(path)


def main():
    with Image.open(SOURCE) as source:
        image = source.convert("RGB")
    if image.width != image.height:
        raise ValueError("The source icon must be square.")

    for density, size in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        save_png(image, ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)

    for platform in ("ios", "macos"):
        catalog = ROOT / platform / "Runner/Assets.xcassets/AppIcon.appiconset"
        entries = json.loads((catalog / "Contents.json").read_text())["images"]
        for entry in entries:
            size = round(float(entry["size"].split("x")[0]) * float(entry["scale"][:-1]))
            save_png(image, catalog / entry["filename"], size)

    for size in (192, 512):
        save_png(image, ROOT / f"web/icons/Icon-{size}.png", size)
        save_png(image, ROOT / f"web/icons/Icon-maskable-{size}.png", size)
    save_png(image, ROOT / "web/favicon.png", 32)
    save_png(image, ROOT / "linux/runner/resources/app_icon.png", 512)

    # Supersample the rounded mask so small Windows icons have smooth edges.
    rounded = image.resize((1024, 1024), Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", rounded.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 1023, 1023), radius=205, fill=255)
    rounded.putalpha(mask)
    sizes = [(size, size) for size in (16, 20, 24, 32, 40, 48, 64, 128, 256)]
    frames = []
    for size in sizes:
        frame = rounded.resize(size, Image.Resampling.LANCZOS)
        # Remove near-transparent resampling artifacts outside the rounded edge.
        frame.putalpha(frame.getchannel("A").point(lambda alpha: 0 if alpha < 3 else alpha))
        frames.append(frame)
    rounded.save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=sizes,
        append_images=frames,
    )


if __name__ == "__main__":
    main()
