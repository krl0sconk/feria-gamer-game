# Flecha visual que cae por la pantalla; se destruye al sobrepasar el target.
class_name NoteArrow
extends Node2D

enum Direction { LEFT, DOWN, UP, RIGHT }

const ROTATIONS: Dictionary = {
	Direction.LEFT: -90.0,
	Direction.DOWN: 180.0,
	Direction.UP: 0.0,
	Direction.RIGHT: 90.0,
}

@export var direction: Direction = Direction.UP
@export var speed: float = 400.0
@export var target_y: float = 500.0


func _ready() -> void:
	rotation_degrees = ROTATIONS[direction]


signal expired()

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > target_y + 100.0:
		expired.emit()
		queue_free()


func destroy() -> void:
	queue_free()
