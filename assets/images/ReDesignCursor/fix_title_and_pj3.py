"""Regenerate menu title and pj3 battle sheet."""
from __future__ import annotations

import collections
import math
import os
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
FILL = (18, 22, 58, 255)


def is_bg(r: int, g: int, b: int, a: int) -> bool:
    return a < 10 or (r < 28 and g < 28 and b < 28)


def build_title() -> None:
    src = ROOT / "assets/images/icons/Banner3.png"
    dst = ROOT / "assets/images/menu/title.png"
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    px = img.load()

    bg = [[False] * w for _ in range(h)]
    q: collections.deque[tuple[int, int]] = collections.deque()
    for x in range(w):
        for y in (0, h - 1):
            if not bg[y][x] and is_bg(*px[x, y]):
                bg[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not bg[y][x] and is_bg(*px[x, y]):
                bg[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx] and is_bg(*px[nx, ny]):
                bg[ny][nx] = True
                q.append((nx, ny))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y in range(h):
        for x in range(w):
            if bg[y][x]:
                continue
            r, g, b, a = px[x, y]
            if r > 210 and g > 210 and b > 210:
                out.putpixel((x, y), (r, g, b, a))
            elif max(r, g, b) > 170 and (abs(r - g) > 40 or abs(r - b) > 40 or abs(g - b) > 40):
                out.putpixel((x, y), (r, g, b, a))
            elif r > 140 and g > 100 and b < 80:
                out.putpixel((x, y), (r, g, b, a))
            else:
                out.putpixel((x, y), FILL)

    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    pad = 10
    final = Image.new("RGBA", (out.width + pad * 2, out.height + pad * 2), (0, 0, 0, 0))
    final.paste(out, (pad, pad), out)
    final.save(dst)
    print("title", final.size)


def trim_icon(img: Image.Image, tol: int = 80) -> Image.Image:
    bg = img.getpixel((0, 0))
    px = img.load()
    w, h = img.size
    minx, miny, maxx, maxy = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 10:
                continue
            if abs(r - bg[0]) < tol and abs(g - bg[1]) < tol and abs(b - bg[2]) < tol:
                continue
            minx = min(minx, x)
            miny = min(miny, y)
            maxx = max(maxx, x)
            maxy = max(maxy, y)
    return img.crop((minx, miny, maxx + 1, maxy + 1))


def build_pj3_idle() -> None:
    icon = Image.open(ROOT / "assets/images/characters/pj3/pj3_icon.png").convert("RGBA")
    icon_trim = trim_icon(icon)
    fw, fh = 1280, 1280
    frames = 9
    sheet_w = fw * frames
    if sheet_w > 16384:
        raise ValueError(f"sheet too wide: {sheet_w}")
    sheet = Image.new("RGBA", (sheet_w, fh), (0, 0, 0, 0))
    scale = (fh * 0.82) / icon_trim.height
    new_w = max(1, int(icon_trim.width * scale))
    new_h = max(1, int(icon_trim.height * scale))
    icon_scaled = icon_trim.resize((new_w, new_h), Image.Resampling.LANCZOS)
    for i in range(frames):
        frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        bob = int(12 * math.sin(i * 1.05))
        sway = int(6 * math.cos(i * 0.85))
        x = (fw - new_w) // 2 + sway
        y = fh - new_h - 70 + bob
        frame.paste(icon_scaled, (x, y), icon_scaled)
        sheet.paste(frame, (i * fw, 0))
    out_path = ROOT / "assets/images/characters/pj3/pj3_idle.png"
    sheet.save(out_path)
    print("pj3_idle", sheet.size)


if __name__ == "__main__":
    build_title()
    build_pj3_idle()
