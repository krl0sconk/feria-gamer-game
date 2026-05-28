"""Genera variantes de ropa/cabello desde 16x32 Walk.png y Walk-boy.png."""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "rediseños"
FRAME_W, FRAME_H = 16, 32


def color_dist(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> float:
    return math.sqrt(sum((a[i] - b[i]) ** 2 for i in range(3)))


def classify_pixel(rgba: tuple[int, int, int, int], groups: dict[str, list[tuple[int, int, int]]]) -> str | None:
    if rgba[3] == 0:
        return None
    best_group = None
    best_dist = 9999.0
    for name, colors in groups.items():
        for c in colors:
            d = color_dist(rgba, (*c, 255))
            if d < best_dist:
                best_dist = d
                best_group = name
    if best_dist > 48:
        return "other"
    return best_group


def remap_image(img: Image.Image, groups: dict[str, list[tuple[int, int, int]]], palette: dict[str, list[tuple[int, int, int]]]) -> Image.Image:
    src = img.convert("RGBA")
    out = Image.new("RGBA", src.size)
    pixels = src.load()
    dst = out.load()
    for y in range(src.height):
        for x in range(src.width):
            px = pixels[x, y]
            group = classify_pixel(px, groups)
            if group is None:
                dst[x, y] = px
                continue
            if group == "outline":
                dst[x, y] = (*palette["outline"][0], px[3])
                continue
            if group == "other":
                dst[x, y] = px
                continue
            refs = groups[group]
            pal = palette[group]
            idx = min(range(len(refs)), key=lambda i: color_dist(px, (*refs[i], 255)))
            dst[x, y] = (*pal[min(idx, len(pal) - 1)], px[3])
    return out


def flatten_boy_sheet(img: Image.Image) -> Image.Image:
    """Convierte 4x4 (frente/lado/back) a tira horizontal 12 frames como npc0."""
    src = img.convert("RGBA")
    strip = Image.new("RGBA", (FRAME_W * 12, FRAME_H))
    rows = [0, 2, 3]  # frente, perfil derecho, espalda
    col = 0
    for row in rows:
        for frame in range(4):
            box = (frame * FRAME_W, row * FRAME_H, (frame + 1) * FRAME_W, (row + 1) * FRAME_H)
            strip.paste(src.crop(box), (col * FRAME_W, 0))
            col += 1
    return strip


FEMALE_GROUPS = {
    "outline": [(47, 37, 34)],
    "hair": [(182, 130, 76), (153, 84, 13), (143, 100, 55), (73, 60, 60)],
    "shirt": [(80, 80, 80), (148, 156, 167)],
    "skirt": [(30, 43, 58), (64, 74, 89), (49, 51, 77)],
    "skin": [(254, 227, 238), (209, 157, 167), (237, 186, 183)],
}

MALE_GROUPS = {
    "outline": [(47, 37, 34)],
    "hair": [(22, 24, 26), (32, 34, 37), (18, 17, 17)],
    "jacket": [(66, 60, 106), (54, 49, 90), (33, 28, 72), (126, 119, 175)],
    "shirt": [(244, 242, 239), (85, 131, 200)],
    "pants": [(22, 24, 26), (32, 34, 37)],
    "skin": [(237, 206, 188), (196, 159, 119), (209, 157, 167)],
}

FEMALE_VARIANTS = [
    {
        "id": "chica_rubia_azul",
        "label": "Chica rubia — blusa azul",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(240, 210, 120), (210, 170, 70), (190, 150, 60), (120, 90, 40)],
            "shirt": [(70, 130, 210), (110, 160, 230)],
            "skirt": [(35, 45, 90), (55, 65, 110), (45, 55, 95)],
            "skin": [(254, 227, 238), (209, 157, 167), (237, 186, 183)],
        },
    },
    {
        "id": "chica_pelirroja_verde",
        "label": "Chica pelirroja — blusa verde",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(210, 90, 55), (170, 60, 35), (150, 50, 30), (90, 35, 25)],
            "shirt": [(60, 150, 90), (90, 180, 120)],
            "skirt": [(40, 35, 55), (60, 55, 75), (50, 45, 65)],
            "skin": [(255, 230, 215), (220, 170, 150), (240, 195, 175)],
        },
    },
    {
        "id": "chica_morena_rojo",
        "label": "Chica morena — blusa roja",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(55, 35, 25), (35, 22, 18), (45, 28, 20), (30, 18, 15)],
            "shirt": [(190, 55, 55), (220, 90, 90)],
            "skirt": [(30, 30, 40), (50, 50, 65), (40, 40, 52)],
            "skin": [(210, 170, 140), (175, 130, 105), (195, 150, 125)],
        },
    },
    {
        "id": "chica_cafe_rosa",
        "label": "Chica castaña — blusa rosa",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(120, 75, 45), (95, 58, 32), (110, 68, 40), (70, 45, 28)],
            "shirt": [(230, 130, 170), (250, 170, 200)],
            "skirt": [(70, 50, 80), (90, 70, 100), (80, 60, 90)],
            "skin": [(254, 227, 238), (209, 157, 167), (237, 186, 183)],
        },
    },
    {
        "id": "chica_negro_morado",
        "label": "Chica cabello negro — blusa morada",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(30, 28, 32), (20, 18, 22), (25, 23, 28), (15, 14, 18)],
            "shirt": [(120, 70, 170), (150, 100, 200)],
            "skirt": [(25, 25, 35), (40, 40, 55), (32, 32, 45)],
            "skin": [(255, 230, 215), (220, 170, 150), (240, 195, 175)],
        },
    },
    {
        "id": "chico_base_falda_pantalon",
        "label": "Chico (base femenina) — pantalón oscuro",
        "gender": "masculino",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(55, 35, 25), (35, 22, 18), (45, 28, 20), (30, 18, 15)],
            "shirt": [(90, 110, 140), (120, 140, 170)],
            "skirt": [(28, 28, 32), (40, 40, 48), (34, 34, 40)],
            "skin": [(237, 206, 188), (196, 159, 119), (209, 157, 167)],
        },
    },
]

MALE_VARIANTS = [
    {
        "id": "chico_rubio_verde",
        "label": "Chico rubio — chaqueta verde",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(210, 180, 90), (180, 150, 70), (160, 130, 60)],
            "jacket": [(45, 110, 70), (35, 90, 58), (28, 70, 45), (70, 140, 95)],
            "shirt": [(245, 245, 240), (200, 210, 220)],
            "pants": [(28, 28, 32), (38, 38, 44)],
            "skin": [(254, 227, 238), (209, 157, 167), (237, 186, 183)],
        },
    },
    {
        "id": "chico_moreno_rojo",
        "label": "Chico moreno — chaqueta roja",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(30, 22, 18), (20, 15, 12), (25, 18, 14)],
            "jacket": [(150, 45, 45), (120, 35, 35), (90, 28, 28), (180, 70, 70)],
            "shirt": [(240, 240, 235), (180, 190, 210)],
            "pants": [(22, 22, 28), (32, 32, 38)],
            "skin": [(210, 170, 140), (175, 130, 105), (195, 150, 125)],
        },
    },
    {
        "id": "chico_cafe_azul",
        "label": "Chico castaño — chaqueta azul",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(100, 65, 40), (80, 50, 30), (70, 42, 25)],
            "jacket": [(50, 70, 140), (40, 55, 110), (30, 45, 90), (80, 100, 170)],
            "shirt": [(245, 245, 240), (130, 170, 220)],
            "pants": [(30, 30, 36), (42, 42, 50)],
            "skin": [(237, 206, 188), (196, 159, 119), (209, 157, 167)],
        },
    },
    {
        "id": "chico_negro_amarillo",
        "label": "Chico cabello negro — chaqueta amarilla",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(22, 20, 24), (14, 12, 16), (18, 16, 20)],
            "jacket": [(210, 180, 50), (180, 150, 40), (150, 125, 32), (230, 200, 80)],
            "shirt": [(250, 250, 245), (200, 200, 195)],
            "pants": [(25, 25, 30), (35, 35, 42)],
            "skin": [(255, 230, 215), (220, 170, 150), (240, 195, 175)],
        },
    },
    {
        "id": "chico_pelirrojo_morado",
        "label": "Chico pelirrojo — chaqueta morada",
        "palette": {
            "outline": [(47, 37, 34)],
            "hair": [(190, 70, 40), (160, 55, 30), (140, 45, 25)],
            "jacket": [(100, 50, 130), (80, 40, 105), (65, 32, 85), (130, 80, 160)],
            "shirt": [(245, 240, 250), (190, 170, 220)],
            "pants": [(28, 26, 34), (40, 38, 48)],
            "skin": [(254, 227, 238), (209, 157, 167), (237, 186, 183)],
        },
    },
]


def write_spriteframes_tres(path: Path, texture_path: str) -> None:
    regions_frente = [0, 16, 32, 48]
    regions_lados = [64, 80, 96, 112]
    regions_espalda = [128, 144, 160, 176]
    sub_ids: list[str] = []
    blocks: list[str] = []
    idx = 0

    def add_atlas(x: int) -> str:
        nonlocal idx
        sid = f"AtlasTexture_{idx}"
        idx += 1
        blocks.append(
            f"[sub_resource type=\"AtlasTexture\" id=\"{sid}\"]\n"
            f"atlas = ExtResource(\"1_tex\")\n"
            f"region = Rect2({x}, 0, 16, 32)\n"
        )
        sub_ids.append(sid)
        return sid

    frente_ids = [add_atlas(x) for x in regions_frente]
    lados_ids = [add_atlas(x) for x in regions_lados]
    espalda_ids = [add_atlas(x) for x in regions_espalda]

    def frames_line(ids: list[str]) -> str:
        parts = []
        for sid in ids:
            parts.append('{\n"duration": 1.0,\n"texture": SubResource("' + sid + '")\n}')
        return ", ".join(parts)

    content = f'''[gd_resource type="SpriteFrames" format=3]

[ext_resource type="Texture2D" path="{texture_path}" id="1_tex"]

{"".join(blocks)}
[resource]
animations = [{{
"frames": [{frames_line(espalda_ids)}],
"loop": true,
"name": &"espalda",
"speed": 5.0
}}, {{
"frames": [{frames_line(frente_ids)}],
"loop": true,
"name": &"frente",
"speed": 5.0
}}, {{
"frames": [{frames_line(lados_ids)}],
"loop": true,
"name": &"lados",
"speed": 5.0
}}]
'''
    path.write_text(content, encoding="utf-8")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    female_base = Image.open(ROOT / "16x32 Walk.png")
    male_base = flatten_boy_sheet(Image.open(ROOT / "16x32 Walk-boy.png"))

    manifest = []

    for variant in FEMALE_VARIANTS:
        img = remap_image(female_base, FEMALE_GROUPS, variant["palette"])
        png_name = f"{variant['id']}.png"
        tres_name = f"{variant['id']}.tres"
        img.save(OUT / png_name)
        godot_tex = f"res://assets/images/ReDesignCursor/rediseños/{png_name}"
        write_spriteframes_tres(OUT / tres_name, godot_tex)
        manifest.append({"id": variant["id"], "label": variant["label"], "gender": variant.get("gender", "femenino"), "file": png_name})

    for variant in MALE_VARIANTS:
        img = remap_image(male_base, MALE_GROUPS, variant["palette"])
        png_name = f"{variant['id']}.png"
        tres_name = f"{variant['id']}.tres"
        img.save(OUT / png_name)
        godot_tex = f"res://assets/images/ReDesignCursor/rediseños/{png_name}"
        write_spriteframes_tres(OUT / tres_name, godot_tex)
        manifest.append({"id": variant["id"], "label": variant["label"], "gender": variant.get("gender", "masculino"), "file": png_name})

    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Generados {len(manifest)} rediseños en {OUT}")


if __name__ == "__main__":
    main()
