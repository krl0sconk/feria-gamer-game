"""Genera battlebullieextra(N).tscn y reescribe bully_spawn_manager.tscn."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RHYTHM = ROOT / "scenes" / "rhythm"
SPAWN_TSCN = ROOT / "scenes" / "map" / "bully_spawn_manager.tscn"
MANIFEST = Path(__file__).resolve().parent / "rediseños" / "batalla" / "manifest.json"

BG = "res://assets/images/backgrounds/bgPasillo.png"
BATTLE = "res://scenes/rhythm/battle.tscn"

MUSIC = {
    "crossing": {
        "path": "res://assets/audio/music/CROSSINGFIELDS.wav",
        "uid": "uid://coajlg8uc0npg",
        "bpm": 176.0,
        "chart": "res://assets/charts/crossingfield_chart_easy_plus.json",
    },
    "crossing_norm": {
        "path": "res://assets/audio/music/CROSSINGFIELDS.wav",
        "uid": "uid://coajlg8uc0npg",
        "bpm": 176.0,
        "chart": "res://assets/charts/crossingfield_chart_aligned_normal.json",
    },
    "midnight": {
        "path": "res://assets/audio/music/midnightcity_piano_full.wav",
        "uid": "uid://co5wluprbwb83",
        "bpm": 150.0,
        "chart": "res://assets/charts/midnightcity_piano_40s.json",
    },
    "arriba": {
        "path": "res://assets/audio/music/itsgoingarriba_chorus_20_60.wav",
        "uid": "uid://bntdhu6y3j0ir",
        "bpm": 150.0,
        "chart": "res://assets/charts/itsgoingarriba_chorus_40s.json",
    },
}

SPAWNS = [
    {"music": "crossing", "enabled": False, "pos": (-720, 1180)},
    {"music": "midnight", "enabled": True, "pos": (1480, 1240)},
    {"music": "crossing", "enabled": True, "pos": (420, 1680)},
    {"music": "midnight", "enabled": True, "pos": (-650, 920)},
    {"music": "arriba", "enabled": True, "pos": (-200, 580)},
    {"music": "crossing_norm", "enabled": True, "pos": (850, 720)},
    {"music": "crossing", "enabled": True, "pos": (-450, 1380)},
    {"music": "crossing_norm", "enabled": True, "pos": (720, 1550)},
    {"music": "arriba", "enabled": True, "pos": (1180, 980)},
    {"music": "midnight", "enabled": False, "pos": (-980, 850)},
]


def write_battle_scene(index: int, battle_tres: str, music_key: str) -> str:
    m = MUSIC[music_key]
    scene_path = f"res://scenes/rhythm/battlebullieextra{index}.tscn"
    content = f"""[gd_scene format=3 load_steps=5]

[ext_resource type="PackedScene" uid="uid://pid50iwjx4dd" path="{BATTLE}" id="1_base"]
[ext_resource type="Texture2D" uid="uid://ck45u308f8w0m" path="{BG}" id="2_bg"]
[ext_resource type="AudioStream" uid="{m['uid']}" path="{m['path']}" id="3_music"]
[ext_resource type="SpriteFrames" path="{battle_tres}" id="4_enemy"]

[node name="Battle" instance=ExtResource("1_base")]
chart_path = "{m['chart']}"
lose_scene_path = ""

[node name="Background" parent="." index="0"]
position = Vector2(5, 1)
scale = Vector2(0.7918985, 0.79189855)
texture = ExtResource("2_bg")

[node name="MusicPlayer" parent="." index="3"]
stream = ExtResource("3_music")
bpm = {m['bpm']}

[node name="Metronome" parent="." index="4"]
bpm = {m['bpm']}

[node name="AnimatedSprite2D" parent="EnemyBattle" index="0"]
position = Vector2(-11, -7)
scale = Vector2(0.23, 0.23)
sprite_frames = ExtResource("4_enemy")
animation = &"Enemy"

[node name="CollisionShape2D" parent="EnemyBattle" index="1"]
visible = true

[editable path="BattleHUD"]
[editable path="EnemyBattle"]
"""
    out = RHYTHM / f"battlebullieextra{index}.tscn"
    out.write_text(content, encoding="utf-8")
    return scene_path


def write_spawn_manager(variants: list[dict]) -> None:
    lines: list[str] = [
        '[gd_scene format=3 uid="uid://vkjnvbwonuy7"]',
        "",
        '[ext_resource type="Script" uid="uid://wldx3dpj0kel" path="res://scripts/encounters/bully_spawn_manager.gd" id="1_bsm"]',
        '[ext_resource type="Script" uid="uid://dd31ougo88is6" path="res://scripts/encounters/spawn_point.gd" id="2_sp"]',
    ]

    music_ids: dict[str, str] = {}
    for key, m in MUSIC.items():
        mid = f"m_{key}"
        music_ids[key] = mid
        lines.append(
            f'[ext_resource type="AudioStream" uid="{m["uid"]}" path="{m["path"]}" id="{mid}"]'
        )

    walk_ids: list[str] = []
    battle_ids: list[str] = []
    for i, variant in enumerate(variants[:10]):
        wid = f"w{i + 1:02d}"
        bid = f"b{i + 1:02d}"
        walk_ids.append(wid)
        battle_ids.append(bid)
        lines.append(
            f'[ext_resource type="SpriteFrames" path="{variant["walk_tres"]}" id="{wid}"]'
        )
        lines.append(
            f'[ext_resource type="PackedScene" path="res://scenes/rhythm/battlebullieextra{i + 1}.tscn" id="{bid}"]'
        )

    lines.extend(
        [
            "",
            '[node name="BullySpawnManager" type="Node2D"]',
            "position = Vector2(0, 2)",
            'script = ExtResource("1_bsm")',
            "",
        ]
    )

    for i, spawn in enumerate(SPAWNS):
        n = i + 1
        m = MUSIC[spawn["music"]]
        pos = spawn["pos"]
        enabled_line = ""
        if not spawn.get("enabled", True):
            enabled_line = "enabled = false\n"
        lines.extend(
            [
                f'[node name="SpawnPoint{n:02d}" type="Marker2D" parent="."]',
                f"position = Vector2({pos[0]}, {pos[1]})",
                'script = ExtResource("2_sp")',
                enabled_line.rstrip(),
                "despawn_on_win = false",
                f'sprite_frames = ExtResource("{walk_ids[i]}")',
                f'sprite_scale = Vector2(4, 4)',
                'preferred_animation = "frente"',
                f'battle_scene = ExtResource("{battle_ids[i]}")',
                f'battle_chart_path = "{m["chart"]}"',
                f'battle_music = ExtResource("{music_ids[spawn["music"]]}")',
                "",
            ]
        )
        # Remove empty line from enabled_line if false
        lines = [ln for ln in lines if ln != ""]

    # Rebuild more cleanly
    final: list[str] = [
        '[gd_scene format=3 uid="uid://vkjnvbwonuy7"]',
        "",
        '[ext_resource type="Script" uid="uid://wldx3dpj0kel" path="res://scripts/encounters/bully_spawn_manager.gd" id="1_bsm"]',
        '[ext_resource type="Script" uid="uid://dd31ougo88is6" path="res://scripts/encounters/spawn_point.gd" id="2_sp"]',
    ]
    for key, m in MUSIC.items():
        final.append(
            f'[ext_resource type="AudioStream" uid="{m["uid"]}" path="{m["path"]}" id="{music_ids[key]}"]'
        )
    for i, variant in enumerate(variants[:10]):
        final.append(
            f'[ext_resource type="SpriteFrames" path="{variant["walk_tres"]}" id="{walk_ids[i]}"]'
        )
        final.append(
            f'[ext_resource type="PackedScene" path="res://scenes/rhythm/battlebullieextra{i + 1}.tscn" id="{battle_ids[i]}"]'
        )
    final.extend(
        [
            "",
            '[node name="BullySpawnManager" type="Node2D"]',
            "position = Vector2(0, 2)",
            'script = ExtResource("1_bsm")',
        ]
    )
    for i, spawn in enumerate(SPAWNS):
        n = i + 1
        m = MUSIC[spawn["music"]]
        pos = spawn["pos"]
        block = [
            "",
            f'[node name="SpawnPoint{n:02d}" type="Marker2D" parent="."]',
            f"position = Vector2({pos[0]}, {pos[1]})",
            'script = ExtResource("2_sp")',
        ]
        if not spawn.get("enabled", True):
            block.append("enabled = false")
        block.extend(
            [
                "despawn_on_win = false",
                f'sprite_frames = ExtResource("{walk_ids[i]}")',
                "sprite_scale = Vector2(4, 4)",
                'preferred_animation = "frente"',
                f'battle_scene = ExtResource("{battle_ids[i]}")',
                f'battle_chart_path = "{m["chart"]}"',
                f'battle_music = ExtResource("{music_ids[spawn["music"]]}")',
            ]
        )
        final.extend(block)

    SPAWN_TSCN.write_text("\n".join(final) + "\n", encoding="utf-8")


def main() -> None:
    variants = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for i, spawn in enumerate(SPAWNS, start=1):
        variant = variants[i - 1]
        write_battle_scene(i, variant["battle_tres"], spawn["music"])
        print(f"battlebullieextra{i}.tscn -> {variant['id']}")
    write_spawn_manager(variants)
    print(f"Updated {SPAWN_TSCN}")


if __name__ == "__main__":
    main()
