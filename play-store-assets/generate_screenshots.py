"""Generate Play Store phone screenshots (1080x1920) for Hello Tuk-Tuk."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "screenshots"
W, H = 1080, 1920

TEAL = (15, 118, 110)
TEAL_LIGHT = (244, 251, 250)
GOLD = (255, 196, 0)
WHITE = (255, 255, 255)
GREY = (120, 120, 120)
DARK = (30, 30, 30)
MAP_BG = (232, 240, 238)
GREEN = (22, 163, 74)
RED = (220, 38, 38)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        r"C:\Windows\Fonts\segoeuib.ttf" if bold else r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def draw_app_bar(draw: ImageDraw.ImageDraw, title: str) -> None:
    draw.rectangle((0, 0, W, 140), fill=TEAL)
    draw.text((W // 2, 78), title, fill=WHITE, font=font(42, bold=True), anchor="mm")


def rounded_card(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int, int, int],
    *,
    fill=WHITE,
    outline=None,
) -> None:
    draw.rounded_rectangle(xy, radius=24, fill=fill, outline=outline, width=2)


def screenshot_customer_map() -> None:
    img = Image.new("RGB", (W, H), TEAL_LIGHT)
    draw = ImageDraw.Draw(img)
    draw_app_bar(draw, "Hello Tuk-Tuk")

    # Map area
    draw.rectangle((0, 140, W, 1180), fill=MAP_BG)
    for x in range(0, W, 80):
        draw.line((x, 140, x, 1180), fill=(210, 220, 218), width=1)
    for y in range(140, 1180, 80):
        draw.line((0, y, W, y), fill=(210, 220, 218), width=1)

    # Markers
    draw.ellipse((420, 520, 470, 570), fill=GREEN, outline=WHITE, width=4)
    draw.ellipse((620, 760, 670, 810), fill=RED, outline=WHITE, width=4)

    panel_y = 980
    draw.rounded_rectangle((24, panel_y, W - 24, H - 40), radius=32, fill=WHITE)
    draw.text((W - 48, panel_y + 36), "قضاء الهاشمية • الشوملي", fill=TEAL, font=font(28), anchor="rm")
    draw.text((W - 48, panel_y + 92), "نقطة الانطلاق", fill=GREY, font=font(24), anchor="rm")
    draw.rounded_rectangle((48, panel_y + 118, W - 48, panel_y + 198), radius=16, fill=(248, 250, 252))
    draw.text((W - 72, panel_y + 158), "موقعي الحالي", fill=DARK, font=font(30, bold=True), anchor="rm")
    draw.text((W - 48, panel_y + 230), "إلى أين؟", fill=GREY, font=font(24), anchor="rm")
    draw.rounded_rectangle((48, panel_y + 256, W - 48, panel_y + 336), radius=16, fill=(248, 250, 252))
    draw.text((W - 72, panel_y + 296), "ابحث عن مكان في الحلة", fill=GREY, font=font(28), anchor="rm")
    draw.rounded_rectangle((48, panel_y + 380, W - 48, panel_y + 470), radius=20, fill=TEAL)
    draw.text((W // 2, panel_y + 425), "احجز رحلة", fill=WHITE, font=font(34, bold=True), anchor="mm")

    img.save(OUT / "02-customer-map.png", "PNG", optimize=True)


def screenshot_book_ride() -> None:
    img = Image.new("RGB", (W, H), TEAL_LIGHT)
    draw = ImageDraw.Draw(img)
    draw_app_bar(draw, "حجز رحلة")

    y = 180
    draw.text((W - 48, y), "نقطة الانطلاق", fill=GREY, font=font(26), anchor="rm")
    draw.text((W - 48, y + 40), "ناحية الشوملي", fill=DARK, font=font(32), anchor="rm")
    y += 120
    draw.text((W - 48, y), "الوجهة", fill=GREY, font=font(26), anchor="rm")
    draw.text(
        (W - 48, y + 40),
        "مطعم سيد هشام العوادي، الشوملي",
        fill=DARK,
        font=font(28),
        anchor="rm",
    )
    y += 160
    draw.line((48, y, W - 48, y), fill=(220, 220, 220), width=2)
    y += 60
    draw.text((W // 2, y), "1000 د.ع", fill=TEAL, font=font(72, bold=True), anchor="mm")
    y += 80
    draw.text((W // 2, y), "1.30 km    ~4 د", fill=GREY, font=font(30), anchor="mm")
    y += 50
    draw.text(
        (W // 2, y),
        "الدفع: نقداً فقط",
        fill=DARK,
        font=font(28),
        anchor="mm",
    )

    draw.rounded_rectangle((48, H - 180, W - 48, H - 80), radius=20, fill=TEAL)
    draw.text((W // 2, H - 130), "احجز الآن", fill=WHITE, font=font(36, bold=True), anchor="mm")

    img.save(OUT / "03-book-ride.png", "PNG", optimize=True)


def screenshot_driver_ride() -> None:
    img = Image.new("RGB", (W, H), TEAL_LIGHT)
    draw = ImageDraw.Draw(img)
    draw_app_bar(draw, "Hello Tuk-Tuk")

    draw.rectangle((0, 140, W, 900), fill=MAP_BG)
    draw.ellipse((500, 420, 560, 480), fill=GREEN, outline=WHITE, width=4)
    draw.ellipse((420, 560, 480, 620), fill=RED, outline=WHITE, width=4)

    card = (24, 920, W - 24, H - 60)
    rounded_card(draw, card)
    draw.text((W - 48, 980), "طلب رحلة جديد", fill=DARK, font=font(38, bold=True), anchor="rm")
    draw.text((W - 48, 1060), "نقطة الانطلاق", fill=GREY, font=font(24), anchor="rm")
    draw.text((W - 48, 1100), "ناحية الشوملي", fill=DARK, font=font(30), anchor="rm")
    draw.text((W - 48, 1170), "الوجهة", fill=GREY, font=font(24), anchor="rm")
    draw.text((W - 48, 1210), "مركز الهاشمية", fill=DARK, font=font(30), anchor="rm")
    draw.text((W - 48, 1290), "الأجرة نقداً: 1000 د.ع", fill=TEAL, font=font(32, bold=True), anchor="rm")

    draw.rounded_rectangle((600, 1380, W - 48, 1470), radius=18, fill=TEAL)
    draw.text((824, 1425), "قبول", fill=WHITE, font=font(32, bold=True), anchor="mm")
    draw.rounded_rectangle((48, 1380, 520, 1470), radius=18, outline=RED, width=3)
    draw.text((284, 1425), "رفض", fill=RED, font=font(32, bold=True), anchor="mm")

    img.save(OUT / "04-driver-accept-ride.png", "PNG", optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    screenshot_customer_map()
    screenshot_book_ride()
    screenshot_driver_ride()
    print("Generated screenshots in", OUT)


if __name__ == "__main__":
    main()
