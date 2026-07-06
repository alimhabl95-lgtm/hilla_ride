"""Recapture the driver flow screenshot for App Store."""

from __future__ import annotations

import asyncio
from pathlib import Path

from PIL import Image
from playwright.async_api import async_playwright

APP_URL = "https://hello-tiktok-57dc5.web.app"
OUTPUT_DIR = Path(__file__).resolve().parents[1] / "app-store-assets" / "ios-screenshots"
TARGET_SIZE = (1284, 2778)
VIEWPORT = {"width": 428, "height": 926}
DEVICE_SCALE = 3


def fit_to_target(source: Path, destination: Path) -> None:
    with Image.open(source) as image:
        fitted = image.convert("RGB").resize(TARGET_SIZE, Image.Resampling.LANCZOS)
        fitted.save(destination, format="PNG", optimize=True)


async def main() -> None:
    raw_path = OUTPUT_DIR / "_raw" / "03-driver-retake.png"
    raw_path.parent.mkdir(parents=True, exist_ok=True)

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
        await page.goto(APP_URL, wait_until="networkidle")
        await page.wait_for_timeout(8000)

        # Driver card on welcome screen.
        await page.mouse.click(214, 560)
        await page.wait_for_timeout(4000)

        # Open create-account if we landed on login.
        await page.mouse.click(214, 760)
        await page.wait_for_timeout(4000)

        await page.screenshot(path=str(raw_path), type="png")
        await browser.close()

    destination = OUTPUT_DIR / "03-driver-signup.png"
    fit_to_target(raw_path, destination)
    print(f"Saved {destination}: {TARGET_SIZE[0]}x{TARGET_SIZE[1]}")


if __name__ == "__main__":
    asyncio.run(main())
