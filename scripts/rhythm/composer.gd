# Gestiona el chart del nivel y emite cada nota cuando llega su momento.
class_name Composer
extends Node

signal note_expected(note: NoteData)

@export var chart: Array[NoteData] = []

var _next_index: int = 0
## Offset en ms: las notas se emiten _anticipation_ms ANTES de su time_ms,
## para que la flecha tenga tiempo de caer hasta el target.
var anticipation_ms: float = 0.0


func load_chart(data: Array[NoteData]) -> void:
	chart = data
	_next_index = 0


# Emite todas las notas cuyo momento de spawn ya llegó.
# spawn_time = note.time_ms - anticipation_ms
func update_time(current_ms: float) -> void:
	while _next_index < chart.size():
		var note: NoteData = chart[_next_index]
		if current_ms < note.time_ms - anticipation_ms:
			break
		note_expected.emit(note)
		_next_index += 1
