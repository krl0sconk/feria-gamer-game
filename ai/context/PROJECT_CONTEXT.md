# 🎮 Contexto del Proyecto — Feria Gamer 2026

> **Archivo de referencia para asistentes de IA.**
> Actualiza este archivo cada vez que haya cambios importantes en el proyecto.

---

## 📋 Información General

| Campo | Detalle |
|---|---|
| **Nombre del proyecto** | Beat the bully |
| **Motor** | Godot 4.6.1 (GDScript) |
| **Universidad** | Universidad del Norte — Barranquilla, Colombia |
| **Materia** | Programación Orientada a Objetos (POO) 2026-10 |
| **Evento** | V Feria Gamer — 28 de mayo de 2026 |
| **Repositorio** | https://github.com/krl0sconk/feria-gamer-game |


---

## 🏗️ Requisitos Técnicos (Materia POO)

- [x] Mínimo **5 clases (TAD)** de autoría propia — ✅ 12 clases implementadas en `scripts/rhythm/`
- [ ] Al menos **1 patrón de diseño** (Sin contar Singleton, Prototype ni Module)
- [ ] **Interfaz gráfica** obligatoria (Godot UI)
- [ ] **Componente aleatorio** 
- [ ] **Componente inclusivo** (subtítulos, modos de accesibilidad, selección de avatar)
- [ ] Robusto ante **entradas erróneas**

---


---

## 🗂️ Estructura del Repositorio

```
feria-gamer-game/
├── assets/          # Sprites, audio, fuentes, videos
├── scenes/          # Escenas Godot (.tscn)
├── scripts/         # GDScript (.gd) — lógica del juego
│   ├── rhythm/      # Sistema de ritmo: 13 clases (NoteData, PlayerInput, MusicPlayer,
│   │                #   Metronome, Composer, Judge, Referee, ScoreRules,
│   │                #   HealthRules, EnemyGauge, RatingFeedback, LoseScreen,
│   │                #   WinScreen)
│   ├── dialogue/    # Sistema de diálogo: 4 clases (DialogueLoader + DialogueData
│   │                #   + DialogueLine, DialogueBox, DialogueRunner, Interactable)
│   └── cinematic/   # Sistema de cinemáticas: CinematicLoader, CinematicPlayer,
│                    #   CinematicActor, CinematicCamera, WaypointPath, ScriptedTrigger,
│                    #   ScriptedBarrier, Follower, InteractionIndicator
├── resources/       # Temas, shaders, materiales, datos
├── addons/          # Plugins de Godot (Asset Library)
├── tests/           # Tests unitarios / integración
└── ai/              # Contexto y prompts para IA
    ├── context/     # ← ESTÁS AQUÍ
    ├── prompts/     # Prompts reutilizables
    ├── decisions/   # Decisiones tomadas con ayuda de IA
```

## 📝 Notas para la IA

- El juego usa **GDScript**, no C#
- Godot 4.x usa `@export`, `@onready`, signals con `signal_name.emit()`, `CharacterBody2D`, etc.
- Los patrones de diseño deben ser evidentes en el código para la evaluación
- Cada clase debe tener docstring descriptivo
- Priorizar legibilidad sobre optimización prematura

## 🎵 Rhythm System — Implemented Classes

All classes are in `scripts/rhythm/`. They follow SOLID principles and communicate
mainly through Godot signals; `MusicPlayer → Metronome` and `Battle → EnemyGauge`
use direct method calls by design.

| File | Class | Base | Role |
|------|-------|------|------|
| `note_data.gd` | NoteData | Resource | Data: beat + action |
| `player_input.gd` | PlayerInput | Node | Input detection |
| `music_player.gd` | MusicPlayer | AudioStreamPlayer | Playback + time |
| `metronome.gd` | Metronome | Node | Beat tracking + timing eval |
| `composer.gd` | Composer | Node | Chart management |
| `judge.gd` | Judge | Node | Action validation |
| `referee.gd` | Referee | Node | Player HP / score / combo (data-driven) |
| `score_rules.gd` | ScoreRules | Resource | Tunable score values (editor) |
| `health_rules.gd` | HealthRules | Resource | Tunable HP values (editor) |
| `enemy_gauge.gd` | EnemyGauge | Node | Scripted enemy HP (song progress) |
| `rating_feedback.gd` | RatingFeedback | Node | Popup PERFECT/GOOD/MISS (text or image) |
| `lose_screen.gd` | LoseScreen | Control | Defeat scene: Retry / Return to Map / Main menu |
| `win_screen.gd` | WinScreen | Control | Victory scene with Continue button back to Map |

Signal flow: `MusicPlayer` → `Metronome` → `Composer` → `Judge` → `Referee` → UI.
`Battle` drives `EnemyGauge.update_song_progress()` each frame.
Tunables live in `assets/rules/*.tres` and are assigned to `Referee` in the Inspector.

## 💬 Dialogue System — Implemented Classes

All classes are in `scripts/dialogue/`. Pokemon-style: JSON-driven, attachable
to NPCs and objects through a single `Interactable` class. Signal-driven.

| File | Class | Base | Role |
|------|-------|------|------|
| `dialogue_loader.gd` | DialogueLoader + DialogueData + DialogueLine | RefCounted | Static JSON → data parser (mirrors ChartLoader) |
| `dialogue_box.gd` | DialogueBox | Control | Pure view: speaker + text + advance hint |
| `dialogue_runner.gd` | DialogueRunner | Node | Sequences lines, emits dialogue_started / dialogue_finished |
| `interactable.gd` | Interactable | Area2D | NPC or object; triggers dialogue and optionally a battle |

`DialogueRunner` instance lives as a child of `Map` (single runner per scene).
`Interactable` instances self-register to group `"interactables"` and are
looked up by `id` on post-battle return to replay win/lose dialogues.

Cross-scene state (return path, position, pending NPC id, battle result) lives
in the `Gamemanager` autoload.

Dialogue JSON lives in `assets/dialogues/*.json`; schema supports multiple
named dialogues per file (intro / victory / defeat / etc.).

## 🎬 Cinematic System — Implemented Classes

JSON-driven cutscenes for Map scenes. Command pattern in `CinematicPlayer`.
Authoring guide: `docs/cinematics/AUTHORING_GUIDE.md`.

| File | Class | Base | Role |
|------|-------|------|------|
| `cinematic_loader.gd` | CinematicLoader + CinematicStep + CinematicData | RefCounted | Parses cinematic JSON |
| `cinematic_player.gd` | CinematicPlayer | CanvasLayer | Executes steps; fade, letterbox, skip (E) |
| `cinematic_actor.gd` | CinematicActor | RefCounted | NPC walk / face / animation helpers |
| `cinematic_camera.gd` | CinematicCamera | RefCounted | Pan, zoom, shake, restore |
| `cinematic_target_resolver.gd` | CinematicTargetResolver | RefCounted | `to_path` / `to_node` / `to` resolution |
| `waypoint_path.gd` | WaypointPath | Node2D | Editable route with Marker2D children (`@tool`) |
| `scripted_trigger.gd` | ScriptedTrigger | Area2D | In-scene trigger → `Gamemanager.request_cinematic()` |
| `scripted_barrier.gd` | ScriptedBarrier | StaticBody2D | Toggleable barrier by `id` |
| `follower.gd` | Follower | Node2D | NPC lead/follow along WaypointPath |
| `interaction_indicator.gd` | InteractionIndicator | Node2D | Floating `!` on pending interactions |

Template scenes: `scenes/cinematic/*.tscn`. Cinematic JSON convention: `assets/cinematics/`.
Queue and one-shot state in `Gamemanager` (`request_cinematic`, `cinematics_played`).

**Editor plugin:** `addons/cinematic_authoring/` — toolbar 2D (+ Trigger, Barrier, Path, Waypoint, !).
Full guide (ES): `docs/cinematics/GUIA_COMPLETA_CINEMATICAS.md`.
