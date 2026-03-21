# Indicador estático de zona de pulsación; parpadea según el resultado del hit.
class_name NoteTarget
extends Node2D

enum Direction { LEFT, DOWN, UP, RIGHT }

const ROTATIONS: Dictionary = {
	Direction.LEFT: -90.0,
	Direction.DOWN: 180.0,
	Direction.UP: 0.0,
	Direction.RIGHT: 90.0,
}

@export var direction: Direction = Direction.UP


func _ready() -> void:
	rotation_degrees = ROTATIONS[direction]


func flash_hit() -> void:
	modulate = Color(1, 1, 0)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)


func flash_miss() -> void:
	modulate = Color(1, 0, 0)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)
