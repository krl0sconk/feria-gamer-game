# Indicador estático de zona de pulsación
class_name NoteTarget
extends Node2D

enum Direction {LEFT, DOWN, UP, RIGHT}

const ROTATIONS: Dictionary = {
	Direction.LEFT: - 90.0,
	Direction.DOWN: 180.0,
	Direction.UP: 0.0,
	Direction.RIGHT: 90.0,
}

@export var direction: Direction = Direction.UP

## Colores editables desde el Inspector — fácil de retocar sin tocar código.
@export var idle_color: Color = Color(1, 1, 1)
@export var press_color: Color = Color(0.4, 0.85, 1.0)
@export var hit_color: Color = Color(1, 1, 0)
@export var miss_color: Color = Color(1, 0.2, 0.2)
@export var flash_seconds: float = 0.1

# Token monotónico — solo el último flash apaga el sprite.
var _flash_token: int = 0


func _ready() -> void:
	rotation_degrees = ROTATIONS[direction]
	modulate = idle_color


func flash_press() -> void:
	_flash(press_color)


func flash_hit() -> void:
	_flash(hit_color)


func flash_miss() -> void:
	_flash(miss_color)


func _flash(color: Color) -> void:
	# Guard: el target podría estar fuera del árbol si la escena ya está
	# cambiando (derrota/victoria). get_tree() devuelve null en ese caso.
	if not is_inside_tree():
		return
	_flash_token += 1
	var token: int = _flash_token
	modulate = color
	await get_tree().create_timer(flash_seconds).timeout
	# Tras el await puede que ya no estemos en el árbol.
	if not is_inside_tree():
		return
	if token == _flash_token:
		modulate = idle_color
