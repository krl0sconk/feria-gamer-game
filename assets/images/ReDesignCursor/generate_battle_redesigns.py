"""Genera spritesheets de batalla (3 frames) recoloreados por variante de mapa."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image

from generate_redesigns import FEMALE_VARIANTS, MALE_VARIANTS

ROOT = Path(__file__).resolve().parent
BATTLE_BASE = ROOT / "spritesheet_npc.png"
OUT = ROOT / "rediseños" / "batalla"

FRAME_W, FRAME_H = 2008, 2026
FRAME_OFFSETS = [(0, 0), (2008, 0), (4016, 0)]

BATTLE_LUT: dict[tuple[int, int, int], str] = {}
for group, colors in {
    "outline": [
        (0, 0, 0),
        (1, 1, 1),
        (0, 0, 1),
        (1, 0, 0),
        (37, 14, 13),
        (47, 20, 14),
    ],
    "pants": [
        (22, 28, 44),
        (24, 31, 48),
        (25, 32, 49),
        (25, 31, 48),
        (24, 30, 47),
        (23, 30, 47),
        (17, 20, 41),
        (25, 32, 50),
        (24, 31, 47),
        (23, 30, 48),
        (25, 31, 49),
        (38, 37, 52),
        (53, 47, 76),
        (30, 26, 49),
    ],
    "blazer": [
        (140, 137, 172),
        (109, 95, 160),
        (178, 164, 238),
        (199, 155, 194),
    ],
    "hair": [(99, 65, 58), (77, 45, 54)],
    "accent": [(37, 29, 184), (29, 20, 172)],
    "skin": [(255, 223, 208)],
}.items():
    for c in colors:
        BATTLE_LUT[c] = group

REF_BY_GROUP: dict[str, list[tuple[int, int, int]]] = {
    "outline": [
        (0, 0, 0),
        (1, 1, 1),
        (0, 0, 1),
        (1, 0, 0),
        (37, 14, 13),
        (47, 20, 14),
    ],
    "pants": [
        (22, 28, 44),
        (24, 31, 48),
        (25, 32, 49),
        (25, 31, 48),
        (24, 30, 47),
        (23, 30, 47),
        (17, 20, 41),
        (25, 32, 50),
        (24, 31, 47),
        (23, 30, 48),
        (25, 31, 49),
        (38, 37, 52),
        (53, 47, 76),
        (30, 26, 49),
    ],
    "blazer": [
        (140, 137, 172),
        (109, 95, 160),
        (178, 164, 238),
        (199, 155, 194),
    ],
    "hair": [(99, 65, 58), (77, 45, 54)],
    "accent": [(37, 29, 184), (29, 20, 172)],
    "skin": [(255, 223, 208)],
}


def _saturate(rgb: tuple[int, int, int], factor: float = 1.35) -> tuple[int, int, int]:
    r, g, b = rgb
    avg = (r + g + b) / 3.0
    return (
        max(0, min(255, int(avg + (r - avg) * factor))),
        max(0, min(255, int(avg + (g - avg) * factor))),
        max(0, min(255, int(avg + (b - avg) * factor))),
    )


def walk_palette_to_battle(walk_pal: dict) -> dict[str, list[tuple[int, int, int]]]:
    jacket = walk_pal.get("jacket", walk_pal.get("shirt", [(80, 80, 80), (148, 156, 167)]))
    bottom = walk_pal.get("pants", walk_pal.get("skirt", [(30, 43, 58), (64, 74, 89)]))
    accent_base = jacket[1] if len(jacket) > 1 else jacket[0]
    if "shirt" in walk_pal and walk_pal["shirt"]:
        accent_base = walk_pal["shirt"][0]
    accent = _saturate(accent_base, 1.5)
    return {
        "outline": walk_pal["outline"],
        "hair": walk_pal["hair"],
        "blazer": jacket[:2] if len(jacket) >= 2 else [jacket[0], jacket[0]],
        "pants": bottom[:3] if len(bottom) >= 3 else bottom,
        "accent": [accent, _saturate(accent, 1.2)],
        "skin": walk_pal["skin"],
    }


def _nearest_group(rgb: np.ndarray) -> np.ndarray:
    keys = np.array(list(BATTLE_LUT.keys()), dtype=np.int16)
    groups = np.array([BATTLE_LUT[tuple(c)] for c in keys], dtype=object)
    flat = rgb.reshape(-1, 3).astype(np.int16)
    diff = flat[:, None, :] - keys[None, :, :]
    dist = np.sum(diff * diff, axis=2)
    idx = np.argmin(dist, axis=1)
    min_dist = dist[np.arange(dist.shape[0]), idx]
    out = np.full(flat.shape[0], "", dtype=object)
    out[min_dist <= 48 * 48] = groups[idx[min_dist <= 48 * 48]]
    return out.reshape(rgb.shape[:2])


def remap_battle_array(arr: np.ndarray, palette: dict[str, list[tuple[int, int, int]]]) -> np.ndarray:
    h, w, _ = arr.shape
    out = arr.copy()
    alpha = arr[:, :, 3]
    rgb = arr[:, :, :3]
    groups = _nearest_group(rgb)
    visible = alpha > 128

    for group in REF_BY_GROUP:
        mask = visible & (groups == group)
        if not np.any(mask):
            continue
        refs = np.array(REF_BY_GROUP[group], dtype=np.int16)
        pal = np.array(palette[group], dtype=np.int16)
        px = rgb[mask].astype(np.int16)
        diff = px[:, None, :] - refs[None, :, :]
        dist = np.sum(diff * diff, axis=2)
        ref_idx = np.argmin(dist, axis=1)
        pal_idx = np.minimum(ref_idx, len(pal) - 1)
        out[mask, :3] = pal[pal_idx]

    return out


def extract_three_frames(full: Image.Image) -> Image.Image:
    strip = Image.new("RGBA", (FRAME_W * 3, FRAME_H))
    for i, (x, y) in enumerate(FRAME_OFFSETS):
        frame = full.crop((x, y, x + FRAME_W, y + FRAME_H))
        strip.paste(frame, (i * FRAME_W, 0))
    return strip


def write_battle_tres(path: Path, texture_path: str, frame_count: int = 3) -> None:
    blocks: list[str] = []
    frame_refs: list[str] = []
    for i in range(frame_count):
        sid = f"AtlasTexture_{i}"
        x = i * FRAME_W
        blocks.append(
            f'[sub_resource type="AtlasTexture" id="{sid}"]\n'
            f'atlas = ExtResource("1_tex")\n'
            f"region = Rect2({x}, 0, {FRAME_W}, {FRAME_H})\n"
        )
        frame_refs.append(sid)

    frames = ", ".join(
        '{\n"duration": 1.0,\n"texture": SubResource("' + sid + '")\n}' for sid in frame_refs
    )
    content = f'''[gd_resource type="SpriteFrames" format=3]

[ext_resource type="Texture2D" path="{texture_path}" id="1_tex"]

{"".join(blocks)}
[resource]
animations = [{{
"frames": [{frames}],
"loop": true,
"name": &"Enemy",
"speed": 4.0
}}]
'''
    path.write_text(content, encoding="utf-8")


def all_variants() -> list[dict]:
    return list(FEMALE_VARIANTS) + list(MALE_VARIANTS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    base = Image.open(BATTLE_BASE).convert("RGBA")
    manifest = []

    cropped_frames = []
    for x, y in FRAME_OFFSETS:
        cropped_frames.append(np.array(base.crop((x, y, x + FRAME_W, y + FRAME_H)), dtype=np.uint8))

    for variant in all_variants():
        variant_id = variant["id"]
        battle_palette = walk_palette_to_battle(variant["palette"])
        recolored_frames = [remap_battle_array(frame, battle_palette) for frame in cropped_frames]
        strip = Image.new("RGBA", (FRAME_W * 3, FRAME_H))
        for i, frame_arr in enumerate(recolored_frames):
            strip.paste(Image.fromarray(frame_arr, "RGBA"), (i * FRAME_W, 0))

        png_name = f"{variant_id}_battle.png"
        tres_name = f"{variant_id}_battle.tres"
        strip.save(OUT / png_name)
        godot_tex = f"res://assets/images/ReDesignCursor/rediseños/batalla/{png_name}"
        write_battle_tres(OUT / tres_name, godot_tex)

        manifest.append(
            {
                "id": variant_id,
                "label": variant["label"],
                "walk_tres": f"res://assets/images/ReDesignCursor/rediseños/{variant_id}.tres",
                "battle_tres": f"res://assets/images/ReDesignCursor/rediseños/batalla/{tres_name}",
                "battle_png": png_name,
                "frames": 3,
            }
        )

    (OUT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Generados {len(manifest)} spritesheets de batalla en {OUT}")


if __name__ == "__main__":
    main()
