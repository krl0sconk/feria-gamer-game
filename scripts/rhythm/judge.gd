# Valida si la acción del jugador coincide con la nota esperada y el timing fue aceptable.
class_name Judge
extends Node

signal note_result(player_action: String, expected_action: String, timing: String, success: bool)


func evaluate(player_action: String, expected: NoteData, timing: String) -> void:
	var success: bool = player_action == expected.action and timing != "Miss"
	note_result.emit(player_action, expected.action, timing, success)
