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

- [ ] Mínimo **5 clases (TAD)** de autoría propia
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
