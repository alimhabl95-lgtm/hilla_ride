"""Generate 7-inch and 10-inch tablet screenshots for Google Play."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
PHONE_DIR = ROOT / "screenshots"

# 9:16 portrait — within Play Console size limits.
TABLET_7 = (1200, 2133)   # sides 320–3840 px
TABLET_10 = (1440, 2560)  # sides 1080–7680 px

PHONE_FILES = [
    "01-mode-chooser.png",
    "02-customer-map.png",
    "03-book-ride.png",
    "04-track-driver.png",
    "05-driver-assigned.png",
    "06-driver-dashboard.png",
]


def resize_screenshot(src: Path, dst: Path, size: tuple[int, int]) -> None:
    img = Image.open(src).convert("RGB")
    resized = img.resize(size, Image.Resampling.LANCZOS)
    resized.save(dst, "PNG", optimize=True)
    mb = dst.stat().st_size / (1024 * 1024)
    print(f"  {dst.name}: {size[0]}x{size[1]}, {mb:.2f} MB")


def generate_set(out_dir: Path, size: tuple[int, int], label: str) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    print(f"\n{label} ({size[0]}x{size[1]}):")
    for name in PHONE_FILES:
        src = PHONE_DIR / name
        if not src.exists():
            raise FileNotFoundError(f"Missing phone screenshot: {src}")
        resize_screenshot(src, out_dir / name, size)


def main() -> None:
    generate_set(ROOT / "tablet-7in", TABLET_7, "7-inch tablet")
    generate_set(ROOT / "tablet-10in", TABLET_10, "10-inch tablet")
    print("\nDone. Upload folders:")
    print("  tablet-7in/  -> Play Console -> 7-inch tablet screenshots")
    print("  tablet-10in/ -> Play Console -> 10-inch tablet screenshots")


if __name__ == "__main__":
    main()
