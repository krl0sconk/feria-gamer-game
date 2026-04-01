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

- [x] Mínimo **5 clases (TAD)** de autoría propia — ✅ 7 clases implementadas en `scripts/rhythm/`
- [x] Al menos **1 patrón de diseño** (Sin contar Singleton, Prototype ni Module) — ✅ Observer (señales de Godot)
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
│   └── rhythm/      # Sistema de ritmo: 7 clases (NoteData, PlayerInput, MusicPlayer,
│                    #   Metronome, Composer, Judge, Referee)
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

All 7 classes are in `scripts/rhythm/`. They follow SOLID principles and communicate
exclusively via signals (Observer pattern), except MusicPlayer → Metronome which uses
a direct `update_time(ms)` call by design.

| File | Class | Base | Role |
|------|-------|------|------|
| `note_data.gd` | NoteData | Resource | Data: beat + action |
| `player_input.gd` | PlayerInput | Node | Input detection |
| `music_player.gd` | MusicPlayer | AudioStreamPlayer | Playback + time |
| `metronome.gd` | Metronome | Node | Beat tracking + timing eval |
| `composer.gd` | Composer | Node | Chart management |
| `judge.gd` | Judge | Node | Action validation |
| `referee.gd` | Referee | Node | HP / score / combo |

Signal flow: `MusicPlayer` → `Metronome` → `Composer` → `Judge` → `Referee` → UI
