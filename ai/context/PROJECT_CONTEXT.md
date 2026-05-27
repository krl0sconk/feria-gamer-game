# 🎮 Contexto del Proyecto — Feria Gamer 2026

> **Archivo de referencia para asistentes de IA.**
> Actualiza este archivo cada vez que haya cambios importantes en el proyecto.

---

## 📋 Información General

| Campo | Detalle |
|---|---|
| **Nombre del proyecto** | Beat the bully |
| **Motor** | Godot 4.6.1 (GDScript) |
| **Versión** | 0.1.5 |
| **Universidad** | Universidad del Norte — Barranquilla, Colombia |
| **Materia** | Programación Orientada a Objetos (POO) 2026-10 |
| **Evento** | V Feria Gamer — 28 de mayo de 2026 |
| **Repositorio** | https://github.com/krl0sconk/feria-gamer-game |
| **Documentación técnica** | `DOCUMENTATION.md` (referencia completa) |

---

## 🏗️ Requisitos Técnicos (Materia POO)

- [x] Mínimo **5 clases (TAD)** de autoría propia — ✅ 39+ clases GDScript en 10 módulos
- [x] Al menos **1 patrón de diseño** (Sin contar Singleton, Prototype ni Module) — ✅ Strategy (ScoreRules/HealthRules → Referee), Command (cinemáticas)
- [x] **Interfaz gráfica** obligatoria (Godot UI)
- [x] **Componente aleatorio** — BullySpawnManager (spawns aleatorios con seed)
- [x] **Componente inclusivo** — shader daltonismo, fuente dislexia, 4 avatares, subtítulos en diálogos
- [x] Robusto ante **entradas erróneas** — parsers con fallback, saves atómicos, validación de controles

---

## 🗂️ Estructura del Repositorio

```
Beat-The-Bully/
├── assets/
│   ├── audio/          # Música y SFX
│   ├── charts/         # Charts JSON de batallas (6 archivos)
│   ├── cinematics/     # Cinemáticas JSON (24 archivos)
│   ├── dialogues/      # Diálogos JSON (21 archivos)
│   └── images/         # Sprites, tilesets, iconos
│       └── characters/
│           ├── pj1–pj4/   # 4 skins jugables
│           └── npc/
│               ├── npc1/  # NPCs genéricos
│               ├── npc2/  # Cyber bully
│               ├── npc3/  # Duo bully
│               └── npc4/  # Girl bully (boss final)
├── scenes/
│   ├── menu/           # main_menu, save_slots, select_pj, options
│   ├── map/            # room, classroom, map, backyard, tableros, player, bully_spawn_manager
│   ├── rhythm/         # 8 batallas temáticas + HUD + win/lose
│   ├── dialogue/       # dialogue_box, dialogue_runner, interactable
│   ├── cinematic/      # 7 templates de authoring
│   ├── ui/             # pause, save_slots, rebind, colorblind, keychain
│   ├── quest/          # quest_hud
│   └── editor/         # chart, quest, cinematic editors
├── scripts/            # GDScript — lógica del juego (39 archivos)
│   ├── cinematic/      # 10 clases — sistema de cinemáticas
│   ├── dialogue/       # 4 clases — diálogos JSON
│   ├── encounters/     # 3 clases — BullySpawnManager + spawn points
│   ├── map/            # map.gd, room.gd, player.gd
│   ├── menu/           # main_menu, select_pj, options, controls_settings
│   ├── quests/         # quest.gd, quest_manager, quest_hud
│   ├── rhythm/         # 18 clases — sistema de ritmo completo
│   ├── save/           # save_manager.gd
│   └── ui/             # pause, save_slots, rebind, colorblind, keychain
├── addons/
│   └── cinematic_authoring/  # Plugin editor para colocar nodos cinemáticos
├── resources/          # Temas, shaders, datos (quests.json, translations)
├── docs/               # Guías de cinemáticas y debug
└── ai/                 # Contexto y prompts para IA
```

---

## 🔄 Flujo de Escenas

```
main_menu → save_slots (3 slots) → select_pj (4 skins) → room
    → classroom → map ↔ backyard
    → batallas rítmicas → win/lose screen → retorno al mapa
```

---

## 🔌 Autoloads

| Nombre | Archivo | Rol |
|--------|---------|-----|
| Gamemanager | `scripts/gamemanager.gd` | Estado global, cinemáticas, highscores, música menú |
| QuestManager | `scripts/quests/quest_manager.gd` | Progresión de misiones |
| SaveManager | `scripts/save/save_manager.gd` | 3 slots JSON en `user://savesgames/` |
| ColorblindOverlay | `scenes/ui/colorblind_overlay.tscn` | Shader accesibilidad |

---

## 🎵 Rhythm System — Implemented Classes

All classes are in `scripts/rhythm/`. Signal-driven pipeline; Strategy pattern in Referee.

| File | Class | Role |
|------|-------|------|
| `note_data.gd` | NoteData | Data: beat + action |
| `player_input.gd` | PlayerInput | Input detection |
| `music_player.gd` | MusicPlayer | Playback + time |
| `metronome.gd` | Metronome | Beat tracking + timing eval |
| `composer.gd` | Composer | Chart management |
| `judge.gd` | Judge | Action validation |
| `referee.gd` | Referee | HP / score / combo (Strategy context) |
| `score_rules.gd` | ScoreRules | Strategy: scoring formula |
| `health_rules.gd` | HealthRules | Strategy: HP formula |
| `enemy_gauge.gd` | EnemyGauge | Song progress bar |
| `rating_feedback.gd` | RatingFeedback | PERFECT/GOOD/MISS popup |
| `battle.gd` / `battle_hud.gd` | Battle / BattleHUD | Orchestrator + visuals |
| `win_screen.gd` / `lose_screen.gd` | Win/LoseScreen | Post-battle screens |

**Battle scenes:** tutorial, battle (genérico), cool_battle, double_battle, cyber_battle, final_battle.
**Charts:** tutorial, coolguy, doubletrouble, cyberbattle, rudegirl (+ grandfinal sin usar).

---

## 💬 Dialogue System

| File | Class | Role |
|------|-------|------|
| `dialogue_loader.gd` | DialogueLoader + data classes | JSON parser |
| `dialogue_box.gd` | DialogueBox | Typewriter view |
| `dialogue_runner.gd` | DialogueRunner | Sequencer |
| `interactable.gd` | Interactable | NPC trigger + battle + missions |

21 JSON files in `assets/dialogues/`. Cross-scene state in Gamemanager.

---

## 🎬 Cinematic System

| File | Class | Role |
|------|-------|------|
| `cinematic_loader.gd` | CinematicLoader | JSON parser |
| `cinematic_player.gd` | CinematicPlayer | Command executor |
| `cinematic_actor.gd` | CinematicActor | NPC movement helpers |
| `cinematic_camera.gd` | CinematicCamera | Pan/zoom/shake |
| `cinematic_target_resolver.gd` | CinematicTargetResolver | Destination resolution |
| `waypoint_path.gd` | WaypointPath | Editable routes |
| `scripted_trigger.gd` | ScriptedTrigger | Area2D trigger |
| `scripted_barrier.gd` | ScriptedBarrier | Toggleable walls |
| `follower.gd` | Follower | NPC escort |
| `interaction_indicator.gd` | InteractionIndicator | Floating `!` |

24 JSON in `assets/cinematics/`. 7 template scenes in `scenes/cinematic/`.
Editor plugin: `addons/cinematic_authoring/`.
Guides: `docs/cinematics/GUIA_COMPLETA_CINEMATICAS.md`.

---

## 💾 Save System

- 3 slots at `user://savesgames/save_slot_{1,2,3}.json`
- Saves: player scene/position/skin, quests, world serializers, cinematics played
- Triggers: first skin pick, pause exit, manual
- Separate: highscores (`user://highscores.json`), settings (`user://settings.cfg`)

---

## 👾 Encounter System

- `BullySpawnManager` on `map.tscn` — seeded random bully spawns (default 5)
- `spawn_point.gd` on Marker2D children — per-marker profile/chart/music
- Persists via `"world_state_serializers"` group in saves

---

## 📝 Notas para la IA

- El juego usa **GDScript**, no C#
- Godot 4.x: `@export`, `@onready`, signals, `CharacterBody2D`
- Los patrones de diseño deben ser evidentes en el código para la evaluación
- Priorizar legibilidad sobre optimización prematura
- Documentación completa en `DOCUMENTATION.md`
