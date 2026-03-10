# 🎮 Contexto del Proyecto — Feria Gamer 2026

> **Archivo de referencia para asistentes de IA.**
> Actualiza este archivo cada vez que haya cambios importantes en el proyecto.

---

## 📋 Información General

| Campo | Detalle |
|---|---|
| **Nombre del proyecto** | Videojuego Educativo sobre Ciberacoso |
| **Motor** | Godot 4.6.1 (GDScript) |
| **Universidad** | Universidad del Norte — Barranquilla, Colombia |
| **Materia** | Programación Orientada a Objetos (POO) 2026-10 |
| **Evento** | V Feria Gamer — 28 de mayo de 2026 |
| **Repositorio** | https://github.com/[USUARIO]/feria-gamer-game |

---

## 🎯 Objetivo del Juego

Crear un videojuego educativo e inclusivo que concientice sobre el **bullying** y el **ciberacoso**,
promoviendo empatía, pensamiento crítico y estrategias de defensa positiva.

**No es un juego de trivia.** Tiene mecánicas activas, componente aleatorio y toma de decisiones.

---

## 🏗️ Requisitos Técnicos (Materia POO)

- [ ] Mínimo **5 clases (TAD)** de autoría propia
- [ ] Al menos **1 patrón de diseño** (NO Singleton, Prototype ni Module)
- [ ] **Interfaz gráfica** obligatoria (Godot UI)
- [ ] **Componente aleatorio** (obstáculos, eventos, dados virtuales)
- [ ] **Componente inclusivo** (subtítulos, modos de accesibilidad, selección de avatar)
- [ ] Herramienta de **AYUDA** dentro del juego
- [ ] **Mensajes motivadores**, sonidos y recompensas
- [ ] Robusto ante **entradas erróneas**
- [ ] **Prueba de usabilidad** con ≥ 5 usuarios reales

---

## 📅 Fechas Clave

| Entrega | Fecha | Peso |
|---|---|---|
| Primera entrega | 06 – 10 abril 2026 | 20% |
| Informe técnico | 20 mayo 2026 | 30% |
| Sustentación / Feria Gamer | 28 mayo 2026 | 50% |

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
├── docs/            # Documentación del proyecto
│   ├── design/      # GDD, diagramas UML, wireframes
│   ├── technical/   # Arquitectura, API interna
│   └── reports/     # Sprints, pruebas de usabilidad
└── ai/              # Contexto y prompts para IA
    ├── context/     # ← ESTÁS AQUÍ
    ├── prompts/     # Prompts reutilizables
    ├── decisions/   # Decisiones tomadas con ayuda de IA
    └── conversations/ # Conversaciones relevantes guardadas
```

---

## 🧩 Arquitectura de Clases (Borrador)

```
Entity (base)
├── Player
├── NPC
│   ├── Bully
│   └── Ally
GameManager (Observer/State pattern)
SceneTransitionManager
DialogueSystem
ScoreSystem
AccessibilityManager
```

> Ver diagrama completo en: `docs/design/diagrams/uml/class_diagram.puml`

---

## 🎨 Estilo Visual

- **Paleta:** Colores suaves, amigables (no violentos)
- **Resolución base:** 1280×720 (16:9)
- **Estilo:** Semi-cartoon, inclusivo, diverso en representación de personajes

---

## ⚙️ Stack Técnico

- **Motor:** Godot 4.6.1
- **Lenguaje:** GDScript (tipado estático donde sea posible)
- **Control de versiones:** Git + GitHub
- **Gestión de tareas:** [Jira / Trello — agregar link]
- **Comunicación:** [Discord / WhatsApp del equipo]

---

## 👥 Equipo

| Nombre | Rol | GitHub |
|---|---|---|
| [Nombre 1] | Lead Dev / Arquitectura | @usuario |
| [Nombre 2] | Game Design / Arte | @usuario |
| [Nombre 3] | UI/UX / Accesibilidad | @usuario |
| [Nombre 4] | Audio / Narrativa | @usuario |

---

## 📝 Notas para la IA

- El juego usa **GDScript**, no C#
- Godot 4.x usa `@export`, `@onready`, signals con `signal_name.emit()`, `CharacterBody2D`, etc.
- Los patrones de diseño deben ser evidentes en el código para la evaluación
- Cada clase debe tener docstring descriptivo
- Priorizar legibilidad sobre optimización prematura
