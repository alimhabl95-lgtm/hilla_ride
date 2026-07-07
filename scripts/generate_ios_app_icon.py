"""Generate the iOS App Store icon (1024x1024, no alpha) from the brand logo.

Source: play-store-assets/app-icon-original.png (the Hello Tuk-Tuk logo used on
Android/Play Store). App Store icons must be a fully opaque 1024x1024 square with
no transparency and no pre-applied rounded corners, so we flatten the logo onto a
solid white square canvas.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "play-store-assets" / "app-icon-original.png"
DEST = (
    ROOT
    / "hilla_ride_ios"
    / "HelloTukTuk"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
    / "AppIcon-1024.png"
)

CANVAS = 1024
BACKGROUND = (255, 255, 255)


def main() -> None:
    logo = Image.open(SOURCE).convert("RGBA")

    # Scale the logo to fit within the square canvas, preserving aspect ratio.
    scale = min(CANVAS / logo.width, CANVAS / logo.height)
    new_size = (round(logo.width * scale), round(logo.height * scale))
    logo = logo.resize(new_size, Image.LANCZOS)

    canvas = Image.new("RGB", (CANVAS, CANVAS), BACKGROUND)
    offset = ((CANVAS - logo.width) // 2, (CANVAS - logo.height) // 2)
    canvas.paste(logo, offset, mask=logo)

    DEST.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(DEST, format="PNG")
    print(f"Wrote {DEST} ({canvas.size[0]}x{canvas.size[1]}, mode={canvas.mode})")


if __name__ == "__main__":
    main()
