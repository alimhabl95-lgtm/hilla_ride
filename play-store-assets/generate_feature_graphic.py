"""Generate Google Play feature graphic (1024 x 500 PNG) in Arabic."""

from pathlib import Path

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "feature-graphic.png"
ICON = ROOT / "app-icon-512.png"
W, H = 1024, 500

TEAL = (15, 118, 110)
TEAL_DARK = (8, 78, 72)
GOLD = (255, 196, 0)
WHITE = (255, 255, 255)
CREAM = (244, 251, 250)


def ar(text: str) -> str:
    return get_display(arabic_reshaper.reshape(text))


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        r"C:\Windows\Fonts\tahomabd.ttf" if bold else r"C:\Windows\Fonts\tahoma.ttf",
        r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw_rtl(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    *,
    fill,
    size: int,
    bold: bool = False,
) -> None:
    shaped = ar(text)
    draw.text(xy, shaped, fill=fill, font=font(size, bold=bold), anchor="ra")


def main() -> None:
    img = Image.new("RGB", (W, H), TEAL)
    draw = ImageDraw.Draw(img)

    for y in range(H):
        t = y / H
        r = int(TEAL[0] * (1 - t) + TEAL_DARK[0] * t)
        g = int(TEAL[1] * (1 - t) + TEAL_DARK[1] * t)
        b = int(TEAL[2] * (1 - t) + TEAL_DARK[2] * t)
        draw.line((0, y, W, y), fill=(r, g, b))

    draw.ellipse((720, -80, 1120, 320), fill=GOLD)
    draw.ellipse((-120, 280, 280, 680), fill=(255, 220, 80))

    icon = Image.open(ICON).convert("RGBA")
    icon_size = 280
    icon = icon.resize((icon_size, icon_size), Image.Resampling.LANCZOS)
    img.paste(icon, (72, (H - icon_size) // 2), icon)

    draw.rounded_rectangle((390, 108, 960, 392), radius=28, fill=CREAM)
    draw.text((930, 158), "Hello Tuk-Tuk", fill=TEAL_DARK, font=font(58, bold=True), anchor="ra")
    draw_rtl(draw, (930, 228), "احجز رحلات التكتك في الهاشمية", fill=TEAL, size=30, bold=True)
    draw_rtl(draw, (930, 278), "نقداً • تتبّع مباشر • عربي / English", fill=(60, 60, 60), size=24)
    draw.rounded_rectangle((690, 318, 930, 368), radius=14, fill=GOLD)
    draw_rtl(draw, (910, 343), "محافظة بابل، العراق", fill=TEAL_DARK, size=22, bold=True)

    img.save(OUT, "PNG", optimize=True)
    print(f"Saved {OUT} ({W}x{H})")


if __name__ == "__main__":
    main()
