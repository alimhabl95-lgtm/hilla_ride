"""Capture iPhone 6.5-inch App Store screenshots from the hosted web app."""

from __future__ import annotations

import asyncio
from pathlib import Path

from PIL import Image
from playwright.async_api import TimeoutError as PlaywrightTimeoutError
from playwright.async_api import async_playwright

APP_URL = "https://hello-tiktok-57dc5.web.app"
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "app-store-assets" / "ios-screenshots"
TARGET_SIZE = (1284, 2778)  # iPhone 6.5-inch (also accepted: 1242 x 2688)
VIEWPORT = {"width": 428, "height": 926}
DEVICE_SCALE = 3
FLUTTER_LOAD_MS = 8000


def fit_to_target(source: Path, destination: Path) -> None:
    with Image.open(source) as image:
        rgb = image.convert("RGB")
        fitted = rgb.resize(TARGET_SIZE, Image.Resampling.LANCZOS)
        destination.parent.mkdir(parents=True, exist_ok=True)
        fitted.save(destination, format="PNG", optimize=True)


async def wait_for_flutter(page) -> None:
    await page.wait_for_timeout(FLUTTER_LOAD_MS)
    try:
        await page.wait_for_selector("flutter-view", timeout=15000)
    except PlaywrightTimeoutError:
        pass


async def click_center(page, x_ratio: float, y_ratio: float) -> None:
    width = VIEWPORT["width"]
    height = VIEWPORT["height"]
    await page.mouse.click(width * x_ratio, height * y_ratio)


async def capture(page, raw_path: Path) -> None:
    await wait_for_flutter(page)
    await page.screenshot(path=str(raw_path), full_page=False, type="png")


async def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    raw_dir = OUTPUT_DIR / "_raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    async with async_playwright() as playwright:
        browser = await playwright.chromium.launch(headless=True)
        context = await browser.new_context(
            viewport=VIEWPORT,
            device_scale_factor=DEVICE_SCALE,
            is_mobile=True,
            has_touch=True,
            locale="ar-IQ",
        )
        page = await context.new_page()

        shots: list[tuple[str, Path]] = []

        # 1) Welcome / mode chooser
        await page.goto(APP_URL, wait_until="networkidle")
        raw_welcome = raw_dir / "01-welcome.png"
        await capture(page, raw_welcome)
        shots.append(("01-welcome-mode-chooser.png", raw_welcome))

        # 2) Customer login / signup entry
        await click_center(page, 0.5, 0.47)
        await page.wait_for_timeout(3000)
        raw_customer = raw_dir / "02-customer.png"
        await capture(page, raw_customer)
        shots.append(("02-customer-login.png", raw_customer))

        # 3) Back and open driver flow
        await page.goto(APP_URL, wait_until="networkidle")
        await capture(page, raw_dir / "reload.png")
        await click_center(page, 0.5, 0.62)
        await page.wait_for_timeout(3000)
        raw_driver = raw_dir / "03-driver.png"
        await capture(page, raw_driver)
        shots.append(("03-driver-signup.png", raw_driver))

        await browser.close()

    for filename, raw_path in shots:
        destination = OUTPUT_DIR / filename
        fit_to_target(raw_path, destination)
        with Image.open(destination) as image:
            print(f"Saved {destination.name}: {image.size[0]}x{image.size[1]}")

    print(f"\nDone. Upload files from:\n{OUTPUT_DIR}")


if __name__ == "__main__":
    asyncio.run(main())
