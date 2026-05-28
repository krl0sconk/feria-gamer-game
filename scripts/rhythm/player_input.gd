# Detecta las pulsaciones del jugador y las emite como señales.
class_name PlayerInput
extends Node

signal button_pressed(action: String)

const VALID_ACTIONS: Array[String] = ["note_left", "note_down", "note_up", "note_right"]


# `_unhandled_input` corre tras la UI (Pause, etc), evitando dobles disparos
# si un Button/Control consumió el evento. `is_echo()` filtra el auto-repeat
# del SO al mantener una tecla — clave para charts densos.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) and not (event is InputEventJoypadButton):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	for action in VALID_ACTIONS:
		if event.is_action_pressed(action):
			button_pressed.emit(action)
			get_viewport().set_input_as_handled()
			return
