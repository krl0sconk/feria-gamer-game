# 📐 Convenciones de Godot 4 — Proyecto Feria Gamer

> Guía de estilo y convenciones para mantener consistencia en el código.

---

## Nomenclatura

| Elemento | Convención | Ejemplo |
|---|---|---|
| Clases | PascalCase | `class_name PlayerCharacter` |
| Variables | snake_case | `var health_points: int` |
| Constantes | UPPER_SNAKE | `const MAX_HEALTH: int = 100` |
| Funciones | snake_case | `func take_damage(amount: int)` |
| Signals | snake_case | `signal health_changed(new_health)` |
| Nodos en escena | PascalCase | `AnimationPlayer`, `HitboxArea` |
| Archivos .gd | snake_case | `player_character.gd` |
| Archivos .tscn | snake_case | `main_menu.tscn` |

---

## Estructura de un Script GDScript

```gdscript
class_name NombreClase
extends NodoBase

## Descripción breve de la clase.
## Documentación adicional si es necesario.

# ── Signals ───────────────────────────────────────────────
signal example_signal(param: int)

# ── Constantes ────────────────────────────────────────────
const MAX_VALUE: int = 100

# ── @export (propiedades editables en editor) ─────────────
@export var speed: float = 200.0

# ── Variables privadas ────────────────────────────────────
var _internal_state: String = ""

# ── @onready (referencias a nodos hijos) ──────────────────
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _anim: AnimationPlayer = $AnimationPlayer

# ── Lifecycle ─────────────────────────────────────────────
func _ready() -> void:
    pass

func _process(delta: float) -> void:
    pass

func _physics_process(delta: float) -> void:
    pass

# ── Métodos públicos ──────────────────────────────────────
func do_something() -> void:
    pass

# ── Métodos privados ──────────────────────────────────────
func _helper_method() -> void:
    pass

# ── Signal handlers ───────────────────────────────────────
func _on_button_pressed() -> void:
    pass
```

---

## Godot 4 — Cambios Importantes vs Godot 3

```gdscript
# Godot 4 — NO Godot 3
emit_signal("signal_name")      # ❌ Godot 3
signal_name.emit()              # ✅ Godot 4

connect("signal", callable)     # ❌ Godot 3
signal_name.connect(callable)   # ✅ Godot 4

yield(signal, "completed")      # ❌ Godot 3
await signal_name               # ✅ Godot 4

KinematicBody2D                 # ❌ Godot 3
CharacterBody2D                 # ✅ Godot 4

move_and_slide(velocity)        # ❌ Godot 3
velocity = ...; move_and_slide()# ✅ Godot 4
```

---

## Patrones de Diseño Aprobados (para POO)

- ✅ **Observer** (Signals de Godot son Observer nativo)
- ✅ **State Machine** (para estados del jugador/NPC)
- ✅ **Factory** (para instanciar NPCs/objetos)
- ✅ **Command** (para sistema de diálogos o acciones)
- ✅ **Strategy** (para comportamientos de NPC)
- ✅ **Decorator** (para modificadores de stats)
- ❌ Singleton (prohibido por la materia)
- ❌ Prototype (prohibido por la materia)
- ❌ Module (prohibido por la materia)

---

## Organización de Escenas

- Cada escena tiene su propio archivo `.tscn` y script `.gd` del mismo nombre
- Los scripts van en `scripts/` mirroring la estructura de `scenes/`
- Recursos reutilizables → `resources/`
- Evitar escenas demasiado grandes: descomponer en sub-escenas

---

## Accesibilidad (Requisito del Proyecto)

- Todos los textos deben tener contraste ≥ 4.5:1 (WCAG AA)
- Usar fuentes legibles, tamaño mínimo 16px en UI
- Subtítulos en todos los audios relevantes
- Opciones de daltonismo (filtros de color)
- Teclas de acceso rápido + soporte de gamepad
- Selección de skin/avatar inclusiva (género, etnia)
