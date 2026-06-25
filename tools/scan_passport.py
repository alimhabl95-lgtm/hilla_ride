"""Process passport photos into flat color-scanner style images."""

import cv2
import numpy as np
from pathlib import Path


ASSETS = Path(
    r"C:\Users\Bi\.cursor\projects\c-Users-Bi-Projects-hilla-ride\assets"
)
OUTPUT = Path(r"C:\Users\Bi\Projects\hilla_ride\scanned_passport")

# Normalized corners: top-left, top-right, bottom-right, bottom-left
MANUAL_CORNERS: dict[str, list[tuple[float, float]]] = {
    "01852048": [(0.04, 0.03), (0.67, 0.02), (0.68, 0.97), (0.03, 0.96)],
    "18006a3c": [(0.02, 0.03), (0.98, 0.02), (0.97, 0.97), (0.03, 0.96)],
    "95cfdc2d": [(0.04, 0.03), (0.97, 0.04), (0.96, 0.97), (0.03, 0.96)],
    "424449b1": [(0.06, 0.04), (0.82, 0.05), (0.78, 0.95), (0.05, 0.94)],
}

ROTATION: dict[str, int | None] = {
    "01852048": cv2.ROTATE_90_COUNTERCLOCKWISE,
    "18006a3c": cv2.ROTATE_90_COUNTERCLOCKWISE,
    "95cfdc2d": None,
    "424449b1": None,
}

INPUTS = [
    ("01_passport_data_page.png",
     "c__Users_Bi_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_image-01852048-7de3-47f3-9c46-88d29f73905c.png"),
    ("02_visa_schengen_spread.png",
     "c__Users_Bi_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_image-18006a3c-b28b-4713-83db-df0e024da452.png"),
    ("03_visa_iraq_stamps.png",
     "c__Users_Bi_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_image-95cfdc2d-5bec-4d0d-a8ec-aea19f2c32f7.png"),
    ("04_visa_turkey_stamp.png",
     "c__Users_Bi_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_image-424449b1-4d3a-4f08-9c71-d0cf1a5d740a.png"),
]


def order_points(pts: np.ndarray) -> np.ndarray:
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    return rect


def find_corners(image: np.ndarray, key: str) -> np.ndarray:
    pts = MANUAL_CORNERS.get(key)
    if not pts:
        raise RuntimeError(f"No corner map for {key}")
    h, w = image.shape[:2]
    return np.array([[x * w, y * h] for x, y in pts], dtype="float32")


def four_point_transform(image: np.ndarray, pts: np.ndarray) -> np.ndarray:
    rect = order_points(pts)
    tl, tr, br, bl = rect
    width = int(max(np.linalg.norm(br - bl), np.linalg.norm(tr - tl)))
    height = int(max(np.linalg.norm(tr - br), np.linalg.norm(tl - bl)))
    dst = np.array(
        [[0, 0], [width - 1, 0], [width - 1, height - 1], [0, height - 1]],
        dtype="float32",
    )
    matrix = cv2.getPerspectiveTransform(rect, dst)
    return cv2.warpPerspective(image, matrix, (width, height))


def enhance_scan(image: np.ndarray) -> np.ndarray:
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    clahe = cv2.createCLAHE(clipLimit=1.8, tileGridSize=(8, 8))
    l = clahe.apply(l)
    blur_l = cv2.GaussianBlur(l, (0, 0), sigmaX=40, sigmaY=40)
    l = cv2.addWeighted(l, 1.35, blur_l, -0.35, 0)
    l = np.clip(l, 0, 255).astype(np.uint8)
    result = cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)
    avg = result.reshape(-1, 3).mean(axis=0)
    gain = np.clip(238.0 / (avg + 1e-6), 0.88, 1.12)
    result = np.clip(result.astype(np.float32) * gain, 0, 255).astype(np.uint8)
    blur = cv2.GaussianBlur(result, (0, 0), 1.0)
    return cv2.addWeighted(result, 1.2, blur, -0.2, 0)


def trim_borders(image: np.ndarray) -> np.ndarray:
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    paper = cv2.inRange(hsv, (25, 5, 60), (140, 180, 255))
    red = cv2.inRange(hsv, (0, 40, 40), (15, 255, 255)) | cv2.inRange(
        hsv, (165, 40, 40), (180, 255, 255)
    )
    mask = paper & ~red
    coords = np.argwhere(mask)
    if coords.size == 0:
        return image
    y0, x0 = coords.min(axis=0)
    y1, x1 = coords.max(axis=0)
    pad = 3
    y0 = max(0, y0 - pad)
    x0 = max(0, x0 - pad)
    y1 = min(image.shape[0] - 1, y1 + pad)
    x1 = min(image.shape[1] - 1, x1 + pad)
    return image[y0 : y1 + 1, x0 : x1 + 1]


def process_image(path: Path) -> np.ndarray:
    image = cv2.imread(str(path))
    if image is None:
        raise FileNotFoundError(path)

    key = next(k for k in MANUAL_CORNERS if k in path.name)
    warped = four_point_transform(image, find_corners(image, key))
    rotate = ROTATION.get(key)
    if rotate is not None:
        warped = cv2.rotate(warped, rotate)
    warped = trim_borders(warped)
    return enhance_scan(warped)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for out_name, src_name in INPUTS:
        src = ASSETS / src_name
        print(f"Processing {src.name} -> {out_name}")
        result = process_image(src)
        out_path = OUTPUT / out_name
        cv2.imwrite(str(out_path), result, [cv2.IMWRITE_PNG_COMPRESSION, 3])
        jpg_path = out_path.with_suffix(".jpg")
        cv2.imwrite(str(jpg_path), result, [cv2.IMWRITE_JPEG_QUALITY, 95])
        print(f"  Saved {out_path} ({result.shape[1]}x{result.shape[0]})")
    print(f"\nDone. Output folder: {OUTPUT}")


if __name__ == "__main__":
    main()
