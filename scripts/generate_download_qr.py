"""Generate QR code PNG for the Hello Tuk-Tuk app download page."""

from __future__ import annotations

from pathlib import Path

import qrcode

DOWNLOAD_URL = "https://hello-tiktok-57dc5.web.app/download.html"
OUT_DIR = Path(__file__).resolve().parents[1] / "app-store-assets"
OUT_FILE = OUT_DIR / "download-qr-code.png"


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=12,
        border=4,
    )
    qr.add_data(DOWNLOAD_URL)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#0f766e", back_color="white")
    img.save(OUT_FILE)
    print(f"QR code saved: {OUT_FILE}")
    print(f"Points to: {DOWNLOAD_URL}")


if __name__ == "__main__":
    main()
