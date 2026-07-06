"""Resize app screenshots to iPad 13-inch App Store size (2732 x 2048 landscape)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

TARGET_W, TARGET_H = 2732, 2048
ASSETS_DIR = Path(
    r"C:\Users\Bi\.cursor\projects\c-Users-Bi-Projects-hilla-ride\assets"
)
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "app-store-assets" / "ipad-screenshots"

SOURCE_FILES = [
    (
        ASSETS_DIR
        / "c__Users_Bi_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_02-customer-map-d6bf44d7-6b0b-44ae-8450-6f2bfaa3456f.png",
        "01-customer-map.png",
    ),
    (
        ASSETS_DIR
        / "c__Users_Bi_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_03-book-ride-4da8cd36-75fd-4265-a3f4-97b4b0464eae.png",
        "02-book-ride.png",
    ),
    (
        ASSETS_DIR
        / "c__Users_Bi_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_05-driver-assigned-8e8be90f-c049-4d8a-9646-0fd97927b485.png",
        "03-driver-assigned.png",
    ),
    (
        ASSETS_DIR
        / "c__Users_Bi_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_06-driver-dashboard-d9c7553e-7506-4efa-b720-fe597a044f30.png",
        "04-driver-dashboard.png",
    ),
]


def background_color(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    samples = [
        rgb.getpixel((0, 0)),
        rgb.getpixel((rgb.width - 1, 0)),
        rgb.getpixel((0, rgb.height - 1)),
        rgb.getpixel((rgb.width - 1, rgb.height - 1)),
    ]
    r = sum(color[0] for color in samples) // len(samples)
    g = sum(color[1] for color in samples) // len(samples)
    b = sum(color[2] for color in samples) // len(samples)
    return (r, g, b)


def resize_for_ipad(image: Image.Image, width: int, height: int) -> Image.Image:
    """Fit portrait phone UI into landscape iPad frame (centered, no stretch)."""
    source = image.convert("RGB")
    scale = height / source.height
    resized_w = round(source.width * scale)
    resized_h = height
    resized = source.resize((resized_w, resized_h), Image.Resampling.LANCZOS)

    canvas = Image.new("RGB", (width, height), background_color(source))
    left = (width - resized_w) // 2
    canvas.paste(resized, (left, 0))
    return canvas


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for source_path, output_name in SOURCE_FILES:
        if not source_path.exists():
            raise FileNotFoundError(f"Missing source screenshot: {source_path}")

        with Image.open(source_path) as image:
            print(f"Source {output_name}: {image.size[0]}x{image.size[1]}")
            result = resize_for_ipad(image, TARGET_W, TARGET_H)
            destination = OUTPUT_DIR / output_name
            result.save(destination, format="PNG", optimize=True)
            print(f"Saved {destination.name}: {result.size[0]}x{result.size[1]}")


if __name__ == "__main__":
    main()
