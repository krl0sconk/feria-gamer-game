# Detecta las pulsaciones del jugador y las emite como señales.
class_name PlayerInput
extends Node

signal button_pressed(action: String)

const VALID_ACTIONS: Array[String] = ["note_left", "note_down", "note_up", "note_right"]


func _input(event: InputEvent) -> void:
	for action in VALID_ACTIONS:
		if event.is_action_pressed(action):
			button_pressed.emit(action)
