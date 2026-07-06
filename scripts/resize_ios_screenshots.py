"""Resize real app screenshots to iPhone 6.5-inch App Store size (1284 x 2778)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

TARGET_W, TARGET_H = 1284, 2778
ASSETS_DIR = Path(
    r"C:\Users\Bi\.cursor\projects\c-Users-Bi-Projects-hilla-ride\assets"
)
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "app-store-assets" / "ios-screenshots"

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


def resize_cover(image: Image.Image, width: int, height: int) -> Image.Image:
    """Scale proportionally to fill the frame, then center-crop (no stretching)."""
    source = image.convert("RGB")
    scale = max(width / source.width, height / source.height)
    resized = source.resize(
        (round(source.width * scale), round(source.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for source_path, output_name in SOURCE_FILES:
        if not source_path.exists():
            raise FileNotFoundError(f"Missing source screenshot: {source_path}")

        with Image.open(source_path) as image:
            print(f"Source {output_name}: {image.size[0]}x{image.size[1]}")
            result = resize_cover(image, TARGET_W, TARGET_H)
            destination = OUTPUT_DIR / output_name
            result.save(destination, format="PNG", optimize=True)
            print(f"Saved {destination.name}: {result.size[0]}x{result.size[1]}")


if __name__ == "__main__":
    main()
